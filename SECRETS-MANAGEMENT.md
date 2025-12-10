# Secrets Management Guide

This guide covers three methods for managing secrets in the monitoring stack, from basic to production-ready.

## Table of Contents

- [Method 1: Basic Kubernetes Secrets](#method-1-basic-kubernetes-secrets)
- [Method 2: SOPS (Recommended for GitOps)](#method-2-sops-recommended-for-gitops)
- [Method 3: HashiCorp Vault](#method-3-hashicorp-vault)

---

## Method 1: Basic Kubernetes Secrets

**Use for:** Testing, local development
**Security level:** Low (base64 encoded, not encrypted)

### Setup

```bash
# Edit the secret file
nano base/grafana/secret.yaml

# Change the password
stringData:
  GF_SECURITY_ADMIN_PASSWORD: "YOUR_SECURE_PASSWORD_HERE"

# Apply
kubectl apply -k overlays/local-path
```

### Generate Secure Password

```bash
# Generate random password
openssl rand -base64 32

# Or use pwgen (install: sudo pacman -S pwgen)
pwgen -s 32 1
```

### Updating Existing Secret

```bash
# Delete old secret
kubectl delete secret grafana-admin-secret -n monitoring

# Recreate
kubectl create secret generic grafana-admin-secret \
  -n monitoring \
  --from-literal=GF_SECURITY_ADMIN_USER=admin \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD="$(openssl rand -base64 32)" \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

---

## Method 2: SOPS (Recommended for GitOps)

**Use for:** GitOps with ArgoCD, version-controlled secrets
**Security level:** High (encrypted at rest, keys managed separately)

### Prerequisites

```bash
# Install SOPS and age on Arch Linux
sudo pacman -S sops age

# Or using Homebrew/other package managers
# brew install sops age
```

### Setup

#### 1. Generate Age Key

```bash
# Create SOPS config directory
mkdir -p ~/.config/sops/age

# Generate age keypair
age-keygen -o ~/.config/sops/age/keys.txt

# View public key (you'll need this)
grep 'public key:' ~/.config/sops/age/keys.txt
# Output: public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### 2. Configure SOPS

```bash
# Create .sops.yaml in repository root
cat > .sops.yaml <<EOF
creation_rules:
  - path_regex: .*secret.*\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Your public key from step 1
EOF

# Add to .gitignore (don't commit keys!)
echo "~/.config/sops/age/keys.txt" >> ~/.gitignore
```

#### 3. Encrypt Secrets

```bash
# Encrypt Grafana secret
sops -e -i base/grafana/secret.yaml

# The file is now encrypted and safe to commit to Git
git add base/grafana/secret.yaml .sops.yaml
git commit -m "Add encrypted Grafana secret"
```

#### 4. Edit Encrypted Secrets

```bash
# SOPS will decrypt in your editor, re-encrypt on save
sops base/grafana/secret.yaml
```

#### 5. Decrypt for Kubectl

```bash
# Decrypt and apply
sops -d base/grafana/secret.yaml | kubectl apply -f -

# Or use with Kustomize
kubectl apply -k overlays/local-path --dry-run=client -o yaml | \
  sops -d /dev/stdin | kubectl apply -f -
```

### ArgoCD Integration

#### Option A: ArgoCD SOPS Plugin

```bash
# 1. Install SOPS plugin for ArgoCD
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  kustomize.buildOptions: "--enable-alpha-plugins --enable-exec"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cmp-plugin
  namespace: argocd
data:
  plugin.yaml: |
    apiVersion: argoproj.io/v1alpha1
    kind: ConfigManagementPlugin
    metadata:
      name: kustomized-sops
    spec:
      version: v1.0
      init:
        command: [sh, -c]
        args: ["kustomize build . > all.yaml && sops -d all.yaml > all-decrypted.yaml"]
      generate:
        command: [sh, -c]
        args: ["cat all-decrypted.yaml"]
EOF

# 2. Create secret with age key
kubectl create secret generic sops-age-key \
  -n argocd \
  --from-file=keys.txt=$HOME/.config/sops/age/keys.txt

# 3. Patch ArgoCD repo server deployment
kubectl patch deployment argocd-repo-server -n argocd --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "sops-age-key", "secret": {"secretName": "sops-age-key"}}},
       {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": {"mountPath": "/sops-age", "name": "sops-age-key"}},
       {"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "SOPS_AGE_KEY_FILE", "value": "/sops-age/keys.txt"}}]'
```

#### Option B: External Secrets with SOPS

```bash
# Use external-secrets operator with SOPS backend
# This is more complex but provides better separation
# See: https://external-secrets.io/latest/provider/sops/
```

### Managing Multiple Secrets

```bash
# Encrypt Discord webhook
cat > base/alertmanager/discord-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: discord-webhook
  namespace: monitoring
type: Opaque
stringData:
  webhook_url: "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE"
EOF

sops -e -i base/alertmanager/discord-secret.yaml

# Reference in Alertmanager config
# webhook_configs:
#   - url_file: /secrets/webhook_url
```

---

## Method 3: HashiCorp Vault

**Use for:** Enterprise, multiple clusters, centralized secret management
**Security level:** Highest (dynamic secrets, audit logs, access control)

### Prerequisites

```bash
# Install Vault
sudo pacman -S vault

# Or deploy Vault in Kubernetes
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault -n vault --create-namespace
```

### Setup Vault in Kubernetes

#### 1. Deploy Vault

```bash
# Create namespace
kubectl create namespace vault

# Install Vault
helm install vault hashicorp/vault \
  --namespace vault \
  --set "server.dev.enabled=true"  # DEV MODE - NOT FOR PRODUCTION

# Initialize and unseal (production setup)
# kubectl exec -n vault vault-0 -- vault operator init
# kubectl exec -n vault vault-0 -- vault operator unseal
```

#### 2. Configure Vault

```bash
# Port-forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

# Login to Vault
export VAULT_ADDR='http://127.0.0.1:8200'
vault login  # Use root token from init

# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Store Grafana password
vault kv put secret/monitoring/grafana \
  admin_user=admin \
  admin_password="$(openssl rand -base64 32)"

# Store Discord webhook
vault kv put secret/monitoring/alertmanager \
  discord_webhook="https://discord.com/api/webhooks/YOUR_WEBHOOK"
```

#### 3. Option A: Vault Injector (Sidecar)

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create policy
vault policy write monitoring - <<EOF
path "secret/data/monitoring/*" {
  capabilities = ["read"]
}
EOF

# Create role
vault write auth/kubernetes/role/monitoring \
  bound_service_account_names=grafana \
  bound_service_account_namespaces=monitoring \
  policies=monitoring \
  ttl=24h
```

**Update Grafana deployment:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "monitoring"
        vault.hashicorp.com/agent-inject-secret-admin: "secret/data/monitoring/grafana"
        vault.hashicorp.com/agent-inject-template-admin: |
          {{- with secret "secret/data/monitoring/grafana" -}}
          export GF_SECURITY_ADMIN_PASSWORD="{{ .Data.data.admin_password }}"
          {{- end }}
    spec:
      serviceAccountName: grafana
      containers:
        - name: grafana
          command: ["/bin/sh", "-c"]
          args:
            - source /vault/secrets/admin && /run.sh
```

#### 4. Option B: External Secrets Operator

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace

# Create SecretStore
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: monitoring
spec:
  provider:
    vault:
      server: "http://vault.vault:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "monitoring"
          serviceAccountRef:
            name: "grafana"
EOF

# Create ExternalSecret
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-admin-secret
  namespace: monitoring
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: grafana-admin-secret
    creationPolicy: Owner
  data:
    - secretKey: GF_SECURITY_ADMIN_USER
      remoteRef:
        key: monitoring/grafana
        property: admin_user
    - secretKey: GF_SECURITY_ADMIN_PASSWORD
      remoteRef:
        key: monitoring/grafana
        property: admin_password
EOF
```

### Vault Best Practices

1. **Never use dev mode in production**
2. **Always enable audit logging**
3. **Use AppRole or Kubernetes auth, not root tokens**
4. **Rotate secrets regularly**
5. **Use dynamic secrets when possible**
6. **Monitor Vault metrics with Prometheus**

---

## Comparison

| Feature | Basic Secrets | SOPS | Vault |
|---------|--------------|------|-------|
| **Encryption at rest** | ❌ | ✅ | ✅ |
| **Version control safe** | ❌ | ✅ | N/A |
| **GitOps friendly** | ⚠️  | ✅ | ✅ |
| **Audit logs** | ❌ | ❌ | ✅ |
| **Dynamic secrets** | ❌ | ❌ | ✅ |
| **Setup complexity** | Low | Medium | High |
| **Operational overhead** | Low | Low | Medium-High |
| **Cost** | Free | Free | Free (OSS) |
| **Best for** | Testing | GitOps/homelab | Enterprise |

---

## Recommended Approach

### For Your Arch Linux Homelab

**Start with SOPS** (Method 2):
- Production-like security without complexity
- Works perfectly with ArgoCD
- Easy to use with `age` encryption
- Secrets safely stored in Git (encrypted)
- Low operational overhead

**Migrate to Vault later if needed:**
- Adding more clusters
- Need dynamic secrets
- Require audit logging
- Compliance requirements

---

## Quick Reference

### SOPS Commands

```bash
# Encrypt file
sops -e -i secret.yaml

# Decrypt file
sops -d secret.yaml

# Edit encrypted file
sops secret.yaml

# Decrypt and apply
sops -d secret.yaml | kubectl apply -f -

# Rotate keys
sops updatekeys secret.yaml
```

### Vault Commands

```bash
# Store secret
vault kv put secret/path key=value

# Read secret
vault kv get secret/path

# Delete secret
vault kv delete secret/path

# List secrets
vault kv list secret/

# Create token
vault token create -policy=monitoring
```

---

## Troubleshooting

### SOPS: "no key could decrypt the data"

```bash
# Ensure age key is available
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
cat $SOPS_AGE_KEY_FILE

# Check .sops.yaml has correct public key
cat .sops.yaml
```

### Vault: "permission denied"

```bash
# Check Vault token
vault token lookup

# Verify policy
vault policy read monitoring

# Test authentication
vault login -method=kubernetes role=monitoring
```

### External Secrets: Not syncing

```bash
# Check SecretStore
kubectl describe secretstore vault-backend -n monitoring

# Check ExternalSecret
kubectl describe externalsecret grafana-admin-secret -n monitoring

# View operator logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets
```
