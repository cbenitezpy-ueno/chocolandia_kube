# Tasks: Homepage Dashboard Update

**Input**: Design documents from `/specs/001-homepage-update/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/,quickstart.md

**Tests**: No test tasks included - this is an infrastructure configuration update validated through manual testing and OpenTofu validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Configuration files**: `terraform/modules/homepage/configs/`
- **Terraform module**: `terraform/modules/homepage/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prerequisites and ArgoCD token generation

- [x] T001 Generate read-only ArgoCD API token using command from research.md
- [x] T002 [P] Backup current Homepage configuration files in terraform/modules/homepage/configs/
- [x] T003 [P] Verify ArgoCD CD configuration for homepage namespace in cluster

**Validation**: ArgoCD token created, backup files exist, ArgoCD Application for homepage confirmed

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core configuration updates that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Update kubernetes.yaml to enable node display with CPU/memory metrics in terraform/modules/homepage/configs/kubernetes.yaml
- [x] T005 Verify Homepage ServiceAccount has ClusterRole permissions to read nodes and metrics in terraform/modules/homepage/rbac.tf

**Checkpoint**: Kubernetes integration configured - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View Cluster Infrastructure Information (Priority: P1) 🎯 MVP

**Goal**: Display all four cluster nodes with IP addresses, roles, and status on Homepage dashboard

**Independent Test**: Open Homepage dashboard and verify all four nodes (master1: 192.168.4.101, nodo1: 192.168.4.102, nodo03: 192.168.4.103, nodo04: 192.168.4.104) are displayed with their roles and status

### Implementation for User Story 1

- [x] T006 [US1] Update widgets.yaml to configure Kubernetes cluster widget with node display enabled in terraform/modules/homepage/configs/widgets.yaml
- [x] T007 [US1] Run tofu validate in terraform/environments/chocolandiadc-mvp/ to check syntax
- [x] T008 [US1] Run tofu plan in terraform/environments/chocolandiadc-mvp/ to preview ConfigMap changes
- [x] T009 [US1] Apply configuration with tofu apply in terraform/environments/chocolandiadc-mvp/
- [x] T010 [US1] Verify ConfigMap homepage-kubernetes updated in cluster with kubectl get configmap homepage-kubernetes -n homepage -o yaml
- [x] T011 [US1] Restart Homepage pod with kubectl rollout restart deployment/homepage -n homepage (or wait for ArgoCD auto-sync)
- [ ] T012 [US1] Verify node widget displays all 4 nodes with correct IPs and roles by accessing Homepage dashboard

**Checkpoint**: At this point, User Story 1 should be fully functional - all nodes visible with infrastructure details

---

## Phase 4: User Story 2 - Access All Services via Links (Priority: P1)

**Goal**: Display all deployed services with both public (Cloudflare tunnel) and private (IP/port) access links

**Independent Test**: Click each service link to verify it opens the correct interface, and confirm visual distinction between public (🌐) and private (🏠) access methods

### Implementation for User Story 2

- [x] T013 [P] [US2] Add Storage category with Longhorn, MinIO API, MinIO Console, PostgreSQL services in terraform/modules/homepage/configs/services.yaml
- [x] T014 [P] [US2] Add Pi-hole to Infrastructure category with public and private URLs in terraform/modules/homepage/configs/services.yaml
- [x] T015 [P] [US2] Add Netdata to Monitoring category with private NodePort URL in terraform/modules/homepage/configs/services.yaml
- [x] T016 [P] [US2] Add Prometheus to Monitoring category with port-forward instructions in terraform/modules/homepage/configs/services.yaml
- [x] T017 [P] [US2] Add Beersystem to Applications category with public and private URLs in terraform/modules/homepage/configs/services.yaml
- [x] T018 [US2] Update all existing service entries to include visual distinction (🌐 Public / 🏠 Private) in descriptions in terraform/modules/homepage/configs/services.yaml
- [x] T019 [US2] Sort all services alphabetically within each category per FR-009 in terraform/modules/homepage/configs/services.yaml
- [x] T020 [US2] Run tofu validate in terraform/environments/chocolandiadc-mvp/
- [x] T021 [US2] Run tofu plan in terraform/environments/chocolandiadc-mvp/ to preview services.yaml changes
- [x] T022 [US2] Apply configuration with tofu apply in terraform/environments/chocolandiadc-mvp/
- [x] T023 [US2] Verify ConfigMap homepage-services updated with kubectl get configmap homepage-services -n homepage -o yaml
- [x] T024 [US2] Restart Homepage pod with kubectl rollout restart deployment/homepage -n homepage (or wait for ArgoCD auto-sync)
- [ ] T025 [US2] Test all service links (public URLs) by clicking each service from Homepage dashboard
- [ ] T026 [US2] Test private access methods (LoadBalancer IPs, NodePorts) from local network
- [ ] T027 [US2] Verify visual distinction (🌐/🏠 icons or labels) is clear and unconfusing per SC-004

