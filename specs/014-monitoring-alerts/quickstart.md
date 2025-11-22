# Quickstart: Monitoring & Alerting System

**Feature**: 014-monitoring-alerts
**Date**: 2025-11-22

## Prerequisites

Before starting, ensure you have:

- [ ] K3s cluster running (4 nodes: master1, nodo03, nodo1, nodo04)
- [ ] kubectl configured with cluster access
- [ ] OpenTofu 1.6+ installed
- [ ] Helm 3.x installed
- [ ] Traefik ingress controller deployed
- [ ] cert-manager with ClusterIssuer configured
- [ ] Cloudflare Access configured (for external access)

## Quick Deploy (TL;DR)

```bash
# From repo root
cd terraform/environments/chocolandiadc-mvp

# Deploy monitoring stack
tofu init
tofu plan -target=module.prometheus_stack -target=module.ntfy
tofu apply -target=module.prometheus_stack -target=module.ntfy

# Verify deployment
kubectl get pods -n monitoring
kubectl get pods -n ntfy

# Subscribe to alerts (on your phone)
# 1. Install Ntfy app from App Store/Play Store
# 2. Subscribe to: https://ntfy.chocolandia.com/homelab-alerts

# Test alerting
./scripts/monitoring/test-alerts.sh
```

## Step-by-Step Deployment

### Step 1: Deploy Prometheus Stack

```bash
# Navigate to environment
cd terraform/environments/chocolandiadc-mvp

# Initialize if needed
tofu init

# Plan and review
tofu plan -target=module.prometheus_stack

# Apply
tofu apply -target=module.prometheus_stack
```

**Expected output:**
- Namespace `monitoring` created
- Prometheus, Grafana, Alertmanager pods running
- PersistentVolumeClaims bound

**Verify:**
```bash
kubectl get pods -n monitoring
# Expected: prometheus-*, grafana-*, alertmanager-* all Running

kubectl get pvc -n monitoring
# Expected: prometheus-* and alertmanager-* Bound
```

### Step 2: Deploy Ntfy

```bash
# Deploy Ntfy
tofu plan -target=module.ntfy
tofu apply -target=module.ntfy
```

**Verify:**
```bash
kubectl get pods -n ntfy
# Expected: ntfy-* Running

kubectl get ingress -n ntfy
# Expected: ntfy ingress with host ntfy.chocolandia.com
```

### Step 3: Configure Alertmanager -> Ntfy Integration

```bash
# Apply alert rules
kubectl apply -f specs/014-monitoring-alerts/contracts/alert-rules.yaml

# Verify rules loaded
kubectl get prometheusrule -n monitoring
```

### Step 4: Subscribe to Alerts

**Mobile App:**
1. Install Ntfy app (iOS App Store / Google Play Store)
2. Open app and tap "+" to subscribe
3. Enter topic: `homelab-alerts`
4. For external access: Use server `https://ntfy.chocolandia.com`

**Web Browser:**
1. Navigate to `https://ntfy.chocolandia.com`
2. Authenticate via Cloudflare Access
3. Subscribe to `homelab-alerts` topic

**curl (testing):**
```bash
# Subscribe and listen
curl -s https://ntfy.chocolandia.com/homelab-alerts/sse
```

### Step 5: Verify End-to-End

**Test alert delivery:**
```bash
# Send test notification
curl -X POST https://ntfy.chocolandia.com/homelab-alerts \
  -H "Title: Test Alert" \
  -H "Priority: 3" \
  -H "Tags: test" \
  -d "This is a test notification from the monitoring system"
```

**Trigger real alert (careful in production!):**
```bash
# Simulate node down by stopping node-exporter (DON'T do on control-plane)
kubectl scale deployment node-exporter -n monitoring --replicas=0

# Wait 2 minutes for alert to fire
# Check Alertmanager UI: https://alertmanager.chocolandia.com

# Restore
kubectl scale deployment node-exporter -n monitoring --replicas=1
```

## Access Points

| Service | Internal URL | External URL |
|---------|--------------|--------------|
| Prometheus | http://prometheus.monitoring.svc:9090 | https://prometheus.chocolandia.com |
| Grafana | http://grafana.monitoring.svc:3000 | https://grafana.chocolandia.com |
| Alertmanager | http://alertmanager.monitoring.svc:9093 | https://alertmanager.chocolandia.com |
| Ntfy | http://ntfy.ntfy.svc:80 | https://ntfy.chocolandia.com |

## Default Credentials

| Service | Username | Password Source |
|---------|----------|-----------------|
| Grafana | admin | `kubectl get secret -n monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" \| base64 -d` |

## Validation Checklist

After deployment, verify:

- [ ] Prometheus UI accessible and showing targets UP
- [ ] Grafana dashboards loading with data
- [ ] Alertmanager UI showing receiver configuration
- [ ] Ntfy accessible and accepting subscriptions
- [ ] Test notification received on mobile device
- [ ] Node metrics visible in Grafana
- [ ] Traefik metrics visible (golden signals)

## Troubleshooting

### Prometheus targets showing DOWN
```bash
# Check target endpoints
kubectl get endpoints -n monitoring

# Check service discovery
kubectl logs -n monitoring -l app=prometheus --tail=100 | grep -i "error\|warn"
```

### Alerts not reaching Ntfy
```bash
# Check Alertmanager logs
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=100

# Test webhook manually
kubectl exec -n monitoring -it deployment/alertmanager -- \
  wget -O- http://ntfy.ntfy.svc.cluster.local/homelab-alerts
```

### Grafana dashboards empty
```bash
# Verify Prometheus datasource
kubectl get configmap -n monitoring -l grafana_datasource=1

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=100
```

## Rollback

If something goes wrong:

```bash
# Uninstall Prometheus stack
tofu destroy -target=module.prometheus_stack

# Uninstall Ntfy
tofu destroy -target=module.ntfy

# Clean up PVCs manually if needed
kubectl delete pvc -n monitoring --all
kubectl delete pvc -n ntfy --all
```

## Next Steps

After successful deployment:

1. Configure additional alert rules for your specific services
2. Import custom Grafana dashboards
3. Set up alert silences for maintenance windows
4. Document runbooks for each alert type
5. Test disaster recovery (node failure, pod eviction)
