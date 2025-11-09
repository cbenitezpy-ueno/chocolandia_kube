# Tasks: Pi-hole DNS Ad Blocker

**Input**: Design documents from `/specs/003-pihole/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: Integration tests included for each user story as specified in spec.md acceptance scenarios

**Organization**: Tasks are grouped by user story (P1 → P2 → P3) to enable independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

## Path Conventions

Infrastructure deployment project:
- **OpenTofu modules**: `terraform/modules/pihole/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`
- **Integration tests**: `tests/integration/`
- **Documentation**: `docs/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and module structure

- [x] T001 Create Pi-hole OpenTofu module directory structure at terraform/modules/pihole/
- [x] T002 [P] Create manifests directory at terraform/modules/pihole/manifests/ for Kubernetes YAML files
- [x] T003 [P] Create integration test directory at tests/integration/ for Pi-hole tests
- [x] T004 [P] Create documentation directory at docs/ for Pi-hole guides (if not exists)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Verify K3s cluster is operational and nodes are Ready (prerequisite check)
- [x] T006 Verify K3s local-path-provisioner is running in kube-system namespace (prerequisite check)
- [x] T007 Verify kubectl access and kubeconfig at terraform/environments/chocolandiadc-mvp/kubeconfig
- [x] T008 Set KUBECONFIG environment variable for OpenTofu kubernetes provider
- [x] T009 [P] Create module variables file at terraform/modules/pihole/variables.tf
- [x] T010 [P] Create module outputs file at terraform/modules/pihole/outputs.tf

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Pi-hole Deployment on K3s Cluster (Priority: P1) 🎯 MVP

**Goal**: Deploy Pi-hole as a containerized workload on K3s cluster with DNS service accessible within cluster

**Independent Test**: Deploy Pi-hole, verify pod is Running, DNS service is accessible, and basic DNS queries are resolved correctly

### Implementation for User Story 1

- [ ] T011 [P] [US1] Create Kubernetes Secret manifest for admin password at terraform/modules/pihole/manifests/secret.yaml
- [ ] T012 [P] [US1] Create PersistentVolumeClaim manifest for /etc/pihole at terraform/modules/pihole/manifests/pvc.yaml
- [ ] T013 [US1] Create Pi-hole Deployment manifest with container spec at terraform/modules/pihole/manifests/deployment.yaml
- [ ] T014 [US1] Configure Pi-hole environment variables (TZ, admin password, upstream DNS, listening mode) in deployment.yaml
- [ ] T015 [US1] Configure volume mounts for /etc/pihole and PVC binding in deployment.yaml
- [ ] T016 [US1] Add security context with NET_BIND_SERVICE capability in deployment.yaml
- [ ] T017 [US1] Configure liveness probe (HTTP /admin/api.php, 60s initial delay, 10 failure threshold) in deployment.yaml
- [ ] T018 [US1] Configure readiness probe (HTTP /admin/api.php, 60s initial delay, 3 failure threshold) in deployment.yaml
- [ ] T019 [US1] Set resource limits (512Mi memory, 500m CPU) and requests (256Mi memory, 100m CPU) in deployment.yaml
- [ ] T020 [P] [US1] Create DNS Service manifest (ClusterIP, port 53 TCP+UDP) at terraform/modules/pihole/manifests/service-dns.yaml
- [ ] T021 [US1] Create OpenTofu main.tf file at terraform/modules/pihole/main.tf with kubernetes provider config
- [ ] T022 [US1] Add kubernetes_manifest resources for all YAML manifests in main.tf (Secret, PVC, Deployment, DNS Service)
- [ ] T023 [US1] Create module invocation file at terraform/environments/chocolandiadc-mvp/pihole.tf
- [ ] T024 [US1] Configure module variables (admin password, timezone, upstream DNS, node IPs) in pihole.tf
- [ ] T025 [US1] Run tofu init to initialize Pi-hole module
- [ ] T026 [US1] Run tofu validate to validate Pi-hole module syntax
- [ ] T027 [US1] Run tofu plan to preview Pi-hole deployment
- [ ] T028 [US1] Run tofu apply to deploy Pi-hole to K3s cluster

### Tests for User Story 1