**Checkpoint**: At this point, all services should be accessible via Homepage with clear public/private distinction

---

## Phase 5: User Story 3 - Monitor Service Status with Working Widgets (Priority: P2)

**Goal**: Fix ArgoCD widget authentication and ensure Kubernetes widget displays cluster metrics with 30-second refresh

**Independent Test**: Verify ArgoCD widget shows application sync status without errors, and Kubernetes widget displays cluster resource usage that refreshes every 30 seconds

### Implementation for User Story 3

- [x] T028 [US3] Store ArgoCD API token in Kubernetes Secret homepage-widgets using kubectl create secret or update via OpenTofu in terraform/modules/homepage/main.tf
- [x] T029 [US3] Update widgets.yaml to configure ArgoCD widget with correct URL and token reference in terraform/modules/homepage/configs/widgets.yaml
- [x] T030 [US3] Configure widget refresh interval to 30 seconds globally (if Homepage supports, otherwise documented as default) in terraform/modules/homepage/configs/widgets.yaml
- [x] T031 [US3] Add error handling configuration for single retry after 10 seconds (if Homepage supports) in terraform/modules/homepage/configs/widgets.yaml or document as application behavior
- [x] T032 [US3] Run tofu validate in terraform/environments/chocolandiadc-mvp/
- [x] T033 [US3] Run tofu plan in terraform/environments/chocolandiadc-mvp/ to preview widget changes
- [x] T034 [US3] Apply configuration with tofu apply in terraform/environments/chocolandiadc-mvp/
- [x] T035 [US3] Verify ConfigMap homepage-widgets updated with kubectl get configmap homepage-widgets -n homepage -o yaml
- [x] T036 [US3] Verify Secret homepage-widgets contains ArgoCD token with kubectl get secret homepage-widgets -n homepage -o yaml
- [x] T037 [US3] Restart Homepage pod with kubectl rollout restart deployment/homepage -n homepage (or wait for ArgoCD auto-sync)
- [ ] T038 [US3] Verify ArgoCD widget displays application sync status without authentication errors per SC-003
- [ ] T039 [US3] Verify Kubernetes widget shows node count, pod count, and resource usage metrics
- [ ] T040 [US3] Monitor widget refresh behavior (should update every ~30 seconds)
- [ ] T041 [US3] Test error handling by temporarily invalidating ArgoCD token and verifying error message appears

**Checkpoint**: All widgets should now be functional with proper authentication and refresh intervals

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, documentation, and deployment

- [ ] T042 [P] Run full OpenTofu validation: tofu validate && tofu fmt -check in terraform/environments/chocolandiadc-mvp/
- [ ] T043 [P] Verify all ConfigMaps applied correctly with kubectl get configmaps -n homepage
- [ ] T044 [P] Check Homepage pod logs for any errors with kubectl logs -n homepage -l app=homepage --tail=50
- [ ] T045 Test dashboard load time (should be <3 seconds on local network) per SC-005
- [ ] T046 Verify success criteria SC-001 through SC-007 using quickstart.md validation steps
- [ ] T047 [P] Update CLAUDE.md with any new learnings or configuration patterns discovered
- [ ] T048 [P] Document ArgoCD token rotation procedure in quickstart.md or separate runbook
- [ ] T049 Commit all changes with descriptive message following Git conventions from CLAUDE.md
- [ ] T050 Create pull request for review before merging to main branch

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion (T001-T003) - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion (T004-T005)
  - User Story 1 (US1): Independent - can start immediately after Foundational
  - User Story 2 (US2): Independent - can start immediately after Foundational (parallel with US1)
  - User Story 3 (US3): Independent - can start immediately after Foundational (parallel with US1/US2)
- **Polish (Phase 6)**: Depends on all user stories being complete (T006-T041)

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Foundational (T004-T005) - No dependencies on other stories
- **User Story 2 (P1)**: Depends on Foundational (T004-T005) - No dependencies on other stories
- **User Story 3 (P2)**: Depends on Foundational (T004-T005) - No dependencies on other stories

**Key Insight**: All three user stories are independent and can be worked in parallel after Foundational phase completes!

### Within Each User Story

- **US1**: T006 (update config) → T007-T009 (tofu validate/plan/apply) → T010-T011 (verify & restart) → T012 (validate)
- **US2**: T013-T019 (update all services) → T020-T022 (tofu validate/plan/apply) → T023-T024 (verify & restart) → T025-T027 (test all links)
- **US3**: T028-T031 (configure widgets & secrets) → T032-T034 (tofu validate/plan/apply) → T035-T037 (verify & restart) → T038-T041 (test widgets)

