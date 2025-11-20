# Implementation Tasks: Redis Deployment with Beersystem Migration

**Feature**: 013-redis-deployment
**Branch**: `013-redis-deployment`
**Generated**: 2025-11-20

## Overview

This document provides a complete, dependency-ordered task list for deploying a shared Redis service and migrating the beersystem application. Tasks are organized by user story to enable independent, incremental delivery.

**Total Estimated Tasks**: 45
**Parallel Opportunities**: High (independent user stories after foundational setup)
**Estimated Timeline**: 4-5 hours active work + 24+ hours validation

---

## Task Summary by Phase

| Phase | User Story | Task Count | Can Start After |
|-------|------------|------------|------------------|
| Phase 1 | Setup | 8 tasks | - |
| Phase 2 | Foundational | 7 tasks | Phase 1 complete |
| Phase 3 | US1: Internal Application Cache Access (P1) | 6 tasks | Phase 2 complete |
| Phase 4 | US3: Instance Health Monitoring (P1) | 4 tasks | Phase 2 complete (parallel with US1) |
| Phase 5 | US2: Private Network Access (P2) | 5 tasks | Phase 2 complete (parallel with US1/US3) |
| Phase 6 | US4: Beersystem Migration (P1) | 11 tasks | Phase 3, 4, 5 complete |
| Phase 7 | Polish & Cross-Cutting | 4 tasks | Phase 6 complete |

---

## Implementation Strategy

**MVP Scope**: User Story 1 only (Internal Application Cache Access)
- Deploy redis-shared with 2 instances
- Configure cluster-internal access
- Validate connectivity and replication
- **Delivers**: Functional shared Redis for new applications

**Incremental Delivery**:
1. **Iteration 1**: US1 (core Redis deployment)
2. **Iteration 2**: US3 + US2 (monitoring + private network - parallel)
3. **Iteration 3**: US4 (beersystem migration - depends on 1 + 2)
4. **Iteration 4**: Polish (documentation, optimization)

---

## Phase 1: Setup

**Goal**: Initialize project structure, create OpenTofu modules, prepare infrastructure

**Prerequisites**: None

**Tasks**:

- [ ] T001 Create redis namespace via terraform/modules/redis-shared/namespace.tf
- [ ] T002 Create redis-shared module directory structure (terraform/modules/redis-shared/)
- [ ] T003 Create versions.tf with provider requirements (Helm ~2.0, Kubernetes ~2.0, Random ~3.0) in terraform/modules/redis-shared/
- [ ] T004 Create variables.tf with input variables in terraform/modules/redis-shared/
- [ ] T005 Create locals.tf with common labels in terraform/modules/redis-shared/
- [ ] T006 Create outputs.tf with module outputs in terraform/modules/redis-shared/
- [ ] T007 Create validation scripts directory (scripts/redis-shared/)
- [ ] T008 [P] Create environment configuration in terraform/environments/chocolandiadc-mvp/redis-shared.tf

**Completion Criteria**:
- ✅ Module directory structure exists
- ✅ All infrastructure-as-code files created
- ✅ OpenTofu validate passes

---

## Phase 2: Foundational (Blocking Prerequisites)

**Goal**: Deploy core Redis infrastructure that all user stories depend on

**Prerequisites**: Phase 1 complete

**Dependencies**: These tasks MUST complete before any user story implementation

**Tasks**:

- [ ] T009 Generate Redis password using random_password resource in terraform/modules/redis-shared/secrets.tf
- [ ] T010 Create Redis credentials Secret in "redis" namespace in terraform/modules/redis-shared/secrets.tf
- [ ] T011 Create Redis credentials Secret in "beersystem" namespace (replication) in terraform/modules/redis-shared/secrets.tf
- [ ] T012 Configure Bitnami Redis Helm release (release name: "redis-shared") in terraform/modules/redis-shared/main.tf
- [ ] T013 Configure Redis primary instance (1 replica, 10Gi storage, 1CPU/2GB RAM) in terraform/modules/redis-shared/main.tf
- [ ] T014 Configure Redis replica instance (1 replica, 10Gi storage, 250m CPU/2GB RAM) in terraform/modules/redis-shared/main.tf
- [ ] T015 Configure Redis authentication, health checks, and resource limits in terraform/modules/redis-shared/main.tf

**Completion Criteria**:
- ✅ OpenTofu plan shows 2 Redis pods + 2 PVCs + 2 Secrets + 1 Helm release
- ✅ OpenTofu apply succeeds without errors
- ✅ `kubectl get pods -n redis` shows redis-shared-master-0 and redis-shared-replicas-0 Running

---

## Phase 3: User Story 1 - Internal Application Cache Access (P1)

