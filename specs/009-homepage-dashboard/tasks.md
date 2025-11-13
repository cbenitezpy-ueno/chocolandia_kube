# Tasks: Homepage Dashboard

**Input**: Design documents from `/specs/009-homepage-dashboard/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Integration tests are included per user story as this is an infrastructure deployment feature where validation is critical.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Infrastructure as Code project using OpenTofu:
- **Modules**: `terraform/modules/homepage/`
- **Environment**: `terraform/environments/chocolandiadc-mvp/`
- **Tests**: `tests/homepage/`
- **Configs**: `terraform/modules/homepage/configs/`

---

## Phase 1: Setup (Module Structure)

**Purpose**: Create Homepage OpenTofu module directory structure and initial scaffolding

- [X] T001 Create Homepage module directory structure at terraform/modules/homepage/
- [X] T002 [P] Create module README.md documenting purpose, inputs, and outputs
- [X] T003 [P] Create configs subdirectory at terraform/modules/homepage/configs/
- [X] T004 [P] Create test directory structure at tests/homepage/

---

## Phase 2: Foundational (Core Infrastructure)

**Purpose**: Core Kubernetes resources and RBAC that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Verify K3s cluster prerequisites (3 control-plane + 1 worker operational) via kubectl get nodes
- [ ] T006 Create namespace resource in terraform/modules/homepage/main.tf
- [ ] T007 [P] Create variables.tf with input variables (image version, domain, API credentials)
- [ ] T008 [P] Create outputs.tf with output values (service URL, pod status, configmap names)
- [ ] T009 Create ServiceAccount resource in terraform/modules/homepage/rbac.tf
- [ ] T010 Create Role resources for monitored namespaces in terraform/modules/homepage/rbac.tf
- [ ] T011 Create RoleBinding resources linking ServiceAccount to Roles in terraform/modules/homepage/rbac.tf

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Access Centralized Dashboard (Priority: P1) 🎯 MVP

**Goal**: Deploy Homepage with basic configuration showing all cluster services with their internal and external URLs

**Independent Test**: Deploy Homepage, access dashboard via browser, verify all services are displayed with correct URLs (internal ClusterIP and external Cloudflare domains)

### Implementation for User Story 1

- [ ] T012 [P] [US1] Create services.yaml configuration at terraform/modules/homepage/configs/services.yaml
- [ ] T013 [P] [US1] Create settings.yaml configuration at terraform/modules/homepage/configs/settings.yaml
- [ ] T014 [P] [US1] Create widgets.yaml configuration at terraform/modules/homepage/configs/widgets.yaml
- [ ] T015 [US1] Create ConfigMap resources for Homepage configuration in terraform/modules/homepage/main.tf
- [ ] T016 [US1] Create Secret resource for widget API credentials in terraform/modules/homepage/main.tf
- [ ] T017 [US1] Create Deployment resource with Homepage container in terraform/modules/homepage/main.tf
- [ ] T018 [US1] Configure volume mounts for ConfigMaps in Deployment spec
- [ ] T019 [US1] Configure environment variable injection from Secret in Deployment spec
- [ ] T020 [US1] Add resource limits (CPU/memory) to container spec
- [ ] T021 [US1] Add liveness probe (HTTP GET / on port 3000) to container spec
- [ ] T022 [US1] Add readiness probe (HTTP GET / on port 3000) to container spec
- [ ] T023 [US1] Create Service resource (ClusterIP type) in terraform/modules/homepage/main.tf
- [ ] T024 [US1] Create module invocation in terraform/environments/chocolandiadc-mvp/homepage.tf
- [ ] T025 [US1] Add sensitive variables (pihole_api_key, argocd_token) to terraform/environments/chocolandiadc-mvp/variables.tf
- [ ] T026 [US1] Run tofu init in terraform/environments/chocolandiadc-mvp/
- [ ] T027 [US1] Run tofu validate and fix any syntax errors
- [ ] T028 [US1] Run tofu plan and review proposed changes
- [ ] T029 [US1] Run tofu apply to deploy Homepage

### Integration Tests for User Story 1

- [ ] T030 [P] [US1] Create test_deployment.sh validating Homepage pod status (Running, Ready) at tests/homepage/test_deployment.sh
- [ ] T031 [P] [US1] Create test_accessibility.sh testing internal HTTP access (curl from test pod) at tests/homepage/test_accessibility.sh
- [ ] T032 [US1] Execute deployment validation: kubectl -n homepage get pods (expect 1/1 Running)
- [ ] T033 [US1] Execute internal accessibility test: kubectl run test-curl --rm -it --image=curlimages/curl -- curl http://homepage.homepage.svc.cluster.local:3000
- [ ] T034 [US1] Verify ConfigMaps mounted: kubectl -n homepage exec deployment/homepage -- ls /app/config
- [ ] T035 [US1] Verify Secret environment variables: kubectl -n homepage exec deployment/homepage -- env | grep HOMEPAGE_VAR

**Checkpoint**: Homepage deployed, accessible internally, services displayed with URLs

---

## Phase 4: User Story 2 - View Real-Time Service Status (Priority: P1)

**Goal**: Enable Kubernetes API integration for Homepage to display real-time service status (healthy, degraded, failed)

**Independent Test**: Scale down a service pod, refresh Homepage dashboard, verify status changes from green to red

### Implementation for User Story 2

- [ ] T036 [P] [US2] Add Kubernetes server configuration to services.yaml (server: k3s-cluster)
- [ ] T037 [P] [US2] Add namespace and container fields to each service entry in services.yaml
- [ ] T038 [US2] Verify ServiceAccount is referenced in Deployment spec (already created in Phase 2)
- [ ] T039 [US2] Verify Role permissions include services, pods, ingresses (get, list verbs)
- [ ] T040 [US2] Update Homepage ConfigMap with modified services.yaml via tofu apply
- [ ] T041 [US2] Restart Homepage pod: kubectl -n homepage rollout restart deployment/homepage

### Integration Tests for User Story 2

- [ ] T042 [P] [US2] Create test_service_discovery.sh validating K8s API connectivity at tests/homepage/test_service_discovery.sh
- [ ] T043 [US2] Execute service discovery test: Check Homepage logs for "Kubernetes" without RBAC errors
- [ ] T044 [US2] Test status reflection: Scale Pi-hole to 0 replicas, verify Homepage shows degraded/failed status
- [ ] T045 [US2] Test status recovery: Scale Pi-hole back to 1 replica, verify Homepage shows healthy status
- [ ] T046 [US2] Verify RBAC permissions: kubectl auth can-i list pods --as=system:serviceaccount:homepage:homepage -n pihole

**Checkpoint**: Homepage displays real-time service status from Kubernetes API

---

## Phase 5: User Story 4 - Secure External Access (Priority: P1)

**Goal**: Configure Cloudflare Tunnel and Access to enable secure external access to Homepage dashboard via https://homepage.chocolandiadc.com

**Independent Test**: Access https://homepage.chocolandiadc.com from external network (unauthenticated), verify redirect to Google OAuth, authenticate, verify dashboard loads

### Implementation for User Story 4

- [ ] T047 [P] [US4] Add Cloudflare Tunnel ingress rule for homepage.chocolandiadc.com in terraform/environments/chocolandiadc-mvp/cloudflare-tunnel.tf
- [ ] T048 [P] [US4] Create Cloudflare Access Application for Homepage in terraform/environments/chocolandiadc-mvp/cloudflare-access.tf
- [ ] T049 [P] [US4] Create Cloudflare Access Policy with Google OAuth allow rule in terraform/environments/chocolandiadc-mvp/cloudflare-access.tf
- [ ] T050 [US4] Update Cloudflare DNS record (CNAME) for homepage.chocolandiadc.com (if not auto-managed)
- [ ] T051 [US4] Run tofu plan reviewing Cloudflare changes
- [ ] T052 [US4] Run tofu apply to deploy Cloudflare configuration

### Integration Tests for User Story 4

- [ ] T053 [P] [US4] Create test_authentication.sh testing Cloudflare Access enforcement at tests/homepage/test_authentication.sh
- [ ] T054 [US4] Execute unauthenticated test: curl -I https://homepage.chocolandiadc.com (expect HTTP 302 redirect)
- [ ] T055 [US4] Execute authenticated test: Open browser, login with Google OAuth, verify dashboard loads
- [ ] T056 [US4] Test session expiration: Wait for session timeout, verify re-authentication required
- [ ] T057 [US4] Verify Cloudflare Access logs show successful authentication events

**Checkpoint**: Homepage accessible externally via Cloudflare Zero Trust with Google OAuth

---

## Phase 6: User Story 3 - Monitor Key Infrastructure Widgets (Priority: P2)

**Goal**: Configure specialized widgets for Pi-hole, Traefik, cert-manager, and ArgoCD to display infrastructure metrics on the dashboard

**Independent Test**: View Homepage dashboard, verify each widget displays current metrics (Pi-hole queries, Traefik routers, certificates, ArgoCD apps)

### Implementation for User Story 3

- [ ] T058 [P] [US3] Add Pi-hole widget configuration to Pi-hole service entry in services.yaml
- [ ] T059 [P] [US3] Add Traefik widget configuration to Traefik service entry in services.yaml
- [ ] T060 [P] [US3] Add cert-manager widget (Kubernetes CRD) configuration to cert-manager service entry in services.yaml
- [ ] T061 [P] [US3] Add ArgoCD widget configuration to ArgoCD service entry in services.yaml
- [ ] T062 [US3] Update Secret with Pi-hole API key: PIHOLE_API_KEY variable
- [ ] T063 [US3] Update Secret with ArgoCD API token: ARGOCD_TOKEN variable
- [ ] T064 [US3] Verify cert-manager.io/v1/Certificate CRD access in Role permissions
- [ ] T065 [US3] Update Homepage ConfigMap with widgets via tofu apply
- [ ] T066 [US3] Restart Homepage pod to load new widget configuration

### Integration Tests for User Story 3

- [ ] T067 [P] [US3] Create test_widgets.sh validating widget functionality at tests/homepage/test_widgets.sh
- [ ] T068 [US3] Test Pi-hole widget API connectivity from Homepage pod: curl http://pihole.pihole.svc.cluster.local/admin/api.php
- [ ] T069 [US3] Test Traefik widget API connectivity from Homepage pod: curl http://traefik.traefik.svc.cluster.local:9000/api/overview
- [ ] T070 [US3] Test cert-manager widget: kubectl -n homepage logs deployment/homepage | grep "cert-manager" (no errors)
- [ ] T071 [US3] Test ArgoCD widget API connectivity from Homepage pod: curl http://argocd-server.argocd.svc.cluster.local/api/version
- [ ] T072 [US3] Verify all widgets display data on dashboard: Pi-hole stats, Traefik routers, certificates, ArgoCD apps
- [ ] T073 [US3] Test widget error handling: Stop Pi-hole service, verify widget shows error state (not blank)

**Checkpoint**: All infrastructure widgets operational and displaying current metrics

---

## Phase 7: User Story 5 - Automatic Service Discovery (Priority: P2)

**Goal**: Configure Homepage to automatically discover new services deployed to monitored namespaces via Kubernetes API

**Independent Test**: Deploy a new test service with proper labels/annotations, wait 30 seconds, verify it appears on Homepage dashboard without configuration changes

### Implementation for User Story 5

- [ ] T074 [P] [US5] Document service discovery annotations in terraform/modules/homepage/README.md
- [ ] T075 [P] [US5] Add example service with discovery annotations to README
- [ ] T076 [US5] Verify Homepage deployment has Kubernetes API access configured (completed in US2)
- [ ] T077 [US5] Test service discovery: Deploy test service with annotations in test namespace
- [ ] T078 [US5] Wait 30 seconds for Homepage refresh cycle
- [ ] T079 [US5] Verify test service appears on Homepage dashboard automatically
- [ ] T080 [US5] Test service removal: Delete test service, verify it disappears from dashboard
- [ ] T081 [US5] Test ingress URL discovery: Create ingress for test service, verify URL appears on dashboard

### Integration Tests for User Story 5

- [ ] T082 [P] [US5] Create test_auto_discovery.sh validating automatic service detection at tests/homepage/test_auto_discovery.sh
- [ ] T083 [US5] Deploy test-app with labels: app=test-app, homepage.discover=true
- [ ] T084 [US5] Create test-app service in monitored namespace
- [ ] T085 [US5] Wait 60 seconds (2x refresh interval for safety margin)
- [ ] T086 [US5] Query Homepage pod logs for test-app discovery events
- [ ] T087 [US5] Verify test-app appears on dashboard via HTTP GET /
- [ ] T088 [US5] Delete test-app and verify removal from dashboard

**Checkpoint**: Homepage automatically discovers and displays new services without manual configuration

---

## Phase 8: ArgoCD Integration (GitOps Deployment)

**Goal**: Configure ArgoCD Application to manage Homepage deployment via GitOps workflow

**Independent Test**: Modify services.yaml in Git, push changes, verify ArgoCD auto-syncs and Homepage updates automatically

### Implementation for ArgoCD Integration

- [ ] T089 [P] Create ArgoCD Application manifest in terraform/environments/chocolandiadc-mvp/argocd.tf
- [ ] T090 [P] Configure sync policy (automated, prune, self-heal) in Application spec
- [ ] T091 [US1] Run tofu apply to create ArgoCD Application resource
- [ ] T092 [US1] Verify Application appears in ArgoCD UI with Synced status
- [ ] T093 [US1] Test GitOps workflow: Modify services.yaml comment, git commit, git push
- [ ] T094 [US1] Wait for ArgoCD sync (auto or manual trigger)
- [ ] T095 [US1] Verify Homepage ConfigMap updated with new content
- [ ] T096 [US1] Verify Homepage pod restarted by ArgoCD to load new configuration

### Integration Tests for ArgoCD Integration

- [ ] T097 [P] Create test_gitops.sh validating ArgoCD synchronization at tests/homepage/test_gitops.sh
- [ ] T098 Check ArgoCD Application health: kubectl -n argocd get application homepage
- [ ] T099 Test sync status: argocd app get homepage (expect Status: Synced, Health: Healthy)
- [ ] T100 Test configuration update: Edit services.yaml title, commit, verify update in dashboard
- [ ] T101 Test rollback: Git revert, verify ArgoCD syncs previous configuration

**Checkpoint**: Homepage managed via ArgoCD GitOps workflow

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, optimization, and final validation

- [ ] T102 [P] Create troubleshooting guide at terraform/modules/homepage/docs/TROUBLESHOOTING.md
- [ ] T103 [P] Document widget configuration examples at terraform/modules/homepage/docs/WIDGETS.md
- [ ] T104 [P] Document RBAC permission requirements at terraform/modules/homepage/docs/RBAC.md
- [ ] T105 [P] Add code comments to main.tf explaining resource relationships
- [ ] T106 [P] Add code comments to rbac.tf explaining permission scoping rationale
- [ ] T107 Run tofu fmt on all .tf files in terraform/modules/homepage/
- [ ] T108 Run tofu validate on module and environment configurations
- [ ] T109 Create tests/homepage/README.md documenting test execution procedures
- [ ] T110 Run full quickstart.md validation end-to-end
- [ ] T111 Document credential rotation procedure in terraform/modules/homepage/README.md
- [ ] T112 Document adding new services procedure in terraform/modules/homepage/README.md
- [ ] T113 [P] Create backup procedure for Homepage configuration in docs/
- [ ] T114 [P] Add monitoring/alerting recommendations (Prometheus scraping, Grafana dashboard)
- [ ] T115 Verify all success criteria from spec.md (dashboard load time, widget refresh, authentication)

**Checkpoint**: All user stories complete, documentation finalized, ready for production use

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) - MVP baseline
- **User Story 2 (Phase 4)**: Depends on US1 completion (needs deployed Homepage)
- **User Story 4 (Phase 5)**: Depends on US1 completion (needs deployed Homepage)
- **User Story 3 (Phase 6)**: Depends on US1 + US2 completion (needs service discovery)
- **User Story 5 (Phase 7)**: Depends on US2 completion (needs Kubernetes API integration)
- **ArgoCD Integration (Phase 8)**: Depends on US1 completion (needs deployable Homepage)
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

```
Phase 2 (Foundational)
     ↓
