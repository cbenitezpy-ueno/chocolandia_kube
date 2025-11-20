# Redis Shared Module

**Feature**: 013-redis-deployment
**Purpose**: Deploy shared Redis caching service with primary-replica architecture

## Overview

This OpenTofu module deploys a highly available Redis caching layer using the Bitnami Redis Helm chart. Redis is configured with:

- **2 instances** (1 primary + 1 replica) for high availability
- **Persistent storage** (10Gi per instance via local-path-provisioner)
- **Authentication** (password-based, stored in Kubernetes Secrets)
- **Monitoring** (Prometheus metrics via redis_exporter)
- **Dual access**:
  - Cluster-internal (ClusterIP services)
  - Private network (MetalLB LoadBalancer at 192.168.4.203)

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    Redis Namespace                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────┐      ┌──────────────────────┐    │
│  │  redis-shared-master │      │ redis-shared-replica │    │
│  │  (Primary - R/W)     │─────▶│  (Replica - R/O)     │    │
│  └──────────────────────┘      └──────────────────────┘    │
│           │                              │                  │
│           ▼                              ▼                  │
│  ┌──────────────────────┐      ┌──────────────────────┐    │
│  │ PVC: redis-data-     │      │ PVC: redis-data-     │    │
│  │ master-0 (10Gi)      │      │ replicas-0 (10Gi)    │    │
│  └──────────────────────┘      └──────────────────────┘    │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  Services:                                                  │
│  • redis-shared-master.redis.svc.cluster.local:6379        │
│  • redis-shared-replicas.redis.svc.cluster.local:6379      │
│  • 192.168.4.203:6379 (MetalLB LoadBalancer)               │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "redis_shared" {
  source = "../../modules/redis-shared"

  release_name       = "redis-shared"
  namespace          = "redis"
  replica_namespaces = ["beersystem", "other-app"]

  # MetalLB LoadBalancer
  loadbalancer_ip = "192.168.4.203"
}
```

### Connecting to Redis

#### From Kubernetes Applications

```bash
# ClusterIP DNS (internal access)
redis-cli -h redis-shared-master.redis.svc.cluster.local -p 6379 -a $(kubectl get secret redis-credentials -n redis -o jsonpath='{.data.redis-password}' | base64 -d)
```

#### From Private Network (192.168.4.0/24)

```bash
# MetalLB LoadBalancer IP
redis-cli -h 192.168.4.203 -p 6379 -a <password>
```

### Environment Variables (Application Config)

```yaml
env:
  - name: REDIS_HOST
    value: "redis-shared-master.redis.svc.cluster.local"
  - name: REDIS_PORT
    value: "6379"
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-credentials
        key: redis-password
```

## Inputs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `release_name` | string | `"redis-shared"` | Helm release name |
| `namespace` | string | `"redis"` | Kubernetes namespace |
| `replica_namespaces` | list(string) | `["beersystem"]` | Namespaces for Secret replication |
| `chart_version` | string | `"23.2.12"` | Bitnami Redis chart version |
| `storage_size` | string | `"10Gi"` | PersistentVolume size per instance |
| `replica_count` | number | `1` | Number of read replicas |
| `master_cpu_limit` | string | `"1000m"` | Master CPU limit |
| `master_memory_limit` | string | `"2Gi"` | Master memory limit |
| `loadbalancer_ip` | string | `"192.168.4.203"` | MetalLB IP address |
| `enable_metrics` | bool | `true` | Enable Prometheus exporter |

See `variables.tf` for complete list.

## Outputs

| Output | Description |
|--------|-------------|
| `redis_master_service` | Master service DNS name |
| `redis_replicas_service` | Replicas service DNS name |
| `redis_external_ip` | LoadBalancer IP address |
| `redis_secret_name` | Credentials Secret name |
| `redis_password` | Redis password (sensitive) |

## Security

### Authentication

- **Password-based auth** enabled by default
- Credentials stored in Kubernetes Secret: `redis-credentials`
- Secret replicated to additional namespaces (via `replica_namespaces` variable)

### Network Isolation

- **Cluster-internal**: Accessible via ClusterIP services
- **Private network**: Accessible via MetalLB LoadBalancer (192.168.4.0/24 only)
- **Public internet**: Not accessible (no public IP)

### Disabled Commands

The following dangerous commands are disabled:
- `FLUSHDB` - Prevents accidental database deletion
- `FLUSHALL` - Prevents accidental all-database deletion
- `CONFIG` - Prevents runtime configuration changes
- `SHUTDOWN` - Prevents unauthorized shutdown

## Monitoring

### Prometheus Metrics

Metrics exposed via redis_exporter sidecar:

- `redis_memory_used_bytes` - Memory usage
- `redis_connected_clients` - Active connections
- `redis_commands_processed_total` - Commands executed
- `redis_replication_lag_seconds` - Replication lag
- `redis_uptime_seconds` - Instance uptime

### ServiceMonitor

Prometheus Operator ServiceMonitor automatically created when `enable_service_monitor = true`.

### Grafana Dashboard

Import Redis dashboard: https://grafana.com/grafana/dashboards/11835

## Persistence

- **Storage Class**: `local-path` (K3s local-path-provisioner)
- **PVC Size**: 10Gi per instance
- **Data Retention**: Survives pod restarts
- **Backup**: Not included (out of scope)

## High Availability

- **Primary-Replica**: 1 primary (read/write) + 1 replica (read-only)
- **Automatic Failover**: NOT included (Redis Sentinel out of scope)
- **Manual Failover**: Delete primary pod → replica promoted manually
- **Read Scaling**: Read operations can use replica service

## Performance

- **Target**: ≥10,000 ops/sec
- **Latency**: <10ms p95 for SET/GET operations
- **Benchmarking**: Use `redis-benchmark` tool

```bash
redis-benchmark -h redis-shared-master.redis.svc.cluster.local -p 6379 -a <password> -q
```

## Maintenance

### Scaling Replicas

```hcl
module "redis_shared" {
  # ...
  replica_count = 2  # Scale to 2 replicas
}
```

### Updating Redis Version

```hcl
module "redis_shared" {
  # ...
  chart_version = "23.2.13"  # Update Helm chart
}
```

### Retrieving Password

```bash
kubectl get secret redis-credentials -n redis -o jsonpath='{.data.redis-password}' | base64 -d
```

## Troubleshooting

### Redis Pod Not Starting

```bash
# Check pod status
kubectl get pods -n redis

# View logs
kubectl logs -n redis redis-shared-master-0

# Describe pod for events
kubectl describe pod -n redis redis-shared-master-0
```

### Connection Refused

```bash
# Test from within cluster
kubectl run redis-test --rm -it --image=redis:8.2 -- redis-cli -h redis-shared-master.redis.svc.cluster.local -p 6379 -a <password> PING

# Should return: PONG
```

### LoadBalancer Pending

```bash
# Check MetalLB configuration
kubectl get ipaddresspool -n metallb-system
kubectl get service -n redis redis-shared-external
```

## Dependencies

- **MetalLB**: LoadBalancer provisioning
- **local-path-provisioner**: Persistent storage
- **Prometheus Operator**: ServiceMonitor (optional)

## Related Documentation

- [spec.md](../../../specs/013-redis-deployment/spec.md) - Feature specification
- [plan.md](../../../specs/013-redis-deployment/plan.md) - Implementation plan
- [quickstart.md](../../../specs/013-redis-deployment/quickstart.md) - Operational guide
- [data-model.md](../../../specs/013-redis-deployment/data-model.md) - Configuration schema

## License

Internal use only - Chocolandia Homelab Infrastructure