**Goal**: Enable applications within the cluster to access Redis via ClusterIP service

**Why P1**: Core value proposition - shared caching layer for cluster applications

**Prerequisites**: Phase 2 complete (redis-shared deployed)

**Independent Test**: Deploy test pod → connect to redis-shared-master.redis.svc.cluster.local → SET/GET operations → verify data persists across pod restarts

**Tasks**:

- [ ] T016 [P] [US1] Verify ClusterIP service redis-shared-master exists (created by Helm chart)
- [ ] T017 [P] [US1] Create connectivity test script in scripts/redis-shared/test-connectivity.sh
- [ ] T018 [US1] Execute connectivity test from cluster pod (redis-cli connect, auth, SET/GET)
- [ ] T019 [P] [US1] Create replication test script in scripts/redis-shared/test-replication.sh
- [ ] T020 [US1] Execute replication test (write to primary, read from replica)
- [ ] T021 [US1] Validate US1 acceptance criteria (AS-1, AS-2, AS-3 from spec.md)

**Completion Criteria**:
- ✅ AS-1: Application pod connects to redis-shared-master.redis.svc.cluster.local and performs SET/GET successfully
- ✅ AS-2: Data written to primary is accessible from replica
- ✅ AS-3: Both Redis instances report as healthy

**Parallel Opportunity**: Can run in parallel with US3 (monitoring) and US2 (LoadBalancer)

---

## Phase 4: User Story 3 - Instance Health Monitoring (P1)

**Goal**: Integrate Redis metrics with Prometheus/Grafana for visibility

**Why P1**: Monitoring is critical for production reliability

**Prerequisites**: Phase 2 complete (redis-shared deployed)

**Independent Test**: Access Grafana → view Redis metrics → simulate failure (kill pod) → verify alert triggers

**Tasks**:

- [ ] T022 [P] [US3] Configure Prometheus redis_exporter in terraform/modules/redis-shared/main.tf (metrics.enabled: true)
- [ ] T023 [P] [US3] Configure ServiceMonitor for Prometheus Operator in terraform/modules/redis-shared/main.tf
- [ ] T024 [US3] Create monitoring validation script in scripts/redis-shared/test-monitoring.sh
- [ ] T025 [US3] Validate US3 acceptance criteria (AS-1, AS-2, AS-3 from spec.md)

**Completion Criteria**:
- ✅ AS-1: Grafana dashboard displays metrics for both instances (uptime, memory, connections, commands)
- ✅ AS-2: Simulated failure triggers alert; remaining instance continues serving
- ✅ AS-3: Performance metrics (ops/sec, latency, hit rates) accurately reported

**Parallel Opportunity**: Can run in parallel with US1 (connectivity) and US2 (LoadBalancer)

---

## Phase 5: User Story 2 - Private Network Access (P2)

**Goal**: Expose Redis on private network (192.168.4.0/24) via MetalLB LoadBalancer

**Why P2**: Provides flexibility for non-containerized access (lower priority than cluster access)

**Prerequisites**: Phase 2 complete (redis-shared deployed)

**Independent Test**: Connect from private network host (192.168.4.X) → redis-cli to 192.168.4.203 → auth → SET/GET

**Tasks**:

- [ ] T026 [P] [US2] Create LoadBalancer service in terraform/modules/redis-shared/services.tf (IP: 192.168.4.203)
- [ ] T027 [P] [US2] Configure MetalLB annotations (address-pool: eero-pool) in terraform/modules/redis-shared/services.tf
- [ ] T028 [US2] Apply OpenTofu changes and verify LoadBalancer IP assigned
- [ ] T029 [P] [US2] Create private network test script in scripts/redis-shared/test-private-network.sh
- [ ] T030 [US2] Validate US2 acceptance criteria (AS-1, AS-2, AS-3 from spec.md)

**Completion Criteria**:
- ✅ AS-1: Client on 192.168.4.0/24 connects to 192.168.4.203:6379 successfully
- ✅ AS-2: Connection from outside private network is blocked/times out
- ✅ AS-3: Authentication works; valid credentials grant access

**Parallel Opportunity**: Can run in parallel with US1 (connectivity) and US3 (monitoring)

---

## Phase 6: User Story 4 - Beersystem Migration (P1)

**Goal**: Migrate beersystem from dedicated Redis to shared Redis with planned downtime

**Why P1**: Critical for infrastructure consolidation and production stability

**Prerequisites**: Phase 3, 4, 5 complete (redis-shared fully operational and validated)

**Independent Test**: Scale down beersystem → reconfigure → scale up → verify functionality → 24+ hour validation → decommission old Redis

**Tasks**:

### Migration Preparation

