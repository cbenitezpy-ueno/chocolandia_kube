# Tasks: Home Assistant with Prometheus Temperature Monitoring

**Input**: Design documents from `/specs/018-home-assistant/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/
**Scope**: Phase 1 - Base Installation + Prometheus Integration (Govee deferred to Phase 2)

**Tests**: Manual validation scripts only (no automated test suite requested)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Infrastructure project**: `terraform/modules/home-assistant/`, `terraform/environments/chocolandiadc-mvp/`
- Home Assistant configuration is managed within the container via PVC at `/config`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: OpenTofu module initialization and basic Kubernetes resources

- [ ] T001 Create OpenTofu module directory structure at terraform/modules/home-assistant/
- [ ] T002 [P] Create variables.tf with configurable parameters in terraform/modules/home-assistant/variables.tf
- [ ] T003 [P] Create outputs.tf with service endpoints in terraform/modules/home-assistant/outputs.tf
- [ ] T004 Create module instantiation in terraform/environments/chocolandiadc-mvp/home-assistant.tf

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Kubernetes resources that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Create Kubernetes namespace resource in terraform/modules/home-assistant/main.tf
- [ ] T006 [P] Create PersistentVolumeClaim for Home Assistant config (10Gi) in terraform/modules/home-assistant/main.tf
- [ ] T007 [P] Create Deployment resource with Home Assistant container in terraform/modules/home-assistant/main.tf
- [ ] T008 [P] Create ClusterIP Service resource in terraform/modules/home-assistant/main.tf
- [ ] T009 [P] Create Ingress for local domain (homeassistant.chocolandiadc.local) with local-ca in terraform/modules/home-assistant/main.tf
- [ ] T010 [P] Create Ingress for external domain (homeassistant.chocolandiadc.com) with letsencrypt in terraform/modules/home-assistant/main.tf
- [ ] T011 Run tofu validate and tofu plan to verify configuration
- [ ] T012 Apply OpenTofu configuration with tofu apply -target=module.home_assistant
- [ ] T013 Verify Home Assistant pod is running with kubectl get pods -n home-assistant
- [ ] T014 Wait for certificates to be issued with kubectl get certificates -n home-assistant
- [ ] T015 Complete Home Assistant onboarding wizard via web UI (create admin account)

**Checkpoint**: Home Assistant is deployed and accessible via both domains with valid TLS

---

## Phase 3: User Story 1 - Prometheus Temperature Visualization (Priority: P1) 🎯 MVP

**Goal**: View CPU temperature from Prometheus in Home Assistant dashboard

**Independent Test**: Access Home Assistant dashboard and verify the temperature sensor card shows current CPU temperature from Prometheus

### Implementation for User Story 1

- [ ] T016 [US1] Install HACS via kubectl exec into Home Assistant pod (wget -O - https://get.hacs.xyz | bash -)
- [ ] T017 [US1] Restart Home Assistant pod after HACS installation with kubectl rollout restart -n home-assistant deploy/home-assistant
- [ ] T018 [US1] Configure HACS integration via Home Assistant UI (Settings → Devices & Services → Add Integration → HACS)
- [ ] T019 [US1] Add ha-prometheus-sensor repository via HACS (HACS → Integrations → Custom repositories → https://github.com/mweinelt/ha-prometheus-sensor)
- [ ] T020 [US1] Install ha-prometheus-sensor integration from HACS
- [ ] T021 [US1] Restart Home Assistant after installing custom integration with kubectl rollout restart
- [ ] T022 [US1] Configure Prometheus sensor in /config/configuration.yaml with PromQL query for CPU temperature
- [ ] T023 [US1] Restart Home Assistant to load Prometheus sensor configuration
- [ ] T024 [US1] Verify sensor.node_cpu_temperature entity shows numeric value in Developer Tools → States
- [ ] T025 [US1] Add temperature sensor card to Home Assistant dashboard (Overview → Edit → Add Card → Sensor)
- [ ] T026 [US1] Verify temperature sensor updates within 60 seconds when Prometheus metric changes

**Checkpoint**: Temperature sensor visible on dashboard with live data from Prometheus

---

## Phase 4: User Story 2 - Home Assistant Dashboard Access (Priority: P2)

**Goal**: Secure access to Home Assistant dashboard from local network and via Cloudflare Zero Trust

**Independent Test**: Access dashboard via both domains, verify TLS certificates are valid, verify temperature sensor is visible

### Implementation for User Story 2

- [ ] T027 [US2] Verify local domain access at https://homeassistant.chocolandiadc.local with valid local-ca certificate
- [ ] T028 [US2] Verify external domain access at https://homeassistant.chocolandiadc.com with valid Let's Encrypt certificate
- [ ] T029 [US2] Verify Cloudflare Zero Trust protects external domain (may need manual configuration)
- [ ] T030 [US2] Verify dashboard load time is under 3 seconds (SC-001)
- [ ] T031 [US2] Verify temperature sensor from Prometheus is visible after login

**Checkpoint**: Dashboard is accessible via both domains with proper TLS and temperature sensor visible

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, validation, and documentation

- [ ] T032 [P] Add Pi-hole DNS entry for homeassistant.chocolandiadc.local (if not auto-resolved)
- [ ] T033 [P] Update Homepage dashboard to include Home Assistant service link
- [ ] T034 Verify configuration persists across pod restart with kubectl rollout restart -n home-assistant deploy/home-assistant
- [ ] T035 Run quickstart.md validation - verify all steps work
- [ ] T036 Update CLAUDE.md with Home Assistant service information (already done by update-agent-context.sh)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational phase completion
- **User Story 2 (Phase 4)**: Depends on Foundational phase (but can run in parallel with US1)
- **Polish (Phase 5)**: Depends on at least US1 being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Independently testable

### Within Each User Story

- HACS must be installed before custom integrations
- Custom integrations must restart HA before configuration
- Prometheus sensor must show data before dashboard card can display it

### Parallel Opportunities

- T002, T003 can run in parallel (different files)
- T006, T007, T008, T009, T010 can run in parallel (independent K8s resources in same file but logically independent)
- T027, T028 can run in parallel (different domain tests)
- T032, T033 can run in parallel (independent systems)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (4 tasks)
2. Complete Phase 2: Foundational (11 tasks) - CRITICAL blocks all stories
3. Complete Phase 3: User Story 1 (11 tasks)
4. **STOP and VALIDATE**: Verify temperature sensor shows in dashboard
5. Deploy/demo if ready - core functionality complete!

### Incremental Delivery

1. Complete Setup + Foundational → HA deployed and accessible
2. Add User Story 1 → Temperature visualization works (MVP!)
3. Add User Story 2 → Dashboard access validated
4. Polish → Documentation and DNS complete

### Single Developer Strategy

With one developer (recommended order):

1. Complete Phases 1-2: Setup + Foundational (15 tasks)
2. Complete Phase 3: User Story 1 (11 tasks) - validate MVP
3. Complete Phase 4: User Story 2 (5 tasks)
4. Complete Phase 5: Polish (5 tasks)

**Total Tasks**: 36

---

## Deferred to Phase 2 (Manual Implementation)

The following are explicitly OUT OF SCOPE for this tasks.md:

- Govee smart plug integration (user will configure via HACS or Alexa)
- Temperature-based automations (ON at 50°C, OFF at 45°C)
- Ntfy push notifications
- Hysteresis logic

---

## Notes

- [P] tasks = different files or systems, no dependencies
- [Story] label maps task to specific user story for traceability
- User Story 1 is the MVP - delivers temperature visualization value
- Many tasks require UI interaction (HA dashboard) - cannot be fully automated
- HACS installation requires kubectl exec into pod
- Restart HA after configuration changes to apply
- Prometheus sensor URL: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
