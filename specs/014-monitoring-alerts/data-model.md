# Data Model: Monitoring & Alerting System

**Feature**: 014-monitoring-alerts
**Date**: 2025-11-22

## Overview

Este documento define las entidades de datos del sistema de monitoreo. No hay base de datos relacional involucrada - los datos son métricas de series temporales (Prometheus TSDB) y configuraciones (Kubernetes ConfigMaps/Secrets).

## Entities

### 1. Metric (Serie Temporal)

Representa un punto de datos recolectado por Prometheus.

| Field | Type | Description |
|-------|------|-------------|
| `__name__` | string | Nombre de la métrica (e.g., `node_cpu_seconds_total`) |
| `labels` | map[string]string | Labels para identificación (instance, job, namespace, pod) |
| `value` | float64 | Valor numérico de la métrica |
| `timestamp` | int64 | Unix timestamp en milisegundos |

**Ejemplos de Métricas Clave**:
```
# Nodo
node_cpu_seconds_total{cpu="0", mode="idle", instance="master1:9100"}
node_memory_MemAvailable_bytes{instance="master1:9100"}
node_filesystem_avail_bytes{device="/dev/sda1", instance="master1:9100"}

# Kubernetes
kube_node_status_condition{node="master1", condition="Ready", status="true"}
kube_deployment_status_replicas_available{deployment="beersystem-backend", namespace="beersystem"}
kube_pod_container_status_restarts_total{pod="xxx", namespace="beersystem"}

# Traefik (Golden Signals)
traefik_service_requests_total{service="beersystem-backend@kubernetes", code="200"}
traefik_service_request_duration_seconds_bucket{service="beersystem-backend@kubernetes", le="0.1"}
```

### 2. Alert Rule

Definición de una regla de alerta en Prometheus/Alertmanager.

| Field | Type | Description |
|-------|------|-------------|
| `alert` | string | Nombre de la alerta (e.g., `NodeDown`) |
| `expr` | string | Expresión PromQL que dispara la alerta |
| `for` | duration | Tiempo que debe mantenerse true antes de disparar |
| `labels.severity` | string | Nivel: `critical`, `warning`, `info` |
| `annotations.summary` | string | Resumen corto para notificación |
| `annotations.description` | string | Descripción detallada |

**Ejemplo**:
```yaml
- alert: NodeDown
  expr: up{job="node-exporter"} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Node {{ $labels.instance }} is down"
    description: "Node {{ $labels.instance }} has been unreachable for more than 1 minute."
```

### 3. Alert (Instancia Activa)

Una alerta que se ha disparado y está activa.

| Field | Type | Description |
|-------|------|-------------|
| `alertname` | string | Nombre de la regla que generó la alerta |
| `status` | string | `firing` o `resolved` |
| `startsAt` | timestamp | Cuándo comenzó a dispararse |
| `endsAt` | timestamp | Cuándo se resolvió (si resolved) |
| `labels` | map | Labels heredados de la regla + métrica |
| `annotations` | map | Anotaciones con contexto |
| `generatorURL` | string | Link a Prometheus con la query |

### 4. Notification (Mensaje a Ntfy)

Mensaje enviado a Ntfy para entrega al usuario.

| Field | Type | Description |
|-------|------|-------------|
| `topic` | string | Canal de Ntfy (e.g., `homelab-alerts`) |
| `title` | string | Título de la notificación |
| `message` | string | Cuerpo del mensaje |
| `priority` | int | 1-5 (1=min, 5=urgent) |
| `tags` | []string | Emojis/tags para categorización |
| `click` | string | URL al hacer click (link a Grafana) |

**Mapeo Severity → Priority**:
| Severity | Ntfy Priority | Tags |
|----------|---------------|------|
| critical | 5 (urgent) | `rotating_light`, `warning` |
| warning | 3 (default) | `warning` |
| info | 2 (low) | `information_source` |
| resolved | 2 (low) | `white_check_mark` |

### 5. Receiver Configuration

Configuración de destino de alertas en Alertmanager.

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Nombre del receiver (e.g., `ntfy-critical`) |
| `webhook_configs` | []object | Configuraciones de webhook |
| `webhook_configs[].url` | string | URL del endpoint Ntfy |
| `webhook_configs[].send_resolved` | bool | Enviar notificación cuando se resuelve |

### 6. Dashboard

Panel de Grafana para visualización.

| Field | Type | Description |
|-------|------|-------------|
| `uid` | string | Identificador único del dashboard |
| `title` | string | Nombre del dashboard |
| `panels` | []Panel | Lista de paneles/gráficos |
| `templating` | object | Variables para filtrado dinámico |
| `refresh` | string | Intervalo de actualización (e.g., `30s`) |

## Relationships

```
┌─────────────┐     scrapes      ┌─────────────┐
│   Target    │ ──────────────▶  │  Prometheus │
│ (node/pod)  │                  │   (TSDB)    │
└─────────────┘                  └──────┬──────┘
                                        │
                                        │ evaluates
                                        ▼
                                 ┌─────────────┐
                                 │ Alert Rules │
                                 └──────┬──────┘
                                        │
                                        │ fires
                                        ▼
                                 ┌─────────────┐
                                 │Alertmanager │
                                 └──────┬──────┘
                                        │
                                        │ routes to
                                        ▼
                                 ┌─────────────┐     delivers    ┌─────────────┐
                                 │  Receiver   │ ─────────────▶  │    Ntfy     │
                                 │ (webhook)   │                 │  (mobile)   │
                                 └─────────────┘                 └─────────────┘
```

## State Transitions

### Alert Lifecycle

```
[inactive] ──(condition true)──▶ [pending]
                                     │
                         (for duration elapsed)
                                     │
                                     ▼
                               [firing] ──(condition false)──▶ [resolved]
                                     │                              │
                          (still true)                    (after resolve delay)
                                     │                              │
                                     ▼                              ▼
                          [firing] (repeat)               [inactive]
```

### Notification Delivery States

```
[generated] ──(webhook POST)──▶ [sent to Ntfy]
                                     │
                          (Ntfy delivers)
                                     │
                                     ▼
                         [delivered to device]
```

## Validation Rules

### Alert Rules
- `expr` MUST be valid PromQL
- `for` MUST be >= 30s for non-critical alerts (avoid flapping)
- `severity` MUST be one of: `critical`, `warning`, `info`
- Critical alerts MUST have `for` <= 2m (fast response required)

### Notifications
- `priority` MUST be 1-5
- `topic` MUST match regex `^[a-zA-Z0-9_-]+$`
- `title` MUST be <= 256 characters
- `message` MUST be <= 4096 characters

### Metrics Retention
- Raw metrics: 7 days
- Downsampled (5m): Not configured (homelab scale doesn't require)
