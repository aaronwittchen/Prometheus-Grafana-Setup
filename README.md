# Prometheus & Grafana Kubernetes Setup

> **Version 2.0** - Complete monitoring stack with Loki, Alertmanager, and GitOps support

A production-ready monitoring and observability stack for Kubernetes, optimized for homelab use on Arch Linux. Built with Kustomize for easy customization and ArgoCD integration.

## 🎯 What This Deploys

This setup provides a complete observability stack:

### Core Monitoring
- **Prometheus**: Metrics collection, time-series database, and alerting engine with 30-day retention
- **Grafana**: Visualization and dashboards with pre-configured datasources
- **Node Exporter**: Host-level metrics (CPU, memory, disk, network)
- **Kube-State-Metrics**: Kubernetes object metrics (pods, deployments, nodes)

### Alerting & Notifications
- **Alertmanager**: Alert routing and notification management
- **Discord Integration**: Send alerts to Discord channels via webhooks
- **10+ Pre-configured Alerts**: CPU, memory, disk, pod health, node status, and more

### Log Aggregation
- **Loki**: Log aggregation and querying
- **Promtail**: Log collector DaemonSet running on all nodes

### Security & Production Features
- **Network Policies**: Restrict pod-to-pod communication
- **RBAC**: Least-privilege service accounts
- **Secrets Management**: Ready for SOPS/Vault integration
- **Resource Limits**: Prevent resource exhaustion

### Storage & GitOps
- **Flexible Storage**: Choose between local-path or Longhorn via Kustomize overlays
- **ArgoCD Ready**: Full GitOps support with example configurations
- **Auto-discovery**: Automatically scrapes pods with Prometheus annotations

## 📋 Prerequisites

- Kubernetes cluster (1.24+)
- NGINX Ingress Controller installed
- Storage provisioner: **local-path** OR **Longhorn**
- `kubectl` configured to access your cluster
- Cluster admin permissions (for RBAC setup)

## 🚀 Quick Start

Choose your deployment method:

### Method 1: kubectl + Kustomize (Fastest)

```bash
# 1. Clone/download this repository
cd "Prometheus & Grafana Setup"

# 2. **IMPORTANT:** Change default password!
nano base/grafana/secret.yaml
# Change: GF_SECURITY_ADMIN_PASSWORD: "YOUR_SECURE_PASSWORD"

# 3. Deploy with local-path storage (default)
kubectl apply -k overlays/local-path

# OR deploy with Longhorn storage
kubectl apply -k overlays/longhorn

# 4. Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s

# 5. Access Grafana
echo "http://grafana.192.168.2.207.nip.io"
# Username: admin
# Password: (what you set in step 2)
```

### Method 2: ArgoCD (GitOps - Recommended for Production)

```bash
# 1. Install ArgoCD (if not installed)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Create monitoring Application
kubectl apply -f examples/argocd-integration.yaml

# 3. Sync the application
argocd app sync monitoring-stack
```

### 3. Post-Deployment Steps

