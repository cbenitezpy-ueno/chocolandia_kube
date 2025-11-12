# Headlamp Monitoring Integration

This document explains how Headlamp integrates with Prometheus for metrics visualization.

## Overview

Headlamp is a **metrics consumer**, not a metrics exporter. It integrates with Prometheus to display cluster metrics in the web UI, but does not expose its own `/metrics` endpoint.

## Prometheus Configuration

Headlamp is configured to connect to the Prometheus server deployed in the `monitoring` namespace:

```yaml
config:
  prometheusUrl: "http://kube-prometheus-stack-prometheus.monitoring:9090"
```

This configuration was applied during Headlamp deployment via Helm chart values.

## What Headlamp Displays

When browsing the Headlamp UI, you'll see metrics charts for:

### Pod Metrics
- **CPU Usage**: Real-time and historical CPU consumption
- **Memory Usage**: Real-time and historical memory consumption
- **Network I/O**: Network traffic rates
- **Container Restarts**: Restart counts over time

### Node Metrics
- **CPU Utilization**: Per-node CPU usage
- **Memory Utilization**: Per-node memory usage
- **Disk Usage**: Filesystem usage
- **Network Traffic**: Network throughput

### Cluster-Wide Metrics
- **Resource Quotas**: Quota usage across namespaces
- **Persistent Volume Usage**: PVC capacity and usage
- **API Server Metrics**: Request rates and latency

## Metrics Flow

```
┌──────────────────┐
│  Kubernetes API  │
│   + kubelet      │
└────────┬─────────┘
         │ metrics
         ▼
┌──────────────────┐
│  metrics-server  │
│  (resource API)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐      ┌──────────────────┐
│   Prometheus     │◄─────│ ServiceMonitors  │
│  (monitoring ns) │      │ (scrape configs) │
└────────┬─────────┘      └──────────────────┘
         │
         │ PromQL queries
         ▼
┌──────────────────┐
│    Headlamp UI   │
│  (headlamp ns)   │
└──────────────────┘
```

## Verifying Metrics Integration

### 1. Check Headlamp Configuration

Verify the Prometheus URL is configured in the Headlamp deployment:

```bash
kubectl get deployment headlamp -n headlamp -o jsonpath='{.spec.template.spec.containers[0].env}' | jq -r '.[] | select(.name=="HEADLAMP_PROMETHEUS_URL")'
```

### 2. Test Prometheus Accessibility

From a Headlamp pod, verify it can reach Prometheus:

```bash
kubectl exec -n headlamp deployment/headlamp -- curl -s http://kube-prometheus-stack-prometheus.monitoring:9090/api/v1/query?query=up
```

Expected output: JSON response with Prometheus targets

### 3. Verify Metrics Display

1. Access Headlamp UI: `https://headlamp.chocolandiadc.com`
2. Authenticate via Cloudflare Access (Google OAuth)
3. Navigate to any pod detail page
4. Verify CPU and Memory charts are displayed
5. Check that metrics show real-time data

## Monitoring Headlamp Itself

While Headlamp consumes metrics, **it does not expose its own metrics endpoint**. To monitor Headlamp's health and performance:

### Option 1: Use kube-state-metrics

The `kube-state-metrics` service (deployed with kube-prometheus-stack) provides metrics about Kubernetes resources, including Headlamp pods:

```promql
# Headlamp pod status
kube_pod_status_phase{namespace="headlamp", pod=~"headlamp-.*"}

# Headlamp container restarts
kube_pod_container_status_restarts_total{namespace="headlamp", container="headlamp"}

# Headlamp pod CPU usage (via kubelet)
container_cpu_usage_seconds_total{namespace="headlamp", pod=~"headlamp-.*", container="headlamp"}

# Headlamp pod memory usage (via kubelet)
container_memory_working_set_bytes{namespace="headlamp", pod=~"headlamp-.*", container="headlamp"}
```

### Option 2: Use Liveness/Readiness Probes

Headlamp deployment includes health check endpoints:

```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
```

Monitor probe failures via Kubernetes events:

```bash
kubectl get events -n headlamp --field-selector involvedObject.name=headlamp
```

### Option 3: Use Grafana Dashboard

Import the "Kubernetes / Compute Resources / Pod" dashboard in Grafana:

1. Access Grafana: `https://grafana.chocolandiadc.com`
2. Go to Dashboards → Browse
3. Search for "Kubernetes / Compute Resources / Pod"
4. Filter by namespace: `headlamp`

## Troubleshooting

### Metrics Not Showing in UI

**Symptom**: Headlamp UI shows "No metrics available" or empty charts

**Possible Causes**:

1. **Prometheus URL not configured**
   ```bash
   kubectl describe deployment headlamp -n headlamp | grep PROMETHEUS
   ```
   Fix: Ensure `prometheusUrl` is set in Helm values

2. **Network connectivity issues**
   ```bash
   kubectl exec -n headlamp deployment/headlamp -- curl -v http://kube-prometheus-stack-prometheus.monitoring:9090/api/v1/status/config
   ```
   Fix: Verify NetworkPolicies allow headlamp → monitoring traffic

3. **Prometheus not running**
   ```bash
   kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
   ```
   Fix: Ensure Prometheus pods are Running

4. **metrics-server not available**
   ```bash
   kubectl top nodes
   kubectl top pods -n headlamp
   ```
   Fix: Deploy metrics-server if missing

### High Headlamp Resource Usage

**Symptom**: Headlamp pods using excessive CPU/memory

**Investigation**:

```bash
# Check current resource usage
kubectl top pods -n headlamp

# Check resource limits
kubectl get deployment headlamp -n headlamp -o jsonpath='{.spec.template.spec.containers[0].resources}'

# Check pod events
kubectl get events -n headlamp --field-selector involvedObject.name=headlamp-<pod-id>
```

**Fixes**:

- Increase resource limits if constrained
- Check for memory leaks via restart count
- Review browser console for JavaScript errors
- Reduce number of concurrent users/sessions

## Best Practices

1. **Resource Limits**: Headlamp is configured with reasonable defaults:
   - CPU request: 100m, limit: 200m
   - Memory request: 128Mi, limit: 256Mi

2. **High Availability**: Deploy 2+ replicas with pod anti-affinity:
   - Ensures availability during node maintenance
   - PodDisruptionBudget maintains minAvailable: 1

3. **Prometheus Retention**: Ensure Prometheus retention is adequate:
   - Default: 10 days
   - Adjust based on historical metrics needs
   - Balance retention vs. storage costs

4. **Grafana Dashboards**: Use Grafana for deeper analysis:
   - Headlamp provides quick overview
   - Grafana provides detailed investigation
   - Both consume same Prometheus data source

## Related Documentation

- [Headlamp Prometheus Integration](https://headlamp.dev/docs/latest/installation/in-cluster/#prometheus-integration)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [metrics-server](https://github.com/kubernetes-sigs/metrics-server)
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)

## Support

For Headlamp-specific monitoring issues:
- GitHub Issues: https://github.com/headlamp-k8s/headlamp/issues
- Slack: kubernetes.slack.com #headlamp

For Prometheus/Grafana issues:
- Feature 005 documentation: `specs/005-traefik-ingress/`
- Prometheus Community: prometheus.io/community/
