# Data Model: Home Assistant with Prometheus Temperature Monitoring

**Feature**: 018-home-assistant
**Date**: 2025-12-02
**Scope**: Phase 1 - Base Installation + Prometheus Integration

## Entities

### 1. Home Assistant Instance

| Attribute | Type | Description |
|-----------|------|-------------|
| name | string | Instance identifier (e.g., "home-assistant") |
| namespace | string | Kubernetes namespace (default: "home-assistant") |
| config_volume | PVC | Persistent storage for /config directory (10Gi) |
| service_port | int | Web UI port (8123) |
| ingress_hosts | list[string] | Exposed hostnames (local + external) |

**Relationships**:
- Has one → Prometheus Sensor (via HACS integration)
- Has one → PersistentVolumeClaim (config storage)

---

### 2. Prometheus Sensor

| Attribute | Type | Description |
|-----------|------|-------------|
| entity_id | string | sensor.node_cpu_temperature |
| prometheus_url | string | http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090 |
| promql_expr | string | max(node_hwmon_temp_celsius{job="node-exporter"}) |
| unit_of_measurement | string | °C |
| device_class | string | temperature |
| state_class | string | measurement |
| polling_interval | int | Update frequency in seconds (default: 30) |

**State Transitions**:
```
[unavailable] ---(prometheus responds)---> [numeric value]
[numeric value] ---(prometheus unreachable)---> [unavailable]
[numeric value] ---(metric not found)---> [unknown]
```

---

### 3. HACS Integration

| Attribute | Type | Description |
|-----------|------|-------------|
| installation_path | string | /config/custom_components/hacs/ |
| status | enum | not_installed, installed, needs_restart |
| custom_repositories | list[string] | URLs of custom repos added |

**State Transitions**:
```
[not_installed] ---(wget install script)---> [needs_restart]
[needs_restart] ---(pod restart)---> [installed]
[installed] ---(add repo)---> [installed]
```

---

## Kubernetes Resources

### Phase 1 Resources

| Resource | Name | Purpose |
|----------|------|---------|
| Namespace | home-assistant | Isolated namespace for HA |
| Deployment | home-assistant | Main application pod |
| Service | home-assistant | ClusterIP for internal access (port 8123) |
| PersistentVolumeClaim | home-assistant-config | Configuration storage (10Gi) |
| Ingress | home-assistant-local | Local domain access (.chocolandiadc.local) |
| Ingress | home-assistant-external | External domain access (.chocolandiadc.com) |

### Deferred Resources (Phase 2)

| Resource | Name | Purpose |
|----------|------|---------|
| Secret | home-assistant-secrets | Govee API key (when needed) |

---

## Validation Rules

1. **Prometheus URL**: Must be reachable from Home Assistant pod (cluster internal)
2. **Ingress Hosts**: Must match configured domains with valid TLS certificates
3. **PVC Size**: Minimum 10Gi for config persistence + HACS integrations
4. **Temperature Value**: Sensor must return numeric value (not "unavailable" or "unknown")

---

## Data Flow (Phase 1)

```
┌─────────────────────┐     PromQL Query      ┌──────────────────┐
│     Prometheus      │◄──────────────────────│  Home Assistant  │
│   (monitoring ns)   │   (every 30 seconds)  │                  │
│                     │                       │                  │
│  node_hwmon_temp_   │                       │  Dashboard:      │
│  celsius metric     │                       │  Temperature     │
└─────────────────────┘                       │  Sensor Card     │
                                              │                  │
                                              └────────┬─────────┘
                                                       │
                              ┌────────────────────────┼────────────────────────┐
                              │                        │                        │
                              ▼                        ▼                        ▼
                      ┌──────────────┐         ┌──────────────┐         ┌──────────────┐
                      │    Local     │         │   External   │         │   Grafana    │
                      │   Browser    │         │   Browser    │         │  (optional)  │
                      │ .local:8123  │         │ .com:443     │         │              │
                      └──────────────┘         └──────────────┘         └──────────────┘
```

---

## Entity ID Naming Convention

| Entity Type | Pattern | Example |
|-------------|---------|---------|
| Temperature Sensor | sensor.{source}_{metric} | sensor.node_cpu_temperature |
| HACS | update.hacs | update.hacs |
