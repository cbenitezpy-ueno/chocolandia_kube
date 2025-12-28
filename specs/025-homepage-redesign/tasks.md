# Tasks: Homepage Dashboard Redesign

**Input**: Design documents from `/specs/025-homepage-redesign/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Visual verification tests included as part of implementation (no separate test phase).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Infrastructure**: `terraform/modules/homepage/`
- **Config files**: `terraform/modules/homepage/configs/`
- **Contracts**: `specs/025-homepage-redesign/contracts/`
- **Environment**: `terraform/environments/chocolandiadc-mvp/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Obtain credentials and prepare environment for configuration changes

- [x] T001 Obtain Pi-hole API key from https://pihole.chocolandiadc.com/admin Settings → API → Show API Token
- [x] T002 [P] Verify ArgoCD token exists in kubectl get secret -n homepage homepage-widgets
- [x] T003 [P] Obtain Grafana password from terraform/environments/chocolandiadc-mvp/monitoring.tf (grafana.adminPassword)
- [x] T004 Backup current Homepage configuration: cp -r terraform/modules/homepage/configs/ terraform/modules/homepage/configs.backup/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add new credential variables to OpenTofu module before updating configuration

**⚠️ CRITICAL**: No configuration updates can be applied until credentials are configured

- [x] T005 Add pihole_api_key, grafana_username, grafana_password variables in terraform/modules/homepage/variables.tf
- [x] T006 Update kubernetes_secret.homepage_widgets to include new environment variables in terraform/modules/homepage/main.tf
- [x] T007 Validate OpenTofu changes with tofu validate in terraform/environments/chocolandiadc-mvp/

**Checkpoint**: Foundation ready - configuration files can now be updated

---

## Phase 3: User Story 1 - Cluster Health at a Glance (Priority: P1) 🎯 MVP

**Goal**: Display cluster-wide CPU/memory utilization and node status in header widgets

**Independent Test**: Open Homepage and verify cluster CPU/memory percentages and node count visible in header area within 5 seconds

### Implementation for User Story 1

- [x] T008 [US1] Update widgets.yaml with resources and kubernetes widgets from specs/025-homepage-redesign/contracts/widgets.yaml to terraform/modules/homepage/configs/widgets.yaml
- [x] T009 [US1] Add Cluster Health section with Kubernetes API and Node Status cards to services.yaml from specs/025-homepage-redesign/contracts/services.yaml
- [x] T010 [US1] Update settings.yaml with dark theme and sky color palette from specs/025-homepage-redesign/contracts/settings.yaml to terraform/modules/homepage/configs/settings.yaml
- [x] T011 [US1] Verify YAML syntax validity with python3 -c "import yaml; yaml.safe_load(open('terraform/modules/homepage/configs/widgets.yaml'))"
- [x] T012 [US1] Run tofu plan to preview changes in terraform/environments/chocolandiadc-mvp/
- [x] T013 [US1] Apply changes with tofu apply -target=module.homepage in terraform/environments/chocolandiadc-mvp/
- [x] T014 [US1] Visual verification: Open https://homepage.chocolandiadc.com and confirm header widgets show cluster metrics

**Checkpoint**: Cluster health visible in header. User Story 1 complete.

---

## Phase 4: User Story 2 - Service Status and Access (Priority: P1)

**Goal**: Display all services organized by category with status indicators and access URLs

**Independent Test**: Verify each service card shows green status indicator, clickable URL, and access methods in description

### Implementation for User Story 2

- [x] T015 [US2] Add Critical Infrastructure section (Traefik, Pi-hole, PostgreSQL, Redis) to terraform/modules/homepage/configs/services.yaml
- [x] T016 [P] [US2] Add Platform Services section (ArgoCD, Grafana, Headlamp, cert-manager) to terraform/modules/homepage/configs/services.yaml
- [x] T017 [P] [US2] Add Applications section (Beersystem, Homepage, Prometheus) to terraform/modules/homepage/configs/services.yaml
- [x] T018 [P] [US2] Add Storage & Data section (Longhorn, MinIO Console, MinIO S3 API) to terraform/modules/homepage/configs/services.yaml
- [x] T019 [US2] Update layout in settings.yaml with 6 sections and column counts per specs/025-homepage-redesign/contracts/settings.yaml
- [x] T020 [US2] Apply changes with tofu apply -target=module.homepage in terraform/environments/chocolandiadc-mvp/
- [x] T021 [US2] Visual verification: Confirm 5 service categories visible with status dots and clickable URLs

