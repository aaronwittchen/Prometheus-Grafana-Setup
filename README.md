# Prometheus & Grafana Kubernetes Setup

A complete monitoring stack for Kubernetes, configured for homelab use with automatic service discovery, persistent storage, and built-in alerting.

## 🎯 What This Does

This setup deploys:
- **Prometheus**: Metrics collection, time-series database, and alerting engine
- **Grafana**: Visualization and dashboards
- **Alert Rules**: Pre-configured alerts for CPU, memory, disk, pod restarts, and node health
- **Auto-discovery**: Automatically discovers and monitors Kubernetes pods with Prometheus annotations
- **Persistent Storage**: Data survives pod restarts using Longhorn storage
- **External Access**: Accessible via nip.io domains

## 📋 Prerequisites

- Kubernetes cluster (1.24+)
- NGINX Ingress Controller installed
- Longhorn storage system installed and configured
- `kubectl` configured to access your cluster
- Cluster admin permissions (for RBAC setup)
- Prometheus Operator CRDs (for alert rules)

## 🚀 Quick Start

### 0. Install Prometheus Operator CRDs (Required for Alerts)

```bash
kubectl apply -f https://github.com/prometheus-operator/prometheus-operator/releases/latest/download/bundle.yaml
```

This installs the custom resource definitions needed for PrometheusRule alert configuration.

### 1. Deploy the Stack

```bash
kubectl apply -f prometheus-grafana.yaml
```

### 2. Verify Deployment

```bash
# Check pods are running
kubectl get pods -n monitoring

# Check PVCs are bound
kubectl get pvc -n monitoring

# Check services
kubectl get svc -n monitoring

# Check alert rules are loaded
kubectl get prometheusrule -n monitoring
```

### 3. Access the Services

**Grafana:**
- URL: `http://grafana.192.168.2.207.nip.io`
- Username: `admin`
- Password: `admin`

**Prometheus:**
- URL: `http://prometheus.192.168.2.207.nip.io`

> **Note:** Replace `192.168.2.207` with your actual cluster/node IP address.

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
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"        # Optional, defaults to pod port
  prometheus.io/path: "/metrics"    # Optional, defaults to /metrics
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
    storage: 25Gi  # Change this value
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
  - --storage.tsdb.retention.time=30d  # Change to 60d, 90d, etc.
```

### Alert Configuration

Current alert thresholds (homelab-friendly):

| Alert | Condition | Duration |
|-------|-----------|----------|
| High CPU | CPU > 80% | 5 minutes |
| High Memory | Memory > 85% | 5 minutes |
| Low Disk Space | Free space < 15% | 5 minutes |
| Pod Restarts | Restarts in last 15 minutes | 5 minutes |
| Node Not Ready | Node down | 2 minutes |

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

## 🗂️ File Structure

```
.
├── prometheus-grafana.yaml    # Main deployment manifest with alert rules
├── README.md                   # This file
└── ARCHITECTURE.md            # Detailed architecture explanation
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

## 🤝 Contributing

Feel free to submit issues or improvements! This is a homelab setup, so suggestions are welcome.

---

**Happy Monitoring! 📊**