- [ ] T029 [US1] Create integration test script at tests/integration/test-pihole-dns.sh
- [ ] T030 [US1] Add test for pod reaching Running state within 2 minutes in test-pihole-dns.sh
- [ ] T031 [US1] Add test for readiness probe passing in test-pihole-dns.sh
- [ ] T032 [US1] Add test for DNS service ClusterIP assignment in test-pihole-dns.sh
- [ ] T033 [US1] Add test for DNS query resolution (nslookup google.com from test pod) in test-pihole-dns.sh
- [ ] T034 [US1] Add test for DNS query to blocked domain (doubleclick.net returns 0.0.0.0 or NXDOMAIN) in test-pihole-dns.sh
- [ ] T035 [US1] Add test for DNS query statistics availability via metrics endpoint in test-pihole-dns.sh
- [ ] T036 [US1] Run integration test script and verify all tests pass

**Checkpoint**: At this point, User Story 1 should be fully functional - Pi-hole pod Running, DNS service accessible, queries resolving

---

## Phase 4: User Story 2 - Web Admin Interface Access (Priority: P1) 🎯 MVP

**Goal**: Expose Pi-hole web admin interface via NodePort for configuration and monitoring from notebook

**Independent Test**: Open browser on notebook, navigate to Pi-hole admin URL, and successfully login to view dashboard with DNS statistics

### Implementation for User Story 2

- [ ] T037 [US2] Create Web Admin Service manifest (NodePort 30001, port 80 HTTP) at terraform/modules/pihole/manifests/service-web.yaml
- [ ] T038 [US2] Configure externalTrafficPolicy: Local to preserve client source IPs in service-web.yaml
- [ ] T039 [US2] Add kubernetes_manifest resource for Web Admin Service in main.tf
- [ ] T040 [US2] Update pihole.tf module invocation with NodePort configuration
- [ ] T041 [US2] Run tofu plan to preview Web Admin Service changes
- [ ] T042 [US2] Run tofu apply to deploy Web Admin Service

### Tests for User Story 2

- [ ] T043 [P] [US2] Create integration test script at tests/integration/test-pihole-web.sh
- [ ] T044 [US2] Add test for NodePort service creation with port 30001 in test-pihole-web.sh
- [ ] T045 [US2] Add test for HTTP accessibility at http://<node-ip>:30001 (curl check) in test-pihole-web.sh
- [ ] T046 [US2] Add test for admin login page loading (HTTP 200 or 302) in test-pihole-web.sh
- [ ] T047 [US2] Add test for Grafana API health check (/api/health endpoint) in test-pihole-web.sh
- [ ] T048 [US2] Add test for dashboard pages navigation (Query Log, Whitelist, Blacklist, Settings) in test-pihole-web.sh
- [ ] T049 [US2] Run integration test script and verify all tests pass
- [ ] T050 [US2] Manual test: Access http://192.168.4.101:30001 from notebook browser and verify login works

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - DNS service + Web admin accessible

---

## Phase 5: User Story 3 - Configure Devices to Use Pi-hole DNS (Priority: P2)

**Goal**: Enable devices on Eero network to use Pi-hole for DNS resolution with ad blocking

**Independent Test**: Configure a single device (laptop or phone) to use Pi-hole DNS server IP, browse websites, verify ads are blocked and queries appear in Pi-hole log

### Implementation for User Story 3

- [ ] T051 [P] [US3] Create device DNS configuration guide at docs/device-dns-config.md
- [ ] T052 [P] [US3] Document macOS DNS configuration steps in device-dns-config.md
- [ ] T053 [P] [US3] Document Windows DNS configuration steps in device-dns-config.md
- [ ] T054 [P] [US3] Document iOS DNS configuration steps in device-dns-config.md
- [ ] T055 [P] [US3] Document Android DNS configuration steps in device-dns-config.md
- [ ] T056 [US3] Document how to find Pi-hole DNS service IP (node IP or LoadBalancer IP) in device-dns-config.md
- [ ] T057 [US3] Document DNS service external IP retrieval command (kubectl get svc pihole-dns) in device-dns-config.md

### Tests for User Story 3

- [ ] T058 [US3] Create integration test script at tests/integration/test-pihole-blocking.sh
- [ ] T059 [US3] Add test for device queries appearing in Pi-hole query log in test-pihole-blocking.sh
- [ ] T060 [US3] Add test for ad domain blocking (doubleclick.net, googlesyndication.com) in test-pihole-blocking.sh
- [ ] T061 [US3] Add test for Pi-hole dashboard showing increased blocked query count in test-pihole-blocking.sh
- [ ] T062 [US3] Add test for whitelisting domain and verifying immediate access in test-pihole-blocking.sh
- [ ] T063 [US3] Run integration test script and verify all tests pass
- [ ] T064 [US3] Manual test: Configure laptop DNS to use Pi-hole, browse news site, verify ads blocked

**Checkpoint**: At this point, User Stories 1, 2, AND 3 should work independently - Devices can use Pi-hole DNS