**Checkpoint**: All services organized by category. User Stories 1 AND 2 complete.

---

## Phase 5: User Story 3 - Quick Reference Information (Priority: P2)

**Goal**: Provide quick access to SSH commands, kubectl commands, IP assignments, and certificate info

**Independent Test**: Verify Quick Reference section contains SSH commands, port-forward commands, MetalLB IPs, and certificate info

### Implementation for User Story 3

- [x] T022 [US3] Add Quick Reference section with SSH Access, Port Forwards, MetalLB IPs, Certificates, Common Commands to terraform/modules/homepage/configs/services.yaml
- [x] T023 [US3] Verify multi-line description YAML syntax with proper indentation
- [x] T024 [US3] Apply changes with tofu apply -target=module.homepage in terraform/environments/chocolandiadc-mvp/
- [x] T025 [US3] Visual verification: Confirm Quick Reference section displays all command reference cards

**Checkpoint**: Quick Reference section complete. User Stories 1, 2, AND 3 complete.

---

## Phase 6: User Story 4 - Visual Design and Aesthetics (Priority: P2)

**Goal**: Apply professional dark theme with sky color palette and modern card styling

**Independent Test**: Visual inspection confirming consistent color scheme, section organization, readable text contrast

### Implementation for User Story 4

- [x] T026 [US4] Verify cardBlur: sm and headerStyle: boxed applied in terraform/modules/homepage/configs/settings.yaml
- [x] T027 [US4] Verify statusStyle: dot configured for service status indicators
- [x] T028 [US4] Apply any final styling adjustments with tofu apply in terraform/environments/chocolandiadc-mvp/
- [x] T029 [US4] Visual verification: Confirm sky blue color theme, boxed headers, and dot status indicators

**Checkpoint**: Visual design complete. User Stories 1-4 complete.

---

## Phase 7: User Story 5 - Native Service Widgets (Priority: P3)

**Goal**: Display live metrics from Pi-hole, ArgoCD, Traefik, and Grafana

**Independent Test**: Verify native widgets show real-time data (Pi-hole blocked queries, ArgoCD sync status)

### Implementation for User Story 5

- [x] T030 [US5] Configure Pi-hole widget with API key in Cluster Health and Critical Infrastructure sections
- [x] T031 [P] [US5] Verify ArgoCD widget configuration uses existing HOMEPAGE_VAR_ARGOCD_TOKEN
- [x] T032 [P] [US5] Configure Traefik widget with internal cluster URL http://traefik.traefik.svc.cluster.local:9100
- [x] T033 [P] [US5] Configure Grafana widget with HOMEPAGE_VAR_GRAFANA_USER and HOMEPAGE_VAR_GRAFANA_PASSWORD
- [x] T034 [US5] Set environment variables for credentials before tofu apply
- [x] T035 [US5] Apply changes with tofu apply -target=module.homepage in terraform/environments/chocolandiadc-mvp/
- [ ] T036 [US5] Visual verification: Confirm Pi-hole shows queries/blocked, ArgoCD shows sync status, Traefik shows routes

**Checkpoint**: Native widgets showing live data. User Stories 1-5 complete.

---

## Phase 8: User Story 6 - Mobile Responsiveness (Priority: P3)

**Goal**: Dashboard usable on mobile devices with responsive column stacking

**Independent Test**: View Homepage on mobile device (or responsive mode) and confirm services visible and clickable

### Implementation for User Story 6