- [ ] T031 [US4] Create beersystem-migration module directory (terraform/modules/beersystem-migration/)
- [ ] T032 [P] [US4] Create migration validation script in scripts/redis-shared/test-beersystem.sh
- [ ] T033 [US4] Backup beersystem deployment configuration (kubectl get deployment beersystem -n beersystem -o yaml > backup.yaml)
- [ ] T034 [US4] Document rollback procedure in specs/013-redis-deployment/quickstart.md

### Migration Execution

- [ ] T035 [US4] Scale down beersystem to 0 replicas (kubectl scale deployment beersystem --replicas=0 -n beersystem)
- [ ] T036 [US4] Verify beersystem pods terminated (kubectl get pods -n beersystem)
- [ ] T037 [US4] Update beersystem deployment with new Redis DNS in terraform/modules/beersystem-migration/main.tf (REDIS_HOST=redis-shared-master.redis.svc.cluster.local)
- [ ] T038 [US4] Update beersystem deployment with new Redis credentials in terraform/modules/beersystem-migration/main.tf (secretKeyRef: redis-credentials)
- [ ] T039 [US4] Apply beersystem configuration changes via OpenTofu
- [ ] T040 [US4] Scale up beersystem to 1 replica (kubectl scale deployment beersystem --replicas=1 -n beersystem)

### Migration Validation & Cleanup

- [ ] T041 [US4] Execute beersystem functional tests (login, session persistence, cache operations) via scripts/redis-shared/test-beersystem.sh
- [ ] T042 [US4] Monitor beersystem logs and metrics for 24+ hours (document in validation checklist)
- [ ] T043 [US4] Validate US4 acceptance criteria (AS-1 through AS-6 from spec.md)
- [ ] T044 [US4] Decommission old beersystem Redis deployment (kubectl delete deployment redis -n beersystem && kubectl delete svc redis -n beersystem)

**Completion Criteria**:
- ✅ AS-1: New redis-shared accepts connections and passes health checks
- ✅ AS-2: Beersystem configuration updated with new Redis DNS + credentials
- ✅ AS-3: Beersystem pod starts successfully and connects to redis-shared
- ✅ AS-4: Beersystem functionality works correctly (cache starts empty as expected)
- ✅ AS-5: After 24+ hours validation, old Redis deleted without errors
- ✅ AS-6: Beersystem-specific metrics visible in Prometheus/Grafana

**CRITICAL**: Do NOT proceed to T044 (decommission old Redis) until 24+ hours of successful operation

---

## Phase 7: Polish & Cross-Cutting Concerns

**Goal**: Performance validation, documentation updates, final optimization

**Prerequisites**: Phase 6 complete (beersystem migrated successfully)

**Tasks**:

- [ ] T045 [P] Create performance benchmark script in scripts/redis-shared/benchmark.sh (redis-benchmark target: 10k ops/sec)
- [ ] T046 [P] Execute performance benchmark and validate SC-006 (≥10,000 ops/sec)
- [ ] T047 [P] Update MetalLB IP assignment table in CLAUDE.md (add 192.168.4.203 - redis-shared-external)
- [ ] T048 Generate pull request with summary of changes and migration notes

**Completion Criteria**:
- ✅ Performance benchmarks meet all success criteria (SC-001 through SC-010)
- ✅ Documentation updated
- ✅ Pull request ready for review

---

## Dependencies & Parallel Execution

### Critical Path

```text
Phase 1 (Setup)
   ↓
Phase 2 (Foundational - redis-shared deployment)
   ↓
   ├─→ Phase 3 (US1: Internal Access) ──┐
   ├─→ Phase 4 (US3: Monitoring)      ──┼─→ Phase 6 (US4: Beersystem Migration)
   └─→ Phase 5 (US2: Private Network) ──┘        ↓
                                          Phase 7 (Polish)
```

### Parallel Execution Opportunities

**After Phase 2 completes**, the following can run **in parallel**:

- **US1 (T016-T021)**: Internal connectivity tests
- **US3 (T022-T025)**: Monitoring configuration
- **US2 (T026-T030)**: LoadBalancer setup

**Total parallelizable tasks**: 15 tasks (T016-T030)

**Sequential constraint**: Phase 6 (US4: Beersystem Migration) MUST wait for US1, US2, US3 to complete and be validated.

---

## User Story Completion Order

### MVP (Minimum Viable Product)

**Scope**: User Story 1 only
- **Tasks**: T001-T021 (21 tasks)
- **Deliverable**: Shared Redis accessible from cluster applications
- **Timeline**: ~2-3 hours

### Full Feature Delivery

**Recommended Order**:

