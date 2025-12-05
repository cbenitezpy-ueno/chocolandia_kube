# Tasks: Govee2MQTT Integration

**Input**: Design documents from `/specs/019-govee2mqtt/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: No test tasks included (not explicitly requested in spec). Validation via kubectl smoke tests.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **OpenTofu modules**: `terraform/modules/[module-name]/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create OpenTofu module structure and directory layout

- [ ] T001 Create Mosquitto module directory structure at terraform/modules/mosquitto/
- [ ] T002 [P] Create govee2mqtt module directory structure at terraform/modules/govee2mqtt/

---

## Phase 2: Foundational (MQTT Broker - Blocking Prerequisite)

**Purpose**: Deploy Mosquitto MQTT broker - MUST be complete before govee2mqtt can connect

**⚠️ CRITICAL**: No govee2mqtt work can begin until Mosquitto is deployed and accessible

- [ ] T003 Create Mosquitto variables.tf with namespace, storage_size, storage_class, image inputs at terraform/modules/mosquitto/variables.tf
- [ ] T004 [P] Create Mosquitto main.tf with ConfigMap for mosquitto.conf at terraform/modules/mosquitto/main.tf
- [ ] T005 Create Mosquitto main.tf PersistentVolumeClaim resource at terraform/modules/mosquitto/main.tf
- [ ] T006 Create Mosquitto main.tf Deployment resource with probes at terraform/modules/mosquitto/main.tf
- [ ] T007 Create Mosquitto main.tf Service (ClusterIP) resource at terraform/modules/mosquitto/main.tf
- [ ] T008 Create Mosquitto outputs.tf with service_name, service_host, service_port at terraform/modules/mosquitto/outputs.tf
- [ ] T009 Create environment module instantiation for Mosquitto at terraform/environments/chocolandiadc-mvp/govee2mqtt.tf
- [ ] T010 Run tofu plan and tofu apply for Mosquitto module
- [ ] T011 Validate Mosquitto deployment with kubectl get pods -n home-assistant

**Checkpoint**: Mosquitto running and accessible at mosquitto.home-assistant.svc.cluster.local:1883

---

## Phase 3: User Story 1 - Control Local de Dispositivos Govee (Priority: P1) 🎯 MVP

**Goal**: Deploy govee2mqtt bridge to enable local control of Govee devices from Home Assistant

**Independent Test**: Encender/apagar una luz Govee desde Home Assistant y verificar respuesta < 2 segundos

### Implementation for User Story 1

- [ ] T012 [P] [US1] Create govee2mqtt variables.tf with namespace, image, credentials, mqtt_host, mqtt_port, timezone at terraform/modules/govee2mqtt/variables.tf
- [ ] T013 [P] [US1] Create govee2mqtt main.tf Kubernetes Secret for Govee credentials at terraform/modules/govee2mqtt/main.tf
- [ ] T014 [US1] Create govee2mqtt main.tf Deployment with hostNetwork=true and env from Secret at terraform/modules/govee2mqtt/main.tf
- [ ] T015 [US1] Create govee2mqtt outputs.tf with deployment_name, namespace at terraform/modules/govee2mqtt/outputs.tf
- [ ] T016 [US1] Add govee2mqtt module instantiation to terraform/environments/chocolandiadc-mvp/govee2mqtt.tf
- [ ] T017 [US1] Run tofu plan and tofu apply for govee2mqtt module
- [ ] T018 [US1] Validate govee2mqtt pod is running with kubectl get pods -n home-assistant -l app.kubernetes.io/name=govee2mqtt
- [ ] T019 [US1] Check govee2mqtt logs for successful MQTT connection with kubectl logs

**Checkpoint**: govee2mqtt running, connected to Mosquitto, ready for Home Assistant MQTT integration

---

## Phase 4: User Story 2 - Descubrimiento Automático de Dispositivos (Priority: P2)

**Goal**: Configure Home Assistant MQTT integration so Govee devices auto-discover

**Independent Test**: Verificar que dispositivos Govee aparecen en Home Assistant < 5 minutos después del despliegue

### Implementation for User Story 2

