# Traefik Prometheus Integration

Feature 005: Traefik Ingress Controller - Metrics Integration

## Overview

Traefik v3.x exposes Prometheus metrics on port 9100 at the `/metrics` endpoint. This document describes how to integrate these metrics with Prometheus for monitoring and observability.

## Available Metrics

Traefik exposes the following metric categories:

### Configuration Metrics
- `traefik_config_reloads_total`: Total number of configuration reloads
- `traefik_config_last_reload_success`: Timestamp of last successful config reload

### Entry Point Metrics
- `traefik_entrypoint_requests_total`: Total requests by entrypoint, code, method, protocol
- `traefik_entrypoint_request_duration_seconds`: Request duration histogram
- `traefik_entrypoint_requests_bytes_total`: Total request bytes
- `traefik_entrypoint_responses_bytes_total`: Total response bytes
- `traefik_open_connections`: Current open connections by entrypoint

### Router Metrics
- `traefik_router_requests_total`: Total requests by router, code, method, protocol
- `traefik_router_request_duration_seconds`: Request duration by router

### Service Metrics
- `traefik_service_requests_total`: Total requests by service, code, method, protocol
- `traefik_service_request_duration_seconds`: Request duration by service
- `traefik_service_open_connections`: Current open connections by service
- `traefik_service_retries_total`: Total retries by service

### TLS Metrics
- `traefik_tls_certs_not_after`: Certificate expiration timestamps

## ServiceMonitor Configuration

A Kubernetes ServiceMonitor resource has been created for automatic scraping by Prometheus Operator:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: traefik
  namespace: traefik
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
      app.kubernetes.io/component: metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

This ServiceMonitor:
- Scrapes metrics every 30 seconds
- Targets the `traefik-metrics` ClusterIP service on port 9100
- Automatically discovered by Prometheus Operator

## Manual Prometheus Configuration

If not using Prometheus Operator, add this scrape config to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'traefik'
    kubernetes_sd_configs:
      - role: service
        namespaces:
          names:
            - traefik
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        regex: traefik-metrics
        action: keep
      - source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
        target_label: app
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_service_name]
        target_label: service
```

## Verification

### Check Metrics Endpoint

From inside the cluster:
```bash
kubectl exec -n traefik deployment/traefik -- wget -O- http://localhost:9100/metrics
```

Via the metrics service:
```bash
kubectl run -n traefik curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl http://traefik-metrics:9100/metrics
```

### Check ServiceMonitor

```bash
kubectl get servicemonitor -n traefik
kubectl describe servicemonitor traefik -n traefik
```

### Check Prometheus Targets

If using Prometheus Operator, check that the target is being scraped:
```bash
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090
# Open http://localhost:9090/targets
# Look for "traefik/traefik/0" target with status UP
```

## Example PromQL Queries

### Request Rate
```promql
# Total requests per second by entrypoint
rate(traefik_entrypoint_requests_total[5m])

# Requests per second by router
rate(traefik_router_requests_total[5m])

# Error rate (4xx + 5xx)
rate(traefik_entrypoint_requests_total{code=~"4..|5.."}[5m])
```

### Latency
```promql
# Average request duration by entrypoint (p50, p95, p99)
histogram_quantile(0.50, rate(traefik_entrypoint_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(traefik_entrypoint_request_duration_seconds_bucket[5m]))
histogram_quantile(0.99, rate(traefik_entrypoint_request_duration_seconds_bucket[5m]))

# Average request duration by service
histogram_quantile(0.95, rate(traefik_service_request_duration_seconds_bucket[5m]))
```

### Throughput
```promql
# Request bytes per second
rate(traefik_entrypoint_requests_bytes_total[5m])

# Response bytes per second
rate(traefik_entrypoint_responses_bytes_total[5m])
```

### Connections
```promql
# Current open connections
traefik_open_connections

# Open connections by entrypoint
sum by (entrypoint) (traefik_open_connections)
```

## Grafana Dashboards

Recommended Grafana dashboards for Traefik v3.x:
- **Dashboard ID 17346**: Traefik Official Dashboard (v3.x)
- **Dashboard ID 11462**: Traefik 2.x (may work with v3.x)

Import via Grafana UI:
1. Navigate to Dashboards → Import
2. Enter dashboard ID
3. Select Prometheus data source
4. Click Import

## Alerting Examples

Example Prometheus alerting rules:

```yaml
groups:
  - name: traefik
    interval: 30s
    rules:
      - alert: TraefikHighErrorRate
        expr: |
          (
            sum(rate(traefik_entrypoint_requests_total{code=~"5.."}[5m]))
            /
            sum(rate(traefik_entrypoint_requests_total[5m]))
          ) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Traefik high error rate (> 5%)"
          description: "{{ $value | humanizePercentage }} of requests are failing"

      - alert: TraefikHighLatency
        expr: |
          histogram_quantile(0.95,
            rate(traefik_entrypoint_request_duration_seconds_bucket[5m])
          ) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Traefik high latency (p95 > 1s)"
          description: "95th percentile latency is {{ $value }}s"

      - alert: TraefikConfigReloadFailure
        expr: |
          traefik_config_last_reload_success == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Traefik config reload failed"
          description: "Last config reload was not successful"
```

## Troubleshooting

### Metrics Endpoint Not Accessible

1. Check that metrics port is exposed in pod:
```bash
kubectl get pods -n traefik -o jsonpath='{.items[0].spec.containers[0].ports}' | jq
```

2. Verify metrics are enabled in Helm values:
```yaml
metrics:
  prometheus:
    enabled: true
    entryPoint: metrics
```

3. Check that metrics service exists and has correct selector:
```bash
kubectl get svc traefik-metrics -n traefik
kubectl get endpoints traefik-metrics -n traefik
```

### ServiceMonitor Not Being Scraped

1. Verify Prometheus Operator CRDs are installed:
```bash
kubectl get crd servicemonitors.monitoring.coreos.com
```

2. Check ServiceMonitor labels match Prometheus serviceMonitorSelector:
```bash
kubectl get prometheus -n monitoring -o yaml | grep -A5 serviceMonitorSelector
```

3. Check Prometheus logs for errors:
```bash
kubectl logs -n monitoring prometheus-k8s-0 -c prometheus
```

## References

- [Traefik Metrics Documentation](https://doc.traefik.io/traefik/observability/metrics/prometheus/)
- [Prometheus Operator ServiceMonitor](https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.ServiceMonitor)
- [Grafana Dashboard 17346](https://grafana.com/grafana/dashboards/17346)
