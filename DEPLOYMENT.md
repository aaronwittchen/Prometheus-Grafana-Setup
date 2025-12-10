# Deployment Guide

Complete deployment guide for the Kubernetes monitoring stack on Arch Linux homeserver.

## Table of Contents

- [Quick Start](#quick-start)
- [Storage Configuration](#storage-configuration)
- [Secrets Management](#secrets-management)
- [Deployment Methods](#deployment-methods)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Prerequisites

1. **Kubernetes cluster** (v1.24+) - Already set up on your Arch Linux host
2. **kubectl** configured and working
3. **Storage provisioner** - Either local-path or Longhorn
4. **NGINX Ingress Controller** - For external access
5. **Cluster admin permissions**

### Choose Your Deployment Method

You have three options:

1. **kubectl + Kustomize** (Recommended for testing)
2. **ArgoCD** (Recommended for GitOps)
3. **Legacy single-file deployment** (Not recommended)

---

## Storage Configuration

You have both `local-path` and `longhorn` storage classes available. Choose one:

### Option 1: Local-Path Storage (Default)

```bash
# Deploy with local-path storage
kubectl apply -k overlays/local-path
```

**Pros:**
- Simpler setup
- Lower overhead
- Good for single-node clusters

**Cons:**
- No replication
- Data tied to single node
- No snapshots/backups

### Option 2: Longhorn Storage

```bash
# Deploy with Longhorn storage
kubectl apply -k overlays/longhorn
```

**Pros:**
- Data replication (if multi-node)
- Built-in snapshots and backups
- Volume encryption support
- Better for production

**Cons:**
- Higher resource usage
- More complex setup

---

## Secrets Management

The stack includes three options for managing secrets (Grafana password, Discord webhooks, etc.):

### Option 1: Basic Kubernetes Secrets (Current - Change Before Deploy!)

```bash
# Edit the secret file
nano base/grafana/secret.yaml

# Change the password
stringData:
  GF_SECURITY_ADMIN_PASSWORD: "YOUR_SECURE_PASSWORD_HERE"

# Apply
kubectl apply -k overlays/local-path
```

### Option 2: SOPS (Recommended for GitOps)

```bash
# Install SOPS and age
sudo pacman -S sops age

# Generate encryption key
age-keygen -o ~/.config/sops/age/keys.txt

# Get the public key
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
grep 'public key:' ~/.config/sops/age/keys.txt

# Create .sops.yaml in repository root
cat > .sops.yaml <<EOF
creation_rules:
  - path_regex: .*secret.*\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Your public key
EOF

# Encrypt the secret
sops -e -i base/grafana/secret.yaml

# Now the file is encrypted and safe to commit to Git
# ArgoCD will decrypt it automatically if configured

# To edit encrypted file
sops base/grafana/secret.yaml
```

**ArgoCD SOPS Integration:**
```bash
# Install SOPS plugin for ArgoCD
kubectl apply -f examples/argocd-sops-plugin.yaml
```

### Option 3: HashiCorp Vault

```bash
# Install Vault
kubectl create namespace vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault -n vault

# Store Grafana password in Vault
vault kv put secret/monitoring/grafana \
  admin_user=admin \
  admin_password="YOUR_SECURE_PASSWORD"

# Use vault-injector or external-secrets operator
# See examples/vault-integration.yaml for details
```

---

## Deployment Methods

### Method 1: kubectl + Kustomize (Quick Start)

```bash
# 1. Clone or navigate to repository
cd "Prometheus & Grafana Setup"

# 2. Review and update secrets
nano base/grafana/secret.yaml
# Change GF_SECURITY_ADMIN_PASSWORD

# 3. (Optional) Update Discord webhook URL
nano base/alertmanager/configmap.yaml
# Replace DISCORD_WEBHOOK_URL with your webhook

# 4. Deploy with local-path storage
kubectl apply -k overlays/local-path

# OR deploy with Longhorn
kubectl apply -k overlays/longhorn

# 5. Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s

# 6. Check deployment
kubectl get pods -n monitoring
```

### Method 2: ArgoCD (GitOps - Recommended)

```bash
# 1. Install ArgoCD (if not already installed)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# 3. Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 4. Port-forward ArgoCD UI (or use Ingress)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 5. Login to ArgoCD
# URL: https://localhost:8080
# Username: admin
# Password: (from step 3)

# 6. Create Application via CLI
kubectl apply -f examples/argocd-integration.yaml

# OR create via UI:
# - Click "+ New App"
# - Application Name: monitoring-stack
# - Project: default
# - Repo URL: https://github.com/YOUR_USERNAME/YOUR_REPO
# - Path: overlays/local-path
# - Cluster: https://kubernetes.default.svc
# - Namespace: monitoring
# - Enable auto-sync

# 7. Sync the application
argocd app sync monitoring-stack
```

### Method 3: Helm (Alternative)

```bash
# Package as Helm chart (future improvement)
# This would allow values.yaml for configuration
# Not implemented yet - stick with Kustomize for now
```

---

## Post-Deployment Configuration

### 1. Configure Discord Webhook (Optional)

```bash
# Get Discord webhook URL:
# 1. Go to your Discord server
# 2. Server Settings → Integrations → Webhooks
# 3. Create webhook, copy URL

# Update Alertmanager config
kubectl edit configmap alertmanager-config -n monitoring

# Replace DISCORD_WEBHOOK_URL with your actual URL
# Restart Alertmanager
kubectl rollout restart deployment/alertmanager -n monitoring
```

### 2. Access Grafana

```bash
# Get Grafana URL
echo "http://grafana.192.168.2.207.nip.io"

# Or port-forward
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Login
# URL: http://localhost:3000
# Username: admin
# Password: (what you set in secrets)
```

### 3. Import Grafana Dashboards

```bash
# Recommended dashboards:
# 1. Kubernetes Cluster Monitoring - ID: 15757
# 2. Node Exporter Full - ID: 1860
# 3. Loki Dashboard - ID: 13639
# 4. Prometheus Stats - ID: 2
# 5. Alertmanager - ID: 9578

# Import via UI:
# Grafana → Dashboards → Import → Enter Dashboard ID
```

### 4. Verify Prometheus Targets

```bash
# Access Prometheus UI
echo "http://prometheus.192.168.2.207.nip.io"

# Or port-forward
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Check targets at: http://localhost:9090/targets
# Should see:
# - kubernetes-apiservers
# - kubernetes-nodes
# - kubernetes-cadvisor
# - node-exporter
# - kube-state-metrics
# - loki
# - longhorn (if available)
```

### 5. Test Alerting

```bash
# Trigger a test alert
kubectl run test-alert --image=progrium/stress -n monitoring -- --cpu 4 --timeout 360s

# Check alerts in Prometheus:
# http://prometheus.192.168.2.207.nip.io/alerts

# Should see HighCPUUsage firing after 5 minutes

# Clean up
kubectl delete pod test-alert -n monitoring
```

---

## Verification

### Check All Pods are Running

```bash
kubectl get pods -n monitoring

# Expected output:
# NAME                                 READY   STATUS    RESTARTS   AGE
# prometheus-xxxx                      1/1     Running   0          5m
# grafana-xxxx                         1/1     Running   0          5m
# alertmanager-xxxx                    1/1     Running   0          5m
# node-exporter-xxxx                   1/1     Running   0          5m
# kube-state-metrics-xxxx              1/1     Running   0          5m
# loki-xxxx                            1/1     Running   0          5m
# promtail-xxxx                        1/1     Running   0          5m
```

### Check PVCs are Bound

```bash
kubectl get pvc -n monitoring

# Expected output:
# NAME                 STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS
# prometheus-storage   Bound    pvc-xxxx      25Gi       RWO            local-path
# grafana-storage      Bound    pvc-xxxx      10Gi       RWO            local-path
# loki-storage         Bound    pvc-xxxx      20Gi       RWO            local-path
```

### Check Services

```bash
kubectl get svc -n monitoring

# Expected services:
# - prometheus (ClusterIP:9090)
# - grafana (ClusterIP:3000)
# - alertmanager (ClusterIP:9093)
# - loki (ClusterIP:3100)
# - node-exporter (ClusterIP:9100)
# - kube-state-metrics (ClusterIP:8080)
```

### Check Ingress

```bash
kubectl get ingress -n monitoring

# Should show ingresses for:
# - grafana.192.168.2.207.nip.io
# - prometheus.192.168.2.207.nip.io
# - alertmanager.192.168.2.207.nip.io
```

### Test Metrics Collection

```bash
# Query Prometheus for node metrics
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl "http://localhost:9090/api/v1/query?query=up" | jq .

# Should return metrics from all exporters
```

### Test Log Collection

```bash
# Query Loki for logs
kubectl port-forward -n monitoring svc/loki 3100:3100 &
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={namespace="monitoring"}' | jq .

# Should return recent logs from monitoring namespace
```

---

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check PVC status
kubectl describe pvc -n monitoring

# Check storage class
kubectl get storageclass

# If local-path missing:
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
```

### Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
kubectl logs -n monitoring -l app=prometheus --tail=100

# Check RBAC permissions
kubectl get clusterrolebinding prometheus
kubectl describe clusterrole prometheus

# Verify service discovery
kubectl get pods -n monitoring -o yaml | grep "prometheus.io/scrape"
```

### Grafana Can't Connect to Datasources

```bash
# Check Grafana logs
kubectl logs -n monitoring -l app=grafana --tail=100

# Verify datasource config
kubectl get configmap grafana-datasources -n monitoring -o yaml

# Test Prometheus connectivity from Grafana pod
kubectl exec -n monitoring -it $(kubectl get pod -n monitoring -l app=grafana -o name) -- \
  wget -O- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/status/config
```

### Alerts Not Firing

```bash
# Check alert rules are loaded
kubectl logs -n monitoring -l app=prometheus --tail=100 | grep -i rule

# View alert rules in Prometheus UI
# http://prometheus.192.168.2.207.nip.io/rules

# Check Alertmanager connection
kubectl logs -n monitoring -l app=alertmanager --tail=100
```

### Discord Webhooks Not Working

```bash
# Check Alertmanager logs
kubectl logs -n monitoring -l app=alertmanager --tail=100 | grep -i webhook

# Test webhook manually
curl -X POST "YOUR_DISCORD_WEBHOOK_URL/slack" \
  -H "Content-Type: application/json" \
  -d '{"text": "Test alert from Alertmanager"}'

# Verify Alertmanager config
kubectl get configmap alertmanager-config -n monitoring -o yaml
```

### High Resource Usage

```bash
# Check resource usage
kubectl top pods -n monitoring
kubectl top nodes

# Reduce Prometheus retention if needed
kubectl edit deployment prometheus -n monitoring
# Change: --storage.tsdb.retention.time=15d

# Reduce resource limits
kubectl edit deployment prometheus -n monitoring
```

### Network Policies Blocking Traffic

```bash
# Check if network policies are applied
kubectl get networkpolicies -n monitoring

# Temporarily disable network policies for testing
kubectl delete networkpolicies --all -n monitoring

# Re-enable after troubleshooting
kubectl apply -k overlays/local-path
```

---

## Next Steps

1. **Configure Application Monitoring**
   - See `examples/linkding-servicemonitor.yaml`
   - See `examples/gitlab-monitoring.yaml`

2. **Set Up Backups**
   - If using Longhorn: Enable recurring snapshots
   - Manual backups: See `examples/backup-cronjob.yaml`

3. **Enable HTTPS**
   - Install cert-manager
   - Configure TLS ingress
   - See examples/https-ingress.yaml

4. **Integrate with Vault/SOPS**
   - Follow secrets management section above
   - Commit encrypted secrets to Git

5. **Add More Exporters**
   - PostgreSQL exporter for databases
   - NGINX exporter for ingress metrics
   - Redis exporter if using Redis

6. **Configure Grafana Alerts**
   - Set up alert rules in Grafana
   - Configure notification channels
   - Create custom dashboards

---

## Useful Commands

```bash
# View all monitoring resources
kubectl get all -n monitoring

# Restart all deployments
kubectl rollout restart deployment -n monitoring

# View logs from all pods
kubectl logs -n monitoring -l stack=monitoring --tail=50 -f

# Delete everything (CAREFUL!)
kubectl delete -k overlays/local-path

# Export current configuration
kubectl get all -n monitoring -o yaml > backup.yaml

# Check resource quotas
kubectl describe resourcequota -n monitoring
```
