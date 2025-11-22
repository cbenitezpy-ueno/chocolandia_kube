# Implementation Plan: Redis Deployment with Beersystem Migration

**Branch**: `013-redis-deployment` | **Date**: 2025-11-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/013-redis-deployment/spec.md`

**Note**: This plan reflects the clarifications from `/speckit.clarify` session which expanded the scope to include migrating the existing beersystem application.

## Summary

Deploy a highly available Redis caching layer with 2 instances (primary-replica) in a dedicated "redis" namespace, accessible within the Kubernetes cluster and from the private network (192.168.4.0/24). The deployment includes persistent storage, authentication, monitoring integration, and MetalLB LoadBalancer. Additionally, **migrate the existing beersystem application** from its dedicated Redis instance to the new shared Redis using a planned downtime approach, then decommission the old Redis.

**Key Clarifications**:
- Namespace: Dedicated "redis" namespace (not "default")
- Release name: "redis-shared" → services: redis-shared-master.redis.svc.cluster.local
- Beersystem migration: Planned downtime (scale down → reconfigure → scale up)
- Credentials access: Secret replicated to both "redis" and "beersystem" namespaces
- Old Redis: Decommissioned after 24+ hours of successful operation

## Technical Context

**Language/Version**: N/A (infrastructure deployment)
**Primary Dependencies**: Redis 7.x (Bitnami Helm chart), MetalLB LoadBalancer, Prometheus Redis Exporter
**Storage**: Kubernetes PersistentVolumes via local-path-provisioner
**Testing**: Connectivity tests (redis-cli), replication tests, load testing (redis-benchmark), monitoring validation (Prometheus metrics), beersystem migration validation
**Target Platform**: K3s 1.28+ cluster on homelab hardware (4 nodes)
**Project Type**: Infrastructure deployment (Kubernetes + OpenTofu) + Application migration
**Performance Goals**: 10,000 ops/sec minimum, <10ms p95 latency for SET/GET operations
**Constraints**: Private network only (192.168.4.0/24), no public internet exposure, 2 instances maximum (primary + replica), planned downtime acceptable for beersystem migration
**Scale/Scope**: Cluster-wide shared caching service, migrating 1 production application (beersystem), decommissioning 1 old Redis instance

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Infrastructure as Code - OpenTofu First ✅

**Status**: PASS

- Redis deployment managed via OpenTofu using Helm provider
- Beersystem migration configuration changes managed via OpenTofu (kubectl patches)
- All Kubernetes resources (namespaces, Services, ConfigMaps, Secrets) defined in .tf files
- MetalLB LoadBalancer configuration in OpenTofu
- Old Redis decommissioning via OpenTofu destroy
- No manual kubectl apply or Helm CLI commands for deployment
- State tracked in OpenTofu state file

### II. GitOps Workflow ✅

**Status**: PASS

- All changes committed to feature branch `013-redis-deployment`
- OpenTofu plan will be reviewed before apply
- Migration steps documented and executed via OpenTofu
- Pull request required before merging to main
- Rollback via Git revert and OpenTofu apply

### III. Container-First Development ✅

**Status**: PASS

- Redis runs in containers (Bitnami Redis Helm chart)
- Stateless container design with persistent data in PersistentVolumes
- Health checks (liveness/readiness probes) configured
- Resource limits (CPU/memory) defined
- Beersystem already containerized (no changes required)

### IV. Observability & Monitoring - Prometheus + Grafana Stack ✅

**Status**: PASS

- Redis metrics exposed via Prometheus-compatible exporter (built-in redis_exporter)
- Integration with existing Prometheus/Grafana stack (monitoring namespace)
- Metrics: memory usage, connections, ops/sec, replication lag
- ServiceMonitor for Prometheus Operator auto-discovery
- Beersystem-specific Redis metrics tracked separately (by client labels)

### V. Security Hardening ✅

**Status**: PASS

- Network isolation: LoadBalancer restricted to private network (192.168.4.0/24)
- Authentication: Redis password stored in Kubernetes Secret
- Secret replication: Same password available in both "redis" and "beersystem" namespaces (simplifies cross-namespace access)
- Principle of least privilege: RBAC for Redis ServiceAccount (if needed)
- Resource limits: CPU/memory limits to prevent exhaustion
- No public internet exposure (FR-005)
- Disabled dangerous Redis commands (FLUSHDB, FLUSHALL, CONFIG, SHUTDOWN)

### VI. High Availability (HA) Architecture ✅

**Status**: PASS

- 2 Redis instances (primary + replica) for redundancy
- Persistent storage ensures data survives pod restarts
- Health checks enable automatic restart on failure
- **Note**: Redis Sentinel NOT included (out of scope per spec), so automatic failover is manual
- Cluster survives single Redis instance failure (reads continue from replica)
- Beersystem migration with planned downtime (acceptable for homelab)

### VII. Test-Driven Learning ✅

**Status**: PASS (with expanded test plan)

- OpenTofu validate/plan before apply
- Connectivity tests: redis-cli from cluster pod and private network host
- Performance tests: redis-benchmark for ops/sec validation
- Replication tests: Verify data sync between primary and replica
- Failure tests: Simulate instance failure and verify recovery
- Monitoring tests: Verify metrics appear in Prometheus/Grafana
- **Migration tests**: Verify beersystem functionality before and after migration
- **Validation period**: 24+ hours of operation before decommissioning old Redis

### VIII. Documentation-First ✅

**Status**: PASS

- This plan.md documents architecture and migration decisions
- research.md captures technology decisions (Helm chart choice, migration strategy)
- quickstart.md provides operational runbook (deployment, migration, testing, troubleshooting)
- data-model.md documents Redis configuration schema and namespace architecture
- Clarifications section in spec.md documents all 5 Q&A pairs from clarify session
- **ADR documented**: Planned downtime migration approach (vs. zero-downtime alternatives)
- **ADR documented**: Secret replication approach (vs. External Secrets Operator/RBAC cross-namespace)

### IX. Network-First Security ✅

**Status**: PASS

- LoadBalancer IP from MetalLB pool (192.168.4.203)
- Private network access only (192.168.4.0/24)
- No cross-VLAN routing required (Redis accessible on cluster VLAN and services VLAN via MetalLB)
- Dedicated namespace for network isolation ("redis" separate from "beersystem")
- **Assumption**: MetalLB already configured (dependency from spec)

### Constitution Compliance Summary

**Overall Status**: ✅ PASS - All requirements met

All core principles satisfied. No constitution violations. The expanded scope (beersystem migration) adds complexity but remains compliant with all principles.

**Key Compliance Notes**:
- Planned downtime is acceptable per homelab context (not production-critical)
- Secret replication is pragmatic security choice (avoids External Secrets Operator complexity)
- Migration follows GitOps workflow (all changes via OpenTofu)
- Testing expanded to cover migration scenarios

## Project Structure

### Documentation (this feature)

```text
specs/013-redis-deployment/
├── plan.md              # This file - updated with migration scope
├── research.md          # Technology decisions including migration strategy
├── data-model.md        # Redis configuration schema + namespace architecture
├── quickstart.md        # Deployment and migration operations guide
├── checklists/
│   └── requirements.md  # Spec quality validation (already complete)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/modules/redis-shared/
├── main.tf              # Helm release for Redis deployment (release name: "redis-shared")
├── namespace.tf         # Redis namespace creation
├── secrets.tf           # Redis credentials Secret (replicated to multiple namespaces)
├── services.tf          # LoadBalancer service for private network access
├── variables.tf         # Input variables (namespace, storage size, memory limits, LoadBalancer IP, replica namespaces)
├── outputs.tf           # Outputs (service names, LoadBalancer IP, secret name)
├── versions.tf          # Provider requirements (Helm, Kubernetes)
└── README.md            # Module documentation

