# Research: Home Assistant with Prometheus Temperature Monitoring

**Feature**: 018-home-assistant
**Date**: 2025-12-02
**Status**: Complete
**Scope**: Phase 1 - Base Installation + Prometheus Integration (Govee deferred)

## Research Topics

### 1. Home Assistant Kubernetes Deployment

**Decision**: Deploy Home Assistant Core as a container using official image `ghcr.io/home-assistant/home-assistant:stable`

**Rationale**:
- Official OCI-compatible image maintained by Home Assistant team
- Lightweight compared to Home Assistant OS (no VM required)
- Compatible with K3s and standard Kubernetes deployments
- Exposes port 8123 for web UI

**Alternatives Considered**:
| Alternative | Rejected Because |
|------------|------------------|
| Home Assistant OS (VM) | Requires hypervisor, not native K8s deployment |
| Home Assistant Supervised | Requires Debian host, complex for K8s |
| Helm chart (unofficial) | No official Helm chart exists, custom manifest preferred for learning |

**Configuration**:
- Container port: 8123
- Minimum resources: 512Mi RAM, 250m CPU (requests)
- Maximum resources: 2Gi RAM, 2000m CPU (limits)
- Config directory: `/config` (mount PersistentVolume here)
- Health check: HTTP GET `/` on port 8123

**Sources**:
- [Home Assistant Linux Installation](https://www.home-assistant.io/installation/linux)

---

### 2. Reading Prometheus Metrics into Home Assistant

**Decision**: Use `ha-prometheus-sensor` custom integration via HACS to query Prometheus metrics

**Rationale**:
- Native Home Assistant Prometheus integration only EXPORTS metrics (one-way)
- `ha-prometheus-sensor` allows PromQL queries against external Prometheus
- Creates Home Assistant sensors from Prometheus metrics
- Supports async queries via aiohttp
- Compatible with Prometheus, VictoriaMetrics, and Mimir

**Alternatives Considered**:
| Alternative | Rejected Because |
|------------|------------------|
| Built-in Prometheus integration | Only exports metrics TO Prometheus, cannot read |
| REST sensor with manual HTTP | More complex, requires manual JSON parsing |
| Command line sensor with curl | Not async, blocks HA event loop |

**Configuration**:
```yaml
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
```

**Sources**:
- [ha-prometheus-sensor GitHub](https://github.com/mweinelt/ha-prometheus-sensor)

---

### 3. HACS (Home Assistant Community Store) Installation

**Decision**: Install HACS via kubectl exec as post-deployment step

**Rationale**:
- Required for installing `ha-prometheus-sensor`
- Standard method for custom integrations in HA community
- One-time setup, persists across restarts via PVC

**Installation Method**:
```bash
# Connect to Home Assistant pod
kubectl exec -it -n home-assistant deploy/home-assistant -- bash

# Download and install HACS
wget -O - https://get.hacs.xyz | bash -

# Exit and restart pod
exit
kubectl rollout restart -n home-assistant deploy/home-assistant
```

**Post-Installation**:
1. Add HACS integration via UI (Settings → Devices & Services → Add Integration → HACS)
2. Follow GitHub authentication prompts (optional but recommended)

---

### 4. Traefik Ingress with Dual Certificates

**Decision**: Create two Ingress resources for `.local` (local-ca) and `.com` (letsencrypt) domains

**Rationale**:
- Existing cluster pattern for dual-domain services (e.g., Nexus)
- Local-ca for internal network access (no internet dependency)
- Let's Encrypt for external access via Cloudflare Zero Trust
- cert-manager handles certificate issuance automatically

**Configuration Pattern**:
```yaml
# Local domain - uses self-signed CA
metadata:
  annotations:
    cert-manager.io/cluster-issuer: local-ca
spec:
  rules:
    - host: homeassistant.chocolandiadc.local

# External domain - uses Let's Encrypt
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  rules:
    - host: homeassistant.chocolandiadc.com
```

---

### 5. Temperature Metric Selection

**Decision**: Use `node_hwmon_temp_celsius` from node_exporter with max() aggregation

**Rationale**:
- Standard metric exposed by node_exporter on all nodes
- Hardware monitoring subsystem provides accurate CPU temperature
- max() aggregation gives highest temperature across all nodes/cores

**PromQL Query**:
```promql
max(node_hwmon_temp_celsius{job="node-exporter"})
```

**Verification Command**:
```bash
# Test query in Prometheus
kubectl exec -n monitoring deploy/prometheus-kube-prometheus-prometheus -- \
  wget -qO- "http://localhost:9090/api/v1/query?query=max(node_hwmon_temp_celsius)"
```

---

### 6. PersistentVolume Configuration

**Decision**: 10Gi PVC with local-path-provisioner, ReadWriteOnce access mode

**Rationale**:
- Home Assistant stores configuration, database, and custom components in /config
- 10Gi provides ample space for HACS integrations and history database
- ReadWriteOnce is sufficient for single-replica deployment
- local-path-provisioner is already deployed in cluster

**Deployment Strategy**: Recreate (not RollingUpdate) to avoid PVC mount conflicts

---

## Summary of Key Decisions (Phase 1)

| Topic | Decision | Key Integration |
|-------|----------|-----------------|
| Deployment | Container on K3s | `ghcr.io/home-assistant/home-assistant:stable` |
| Prometheus Reading | ha-prometheus-sensor | HACS custom component |
| Custom Components | HACS | kubectl exec install |
| Ingress | Dual Traefik Ingress | local-ca + letsencrypt |
| Storage | 10Gi PVC | local-path-provisioner |

## Dependencies for Phase 1

1. **HACS Installation**: Required before Prometheus sensor integration
2. **Prometheus Endpoint**: `http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090`
3. **cert-manager**: Both ClusterIssuers (local-ca, letsencrypt-production) must be configured
4. **local-path-provisioner**: For PVC provisioning

## Deferred to Phase 2 (Manual)

| Topic | Notes |
|-------|-------|
| Govee Integration | User will configure via HACS or Alexa |
| Ntfy Notifications | Optional, depends on automation needs |
| Temperature Automation | ON at 50°C, OFF at 45°C |
