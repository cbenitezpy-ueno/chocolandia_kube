# Tasks: LocalStack and Container Registry for Local Development

**Input**: Design documents from `/specs/015-dev-tools-local/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Validation scripts included (per plan.md: "Bash scripts for validation")

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

## Path Conventions (Infrastructure Project)

- **OpenTofu modules**: `terraform/modules/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`
- **Validation scripts**: `scripts/dev-tools/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create module structure and shared configuration

- [x] T001 Create registry module directory structure at terraform/modules/registry/
- [x] T002 Create localstack module directory structure at terraform/modules/localstack/
- [x] T003 [P] Create validation scripts directory at scripts/dev-tools/
- [x] T004 [P] Generate htpasswd credentials secret for registry auth at kubernetes/dev-tools/secrets/htpasswd
- [x] T005 [P] Create README.md for registry module explaining purpose and usage at terraform/modules/registry/README.md
- [x] T006 [P] Create README.md for localstack module explaining purpose and usage at terraform/modules/localstack/README.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T007 Create registry module variables.tf with storage_size, hostname, auth_secret, namespace inputs at terraform/modules/registry/variables.tf
- [x] T008 [P] Create localstack module variables.tf with services_list, storage_size, hostname, namespace inputs at terraform/modules/localstack/variables.tf
- [x] T009 Create registry module outputs.tf with registry_url, credentials_secret_name at terraform/modules/registry/outputs.tf
- [x] T010 [P] Create localstack module outputs.tf with endpoint_url, services_enabled at terraform/modules/localstack/outputs.tf

**Checkpoint**: Module interfaces defined - implementation can begin

---

## Phase 3: User Story 1 - Push and Pull Container Images (Priority: P1)

**Goal**: Deploy Docker Registry v2 with basic auth and HTTPS so developers can push/pull images locally

**Independent Test**: `docker login`, `docker push`, `docker pull` against registry.homelab.local

### Implementation for User Story 1

- [x] T011 [US1] Create registry PersistentVolumeClaim (30Gi) in terraform/modules/registry/main.tf
- [x] T012 [US1] Create registry ConfigMap with config.yml (htpasswd auth, storage path) in terraform/modules/registry/main.tf
- [x] T013 [US1] Create registry Deployment (registry:2 image, volume mounts, resource limits, liveness/readiness probes on /v2/) in terraform/modules/registry/main.tf
- [x] T014 [US1] Create registry Service (ClusterIP, port 5000) in terraform/modules/registry/main.tf
- [x] T015 [US1] Create registry IngressRoute with cert-manager TLS for registry.homelab.local in terraform/modules/registry/main.tf
- [x] T016 [US1] Create registry Traefik Middleware for basic-auth in terraform/modules/registry/main.tf
- [x] T017 [US1] Instantiate registry module in terraform/environments/chocolandiadc-mvp/registry.tf
- [ ] T018 [US1] Add DNS record for registry.homelab.local in Pi-hole (manual step, document in quickstart)
- [x] T019 [US1] Create validation script for docker push/pull at scripts/dev-tools/validate-registry.sh
- [x] T020 [US1] Document K3s registries.yaml configuration for node trust in specs/015-dev-tools-local/quickstart.md

**Checkpoint**: Registry functional - `docker login`, `docker push`, `docker pull` work

---

## Phase 4: User Story 2 - Emulate AWS S3 (Priority: P1)

**Goal**: Deploy LocalStack with S3 enabled so developers can test S3 operations locally

**Independent Test**: `aws s3 mb`, `aws s3 cp`, `aws s3 ls` against localstack.homelab.local

### Implementation for User Story 2

- [x] T021 [US2] Create localstack PersistentVolumeClaim (20Gi) in terraform/modules/localstack/main.tf
- [x] T022 [US2] Create localstack Deployment with SERVICES=s3,sqs,sns,dynamodb,lambda, PERSISTENCE=1, liveness/readiness probes on /_localstack/health in terraform/modules/localstack/main.tf
- [x] T023 [US2] Create localstack Service (ClusterIP, port 4566) in terraform/modules/localstack/main.tf
- [x] T024 [US2] Create localstack IngressRoute with cert-manager TLS for localstack.homelab.local in terraform/modules/localstack/main.tf
- [x] T025 [US2] Instantiate localstack module in terraform/environments/chocolandiadc-mvp/localstack.tf
- [ ] T026 [US2] Add DNS record for localstack.homelab.local in Pi-hole (manual step, document in quickstart)
- [x] T027 [US2] Create validation script for S3 operations at scripts/dev-tools/validate-localstack-s3.sh
- [x] T028 [US2] Document AWS CLI endpoint configuration for LocalStack in specs/015-dev-tools-local/quickstart.md

**Checkpoint**: LocalStack S3 functional - bucket create, upload, download work

---

## Phase 5: User Story 3 - Emulate SQS/SNS (Priority: P2)

**Goal**: Verify SQS and SNS message queue functionality in LocalStack

**Independent Test**: Create queue, send message, receive message using AWS CLI

### Implementation for User Story 3

- [x] T029 [US3] Create validation script for SQS operations at scripts/dev-tools/validate-localstack-sqs.sh
- [x] T030 [US3] Create validation script for SNS operations at scripts/dev-tools/validate-localstack-sns.sh
- [x] T031 [US3] Document SQS/SNS usage examples in specs/015-dev-tools-local/contracts/localstack-api.md

