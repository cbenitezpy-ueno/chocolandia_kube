# Homepage Widget Configuration Guide

Comprehensive guide for configuring widgets in Homepage dashboard.

## Table of Contents

- [Widget Basics](#widget-basics)
- [Kubernetes Widget](#kubernetes-widget)
- [ArgoCD Widget](#argocd-widget)
- [Custom Widgets](#custom-widgets)
- [Widget Best Practices](#widget-best-practices)

---

## Widget Basics

### What are Widgets?

Widgets display real-time metrics and status information from services and infrastructure components. Homepage supports two main widget placement areas:

1. **Service Widgets**: Attached to specific services (in `services.yaml`)
2. **Dashboard Widgets**: Standalone widgets in sidebar (in `widgets.yaml`)

### Widget Configuration Structure

```yaml
widget:
  type: <widget-type>       # Required: kubernetes, argocd, custom, etc.
  <type-specific-params>    # Parameters specific to widget type
```

### Adding Widgets via GitOps

1. Edit `kubernetes/homepage/configmaps.yaml`
2. Add widget configuration to appropriate ConfigMap
3. Commit and push changes
4. ArgoCD syncs automatically (max 3 minutes)

---

## Kubernetes Widget

The Kubernetes widget displays pod status, resource usage, and metrics from Kubernetes API and metrics-server.

### Basic Configuration

```yaml
widget:
  type: kubernetes
  cluster: default
  namespace: <target-namespace>
  app: <app-name>
  podSelector: <label-selector>
```

### Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `type` | Yes | Must be "kubernetes" | `kubernetes` |
| `cluster` | No | Cluster name (use "default") | `default` |
| `namespace` | Yes | Target namespace | `traefik` |
| `app` | No | App name for display | `traefik` |
| `podSelector` | Yes | Label selector for pods | `app.kubernetes.io/name=traefik` |

### Example: Traefik Service Widget

```yaml
- Infrastructure:
    - Traefik:
        icon: traefik.svg
        description: Reverse proxy and ingress controller
        namespace: traefik
        app: traefik
        widget:
          type: kubernetes
          cluster: default
          namespace: traefik
          app: traefik
          podSelector: app.kubernetes.io/name=traefik
```

**Displays**:
- Pod status (Running, Pending, Failed)
- Pod count (e.g., "1/1")
- CPU usage (if metrics-server available)
- Memory usage (if metrics-server available)

### Advanced: Selecting Multiple Pods

To monitor all pods with multiple labels:

```yaml
widget:
  type: kubernetes
  namespace: monitoring
  podSelector: app.kubernetes.io/part-of=kube-prometheus-stack
```

### Advanced: Monitoring Specific Deployment

```yaml
widget:
  type: kubernetes
  namespace: argocd
  podSelector: app.kubernetes.io/name=argocd-server,app.kubernetes.io/instance=argocd
```

### Troubleshooting Kubernetes Widget

**Problem**: Widget shows "No pods found"

**Solutions**:
1. Verify pods exist: `kubectl get pods -n <namespace>`
2. Check pod labels: `kubectl get pods -n <namespace> --show-labels`
3. Update `podSelector` to match actual labels
4. Verify RBAC permissions (see [RBAC.md](./RBAC.md))

**Problem**: Widget shows "Forbidden"

**Solution**: Add namespace to RBAC (see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md#rbac-permission-errors))

---

## ArgoCD Widget

The ArgoCD widget displays application sync status and health from ArgoCD API.

### Basic Configuration

```yaml
widget:
  type: argocd
  url: <argocd-api-url>
  key: <argocd-jwt-token>
```

### Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `type` | Yes | Must be "argocd" | `argocd` |
| `url` | Yes | ArgoCD API URL | `http://argocd-server.argocd.svc.cluster.local:80` |
| `key` | Yes | ArgoCD JWT token (template variable) | `{{HOMEPAGE_VAR_ARGOCD_TOKEN}}` |

### Example: ArgoCD Service Widget

```yaml
- Kubernetes Management:
    - ArgoCD:
        icon: argocd.svg
        href: https://argocd.chocolandiadc.com
        description: GitOps continuous delivery for Kubernetes
        namespace: argocd
        app: argocd-server
        widget:
          type: argocd
          url: http://argocd-server.argocd.svc.cluster.local:80
          key: {{HOMEPAGE_VAR_ARGOCD_TOKEN}}
```

**Displays**:
- Total applications count
- Synced applications
- Healthy applications
- Application list with status icons

### Token Template Variable

The `{{HOMEPAGE_VAR_ARGOCD_TOKEN}}` template is replaced at runtime by Homepage using the value from Secret:

```yaml
# In secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: homepage-widgets
  namespace: homepage
type: Opaque
stringData:
  HOMEPAGE_VAR_ARGOCD_TOKEN: "eyJhbGciOiJIUzI1NiIs..."
```

### Generating ArgoCD Token

1. **Open ArgoCD UI**: https://argocd.chocolandiadc.com
2. **Navigate**: Settings → Accounts → `homepage` → Tokens
3. **Generate New Token**:
   - Name: `homepage-dashboard`
   - Expires In: Never (or custom duration)
4. **Copy token** and update Secret:

```bash
kubectl create secret generic homepage-widgets \
  --from-literal=HOMEPAGE_VAR_ARGOCD_TOKEN="NEW_TOKEN_HERE" \
  -n homepage \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/homepage -n homepage
```

### Troubleshooting ArgoCD Widget

**Problem**: Widget shows "Authentication required"

**Solution**: Generate new token and update Secret (see above)

**Problem**: Widget shows "URL not reachable"

**Solutions**:
1. Verify ArgoCD service exists: `kubectl get service argocd-server -n argocd`
2. Use correct internal URL: `http://argocd-server.argocd.svc.cluster.local:80`
3. Test connectivity from Homepage pod:
   ```bash
   kubectl exec -n homepage deployment/homepage -- \
     wget -O- http://argocd-server.argocd.svc.cluster.local:80/api/version
   ```

---

## Custom Widgets

Homepage supports custom widgets for external APIs and services.

### Generic API Widget

Query any REST API endpoint:

```yaml
widget:
  type: customapi
  url: https://api.example.com/status
  method: GET
  headers:
    Authorization: Bearer {{HOMEPAGE_VAR_API_TOKEN}}
  mappings:
    - field: status
      label: Status
      format: text
    - field: uptime
      label: Uptime
      format: duration
```

### Script Widget

Execute custom scripts (requires Homepage to have script execution enabled):

```yaml
widget:
  type: script
  command: /scripts/custom-status.sh
  interval: 60  # Seconds
```

### Prometheus Widget

Query Prometheus metrics:

```yaml
widget:
  type: prometheus
  url: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
  query: up{job="traefik"}
  label: Traefik Uptime
```

---

## Widget Best Practices

### 1. Use Specific podSelectors

**❌ Bad**: Too broad, queries all pods
```yaml
podSelector: ""
```

**✅ Good**: Specific label selector
```yaml
podSelector: app.kubernetes.io/name=traefik
```

### 2. Secure Token Management

**❌ Bad**: Hardcoded token in ConfigMap
```yaml
widget:
  type: argocd
  key: "eyJhbGciOiJIUzI1NiIs..."  # Never hardcode tokens!
```

**✅ Good**: Template variable from Secret
```yaml
widget:
  type: argocd
  key: {{HOMEPAGE_VAR_ARGOCD_TOKEN}}
```

### 3. Use Internal Service URLs

**❌ Bad**: External URL (slower, unnecessary)
```yaml
url: https://argocd.chocolandiadc.com
```

**✅ Good**: Internal ClusterIP service
```yaml
url: http://argocd-server.argocd.svc.cluster.local:80
```

### 4. Optimize Widget Refresh Intervals

For high-traffic services, avoid too-frequent refreshes:

```yaml
# In widgets.yaml
widgets:
  - resources:
      refresh: 30000  # 30 seconds (default: 10000ms)
```

### 5. Group Related Services

Organize services by function for better dashboard layout:

```yaml
- Infrastructure:
    - Traefik:
        # ...
    - cert-manager:
        # ...

- Kubernetes Management:
    - ArgoCD:
        # ...
    - Headlamp:
        # ...

- Monitoring:
    - Prometheus:
        # ...
    - Grafana:
        # ...
```

---

## Dashboard Widgets Configuration

Dashboard widgets appear in the sidebar (configured in `widgets.yaml`).

### Cluster Statistics Widget

```yaml
- resources:
    cpu: true
    memory: true
    disk: false  # Disabled for K3s (no disk metrics)
```

**Displays**:
- Total cluster CPU usage
- Total cluster memory usage
- Node count and status

### Kubernetes Widget (Dashboard)

Show cluster-wide Kubernetes statistics:

```yaml
- kubernetes:
    cluster:
      show: true
      cpu: true
      memory: true
      showLabel: true
    nodes:
      show: true
      cpu: true
      memory: true
```

**Displays**:
- Total cluster CPU/memory
- Node count and individual node stats
- Pod count across all namespaces

---

## Complete Widget Examples

### Example 1: Monitoring Grafana

```yaml
- Monitoring:
    - Grafana:
        icon: grafana.svg
        href: https://grafana.chocolandiadc.com
        description: Metrics visualization and dashboards
        namespace: monitoring
        app: grafana
        widget:
          type: kubernetes
          cluster: default
          namespace: monitoring
          app: grafana
          podSelector: app.kubernetes.io/name=grafana
```

### Example 2: Monitoring Multiple Prometheus Pods

```yaml
- Monitoring:
    - Prometheus:
        icon: prometheus.svg
        href: https://prometheus.chocolandiadc.com
        description: Metrics collection and alerting
        namespace: monitoring
        app: prometheus
        widget:
          type: kubernetes
          namespace: monitoring
          podSelector: app.kubernetes.io/name=prometheus,prometheus=kube-prometheus-stack-prometheus
```

### Example 3: Custom API Integration

```yaml
- External Services:
    - UptimeRobot:
        icon: uptimerobot.svg
        description: Uptime monitoring service
        widget:
          type: customapi
          url: https://api.uptimerobot.com/v2/getMonitors
          method: POST
          headers:
            Content-Type: application/x-www-form-urlencoded
          body: api_key={{HOMEPAGE_VAR_UPTIMEROBOT_KEY}}&format=json
          mappings:
            - field: monitors[0].status
              label: Status
              format: text
```

---

## Widget Icons

Homepage uses icons from [dashboard-icons](https://github.com/walkxcode/dashboard-icons).

### Available Icons

- **Infrastructure**: traefik.svg, nginx.svg, haproxy.svg
- **Kubernetes**: kubernetes.svg, k3s.svg, argocd.svg, helm.svg
- **Monitoring**: prometheus.svg, grafana.svg, alertmanager.svg
- **Databases**: postgresql.svg, mysql.svg, mongodb.svg, redis.svg
- **CI/CD**: jenkins.svg, gitlab.svg, github.svg, drone.svg

### Custom Icons

Place custom icons in Homepage's public folder or use URLs:

```yaml
icon: https://example.com/my-icon.png
# or
icon: /icons/custom-icon.svg
```

---

## Testing Widget Configuration

### 1. Validate YAML Syntax

```bash
# Test ConfigMap before committing
kubectl apply --dry-run=client -f kubernetes/homepage/configmaps.yaml
```

### 2. Test Widget in Homepage

After committing changes:

```bash
# Watch ArgoCD sync
kubectl get application homepage -n argocd -w

# Check Homepage logs for widget errors
kubectl logs -n homepage -l app=homepage --tail=50 | grep -i "widget\|error"
```

### 3. Verify API Connectivity

```bash
# Test from Homepage pod
kubectl exec -n homepage deployment/homepage -- \
  wget -O- http://argocd-server.argocd.svc.cluster.local:80/api/version
```

---

## Additional Resources

- **Homepage Widgets Documentation**: https://gethomepage.dev/en/widgets/
- **Kubernetes Widget Docs**: https://gethomepage.dev/en/widgets/services/kubernetes/
- **ArgoCD Widget Docs**: https://gethomepage.dev/en/widgets/services/argocd/
- **Dashboard Icons Repository**: https://github.com/walkxcode/dashboard-icons
- **Homepage Configuration Examples**: https://gethomepage.dev/en/configs/services/
