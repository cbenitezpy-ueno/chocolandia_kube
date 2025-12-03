# Quickstart: Home Assistant with Prometheus Temperature Monitoring

**Feature**: 018-home-assistant
**Date**: 2025-12-02
**Scope**: Phase 1 - Base Installation + Prometheus Integration

## Prerequisites

Before deploying, ensure you have:

1. **Prometheus**: Running and scraping node_exporter temperature metrics
2. **cert-manager**: Both `local-ca` and `letsencrypt-production` ClusterIssuers configured
3. **local-path-provisioner**: For PVC provisioning

## Quick Deployment

### 1. Deploy via OpenTofu

```bash
cd terraform/environments/chocolandiadc-mvp

# Initialize if needed
tofu init

# Preview changes
tofu plan -target=module.home_assistant

# Apply
tofu apply -target=module.home_assistant
```

### 2. Verify Deployment

```bash
# Pod status
kubectl get pods -n home-assistant

# Wait for pod to be Running
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=home-assistant -n home-assistant --timeout=120s

# Check ingress
kubectl get ingress -n home-assistant
```

### 3. Initial Home Assistant Setup

1. Access Home Assistant at: `https://homeassistant.chocolandiadc.local`
2. Create admin account on first launch
3. Complete onboarding wizard (name, location, units)

### 4. Install HACS

```bash
# Connect to Home Assistant pod
kubectl exec -it -n home-assistant deploy/home-assistant -- bash

# Download and install HACS
wget -O - https://get.hacs.xyz | bash -

# Exit pod
exit

# Restart pod to load HACS
kubectl rollout restart -n home-assistant deploy/home-assistant
```

After restart (~60 seconds), add HACS integration:
1. Settings → Devices & Services → Add Integration
2. Search for "HACS"
3. Follow GitHub authentication prompts (optional but recommended)

### 5. Install Prometheus Sensor via HACS

1. Go to HACS → Integrations → ⋮ (menu) → Custom repositories
2. Add repository: `https://github.com/mweinelt/ha-prometheus-sensor`
3. Category: Integration
4. Click "Add"
5. Search for "Prometheus Sensor" and install
6. Restart Home Assistant:
   ```bash
   kubectl rollout restart -n home-assistant deploy/home-assistant
   ```

### 6. Configure Prometheus Sensor

After restart, add to `/config/configuration.yaml` via File Editor or kubectl:

```bash
kubectl exec -it -n home-assistant deploy/home-assistant -- bash -c 'cat >> /config/configuration.yaml << EOF

sensor:
  - platform: prometheus_sensor
    url: "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
    queries:
      - name: "Node CPU Temperature"
        unique_id: node_cpu_temperature
        expr: max(node_hwmon_temp_celsius{job="node-exporter"})
        unit_of_measurement: "°C"
        device_class: temperature
        state_class: measurement
EOF'
```

Restart Home Assistant to apply:
```bash
kubectl rollout restart -n home-assistant deploy/home-assistant
```

### 7. Verify Temperature Sensor

1. Navigate to Home Assistant dashboard
2. Go to Settings → Devices & Services → Entities
3. Search for "node_cpu_temperature"
4. Verify sensor shows numeric value (e.g., 45.0)

### 8. Add Dashboard Card

1. Go to Overview dashboard
2. Click ⋮ → Edit Dashboard → Add Card
3. Select "Sensor" card
4. Choose entity: `sensor.node_cpu_temperature`
5. Save

## Verification Checklist

```bash
# 1. Pod is running
kubectl get pods -n home-assistant

# 2. PVC is bound
kubectl get pvc -n home-assistant

# 3. Ingress has address
kubectl get ingress -n home-assistant

# 4. Certificates are ready
kubectl get certificates -n home-assistant

# 5. Logs show no errors
kubectl logs -n home-assistant deploy/home-assistant --tail=20
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Pod CrashLoopBackOff | Check PVC is bound: `kubectl get pvc -n home-assistant` |
| Ingress not working | Verify certificates: `kubectl get certificates -n home-assistant` |
| Prometheus sensor unavailable | Test PromQL in Grafana: `max(node_hwmon_temp_celsius{job="node-exporter"})` |
| HACS not appearing | Verify HACS installed: check `/config/custom_components/hacs/` exists |
| Sensor shows "unknown" | Check Prometheus URL is reachable from HA pod |

## URLs

| Service | URL |
|---------|-----|
| Home Assistant (local) | https://homeassistant.chocolandiadc.local |
| Home Assistant (external) | https://homeassistant.chocolandiadc.com |
| Prometheus (internal) | http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090 |

## Phase 2 (Manual - Deferred)

After Phase 1 is complete, you can manually add:
- Govee smart plug integration via HACS or Alexa
- Temperature-based automations (ON at 50°C, OFF at 45°C)
- Ntfy push notifications
