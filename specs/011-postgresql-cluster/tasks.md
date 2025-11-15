# Tasks: PostgreSQL Cluster Database Service

**Input**: Design documents from `/specs/011-postgresql-cluster/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are included as this is an infrastructure feature requiring validation at each step

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Infrastructure as Code**: `terraform/modules/postgresql-cluster/`, `kubernetes/applications/postgresql/`
- **Documentation**: `docs/runbooks/`, `docs/architecture/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and MetalLB prerequisite

- [ ] T001 Verify K3s cluster operational status via `kubectl get nodes`
- [ ] T002 Verify ArgoCD is deployed and healthy via `kubectl get pods -n argocd`
- [ ] T003 [P] Install MetalLB in K3s cluster via Helm chart or manifest
- [ ] T004 [P] Configure MetalLB IP address pool for cluster VLAN in metallb-system namespace
- [ ] T005 Verify MetalLB speaker pods running via `kubectl get pods -n metallb-system`
- [ ] T006 Coordinate MetalLB IP pool with FortiGate DHCP exclusions (document range)
- [ ] T007 [P] Create PostgreSQL namespace via `kubectl create namespace postgresql`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T008 Create OpenTofu module directory structure at terraform/modules/postgresql-cluster/
- [ ] T009 [P] Create terraform/modules/postgresql-cluster/versions.tf with provider constraints
- [ ] T010 [P] Create terraform/modules/postgresql-cluster/variables.tf with input variables
- [ ] T011 [P] Create terraform/modules/postgresql-cluster/outputs.tf with connection endpoints
- [ ] T012 Create terraform/modules/postgresql-cluster/main.tf with provider configuration
- [ ] T013 Generate random passwords for PostgreSQL credentials using random provider
- [ ] T014 Create Kubernetes Secret for PostgreSQL credentials in terraform/modules/postgresql-cluster/secrets.tf
- [ ] T015 Configure Bitnami PostgreSQL HA Helm chart in terraform/modules/postgresql-cluster/postgresql.tf
- [ ] T016 Set PostgreSQL version to 16.x in Helm values
- [ ] T017 Configure primary-replica topology (replicaCount: 2) in Helm values
- [ ] T018 Configure asynchronous replication mode in Helm values
- [ ] T019 Configure PersistentVolumeClaim size (50Gi per instance) in Helm values
- [ ] T020 Configure resource limits (2 CPU, 4GB RAM per pod) in Helm values
- [ ] T021 Configure readiness and liveness probes in Helm values
- [ ] T022 [P] Create terraform/modules/postgresql-cluster/README.md with module documentation
- [ ] T023 Run `tofu init` in terraform/modules/postgresql-cluster/
- [ ] T024 Run `tofu validate` to verify module syntax
- [ ] T025 Run `tofu plan` to preview infrastructure changes

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Application Database Connectivity (Priority: P1) 🎯 MVP

**Goal**: Enable applications running in Kubernetes cluster to connect to PostgreSQL database for data persistence

**Independent Test**: Deploy a test application pod that connects to PostgreSQL, writes data, reads data back, and verifies persistence after pod restart

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T026 [P] [US1] Create connectivity test script at tests/integration/test_cluster_connectivity.sh
- [ ] T027 [P] [US1] Create persistence test script at tests/integration/test_data_persistence.sh
- [ ] T028 [P] [US1] Create replication test script at tests/integration/test_replication.sh

### Implementation for User Story 1

- [ ] T029 [US1] Create ClusterIP Service for primary instance in terraform/modules/postgresql-cluster/services.tf
- [ ] T030 [US1] Configure Service selector to route to primary pod (role: primary)
- [ ] T031 [US1] Set Service port to 5432 (standard PostgreSQL port)
- [ ] T032 [US1] Add DNS name output (postgres-ha-postgresql.postgresql.svc.cluster.local)
- [ ] T033 [US1] Apply OpenTofu configuration via `tofu apply`
- [ ] T034 [US1] Verify PostgreSQL pods are running via `kubectl get pods -n postgresql`
- [ ] T035 [US1] Verify ClusterIP Service is created via `kubectl get svc -n postgresql`
- [ ] T036 [US1] Test connection from test pod via `kubectl run test-postgres`
- [ ] T037 [US1] Verify replication is active via `SELECT * FROM pg_stat_replication;`
- [ ] T038 [US1] Create test database and verify data persistence
- [ ] T039 [US1] Document connection string format in quickstart.md

