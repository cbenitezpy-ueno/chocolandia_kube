# Data Model: PostgreSQL Cluster Database Service

**Branch**: `011-postgresql-cluster` | **Date**: 2025-11-14
**Purpose**: Define the entities and relationships for the PostgreSQL cluster infrastructure

## Overview

This data model describes the infrastructure entities for the PostgreSQL cluster, not application database schemas (which are out of scope). It focuses on cluster topology, access patterns, persistence, and operational entities.

---

## Entity Definitions

### 1. PostgreSQL Cluster

The top-level entity representing the high-availability database service.

**Attributes**:
- `cluster_name`: Unique identifier for the cluster (e.g., "postgres-ha")
- `namespace`: Kubernetes namespace where cluster is deployed (e.g., "postgresql")
- `version`: PostgreSQL major version (e.g., "16")
- `topology`: Replication topology (e.g., "primary-replica")
- `replication_mode`: Synchronous or asynchronous replication
- `instance_count`: Number of instances (2 for primary-replica)
- `created_at`: Timestamp when cluster was deployed
- `status`: Cluster health status (healthy, degraded, failed)

**Relationships**:
- Contains: 1+ PostgreSQL Instances
- Contains: 0+ Databases
- Contains: 0+ Database Users
- Exposed via: 2 Connection Endpoints (cluster-internal, external)
- Monitored by: 1 Service Monitor (Prometheus)

**Lifecycle**:
1. Created: Deployed via ArgoCD Application
2. Running: Serving connections, replicating data
3. Degraded: One instance unavailable, cluster operational
4. Failed: All instances unavailable
5. Deleted: Removed via ArgoCD Application deletion (PVCs retained)

**Validation Rules**:
- `instance_count` must be >= 2 for HA configuration
- `replication_mode` must be "async" or "sync"
- `namespace` must not be "default" or "kube-system" (security)

---

### 2. PostgreSQL Instance

A single PostgreSQL server process within the cluster.

**Attributes**:
- `instance_name`: Unique identifier (e.g., "postgres-ha-postgresql-0", "postgres-ha-postgresql-1")
- `role`: Instance role ("primary" or "replica")
- `pod_name`: Kubernetes pod name (matches StatefulSet ordinal)
- `node_name`: Kubernetes node where pod is scheduled
- `ip_address`: Pod IP address (cluster-internal)
- `port`: PostgreSQL port (5432)
- `status`: Instance status (running, pending, failed)
- `replication_lag`: Time lag behind primary (for replicas, in seconds)
- `storage_used`: Storage utilization (GB)
- `storage_capacity`: Total storage allocated (GB)

**Relationships**:
- Belongs to: 1 PostgreSQL Cluster
- Uses: 1 Persistent Storage volume
- Replicates to: 0+ PostgreSQL Instances (primary → replicas)
- Replicates from: 0-1 PostgreSQL Instance (replica ← primary)
- Exposes: 1+ Metrics endpoints (PostgreSQL Exporter)

**State Transitions**:
```
Pending → Running (pod starts successfully)
Running → Failed (pod crashes or unhealthy)
Failed → Running (Kubernetes restarts pod)
Running (replica) → Running (primary) (failover promotion)
```

**Validation Rules**:
- Only 1 instance can have `role = "primary"` per cluster
- Replicas must have `replication_lag >= 0` (cannot be ahead of primary)
- `storage_used` must not exceed `storage_capacity` (prevent OOM)

---

### 3. Database

A logical database within the PostgreSQL cluster (not to be confused with the cluster itself).

**Attributes**:
- `database_name`: Database identifier (e.g., "appdb", "analytics")
- `owner`: Database owner role (PostgreSQL user)
- `encoding`: Character encoding (e.g., "UTF8")
- `collation`: Sort order (e.g., "en_US.UTF-8")
- `size`: Database size (MB)
- `created_at`: Timestamp when database was created

**Relationships**:
- Belongs to: 1 PostgreSQL Cluster
- Owned by: 1 Database User
- Accessed by: 0+ Database Users (via grants)

**Lifecycle**:
1. Created: Via SQL `CREATE DATABASE` or application migration
2. Active: Storing application data
3. Archived: Exported to backup, marked for deletion
4. Deleted: Dropped via SQL `DROP DATABASE`

**Validation Rules**:
- `database_name` must be unique within cluster
- `database_name` must not be reserved ("postgres", "template0", "template1")
- `owner` must be an existing Database User

