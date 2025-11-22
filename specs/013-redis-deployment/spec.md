# Feature Specification: Redis Deployment

**Feature Branch**: `013-redis-deployment`
**Created**: 2025-11-20
**Status**: Draft
**Input**: User description: "quiero deployar redis para poder usar dentro del cluster y desde la red privada solamente. tengamos 2 instancias, con monitoreo."

## Clarifications

### Session 2025-11-20

- Q: Relación con Redis existente de beersystem (namespace: beersystem) - ¿migrar, mantener separado, o cancelar? → A: Migrar beersystem al nuevo Redis compartido; desinstalar el Redis dedicado de beersystem
- Q: Namespace para el nuevo Redis compartido - ¿default, redis dedicado, beersystem, o shared-services? → A: Namespace dedicado "redis" para el servicio compartido
- Q: Estrategia de migración de beersystem - ¿blue-green, downtime planificado, rolling update, o feature flag? → A: Downtime planificado (parar beersystem → deploy nuevo Redis → cambiar config → iniciar beersystem)
- Q: Acceso a credenciales de Redis desde beersystem (cross-namespace) - ¿External Secrets Operator, copiar Secret, RBAC cross-namespace, o ConfigMap? → A: Copiar Secret a namespace beersystem (OpenTofu crea secret en ambos namespaces)
- Q: Nombre del Helm release y servicios - ¿redis-shared, redis, redis-ha, o cluster-redis? → A: Release "redis-shared" con servicios redis-shared-master.redis.svc.cluster.local

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Internal Application Cache Access (Priority: P1)

Applications running within the Kubernetes cluster need fast, reliable access to a shared caching layer for storing session data, frequently accessed data, and temporary state.

**Why this priority**: This is the core value proposition - enabling applications to use Redis as a high-performance cache without external exposure, which is essential for application performance.

**Independent Test**: Can be fully tested by deploying a simple application pod that connects to the Redis service using the cluster-internal DNS name, performs set/get operations, and verifies data persistence across pod restarts.

**Acceptance Scenarios**:

1. **Given** an application pod running in the same cluster, **When** the application connects to Redis using the internal service DNS name, **Then** the connection succeeds and data operations (SET/GET) complete successfully
2. **Given** Redis is running with 2 instances, **When** data is written to the primary instance, **Then** the data is accessible from both instances
3. **Given** Redis instances are running, **When** an application pod queries available replicas, **Then** both Redis instances are reported as healthy and available

---

### User Story 2 - Private Network Access (Priority: P2)

Services running on the private network (192.168.4.0/24) need direct access to Redis for administrative tasks, monitoring, or legacy applications that cannot run in containers.

**Why this priority**: Provides flexibility for accessing Redis from trusted network hosts while maintaining security isolation from the public internet.

**Independent Test**: Can be fully tested by connecting to Redis from a machine on the private network (e.g., 192.168.4.X) using a Redis CLI client and verifying successful authentication and data operations.

**Acceptance Scenarios**:

1. **Given** Redis is exposed on the private network, **When** a client on 192.168.4.0/24 connects to the assigned LoadBalancer IP, **Then** the connection succeeds and Redis responds to commands
2. **Given** a client attempts to connect from outside the private network, **When** they try to reach the Redis LoadBalancer IP, **Then** the connection is blocked or times out
3. **Given** Redis requires authentication, **When** a private network client provides valid credentials, **Then** access is granted to all Redis commands

---

### User Story 3 - Instance Health Monitoring (Priority: P1)

Operations team needs visibility into Redis instance health, performance metrics, and availability to detect issues before they impact applications.

**Why this priority**: Monitoring is critical for production reliability - without it, failures go undetected until applications break.

**Independent Test**: Can be fully tested by accessing the monitoring dashboard, viewing Redis metrics (uptime, memory usage, connections, operations per second), and triggering an alert by simulating a failure scenario (e.g., stopping one instance).

**Acceptance Scenarios**:

1. **Given** Redis monitoring is configured, **When** an operator views the monitoring dashboard, **Then** metrics for both instances are displayed including uptime, memory usage, connected clients, and command statistics
2. **Given** one Redis instance becomes unavailable, **When** the monitoring system detects the failure, **Then** an alert is generated and the remaining instance continues serving requests
3. **Given** Redis is under load, **When** performance metrics are collected, **Then** operations per second, latency percentiles, and cache hit rates are accurately reported

---

### User Story 4 - Beersystem Migration to Shared Redis (Priority: P1)

