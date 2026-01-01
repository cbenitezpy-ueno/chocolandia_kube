# Contract: Homepage to Prometheus (prometheusmetric Widget)

**Feature**: 026-ntfy-homepage-alerts
**Type**: HTTP API Query
**Direction**: Homepage → Prometheus

## Endpoint

```
GET http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query
```

## PromQL Queries

### Critical Alerts Count

```promql
count(ALERTS{alertstate="firing", severity="critical"}) or vector(0)
```

Returns: Number of firing critical alerts, or 0 if none.

### Warning Alerts Count

```promql
count(ALERTS{alertstate="firing", severity="warning"}) or vector(0)
```

Returns: Number of firing warning alerts, or 0 if none.

### Total Firing Alerts

```promql
count(ALERTS{alertstate="firing"}) or vector(0)
```

Returns: Total number of all firing alerts.

## Request Format

```http
GET /api/v1/query?query=count(ALERTS{alertstate="firing",severity="critical"})%20or%20vector(0)
Host: kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
```

## Response Format

### Success (200 OK)

```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {},
        "value": [1735636800, "2"]
      }
    ]
  }
}
```

- `value[0]`: Unix timestamp
- `value[1]`: Query result as string (e.g., "2" means 2 alerts)

### Empty Result (0 alerts)

```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {},
        "value": [1735636800, "0"]
      }
    ]
  }
}
```

## Homepage Widget Configuration

### widgets.yaml (top-level widget)

```yaml
- prometheusmetric:
    url: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
    refreshInterval: 30000  # 30 seconds
    label: "Cluster Alerts"
    query: count(ALERTS{alertstate="firing"}) or vector(0)
    format:
      type: number
```

### services.yaml (service card with alerts)

```yaml
- Cluster Alerts:
    icon: mdi-alert-circle
    description: "Prometheus firing alerts"
    widget:
      type: prometheusmetric
      url: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
      refreshInterval: 30000
      metrics:
        - label: Critical
          query: count(ALERTS{alertstate="firing", severity="critical"}) or vector(0)
          format:
            type: number
        - label: Warning
          query: count(ALERTS{alertstate="firing", severity="warning"}) or vector(0)
          format:
            type: number
```

## Error Handling

| Scenario | Homepage Behavior |
|----------|-------------------|
| Prometheus unreachable | Shows "Error" or "-" |
| Query timeout | Retries after refreshInterval |
| Invalid query | Shows error message |
| No data | Shows "0" (due to `or vector(0)`) |

## Network Requirements

- Homepage pod must be able to reach Prometheus ClusterIP
- No authentication required (internal cluster traffic)
- Port 9090 must be accessible

## Validation

Test queries from within the cluster:

```bash
# From any pod with curl
kubectl run curl-test --image=curlimages/curl -it --rm -- \
  curl -s "http://kube-prometheus-stack-prometheus.monitoring:9090/api/v1/query" \
  --data-urlencode 'query=count(ALERTS{alertstate="firing"}) or vector(0)'

# Expected output:
# {"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[...,"0"]}]}}
```
