# Research & Technology Decisions: Redis Deployment

**Feature**: 013-redis-deployment
**Date**: 2025-11-20
**Status**: Complete

## Overview

This document captures research findings and technology decisions for deploying Redis in the chocolandia_kube homelab cluster. All decisions align with the project constitution (Infrastructure as Code, HA, Observability, Security).

---

## Decision 1: Deployment Method - Bitnami Redis Helm Chart

### Decision

Use the **Bitnami Redis Helm Chart** (chart version ~23.2.x) deployed via OpenTofu Helm provider.

### Rationale

1. **Proven pattern**: Matches existing PostgreSQL deployment (terraform/modules/postgresql-cluster/postgresql.tf uses Bitnami PostgreSQL chart)
2. **Constitution alignment**:
   - Infrastructure as Code: Helm chart managed via OpenTofu
   - Container-first: Prebuilt, tested container images
   - HA support: Built-in primary-replica architecture
   - Observability: Integrated Prometheus exporter
3. **Feature completeness**:
   - Primary-replica replication (FR-005)
   - Persistent storage configuration (FR-006)
   - Authentication via Kubernetes Secret (FR-010, FR-011)
   - Health checks and resource limits (FR-009, FR-012)
   - Metrics exporter (FR-007)
4. **Maintainability**: Bitnami charts are well-documented, actively maintained, and widely used in production
5. **Consistency**: Using same chart family as PostgreSQL simplifies operations and troubleshooting

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| Custom Kubernetes manifests | Full control, minimal dependencies | High maintenance, no preset HA patterns | Violates "don't reinvent the wheel" principle; Helm chart provides battle-tested configuration |
| Official Redis Helm chart (redis/redis) | Official support | Less feature-rich than Bitnami, weaker HA support | Bitnami chart has better HA, monitoring, and documentation |
| Redis Operator (e.g., Spotahome) | GitOps-native, advanced HA | Additional complexity, CRDs, learning curve | Overkill for 2-instance deployment; Sentinel not required per spec |
| Manual Docker deployment | Simple for single instance | No HA, no K8s integration, not IaC | Violates Infrastructure as Code and Container-First principles |

### Implementation Notes

- Helm chart repository: `https://charts.bitnami.com/bitnami`
- Chart name: `redis`
- Target version: `23.2.x` (Redis 8.2.x, latest stable)
- Deployment via OpenTofu `helm_release` resource

---

## Decision 2: Redis Architecture - Primary-Replica (No Sentinel)

### Decision

Deploy Redis with **primary-replica replication** using 2 instances (1 primary + 1 replica) **without Redis Sentinel**.

### Rationale

1. **Spec requirement**: FR-001 specifies exactly 2 Redis instances; FR-005 requires replication
2. **Scope boundary**: Spec explicitly excludes "Redis Sentinel for automatic failover orchestration"
3. **Simplicity**: Primary-replica provides data redundancy without sentinel complexity
4. **HA alignment**: Meets constitution HA principle (survives single instance failure for reads, manual failover for writes)
5. **Learning value**: Demonstrates replication concepts without overengineering for 2-instance setup

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| Redis Sentinel (3+ instances) | Automatic failover, production-grade HA | Requires 3+ instances (odd number for quorum), added complexity | Out of scope per spec; exceeds 2-instance constraint |
| Redis Cluster (sharding) | Horizontal scaling, distributed data | Requires 6+ instances (3 primary + 3 replicas), high complexity | Out of scope per spec; massive overkill for cache workload |
| Standalone (single instance) | Simplest setup | No redundancy, single point of failure | Violates FR-005 (replication) and HA principle |

### Failure Handling

- **Primary failure**: Manual failover required (promote replica to primary via Redis commands or Helm upgrade)
- **Replica failure**: Reads continue from primary; replica auto-recovers on pod restart
- **Both instances fail**: Data persists in PVCs; pods restart via K8s (liveness/readiness probes)

### Implementation Notes

- Bitnami chart supports primary-replica via `architecture: replication`
- `master.replicaCount: 1` (primary instance)
- `replica.replicaCount: 1` (replica instance)
- Helm values: `auth.enabled: true` for password authentication

---

## Decision 3: Monitoring - Bitnami Chart Built-in Prometheus Exporter

### Decision

Use the **built-in Prometheus exporter** (redis_exporter) provided by the Bitnami Redis Helm chart.

### Rationale

1. **Existing infrastructure confirmed**:
   - `monitoring` namespace has kube-prometheus-stack deployed
   - Prometheus and Grafana are operational (Constitution Principle IV satisfied)
