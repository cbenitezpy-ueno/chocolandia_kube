# Data Model: Monitoring Stack Upgrade

**Feature**: 021-monitoring-stack-upgrade
**Date**: 2025-12-27

## Overview

Este documento describe las entidades de configuración involucradas en el upgrade del stack de monitoreo. El modelo se centra en los recursos de Kubernetes y configuraciones de Helm que deben ser modificados o preservados.

---

## Core Entities

### 1. Helm Release Configuration

**Entity**: `helm_release.kube_prometheus_stack`
**Location**: `terraform/environments/chocolandiadc-mvp/monitoring.tf`

| Field | Current Value | Target Value | Change Type |
|-------|--------------|--------------|-------------|
| `version` | `55.5.0` | `68.4.0` | MODIFY |
| `prometheus.prometheusSpec.retention` | `15d` | `15d` | PRESERVE |
| `prometheus.prometheusSpec.storageSpec...storage` | `10Gi` | `10Gi` | PRESERVE |
| `grafana.service.type` | `NodePort` | `NodePort` | PRESERVE |
| `grafana.service.nodePort` | `30000` | `30000` | PRESERVE |
| `grafana.persistence.enabled` | `true` | `true` | PRESERVE |
| `prometheus-node-exporter.hostNetwork` | `false` | `false` | PRESERVE (explicit) |
| `prometheus-node-exporter.hostPID` | `false` | `false` | PRESERVE (explicit) |

### 2. Alertmanager Configuration

**Entity**: `alertmanager.config` (embedded in Helm values)
**Location**: `monitoring.tf` → `values` block

```yaml
alertmanager:
  alertmanagerSpec:
    alertmanagerConfigMatcherStrategy:
      type: "None"  # PRESERVE
  config:
    global:
      resolve_timeout: "5m"  # PRESERVE
    route:
      receiver: "ntfy-homelab"  # PRESERVE
      group_by: ["alertname", "namespace", "severity"]  # PRESERVE
      group_wait: "30s"  # PRESERVE
      group_interval: "5m"  # PRESERVE
      repeat_interval: "4h"  # PRESERVE
    receivers:  # VALIDATE - may need structure changes
      - name: "null"
      - name: "ntfy-homelab"
        webhook_configs:
          - url: "http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
            send_resolved: true
      - name: "ntfy-critical"
        webhook_configs:
          - url: "http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
            send_resolved: true
```

### 3. Grafana Sidecar Configuration

**Entity**: `grafana.sidecar` (embedded in Helm values)
**Location**: `monitoring.tf` → `values` block

| Field | Current Value | Target Value | Validation |
|-------|--------------|--------------|------------|
| `dashboards.enabled` | `true` | `true` | PRESERVE |
| `dashboards.label` | `grafana_dashboard` | `grafana_dashboard` | VERIFY |
| `dashboards.labelValue` | `"1"` | `"1"` or `"true"` | VERIFY |
| `dashboards.searchNamespace` | `"ALL"` | `"ALL"` | PRESERVE |

### 4. Dashboard ConfigMaps

**Entity**: `kubernetes_config_map` (custom dashboards)
**Instances**: 38+ ConfigMaps across namespaces

**Structure**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <dashboard-name>
  namespace: <namespace>
  labels:
    grafana_dashboard: "1"  # Required for sidecar detection
data:
  <dashboard-name>.json: |
    { ... dashboard JSON ... }