1. **Phase 1-2**: Setup + Foundational (T001-T015) - **BLOCKING**
2. **Phase 3-5** (parallel): US1 + US3 + US2 (T016-T030)
3. **Phase 6**: US4 Beersystem Migration (T031-T044) - **BLOCKING** (depends on 1+2)
4. **Phase 7**: Polish (T045-T048)

**Total Timeline**: 4-5 hours active work + 24+ hours validation (T042)

---

## Task Execution Notes

### Critical Tasks (Cannot Be Parallelized)

- **T009-T015**: Foundational deployment (blocks everything)
- **T035-T040**: Beersystem migration execution (sequential steps)
- **T042**: 24+ hour validation (time-gated)
- **T044**: Decommission old Redis (MUST wait for T042)

### High-Risk Tasks

- **T035**: Scaling down beersystem (begins planned downtime)
- **T040**: Scaling up beersystem (ends planned downtime, ~5-10 min total)
- **T044**: Decommissioning old Redis (irreversible after PVC deletion)

### Rollback Points

- **Before T035**: No changes to production (safe to abort)
- **T035-T039**: Beersystem down, old Redis still running (rollback: scale up old beersystem)
- **After T040**: Beersystem on new Redis (rollback: reconfigure to old Redis, scale down/up)
- **After T044**: Old Redis deleted (rollback requires redeployment)

---

## Validation Checklist

### User Story 1 (Internal Access)

- [ ] Connect from cluster pod to redis-shared-master.redis.svc.cluster.local:6379
- [ ] Authenticate with password from redis-credentials secret
- [ ] Execute SET mykey "myvalue"
- [ ] Execute GET mykey (returns "myvalue")
- [ ] Verify data written to primary appears on replica
- [ ] Verify both pods report as Running/Ready

### User Story 2 (Private Network)

- [ ] Connect from host on 192.168.4.0/24 to 192.168.4.203:6379
- [ ] Authenticate with password
- [ ] Execute SET/GET operations
- [ ] Attempt connection from outside private network (should fail)

### User Story 3 (Monitoring)

- [ ] Port-forward to Prometheus: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
- [ ] Query: redis_memory_used_bytes{service="redis-shared-metrics"}
- [ ] Query: redis_connected_clients{service="redis-shared-metrics"}
- [ ] Query: redis_commands_processed_total{service="redis-shared-metrics"}
- [ ] Verify metrics exist for both master and replica
- [ ] Import Grafana dashboard (ID: 11835)

### User Story 4 (Beersystem Migration)

- [ ] Beersystem scaled down successfully (0/0 pods)
- [ ] New Redis operational and tested (US1, US2, US3 complete)
- [ ] Beersystem configuration updated (REDIS_HOST, secretKeyRef)
- [ ] Beersystem scaled up successfully (1/1 pods)
- [ ] Beersystem logs show no Redis connection errors
- [ ] Beersystem functionality verified (login, sessions, cache)
- [ ] 24+ hours monitoring shows stable operation
- [ ] Old Redis deployment deleted
- [ ] Beersystem continues operating normally after deletion

---

## Success Criteria Validation

| Criteria | Validation Method | Task | Status |
|----------|-------------------|------|--------|
| SC-001: <10ms p95 latency | redis-benchmark | T046 | Pending |
| SC-002: HA (survives failure) | Kill primary pod, verify reads from replica | T021 | Pending |
| SC-003: Private network access <100ms | redis-cli from 192.168.4.X | T030 | Pending |
| SC-004: No public internet access | Connection test from external IP | T030 | Pending |
| SC-005: Metrics update every 15s | Prometheus query refresh rate | T025 | Pending |
| SC-006: ≥10,000 ops/sec | redis-benchmark | T046 | Pending |
| SC-007: Data persists across restart | Write → restart pod → read | T021 | Pending |
| SC-008: Auth rejection (no password) | redis-cli without -a flag | T018 | Pending |
| SC-009: Beersystem functional | Login, session, cache tests | T041 | Pending |
| SC-010: Old Redis decommissioned | kubectl delete validation | T044 | Pending |

---

## Next Steps

1. **Review this task list** with team/stakeholders
2. **Execute Phase 1 (Setup)** - T001-T008
3. **Execute Phase 2 (Foundational)** - T009-T015
4. **Validate redis-shared deployment**: `kubectl get pods -n redis`, `kubectl get pvc -n redis`, `tofu output`
5. **Execute Phases 3-5 in parallel** (if resources available)
6. **Execute Phase 6 (Beersystem Migration)** - coordinate downtime window
7. **Wait 24+ hours for T042 validation**
8. **Execute Phase 7 (Polish)** and create pull request

**Ready to begin implementation**: Yes - all tasks defined with clear acceptance criteria
