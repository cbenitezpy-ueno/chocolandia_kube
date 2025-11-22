# Research: Monitoring & Alerting System

**Feature**: 014-monitoring-alerts
**Date**: 2025-11-22

## Research Topics

### 1. Prometheus Stack Deployment Method

**Decision**: Use `kube-prometheus-stack` Helm chart

**Rationale**:
- Provides Prometheus, Grafana, Alertmanager, and node-exporter in a single deployment
- Pre-configured with Kubernetes monitoring rules and dashboards
- Industry standard for K8s monitoring
- Active community and regular updates
- Aligns with Constitution Principle IV (NON-NEGOTIABLE)

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Manual Prometheus + Grafana | More work, less integrated, missing pre-built dashboards |
| Victoria Metrics | Good alternative but less ecosystem support, learning curve |
| Datadog/New Relic | SaaS, not self-hosted, cost, vendor lock-in |

### 2. Ntfy Deployment Strategy

**Decision**: Deploy Ntfy as Kubernetes Deployment with Helm or raw manifests

**Rationale**:
- Lightweight (~15MB container image)
- No external dependencies (embedded SQLite for persistence)
- Simple HTTP API for sending notifications
- Native mobile apps available (iOS/Android)
- Web UI for browser subscriptions
- Self-hosted = full control, no third-party dependency

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Gotify | Less active development, fewer features |
| Pushover | Paid service ($5 one-time), not self-hosted |
| Email-only | Not real-time, can get lost in inbox |
| Slack/Discord | User explicitly requested no messaging apps |

### 3. Alertmanager to Ntfy Integration

**Decision**: Use Alertmanager webhook receiver pointing to Ntfy HTTP API

**Rationale**:
- Alertmanager supports webhook receivers natively
- Ntfy accepts POST requests with simple JSON payload
- No custom code needed - pure configuration
- Priority levels map to Ntfy priority (1-5)

**Integration Pattern**:
```yaml
# Alertmanager config snippet
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'http://ntfy.ntfy.svc.cluster.local/homelab-alerts'
        send_resolved: true
```

### 4. Golden Signals Collection Strategy

**Decision**: Use built-in exporters + ServiceMonitor CRDs

**Rationale**:
- **Latency**: From Traefik metrics (traefik_service_request_duration_seconds)
- **Traffic**: From Traefik metrics (traefik_service_requests_total)
- **Errors**: From Traefik metrics (traefik_service_requests_total with code=5xx)
- **Saturation**: From node-exporter (CPU, memory, disk usage)

**Data Sources**:
| Signal | Source | Metric |
|--------|--------|--------|
| Latency (app) | Traefik | `traefik_service_request_duration_seconds_bucket` |
| Traffic (app) | Traefik | `traefik_service_requests_total` |
| Errors (app) | Traefik | `traefik_service_requests_total{code=~"5.."}` |
| Saturation (node) | node-exporter | `node_cpu_seconds_total`, `node_memory_*` |
| Saturation (disk) | node-exporter | `node_filesystem_avail_bytes` |

### 5. Alert Rules Design

**Decision**: Layered alerting with severity levels

**Alert Categories**:

| Category | Severity | Threshold | Action |
|----------|----------|-----------|--------|
| Node Down | critical | 1 min unreachable | Immediate Ntfy (priority 5) |
| Pod CrashLoop | warning | 3 restarts in 5 min | Ntfy (priority 3) |
| Deployment Unavailable | critical | 0 ready replicas > 2 min | Immediate Ntfy (priority 5) |
| CPU High | warning | >85% for 5 min | Ntfy (priority 3) |
| Disk Space Low | warning | >80% used | Ntfy (priority 3) |
| Disk Space Critical | critical | >90% used | Immediate Ntfy (priority 5) |
| Memory High | warning | >85% for 5 min | Ntfy (priority 3) |

**Alert Grouping**:
- Group by: `alertname`, `namespace`, `node`
- Group wait: 30s (initial wait before sending)
- Group interval: 5m (wait before sending new alerts in group)
- Repeat interval: 4h (re-send if still firing)

### 6. Storage and Retention

**Decision**: 7-day retention with local-path PVC

**Rationale**:
- Homelab has limited storage
- 7 days sufficient for troubleshooting and learning
- Prometheus TSDB compaction handles efficiency
- ~2-5GB expected storage usage

**Configuration**:
```yaml
prometheus:
  prometheusSpec:
    retention: 7d
    retentionSize: 5GB
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          resources:
            requests:
              storage: 10Gi
```

### 7. Grafana Dashboard Strategy

**Decision**: Use pre-built dashboards + custom homelab dashboard

**Dashboards to Include**:
| Dashboard | Source | Purpose |
|-----------|--------|---------|
| Kubernetes Cluster Overview | kube-prometheus-stack | Node/pod health at a glance |
| Node Exporter Full | Grafana Labs #1860 | Detailed node metrics |
| Kubernetes Pods | Grafana Labs #15760 | Pod resource usage |
| Traefik | Grafana Labs #17346 | Ingress traffic/errors |
| Homelab Overview | Custom | Single pane for all critical info |

### 8. Ntfy Access and Security

**Decision**: Expose Ntfy via Traefik Ingress with Cloudflare Access protection

**Rationale**:
- Ntfy needs external access for mobile app subscriptions
- Cloudflare Access provides authentication layer
- No need for Ntfy's built-in auth (simplified setup)
- HTTPS via cert-manager (existing infrastructure)

**Access Flow**:
1. User subscribes to `https://ntfy.chocolandia.com/homelab-alerts`
2. Cloudflare Access authenticates user (Google OAuth)
3. Traefik routes to Ntfy service
4. Alertmanager sends to internal service URL (no auth needed)

### 9. Namespace Strategy

**Decision**: Dedicated namespaces for monitoring components

| Component | Namespace | Rationale |
|-----------|-----------|-----------|
| Prometheus + Grafana + Alertmanager | `monitoring` | Standard convention |
| Ntfy | `ntfy` | Isolated for security |

## Research Summary

All technology decisions resolved. No NEEDS CLARIFICATION remaining.

**Stack Summary**:
- **Metrics Collection**: Prometheus (kube-prometheus-stack)
- **Visualization**: Grafana (included in kube-prometheus-stack)
- **Alerting Engine**: Alertmanager (included in kube-prometheus-stack)
- **Notification Delivery**: Ntfy (self-hosted)
- **Golden Signals Source**: Traefik (apps) + node-exporter (nodes)
- **Storage**: local-path PVCs, 7-day retention

**Next Phase**: Generate data-model.md and contracts/