The beersystem application currently uses its own dedicated Redis instance (namespace: beersystem). It needs to be migrated to the new shared Redis service using a planned downtime maintenance window. The migration follows: scale down beersystem → deploy new shared Redis → reconfigure beersystem → scale up beersystem → decommission old Redis.

**Why this priority**: This is critical for consolidating infrastructure, reducing resource usage, and enabling beersystem to benefit from HA, monitoring, and persistent storage of the new shared Redis. Planned downtime approach is acceptable for homelab environment and simplifies migration risk.

**Independent Test**: Can be fully tested by scaling down beersystem, deploying new Redis, updating beersystem configuration to point to redis-shared-master.redis.svc.cluster.local with new credentials, scaling up beersystem, verifying application functionality, and confirming the old Redis instance can be safely deleted.

**Acceptance Scenarios**:

1. **Given** beersystem is scaled down to 0 replicas, **When** the new shared Redis is deployed and validated as operational, **Then** the new Redis accepts connections and passes health checks
2. **Given** the new shared Redis is operational, **When** beersystem deployment configuration is updated with new Redis DNS (redis-shared-master.redis.svc.cluster.local) and credentials, **Then** the configuration is successfully applied
3. **Given** beersystem configuration is updated, **When** beersystem is scaled back up to 1 replica, **Then** beersystem pod starts successfully and connects to the new shared Redis without errors
4. **Given** beersystem is running with the new shared Redis, **When** users interact with the beersystem application (login, session management, cached queries), **Then** all functionality works correctly (cache starts empty as expected)
5. **Given** beersystem has been migrated and validated for 24+ hours, **When** the old Redis deployment in beersystem namespace is deleted, **Then** no errors occur and beersystem continues operating normally
6. **Given** beersystem uses the shared Redis, **When** monitoring metrics are checked, **Then** beersystem-specific Redis operations (connections, commands, memory usage) are visible in Prometheus/Grafana

---

### Edge Cases

- What happens when one Redis instance fails while applications are actively reading/writing data?
- How does the system handle network partitions between Redis instances?
- What occurs when Redis reaches maximum memory limits?
- How does the system respond when all connections to Redis are exhausted?
- What happens when Redis restarts and cached data is lost?
- How does authentication interact with monitoring probes and health checks?
- What happens if beersystem migration fails mid-process (connected to new Redis but old Redis still running)?
- How does beersystem handle connection errors during the migration cutover period?
- What occurs if beersystem cache data is incompatible between old and new Redis versions?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST create a dedicated "redis" namespace for the shared Redis service
- **FR-002**: System MUST deploy exactly 2 Redis instances within the "redis" namespace
- **FR-003**: System MUST ensure Redis is accessible via cluster-internal DNS to all pods across all namespaces in the cluster
- **FR-004**: System MUST expose Redis on the private network (192.168.4.0/24) using a LoadBalancer service with an IP from the MetalLB pool
- **FR-005**: System MUST prevent Redis from being accessible from the public internet
- **FR-006**: System MUST configure Redis instances with replication (primary-replica architecture) for data redundancy
- **FR-007**: System MUST persist Redis data across pod restarts using persistent storage
- **FR-008**: System MUST provide monitoring metrics for both Redis instances including memory usage, connection count, operations per second, and replication status
- **FR-009**: System MUST integrate Redis metrics with the existing cluster monitoring infrastructure (Prometheus/Grafana if available)
- **FR-010**: System MUST configure health checks to automatically restart failed Redis instances
- **FR-011**: System MUST require authentication for all Redis connections (both internal and private network)
- **FR-012**: System MUST store Redis credentials securely using Kubernetes Secrets in the "redis" namespace
- **FR-012a**: System MUST replicate Redis credentials Secret to "beersystem" namespace to enable beersystem application access
- **FR-013**: System MUST configure resource limits (CPU and memory) for each Redis instance to prevent resource exhaustion
- **FR-014**: System MUST support standard Redis commands and data structures (strings, lists, sets, sorted sets, hashes)
- **FR-015**: System MUST support planned downtime migration of beersystem application from its dedicated Redis instance to the new shared Redis service
- **FR-016**: System MUST allow beersystem deployment to be scaled down to 0 replicas during migration without data loss risk (cache data is ephemeral)
- **FR-017**: System MUST allow beersystem to connect to the shared Redis using cross-namespace DNS (redis-shared-master.redis.svc.cluster.local) and new credentials from Kubernetes Secret
- **FR-017a**: System MUST name the Helm release "redis-shared" to generate service names redis-shared-master and redis-shared-replicas
- **FR-018**: System MUST enable safe decommissioning of the old beersystem Redis deployment after 24+ hours of successful operation with the new Redis