---

## Phase 6: User Story 4 - Persistent Configuration and Data (Priority: P2)

**Goal**: Ensure Pi-hole configuration (blocklists, whitelist, blacklist) and query history persist across pod restarts

**Independent Test**: Customize Pi-hole configuration (add custom blocklist, whitelist a domain), restart Pi-hole pod, verify customizations are retained

### Implementation for User Story 4

- [ ] T065 [US4] Verify PersistentVolumeClaim is correctly mounted to /etc/pihole in deployment.yaml (already configured in T015)
- [ ] T066 [US4] Verify PVC storage class is local-path (K3s default) in pvc.yaml (already configured in T012)
- [ ] T067 [US4] Verify PVC size is at least 2Gi in pvc.yaml (already configured in T012)
- [ ] T068 [US4] Add output for PVC status to outputs.tf (Bound, size, storage class)
- [ ] T069 [US4] Run tofu plan to verify PVC configuration changes
- [ ] T070 [US4] Run tofu apply if changes needed

### Tests for User Story 4

- [ ] T071 [US4] Add test for custom blocklist persistence after pod restart in test-pihole-dns.sh
- [ ] T072 [US4] Add test for query history persistence after pod restart in test-pihole-dns.sh
- [ ] T073 [US4] Add test for custom upstream DNS servers persistence after pod restart in test-pihole-dns.sh
- [ ] T074 [US4] Add test for PVC binding and size validation in test-pihole-dns.sh
- [ ] T075 [US4] Manual test: Add custom blocklist via web UI, delete pod (kubectl delete pod -l app=pihole), verify blocklist retained after pod recreates
- [ ] T076 [US4] Manual test: Whitelist a domain, delete pod, verify whitelist entry retained
- [ ] T077 [US4] Run integration tests and verify persistence

**Checkpoint**: At this point, all P1 and P2 user stories should work - Configuration persists across restarts

---

## Phase 7: User Story 5 - Integration with Existing Monitoring (Priority: P3)

**Goal**: Integrate Pi-hole metrics into existing Grafana dashboards for DNS performance and ad blocking effectiveness monitoring

**Independent Test**: Access Grafana dashboard, verify Pi-hole metrics (queries per second, blocked percentage, top domains) are displayed and updating in real-time

### Implementation for User Story 5

- [ ] T078 [P] [US5] Add eko/pihole-exporter sidecar container to deployment.yaml
- [ ] T079 [US5] Configure exporter environment variables (PIHOLE_HOSTNAME=127.0.0.1, PIHOLE_PASSWORD from Secret, PORT=9617) in deployment.yaml
- [ ] T080 [US5] Expose exporter port 9617 in deployment.yaml
- [ ] T081 [P] [US5] Create Prometheus Service manifest for exporter at terraform/modules/pihole/manifests/service-metrics.yaml
- [ ] T082 [US5] Add Prometheus scrape annotations to metrics service (prometheus.io/scrape, prometheus.io/port, prometheus.io/path)
- [ ] T083 [US5] Add kubernetes_manifest resource for metrics service in main.tf
- [ ] T084 [US5] Run tofu plan to preview metrics exporter changes
- [ ] T085 [US5] Run tofu apply to deploy metrics exporter
- [ ] T086 [P] [US5] Create Grafana dashboard import guide at docs/pihole-grafana-dashboard.md
- [ ] T087 [US5] Document Grafana dashboard ID 10176 (Pi-hole Exporter) in pihole-grafana-dashboard.md
- [ ] T088 [US5] Document how to import dashboard (Dashboards → Import → ID 10176) in pihole-grafana-dashboard.md
- [ ] T089 [US5] Document expected metrics (queries, blocked percentage, top domains, upstream latency) in pihole-grafana-dashboard.md

### Tests for User Story 5