terraform/modules/beersystem-migration/
├── main.tf              # Beersystem deployment patching for Redis migration
├── variables.tf         # Input variables (new Redis DNS, secret name)
├── outputs.tf           # Migration status outputs
└── README.md            # Migration module documentation

terraform/environments/chocolandiadc-mvp/
├── main.tf              # Root module calling redis-shared and beersystem-migration modules
├── redis-shared.tf      # Redis-shared-specific configuration
├── beersystem-migration.tf  # Beersystem migration configuration
└── outputs.tf           # Environment outputs

# Validation scripts
scripts/redis-shared/
├── test-connectivity.sh    # Test Redis connection from cluster and private network
├── test-replication.sh     # Verify primary-replica sync
├── test-monitoring.sh      # Verify Prometheus metrics collection
├── benchmark.sh            # Redis performance testing (redis-benchmark)
└── test-beersystem.sh      # Verify beersystem functionality after migration

# Migration scripts (called by OpenTofu)
scripts/redis-shared/migration/
├── scale-down-beersystem.sh   # Scale beersystem to 0 replicas
├── scale-up-beersystem.sh     # Scale beersystem to 1 replica
├── validate-beersystem.sh     # Validate beersystem connects to new Redis
└── cleanup-old-redis.sh       # Decommission old beersystem Redis deployment
```

**Structure Decision**: Redis deployed as OpenTofu module using Helm provider with custom naming ("redis-shared"). Module follows existing pattern (terraform/modules/{service}) but with dedicated namespace and migration module. Validation scripts in scripts/ directory align with existing test structure. Migration operations are orchestrated via OpenTofu calling bash scripts.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations identified. All constitution principles satisfied by this feature design.

**Complexity Justification (not violations)**:

The feature has **increased complexity** due to:
1. **Production application migration** (beersystem) - adds migration risk
2. **Cross-namespace Secret management** - requires replication strategy
3. **Validation period** (24+ hours) - extends implementation timeline
4. **Decommissioning old infrastructure** - requires cleanup phase

However, these complexities are **justified and necessary**:
- Migration is required per clarification (user chose Option A)
- Planned downtime simplifies migration (constitution allows for homelab context)
- Secret replication avoids External Secrets Operator dependency
- Validation period ensures production stability before cleanup

**Mitigation**:
- Phased implementation: Deploy new Redis → Migrate beersystem → Decommission old
- Rollback plan: Keep old Redis until 24+ hour validation passes
- Testing at each phase before proceeding

## Implementation Phases

### Phase 0: Research & Decisions (Complete)

All research completed during initial planning and clarification sessions:

1. ✅ **Bitnami Redis Helm Chart** selected (matches PostgreSQL pattern)
2. ✅ **Primary-replica architecture** (no Sentinel) for 2 instances
3. ✅ **Built-in Prometheus exporter** (redis_exporter sidecar)
4. ✅ **Dual service configuration** (ClusterIP + LoadBalancer)
5. ✅ **Dedicated "redis" namespace** for shared service
6. ✅ **Release name "redis-shared"** to avoid conflicts
7. ✅ **Planned downtime migration** for beersystem
8. ✅ **Secret replication** to "beersystem" namespace
9. ✅ **24+ hour validation** before decommissioning old Redis

### Phase 1: Design & Contracts (Current)

**Status**: In progress - updating artifacts with migration scope

**Tasks**:
1. Update research.md with migration strategy decisions
2. Update data-model.md with namespace architecture and Secret replication
3. Update quickstart.md with migration procedures
4. Update agent context (CLAUDE.md)

**Outputs**:
- research.md (updated)
- data-model.md (updated)
- quickstart.md (updated)
- CLAUDE.md (updated)

### Phase 2: Task Generation (Next)

**Status**: Pending - run `/speckit.tasks` after Phase 1 complete

**Estimated Task Categories**:
1. **Setup**: Create "redis" namespace, configure OpenTofu modules
2. **Core Redis Deployment**: Deploy redis-shared with Helm, configure MetalLB LoadBalancer
3. **Monitoring Integration**: Configure ServiceMonitor, validate Prometheus metrics
4. **Beersystem Migration Prep**: Validate beersystem configuration, create migration plan
5. **Beersystem Migration Execution**: Scale down → reconfigure → scale up → validate
6. **Old Redis Decommissioning**: 24+ hour validation → cleanup old deployment
7. **Final Validation**: Complete test suite, documentation updates

---

## Migration-Specific Risks & Mitigations

### Risk 1: Beersystem Downtime During Migration

**Impact**: HIGH - Beersystem unavailable during migration window
**Likelihood**: CERTAIN (planned downtime approach)
**Mitigation**:
- Schedule migration during low-usage window
- Communicate downtime to users in advance
- Keep old Redis running until validation passes (rollback option)
- Estimate downtime: 5-10 minutes (scale down → reconfigure → scale up)

### Risk 2: Beersystem Configuration Errors

**Impact**: HIGH - Beersystem fails to connect to new Redis
**Likelihood**: MEDIUM (manual configuration changes)
**Mitigation**:
- Pre-validate Redis DNS name (redis-shared-master.redis.svc.cluster.local)
- Pre-validate Secret exists in "beersystem" namespace
- Test configuration changes in staging/development first (if available)
- Keep old Redis running for rollback

### Risk 3: Old Redis Premature Decommissioning

**Impact**: MEDIUM - If old Redis deleted too early, rollback is impossible
**Likelihood**: LOW (24+ hour validation period)
**Mitigation**:
- Enforce 24+ hour validation period before cleanup
- Document rollback procedure in quickstart.md
- Monitor beersystem metrics/logs during validation period

### Risk 4: Cross-Namespace Secret Sync Failure

**Impact**: MEDIUM - Beersystem cannot authenticate to new Redis
**Likelihood**: LOW (OpenTofu creates both Secrets atomically)
**Mitigation**:
- OpenTofu creates Secrets in both namespaces before Helm release
- Validate both Secrets exist before migration
- Test Secret access from beersystem namespace before scaling up

### Risk 5: MetalLB IP Conflict

**Impact**: LOW - Redis LoadBalancer IP already in use
**Likelihood**: VERY LOW (192.168.4.203 confirmed available)
**Mitigation**:
- Pre-validate IP availability (already done: 192.168.4.203 free)
- OpenTofu plan will fail if IP in use

---

## Success Criteria Validation

**SC-001**: Applications within the cluster can connect to Redis and complete cache operations (SET/GET) in under 10 milliseconds for 95% of requests
- **Validation**: redis-benchmark test + beersystem latency monitoring

**SC-002**: Redis remains available for cluster applications even when one of the two instances fails
- **Validation**: Failover test (kill primary pod, verify reads continue from replica)

**SC-003**: Redis is accessible from any host on the 192.168.4.0/24 private network within 100 milliseconds
- **Validation**: redis-cli test from private network host

**SC-004**: Redis is completely inaccessible from any IP address outside the private network
- **Validation**: Connection test from external network (should timeout/reject)

**SC-005**: Monitoring dashboards display real-time metrics for both Redis instances with updates every 15 seconds or less
- **Validation**: Prometheus query verification, Grafana dashboard check

**SC-006**: Redis handles at least 10,000 operations per second without performance degradation
- **Validation**: redis-benchmark load test

**SC-007**: Redis data persists across instance restarts with zero data loss for acknowledged writes
- **Validation**: Write test data → restart pods → verify data exists

**SC-008**: Unauthorized connection attempts (without valid credentials) are rejected 100% of the time
- **Validation**: Connection attempt without password (should fail)

**Additional SC (Migration)**:
- **SC-009**: Beersystem successfully connects to redis-shared and operates identically to before migration
  - **Validation**: Beersystem functional tests (login, session, cache operations)
- **SC-010**: Old beersystem Redis is cleanly decommissioned after 24+ hours with no errors
  - **Validation**: kubectl delete validation, beersystem continues operating

---

## Next Steps

1. **Complete Phase 1**: Update research.md, data-model.md, quickstart.md with migration details
2. **Update Agent Context**: Run `.specify/scripts/bash/update-agent-context.sh claude`
3. **Generate Tasks**: Run `/speckit.tasks` to create detailed implementation tasks
4. **Review & Execute**: Review tasks.md, execute phased implementation

**Estimated Timeline**:
- Phase 2 (Redis Deployment): 2-3 hours
- Phase 3 (Beersystem Migration): 1-2 hours (including validation)
- Phase 4 (Old Redis Cleanup): 15 minutes (after 24+ hour validation)
- **Total**: ~4-5 hours active work + 24+ hour validation period

**Ready to proceed**: Yes - all clarifications resolved, constitution compliant, phased approach documented