### Parallel Opportunities

**Phase 1 (Setup)**:
- T002 and T003 can run in parallel with T001

**Phase 2 (Foundational)**:
- T004 and T005 can potentially run in parallel (different files)

**User Story 2 - Service Configuration**:
- T013-T017 can ALL run in parallel (adding different services to same file, but can be done in one edit session)
- After T013-T017 complete: T018-T019 run sequentially (updating existing entries, sorting)

**Phase 6 (Polish)**:
- T042, T043, T044 can run in parallel
- T047, T048 can run in parallel after T046

**User Stories (Phase 3-5)**:
- Once Foundational completes, ALL three user stories can proceed in parallel if desired
- Recommended: Complete US1 first (MVP), then US2, then US3 for incremental value delivery

---

## Parallel Example: User Story 2 (Service Configuration)

```bash
# Add all new services in one editing session (can be done in parallel conceptually):
# In terraform/modules/homepage/configs/services.yaml:

# Edit 1: Add Storage category services (T013)
# Edit 2: Add Pi-hole to Infrastructure (T014)
# Edit 3: Add Netdata to Monitoring (T015)
# Edit 4: Add Prometheus to Monitoring (T016)
# Edit 5: Add Beersystem to Applications (T017)

# Then sequentially:
# Edit 6: Update all existing entries with 🌐/🏠 distinction (T018)
# Edit 7: Sort all services alphabetically within categories (T019)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T005) - CRITICAL
3. Complete Phase 3: User Story 1 (T006-T012)
4. **STOP and VALIDATE**: Verify all 4 nodes visible with IP addresses
5. Optionally deploy/demo MVP before proceeding

**Result**: Cluster infrastructure visibility functional - administrators can see node status

### Incremental Delivery (Recommended)

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 (Node Display) → Test independently → **MVP 1** ✅
3. Add User Story 2 (Service Links) → Test independently → **MVP 2** ✅
4. Add User Story 3 (Working Widgets) → Test independently → **Full Feature** ✅
5. Polish Phase → Production-ready

**Benefits**: Each increment adds value, failures isolated to specific story

### Parallel Team Strategy (If Multiple Contributors)

With two contributors:

1. Both complete Setup + Foundational together (T001-T005)
2. Once Foundational done:
   - **Contributor A**: User Story 1 (T006-T012) - Node display
   - **Contributor B**: User Story 2 (T013-T027) - Service links
3. After US1 & US2 complete:
   - **Either contributor**: User Story 3 (T028-T041) - Widgets
4. Both complete Polish together (T042-T050)

**Note**: Since Homepage has ArgoCD CD configuration, coordinate restarts and testing to avoid conflicts

### Single Developer Sequential (Most Common)

1. Setup (15 min)
2. Foundational (15 min)
3. User Story 1 - Node Display (30 min)
   - Validate before proceeding
4. User Story 2 - Service Links (60 min)
   - Validate before proceeding
5. User Story 3 - Widgets (45 min)
   - Validate before proceeding
6. Polish (30 min)

**Total Estimated Time**: 3-3.5 hours for complete implementation

---

## Notes

- **[P] tasks**: Different files or independent changes, can run in parallel
- **[Story] label**: Maps task to specific user story (US1, US2, US3) for traceability
- **ArgoCD Auto-Sync**: Homepage may auto-deploy on ConfigMap changes - monitor ArgoCD Application status
- **Testing**: Each user story has validation steps before proceeding to next
- **Commits**: Recommended to commit after each user story phase for easy rollback
- **OpenTofu State**: All changes managed declaratively - no manual kubectl edits except for validation
- **Token Security**: ArgoCD token has read-only permissions, stored in Kubernetes Secret
- **Widget Refresh**: 30-second intervals configured globally (or documented as Homepage default)
- **Visual Distinction**: 🌐 Public and 🏠 Private labels in service descriptions per clarifications

---

## Success Validation Checklist

After completing all tasks, verify these success criteria from spec.md:

- [ ] **SC-001**: Can access any service in under 5 seconds from Homepage
- [ ] **SC-002**: All 4 nodes visible with accurate IPs and status (updates within 30s)
- [ ] **SC-003**: ArgoCD widget shows sync status without auth errors (100% success rate)
- [ ] **SC-004**: Users can distinguish public vs private URLs without confusion
- [ ] **SC-005**: Dashboard loads in under 3 seconds on local network
- [ ] **SC-006**: 100% of services have at least one working link
- [ ] **SC-007**: Widget errors show retry behavior and clear error messages

**Validation Method**: Follow quickstart.md testing procedures for comprehensive validation
