# Changelog

All notable changes to this monitoring stack.

## [2.0.0] - 2024-12-10

### Added - New Components

- **Node Exporter**: DaemonSet for host-level metrics (CPU, memory, disk, network)
- **Kube-State-Metrics**: Deployment for Kubernetes object metrics
- **Alertmanager**: Alert routing and notification management
- **Loki**: Log aggregation system with 31-day retention
- **Promtail**: Log collector DaemonSet running on all nodes
- **Network Policies**: Security policies restricting pod-to-pod communication

### Added - Features

- **Kustomize Structure**: Modular base + overlay architecture for easy customization
- **Storage Overlays**: Easy switching between `local-path` and `longhorn` storage classes
- **Discord Integration**: Alertmanager configured for Discord webhooks
- **SOPS Support**: Encrypted secrets ready for GitOps workflows
- **Vault Integration**: Documentation and examples for HashiCorp Vault
- **ArgoCD Examples**: Complete GitOps integration examples
- **ServiceMonitor Examples**: Templates for monitoring Linkding, GitLab, etc.
- **Comprehensive Alerts**: 10+ alert rules covering:
  - High CPU usage (>80%)
  - High memory usage (>85%)
  - Low disk space (<15%)
  - Pod crash looping
  - Node not ready
  - PV space low
  - High pod memory usage
  - Longhorn volume issues
  - Prometheus targets down

### Changed

- **Alert Rules**: Moved from PrometheusRule CRD to ConfigMap (no operator required)
- **Prometheus Config**: Added scrape configs for:
  - kubernetes-cadvisor (container metrics)
  - node-exporter
  - kube-state-metrics
  - Loki self-monitoring
  - Linkding application example
- **Grafana Datasources**: Added Loki datasource alongside Prometheus
- **Grafana Plugins**: Auto-install useful plugins (clock, piechart, simple-json)
- **Security Context**: All pods now run with security contexts (non-root users)
- **Resource Limits**: Optimized for homelab (4-core, 8GB RAM system)
- **Health Checks**: Added liveness and readiness probes to all deployments
- **Storage Optimization**: Enabled Prometheus WAL compression and block duration tuning

### Fixed

- **Missing Node Metrics**: Node Exporter now provides metrics for CPU/memory/disk alerts
- **Missing Kube Metrics**: Kube-State-Metrics now provides pod/node status metrics
- **Alert Rules Not Working**: Fixed by embedding in ConfigMap instead of CRD
- **Storage Class Hardcoded**: Now configurable via Kustomize overlays
- **No Log Collection**: Added Loki + Promtail stack
- **No Alerting**: Added Alertmanager with Discord support
- **Weak Secrets**: Documented SOPS and Vault integration
- **Single File Deployment**: Restructured into modular Kustomize layout

### Documentation

- **DEPLOYMENT.md**: Comprehensive deployment guide with troubleshooting
- **SECRETS-MANAGEMENT.md**: Complete guide for managing secrets (basic, SOPS, Vault)
- **CHANGELOG.md**: This file
- **Updated README.md**: Reflect new structure and features
- **examples/**: Added real-world integration examples

### Deprecated

- **prometheus-grafana.yaml**: Legacy single-file deployment (kept for reference)

### Technical Details

#### Resource Allocation

**Prometheus:**
- Requests: 250m CPU, 512Mi memory
- Limits: 1000m CPU, 2Gi memory
- Storage: 25Gi (30-day retention with compression)

**Grafana:**
- Requests: 100m CPU, 256Mi memory
- Limits: 500m CPU, 1Gi memory
- Storage: 10Gi

**Node Exporter:**
- Requests: 100m CPU, 128Mi memory
- Limits: 200m CPU, 256Mi memory

**Kube-State-Metrics:**
- Requests: 100m CPU, 128Mi memory
- Limits: 200m CPU, 256Mi memory

**Alertmanager:**
- Requests: 50m CPU, 64Mi memory
- Limits: 100m CPU, 128Mi memory

**Loki:**
- Requests: 200m CPU, 256Mi memory
- Limits: 500m CPU, 512Mi memory
- Storage: 20Gi (31-day retention)

**Promtail:**
- Requests: 50m CPU, 64Mi memory
- Limits: 200m CPU, 128Mi memory

**Total Resource Requirements:**
- CPU: ~900m requests, ~2.5 cores limits
- Memory: ~1.5Gi requests, ~5Gi limits
- Storage: ~55Gi total

#### Network Policies

- Prometheus: Can scrape all pods, send to Alertmanager
- Grafana: Can query Prometheus and Loki only
- Loki: Accept logs from Promtail, queries from Grafana
- Alertmanager: Can send external webhooks (Discord)
- All pods: Can access CoreDNS for name resolution

#### Security Improvements

1. Non-root containers with explicit UIDs
2. Read-only root filesystems where possible
3. Network policies limiting pod communication
4. RBAC with least-privilege service accounts
5. Secrets encrypted with SOPS/Vault (optional)
6. No privileged containers (except Node Exporter for host metrics)

---

## [1.0.0] - Previous Version

### Initial Release

- Basic Prometheus deployment
- Basic Grafana deployment
- Simple RBAC configuration
- Alert rules using PrometheusRule CRD
- Single YAML file deployment
- Hardcoded local-path storage
- No log aggregation
- No Alertmanager
- Missing essential exporters

---

## Migration from 1.0 to 2.0

### Breaking Changes

1. **Alert Rules Format**: PrometheusRule CRD → ConfigMap
2. **File Structure**: Single file → Kustomize base + overlays
3. **Storage Class**: Hardcoded → Overlay-based

### Migration Steps

```bash
# 1. Backup existing deployment
kubectl get all -n monitoring -o yaml > backup-v1.yaml

# 2. Export PVC data (if you want to keep metrics)
# ... (see DEPLOYMENT.md for backup procedures)

# 3. Delete old deployment
kubectl delete -f prometheus-grafana.yaml

# 4. Deploy v2.0
kubectl apply -k overlays/local-path

# 5. Verify
kubectl get pods -n monitoring
```

### Notes

- PVCs with same name will be reused (Prometheus and Grafana data preserved)
- New components will start fresh (Node Exporter, Loki, etc.)
- Update Grafana dashboards to use new metrics from exporters
- Configure Discord webhook in Alertmanager if desired

---

## Future Plans

### Planned for 2.1

- [ ] Helm chart alternative
- [ ] Tempo integration for distributed tracing
- [ ] Jaeger as alternative to Tempo
- [ ] Pre-built Grafana dashboards as ConfigMaps
- [ ] Backup CronJob examples
- [ ] TLS/HTTPS setup guide
- [ ] Multi-tenancy examples
- [ ] OAuth2 Proxy integration
- [ ] Kyverno policies for compliance
- [ ] OPA policies for RBAC

### Planned for 3.0

- [ ] High Availability setup (3-replica Prometheus)
- [ ] Thanos for long-term storage
- [ ] Remote write to Prometheus instances
- [ ] Grafana alerting rules migration
- [ ] Full Observability pipeline (metrics + logs + traces)
- [ ] Service mesh integration (Istio/Linkerd)
- [ ] Cost monitoring and optimization

---

## Support

- **Issues**: Report bugs or request features in the repository
- **Documentation**: See README.md and DEPLOYMENT.md
- **Examples**: Check examples/ directory for common use cases
