# PostgreSQL Cluster Module

**Feature**: 011-postgresql-cluster
**Purpose**: Deploy a highly available PostgreSQL database cluster with primary-replica topology

## Overview

This OpenTofu/Terraform module deploys a PostgreSQL HA cluster using the Bitnami PostgreSQL Helm chart (standard chart with replication architecture). The cluster provides:

- **High Availability**: 1 primary instance + 1+ replica instances with asynchronous streaming replication
- **Cluster Access**: ClusterIP Service for applications running in Kubernetes
- **External Access**: LoadBalancer Service (via MetalLB) for internal network administrators
- **Data Persistence**: PersistentVolumes using local-path-provisioner
- **Monitoring**: PostgreSQL Exporter for Prometheus metrics
- **Security**: Auto-generated credentials stored in Kubernetes Secrets

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (K3s)                                    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │ PostgreSQL HA (Bitnami Helm Chart)                 │   │
│  │                                                     │   │
│  │  ┌──────────────┐         ┌──────────────┐        │   │
│  │  │ Primary Pod  │ ──────> │ Replica Pod  │        │   │
│  │  │              │  async  │              │        │   │
│  │  │ PostgreSQL   │  repl   │ PostgreSQL   │        │   │
│  │  │ + Exporter   │         │ + Exporter   │        │   │
│  │  └──────┬───────┘         └──────┬───────┘        │   │
│  │         │                         │                │   │
│  │         │                         │                │   │
│  │    ┌────▼────┐               ┌───▼────┐           │   │
│  │    │  PVC    │               │  PVC   │           │   │
│  │    │  50Gi   │               │  50Gi  │           │   │
│  │    └─────────┘               └────────┘           │   │
│  │                                                     │   │
│  │  ┌─────────────────────────────────────────────┐  │   │
│  │  │ Services                                    │  │   │
│  │  │  • ClusterIP (cluster-internal)             │  │   │
│  │  │  • LoadBalancer (external via MetalLB)      │  │   │
│  │  └─────────────────────────────────────────────┘  │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before using this module, ensure:

1. **K3s Cluster**: Running K3s cluster with at least 2 nodes (for HA)
2. **MetalLB**: Installed and configured with IP address pool (see `docs/network/metallb-ip-allocation.md`)
3. **local-path-provisioner**: Available for PersistentVolume provisioning (included in K3s)
4. **Prometheus Operator** (optional): For ServiceMonitor support
5. **Namespace**: PostgreSQL namespace must exist (`kubectl create namespace postgresql`)

## Usage

### Basic Example

```hcl
module "postgresql_cluster" {
  source = "../../modules/postgresql-cluster"

  namespace        = "postgresql"
  release_name     = "postgres-ha"
  replica_count    = 2 # 1 primary + 1 replica
  storage_size     = "50Gi"

  # External access via MetalLB
  enable_external_access = true
  metallb_ip_pool        = "eero-pool"

  # Monitoring
  enable_metrics         = true
  enable_service_monitor = true
}
```

### Advanced Example

```hcl
module "postgresql_cluster" {
  source = "../../modules/postgresql-cluster"

  # Basic configuration
  namespace          = "postgresql"
  release_name       = "postgres-ha"
  postgresql_version = "16"

  # High availability
  replica_count     = 3 # 1 primary + 2 replicas
  replication_mode  = "async"

  # Storage
  storage_size  = "100Gi"
  storage_class = "local-path"

  # Resource limits (per pod)
  resources_limits_cpu    = "4"
  resources_limits_memory = "8Gi"
  resources_requests_cpu  = "1"
  resources_requests_memory = "2Gi"

  # Network
  enable_external_access = true
  metallb_ip_pool       = "eero-pool"

  # Monitoring
  enable_metrics         = true
  enable_service_monitor = true

  # Security (auto-generate passwords)
  create_random_passwords = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| namespace | Kubernetes namespace | string | `"postgresql"` | no |
| release_name | Helm release name | string | `"postgres-ha"` | no |
| postgresql_version | PostgreSQL major version | string | `"16"` | no |
| replica_count | Total instances (primary + replicas) | number | `2` | no |
| replication_mode | Replication mode: async or sync | string | `"async"` | no |
| storage_size | PVC size per instance | string | `"50Gi"` | no |
| storage_class | StorageClass name | string | `"local-path"` | no |
| resources_limits_cpu | CPU limit per pod | string | `"2"` | no |
| resources_limits_memory | Memory limit per pod | string | `"4Gi"` | no |
| enable_external_access | Enable LoadBalancer service | bool | `true` | no |
| metallb_ip_pool | MetalLB IP pool name | string | `"eero-pool"` | no |
| enable_metrics | Enable PostgreSQL Exporter | bool | `true` | no |
| enable_service_monitor | Create ServiceMonitor | bool | `true` | no |
| create_random_passwords | Auto-generate passwords | bool | `true` | no |

See `variables.tf` for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| cluster_ip_service_endpoint | Full DNS name for cluster-internal connections |
| read_replica_service_endpoint | DNS name for read-only connections |
| external_ip | MetalLB-assigned IP (use kubectl to retrieve) |
| port | PostgreSQL port (5432) |
| credentials_secret_name | Kubernetes Secret name for credentials |
| postgres_password_command | kubectl command to get superuser password |
| verification_commands | Useful kubectl commands for verification |

See `outputs.tf` for complete list of outputs.

## Post-Deployment

### 1. Verify Deployment

```bash
# Check pods are running
kubectl get pods -n postgresql