2. **Chart integration**: Bitnami chart includes prometheus/redis_exporter as optional sidecar
3. **ServiceMonitor support**: Chart can create ServiceMonitor CRD for Prometheus Operator auto-discovery
4. **Proven pattern**: Matches PostgreSQL deployment (uses `metrics.enabled: true` and `metrics.serviceMonitor`)
5. **Metrics coverage**: redis_exporter provides all required metrics (FR-007):
   - Memory usage (`redis_memory_used_bytes`)
   - Connection count (`redis_connected_clients`)
   - Operations per second (`redis_commands_processed_total`)
   - Replication status (`redis_connected_slaves`, `redis_master_repl_offset`)

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| Standalone redis_exporter deployment | Decoupled from Redis pods | Extra deployment to manage, manual configuration | Unnecessary complexity; built-in exporter is simpler |
| Custom metrics collection (StatsD/Telegraf) | Flexible metrics pipeline | Requires additional infrastructure, non-standard | No added value over Prometheus; violates observability principle |
| No monitoring | Simplest option | Violates Constitution Principle IV (NON-NEGOTIABLE) | Non-compliant with mandatory monitoring requirement |

### Implementation Notes

- Helm values:
  ```yaml
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: monitoring
      interval: 30s
  ```
- ServiceMonitor will be auto-discovered by Prometheus Operator
- Metrics port: 9121 (redis_exporter default)
- Grafana dashboards: Use existing Redis dashboards from Grafana Labs (IDs: 11835, 12776)

---

## Decision 4: Network Access - Dual Service Configuration (ClusterIP + LoadBalancer)

### Decision

Deploy **two Kubernetes Services**:
1. **ClusterIP service** (`redis-master`) for internal cluster access (FR-002)
2. **LoadBalancer service** (`redis-external`) for private network access (FR-003)

### Rationale

1. **Spec requirements**:
   - FR-002: Cluster-internal DNS access → ClusterIP service
   - FR-003: Private network (192.168.4.0/24) access → LoadBalancer service
2. **Security isolation**: Separate services prevent accidental public exposure
3. **MetalLB integration**: LoadBalancer service uses MetalLB IP pool (192.168.4.200-192.168.4.210)
4. **Flexibility**: Applications choose cluster-internal (faster) or private network access
5. **Standard pattern**: Matches PostgreSQL deployment (uses LoadBalancer for external, ClusterIP for internal)

### MetalLB IP Assignment

**Current MetalLB Pool Usage** (from cluster query):
- `192.168.4.200` - postgres-ha-postgresql-primary
- `192.168.4.201` - pihole-dns
- `192.168.4.202` - traefik

**Redis IP Assignment**:
- `192.168.4.203` - redis-external (LoadBalancer for private network)

**Available IPs**: 192.168.4.204 - 192.168.4.210 (7 IPs remaining)

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| Single LoadBalancer service | Simpler configuration | Exposes cluster-internal traffic to network (performance overhead) | Inefficient; cluster apps should use fast internal networking |
| Single ClusterIP service | Simplest option | No private network access (violates FR-003) | Fails to meet functional requirements |
| NodePort service | No MetalLB dependency | Non-standard ports (30000+), requires node IP knowledge | Violates network-first security (unpredictable ports) |

### Implementation Notes

- Bitnami chart creates ClusterIP service by default (`redis-master`)
- Additional LoadBalancer service defined in Kubernetes manifest or Helm values override
- LoadBalancer annotations:
  ```yaml
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.4.203
    annotations:
      metallb.universe.tf/address-pool: eero-pool
  ```

---

## Decision 5: Authentication - Kubernetes Secret with Auto-Generated Password

### Decision

Store Redis password in a **Kubernetes Secret** created by OpenTofu, with password auto-generated using `random_password` provider.

### Rationale

1. **Security**: Passwords not hardcoded in .tf files or Git
2. **Constitution compliance**: Meets Security Hardening principle (Secrets management)
3. **Proven pattern**: Matches PostgreSQL module (uses `kubernetes_secret.postgresql_credentials`)
4. **OpenTofu native**: Uses standard Terraform `random_password` resource
5. **Requirement alignment**: FR-010 (authentication required), FR-011 (secure storage)

### Implementation Notes

```hcl
resource "random_password" "redis_password" {
  length  = 32
  special = true
}

resource "kubernetes_secret" "redis_credentials" {
  metadata {
    name      = "redis-credentials"
    namespace = var.namespace
  }

  data = {
    redis-password = random_password.redis_password.result
  }
}
```

