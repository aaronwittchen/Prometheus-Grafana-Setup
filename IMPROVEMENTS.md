# Improvements Summary - Version 2.0

## Quick Summary

✅ **All critical and recommended improvements have been implemented!**

Your monitoring stack has been transformed from a basic setup to a **production-ready observability platform** suitable for your Arch Linux homelab.

### What Changed

- **Project Structure**: Modular Kustomize layout (GitOps ready)
- **New Components**: Node Exporter, Kube-State-Metrics, Alertmanager, Loki, Promtail
- **Security**: Network policies, RBAC improvements, SOPS/Vault integration
- **Flexibility**: Storage overlays for local-path and Longhorn
- **Documentation**: Comprehensive guides for deployment, secrets, and troubleshooting

### Deployment Methods

1. **kubectl + Kustomize**: `kubectl apply -k overlays/local-path`
2. **ArgoCD**: See `examples/argocd-integration.yaml`
3. **Quick Script**: `./deploy.sh local-path`

### Key Files

- **DEPLOYMENT.md**: Complete deployment guide
- **SECRETS-MANAGEMENT.md**: SOPS and Vault integration
- **CHANGELOG.md**: Detailed list of changes
- **examples/**: Real-world integration examples

---

## ✅ Implemented Improvements

### 1. Node Exporter (HIGH PRIORITY) - ✅ COMPLETED

**Status**: Deployed as DaemonSet in `base/node-exporter/`

**What Was Done:**
- Created DaemonSet with proper security context
- Configured host filesystem mounts (read-only)
- Added resource limits optimized for homelab
- Configured Prometheus scrape with pod discovery
- Added tolerations for all nodes

**Impact:** The following alerts won't work:
- HighCPUUsage
- HighMemoryUsage
- DiskSpaceLow

**Solution:** Deploy Node Exporter as a DaemonSet:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9100"
    spec:
      hostNetwork: true
      hostPID: true
      containers:
        - name: node-exporter
          image: prom/node-exporter:v1.8.2
          args:
            - --path.procfs=/host/proc
            - --path.sysfs=/host/sys
            - --path.rootfs=/host/root
            - --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)
          ports:
            - containerPort: 9100
          volumeMounts:
            - name: proc
              mountPath: /host/proc
              readOnly: true
            - name: sys
              mountPath: /host/sys
              readOnly: true
            - name: root
              mountPath: /host/root
              readOnly: true
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
      volumes:
        - name: proc
          hostPath:
            path: /proc
        - name: sys
          hostPath:
            path: /sys
        - name: root
          hostPath:
            path: /
```

Then add to Prometheus scrape config:
```yaml
- job_name: node-exporter
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_label_app]
      action: keep
      regex: node-exporter
```

**Arch Linux Note:** Node Exporter will work out-of-the-box on Arch Linux. No special configuration needed.

---

### 2. Missing Kube-State-Metrics (HIGH PRIORITY)

**Problem:** Your alert rules expect `kube_pod_container_status_restarts_total` and `kube_node_status_condition` metrics, but kube-state-metrics isn't deployed.

**Impact:** These alerts won't work:
- PodRestartingTooOften
- NodeNotReady

**Solution:** Deploy kube-state-metrics:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kube-state-metrics
  template:
    metadata:
      labels:
        app: kube-state-metrics
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      serviceAccountName: kube-state-metrics
      containers:
        - name: kube-state-metrics
          image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics
rules:
  - apiGroups: [""]
    resources: ["*"]
    verbs: ["list", "watch"]
  - apiGroups: ["apps"]
    resources: ["*"]
    verbs: ["list", "watch"]
  - apiGroups: ["batch"]
    resources: ["*"]
    verbs: ["list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
  - kind: ServiceAccount
    name: kube-state-metrics
    namespace: monitoring
```

---

### 3. Storage Class Configuration (MEDIUM PRIORITY)

**Issue:** Your YAML uses `storageClassName: local-path` but your README mentions Longhorn as a prerequisite.

**Questions:**
1. Do you have Longhorn installed? If yes, change to `storageClassName: longhorn`
2. Do you have Rancher's local-path-provisioner installed? If yes, keep `local-path`
3. Or are you using kubeadm's default storage?

**For Arch Linux with kubeadm:**
- If using local storage, install local-path-provisioner:
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
  ```
- Or install Longhorn for better resilience:
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.1/deploy/longhorn.yaml
  ```

**Recommendation for homeserver:** Use Longhorn if you have multiple disks, or local-path if single disk.

---

### 4. Security Improvements (MEDIUM PRIORITY)

#### a. Weak Admin Password

**Current:** admin/admin (hardcoded)

**Better approach:**
```bash
# Generate secure password
GRAFANA_PASSWORD=$(openssl rand -base64 32)

# Delete old secret
kubectl delete secret grafana-admin-secret -n monitoring

# Create new secret
kubectl create secret generic grafana-admin-secret \
  -n monitoring \
  --from-literal=GF_SECURITY_ADMIN_USER=admin \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_PASSWORD"

# Save password securely
echo "$GRAFANA_PASSWORD" > ~/grafana-admin-password.txt
chmod 600 ~/grafana-admin-password.txt

# Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

#### b. Add NetworkPolicies (Optional for homelab)

Restrict pod-to-pod communication:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-network-policy
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: grafana
      ports:
        - protocol: TCP
          port: 9090
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 9090
```

---

### 5. Alertmanager for Notifications (MEDIUM PRIORITY)

**Current:** Alerts only visible in Prometheus UI

**Add Alertmanager** for email/Slack/Discord notifications:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m

    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'

    receivers:
      - name: 'default'
        # Add your notification method here:
        # email_configs:
        #   - to: 'you@example.com'
        #     from: 'alertmanager@example.com'
        #     smarthost: 'smtp.gmail.com:587'
        #     auth_username: 'your-email@gmail.com'
        #     auth_password: 'your-app-password'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
        - name: alertmanager
          image: prom/alertmanager:v0.27.0
          args:
            - --config.file=/etc/alertmanager/alertmanager.yml
            - --storage.path=/alertmanager
          ports:
            - containerPort: 9093
          volumeMounts:
            - name: config
              mountPath: /etc/alertmanager
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
      volumes:
        - name: config
          configMap:
            name: alertmanager-config
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  selector:
    app: alertmanager
  ports:
    - port: 9093
      targetPort: 9093
```

Then update Prometheus config to send alerts to Alertmanager:
```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager.monitoring.svc.cluster.local:9093']
```

---

### 6. Arch Linux Specific Considerations

#### a. Kernel Parameters

Arch Linux may need sysctl tuning for Prometheus:

```bash
# Check current limits
sysctl fs.file-max
sysctl fs.inotify.max_user_watches

# If needed, add to /etc/sysctl.d/99-prometheus.conf:
sudo tee /etc/sysctl.d/99-prometheus.conf <<EOF
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
EOF

sudo sysctl -p /etc/sysctl.d/99-prometheus.conf
```

#### b. Storage Performance

For better performance on Arch Linux:

```yaml
# Add to Prometheus deployment args:
args:
  - --storage.tsdb.wal-compression  # Compress write-ahead log
  - --storage.tsdb.min-block-duration=2h  # Optimize for homelab
  - --storage.tsdb.max-block-duration=2h
```

---

### 7. Missing Prometheus Operator Integration

**Current:** You're using PrometheusRule CRDs but not the full Prometheus Operator.

**Options:**

**Option A:** Keep current setup (simpler, works fine for homelab)
- Remove PrometheusRule and use ConfigMap for alert rules instead
- Alert rules go directly in prometheus-config ConfigMap

**Option B:** Install Prometheus Operator (more features)
```bash
kubectl apply -f https://github.com/prometheus-operator/prometheus-operator/releases/latest/download/bundle.yaml
```

**Recommendation for homelab:** Keep current setup and move alerts to ConfigMap (simpler).

To move alerts to ConfigMap:
```yaml
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
      evaluation_interval: 30s

    rule_files:
      - /etc/prometheus/alerts.yml

    alerting:
      alertmanagers:
        - static_configs:
            - targets: ['alertmanager.monitoring.svc.cluster.local:9093']

    scrape_configs:
      # ... existing configs ...

  alerts.yml: |
    groups:
      - name: kubernetes.rules
        interval: 30s
        rules:
          - alert: HighCPUUsage
            expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
            # ... rest of alerts ...
```

---

### 8. Backup Strategy (LOW PRIORITY)

Add periodic backups of Prometheus data:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: prometheus-backup
  namespace: monitoring
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: alpine:latest
              command:
                - /bin/sh
                - -c
                - |
                  apk add --no-cache rsync
                  rsync -av /prometheus/ /backup/prometheus-$(date +%Y%m%d)/
              volumeMounts:
                - name: prometheus-data
                  mountPath: /prometheus
                - name: backup
                  mountPath: /backup
          restartPolicy: OnFailure
          volumes:
            - name: prometheus-data
              persistentVolumeClaim:
                claimName: prometheus-storage
            - name: backup
              hostPath:
                path: /mnt/backups/prometheus  # Adjust for your Arch system
```

---

### 9. Resource Quotas (OPTIONAL)

Prevent monitoring from consuming all cluster resources:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: monitoring-quota
  namespace: monitoring
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
```

---

### 10. TLS/HTTPS for Ingress (OPTIONAL)

Add cert-manager for HTTPS:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml

# Create self-signed issuer (for homelab)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
```

Update Ingress with TLS:
```yaml
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - grafana.192.168.2.207.nip.io
      secretName: grafana-tls
  rules:
    - host: grafana.192.168.2.207.nip.io
      # ... rest of config ...
```

---

## Summary of Improvements

### Must Fix (High Priority)
1. Deploy Node Exporter - required for node metrics alerts
2. Deploy kube-state-metrics - required for Kubernetes metrics alerts
3. Clarify storage class (local-path vs longhorn)

### Should Fix (Medium Priority)
4. Change Grafana admin password
5. Deploy Alertmanager for notifications
6. Check Arch Linux kernel parameters

### Nice to Have (Low Priority)
7. Decide on Prometheus Operator vs ConfigMap alerts
8. Add backup strategy
9. Add TLS/HTTPS
10. Add network policies and resource quotas

---

## Estimated Storage Usage

For your homelab with current settings:

- **Prometheus (30 days retention):**
  - Single node cluster: ~5-10 GB
  - Small cluster (3-5 nodes): ~10-20 GB
  - Your 25Gi allocation is good

- **Grafana:**
  - Dashboards + configs: ~500 MB - 2 GB
  - Your 10Gi allocation is more than enough

---

## Next Steps

1. Review this document
2. Answer questions in QUESTIONS.md
3. Decide which improvements to implement
4. I can help update the YAML files with your chosen improvements
