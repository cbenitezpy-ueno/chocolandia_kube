# Research: Fix Ntfy Notifications and Add Alerts to Homepage

**Feature**: 026-ntfy-homepage-alerts
**Date**: 2025-12-31

## Problem Analysis

### Root Cause: ntfy Authentication Required

**Observation**: When testing notifications from within the cluster:
```bash
curl -d "Test" http://ntfy.ntfy.svc.cluster.local/homelab-alerts
# Returns: {"code":40301,"http":403,"error":"forbidden"}
```

**Configuration Analysis**: ntfy is configured with:
```yaml
auth-default-access: "read-only"
enable-login: true
```

This means:
- Anonymous users can only READ (subscribe to topics)
- Publishing requires authentication
- Alertmanager is sending webhooks WITHOUT authentication → 403 Forbidden

### Solution Options Evaluated

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **A. Grant anonymous write to topic** | Simple, no Alertmanager changes | Less secure, anyone in cluster can spam | ❌ Rejected |
| **B. Alertmanager basic auth to ntfy** | Native Alertmanager support | Requires ntfy user creation, webhook URL with auth | ✅ Chosen |
| **C. ntfy-alertmanager bridge** | Rich features (silences, priorities) | Extra deployment, more complexity | ❌ Overkill for homelab |
| **D. alertmanager-ntfy service** | Good formatting, flexible | Extra deployment needed | ❌ Unnecessary |

**Decision**: Option B - Configure Alertmanager webhook with basic auth credentials to ntfy.

**Rationale**:
- Alertmanager natively supports basic auth in webhook_configs
- ntfy already has user management (`users: 2` in logs)
- No additional services to deploy
- Maintains security (auth required)

## Homepage Alerts Widget Research

### Available Options

| Widget Type | Capabilities | Limitations |
|-------------|--------------|-------------|
| `prometheus` | Targets up/down count | No alerts support |
| `prometheusmetric` | Custom PromQL queries | Can query alert counts |

**Decision**: Use `prometheusmetric` widget with PromQL queries for alert counts.

**Queries to implement**:
```yaml
metrics:
  - label: Critical
    query: count(ALERTS{alertstate="firing", severity="critical"}) or vector(0)
  - label: Warning
    query: count(ALERTS{alertstate="firing", severity="warning"}) or vector(0)
```

### Alternative Considered: Karma Dashboard

[Karma](https://karma-dashboard.io/) is a dedicated alert dashboard for Alertmanager. While more feature-rich, it requires:
- Additional deployment
- Separate URL/ingress
- More resources

**Decision**: Rejected for this feature. The prometheusmetric widget provides sufficient visibility for a homepage dashboard. Karma could be a future enhancement.

## Implementation Approach

### Phase 1: Fix ntfy Authentication

1. Create/verify ntfy user for Alertmanager (or use existing admin)
2. Update Alertmanager webhook config with basic auth:
   ```yaml
   receivers:
     - name: ntfy-homelab
       webhook_configs:
         - url: http://ntfy.ntfy.svc.cluster.local/homelab-alerts
           http_config:
             basic_auth:
               username: alertmanager
               password_file: /etc/alertmanager/secrets/ntfy-password
           send_resolved: true
   ```
3. Create Kubernetes secret for ntfy password
4. Mount secret in Alertmanager pod

### Phase 2: Add ntfy Alertmanager Template

ntfy supports a built-in `alertmanager` template that formats JSON payloads:
```
POST /homelab-alerts?template=alertmanager
```

This converts Alertmanager JSON to human-readable notifications with:
- Title: Alert name + status (firing/resolved)
- Body: Alert annotations (description, summary)
- Priority: Based on severity label

### Phase 3: Homepage Widget Configuration

Add to Homepage services.yaml or widgets.yaml:
```yaml
- Cluster Alerts:
    icon: mdi-alert-circle
    widget:
      type: prometheusmetric
      url: http://kube-prometheus-stack-prometheus.monitoring:9090
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

## Security Considerations

1. **ntfy credentials in Kubernetes Secret**: Password stored encrypted, not in Git
2. **Internal cluster URLs**: No external exposure of Prometheus/Alertmanager APIs
3. **Read-only for subscribers**: Mobile apps only need read access to subscribe

## Dependencies

- kube-prometheus-stack (Prometheus + Alertmanager) - Already deployed
- ntfy - Already deployed with authentication
- Homepage - Already deployed

## References

- [ntfy Integrations](https://docs.ntfy.sh/integrations/)
- [ntfy Authentication](https://docs.ntfy.sh/publish/#authentication)
- [Homepage prometheusmetric Widget](https://gethomepage.dev/widgets/services/prometheusmetric/)
- [Alertmanager Webhook Config](https://prometheus.io/docs/alerting/latest/configuration/#webhook_config)
