# Quickstart: Fix Ntfy Notifications and Add Alerts to Homepage

**Feature**: 026-ntfy-homepage-alerts
**Date**: 2025-12-31

## Prerequisites

1. ntfy deployed and accessible at `http://ntfy.ntfy.svc.cluster.local`
2. kube-prometheus-stack deployed with Alertmanager
3. Homepage deployed with Prometheus connectivity
4. kubectl access to the cluster

## Quick Verification

### Check Current State

```bash
# Verify ntfy is running
kubectl get pods -n ntfy

# Verify ntfy authentication is enabled
kubectl exec -n ntfy deployment/ntfy -- cat /etc/ntfy/server.yml | grep auth-default-access
# Expected: auth-default-access: "read-only"

# Test ntfy requires auth (should return 403)
kubectl exec -n ntfy deployment/ntfy -- curl -s -d "Test" http://localhost/homelab-alerts
# Expected: {"code":40301,"http":403,"error":"forbidden"}

# Check existing ntfy users
kubectl exec -n ntfy deployment/ntfy -- ntfy user list 2>/dev/null || echo "Check ntfy logs for user info"
```

## Implementation Steps

### Step 1: Create ntfy User for Alertmanager

```bash
# Generate a secure password
PASSWORD=$(openssl rand -base64 24)
echo "Generated password: $PASSWORD"

# Create the alertmanager user in ntfy
kubectl exec -n ntfy deployment/ntfy -- ntfy user add alertmanager

# Grant write permission to the homelab-alerts topic
kubectl exec -n ntfy deployment/ntfy -- ntfy access alertmanager homelab-alerts write

# Verify user was created
kubectl exec -n ntfy deployment/ntfy -- ntfy user list
```

### Step 2: Create Kubernetes Secret for Password

```bash
# Create the secret in monitoring namespace
kubectl create secret generic ntfy-alertmanager-password \
  -n monitoring \
  --from-literal=password="${PASSWORD}"

# Verify secret exists
kubectl get secret ntfy-alertmanager-password -n monitoring
```

### Step 3: Update Alertmanager Configuration

Update `terraform/environments/chocolandiadc-mvp/monitoring.tf` to include basic auth in the webhook config:

```hcl
receivers = [
  {
    name = "ntfy-homelab"
    webhook_configs = [
      {
        url           = "http://ntfy.ntfy.svc.cluster.local/homelab-alerts?template=alertmanager"
        http_config = {
          basic_auth = {
            username      = "alertmanager"
            password_file = "/etc/alertmanager/secrets/ntfy-alertmanager-password/password"
          }
        }
        send_resolved = true
      }
    ]
  }
]
```

### Step 4: Mount Secret in Alertmanager

Add to the Alertmanager spec in the Helm values:

```hcl
alertmanager = {
  alertmanagerSpec = {
    secrets = ["ntfy-alertmanager-password"]
  }
}
```

### Step 5: Add Homepage Alerts Widget

Update `terraform/modules/homepage/configs/services.yaml` to add the alerts widget in the Cluster Health section:

```yaml
- Cluster Health:
    - Cluster Alerts:
        icon: mdi-alert-circle
        href: https://grafana.chocolandiadc.com/alerting/list
        description: "Active Prometheus alerts"
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

### Step 6: Apply Changes

```bash
cd terraform/environments/chocolandiadc-mvp

# Source environment
source backend-env.sh

# Plan changes
tofu plan

# Apply
tofu apply
```

## Validation

### Test Notification Delivery

```bash
# Trigger a test alert manually using curl with auth
kubectl exec -n ntfy deployment/ntfy -- \
  curl -u "alertmanager:${PASSWORD}" \
  -H "Title: Test Alert" \
  -H "Priority: high" \
  -d "This is a test notification from Alertmanager" \
  http://localhost/homelab-alerts

# Check ntfy logs for successful delivery
kubectl logs -n ntfy deployment/ntfy --tail=10 | grep homelab-alerts
```

### Verify Homepage Widget

1. Open Homepage dashboard: https://homepage.chocolandiadc.com
2. Look for "Cluster Alerts" in the Cluster Health section
3. Verify it shows "Critical: 0" and "Warning: X" counts

### Test End-to-End

```bash
# Create a test PrometheusRule that will fire immediately
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-alert
  namespace: monitoring
  labels:
    prometheus: kube-prometheus-stack
    release: kube-prometheus-stack