**Checkpoint**: At this point, User Story 1 should be fully functional - applications can connect to PostgreSQL from within K8s cluster

---

## Phase 4: User Story 2 - Internal Network Database Access (Priority: P2)

**Goal**: Enable system administrators on internal network to connect to PostgreSQL for maintenance and administration

**Independent Test**: Connect from internal network workstation using psql client, execute administrative queries, verify access control works

### Tests for User Story 2

- [ ] T040 [P] [US2] Create external connectivity test script at tests/integration/test_external_connectivity.sh
- [ ] T041 [P] [US2] Create admin access test script at tests/integration/test_admin_access.sh

### Implementation for User Story 2

- [ ] T042 [US2] Create LoadBalancer Service for external access in terraform/modules/postgresql-cluster/services.tf
- [ ] T043 [US2] Configure LoadBalancer IP from MetalLB pool (e.g., 192.168.10.100)
- [ ] T044 [US2] Configure loadBalancerSourceRanges to restrict access to cluster/management VLANs
- [ ] T045 [US2] Set Service port to 5432 (standard PostgreSQL port)
- [ ] T046 [US2] Apply OpenTofu configuration via `tofu apply`
- [ ] T047 [US2] Verify LoadBalancer IP assigned via `kubectl get svc -n postgresql postgres-ha-postgresql-external`
- [ ] T048 [US2] Configure FortiGate firewall rules to allow port 5432 from management VLAN
- [ ] T049 [US2] Test connection from internal network via `psql -h <metallb-ip>`
- [ ] T050 [US2] Verify credentials work from external client
- [ ] T051 [US2] Test connection rejection with invalid credentials
- [ ] T052 [US2] Document MetalLB IP and connection instructions in quickstart.md

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - cluster apps and internal network admins can connect

---

## Phase 5: User Story 3 - High Availability and Failover (Priority: P3)

**Goal**: Ensure database service remains available when individual instances fail, with automatic failure detection

**Independent Test**: Simulate primary pod failure, verify applications continue operating, verify replica promotion (manual), verify data consistency

### Tests for User Story 3

- [ ] T053 [P] [US3] Create failover test script at tests/integration/test_failover.sh
- [ ] T054 [P] [US3] Create recovery test script at tests/integration/test_recovery.sh

### Implementation for User Story 3

- [ ] T055 [US3] Verify streaming replication configuration in Helm values
- [ ] T056 [US3] Configure PodDisruptionBudget to ensure quorum during updates
- [ ] T057 [US3] Configure readiness probe to check replication lag
- [ ] T058 [US3] Configure liveness probe using pg_isready
- [ ] T059 [US3] Apply OpenTofu configuration via `tofu apply`
- [ ] T060 [US3] Test pod restart via `kubectl delete pod postgres-ha-postgresql-0`
- [ ] T061 [US3] Verify Kubernetes restarts pod automatically
- [ ] T062 [US3] Verify data persists after pod restart
- [ ] T063 [US3] Document manual failover procedure in docs/runbooks/postgresql-failover.md
- [ ] T064 [US3] Test manual replica promotion procedure
- [ ] T065 [US3] Verify Service endpoint remains stable during failover

**Checkpoint**: All user stories 1, 2, AND 3 are independently functional - HA and failover tested

---

## Phase 6: User Story 4 - Infrastructure as Code Management (Priority: P2)

**Goal**: Enable infrastructure operators to deploy and manage PostgreSQL cluster via GitOps with ArgoCD

**Independent Test**: Make configuration change in Git, verify ArgoCD detects and applies change, verify PostgreSQL cluster reflects new state

### Tests for User Story 4

- [ ] T066 [P] [US4] Create GitOps test script at tests/integration/test_argocd_sync.sh
- [ ] T067 [P] [US4] Create configuration drift test script at tests/integration/test_config_drift.sh