- [ ] T037 [US6] Verify useEqualHeights: false configured in settings.yaml for natural card sizing on mobile
- [ ] T038 [US6] Test responsive layout in browser developer tools at 375px width (iPhone)
- [ ] T039 [US6] Test responsive layout at 768px width (tablet)
- [ ] T040 [US6] Visual verification: Confirm service cards stack vertically and remain readable on mobile

**Checkpoint**: Mobile responsiveness verified. All User Stories complete.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, documentation, and blog article preparation

- [ ] T041 Measure page load time with time curl -s https://homepage.chocolandiadc.com (should be < 5 seconds)
- [ ] T042 [P] Take desktop screenshot for blog article
- [ ] T043 [P] Take mobile screenshot for blog article
- [ ] T044 Update CLAUDE.md Recent Changes section with 025-homepage-redesign completion
- [ ] T045 Run quickstart.md validation checklist
- [ ] T046 Commit all changes with descriptive commit message
- [ ] T047 Create PR for review

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all configuration changes
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - US1 and US2 can proceed in parallel (different file sections)
  - US3 can start after US2 (extends services.yaml)
  - US4 can run in parallel with US1-US3 (settings.yaml only)
  - US5 depends on credentials from Foundational phase
  - US6 can run anytime after US1-US2 (testing only)
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Foundational → widgets.yaml + settings.yaml + Cluster Health section
- **User Story 2 (P1)**: Foundational → services.yaml sections (Critical, Platform, Apps, Storage)
- **User Story 3 (P2)**: US2 → Quick Reference section (extends services.yaml)
- **User Story 4 (P2)**: Foundational → settings.yaml styling (can parallel with US1-US3)
- **User Story 5 (P3)**: Foundational credentials → native widget configuration
- **User Story 6 (P3)**: US1+US2 → responsive testing (read-only validation)

### Parallel Opportunities

Within Phase 2 (Foundational):
- T005 and T006 modify different files, but T006 depends on T005 for variable names

Within User Story 2:
- T016, T017, T018 can run in parallel (different sections of services.yaml)

Within User Story 5:
- T031, T032, T033 can run in parallel (different widget configurations)

Cross-Story Parallel:
- US1 (widgets.yaml) and US4 (settings.yaml styling) can proceed simultaneously
- US6 testing can happen anytime after US1+US2 implementation

---

## Parallel Example: User Story 2

```bash
# Launch all service section tasks together:
Task: "Add Critical Infrastructure section (Traefik, Pi-hole, PostgreSQL, Redis)"
Task: "Add Platform Services section (ArgoCD, Grafana, Headlamp, cert-manager)"
Task: "Add Applications section (Beersystem, Homepage, Prometheus)"
Task: "Add Storage & Data section (Longhorn, MinIO Console, MinIO S3 API)"
```

---

## Implementation Strategy

### MVP First (User Stories 1+2 Only)

1. Complete Phase 1: Setup (obtain credentials)
2. Complete Phase 2: Foundational (add variables and secrets)
3. Complete Phase 3: User Story 1 (cluster health in header)
4. Complete Phase 4: User Story 2 (service categories)
5. **STOP and VALIDATE**: Dashboard shows cluster health + organized services
6. Deploy/demo if ready - this is a functional MVP!

### Incremental Delivery

1. Setup + Foundational → Credentials ready
2. Add US1 + US2 → Core dashboard functional (MVP!)
3. Add US3 → Quick Reference adds operational value
4. Add US4 → Visual polish applied
5. Add US5 → Native widgets show live data
6. Add US6 → Mobile responsiveness verified
7. Polish → Blog article ready

### Rollback Plan

```bash
# If issues occur, restore backup:
cp -r terraform/modules/homepage/configs.backup/* terraform/modules/homepage/configs/
cd terraform/environments/chocolandiadc-mvp && tofu apply
```

---

## Notes

- [P] tasks = different files or sections, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- ConfigMaps auto-reload - no pod restart needed for most changes
- Commit after each phase or logical group of tasks
- Stop at any checkpoint to validate story independently
- All configuration from contracts/ directory - copy and adapt as needed