- Bitnami chart uses `auth.existingSecret` to reference the secret
- Secret key: `redis-password` (Bitnami chart default)
- Password rotation: Manual (update secret, restart pods)

---

## Decision 6: Persistent Storage - Local-Path-Provisioner (10Gi per instance)

### Decision

Use **local-path-provisioner** (existing in cluster) with **10Gi** PersistentVolume per Redis instance (primary + replica).

### Rationale

1. **Existing infrastructure**: Spec assumes local-path-provisioner available (confirmed in cluster)
2. **Proven pattern**: Matches PostgreSQL deployment (uses local-path for PVCs)
3. **Cache workload**: Redis is ephemeral cache; 10Gi sufficient for most workloads
4. **Constitution compliance**: Uses distributed storage awareness (single-point-of-failure acknowledged)
5. **Requirement alignment**: FR-006 (persist data across pod restarts)

### Storage Sizing

| Data Type | Estimated Size | Notes |
|-----------|----------------|-------|
| Session data | 100MB - 1GB | Depends on concurrent users |
| Application cache | 1GB - 5GB | Frequently accessed data |
| Temporary state | 100MB - 500MB | Short-lived data |
| **Total** | **~6GB** | 10Gi provides 66% buffer |

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| Longhorn distributed storage | Replicated across nodes, no single point of failure | Adds complexity, requires additional setup | Overkill for cache workload; Redis already has replica for redundancy |
| NFS on Raspberry Pi | Centralized storage | Single point of failure (Pi), network latency | Slower than local storage; Pi failure impacts Redis |
| No persistence (in-memory only) | Simplest option | Data loss on restart (violates FR-006) | Fails functional requirements |

### Implementation Notes

- Helm values:
  ```yaml
  master:
    persistence:
      enabled: true
      storageClass: "local-path"
      size: 10Gi
  replica:
    persistence:
      enabled: true
      storageClass: "local-path"
      size: 10Gi
  ```

---

## Decision 7: Resource Limits - Conservative Allocation (1 CPU, 2GB RAM per instance)

### Decision

Allocate **1 CPU and 2GB RAM** per Redis instance (primary + replica) with resource limits enforced.

### Rationale

1. **Cache workload**: Redis is CPU-efficient; 1 CPU handles 10k+ ops/sec
2. **Memory**: 2GB RAM sufficient for 1GB dataset + overhead (Redis ~2x memory for fork/copy-on-write)
3. **Constitution compliance**: FR-012 (resource limits), Security Hardening principle
4. **Cluster capacity**: 4-node cluster can accommodate 2 Redis instances without resource exhaustion
5. **Performance targets**: Meets SC-006 (10,000 ops/sec)