Phase 3 (US1: Basic Dashboard) ← MVP baseline
     ↓
     ├─→ Phase 4 (US2: Service Status)
     │        ↓
     │   Phase 7 (US5: Auto Discovery)
     │
     ├─→ Phase 5 (US4: External Access)
     │
     └─→ Phase 6 (US3: Widgets) ← Depends on US1 + US2
```

### Within Each User Story

1. Configuration files (YAML) before ConfigMap resources
2. ConfigMaps/Secrets before Deployment
3. RBAC resources before Deployment (ServiceAccount must exist)
4. Deployment before Service
5. Core resources before Cloudflare (Homepage must exist before tunnel route)
6. Implementation complete before integration tests
7. Tests pass before moving to next user story

### Parallel Opportunities

**Setup Phase (Phase 1)**: All 4 tasks can run in parallel

**Foundational Phase (Phase 2)**: Tasks T007, T008 can run in parallel

**User Story 1 (Phase 3)**:
- T012, T013, T014 (YAML configs) can run in parallel
- T030, T031 (test scripts) can run in parallel

**User Story 2 (Phase 4)**:
- T036, T037 (YAML updates) can run in parallel
- T042 (test script) independent

**User Story 4 (Phase 5)**:
- T047, T048, T049 (Cloudflare resources) can run in parallel
- T053 (test script) independent

**User Story 3 (Phase 6)**:
- T058, T059, T060, T061 (widget configs) can run in parallel
- T067 (test script) independent

**User Story 5 (Phase 7)**:
- T074, T075 (documentation) can run in parallel
- T082 (test script) independent

**ArgoCD Integration (Phase 8)**:
- T089, T090 (Application manifest) can run in parallel
- T097 (test script) independent

**Polish Phase (Phase 9)**:
- T102, T103, T104, T105, T106, T113, T114 (documentation) can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch YAML configuration files together:
Task: "Create services.yaml configuration at terraform/modules/homepage/configs/services.yaml"
Task: "Create settings.yaml configuration at terraform/modules/homepage/configs/settings.yaml"
Task: "Create widgets.yaml configuration at terraform/modules/homepage/configs/widgets.yaml"

# Launch test scripts together:
Task: "Create test_deployment.sh validating Homepage pod status at tests/homepage/test_deployment.sh"
Task: "Create test_accessibility.sh testing internal HTTP access at tests/homepage/test_accessibility.sh"
```