---

### 4. Database User (Role)

A PostgreSQL user/role with authentication credentials and permissions.

**Attributes**:
- `username`: User identifier (e.g., "app_user", "admin")
- `role_type`: User or role ("user", "role", "superuser")
- `authentication_method`: How user authenticates ("password", "cert")
- `password_secret`: Kubernetes Secret name containing password
- `privileges`: List of granted privileges (e.g., ["CONNECT", "SELECT", "INSERT"])
- `databases`: List of databases user has access to
- `created_at`: Timestamp when user was created

**Relationships**:
- Belongs to: 1 PostgreSQL Cluster
- Owns: 0+ Databases
- Accesses: 0+ Databases (via grants)
- Credentials stored in: 1 Kubernetes Secret

**Lifecycle**:
1. Created: Via SQL `CREATE USER` or bootstrap script
2. Active: Authenticating and executing queries
3. Disabled: Login disabled via `ALTER USER ... NOLOGIN`
4. Deleted: Dropped via SQL `DROP USER`

**Validation Rules**:
- `username` must be unique within cluster
- `password_secret` must reference an existing Kubernetes Secret
- Superuser must not be granted to application users (security)

---

### 5. Connection Endpoint

A Kubernetes Service exposing the PostgreSQL cluster for client connections.

**Attributes**:
- `endpoint_name`: Service name (e.g., "postgres-ha-postgresql", "postgres-ha-external")
- `service_type`: Kubernetes Service type ("ClusterIP", "LoadBalancer")
- `ip_address`: Service IP (ClusterIP or LoadBalancer IP)
- `port`: Service port (5432)
- `target_instances`: Which instances receive traffic ("primary", "replica", "any")
- `dns_name`: Kubernetes DNS name (e.g., "postgres-ha-postgresql.postgresql.svc.cluster.local")
- `external_dns_name`: External DNS name (if applicable, e.g., "postgres.homelab.local")

**Relationships**:
- Exposes: 1 PostgreSQL Cluster
- Routes to: 1+ PostgreSQL Instances (via label selectors)
- Announced by: 1 MetalLB IP (for LoadBalancer type)

**Endpoint Types**:

**Type 1: Cluster-Internal Endpoint (ClusterIP)**
- `service_type`: ClusterIP
- `target_instances`: Primary only (writes) or any (reads)
- `ip_address`: Cluster-internal IP (e.g., 10.43.100.50)
- **Purpose**: Kubernetes pod → database connections

**Type 2: External Endpoint (LoadBalancer)**
- `service_type`: LoadBalancer
- `target_instances`: Primary only (writes) or any (reads)
- `ip_address`: MetalLB IP from cluster VLAN (e.g., 192.168.10.100)
- **Purpose**: Internal network → database connections

**Validation Rules**:
- `port` must be 5432 (standard PostgreSQL port)
- LoadBalancer `ip_address` must be from MetalLB IP pool
- ClusterIP `dns_name` must follow Kubernetes DNS convention

---

### 6. Persistent Storage

A Kubernetes PersistentVolume storing PostgreSQL data files.

**Attributes**:
- `volume_name`: PersistentVolume name (e.g., "pvc-postgres-ha-postgresql-0")
- `pvc_name`: PersistentVolumeClaim name (matches StatefulSet pod)
- `storage_class`: Kubernetes StorageClass ("local-path")
- `capacity`: Volume size (e.g., "50Gi")
- `access_mode`: Volume access mode ("ReadWriteOnce")
- `mount_path`: Container mount path ("/bitnami/postgresql")
- `node_affinity`: Which node hosts the volume (local-path specific)
- `used_space`: Current usage (GB)
- `created_at`: Timestamp when PV was provisioned

**Relationships**:
- Used by: 1 PostgreSQL Instance
- Managed by: 1 Kubernetes PersistentVolumeClaim
- Survives: Pod deletions and restarts

**Lifecycle**:
1. Provisioned: Created by local-path-provisioner when PVC is bound
2. Bound: Attached to PostgreSQL pod
3. Active: Storing data, surviving pod restarts
4. Orphaned: Pod deleted but PVC retained (manual cleanup required)
5. Deleted: PVC deleted (data lost unless backed up)