# Check services
kubectl get svc -n postgresql

# Check PVCs
kubectl get pvc -n postgresql

# Get external IP (if LoadBalancer enabled)
kubectl get svc -n postgresql postgres-ha-postgresql-external \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 2. Retrieve Credentials

```bash
# Get postgres superuser password
kubectl get secret -n postgresql postgres-ha-postgresql-credentials \
  -o jsonpath="{.data.postgres-password}" | base64 -d && echo
```

### 3. Connect to PostgreSQL

**From Kubernetes cluster (read/write to primary):**
```bash
# Using service DNS name
kubectl run postgresql-client --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres -d app_db

# Or exec into primary pod directly
kubectl exec -it -n postgresql postgres-ha-postgresql-primary-0 -- psql -U postgres -d app_db
```

**From Kubernetes cluster (read-only from replica):**
```bash
kubectl run postgresql-client --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-read -U postgres -d app_db
```

**Connection strings for applications:**
- **Primary (read/write)**: `postgres-ha-postgresql-primary.postgresql.svc.cluster.local:5432`
- **Read replica (read-only)**: `postgres-ha-postgresql-read.postgresql.svc.cluster.local:5432`
- **Database**: `app_db`
- **Username**: `postgres` (superuser) or `app_user` (application user)

**From internal network (when MetalLB is configured):**
```bash
# Get external IP first
POSTGRES_IP=$(kubectl get svc -n postgresql postgres-ha-postgresql-external \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Connect using psql
psql -h $POSTGRES_IP -p 5432 -U postgres -d app_db
```

### 4. Verify Replication

```bash
# Check replication status on primary
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;"

# Expected output: 1 row showing replica in 'streaming' state
```

## Monitoring

PostgreSQL metrics are exposed on port 9187 via the PostgreSQL Exporter sidecar.

**Key metrics:**
- `pg_up`: PostgreSQL instance is up
- `pg_stat_database_*`: Database statistics
- `pg_stat_replication_*`: Replication lag and status
- `pg_settings_*`: PostgreSQL configuration

Access metrics:
```bash
kubectl port-forward -n postgresql postgres-ha-postgresql-primary-0 9187:9187
curl http://localhost:9187/metrics
```

## Troubleshooting

### Pods not starting

```bash
# Check primary pod events
kubectl describe pod -n postgresql postgres-ha-postgresql-primary-0

# Check read replica pod events
kubectl describe pod -n postgresql postgres-ha-postgresql-read-0

# Check logs
kubectl logs -n postgresql postgres-ha-postgresql-primary-0 -c postgresql
kubectl logs -n postgresql postgres-ha-postgresql-read-0 -c postgresql
```

### Connection issues

```bash
# Test DNS resolution for primary (from another pod)
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup postgres-ha-postgresql-primary.postgresql.svc.cluster.local

# Test DNS resolution for read replica
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup postgres-ha-postgresql-read.postgresql.svc.cluster.local

# Test TCP connectivity to primary
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nc -zv postgres-ha-postgresql-primary.postgresql.svc.cluster.local 5432
```

### Replication lag

```bash
# Check replication status from primary
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT application_name, state, sync_state, replay_lag FROM pg_stat_replication;"

# Expected: 1 row with state='streaming', sync_state='async'
```

## References

- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/18/)
- [PostgreSQL Replication](https://www.postgresql.org/docs/18/warm-standby.html)
- [K3s Documentation](https://docs.k3s.io/)
- [MetalLB Documentation](https://metallb.universe.tf/)

## License

Part of the chocolandia_kube homelab infrastructure project.