---

## Implementation Strategy

### MVP First (User Stories 1, 2, 4 - Core Dashboard)

1. Complete Phase 1: Setup (4 tasks, ~15 minutes)
2. Complete Phase 2: Foundational (7 tasks, ~30 minutes)
3. Complete Phase 3: User Story 1 - Basic Dashboard (24 tasks, ~90 minutes)
4. **STOP and VALIDATE**: Test dashboard accessibility, service display
5. Complete Phase 4: User Story 2 - Service Status (11 tasks, ~30 minutes)
6. **STOP and VALIDATE**: Test status updates when pods scale
7. Complete Phase 5: User Story 4 - External Access (11 tasks, ~45 minutes)
8. **STOP and VALIDATE**: Test Cloudflare Access authentication
9. **MVP COMPLETE**: Dashboard operational with service status and secure external access

**MVP Scope**: 57 tasks, ~3.5 hours execution time

### Incremental Delivery (Add Widgets and Auto-Discovery)

10. Complete Phase 6: User Story 3 - Widgets (16 tasks, ~60 minutes)
11. **VALIDATE**: Test all widgets display current metrics
12. Complete Phase 7: User Story 5 - Auto Discovery (15 tasks, ~45 minutes)
13. **VALIDATE**: Test new service automatic detection

**Full Feature Scope**: 88 tasks, ~5.5 hours execution time

