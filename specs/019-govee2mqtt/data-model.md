# Data Model: Govee2MQTT Integration

**Feature**: 019-govee2mqtt
**Date**: 2025-12-04

## Overview

Este feature no introduce entidades de base de datos tradicionales. En su lugar, define recursos de Kubernetes y configuración MQTT. Las "entidades" son recursos de infraestructura.

## Kubernetes Resources

### 1. Mosquitto MQTT Broker

```yaml
# Namespace: home-assistant (existing)

# Deployment
mosquitto:
  replicas: 1
  image: eclipse-mosquitto:latest
  ports:
    - 1883 (MQTT)
    - 9001 (WebSockets, optional)
  volumes:
    - config: /mosquitto/config
    - data: /mosquitto/data
    - log: /mosquitto/log

# Service (ClusterIP)
mosquitto-svc:
  type: ClusterIP
  ports:
    - 1883:1883

# ConfigMap
mosquitto-config:
  mosquitto.conf: |
    listener 1883
    allow_anonymous true
    persistence true
    persistence_location /mosquitto/data/

# PersistentVolumeClaim
mosquitto-data:
  storage: 1Gi
  storageClass: local-path
```

### 2. Govee2MQTT Bridge

```yaml
# Namespace: home-assistant (existing)

# Deployment
govee2mqtt:
  replicas: 1
  image: ghcr.io/wez/govee2mqtt:latest
  hostNetwork: true  # Required for LAN discovery
  env:
    - GOVEE_API_KEY: (from Secret)
    - GOVEE_MQTT_HOST: mosquitto.home-assistant.svc.cluster.local
    - GOVEE_MQTT_PORT: "1883"
    - TZ: America/Asuncion

# Secret
govee-credentials:
  GOVEE_API_KEY: <base64-encoded>
  GOVEE_EMAIL: <base64-encoded> (optional)
  GOVEE_PASSWORD: <base64-encoded> (optional)
```

## MQTT Topic Structure

govee2mqtt publica dispositivos usando MQTT discovery de Home Assistant:

```
# Discovery topics (auto-created by govee2mqtt)
homeassistant/light/<device_id>/config    # Device configuration
homeassistant/light/<device_id>/state     # Current state
homeassistant/light/<device_id>/set       # Command topic

# Example device state payload
{
  "state": "ON",
  "brightness": 255,
  "color": {"r": 255, "g": 100, "b": 50},
  "color_temp": 370
}
```

## Entity Relationships

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Govee Device   │────▶│   govee2mqtt    │────▶│    Mosquitto    │
│  (Physical)     │ LAN │   (Bridge)      │MQTT │    (Broker)     │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │ MQTT
                                                         ▼
                                                ┌─────────────────┐
                                                │  Home Assistant │
                                                │   (Consumer)    │
                                                └─────────────────┘
```

## State Transitions

### Govee Device States

| State | Description | MQTT Value |
|-------|-------------|------------|
| ON | Device is powered on | `"ON"` |
| OFF | Device is powered off | `"OFF"` |
| UNAVAILABLE | Device not responding | (no message / LWT) |

### Service States

| Component | Healthy | Unhealthy |
|-----------|---------|-----------|
| Mosquitto | Pod Running, Port 1883 responding | Pod CrashLoopBackOff |
| govee2mqtt | Pod Running, devices discovered | Pod CrashLoopBackOff, no devices |

## Validation Rules

### Govee Credentials
- `GOVEE_API_KEY`: Must be valid UUID format (8-4-4-4-12)
- `GOVEE_EMAIL`: Valid email format (optional)
- `GOVEE_PASSWORD`: Non-empty string if email provided

### MQTT Configuration
- `GOVEE_MQTT_HOST`: Valid DNS name or IP
- `GOVEE_MQTT_PORT`: Integer 1-65535 (default: 1883)

## Configuration Schema

```yaml
# Module variables for OpenTofu

mosquitto:
  namespace: string (default: "home-assistant")
  storage_size: string (default: "1Gi")
  storage_class: string (default: "local-path")
  image: string (default: "eclipse-mosquitto:latest")

govee2mqtt:
  namespace: string (default: "home-assistant")
  image: string (default: "ghcr.io/wez/govee2mqtt:latest")
  govee_api_key: string (sensitive, required)
  govee_email: string (sensitive, optional)
  govee_password: string (sensitive, optional)
  mqtt_host: string (default: "mosquitto.home-assistant.svc.cluster.local")
  mqtt_port: number (default: 1883)
  timezone: string (default: "America/Asuncion")
```