### Implementation for User Story 4

- [ ] T068 [US4] Create ArgoCD Application manifest at kubernetes/applications/postgresql/application.yaml
- [ ] T069 [US4] Configure Application to monitor Bitnami Helm chart repository
- [ ] T070 [US4] Configure Helm values override file at kubernetes/applications/postgresql/values/postgresql-values.yaml
- [ ] T071 [US4] Set automated sync policy (prune: true, selfHeal: true)
- [ ] T072 [US4] Set destination namespace to postgresql
- [ ] T073 [US4] Apply ArgoCD Application manifest via `kubectl apply -f application.yaml`
- [ ] T074 [US4] Verify ArgoCD detects and syncs application via `argocd app get postgresql-cluster`
- [ ] T075 [US4] Make configuration change in Helm values file
- [ ] T076 [US4] Commit and push change to Git repository
- [ ] T077 [US4] Verify ArgoCD auto-syncs change within 3 minutes
- [ ] T078 [US4] Verify PostgreSQL cluster reflects configuration change
- [ ] T079 [US4] Test rollback via Git revert and ArgoCD sync
- [ ] T080 [US4] Document GitOps workflow in docs/runbooks/postgresql-gitops.md

**Checkpoint**: All user stories are independently functional and managed via GitOps

---

## Phase 7: Observability & Monitoring

**Purpose**: Enable monitoring and observability for PostgreSQL cluster

- [ ] T081 [P] Create ServiceMonitor for PostgreSQL Exporter at terraform/modules/postgresql-cluster/monitoring.tf
- [ ] T082 [P] Configure Prometheus scraping for PostgreSQL metrics (port 9187)
- [ ] T083 [P] Create Grafana dashboard for PostgreSQL cluster health
- [ ] T084 [P] Configure alerts for replication lag > 60 seconds
- [ ] T085 [P] Configure alerts for storage utilization > 80%
- [ ] T086 [P] Configure alerts for connection count approaching limit
- [ ] T087 [P] Configure alerts for instance down
- [ ] T088 Apply monitoring configuration via `tofu apply`
- [ ] T089 Verify Prometheus is scraping PostgreSQL metrics
- [ ] T090 Verify Grafana dashboard displays cluster health
- [ ] T091 Test alert firing by simulating high replication lag
- [ ] T092 Document monitoring setup in docs/architecture/postgresql-monitoring.md

---

## Phase 8: Backup & Restore

**Purpose**: Enable automated backups and restore procedures

- [ ] T093 Create backup CronJob manifest at kubernetes/applications/postgresql/backup-cronjob.yaml
- [ ] T094 Configure pg_dump command in CronJob
- [ ] T095 Set backup schedule to daily at 02:00 UTC
- [ ] T096 Configure backup storage location (PersistentVolume or NFS)
- [ ] T097 Set retention policy to 7 days
- [ ] T098 Apply backup CronJob via `kubectl apply`
- [ ] T099 Trigger manual backup via `kubectl create job`
- [ ] T100 Verify backup file created successfully
- [ ] T101 Test restore procedure from backup file
- [ ] T102 Document backup and restore procedures in docs/runbooks/postgresql-backup-restore.md

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T103 [P] Update CLAUDE.md with PostgreSQL cluster context
- [ ] T104 [P] Create network diagram showing PostgreSQL access paths at docs/architecture/postgresql-network.png
- [ ] T105 [P] Document troubleshooting procedures in quickstart.md
- [ ] T106 [P] Create ADR for deployment method decision (Helm vs operator) at docs/architecture/adr-001-postgresql-deployment.md
- [ ] T107 [P] Create ADR for network access decision (LoadBalancer vs NodePort) at docs/architecture/adr-002-postgresql-network-access.md
- [ ] T108 Code review of all OpenTofu modules
- [ ] T109 Security review of credentials management
- [ ] T110 Performance validation (connection time, query latency)
- [ ] T111 [P] Run all integration tests from quickstart.md
- [ ] T112 Final validation of all success criteria from spec.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - User Story 1 (P1): Can start after Phase 2 - No dependencies on other stories
  - User Story 2 (P2): Can start after Phase 2 - Independent of US1 (uses different Service)
  - User Story 3 (P3): Can start after Phase 2 - Validates HA that US1/US2 rely on
  - User Story 4 (P2): Can start after Phase 2 - Manages deployment of US1/US2/US3