**Validation Rules**:
- `capacity` must be >= 10Gi (minimum for PostgreSQL)
- `access_mode` must be "ReadWriteOnce" (StatefulSet requirement)
- `used_space` must not exceed `capacity` - 10% (prevent full disk)

---

### 7. Backup

A point-in-time snapshot of PostgreSQL data.

**Attributes**:
- `backup_id`: Unique backup identifier (timestamp-based, e.g., "backup-20251114-120000")
- `backup_type`: Backup method ("pg_dump", "wal_archive")
- `cluster_name`: Source cluster name
- `database_name`: Database backed up (null for full cluster backup)
- `size`: Backup file size (MB)
- `storage_location`: Where backup is stored ("/backups/postgres", NFS path)
- `created_at`: Timestamp when backup was created
- `expires_at`: Timestamp when backup should be deleted (retention policy)
- `status`: Backup status ("in_progress", "completed", "failed")

**Relationships**:
- Created from: 1 PostgreSQL Cluster or 1 Database
- Stored in: 1 Persistent Volume or NFS share

**Lifecycle**:
1. Initiated: CronJob triggers backup script
2. In Progress: pg_dump executing
3. Completed: Backup file written to storage
4. Retained: Kept until `expires_at`
5. Expired: Deleted by retention policy (after 7 days)

**Validation Rules**:
- `backup_type` must be "pg_dump" initially (WAL archiving is future enhancement)
- `expires_at` must be > `created_at` (retention period > 0)
- `storage_location` must have sufficient free space

---

## Entity Relationship Diagram

```
┌─────────────────────┐
│ PostgreSQL Cluster  │
│ - cluster_name      │
│ - version           │
│ - topology          │
│ - instance_count    │
└──────────┬──────────┘
           │ contains
           │
           ├──────────────────────────────┬──────────────────────┐
           │                              │                      │
           ▼                              ▼                      ▼
┌─────────────────────┐      ┌─────────────────────┐  ┌─────────────────────┐
│ PostgreSQL Instance │      │ Database            │  │ Database User       │
│ - instance_name     │      │ - database_name     │  │ - username          │
│ - role (primary/    │      │ - owner             │  │ - role_type         │
│   replica)          │      │ - size              │  │ - privileges        │
│ - replication_lag   │      └──────────┬──────────┘  └──────────┬──────────┘
└──────────┬──────────┘                 │                        │
           │ uses                       │ owned by               │ credentials
           │                            └────────────────────────┘      │
           ▼                                                            ▼
┌─────────────────────┐                                    ┌──────────────────┐
│ Persistent Storage  │                                    │ Kubernetes Secret│
│ - volume_name       │                                    │ - secret_name    │
│ - capacity          │                                    │ - password       │
│ - used_space        │                                    └──────────────────┘
└─────────────────────┘

           ┌─────────────────────┐
           │ Connection Endpoint │
           │ - endpoint_name     │
           │ - service_type      │
           │ - ip_address        │
           │ - target_instances  │
           └──────────┬──────────┘
                      │ routes to
                      └───────────► PostgreSQL Instance(s)

┌─────────────────────┐
│ Backup              │
│ - backup_id         │
│ - backup_type       │
│ - size              │
│ - created_at        │
└──────────┬──────────┘
           │ created from
           └───────────► PostgreSQL Cluster
```

---

## Data Flows

### Flow 1: Application Connects to Database

```
Application Pod → ClusterIP Service → Primary Instance → Database
   (writes)         (postgres-ha-          (postgres-ha-      (appdb)
                     postgresql.svc)        postgresql-0)
```

### Flow 2: Internal Network Administrator Connects

```
Admin Client → LoadBalancer Service → MetalLB IP → Primary Instance → Database
  (psql)       (postgres-ha-external)   (192.168.10.100)  (postgres-ha-   (postgres)
                                                            postgresql-0)
```

### Flow 3: Data Replication

```
Primary Instance → Streaming Replication → Replica Instance
(postgres-ha-                              (postgres-ha-
 postgresql-0)                              postgresql-1)
    │                                           │
    ▼                                           ▼
Persistent Storage                     Persistent Storage
(pvc-...-0)                            (pvc-...-1)
```

### Flow 4: Backup Creation

```
CronJob → pg_dump command → Primary Instance → Backup File → Backup Storage
(backup-job)                 (postgres-ha-      (SQL dump)   (/backups/postgres/)
                              postgresql-0)
```