**Checkpoint**: SQS/SNS functional - queue create, message send/receive work

---

## Phase 6: User Story 4 - Emulate DynamoDB (Priority: P2)

**Goal**: Verify DynamoDB table operations in LocalStack

**Independent Test**: Create table, put item, get item using AWS CLI

### Implementation for User Story 4

- [x] T032 [US4] Create validation script for DynamoDB operations at scripts/dev-tools/validate-localstack-dynamodb.sh
- [x] T033 [US4] Document DynamoDB usage examples in specs/015-dev-tools-local/contracts/localstack-api.md

**Checkpoint**: DynamoDB functional - table create, item put/get work

---

## Phase 7: User Story 5 - Registry Web UI (Priority: P3)

**Goal**: Deploy Registry UI for visual image browsing

**Independent Test**: Access registry-ui.homelab.local in browser, see image list

### Implementation for User Story 5

- [x] T034 [US5] Create registry-ui Deployment (joxit/docker-registry-ui image) in terraform/modules/registry/main.tf
- [x] T035 [US5] Create registry-ui Service (ClusterIP, port 80) in terraform/modules/registry/main.tf
- [x] T036 [US5] Create registry-ui IngressRoute for registry-ui.homelab.local in terraform/modules/registry/main.tf
- [ ] T037 [US5] Add DNS record for registry-ui.homelab.local in Pi-hole (manual step, document in quickstart)
- [x] T038 [US5] Create validation script for UI accessibility at scripts/dev-tools/validate-registry-ui.sh

**Checkpoint**: Registry UI accessible and shows pushed images

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and final validation

- [x] T039 [P] Document garbage collection procedure for registry in specs/015-dev-tools-local/quickstart.md
- [x] T040 [P] Create comprehensive validation script that runs all tests at scripts/dev-tools/validate-all.sh
- [x] T041 [P] Add Prometheus metrics annotations to registry deployment in terraform/modules/registry/main.tf
- [x] T042 [P] Add health endpoint monitoring for LocalStack in terraform/modules/localstack/main.tf
- [x] T043 Run tofu fmt and tofu validate on all OpenTofu files
- [ ] T044 Run full quickstart.md validation end-to-end
- [ ] T045 Commit and push feature branch for review

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup completion
- **User Story 1 (Phase 3)**: Depends on Foundational - REGISTRY deployment
- **User Story 2 (Phase 4)**: Depends on Foundational - LOCALSTACK deployment
- **User Story 3-4 (Phase 5-6)**: Depends on User Story 2 (LocalStack must be running)
- **User Story 5 (Phase 7)**: Depends on User Story 1 (Registry must be running)
- **Polish (Phase 8)**: Depends on all user stories complete

### User Story Dependencies

```
Setup → Foundational → ┬→ US1 (Registry) → US5 (Registry UI)
                       │
                       └→ US2 (LocalStack S3) → US3 (SQS/SNS)
                                              → US4 (DynamoDB)
```

### Critical Path

1. Setup (T001-T006)
2. Foundational (T007-T010)
3. US1: Registry (T011-T020) - MVP
4. US2: LocalStack (T021-T028) - MVP
5. Then parallel: US3, US4, US5
6. Polish (T039-T045)

### Parallel Opportunities

**Within Phase 1 (Setup)**:
```
T001, T002, T003, T004, T005, T006 can all run in parallel
```

**Within Phase 2 (Foundational)**:
```
T007 || T008 (different modules)
T009 || T010 (different modules)
```

**After Foundational completes**:
```
US1 (Registry) || US2 (LocalStack) can run in parallel
```

**Within User Story 1**:
```
T011 first (PVC needed)
Then T012, T013 can run in parallel
Then T014, T015, T016 after deployment exists
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1 (Registry)
4. **VALIDATE**: `docker login`, `docker push`, `docker pull`
5. Complete Phase 4: User Story 2 (LocalStack S3)
6. **VALIDATE**: `aws s3` commands work
7. **MVP COMPLETE** - Can stop here if needed

### Incremental Delivery

| Increment | Includes | Value Delivered |
|-----------|----------|-----------------|
| MVP | US1 + US2 | Registry push/pull + S3 emulation |
| +1 | US3 + US4 | Full LocalStack (SQS, SNS, DynamoDB) |
| +2 | US5 | Visual registry browsing |
| Final | Polish | Documentation, monitoring, cleanup |

---

## Summary

| Metric | Count |
|--------|-------|
| Total Tasks | 45 |
| Setup Tasks | 6 |
| Foundational Tasks | 4 |
| US1 Tasks (Registry) | 10 |
| US2 Tasks (LocalStack) | 8 |
| US3 Tasks (SQS/SNS) | 3 |
| US4 Tasks (DynamoDB) | 2 |
| US5 Tasks (Registry UI) | 5 |
| Polish Tasks | 7 |
| Parallel Opportunities | 17 tasks marked [P] |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete work
- [Story] label maps task to specific user story for traceability
- Each user story independently testable after completion
- Validation scripts verify acceptance criteria from spec
- Commit after each completed user story
- MVP scope: User Story 1 + User Story 2 (registry + LocalStack core)
