# Getting Started - 5 Minute Setup

Quick guide to get your monitoring stack up and running.

## Prerequisites Checklist

- [ ] Kubernetes cluster running (check: `kubectl get nodes`)
- [ ] NGINX Ingress Controller installed
- [ ] Storage provisioner: local-path OR Longhorn (check: `kubectl get storageclass`)
- [ ] Cluster admin access (check: `kubectl auth can-i '*' '*'`)

## Option 1: Quick Deploy (Fastest)

### Step 1: Change Default Password

```bash
# Generate secure password
GRAFANA_PASSWORD=$(openssl rand -base64 32)
echo "Save this password: $GRAFANA_PASSWORD"

# Update secret file
sed -i "s/changeme-use-strong-password/$GRAFANA_PASSWORD/" base/grafana/secret.yaml
```

### Step 2: Deploy

```bash
# For local-path storage
kubectl apply -k overlays/local-path

# OR for Longhorn storage
kubectl apply -k overlays/longhorn
```

### Step 3: Wait for Ready

```bash
# Watch pods start
kubectl get pods -n monitoring -w

# Or wait for specific pods
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s
```

### Step 4: Access Grafana

```bash
# Get URL (replace with your IP)
echo "http://grafana.192.168.2.207.nip.io"

# Login
# Username: admin
# Password: (from Step 1)
```

### Step 5: Import Dashboards

1. In Grafana, click **+** → **Import**
2. Enter dashboard ID and click **Load**:
   - **15757** - Kubernetes Cluster Monitoring
   - **1860** - Node Exporter Full
   - **13639** - Loki Dashboard

**Done! Your monitoring stack is ready.**

---

## Option 2: Using the Deploy Script

```bash
# Make script executable
chmod +x deploy.sh

# Run (it will check prerequisites)
./deploy.sh local-path

# OR for Longhorn
./deploy.sh longhorn

# Follow the prompts
```

---

## Option 3: Using ArgoCD (GitOps)

### Prerequisites

- ArgoCD installed in your cluster
- This repository accessible to ArgoCD

### Steps

```bash
# 1. Install ArgoCD (if needed)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 3. Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# 4. Login to ArgoCD UI
# URL: https://localhost:8080
# Username: admin
# Password: (from step 2)

# 5. Create Application
kubectl apply -f examples/argocd-integration.yaml

# 6. Sync
argocd app sync monitoring-stack
```

---

## Verification Steps

### 1. Check All Pods Running

```bash
kubectl get pods -n monitoring

# Expected: All pods should be Running (1/1 or similar)
```

### 2. Check PVCs Bound

```bash
kubectl get pvc -n monitoring

# Expected: All PVCs should be Bound
```

### 3. Check Prometheus Targets

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &

# Open browser
# http://localhost:9090/targets

# Expected targets (all UP):
# - kubernetes-apiservers
# - kubernetes-nodes
# - kubernetes-cadvisor
# - node-exporter
# - kube-state-metrics
# - loki
```

### 4. Check Grafana Datasources

```bash
# Access Grafana
# http://grafana.192.168.2.207.nip.io

# Go to: Configuration → Data Sources
# Expected:
# - Prometheus (green check mark)
# - Loki (green check mark)
```

### 5. Test Alerts

```bash
# Create high CPU load
kubectl run stress-test --image=progrium/stress -n monitoring -- --cpu 4 --timeout 360s

# Wait 5 minutes, then check alerts
# http://prometheus.192.168.2.207.nip.io/alerts

# Should see: HighCPUUsage firing

# Clean up
kubectl delete pod stress-test -n monitoring
```

---

## Common Issues

### Pods Stuck in Pending

**Cause**: PVCs not bound (storage class missing)

**Fix**:
```bash
# Check storage classes
kubectl get storageclass

# Install local-path if missing
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
```

### Can't Access Ingress

**Cause**: NGINX Ingress Controller not installed

**Fix**:
```bash
# Install NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

# Wait for ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Prometheus Not Scraping

**Cause**: RBAC permissions

**Fix**:
```bash
# Check ClusterRoleBinding
kubectl get clusterrolebinding prometheus

# If missing, reapply
kubectl apply -k overlays/local-path
```

---

## Next Steps

### Configure Discord Alerts (Optional)

1. **Get Discord webhook URL**:
   - Server Settings → Integrations → Webhooks
   - Create webhook, copy URL

2. **Update Alertmanager**:
   ```bash
   kubectl edit configmap alertmanager-config -n monitoring

   # Replace: DISCORD_WEBHOOK_URL
   # With your actual webhook URL

   # Restart Alertmanager
   kubectl rollout restart deployment/alertmanager -n monitoring
   ```

3. **Test alert**:
   ```bash
   # Trigger test alert (see step 5 in Verification)
   # Check your Discord channel
   ```

### Monitor Your Applications

See examples for:
- **Linkding**: `examples/linkding-servicemonitor.yaml`
- **GitLab**: `examples/gitlab-monitoring.yaml`

Add these annotations to your app pods:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"  # Your metrics port
  prometheus.io/path: "/metrics"
```

### Secure Your Setup

See **SECRETS-MANAGEMENT.md** for:
- SOPS encryption (recommended)
- HashiCorp Vault integration
- Best practices

### Enable HTTPS

Install cert-manager and configure TLS:
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml

# See DEPLOYMENT.md for TLS configuration
```

---

## Quick Commands Reference

```bash
# View all monitoring resources
kubectl get all -n monitoring

# View logs from Prometheus
kubectl logs -n monitoring -l app=prometheus --tail=50

# View logs from Grafana
kubectl logs -n monitoring -l app=grafana --tail=50

# Restart all deployments
kubectl rollout restart deployment -n monitoring

# Delete everything (CAREFUL!)
kubectl delete -k overlays/local-path

# Port-forward services
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
kubectl port-forward -n monitoring svc/alertmanager 9093:9093 &
```

---

## Need Help?

- **Deployment Issues**: See [DEPLOYMENT.md](DEPLOYMENT.md)
- **Secrets Management**: See [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md)
- **What Changed**: See [CHANGELOG.md](CHANGELOG.md)
- **Architecture Details**: See [ARCHITECTURE.md](ARCHITECTURE.md)

---

## Resources

**Recommended Grafana Dashboards:**
- 15757 - Kubernetes Cluster Monitoring
- 1860 - Node Exporter Full
- 13639 - Loki Dashboard
- 2 - Prometheus Stats
- 9578 - Alertmanager

**Official Documentation:**
- [Prometheus](https://prometheus.io/docs/)
- [Grafana](https://grafana.com/docs/)
- [Loki](https://grafana.com/docs/loki/latest/)
- [Kustomize](https://kustomize.io/)
- [ArgoCD](https://argo-cd.readthedocs.io/)

**Community:**
- [Prometheus Community](https://prometheus.io/community/)
- [Grafana Community](https://community.grafana.com/)
- [Kubernetes Slack](https://kubernetes.slack.com/)