### Resource Calculation

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Justification |
|-----------|-------------|-----------|----------------|--------------|---------------|
| Redis primary | 500m | 1000m | 1Gi | 2Gi | Handles writes + reads |
| Redis replica | 250m | 1000m | 1Gi | 2Gi | Handles reads only |
| redis_exporter | 50m | 100m | 64Mi | 128Mi | Lightweight metrics collection |
| **Total** | **800m** | **2200m** | **~2.1Gi** | **~4.3Gi** | Fits comfortably in 4-node cluster |

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| 2 CPU, 4GB RAM | Higher performance ceiling | Resource waste (Redis won't use it for cache workload) | Overprovisioning for cache use case |
| 500m CPU, 1GB RAM | Minimal resource usage | Potential performance issues under load | Might not meet 10k ops/sec target (SC-006) |
| No limits | Maximum flexibility | Risk of resource exhaustion (violates FR-012) | Non-compliant with functional requirements |

### Implementation Notes

```yaml
master:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi

replica:
  resources:
    requests:
      cpu: 250m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi

metrics:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi
```

---

## Decision 8: Testing Strategy - Multi-Phase Validation

### Decision

Implement **four test phases**: connectivity, replication, performance, and monitoring validation.

### Rationale

1. **Constitution compliance**: Test-Driven Learning principle (Principle VII)
2. **Requirement coverage**: Tests validate all success criteria (SC-001 to SC-008)
3. **Operational readiness**: Ensures Redis works before applications depend on it
4. **Learning value**: Tests teach Redis operations and troubleshooting

### Test Phases

| Phase | Tools | Validates | Success Criteria |
|-------|-------|-----------|------------------|
| 1. Connectivity | redis-cli (cluster pod), redis-cli (private network host) | FR-002, FR-003, FR-010 | SC-001, SC-003, SC-008 |
| 2. Replication | redis-cli INFO replication | FR-005 | Data sync between primary/replica |
| 3. Performance | redis-benchmark | FR-013 | SC-006 (10k ops/sec) |
| 4. Monitoring | Prometheus query, Grafana dashboard | FR-007, FR-008 | SC-005 (metrics visible) |

### Test Scripts

1. **test-connectivity.sh**:
   - Deploy temporary pod with redis-cli
   - Connect to `redis-master.default.svc.cluster.local:6379`
   - Authenticate with password from secret
   - Execute SET/GET commands
   - Connect from private network host (192.168.4.X) to LoadBalancer IP
   - Verify authentication rejection without password

2. **test-replication.sh**:
   - Connect to primary and replica
   - Write data to primary
   - Verify data appears on replica
   - Check `INFO replication` output for sync status

3. **benchmark.sh**:
   - Run `redis-benchmark -h redis-master -p 6379 -a <password> -t set,get -n 100000 -c 50`
   - Verify >10,000 ops/sec
   - Check p95 latency <10ms

4. **test-monitoring.sh**:
   - Query Prometheus: `redis_memory_used_bytes`, `redis_connected_clients`, `redis_commands_processed_total`
   - Verify metrics exist for both instances
   - Check Grafana dashboard (if created)

---

## Infrastructure Verification

### Existing Infrastructure Status

✅ **MetalLB**: Operational (3 LoadBalancers currently assigned)
✅ **Prometheus/Grafana**: Deployed in `monitoring` namespace (kube-prometheus-stack)
✅ **local-path-provisioner**: Available for persistent storage
✅ **Helm**: Configured in OpenTofu (provider version ~2.0)

### IP Availability

- **Next available MetalLB IP**: 192.168.4.203 (confirmed)
- **IP pool capacity**: 8 IPs remaining (203-210)
- **Allocation**: redis-external will use 192.168.4.203

### Namespace

- **Target namespace**: `default` (or create `redis` namespace for isolation)
- **Decision**: Use `default` namespace initially for simplicity (matches Pi-hole pattern)
- **Future**: Migrate to dedicated `redis` namespace if multiple Redis instances needed

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Single node failure (local-path PVC) | Medium | High | Accept risk; Redis replica provides read availability; manual failover for writes |
| Memory eviction under load | Low | Medium | Configure `maxmemory-policy allkeys-lru`; monitor memory usage |
| Network partition (primary-replica) | Low | High | Health checks detect split; manual intervention required |
| Password exposure | Low | High | Store in K8s Secret; rotate periodically; use RBAC to restrict access |
| Resource exhaustion | Low | Medium | Enforce resource limits; monitor CPU/memory via Prometheus |

---

## Summary

All research items from Constitution Check (plan.md) are resolved:

1. ✅ **Prometheus/Grafana confirmed**: kube-prometheus-stack deployed in `monitoring` namespace
2. ✅ **Helm chart selected**: Bitnami Redis chart 23.2.x (matches PostgreSQL pattern)
3. ✅ **Redis exporter chosen**: Built-in prometheus/redis_exporter sidecar
4. ✅ **MetalLB IP verified**: 192.168.4.203 available for redis-external LoadBalancer
5. ✅ **Test procedures documented**: Four-phase validation strategy defined

**Next Phase**: Phase 1 (Design & Contracts) - Update data-model.md and quickstart.md with migration details

---

## NEW DECISIONS FROM CLARIFICATION SESSION (2025-11-20)

The following decisions were made during the `/speckit.clarify` session, which expanded the scope to include migrating the existing beersystem application.

---

## Decision 9: Namespace Architecture - Dedicated "redis" Namespace

### Decision

Deploy Redis in a **dedicated "redis" namespace** (not "default" or "beersystem").

### Rationale

1. **Isolation**: Separates shared infrastructure service from application namespaces
2. **Avoids conflicts**: Beersystem namespace already has a service named "redis"
3. **Organization**: Clear separation of concerns (infrastructure vs. applications)
4. **Scalability**: Establishes pattern for future shared services
5. **RBAC simplification**: Namespace-level permissions easier to manage

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| Namespace "default" | Simple, matches current Pi-hole pattern | Cluttered, no logical grouping | Poor organization; default namespace overused |
| Namespace "beersystem" | Reuse existing namespace | Conflicts with existing "redis" service, unclear ownership | Name collision; shared service shouldn't be in app namespace |
| Namespace "shared-services" | Generic for all shared services | Overly generic, harder to manage granular RBAC | Premature generalization; "redis" namespace is clearer |

### Implementation Notes

- Create namespace via OpenTofu: `resource "kubernetes_namespace" "redis"`
- Label namespace: `name: redis`, `type: shared-service`
- Service DNS: `redis-shared-master.redis.svc.cluster.local`

---

## Decision 10: Release Naming - "redis-shared"

### Decision

Name the Helm release **"redis-shared"** to generate service names `redis-shared-master` and `redis-shared-replicas`.

### Rationale

1. **Explicit clarity**: "shared" indicates this is a shared service, not app-specific
2. **Avoids conflicts**: Different from "redis" service in beersystem namespace
3. **Self-documenting**: DNS name `redis-shared-master.redis.svc.cluster.local` clearly indicates purpose
4. **Future-compatible**: Allows for additional Redis deployments (e.g., "redis-cache", "redis-queue") if needed

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| Release "redis" | Simple, short DNS names | Less descriptive, conflicts with beersystem naming | Ambiguous; doesn't indicate shared nature |
| Release "redis-ha" | Emphasizes high availability | "HA" may be misleading (no Sentinel) | Technically inaccurate; primary-replica isn't full HA |
| Release "cluster-redis" | Indicates cluster-wide service | Confusing with "Redis Cluster" mode (sharding) | Terminology conflict; "cluster" has specific Redis meaning |

### Implementation Notes

- OpenTofu: `name = "redis-shared"` in `helm_release` resource
- Services created: `redis-shared-master`, `redis-shared-replicas`
- LoadBalancer service: `redis-shared-external`

---

## Decision 11: Beersystem Migration Strategy - Planned Downtime

### Decision

Migrate beersystem from its dedicated Redis to the new shared Redis using a **planned downtime** approach:
1. Scale down beersystem to 0 replicas
2. Deploy new redis-shared
3. Reconfigure beersystem deployment (new Redis DNS + credentials)
4. Scale up beersystem to 1 replica
5. Validate 24+ hours
6. Decommission old Redis

### Rationale

1. **Simplicity**: Straightforward process, minimal moving parts
2. **Lower risk**: No complex synchronization or dual-running state
3. **Acceptable downtime**: Homelab environment, ~5-10 minute outage acceptable
4. **Clean cutover**: No data migration needed (Redis is cache, ephemeral data)
5. **Rollback plan**: Old Redis remains until validation passes

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| Blue-green deployment | Zero downtime, gradual migration | Requires pre-deployment and testing of new Redis, more complex orchestration | Unnecessary complexity for homelab; downtime is acceptable |
| Rolling update | Partial downtime, mixed state | Complex: 2 replicas (one old Redis, one new), data inconsistency risk | Beersystem only has 1 replica; rolling update not applicable |
| Feature flag in beersystem | Gradual migration, easy rollback | Requires code changes in beersystem, testing burden | Code changes violate constraint (FR-016: config-only changes) |

### Failure Handling

- **Beersystem fails to start**: Rollback to old Redis (scale up old deployment, scale down beersystem, reconfigure to old Redis)
- **Beersystem starts but errors**: Keep old Redis running, investigate, rollback if needed
- **24+ hour validation fails**: Rollback to old Redis, troubleshoot new deployment

### Implementation Notes

- OpenTofu manages scaling: `kubectl scale deployment beersystem --replicas=0`
- Beersystem env vars: `REDIS_HOST=redis-shared-master.redis.svc.cluster.local`, `REDIS_PORT=6379`
- Old Redis NOT deleted until 24+ hour validation passes

---

## Decision 12: Cross-Namespace Secret Access - Secret Replication

### Decision

**Replicate** the Redis credentials Secret to both "redis" and "beersystem" namespaces using OpenTofu.

### Rationale

1. **Simplicity**: No additional operators or tools required
2. **Kubernetes-native**: OpenTofu creates multiple `kubernetes_secret` resources
3. **Atomic**: Both secrets created in same OpenTofu apply
4. **No RBAC complexity**: Beersystem pod reads secret from its own namespace (standard pattern)
5. **Easy rotation**: Update secret in both namespaces via single OpenTofu variable change

### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| External Secrets Operator | Automated sync, enterprise pattern | Additional dependency, complexity, learning curve | Overkill for 2 namespaces; adds unnecessary tooling |
| RBAC cross-namespace access | No secret duplication | Complex RBAC configuration, security risk (beersystem can read any secret in "redis" namespace) | Overly permissive RBAC; violates principle of least privilege |
| ServiceAccount with role binding | Fine-grained permissions | Very complex setup, non-standard pattern | Excessive complexity for simple credential sharing |
| ConfigMap (unencrypted) | Simplest option | Insecure, violates FR-011 (secure storage) | Fails security requirements |

### Implementation Notes

OpenTofu code:
```hcl
resource "random_password" "redis_password" {
  length  = 32
  special = true
}

resource "kubernetes_secret" "redis_credentials_redis_ns" {
  metadata {
    name      = "redis-credentials"
    namespace = "redis"
  }
  data = {
    redis-password = random_password.redis_password.result
  }
}

resource "kubernetes_secret" "redis_credentials_beersystem_ns" {
  metadata {
    name      = "redis-credentials"
    namespace = "beersystem"
  }
  data = {
    redis-password = random_password.redis_password.result
  }
}
```

Beersystem deployment references: `secretKeyRef: {name: redis-credentials, key: redis-password}`

---

## Decision 13: Old Redis Decommissioning - 24+ Hour Validation Period

### Decision

**Do not decommission** the old beersystem Redis deployment until **24+ hours** of successful operation with the new redis-shared.

### Rationale

1. **Safety**: Allows detection of intermittent issues not caught in initial testing
2. **Rollback capability**: Old Redis available if critical issues discovered
3. **Production stability**: Beersystem is production service; conservative approach warranted
4. **Monitoring period**: Time to observe metrics, logs, user reports
5. **Constitution alignment**: Test-driven learning principle (thorough validation)

### Validation Criteria (during 24+ hours)

- ✅ Beersystem remains operational (no crashes, restarts)
- ✅ Beersystem logs show no Redis connection errors
- ✅ Prometheus metrics show stable Redis connections from beersystem
- ✅ Beersystem functionality verified (login, session persistence, cache operations)
- ✅ No user-reported issues related to caching/sessions
- ✅ Redis performance metrics meet success criteria (SC-001: <10ms p95 latency)

### Implementation Notes

- Old Redis deployment: `kubectl get deployment redis -n beersystem` (do NOT delete yet)
- Validation checklist in quickstart.md
- After 24+ hours: `tofu destroy -target=module.beersystem_old_redis`

---

## Updated Risk Assessment

### New Risks from Migration Scope

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Beersystem downtime during migration | CERTAIN | HIGH | Schedule during low-usage window; communicate in advance; estimate 5-10 min |
| Beersystem configuration errors | MEDIUM | HIGH | Pre-validate DNS name and Secret; keep old Redis for rollback |
| Old Redis premature deletion | LOW | MEDIUM | Enforce 24+ hour validation period; document rollback procedure |
| Cross-namespace Secret sync failure | LOW | MEDIUM | OpenTofu creates both Secrets atomically; validate before migration |
| Beersystem incompatibility with new Redis | LOW | HIGH | Redis protocol is standard; beersystem uses standard client libraries |

---

## Updated Summary

All research items from Constitution Check AND clarification session are resolved:

1. ✅ **Prometheus/Grafana confirmed**: kube-prometheus-stack deployed in `monitoring` namespace
2. ✅ **Helm chart selected**: Bitnami Redis chart 23.2.x (matches PostgreSQL pattern)
3. ✅ **Redis exporter chosen**: Built-in prometheus/redis_exporter sidecar
4. ✅ **MetalLB IP verified**: 192.168.4.203 available for redis-shared-external LoadBalancer
5. ✅ **Test procedures documented**: Four-phase validation strategy + migration validation
6. ✅ **Namespace architecture**: Dedicated "redis" namespace for shared service
7. ✅ **Release naming**: "redis-shared" to avoid conflicts and improve clarity
8. ✅ **Migration strategy**: Planned downtime approach (scale down → reconfigure → scale up)
9. ✅ **Cross-namespace access**: Secret replication to "redis" and "beersystem" namespaces
10. ✅ **Decommissioning timeline**: 24+ hour validation before old Redis cleanup

**Scope Expansion Impact**:
- Original scope: Deploy Redis + configure HA + monitoring
- Expanded scope: Above + migrate beersystem + decommission old Redis
- Estimated timeline increase: +1-2 hours active work + 24+ hour validation period

**Next Phase**: Phase 1 (Design & Contracts) - Update data-model.md and quickstart.md with migration architecture and procedures
