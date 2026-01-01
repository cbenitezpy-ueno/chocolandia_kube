# Contract: Alertmanager to ntfy Webhook

**Feature**: 026-ntfy-homepage-alerts
**Type**: HTTP Webhook with Basic Authentication
**Direction**: Alertmanager → ntfy

## Endpoint

```
POST http://ntfy.ntfy.svc.cluster.local/homelab-alerts?template=alertmanager
Authorization: Basic base64(alertmanager:password)
Content-Type: application/json
```

## Request Format (Alertmanager JSON)

ntfy's `?template=alertmanager` automatically parses this format:

```json
{
  "version": "4",
  "groupKey": "{}:{alertname=\"NodeDown\"}",
  "truncatedAlerts": 0,
  "status": "firing",
  "receiver": "ntfy-homelab",
  "groupLabels": {
    "alertname": "NodeDown"
  },
  "commonLabels": {
    "alertname": "NodeDown",
    "severity": "critical"
  },
  "commonAnnotations": {
    "summary": "Node 192.168.4.101 is down",
    "description": "Node has been unreachable for more than 5 minutes"
  },
  "externalURL": "http://alertmanager:9093",
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "NodeDown",
        "instance": "192.168.4.101:9100",
        "severity": "critical"
      },
      "annotations": {
        "summary": "Node 192.168.4.101 is down",
        "description": "Node has been unreachable for more than 5 minutes",
        "dashboard": "https://grafana.chocolandiadc.com/d/..."
      },
      "startsAt": "2025-12-31T10:30:00.000Z",
      "endsAt": "0001-01-01T00:00:00Z",
      "generatorURL": "http://prometheus:9090/graph?g0.expr=..."
    }
  ]
}
```

## Response Format

### Success (200 OK)

```json
{
  "id": "abc123",
  "time": 1735636800,
  "expires": 1735723200,
  "event": "message",
  "topic": "homelab-alerts",
  "message": "[FIRING:1] NodeDown\n\nAlert: NodeDown\nSeverity: critical\n..."
}
```

### Authentication Failure (403 Forbidden)

```json
{
  "code": 40301,
  "http": 403,
  "error": "forbidden"
}
```

## ntfy Template Transformation

With `?template=alertmanager`, ntfy transforms the Alertmanager payload into:

| ntfy Field | Source |
|------------|--------|
| Title | `[STATUS:count] alertname` |
| Message | Formatted alert details |
| Priority | Based on `severity` label (critical=5, warning=4, info=3) |
| Tags | Status emoji + severity icon |

## Authentication Configuration

### Kubernetes Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ntfy-alertmanager-password
  namespace: monitoring
type: Opaque
data:
  password: <base64-encoded-password>
```

### Alertmanager Receiver Config

```yaml
receivers:
  - name: ntfy-homelab
    webhook_configs:
      - url: "http://ntfy.ntfy.svc.cluster.local/homelab-alerts?template=alertmanager"
        http_config:
          basic_auth:
            username: alertmanager
            password_file: /etc/alertmanager/secrets/ntfy-alertmanager-password/password
        send_resolved: true
```

## Error Handling

| HTTP Code | Meaning | Alertmanager Behavior |
|-----------|---------|----------------------|
| 200 | Success | Mark as delivered |
| 403 | Auth failed | Retry with backoff |
| 429 | Rate limited | Retry with backoff |
| 500+ | Server error | Retry with backoff |

## Rate Limits (ntfy configuration)

- `visitor-request-limit-burst`: 60
- `visitor-request-limit-replenish`: 5s
- `visitor-subscription-limit`: 30

## Validation

Test the webhook manually:

```bash
# Test with authentication (should succeed)
curl -u "alertmanager:PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"status":"firing","alerts":[{"labels":{"alertname":"TestAlert"}}]}' \
  "http://ntfy.ntfy.svc.cluster.local/homelab-alerts?template=alertmanager"

# Test without authentication (should fail with 403)
curl -d "Test" http://ntfy.ntfy.svc.cluster.local/homelab-alerts
# Expected: {"code":40301,"http":403,"error":"forbidden"}
```