- [ ] T090 [US5] Add test for exporter sidecar container running in test-pihole-dns.sh
- [ ] T091 [US5] Add test for metrics endpoint accessibility (curl http://pihole-web:9617/metrics) in test-pihole-dns.sh
- [ ] T092 [US5] Add test for Prometheus scraping Pi-hole metrics (query Prometheus API) in test-pihole-dns.sh
- [ ] T093 [US5] Add test for key metrics availability (pihole_dns_queries_today, pihole_ads_blocked_today, pihole_ads_percentage_today) in test-pihole-dns.sh
- [ ] T094 [US5] Manual test: Access Grafana UI, import dashboard 10176, verify Pi-hole metrics displayed
- [ ] T095 [US5] Manual test: Browse websites with ads, refresh Grafana dashboard, verify query metrics updating
- [ ] T096 [US5] Run integration tests and verify metrics exporter working

**Checkpoint**: All user stories complete - Pi-hole fully integrated with monitoring stack

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and production readiness

- [ ] T097 [P] Create Pi-hole deployment guide at docs/pihole-setup.md
- [ ] T098 [P] Create Pi-hole troubleshooting guide at docs/pihole-troubleshooting.md
- [ ] T099 [P] Document common issues (pod not starting, DNS not resolving, web interface unreachable) in pihole-troubleshooting.md
- [ ] T100 [P] Document edge cases (pod crash during DNS queries, PV out of space, blocklist update failures) in pihole-troubleshooting.md
- [ ] T101 [P] Document how to retrieve admin password from Secret (kubectl get secret pihole-admin-password -o jsonpath) in pihole-setup.md
- [ ] T102 [P] Document how to update Pi-hole image version in deployment.yaml in pihole-setup.md
- [ ] T103 [P] Document backup strategy for /etc/pihole PersistentVolume in pihole-setup.md
- [ ] T104 Run OpenTofu fmt to format all .tf files
- [ ] T105 Run OpenTofu validate to check syntax of all modules
- [ ] T106 Add Pi-hole module README at terraform/modules/pihole/README.md with usage examples
- [ ] T107 Update main terraform README at terraform/README.md with Pi-hole deployment section
- [ ] T108 Run quickstart.md validation end-to-end (deploy, test, access web UI, configure device, verify blocking)
- [ ] T109 Create security checklist for Pi-hole deployment (Secret management, resource limits, NodePort access) at docs/pihole-security-checklist.md
- [ ] T110 Run all integration tests in sequence (test-pihole-dns.sh, test-pihole-web.sh, test-pihole-blocking.sh)
- [ ] T111 Verify Pi-hole passes all success criteria from spec.md (query latency <100ms, 15% blocking rate, 99% uptime, web UI <2s load)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - User Story 1 (Pi-hole Deployment): Can start after Foundational
  - User Story 2 (Web Admin): Can start after User Story 1 (depends on Deployment)
  - User Story 3 (Device Config): Can start after User Story 1+2 (depends on DNS service and web UI)
  - User Story 4 (Persistence): Can start after User Story 1 (verifies existing PVC config)
  - User Story 5 (Monitoring): Can start after User Story 1 (adds sidecar to existing deployment)
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

```
Foundational (Phase 2)
    ↓
User Story 1 (P1): Pi-hole Deployment ← REQUIRED FOR ALL
    ↓
    ├──→ User Story 2 (P1): Web Admin Interface (depends on US1)
    │        ↓
    │        └──→ User Story 3 (P2): Device DNS Config (depends on US1+US2)
    │
    ├──→ User Story 4 (P2): Persistence (verifies US1 PVC config, independent)
    │
    └──→ User Story 5 (P3): Monitoring (modifies US1 deployment, can run in parallel with US2-4)
```

### Within Each User Story

- **User Story 1**: Manifests (parallel) → OpenTofu resources → Deploy → Test
- **User Story 2**: Web Service manifest → Deploy → Test → Manual verification
- **User Story 3**: Documentation (parallel) → Manual device config → Test
- **User Story 4**: Verification tasks (parallel) → Persistence tests
- **User Story 5**: Exporter sidecar + metrics service → Grafana dashboard → Test

### Parallel Opportunities

- **Setup (Phase 1)**: All 4 tasks marked [P] can run in parallel (different directories)
- **Foundational (Phase 2)**: Tasks T009-T010 marked [P] can run in parallel
- **User Story 1**: Tasks T011-T012, T020 marked [P] can create manifests in parallel
- **User Story 2**: Tasks T043 (test script creation) can start in parallel with implementation
- **User Story 3**: All documentation tasks T051-T055 marked [P] can run in parallel
- **User Story 5**: Tasks T078, T081, T086 marked [P] can run in parallel
- **Polish (Phase 8)**: All documentation tasks T097-T103 marked [P] can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all manifest creation tasks together:
Task T011: "Create Kubernetes Secret manifest at terraform/modules/pihole/manifests/secret.yaml"
Task T012: "Create PersistentVolumeClaim manifest at terraform/modules/pihole/manifests/pvc.yaml"
Task T020: "Create DNS Service manifest at terraform/modules/pihole/manifests/service-dns.yaml"

# Then launch sequential deployment:
Task T013-T019: "Create and configure Pi-hole Deployment manifest" (sequential - same file)
Task T021-T024: "Create OpenTofu main.tf and module invocation" (sequential - dependencies)
Task T025-T028: "Initialize, validate, plan, apply" (sequential - tofu workflow)

# Finally launch tests:
Task T029: "Create integration test script"
Task T030-T036: "Add test cases to script" (can be parallelized across multiple test files if split)
```

---

## Parallel Example: User Story 3

```bash
# Launch all documentation tasks together:
Task T052: "Document macOS DNS configuration"
Task T053: "Document Windows DNS configuration"
Task T054: "Document iOS DNS configuration"
Task T055: "Document Android DNS configuration"

# These 4 tasks are completely independent (different sections of same file)
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. **Complete Phase 1**: Setup (4 tasks, ~5 minutes)
2. **Complete Phase 2**: Foundational (6 tasks, ~10 minutes)
3. **Complete Phase 3**: User Story 1 - Pi-hole Deployment (36 tasks, ~45 minutes)
4. **Complete Phase 4**: User Story 2 - Web Admin Access (14 tasks, ~20 minutes)
5. **STOP and VALIDATE**:
   - Run integration tests (test-pihole-dns.sh, test-pihole-web.sh)
   - Access web UI from notebook
   - Test DNS queries from test pod
   - Verify all P1 acceptance criteria met
6. **Deploy/demo MVP**: Pi-hole running with DNS service and web admin accessible

**Total MVP Effort**: ~54 tasks, ~80 minutes of work

### Incremental Delivery

1. **Foundation ready** (Phases 1-2): Project structure + prerequisites → ~15 minutes
2. **Add User Story 1** (Phase 3): Pi-hole deployed and running → Test independently → ~45 minutes
3. **Add User Story 2** (Phase 4): Web UI accessible → Test independently → Deploy/Demo **MVP!** → ~20 minutes
4. **Add User Story 3** (Phase 5): Device DNS config → Test independently → ~30 minutes
5. **Add User Story 4** (Phase 6): Persistence validated → Test independently → ~25 minutes
6. **Add User Story 5** (Phase 7): Monitoring integrated → Test independently → Deploy/Demo → ~40 minutes
7. **Polish** (Phase 8): Documentation, security, validation → ~35 minutes

Each story adds value without breaking previous stories.

**Total Full Feature Effort**: ~111 tasks, ~210 minutes (~3.5 hours) of work

### Parallel Team Strategy

With multiple developers:

1. **Team completes Setup + Foundational together** (~15 minutes)
2. **Once Foundational is done**:
   - Developer A: User Story 1 (Pi-hole Deployment) - CRITICAL PATH
   - Developer B: User Story 3 (Device DNS documentation) - can write docs in parallel
   - Developer C: Polish documentation (pihole-setup.md, troubleshooting.md)
3. **After User Story 1 completes**:
   - Developer A: User Story 2 (Web Admin) - depends on US1
   - Developer B: User Story 4 (Persistence tests) - depends on US1
   - Developer C: User Story 5 (Monitoring) - depends on US1
4. **Stories complete and integrate independently**

---

## Notes

- [P] tasks = different files or directories, no dependencies within phase
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Integration tests validate acceptance scenarios from spec.md
- Run `tofu fmt` before committing any .tf files
- Run `tofu validate` after creating or modifying modules
- Commit after each phase or logical group of tasks
- Stop at any checkpoint to validate story independently
- User Story 1 is CRITICAL PATH - all other stories depend on it
- User Story 2 is MVP-critical (Web UI access is P1 requirement)
- User Stories 3-5 can be deferred if needed (P2/P3 priorities)

---

## Success Criteria Validation (from spec.md)

After completing all tasks, verify:

1. ✅ **DNS Query Performance**: Pi-hole resolves DNS queries in under 100ms (95th percentile) for cached queries
2. ✅ **Ad Blocking Effectiveness**: At least 15% of DNS queries are blocked (indicating active ad blocking)
3. ✅ **Service Availability**: Pi-hole DNS service has 99% uptime measured over 7 days
4. ✅ **Admin Interface Accessibility**: Web admin interface is accessible from notebook within 2 seconds of page load
5. ✅ **Configuration Persistence**: Pi-hole customizations (blocklists, whitelist, blacklist) survive pod restarts with 100% retention
6. ✅ **Query History Retention**: Pi-hole query log retains at least 24 hours of history (or 100,000 queries, whichever is reached first)
7. ✅ **User Satisfaction**: Network users report fewer ads visible on websites after Pi-hole deployment (qualitative measure via user survey)

**Task T111** validates all these criteria before marking feature complete.