### Key Entities

- **Redis Primary Instance**: The main Redis instance that handles all write operations and replicates data to the replica instance. Stores cache data, session information, and temporary application state.
- **Redis Replica Instance**: A read-only copy of the primary instance that can serve read requests and provides failover capability. Maintains synchronized data from the primary.
- **Redis Credentials Secret**: Authentication credentials (password) stored securely in Kubernetes Secrets. The same secret is replicated to multiple namespaces ("redis" and "beersystem") to enable cross-namespace access without complex RBAC.
- **Monitoring Metrics**: Performance and health data collected from Redis instances including memory usage, connections, command statistics, replication lag, and availability status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Applications within the cluster can connect to Redis and complete cache operations (SET/GET) in under 10 milliseconds for 95% of requests
- **SC-002**: Redis remains available for cluster applications even when one of the two instances fails
- **SC-003**: Redis is accessible from any host on the 192.168.4.0/24 private network within 100 milliseconds
- **SC-004**: Redis is completely inaccessible from any IP address outside the private network
- **SC-005**: Monitoring dashboards display real-time metrics for both Redis instances with updates every 15 seconds or less
- **SC-006**: Redis handles at least 10,000 operations per second without performance degradation
- **SC-007**: Redis data persists across instance restarts with zero data loss for acknowledged writes
- **SC-008**: Unauthorized connection attempts (without valid credentials) are rejected 100% of the time

## Assumptions

- The cluster already has MetalLB configured with available IP addresses in the 192.168.4.200-192.168.4.210 range
- Persistent storage is available via the existing local-path-provisioner
- A monitoring solution (Prometheus/Grafana or equivalent) is available in the cluster for metrics collection
- The private network (192.168.4.0/24) is trusted and isolated from the public internet
- Applications requiring Redis access will be deployed in the same Kubernetes cluster
- Standard Redis protocol and commands are sufficient (no Redis modules or extensions required)
- Default Redis memory eviction policies (e.g., allkeys-lru) are acceptable for cache workloads

## Dependencies

- MetalLB must be operational for LoadBalancer service provisioning
- Kubernetes local-path-provisioner must be available for persistent volumes
- Cluster monitoring infrastructure must be available for metric collection
- Network policies or firewall rules controlling access to the 192.168.4.0/24 network
- Beersystem namespace must exist for Secret replication
- Beersystem application deployment (namespace: beersystem) must be accessible for configuration updates
- Beersystem application must support reconfiguration of Redis connection parameters (host, port, password) without code changes via environment variables or ConfigMap

## Scope Boundaries

### In Scope

- Creating dedicated "redis" namespace for shared service
- Deploying 2 Redis instances (primary + replica) in the "redis" namespace
- Configuring Redis replication for data redundancy
- Exposing Redis internally via ClusterIP Service (cross-namespace accessible)
- Exposing Redis on private network via LoadBalancer
- Setting up authentication for Redis access
- Replicating Redis credentials Secret to multiple namespaces ("redis" and "beersystem") via OpenTofu
- Configuring persistent storage for Redis data
- Integrating Redis metrics with cluster monitoring
- Setting up health checks and auto-restart policies
- Planned downtime migration of beersystem application from dedicated Redis to shared Redis (scale down → reconfigure → scale up)
- Reconfiguring beersystem deployment to use new Redis service DNS (redis-shared-master.redis.svc.cluster.local) and credentials from replicated Secret
- Decommissioning old beersystem Redis deployment after 24+ hours of successful operation

### Out of Scope

- Redis Cluster mode (sharding across multiple nodes)
- Redis Sentinel for automatic failover orchestration
- Backup and restore procedures for Redis data
- Performance tuning for specific application workloads
- Public internet access to Redis
- Custom Redis modules or extensions
- Data migration/transfer from old beersystem Redis to new Redis (beersystem will start fresh with empty cache)
- Zero-downtime migration of beersystem (planned downtime approach is acceptable for homelab environment)
- Migration of other applications beyond beersystem (ArgoCD Redis remains independent)
- Hot/warm migration strategies (blue-green, rolling update, feature flags)
- External Secrets Operator or secret synchronization tools
- Complex RBAC configurations for cross-namespace Secret access
- ServiceAccount-based cross-namespace authentication
