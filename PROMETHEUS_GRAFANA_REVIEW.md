# Prometheus & Grafana Setup Review

## ✅ What's Good

1. **Auto-Discovery Configuration** - Perfect for GitLab!
   - Your `kubernetes-pods` job will automatically discover GitLab pods with annotations
   - No manual configuration needed

2. **RBAC Setup** - Correctly configured
   - ServiceAccount, ClusterRole, and ClusterRoleBinding are properly set up
   - Prometheus has the right permissions to discover pods/services

3. **Scrape Configs** - Well configured
   - Kubernetes API servers
   - Kubernetes nodes
   - Kubernetes pods (with annotation-based discovery)
   - Longhorn
   - CoreDNS

4. **Resource Limits** - Reasonable for homelab
   - Prometheus: 250m-1000m CPU, 512Mi-2Gi memory
   - Grafana: 100m-500m CPU, 256Mi-1Gi memory

5. **Ingress** - Properly configured with nip.io

## ⚠️ Issues & Recommendations

### 1. **Storage - Data Loss Risk** (Important!)

**Current:**
```yaml
volumes:
  - name: storage
    emptyDir: {}
```

**Problem:** Both Prometheus and Grafana use `emptyDir`, which means:
- **Prometheus**: All metrics history lost when pod restarts
- **Grafana**: All dashboards, datasources, and configs lost when pod restarts

**Recommendation:** Use PersistentVolumeClaims with Longhorn:

```yaml
# For Prometheus
volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: prometheus-storage

# For Grafana  
volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: grafana-storage
```

**Create PVCs:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 50Gi  # Adjust based on retention needs

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

### 2. **Grafana Admin Password** (Security)

**Current:** Password is in plain text in the YAML file.

**Better:** Use a generated password:
```bash
# Generate secure password
GRAFANA_PASSWORD=$(openssl rand -base64 32)

# Create secret
kubectl create secret generic grafana-admin-secret \
  -n monitoring \
  --from-literal=GF_SECURITY_ADMIN_USER=admin \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_PASSWORD"

# Save password somewhere safe!
echo "Grafana password: $GRAFANA_PASSWORD"
```

### 3. **Prometheus Retention** (Optional)

**Current:** 30 days retention is good for homelab.

**Consider:** If you want longer retention or more control:
```yaml
args:
  - --storage.tsdb.retention.time=30d
  - --storage.tsdb.retention.size=20GB  # Add size limit
```

### 4. **Grafana Datasource** (Missing)

Grafana needs to know about Prometheus. You can either:

**Option A:** Configure via Grafana UI (manual)
- After Grafana is running, go to Configuration > Data Sources
- Add Prometheus: `http://prometheus.monitoring.svc.cluster.local:9090`

**Option B:** Auto-configure via ConfigMap (recommended)

Add this to your setup:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus.monitoring.svc.cluster.local:9090
        isDefault: true
        editable: true
```

Then mount it in Grafana:
```yaml
volumeMounts:
  - name: datasources
    mountPath: /etc/grafana/provisioning/datasources
volumes:
  - name: datasources
    configMap:
      name: grafana-datasources
```

### 5. **Prometheus Service Discovery** (Already Good!)

Your config already has the perfect setup for GitLab:
```yaml
- job_name: kubernetes-pods
  kubernetes_sd_configs: [{role: pod}]
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: "true"
```

This will automatically discover GitLab pods once they have the annotations (which we've configured in `gitlab-values.yaml`).

## ✅ Overall Assessment

**Status:** ✅ **Good for homelab, but needs storage fix**

The setup is solid and will work, but you'll lose data on pod restarts. For a production-like setup, add PVCs.

## Quick Fix Priority

1. **High Priority:** Add PVCs for Prometheus and Grafana (prevents data loss)
2. **Medium Priority:** Auto-configure Grafana datasource
3. **Low Priority:** Use generated password for Grafana

## Testing After GitLab Deployment

Once GitLab is deployed, verify monitoring:

```bash
# 1. Check Prometheus discovered GitLab pods
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090 → Status > Targets
# Should see GitLab pods under "kubernetes-pods"

# 2. Check metrics are being scraped
# In Prometheus UI, try query: up{namespace="gitlab"}

# 3. Check Grafana can query Prometheus
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Visit http://localhost:3000
# Login and test a query in Explore
```

## Summary

Your Prometheus/Grafana setup is **well-configured** and will work great with GitLab! The main improvement needed is adding persistent storage to prevent data loss on restarts.