spec:
  groups:
    - name: test
      rules:
        - alert: TestAlertForNtfy
          expr: vector(1)
          for: 0m
          labels:
            severity: warning
          annotations:
            summary: "Test alert for ntfy integration"
            description: "This is a test alert to verify ntfy notifications work"
EOF

# Wait 1-2 minutes for alert to fire and notification to be sent
# Check your ntfy mobile app or https://ntfy.chocolandiadc.com

# Clean up test alert
kubectl delete prometheusrule test-alert -n monitoring
```

## Troubleshooting

### Quick Diagnostics

```bash
# Check Alertmanager webhook logs for ntfy calls
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=100 | grep -iE "webhook|http|send|ntfy"

# Check ntfy server stats (shows messages_published count)
kubectl logs -n ntfy deployment/ntfy --tail=10 | grep "Server stats"
# Look for: "messages_published": N - should increase when alerts fire

# Verify Alertmanager secret is mounted
kubectl exec -n monitoring $(kubectl get pod -n monitoring -l app.kubernetes.io/name=alertmanager -o jsonpath='{.items[0].metadata.name}') -- \
  cat /etc/alertmanager/secrets/ntfy-alertmanager-password/password

# Test ntfy auth from within the cluster (use temp curl pod)
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -u admin:PASSWORD -d "Test from cluster" http://ntfy.ntfy.svc.cluster.local/homelab-alerts
```

### Notifications Not Arriving

1. Check Alertmanager logs:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=50
   ```

2. Check if secret is mounted:
   ```bash
   kubectl exec -n monitoring $(kubectl get pod -n monitoring -l app.kubernetes.io/name=alertmanager -o jsonpath='{.items[0].metadata.name}') -- \
     ls -la /etc/alertmanager/secrets/ntfy-alertmanager-password/
   ```

3. Verify ntfy can receive authenticated requests (requires temp pod since ntfy lacks curl):
   ```bash
   # Get the password from the secret
   PASSWORD=$(kubectl get secret ntfy-alertmanager-password -n monitoring -o jsonpath='{.data.password}' | base64 -d)

   # Test with a temporary curl pod
   kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
     curl -u "admin:${PASSWORD}" -H "Title: Test Alert" -d "Test notification" \
     http://ntfy.ntfy.svc.cluster.local/homelab-alerts
   ```

4. Check ntfy message count is increasing:
   ```bash
   # Run twice with 1-2 minute gap while alerts are firing
   kubectl logs -n ntfy deployment/ntfy --tail=5 | grep messages_published
   ```

### Homepage Widget Shows Error

1. Test Prometheus connectivity from Homepage pod:
   ```bash
   kubectl exec -n homepage deployment/homepage -- \
     wget -qO- "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up"
   ```

2. Verify the PromQL query returns data:
   ```bash
   kubectl exec -n homepage deployment/homepage -- \
     wget -qO- 'http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=count(ALERTS\{alertstate="firing"\})%20or%20vector(0)'
   ```

3. Force Homepage pod restart to pick up ConfigMap changes:
   ```bash
   kubectl rollout restart deployment/homepage -n homepage
   kubectl rollout status deployment/homepage -n homepage
   ```

### Common Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| 403 Forbidden in ntfy | Missing/wrong auth | Verify secret password matches ntfy user password |
| Alertmanager pod CrashLoopBackOff | Secret not found | Create `ntfy-alertmanager-password` secret in monitoring namespace |
| Widget shows "Error" | Prometheus unreachable | Check service name and namespace in URL |
| messages_published not increasing | Alerts not firing | Check Alertmanager for active alerts: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093` |

### Key Endpoints

| Service | Internal URL | Port-Forward Command |
|---------|--------------|---------------------|
| ntfy | http://ntfy.ntfy.svc.cluster.local | `kubectl port-forward -n ntfy svc/ntfy 8080:80` |
| Alertmanager | http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093 | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093` |
| Prometheus | http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090 | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090` |
