# Prometheus & Grafana Kubernetes Architecture - Deep Dive

This document provides a comprehensive, line-by-line explanation of the `prometheus-grafana.yaml` configuration file, explaining not just what each component does, but why it's structured the way it is and how the YAML syntax works.

## Table of Contents

1. [Namespace](#1-namespace)
2. [Grafana Admin Secret](#2-grafana-admin-secret)
3. [Prometheus Configuration (ConfigMap)](#3-prometheus-configuration-configmap)
4. [RBAC Components](#4-rbac-components)
5. [PersistentVolumeClaims](#5-persistentvolumeclaims)
6. [Grafana Datasources ConfigMap](#6-grafana-datasources-configmap)
7. [PrometheusRule (Alert Rules)](#7-prometheusrule-alert-rules)
8. [Prometheus Deployment](#8-prometheus-deployment)
9. [Prometheus Service](#9-prometheus-service)
10. [Grafana Deployment](#10-grafana-deployment)
11. [Grafana Service](#11-grafana-service)
12. [Ingress Resources](#12-ingress-resources)

---

## 1. Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
```

### Line-by-Line Explanation

- **`apiVersion: v1`**: Specifies the Kubernetes API version. `v1` is the stable API for core resources like Namespaces. This tells Kubernetes which API schema to use when parsing this resource.

- **`kind: Namespace`**: Defines the type of Kubernetes resource. A Namespace provides logical isolation and grouping of resources. Think of it as a virtual cluster within your physical cluster.

- **`metadata:`**: Contains identifying information about the resource. All Kubernetes resources have metadata.

- **`name: monitoring`**: The unique identifier for this namespace. All resources in this namespace will be referenced as `resource-name.monitoring` or `resource-name` within the namespace context.

### Why This Structure?

Namespaces allow you to:
- **Isolate resources**: Resources in different namespaces can have the same name
- **Apply policies**: Network policies, resource quotas, and RBAC can be namespace-scoped
- **Organize logically**: Group related resources together (all monitoring tools in `monitoring` namespace)

### The `---` Separator

The `---` (three dashes) is a YAML document separator. It allows multiple Kubernetes resources to be defined in a single file. Each resource between `---` markers is treated as a separate document that can be applied independently.

---

## 2. Grafana Admin Secret

```yaml
---
# Grafana admin credentials
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin-secret
  namespace: monitoring
type: Opaque
stringData:
  GF_SECURITY_ADMIN_USER: admin
  GF_SECURITY_ADMIN_PASSWORD: admin
```

### Line-by-Line Explanation

- **`apiVersion: v1`**: Core API version for Secret resources.

- **`kind: Secret`**: A Secret is a Kubernetes object for storing sensitive data like passwords, tokens, or keys. Secrets are base64-encoded when stored in etcd.

- **`metadata.name: grafana-admin-secret`**: The name of the Secret. This will be referenced later in the Grafana deployment.

- **`metadata.namespace: monitoring`**: Places this Secret in the `monitoring` namespace, making it accessible to pods in that namespace.

- **`type: Opaque`**: The Secret type. `Opaque` means Kubernetes doesn't interpret the data - it's just a key-value store. Other types like `kubernetes.io/tls` or `kubernetes.io/dockerconfigjson` have special handling.

- **`stringData:`**: A field that allows you to provide plain-text values. Kubernetes automatically base64-encodes these when storing. This is more convenient than manually base64-encoding values in the `data:` field.

  - **`GF_SECURITY_ADMIN_USER: admin`**: Grafana environment variable name. Grafana reads `GF_SECURITY_*` environment variables for configuration. This sets the admin username.

  - **`GF_SECURITY_ADMIN_PASSWORD: admin`**: Sets the admin password. In production, this should be a strong, randomly generated password.

### Why Use Secrets Instead of Plain Text?

1. **Security**: Secrets are base64-encoded (not encrypted, but obfuscated)
2. **RBAC**: You can control who can read Secrets via RBAC
3. **Best Practice**: Separates sensitive data from application code
4. **Flexibility**: Can be updated without redeploying the application

### How Grafana Uses This

The Grafana deployment will reference this Secret using `valueFrom.secretKeyRef`, which we'll see in the Grafana Deployment section.

---

## 3. Prometheus Configuration (ConfigMap)

```yaml
---
# Prometheus ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
      evaluation_interval: 30s

    scrape_configs:
      - job_name: kubernetes-apiservers
        kubernetes_sd_configs: [{role: endpoints}]
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https
      # ... more jobs
```

### ConfigMap Structure

- **`kind: ConfigMap`**: Stores non-sensitive configuration data as key-value pairs. Unlike Secrets, ConfigMaps are not encoded.

- **`data:`**: The main field containing configuration data. Each key becomes a filename when mounted as a volume.

- **`prometheus.yml:`**: The key name. When this ConfigMap is mounted, this becomes the filename `prometheus.yml`.

- **`|` (Literal Block Scalar)**: The pipe character in YAML creates a literal block scalar, preserving newlines and formatting. This allows multi-line configuration files to be embedded in YAML.

### Prometheus Configuration Deep Dive

#### Global Settings

```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 30s
```

- **`scrape_interval: 30s`**: Default interval for scraping metrics from targets. Prometheus will query each target every 30 seconds. This is homelab-optimized to reduce disk churn while maintaining reasonable data freshness.

- **`evaluation_interval: 30s`**: How often Prometheus evaluates alerting rules. Alert rules are checked every 30 seconds, matching the scrape interval for consistency.

#### Scrape Job: kubernetes-apiservers

```yaml
- job_name: kubernetes-apiservers
  kubernetes_sd_configs: [{role: endpoints}]
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  relabel_configs:
    - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
      action: keep
      regex: default;kubernetes;https
```

**Line-by-Line:**

- **`job_name: kubernetes-apiservers`**: A unique identifier for this scrape job. Appears in Prometheus UI and metrics.

- **`kubernetes_sd_configs: [{role: endpoints}]`**: Enables Kubernetes service discovery. The `role: endpoints` tells Prometheus to discover Kubernetes Endpoints resources.

  - **Service Discovery**: Instead of manually listing targets, Prometheus queries the Kubernetes API to find what to scrape.
  - **`[{role: endpoints}]`**: The square brackets indicate an array. The curly braces define an object with a `role` property.

- **`scheme: https`**: Use HTTPS for scraping. The Kubernetes API server only accepts HTTPS connections.

- **`tls_config:`**: TLS/SSL configuration for secure connections.

  - **`ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt`**: Path to the CA certificate. Kubernetes automatically mounts service account certificates here. This cert validates the API server's identity.

- **`bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token`**: Path to the authentication token. Kubernetes mounts the service account token here. Prometheus uses this to authenticate API requests.

- **`relabel_configs:`**: Relabeling allows you to filter and transform discovered targets before scraping.

  - **`source_labels: [...]`**: Extract values from these labels and concatenate them with `;` separator.
    - `__meta_kubernetes_namespace`: The namespace of the discovered endpoint
    - `__meta_kubernetes_service_name`: The service name
    - `__meta_kubernetes_endpoint_port_name`: The port name

  - **`action: keep`**: Only keep targets that match the regex. Discard others.

  - **`regex: default;kubernetes;https`**: Match endpoints where:
    - Namespace = `default`
    - Service name = `kubernetes` (the API server service)
    - Port name = `https`

**Result**: Only the Kubernetes API server endpoint is scraped, not all endpoints in the cluster.

#### Scrape Job: kubernetes-nodes

```yaml
- job_name: kubernetes-nodes
  kubernetes_sd_configs: [{role: node}]
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
```

**Key Differences:**

- **`role: node`**: Discovers Kubernetes Node resources instead of endpoints.

- **`action: labelmap`**: Maps (copies) labels matching the regex to new label names.

- **`regex: __meta_kubernetes_node_label_(.+)`**: 
  - Matches labels like `__meta_kubernetes_node_label_kubernetes_io_arch`
  - The `(.+)` captures everything after the prefix
  - Creates new labels like `kubernetes_io_arch: amd64`

**Result**: All node labels (like `kubernetes.io/arch`, `kubernetes.io/os`) are copied to Prometheus metrics, making it easy to filter by node attributes.

#### Scrape Job: kubernetes-pods (The Important One!)

```yaml
- job_name: kubernetes-pods
  kubernetes_sd_configs: [{role: pod}]
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: "true"
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
      action: replace
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace
      target_label: __address__
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: $1:$2
    - action: labelmap
      regex: __meta_kubernetes_pod_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
      action: replace
      target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_pod_name]
      action: replace
      target_label: kubernetes_pod_name
```

**This is the auto-discovery magic!** Let's break it down:

1. **Discovery**: `role: pod` discovers all pods in the cluster.

2. **Filter by Annotation**:
   ```yaml
   - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
     action: keep
     regex: "true"
   ```
   - Only keeps pods with annotation `prometheus.io/scrape: "true"`
   - This is how GitLab (or any app) opts into monitoring

3. **Custom Metrics Path**:
   ```yaml
   - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
     action: replace
     target_label: __metrics_path__
     regex: (.+)
   ```
   - If pod has `prometheus.io/path: "/custom/metrics"`, use that path
   - `__metrics_path__` is a special Prometheus variable for the HTTP path
   - `(.+)` captures any value (the path)

4. **Custom Port**:
   ```yaml
   - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
     action: replace
     target_label: __address__
     regex: ([^:]+)(?::\d+)?;(\d+)
     replacement: $1:$2
   ```
   - **Complex regex breakdown**:
     - `([^:]+)`: Captures IP/hostname (everything except `:`)
     - `(?::\d+)?`: Optionally matches existing port (`:9090`)
     - `;`: Separator between source_labels
     - `(\d+)`: Captures the port from annotation
     - `replacement: $1:$2`: Replaces with `IP:PORT`
   - Example: `10.244.1.5:8080` + annotation `9090` → `10.244.1.5:9090`

5. **Copy Pod Labels**:
   ```yaml
   - action: labelmap
     regex: __meta_kubernetes_pod_label_(.+)
   ```
   - Copies all pod labels to metrics (e.g., `app: gitlab` → metric label `app: gitlab`)

6. **Add Namespace Label**:
   ```yaml
   - source_labels: [__meta_kubernetes_namespace]
     action: replace
     target_label: kubernetes_namespace
   ```
   - Adds `kubernetes_namespace: gitlab` to all metrics from that namespace

7. **Add Pod Name Label**:
   ```yaml
   - source_labels: [__meta_kubernetes_pod_name]
     action: replace
     target_label: kubernetes_pod_name
   ```
   - Adds `kubernetes_pod_name: gitlab-0` to identify the specific pod

**Result**: Any pod with `prometheus.io/scrape: "true"` is automatically discovered and scraped, with proper labels for filtering and grouping!

#### Static Scrape Jobs

```yaml
- job_name: longhorn
  static_configs:
    - targets: ['longhorn-backend.longhorn-system:9500']

- job_name: coredns
  static_configs:
    - targets: ['coredns.kube-system:9153']
```

- **`static_configs:`**: For targets that don't change or aren't discovered via service discovery.
- **`targets:`**: Array of `host:port` strings.
- **DNS Resolution**: Kubernetes DNS resolves service names like `longhorn-backend.longhorn-system` to the actual pod IPs.

---

## 4. RBAC Components

### ServiceAccount

```yaml
---
# Prometheus ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
```

**Explanation:**

- **`kind: ServiceAccount`**: Provides an identity for pods. When a pod runs, it's associated with a ServiceAccount (or the `default` ServiceAccount).

- **`name: prometheus`**: This ServiceAccount will be referenced in the Prometheus deployment.

**Why Needed**: Prometheus needs to authenticate with the Kubernetes API to perform service discovery. The ServiceAccount provides the identity, and the ClusterRole (next) provides the permissions.

### ClusterRole

```yaml
---
# Prometheus ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
  - apiGroups: ['']
    resources: [nodes, nodes/proxy, services, endpoints, pods]
    verbs: [get, list, watch]
  - apiGroups: [extensions, networking.k8s.io]
    resources: [ingresses]
    verbs: [get, list, watch]
  - apiGroups: [monitoring.coreos.com]
    resources: [prometheusrules]
    verbs: [get, list, watch]
```

**Line-by-Line:**

- **`apiVersion: rbac.authorization.k8s.io/v1`**: RBAC (Role-Based Access Control) API version.

- **`kind: ClusterRole`**: A role that applies cluster-wide (not namespace-scoped). Use `ClusterRole` when you need to access resources across all namespaces.

- **`rules:`**: Array of permission rules.

- **First Rule**:
  ```yaml
  - apiGroups: ['']
    resources: [nodes, nodes/proxy, services, endpoints, pods]
    verbs: [get, list, watch]
  ```
  - **`apiGroups: ['']`**: Empty string means the "core" API group (v1 resources like Pods, Services).
  - **`resources:`**: What resources can be accessed:
    - `nodes`: Read node information
    - `nodes/proxy`: Access node proxy endpoints (for scraping node metrics)
    - `services`: List services (for service discovery)
    - `endpoints`: List endpoints (for endpoint discovery)
    - `pods`: List pods (for pod discovery)
  - **`verbs:`**: What actions are allowed:
    - `get`: Read a specific resource
    - `list`: List all resources
    - `watch`: Stream real-time updates (essential for service discovery)

- **Second Rule**:
  ```yaml
  - apiGroups: [extensions, networking.k8s.io]
    resources: [ingresses]
    verbs: [get, list, watch]
  ```
  - Allows reading Ingress resources (useful for discovering ingress endpoints)

- **Third Rule** (NEW for alert rules):
  ```yaml
  - apiGroups: [monitoring.coreos.com]
    resources: [prometheusrules]
    verbs: [get, list, watch]
  ```
  - Allows Prometheus to read PrometheusRule custom resources
  - Required for alert rules to be discovered and loaded

**Why ClusterRole vs Role?** Prometheus needs to discover pods in ALL namespaces (not just `monitoring`), so it needs cluster-wide permissions.

### ClusterRoleBinding

```yaml
---
# Prometheus ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
```

**Line-by-Line:**

- **`kind: ClusterRoleBinding`**: Links a ClusterRole to subjects (users, groups, or ServiceAccounts).

- **`roleRef:`**: References the role to bind.
  - **`apiGroup:`**: The API group of the role
  - **`kind: ClusterRole`**: The type of role
  - **`name: prometheus`**: The name of the ClusterRole defined above

- **`subjects:`**: Who gets the permissions.
  - **`kind: ServiceAccount`**: Binding to a ServiceAccount (not a user)
  - **`name: prometheus`**: The ServiceAccount name
  - **`namespace: monitoring`**: The namespace where the ServiceAccount exists

**Result**: The `prometheus` ServiceAccount in the `monitoring` namespace now has all the permissions defined in the `prometheus` ClusterRole.

---

## 5. PersistentVolumeClaims

### Prometheus PVC

```yaml
---
# Prometheus PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 25Gi
```

**Line-by-Line:**

- **`kind: PersistentVolumeClaim`**: A request for storage. The PVC asks Kubernetes for persistent storage, and the storage system provisions it.

- **`spec.accessModes:`**: How the volume can be accessed.
  - **`ReadWriteOnce`**: Can be mounted as read-write by a single node. This is the most common mode.
  - Other modes: `ReadOnlyMany`, `ReadWriteMany` (for shared storage)

- **`storageClassName: local-path`**: Tells Kubernetes to use the local-path storage provisioner. For homelab use with single-node clusters, local-path provides simple, reliable storage.

- **`resources.requests.storage: 25Gi`**: Requests 25 gibibytes of storage. This is optimized for homelab use with 30-day retention and reduced disk churn from the 30-second scrape interval.

**Why 25Gi for homelab?**
- Smaller than production (which might need 50-100Gi)
- Still provides 30-day retention
- Reduces disk space usage
- Adequate for monitoring a small homelab cluster

### Grafana PVC

```yaml
---
# Grafana PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
```

**Similar structure**, but 10Gi is sufficient for Grafana's dashboards, datasources, users, and session data.

**Why PVCs Instead of emptyDir?**
- **Persistence**: Data survives pod restarts, node reboots, and pod rescheduling
- **Production-Ready**: Essential for any real deployment
- **Data Safety**: Metrics and dashboards aren't lost

---

## 6. Grafana Datasources ConfigMap

```yaml
---
# Grafana Datasources ConfigMap
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

**Line-by-Line:**

- **`data.prometheus.yaml:`**: The filename Grafana expects. Grafana looks in `/etc/grafana/provisioning/datasources/` for YAML files.

- **`apiVersion: 1`**: Grafana's datasource provisioning API version.

- **`datasources:`**: Array of datasource definitions.

  - **`name: Prometheus`**: Display name in Grafana UI.

  - **`type: prometheus`**: Tells Grafana this is a Prometheus datasource.

  - **`access: proxy`**: Grafana proxies requests to Prometheus (more secure than `direct`).

  - **`url: http://prometheus.monitoring.svc.cluster.local:9090`**: 
    - **Kubernetes DNS format**: `service-name.namespace.svc.cluster.local`
    - Resolves to the Prometheus service within the cluster
    - Port 9090 is Prometheus's default port

  - **`isDefault: true`**: Makes this the default datasource for new panels.

  - **`editable: true`**: Allows users to modify it in the UI (useful for testing).

**Why Auto-Provision?**
- No manual configuration after deployment
- Consistent across environments
- Version controlled
- Prevents "forgot to add datasource" mistakes

---

## 7. PrometheusRule (Alert Rules)

```yaml
---
# PrometheusRule for alerts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: home-server-alerts
  namespace: monitoring
spec:
  groups:
    - name: kubernetes.rules
      interval: 30s
      rules:
        - alert: HighCPUUsage
          expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High CPU usage detected on {{ $labels.instance }}"
            description: "CPU usage is {{ $value }}% on {{ $labels.instance }}"

        - alert: HighMemoryUsage
          expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High memory usage detected on {{ $labels.instance }}"
            description: "Memory usage is {{ $value }}% on {{ $labels.instance }}"

        - alert: DiskSpaceLow
          expr: (node_filesystem_avail_bytes{fstype!~"tmpfs"} / node_filesystem_size_bytes) * 100 < 15
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Low disk space on {{ $labels.instance }}"
            description: "Disk {{ $labels.device }} has only {{ $value }}% available"

        - alert: PodRestartingTooOften
          expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} restarting frequently"
            description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting"

        - alert: NodeNotReady
          expr: kube_node_status_condition{condition="Ready",status="true"} == 0
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "Node {{ $labels.node }} is not ready"
            description: "Node {{ $labels.node }} has been unready for more than 2 minutes"
```

### PrometheusRule Structure

**NEW COMPONENT** (not in original version)

- **`apiVersion: monitoring.coreos.com/v1`**: Custom resource from Prometheus Operator. Requires CRDs to be installed.

- **`kind: PrometheusRule`**: Defines alert rules and recording rules for Prometheus.

- **`metadata.name: home-server-alerts`**: Unique identifier for this rule group.

### Alert Rule Anatomy

Each alert rule has:

- **`alert: HighCPUUsage`**: Alert name. Appears in Prometheus UI and alerting systems.

- **`expr:`**: PromQL expression evaluated against metrics. If the expression returns any time series, the alert fires.

  - **HighCPUUsage**:
    ```promql
    (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
    ```
    - `irate(node_cpu_seconds_total{mode="idle"}[5m])`: CPU idle percentage over 5 minutes
    - `(100 - ...)`: Convert idle to busy percentage
    - `> 80`: Fire if busy > 80%

  - **HighMemoryUsage**:
    ```promql
    (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
    ```
    - Calculates memory usage percentage
    - Fires if > 85%

  - **DiskSpaceLow**:
    ```promql
    (node_filesystem_avail_bytes{fstype!~"tmpfs"} / node_filesystem_size_bytes) * 100 < 15
    ```
    - Calculates available disk percentage (excluding tmpfs)
    - Fires if < 15%

  - **PodRestartingTooOften**:
    ```promql
    rate(kube_pod_container_status_restarts_total[15m]) > 0
    ```
    - Rate of container restarts over 15 minutes
    - Fires if any restarts detected

  - **NodeNotReady**:
    ```promql
    kube_node_status_condition{condition="Ready",status="true"} == 0
    ```
    - Checks if node Ready status is false (0)
    - Fires if any node is not ready

- **`for: 5m`**: Alert only fires if the condition is true for at least 5 minutes. Prevents flapping from brief spikes.

- **`labels:`**: Custom labels attached to the alert. `severity: warning` helps categorize alerts.

- **`annotations:`**: Human-readable information.

  - **`summary:`**: Short description. Uses `{{ $labels.instance }}` to inject metric label values.

  - **`description:`**: Detailed explanation. Uses `{{ $value }}` for the metric value.

### Why PrometheusRule?

1. **Declarative**: Rules defined in YAML, version controlled
2. **Automatic Discovery**: Prometheus automatically watches for PrometheusRule resources
3. **Hot Reload**: Rules can be updated without restarting Prometheus
4. **Organization**: Keeps alerts with Prometheus configuration

### Homelab Alert Thresholds

These thresholds are tuned for homelab use:

| Alert | Threshold | Reasoning |
|-------|-----------|-----------|
| HighCPUUsage | > 80% | Homelabs often run efficiently, 80% is a good warning threshold |
| HighMemoryUsage | > 85% | Similar to CPU, leaves buffer before OOM |
| DiskSpaceLow | < 15% | Homelab storage is usually limited, warn early |
| PodRestartingTooOften | > 0 restarts in 15m | Any restart is worth investigating in a homelab |
| NodeNotReady | Immediate | Critical: node down means cluster problems |

---

## 8. Prometheus Deployment

```yaml
---
# Prometheus Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
        - name: prometheus
          image: prom/prometheus:v2.54.1
          args:
            - --config.file=/etc/prometheus/prometheus.yml
            - --storage.tsdb.path=/prometheus
            - --storage.tsdb.retention.time=30d
            - --web.enable-lifecycle
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus
            - name: storage
              mountPath: /prometheus
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 2Gi
          livenessProbe:
            httpGet:
              path: /-/healthy
              port: 9090
            initialDelaySeconds: 30
            timeoutSeconds: 30
      volumes:
        - name: config
          configMap:
            name: prometheus-config
        - name: storage
          persistentVolumeClaim:
            claimName: prometheus-storage
```

### Deployment Structure

- **`apiVersion: apps/v1`**: Apps API for Deployments (not core v1).

- **`kind: Deployment`**: Manages a set of identical pods. Provides rolling updates, rollbacks, and scaling.

- **`spec.replicas: 1`**: Run 1 pod. For high availability, increase this (but you'd need shared storage).

- **`spec.selector.matchLabels:`**: Labels used to find pods managed by this deployment. Must match `template.metadata.labels`.

- **`spec.template:`**: The pod template. This is what gets created.

### Pod Template

- **`spec.template.metadata.labels:`**: Labels applied to created pods. Used by Services to route traffic.

- **`spec.template.spec.serviceAccountName: prometheus`**: Associates the pod with the ServiceAccount, giving it the RBAC permissions.

### Container Specification

- **`containers:`**: Array of containers in the pod.

- **`name: prometheus`**: Container name (useful for logs: `kubectl logs prometheus-prometheus-xxx -c prometheus`).

- **`image: prom/prometheus:v2.54.1`**: 
  - Official Prometheus image
  - Version pinned for reproducibility
  - `v2.54.1` is a specific stable version

- **`args:`**: Command-line arguments passed to Prometheus.

  - **`--config.file=/etc/prometheus/prometheus.yml`**: Path to config file (mounted from ConfigMap).

  - **`--storage.tsdb.path=/prometheus`**: Where Prometheus stores its time-series database (mounted from PVC).

  - **`--storage.tsdb.retention.time=30d`**: Keep metrics for 30 days. After 30 days, old data is deleted.

  - **`--web.enable-lifecycle`**: Enables the `/-/reload` HTTP endpoint. You can reload config without restarting: `curl -X POST http://prometheus:9090/-/reload`

- **`ports:`**: Exposed container ports.

  - **`containerPort: 9090`**: Prometheus's default HTTP port. This is informational; Kubernetes doesn't automatically open this port.

### Volume Mounts

- **`volumeMounts:`**: Mounts volumes into the container filesystem.

  - **`name: config`**: References a volume named `config` (defined in `volumes:` section).
  - **`mountPath: /etc/prometheus`**: Mounts the volume at this path. The ConfigMap's `prometheus.yml` file appears here.

  - **`name: storage`**: References the PVC volume.
  - **`mountPath: /prometheus`**: Where Prometheus writes its database.

### Resources

- **`resources.requests:`**: Minimum resources guaranteed to the pod. Kubernetes scheduler uses this to place the pod on a node with sufficient resources.

  - **`cpu: 250m`**: 250 millicores = 0.25 CPU cores. Guaranteed CPU time.

  - **`memory: 512Mi`**: 512 mebibytes guaranteed memory.

- **`resources.limits:`**: Maximum resources the pod can use. If exceeded, the pod may be throttled (CPU) or killed (memory).

  - **`cpu: 1000m`**: 1 full CPU core maximum.

  - **`memory: 2Gi`**: 2 gibibytes maximum memory.

**Why Both?** Requests ensure the pod gets resources. Limits prevent resource exhaustion on the node.

### Liveness Probe

```yaml
livenessProbe:
  httpGet:
    path: /-/healthy
    port: 9090
  initialDelaySeconds: 30
  timeoutSeconds: 30
```

- **`livenessProbe:`**: Kubernetes periodically checks if the container is alive.

- **`httpGet:`**: Use HTTP GET request for health check.

  - **`path: /-/healthy`**: Prometheus health endpoint. Returns 200 if healthy.

  - **`port: 9090`**: Port to check.

- **`initialDelaySeconds: 30`**: Wait 30 seconds after container starts before first check (gives Prometheus time to initialize).

- **`timeoutSeconds: 30`**: If no response in 30 seconds, consider it failed.

**If probe fails**: Kubernetes restarts the container.

### Volumes

- **`volumes:`**: Defines volumes available to the pod.

  - **`name: config`**: Volume name (referenced in `volumeMounts`).

  - **`configMap.name: prometheus-config`**: Mounts the ConfigMap as a volume. Files in the ConfigMap's `data:` section become files in the mounted directory.

  - **`name: storage`**: Volume name for persistent storage.

  - **`persistentVolumeClaim.claimName: prometheus-storage`**: Mounts the PVC. The storage provisioner provides the actual storage.

---

## 9. Prometheus Service

```yaml
---
# Prometheus Service
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: ClusterIP
  selector:
    app: prometheus
  ports:
    - port: 9090
      targetPort: 9090
```

**Line-by-Line:**

- **`kind: Service`**: Provides a stable network endpoint for pods. Services have a stable IP and DNS name.

- **`spec.type: ClusterIP`**: Service type. `ClusterIP` means the service is only accessible within the cluster.

  - Other types: `NodePort` (expose on node IP), `LoadBalancer` (cloud load balancer), `ExternalName` (DNS alias).

- **`spec.selector.app: prometheus`**: Selects pods with label `app: prometheus`. Traffic to this service is routed to these pods.

- **`spec.ports:`**: Port mapping.

  - **`port: 9090`**: Port exposed by the service (other services connect to `prometheus:9090`).

  - **`targetPort: 9090`**: Port on the pod containers (where Prometheus is listening).

**How It Works:**
1. Service gets a stable IP (e.g., `10.96.1.2`)
2. Kubernetes DNS creates `prometheus.monitoring.svc.cluster.local` → Service IP
3. Traffic to the service is load-balanced to pods matching the selector
4. Grafana connects to `http://prometheus.monitoring.svc.cluster.local:9090`

---

## 10. Grafana Deployment

```yaml
---
# Grafana Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
        - name: grafana
          image: grafana/grafana:11.2.0
          ports:
            - containerPort: 3000
          env:
            - name: GF_SECURITY_ADMIN_USER
              valueFrom:
                secretKeyRef:
                  name: grafana-admin-secret
                  key: GF_SECURITY_ADMIN_USER
            - name: GF_SECURITY_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: grafana-admin-secret
                  key: GF_SECURITY_ADMIN_PASSWORD
          volumeMounts:
            - name: storage
              mountPath: /var/lib/grafana
            - name: datasources
              mountPath: /etc/grafana/provisioning/datasources
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 1Gi
          livenessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 60
      volumes:
        - name: storage
          persistentVolumeClaim:
            claimName: grafana-storage
        - name: datasources
          configMap:
            name: grafana-datasources
```

### Key Differences from Prometheus

- **No ServiceAccount**: Grafana doesn't need Kubernetes API access.

- **Environment Variables from Secret**:
  ```yaml
  env:
    - name: GF_SECURITY_ADMIN_USER
      valueFrom:
        secretKeyRef:
          name: grafana-admin-secret
          key: GF_SECURITY_ADMIN_USER
  ```
  - **`valueFrom.secretKeyRef:`**: References a value from a Secret.
  - **`name: grafana-admin-secret`**: The Secret name.
  - **`key: GF_SECURITY_ADMIN_USER`**: The key in the Secret's `stringData` or `data`.

  Grafana reads these environment variables at startup to configure the admin user.

- **Two Volume Mounts**:
  - **`/var/lib/grafana`**: Grafana's data directory (dashboards, users, SQLite DB). Uses PVC for persistence.
  - **`/etc/grafana/provisioning/datasources`**: Auto-provisioning directory. Grafana reads YAML files here to configure datasources.

- **Datasources Volume**:
  ```yaml
  - name: datasources
    configMap:
      name: grafana-datasources
  ```
  Mounts the ConfigMap. The `prometheus.yaml` file becomes `/etc/grafana/provisioning/datasources/prometheus.yaml`, which Grafana automatically reads.

- **Liveness Probe**: Uses `/api/health` endpoint (Grafana's health check).

---

## 11. Grafana Service

```yaml
---
# Grafana Service
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: ClusterIP
  selector:
    app: grafana
  ports:
    - port: 3000
      targetPort: 3000
```

**Same structure as Prometheus Service**, but:
- Port 3000 (Grafana's default port)
- Selects pods with `app: grafana` label

---

## 12. Ingress Resources

### Grafana Ingress

```yaml
---
# Grafana Ingress with nip.io
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
    - host: grafana.192.168.2.207.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 3000
```

**Line-by-Line:**

- **`apiVersion: networking.k8s.io/v1`**: Networking API (Ingress is not in core v1).

- **`kind: Ingress`**: Manages external HTTP/HTTPS access to services. Works with an Ingress Controller (like NGINX).

- **`spec.ingressClassName: nginx`**: Tells Kubernetes to use the NGINX Ingress Controller. The controller watches for Ingress resources with this class.

- **`spec.rules:`**: Array of routing rules.

  - **`host: grafana.192.168.2.207.nip.io`**: 
    - **nip.io**: A DNS service that resolves `*.IP.nip.io` to that IP
    - `grafana.192.168.2.207.nip.io` resolves to `192.168.2.207`
    - Perfect for homelab (no DNS configuration needed)

  - **`http.paths:`**: URL paths to match.

    - **`path: /`**: Matches all paths starting with `/`.

    - **`pathType: Prefix`**: Path matching type.
      - `Prefix`: Matches paths starting with the value
      - `Exact`: Exact match
      - `ImplementationSpecific`: Controller-specific behavior

    - **`backend.service:`**: Where to route traffic.

      - **`name: grafana`**: Service name (must exist in the same namespace).

      - **`port.number: 3000`**: Service port.

**How It Works:**
1. User visits `http://grafana.192.168.2.207.nip.io`
2. DNS resolves to `192.168.2.207` (your node IP)
3. NGINX Ingress Controller intercepts the request
4. Matches the `host` and `path` rules
5. Routes to the `grafana` service on port 3000
6. Service forwards to a Grafana pod

### Prometheus Ingress

```yaml
---
# Prometheus Ingress with nip.io (optional)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
    - host: prometheus.192.168.2.207.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus
                port:
                  number: 9090
```

**Same structure**, but routes to Prometheus service on port 9090.

---

## Design Patterns Summary

### 1. **Separation of Concerns**
- **ConfigMap**: Application configuration (non-sensitive)
- **Secret**: Sensitive data (credentials)
- **PVC**: Persistent data storage
- **Deployment**: Application runtime
- **Service**: Network access
- **Ingress**: External access
- **PrometheusRule**: Alert rules and conditions

### 2. **Declarative Infrastructure**
- Everything defined in YAML
- Version controlled
- Reproducible deployments
- Infrastructure as Code

### 3. **Service Discovery**
- Prometheus automatically discovers targets via Kubernetes API
- PrometheusRule CRDs enable declarative alerting
- No manual configuration needed
- Scales automatically

### 4. **Resource Management**
- CPU and memory requests/limits
- Prevents resource exhaustion
- Helps scheduler place pods correctly

### 5. **Health Monitoring**
- Liveness probes ensure containers restart if unhealthy
- Kubernetes automatically manages pod lifecycle

### 6. **Alert Management** (NEW)
- Rules defined as Kubernetes resources
- Hot-reloadable without pod restart
- Integrated with Prometheus lifecycle
- Centralized configuration

---

## Data Flow

1. **Prometheus Scraping**:
   - Prometheus pod queries Kubernetes API (using ServiceAccount token)
   - Discovers pods with `prometheus.io/scrape: "true"` annotation
   - Scrapes metrics from those pods
   - Stores metrics in PVC-backed storage
   - Evaluates alert rules against metrics every 30 seconds

2. **Alert Evaluation**:
   - PrometheusRule defines conditions to monitor
   - Prometheus evaluates expressions periodically
   - When condition is true for `for:` duration, alert fires
   - Alert appears in Prometheus UI under "Alerts" tab
   - Can be integrated with Alertmanager for notifications

3. **Grafana Visualization**:
   - Grafana pod reads datasource config from ConfigMap
   - Connects to Prometheus service via Kubernetes DNS
   - Queries Prometheus for metrics
   - Displays dashboards to users

4. **External Access**:
   - User visits `grafana.192.168.2.207.nip.io`
   - NGINX Ingress routes to Grafana service
   - Service forwards to Grafana pod
   - User sees dashboards

---

## Integration with GitLab

When GitLab pods are deployed with these annotations:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"
```

**What Happens:**

1. Prometheus's `kubernetes-pods` job discovers the GitLab pods via Kubernetes API
2. Relabeling config filters pods with `prometheus.io/scrape: "true"`
3. Prometheus scrapes `http://pod-ip:9090/metrics` from each GitLab pod
4. Metrics are stored with labels like `kubernetes_namespace: gitlab`, `app: gitlab`
5. Grafana queries Prometheus and visualizes GitLab metrics
6. Alert rules evaluate against GitLab metrics
7. **No manual configuration needed!**

---

## Prerequisites for Alert Rules

To use PrometheusRule, you need:

1. **Prometheus Operator CRDs installed**:
   ```bash
   kubectl apply -f https://github.com/prometheus-operator/prometheus-operator/releases/latest/download/bundle.yaml
   ```
   This installs the `prometheusrules.monitoring.coreos.com` CRD that Kubernetes needs to understand PrometheusRule resources.

2. **RBAC permissions** (already included in this setup):
   - Prometheus needs permission to read PrometheusRule resources
   - The ClusterRole includes `apiGroups: [monitoring.coreos.com]`

3. **Prometheus watching PrometheusRule**:
   - Prometheus automatically watches for PrometheusRule resources in its namespace
   - Rules are loaded and evaluated without restart

---

## Future Enhancements

Consider these improvements:

1. **AlertManager**: Add alerting rules and notification channels (email, Slack, PagerDuty)
2. **Grafana Dashboard Provisioning**: Auto-provision dashboards via ConfigMap
3. **TLS/SSL**: Add certificates to Ingress for HTTPS
4. **Backup Strategy**: Regular backups of Prometheus and Grafana data
5. **Multi-Replica**: Run multiple Prometheus instances (requires shared storage)
6. **External Database**: Use PostgreSQL for Grafana (instead of SQLite)
7. **Resource Quotas**: Limit total resources in the namespace
8. **Network Policies**: Restrict pod-to-pod communication
9. **Pod Disruption Budgets**: Ensure availability during node maintenance
10. **Custom Alert Rules**: Add domain-specific alerts based on your applications

---

This architecture provides a production-ready monitoring stack with automatic service discovery, persistent storage, built-in alerting, and external access, all configured declaratively in YAML.