### Flow 5: Failover (Primary Fails)

```
Primary Instance (FAILED) → Replica Instance → Promoted to Primary
(postgres-ha-postgresql-0)  (postgres-ha-        (becomes primary)
                             postgresql-1)              │
                                                        ▼
                             Connection Endpoint routes to new primary
                             (Service label selector unchanged)
```

---

## State Management

### Cluster State Machine

```
┌─────────┐
│ Pending │ (Initial deployment, pods starting)
└────┬────┘
     │
     ▼
┌─────────┐
│ Healthy │ (Both instances running, replication active)
└────┬────┘
     │
     ├──► ┌──────────┐
     │    │ Degraded │ (One instance down, cluster operational)
     │    └─────┬────┘
     │          │
     │          └──────► (Instance recovers) → Healthy
     │
     └──► ┌────────┐
          │ Failed │ (All instances down)
          └────┬───┘
               │
               └──────► (Instances recover) → Healthy
```

### Instance State Machine

```
┌─────────┐
│ Pending │ (Pod initializing, PostgreSQL starting)
└────┬────┘
     │
     ▼
┌─────────┐
│ Running │ (PostgreSQL accepting connections)
└────┬────┘
     │
     ├──► ┌─────────┐
     │    │ Unhealthy│ (Liveness probe failing)
     │    └─────┬────┘
     │          │
     │          └──► (Kubernetes restarts pod) → Pending
     │
     └──► ┌─────────┐
          │ Failed  │ (Persistent failure, manual intervention required)
          └─────────┘
```

---

## Constraints and Invariants

### Cluster-Level Invariants

1. **Single Primary Rule**: At most 1 instance with `role = "primary"` per cluster
2. **Minimum Instances**: Cluster must have >= 2 instances for HA
3. **Replication Direction**: Replicas replicate FROM primary, never peer-to-peer
4. **Storage Isolation**: Each instance has its own PersistentVolume (no shared storage)

### Instance-Level Invariants

1. **Pod-Volume Binding**: Each pod is bound to exactly 1 PersistentVolume
2. **Ordinal Naming**: StatefulSet instances follow ordinal naming (0, 1, ...)
3. **Primary is pod-0**: Pod-0 is always the initial primary (Bitnami chart convention)
4. **Replication Lag Bound**: Replica lag must be < 60 seconds (alert threshold)

### Network-Level Invariants

1. **ClusterIP Stability**: ClusterIP address does not change during cluster lifetime
2. **LoadBalancer IP Uniqueness**: LoadBalancer IP must be unique across all services
3. **Port Consistency**: PostgreSQL port is always 5432 (no dynamic port assignment)

### Storage-Level Invariants

1. **Volume Persistence**: PersistentVolumes survive pod deletions and restarts
2. **Volume Locality**: local-path volumes are node-local (pod must run on same node)
3. **Storage Isolation**: Each instance's data is independent (no shared volumes)

---

## Security Considerations

### Credential Management

- Database passwords stored in Kubernetes Secrets (encrypted at rest via etcd)
- Secret names follow convention: `postgres-ha-postgresql-credentials`
- Passwords auto-generated during Helm chart installation (random 16-character strings)
- Application credentials provided via Secret environment variables

### Network Isolation

- ClusterIP service accessible only from cluster pods (no external access)
- LoadBalancer service accessible only from cluster VLAN and management VLAN (FortiGate rules)
- No public internet exposure (LoadBalancer IP is private)

### RBAC

- PostgreSQL superuser disabled for application access
- Application users have minimal privileges (CONNECT, SELECT, INSERT, UPDATE, DELETE on specific databases)
- Database owner role separate from application user role

---

## Monitoring and Observability

### Metrics Collected (via PostgreSQL Exporter)

- Connection count (active, idle, total)
- Replication lag (seconds)
- Query execution time (histogram)
- Database size (MB)
- Storage utilization (%)
- Transaction rate (TPS)
- Cache hit ratio

### Alerts Configured

- Replication lag > 60 seconds (WARN)
- Replication lag > 300 seconds (CRITICAL)
- Storage utilization > 80% (WARN)
- Storage utilization > 95% (CRITICAL)
- Connection count > 90 (approaching limit)
- Instance down (CRITICAL)

---

**Data Model Complete**: 2025-11-14
**Next**: contracts/ (Kubernetes Service manifests), quickstart.md