### Production Readiness (GitOps + Documentation)

14. Complete Phase 8: ArgoCD Integration (13 tasks, ~30 minutes)
15. Complete Phase 9: Polish & Documentation (14 tasks, ~60 minutes)
16. **FINAL VALIDATION**: Run full quickstart.md end-to-end

**Production Ready**: 115 tasks, ~7 hours total execution time

### Parallel Team Strategy

With multiple developers:

1. **Foundation Team** (Developer A): Phases 1-2 together
2. Once Foundational is done:
   - **Developer A**: User Story 1 (Basic Dashboard)
   - **Developer B**: Prepare Cloudflare configs (Phase 5, T047-T049)
   - **Developer C**: Prepare widget configs (Phase 6, T058-T061)
3. **Sequential Integration** (single developer recommended):
   - US1 → US2 → US4 → US3 → US5 (avoid conflicts)
4. **Parallel Polish** (after US1-5 complete):
   - Developer A: ArgoCD Integration (Phase 8)
   - Developer B: Documentation (Phase 9)

---

## Notes

- **[P] tasks**: Different files, no dependencies, can run in parallel
- **[Story] label**: Maps task to specific user story for traceability
- **MVP strategy**: US1 + US2 + US4 provide core value (basic dashboard, status, external access)
- **Enhancement strategy**: US3 (widgets) and US5 (auto-discovery) add convenience
- **Integration tests**: Validate each story independently before moving to next
- **Commit frequency**: After each logical task group (e.g., after YAML configs, after deployment, after tests)
- **Rollback safety**: Each user story is independently functional, can rollback by disabling in OpenTofu
- **Avoid**: Manual kubectl edits (use OpenTofu), skipping tests (validation critical), cross-story coupling

---

## Task Count Summary

- **Phase 1 (Setup)**: 4 tasks
- **Phase 2 (Foundational)**: 7 tasks
- **Phase 3 (US1 - Basic Dashboard)**: 24 tasks
- **Phase 4 (US2 - Service Status)**: 11 tasks
- **Phase 5 (US4 - External Access)**: 11 tasks
- **Phase 6 (US3 - Widgets)**: 16 tasks
- **Phase 7 (US5 - Auto Discovery)**: 15 tasks
- **Phase 8 (ArgoCD Integration)**: 13 tasks
- **Phase 9 (Polish)**: 14 tasks

**Total**: 115 tasks

**MVP Tasks (US1 + US2 + US4)**: 57 tasks (~50% of total)
**Full Feature Tasks (MVP + US3 + US5)**: 88 tasks (~77% of total)
**Production Ready (All phases)**: 115 tasks (100%)

**Parallel Opportunities**: 33 tasks marked [P] (~29% parallelizable)