```

**Categories**:

| Category | Count | Owner | Action |
|----------|-------|-------|--------|
| Chart-provided | ~30 | kube-prometheus-stack | AUTO-UPDATE |
| Custom via OpenTofu | 1 | monitoring.tf | PRESERVE |
| Custom via other modules | 7 | Various modules | PRESERVE |

### 5. ServiceMonitor Resources

**Entity**: `ServiceMonitor` (Prometheus Operator CRD)
**Instances**: 20+ across namespaces

**Structure**:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <service-name>
  namespace: <namespace>
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: <app-label>
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

**Ownership**:

| Namespace | Count | Owner | Action |
|-----------|-------|-------|--------|
| monitoring | 10+ | kube-prometheus-stack chart | AUTO-UPDATE |
| argocd | 6 | argocd module | VERIFY compatibility |
| beersystem | 1 | beersystem deployment | VERIFY compatibility |
| cert-manager | 1 | cert-manager chart | VERIFY compatibility |
| longhorn-system | 1 | longhorn chart | VERIFY compatibility |
| minio | 1 | minio module | VERIFY compatibility |

---

## State Transitions

### Upgrade State Machine

```
[CURRENT]           [PRE-UPGRADE]         [UPGRADING]          [POST-UPGRADE]
v55.5.0             v55.5.0 + backups     v68.4.0 deploying    v68.4.0
    |                    |                     |                    |
    +-- Backup --------->+                     |                    |
                         |                     |                    |
                         +-- tofu apply ------>+                    |
                                               |                    |
                                               +-- Pods Ready ----->+
                                               |                    |
                                               +-- Validation ----->+
                                                     |
                                                     v
                                               [VALIDATED] or [ROLLBACK]
```

### Pod State During Upgrade

| Pod Type | Expected Behavior | Downtime |
|----------|------------------|----------|
| prometheus-server | Rolling update, 1 replica | ~2-3 min |
| grafana | Rolling update, 1 replica | ~1-2 min |
| alertmanager | Rolling update, 1 replica | ~1-2 min |
| node-exporter | DaemonSet update, rolling | < 1 min per node |
| kube-state-metrics | Rolling update | ~1 min |

---

## Validation Rules

### Pre-Upgrade Checks

| Check | Command | Expected Result |
|-------|---------|-----------------|
| Current version | `helm list -n monitoring` | Chart version 55.5.0 |
| Pods healthy | `kubectl get pods -n monitoring` | All Running |
| Metrics available | `curl prometheus:9090/api/v1/query?query=up` | Non-empty results |
| Dashboards count | `kubectl get cm -n monitoring -l grafana_dashboard=1 --no-headers \| wc -l` | >= 38 |

### Post-Upgrade Checks

| Check | Command | Expected Result |
|-------|---------|-----------------|
| New version | `helm list -n monitoring` | Chart version 68.4.0 |
| All pods Running | `kubectl get pods -n monitoring` | All Running, no restarts |
| Retention preserved | `kubectl get prometheus -n monitoring -o yaml \| grep retention` | `15d` |
| NodePort preserved | `kubectl get svc -n monitoring kube-prometheus-stack-grafana` | NodePort 30000 |
| Dashboards loaded | Grafana UI → Dashboards | All 6+ dashboards visible |
| Alerts functional | Send test alert | Received in Ntfy |

---

## Relationships

```
                    ┌─────────────────────────────────────┐
                    │     helm_release.kube_prometheus    │
                    │            (monitoring.tf)          │
                    └─────────────┬───────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
          v                       v                       v
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Prometheus   │    │     Grafana     │    │  Alertmanager   │
│   (StatefulSet) │    │   (Deployment)  │    │   (StatefulSet) │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         v                      v                      v
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ ServiceMonitors │    │ Dashboard CMs   │    │  AlertRules     │
│   (20+ CRDs)    │    │ (38+ ConfigMaps)│    │   (CRDs)        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                      │                      │
         v                      v                      v
    [Metrics]             [Visualizations]        [Ntfy Webhook]
```

---

## Data Preservation

### Critical Data to Preserve

| Data Type | Location | Backup Method | Recovery |
|-----------|----------|---------------|----------|
| Prometheus TSDB | PVC `prometheus-kube-prometheus-stack-prometheus-db-*` | Longhorn snapshot | Restore PVC |
| Grafana SQLite | PVC `kube-prometheus-stack-grafana` | Longhorn snapshot | Restore PVC |
| Helm values | `helm get values` output | File backup | `helm upgrade --reuse-values` |
| Custom dashboards | OpenTofu state | Git repository | `tofu apply` |
| ServiceMonitors | Kubernetes etcd | `kubectl get -o yaml` | `kubectl apply` |

### Data NOT Affected by Upgrade

- Custom ServiceMonitors (external namespaces)
- PersistentVolumeClaims (storage preserved)
- ConfigMaps with custom dashboards (not part of chart)
- Ntfy configuration (external service)
