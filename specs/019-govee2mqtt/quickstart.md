# Quickstart: Govee2MQTT Integration

**Feature**: 019-govee2mqtt
**Date**: 2025-12-04

## Prerequisites

Before starting, ensure you have:

1. **Govee API Key**: Obtain from [Govee Developer Portal](https://developer.govee.com/)
2. **K3s cluster** running with Home Assistant deployed
3. **Govee devices** with LAN API enabled (in Govee app: Device → Settings → Enable LAN Control)
4. **OpenTofu** installed locally

## Quick Deploy

### Step 1: Set Environment Variables

```bash
export TF_VAR_govee_api_key="<YOUR_GOVEE_API_KEY>"
# Optional: If you want IoT features (scenes, music modes)
# export TF_VAR_govee_email="your-email@example.com"
# export TF_VAR_govee_password="your-password"
```

### Step 2: Deploy Infrastructure

```bash
cd terraform/environments/chocolandiadc-mvp

# Initialize (if needed)
tofu init

# Plan and review
tofu plan -target=module.mosquitto -target=module.govee2mqtt

# Apply
tofu apply -target=module.mosquitto -target=module.govee2mqtt
```

### Step 3: Verify Deployment

```bash
# Check pods are running
kubectl get pods -n home-assistant -l 'app.kubernetes.io/name in (mosquitto,govee2mqtt)'

# Check Mosquitto service
kubectl get svc -n home-assistant mosquitto

# View govee2mqtt logs (should show device discovery)
kubectl logs -n home-assistant -l app.kubernetes.io/name=govee2mqtt -f
```

### Step 4: Configure Home Assistant MQTT

1. Open Home Assistant: https://ha.chocolandiadc.local
2. Navigate to: **Settings** → **Devices & Services** → **Add Integration**
3. Search for: **MQTT**
4. Configure broker:
   - **Broker**: `mosquitto.home-assistant.svc.cluster.local`
   - **Port**: `1883`
   - **Username**: (leave empty)
   - **Password**: (leave empty)
5. Click **Submit**

### Step 5: Verify Devices

After MQTT is configured:

1. Go to: **Settings** → **Devices & Services** → **MQTT**
2. Click on **devices** count
3. Your Govee devices should appear automatically

## Troubleshooting

### No devices discovered

```bash
# Check govee2mqtt logs for errors
kubectl logs -n home-assistant -l app.kubernetes.io/name=govee2mqtt --tail=100

# Common issues:
# - "Invalid API key" → verify GOVEE_API_KEY is correct
# - "No devices found" → ensure LAN Control is enabled on Govee devices
# - "MQTT connection failed" → verify Mosquitto is running
```

### MQTT connection issues

```bash
# Test MQTT broker connectivity
kubectl run mqtt-test --rm -it --image=eclipse-mosquitto:latest --restart=Never -- \
  mosquitto_pub -h mosquitto.home-assistant.svc.cluster.local -t test -m "hello"

# Check Mosquitto logs
kubectl logs -n home-assistant -l app.kubernetes.io/name=mosquitto --tail=50
```

### Devices not appearing in Home Assistant

```bash
# Subscribe to MQTT discovery topics
kubectl run mqtt-sub --rm -it --image=eclipse-mosquitto:latest --restart=Never -- \
  mosquitto_sub -h mosquitto.home-assistant.svc.cluster.local -t 'homeassistant/#' -v

# You should see config messages for each device
```

## Expected Behavior

After successful deployment:

- Mosquitto pod running in `home-assistant` namespace
- govee2mqtt pod running with hostNetwork
- Govee devices auto-discovered within 2-5 minutes
- Devices controllable from Home Assistant dashboard
- State changes reflected in < 2 seconds (LAN devices)

## Cleanup

To remove the deployment:

```bash
cd terraform/environments/chocolandiadc-mvp
tofu destroy -target=module.govee2mqtt -target=module.mosquitto
```

## Next Steps

1. Add Govee devices to Home Assistant dashboard
2. Create automations using Govee devices
3. Set up scenes combining Govee with other devices
4. Configure notifications for device state changes