- [ ] T020 [US2] Document MQTT integration setup steps for Home Assistant UI in specs/019-govee2mqtt/quickstart.md
- [ ] T021 [US2] Validate MQTT broker connectivity from Home Assistant namespace
- [ ] T022 [US2] Configure Home Assistant MQTT integration via UI (manual step - document in quickstart.md)
- [ ] T023 [US2] Verify device discovery by checking homeassistant/# MQTT topics with mosquitto_sub
- [ ] T024 [US2] Confirm Govee devices appear in Home Assistant Devices & Services

**Checkpoint**: Dispositivos Govee visibles en Home Assistant automáticamente

---

## Phase 5: User Story 3 - Monitoreo de Estado en Tiempo Real (Priority: P3)

**Goal**: Verify real-time state synchronization between Govee devices and Home Assistant

**Independent Test**: Cambiar estado de dispositivo desde app Govee y verificar actualización en Home Assistant < 5 segundos

### Implementation for User Story 3

- [ ] T025 [US3] Test state change from Govee app reflects in Home Assistant
- [ ] T026 [US3] Test state change from Home Assistant reflects on physical device
- [ ] T027 [US3] Verify bidirectional state sync works with LAN-enabled devices
- [ ] T028 [US3] Document any devices that only support cloud sync in quickstart.md

**Checkpoint**: Estado de dispositivos sincronizado en tiempo real entre Govee app y Home Assistant

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and cleanup

- [ ] T029 [P] Update CLAUDE.md with new technologies (govee2mqtt, Mosquitto MQTT)
- [ ] T030 [P] Update specs/019-govee2mqtt/quickstart.md with final deployment steps
- [ ] T031 Run full quickstart.md validation from scratch
- [ ] T032 Commit all changes with descriptive message
- [ ] T033 Create PR to merge 019-govee2mqtt to main

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories (Mosquitto must be running)
- **User Story 1 (Phase 3)**: Depends on Foundational (Mosquitto) - Core deployment
- **User Story 2 (Phase 4)**: Depends on US1 (govee2mqtt must be running for discovery)
- **User Story 3 (Phase 5)**: Depends on US2 (devices must be discovered to test state sync)
- **Polish (Phase 6)**: Depends on all user stories complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Mosquitto is deployed - Core functionality
- **User Story 2 (P2)**: Requires US1 complete (govee2mqtt running) - Discovery validation
- **User Story 3 (P3)**: Requires US2 complete (devices discovered) - State sync validation

### Within Each Phase

- Tasks with [P] marker can run in parallel
- Sequential tasks must complete in order (T003 → T004 → T005...)
- Commit after each logical group of tasks

### Parallel Opportunities

- T001 and T002 can run in parallel (different directories)
- T003 and T004 can run in parallel (different files)
- T012 and T013 can run in parallel (different concerns in same module)
- T029 and T030 can run in parallel (different files)

---

## Parallel Example: Phase 1 Setup

```bash
# Launch both directory creation tasks together:
Task: "Create Mosquitto module directory at terraform/modules/mosquitto/"
Task: "Create govee2mqtt module directory at terraform/modules/govee2mqtt/"
```

## Parallel Example: User Story 1 Initial Tasks

```bash
# Launch variables and secret tasks together:
Task: "Create govee2mqtt variables.tf at terraform/modules/govee2mqtt/variables.tf"
Task: "Create govee2mqtt Secret resource at terraform/modules/govee2mqtt/main.tf"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (create directories)
2. Complete Phase 2: Foundational (deploy Mosquitto)
3. Complete Phase 3: User Story 1 (deploy govee2mqtt)
4. **STOP and VALIDATE**: Test control of one Govee device from Home Assistant
5. If working → Proceed to US2 and US3

### Incremental Delivery

1. Setup + Foundational → Mosquitto running
2. Add User Story 1 → govee2mqtt running → **MVP Complete!**
3. Add User Story 2 → Devices auto-discovered in Home Assistant
4. Add User Story 3 → Real-time state sync validated
5. Polish → Documentation complete, PR ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- This is infrastructure deployment - "tests" are validation steps (kubectl, logs)
- Commit after each phase completion
- Stop at any checkpoint to validate incrementally
- **Govee API Key**: Already provided by user (stored in TF_VAR_govee_api_key)