1. **Access Grafana**: `http://grafana.192.168.2.207.nip.io`
2. **Import Dashboards**: See [DEPLOYMENT.md](DEPLOYMENT.md#3-import-grafana-dashboards)
3. **Configure Discord**: See [DEPLOYMENT.md](DEPLOYMENT.md#1-configure-discord-webhook-optional)
4. **Verify Targets**: `http://prometheus.192.168.2.207.nip.io/targets`

> **Note:** Replace `192.168.2.207` with your actual node IP address.

📖 **For detailed deployment options, troubleshooting, and advanced configuration, see [DEPLOYMENT.md](DEPLOYMENT.md)**

## 🆕 What's New in Version 2.0

### Major Improvements

1. **Kustomize Structure**: Modular, reusable configurations ready for GitOps
2. **Node Exporter & Kube-State-Metrics**: Essential exporters now included (were missing in v1)
3. **Alertmanager**: Full alert routing with Discord webhook support
4. **Loki + Promtail**: Complete log aggregation stack
5. **Network Policies**: Production-grade security
6. **Secrets Management**: SOPS and Vault integration ready
7. **ArgoCD Ready**: Full GitOps support with example configurations
8. **Storage Flexibility**: Easy switching between local-path and Longhorn
9. **Better Alerts**: 10+ comprehensive alert rules (fixed to work without CRDs)
10. **Improved Documentation**: Comprehensive deployment and troubleshooting guides

### Fixed Issues from v1

- ✅ Missing Node Exporter (node metrics now work)
- ✅ Missing Kube-State-Metrics (pod/node alerts now work)
- ✅ Alert rules requiring Prometheus Operator CRDs (now use ConfigMap)
- ✅ No log aggregation (Loki + Promtail added)
- ✅ No Alertmanager (now included with Discord support)
- ✅ Hardcoded storage class (now flexible via overlays)
- ✅ Weak secrets management (SOPS/Vault integration ready)
- ✅ Single-file deployment (now modular with Kustomize)

## 📊 What Gets Monitored

### 4. Verify Prometheus is Scraping

1. Open Prometheus UI
2. Go to **Status → Targets**
3. You should see:
   - `kubernetes-apiservers`
   - `kubernetes-nodes`
   - `kubernetes-pods` (will show GitLab pods once deployed)
   - `longhorn`
   - `coredns`

### 5. Check Alert Rules

1. Open Prometheus UI
2. Go to **Alerts**
3. You should see five alert rules:
   - **HighCPUUsage**: Triggers when CPU > 80%
   - **HighMemoryUsage**: Triggers when memory > 85%
   - **DiskSpaceLow**: Triggers when disk space < 15%
   - **PodRestartingTooOften**: Triggers when pods restart frequently
   - **NodeNotReady**: Triggers when a node is not ready

## 📊 What Gets Monitored

### Automatic Discovery

Pods with these annotations are automatically discovered:

```yaml
annotations:
  prometheus.io/scrape: 'true'
  prometheus.io/port: '9090' # Optional, defaults to pod port
  prometheus.io/path: '/metrics' # Optional, defaults to /metrics
```

### Pre-configured Targets

- **Kubernetes API Server**: API server metrics
- **Kubernetes Nodes**: Node-level metrics (CPU, memory, disk, network)
- **Longhorn**: Storage system metrics
- **CoreDNS**: DNS service metrics

## 🔧 Configuration

### Storage Sizes

Default storage allocations (homelab-optimized):

- **Prometheus**: 25Gi (30-day retention, reduced for disk efficiency)
- **Grafana**: 10Gi (dashboards and configs)

To adjust, edit the PVC definitions in `prometheus-grafana.yaml`:

```yaml
resources:
  requests:
    storage: 25Gi # Change this value
```

### Scrape Interval

Prometheus is set to 30-second scrape intervals (reduced from 15s for homelab efficiency):

```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 30s
```

To change, edit the ConfigMap in the manifest.

### Retention Period

Prometheus is configured for 30-day retention. To change:

```yaml
args:
  - --storage.tsdb.retention.time=30d # Change to 60d, 90d, etc.
```

### Alert Configuration

Current alert thresholds (homelab-friendly):

| Alert          | Condition                   | Duration  |
| -------------- | --------------------------- | --------- |
| High CPU       | CPU > 80%                   | 5 minutes |
| High Memory    | Memory > 85%                | 5 minutes |
| Low Disk Space | Free space < 15%            | 5 minutes |
| Pod Restarts   | Restarts in last 15 minutes | 5 minutes |
| Node Not Ready | Node down                   | 2 minutes |

To customize thresholds, edit the PrometheusRule in the manifest:

```yaml
expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
```

### Alerting to External Services

To integrate alerts with Slack, email, or PagerDuty, you'll need Alertmanager. Add this minimal setup:

```bash
# Create an Alertmanager ConfigMap and Deployment
# This is optional for homelab - Prometheus UI alerts are visible without it
```

For now, alerts are visible in the Prometheus UI under the **Alerts** tab.

### Resource Limits

Current resource allocation (homelab-friendly):

**Prometheus:**

- CPU: 250m-1000m
- Memory: 512Mi-2Gi

**Grafana:**

- CPU: 100m-500m
- Memory: 256Mi-1Gi

Adjust in the deployment specs if needed.

### Admin Credentials

Default credentials are `admin/admin`. To change:

1. Update the Secret:

```bash
kubectl create secret generic grafana-admin-secret \
  -n monitoring \
  --from-literal=GF_SECURITY_ADMIN_USER=admin \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD=your-password \
  --dry-run=client -o yaml | kubectl apply -f -
```

2. Restart Grafana:

```bash
kubectl rollout restart deployment/grafana -n monitoring
```

## 🔍 Troubleshooting

### Pods Not Starting

**Check PVC status:**

```bash
kubectl get pvc -n monitoring
kubectl describe pvc prometheus-storage -n monitoring
kubectl describe pvc grafana-storage -n monitoring
```

**Check pod events:**

```bash
kubectl describe pod -n monitoring -l app=prometheus
kubectl describe pod -n monitoring -l app=grafana
```

### Prometheus Not Scraping Targets

1. Check Prometheus logs:

```bash
kubectl logs -n monitoring -l app=prometheus
```

2. Verify RBAC permissions:

```bash
kubectl get clusterrolebinding prometheus
kubectl describe clusterrole prometheus
```

3. Check service discovery:
   - Open Prometheus UI → Status → Service Discovery
   - Verify pods have correct annotations

### Alert Rules Not Loading

```bash
# Check if PrometheusRule is created
kubectl get prometheusrule -n monitoring

# Check Prometheus logs for rule loading errors
kubectl logs -n monitoring -l app=prometheus | grep -i rule
```

### Grafana Can't Connect to Prometheus

The datasource is auto-configured. To verify:

1. Check ConfigMap:

```bash
kubectl get configmap grafana-datasources -n monitoring -o yaml
```

2. Check Grafana logs:

```bash
kubectl logs -n monitoring -l app=grafana
```

3. Manually verify in Grafana UI:
   - Configuration → Data Sources
   - Test the Prometheus connection

### Ingress Not Working

1. Check Ingress status:

```bash
kubectl get ingress -n monitoring
kubectl describe ingress grafana -n monitoring
```

2. Verify NGINX Ingress Controller:

```bash
kubectl get pods -n ingress-nginx
```

3. Test DNS resolution:

```bash
nslookup grafana.192.168.2.207.nip.io
# Should resolve to 192.168.2.207
```

## 📈 Monitoring GitLab

Once GitLab is deployed with Prometheus annotations, it will be automatically discovered:

1. **Verify Discovery:**

   ```bash
   # Port-forward to Prometheus
   kubectl port-forward -n monitoring svc/prometheus 9090:9090
   # Visit http://localhost:9090 → Status → Targets
   ```

2. **Query Metrics:**

   - In Prometheus UI, try: `up{namespace="gitlab"}`
   - Should return `1` for each GitLab pod being scraped

3. **Create Dashboards:**
   - In Grafana, go to Dashboards → Import
   - Use GitLab dashboard IDs from [Grafana.com](https://grafana.com/grafana/dashboards/)

## 🗂️ Project Structure

```
.
├── base/                           # Kustomize base configurations
│   ├── namespace.yaml              # monitoring namespace
│   ├── prometheus/                 # Prometheus configs
│   │   ├── rbac.yaml              # ServiceAccount, ClusterRole, Binding
│   │   ├── configmap.yaml         # Prometheus config + alert rules
│   │   ├── deployment.yaml        # Prometheus deployment
│   │   ├── service.yaml           # Prometheus service
│   │   └── pvc.yaml               # Storage claim
│   ├── grafana/                    # Grafana configs
│   │   ├── secret.yaml            # Admin credentials (CHANGE THIS!)
│   │   ├── configmap.yaml         # Datasources config
│   │   ├── deployment.yaml        # Grafana deployment
│   │   ├── service.yaml           # Grafana service
│   │   └── pvc.yaml               # Storage claim
│   ├── node-exporter/              # Node metrics exporter
│   ├── kube-state-metrics/         # Kubernetes metrics exporter
│   ├── alertmanager/               # Alert routing and notifications
│   ├── loki/                       # Log aggregation
│   ├── promtail/                   # Log collection
│   ├── ingress/                    # Ingress resources
│   ├── network-policies/           # Network policies for security
│   └── kustomization.yaml          # Base kustomization
│
├── overlays/                       # Environment-specific configs
│   ├── local-path/                 # Use local-path storage
│   │   └── kustomization.yaml
│   └── longhorn/                   # Use Longhorn storage
│       └── kustomization.yaml
│
├── examples/                       # Example configurations
│   ├── linkding-servicemonitor.yaml    # Monitor Linkding app
│   ├── gitlab-monitoring.yaml          # Monitor GitLab
│   └── argocd-integration.yaml         # ArgoCD Application
│
├── prometheus-grafana.yaml         # Legacy single-file (deprecated)
├── README.md                       # This file
├── DEPLOYMENT.md                   # Detailed deployment guide
└── IMPROVEMENTS.md                 # List of improvements made
```

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Alerting](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Kubernetes Service Discovery](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config)
- [Longhorn Documentation](https://longhorn.io/docs/)

## 🔒 Security Considerations

### Current Setup (Homelab)

- Admin credentials in Secret (better than plain text, but still in YAML)
- HTTP access (no TLS)
- Single replica (no high availability)
- Alerts visible only in Prometheus UI

### Production Recommendations

1. **Use generated passwords** stored in external secret management
2. **Enable TLS/SSL** on Ingress with Let's Encrypt
3. **Deploy Alertmanager** for email/Slack/PagerDuty integration
4. **Network Policies** to restrict pod-to-pod communication
5. **Resource Quotas** to prevent resource exhaustion
6. **Regular Backups** of Prometheus and Grafana data
7. **Multi-replica** setup for high availability

## 🧹 Cleanup

To remove everything:

```bash
kubectl delete -f prometheus-grafana.yaml
```

**Warning:** This will delete all metrics and dashboards! The PVCs will be deleted, so data will be lost unless you've backed it up.

To keep data but remove deployments:

```bash
# Delete deployments but keep PVCs
kubectl delete deployment prometheus grafana -n monitoring
kubectl delete svc prometheus grafana -n monitoring
kubectl delete ingress prometheus grafana -n monitoring
kubectl delete prometheusrule home-server-alerts -n monitoring
```

## 📝 License

This configuration is provided as-is for educational and homelab use.