- **Observability (Phase 7)**: Depends on at least US1 being deployed
- **Backup (Phase 8)**: Depends on at least US1 being deployed
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Independent of US1 (different Service resource)
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Validates HA that US1/US2 implicitly rely on
- **User Story 4 (P2)**: Can start after Foundational (Phase 2) - Orchestrates deployment of US1/US2/US3 but doesn't block them

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Services before endpoints
- Infrastructure configuration (OpenTofu) before validation (kubectl)
- Core implementation before integration testing
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members
- Observability and Backup phases can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Create connectivity test script at tests/integration/test_cluster_connectivity.sh"
Task: "Create persistence test script at tests/integration/test_data_persistence.sh"
Task: "Create replication test script at tests/integration/test_replication.sh"

# These OpenTofu files can be created in parallel:
Task: "Create versions.tf with provider constraints"
Task: "Create variables.tf with input variables"
Task: "Create outputs.tf with connection endpoints"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (MetalLB, namespace)
2. Complete Phase 2: Foundational (OpenTofu module, Helm chart configuration) - CRITICAL
3. Complete Phase 3: User Story 1 (ClusterIP Service for cluster access)
4. **STOP and VALIDATE**: Test User Story 1 independently
   - Deploy test application
   - Verify connection from pod
   - Verify data persistence
   - Verify replication is working
5. Deploy to production if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP! Applications can connect)
3. Add User Story 2 → Test independently → Deploy/Demo (Admins can connect externally)
4. Add User Story 3 → Test independently → Deploy/Demo (HA validated and documented)
5. Add User Story 4 → Test independently → Deploy/Demo (GitOps enabled)
6. Add Observability → Prometheus/Grafana monitoring
7. Add Backup → Automated backups configured
8. Each phase adds value without breaking previous functionality

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (cluster access)
   - Developer B: User Story 2 (external access)
   - Developer C: User Story 3 (HA validation)
   - Developer D: User Story 4 (GitOps integration)
3. Stories complete and integrate independently
4. Observability and Backup can be done in parallel by additional team members

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (TDD approach)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Run `tofu plan` before each `tofu apply` to review changes
- Document all decisions and procedures as you go
- Test failover procedures in non-production first
- Keep MetalLB IP pool coordinated with FortiGate DHCP exclusions

---

## Success Criteria Validation

After completing all phases, validate against spec.md success criteria:

- **SC-001**: ✅ Connection time from K8s cluster < 5 seconds (measure with test app)
- **SC-002**: ✅ Connection time from internal network < 5 seconds (measure with psql)
- **SC-003**: ✅ Support 100+ concurrent connections (load test)
- **SC-004**: ✅ Data consistency 100% (write/read verification)
- **SC-005**: ✅ 99.9% uptime over 30 days (monitor with Prometheus)
- **SC-006**: ✅ Infrastructure changes via ArgoCD < 15 minutes
- **SC-007**: ✅ Failed instances detected < 30 seconds (readiness probe)
- **SC-008**: ✅ Query response time < 100ms for 95th percentile (measure with pgbench)

---

**Total Tasks**: 112
**Breakdown by Phase**:
- Setup: 7 tasks
- Foundational: 18 tasks (BLOCKING)
- User Story 1 (P1): 14 tasks (MVP)
- User Story 2 (P2): 13 tasks
- User Story 3 (P3): 13 tasks
- User Story 4 (P2): 13 tasks
- Observability: 12 tasks
- Backup: 10 tasks
- Polish: 12 tasks

**MVP Scope** (Minimum viable product):
- Phase 1: Setup (7 tasks)
- Phase 2: Foundational (18 tasks)
- Phase 3: User Story 1 only (14 tasks)
- **Total for MVP: 39 tasks**

**Parallel Opportunities**: 42 tasks marked [P] can run in parallel
**Independent Stories**: 4 user stories can be implemented in parallel after Foundational phase
