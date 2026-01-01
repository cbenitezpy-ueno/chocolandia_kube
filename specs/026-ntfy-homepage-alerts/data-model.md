# Data Model: Fix Ntfy Notifications and Add Alerts to Homepage

**Feature**: 026-ntfy-homepage-alerts
**Date**: 2025-12-31

## Entities

### Alert (Prometheus/Alertmanager)

The core entity representing a monitoring alert in the system.

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| alertname | string | Unique identifier for the alert type | `NodeDown`, `RedisMemoryUsageHigh` |
| severity | enum | Alert severity level | `critical`, `warning`, `info` |
| status | enum | Current alert state | `firing`, `resolved` |
| namespace | string | Kubernetes namespace (if applicable) | `monitoring`, `redis` |
| instance | string | Target instance identifier | `192.168.4.101:9100` |
| summary | string | Human-readable alert title | "Node master1 is down" |
| description | string | Detailed alert message | "Node 192.168.4.101 has been unreachable for more than 5 minutes" |
| startsAt | timestamp | When the alert started firing | `2025-12-31T10:30:00Z` |
| endsAt | timestamp | When the alert resolved (if resolved) | `2025-12-31T10:45:00Z` |

### Notification (ntfy)

Message sent to ntfy for delivery to mobile/web clients.

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| topic | string | ntfy topic for routing | `homelab-alerts` |
| title | string | Notification title | "NodeDown - FIRING" |
| message | string | Notification body | "Node 192.168.4.101 has been unreachable..." |
| priority | enum | Notification priority (1-5) | `5` (max), `3` (default), `1` (min) |
| tags | string[] | Emoji/icon tags | `["warning", "computer"]` |
| click | url | URL to open on notification click | `https://grafana.chocolandiadc.com/d/...` |

### AlertSummary (Homepage Widget)

Aggregated view of alerts for dashboard display.

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| critical_count | integer | Number of critical firing alerts | `0` |
| warning_count | integer | Number of warning firing alerts | `2` |
| total_firing | integer | Total number of firing alerts | `2` |
| status | enum | Overall cluster health status | `healthy`, `warning`, `critical` |

## Relationships

```
┌─────────────────┐     webhook      ┌─────────────────┐
│   Prometheus    │──────────────────▶│   Alertmanager  │
│  (alerts fire)  │                   │  (routes/groups)│
└─────────────────┘                   └────────┬────────┘
                                               │
                                               │ http POST
                                               │ + basic_auth
                                               ▼
                                      ┌─────────────────┐
                                      │      ntfy       │
                                      │ (push service)  │
                                      └────────┬────────┘
                                               │
                                               │ WebSocket/SSE
                                               ▼
                                      ┌─────────────────┐
                                      │  Mobile/Web     │
                                      │  Subscribers    │
                                      └─────────────────┘

┌─────────────────┐     PromQL       ┌─────────────────┐
│    Homepage     │──────────────────▶│   Prometheus    │
│   Dashboard     │  (query alerts)  │   (ALERTS{})    │
└─────────────────┘                   └─────────────────┘
```

## State Transitions

### Alert Lifecycle

```
[inactive] ──firing──▶ [pending] ──for_duration──▶ [firing] ──resolved──▶ [inactive]
                              │                       │
                              └───────────────────────┘
                                   (alert clears)
```

### Notification Flow

```
Alert fires ──▶ Alertmanager groups ──▶ ntfy webhook ──▶ Authentication ──▶ Push delivery
                (group_wait: 30s)       (basic_auth)     (user: alertmanager)
```

## Configuration Entities

### ntfy User (Authentication)

| Field | Type | Description |
|-------|------|-------------|
| username | string | User identifier (`alertmanager`) |
| password | string | Password for basic auth (stored in K8s Secret) |
| role | enum | `admin`, `user` |
| permissions | list | Topic-specific permissions |

### Alertmanager Receiver

| Field | Type | Description |
|-------|------|-------------|
| name | string | Receiver identifier (`ntfy-homelab`) |
| webhook_url | string | ntfy internal URL with template |
| http_config | object | Authentication configuration |
| send_resolved | boolean | Whether to send resolution notifications |

## Storage

| Data | Storage Location | Persistence |
|------|------------------|-------------|
| ntfy users | `/var/cache/ntfy/user.db` | PVC (ntfy-data) |
| ntfy cache | `/var/cache/ntfy/cache.db` | PVC (ntfy-data) |
| Alert rules | PrometheusRule CRDs | etcd |
| Alertmanager config | Helm values | Terraform state |
| Homepage config | ConfigMaps | Terraform state |
| K8s Secrets | etcd | Encrypted at rest |
