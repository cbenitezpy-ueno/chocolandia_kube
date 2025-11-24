# Tasks: Nexus Repository Manager

**Input**: Design documents from `/specs/016-nexus-repository/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Validation scripts included as per homelab testing approach.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, etc.)
- Include exact file paths in descriptions

## Path Conventions

- **OpenTofu modules**: `terraform/modules/nexus/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`
- **Scripts**: `scripts/dev-tools/`
- **Dashboard config**: `terraform/dashboards/` and Homepage config

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create OpenTofu module structure and foundational resources

- [ ] T001 Create Nexus module directory structure at terraform/modules/nexus/
- [ ] T002 [P] Create module variables file at terraform/modules/nexus/variables.tf
- [ ] T003 [P] Create module outputs file at terraform/modules/nexus/outputs.tf
- [ ] T004 [P] Create module README at terraform/modules/nexus/README.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Kubernetes resources that MUST exist before any repository can work

**CRITICAL**: No user story work can begin until Nexus is deployed and running

- [ ] T005 Create Kubernetes Namespace resource in terraform/modules/nexus/main.tf
- [ ] T006 Create PersistentVolumeClaim (50Gi) in terraform/modules/nexus/main.tf
- [ ] T007 Create Nexus Deployment with container config in terraform/modules/nexus/main.tf
- [ ] T008 [P] Configure environment variables (JVM, security) in terraform/modules/nexus/main.tf
- [ ] T009 [P] Configure resource limits and probes in terraform/modules/nexus/main.tf
- [ ] T010 Create ClusterIP Service (port 8081) in terraform/modules/nexus/main.tf
- [ ] T011 Create cert-manager Certificate resource in terraform/modules/nexus/main.tf
- [ ] T012 Create Traefik IngressRoute for web UI in terraform/modules/nexus/main.tf
- [ ] T013 Create module instantiation at terraform/environments/chocolandiadc-mvp/nexus.tf
- [ ] T014 Add DNS entry to Pi-hole ConfigMap in terraform/modules/pihole/main.tf
- [ ] T015 Run tofu plan and tofu apply to deploy Nexus base
- [ ] T016 Verify Nexus pod is running and web UI accessible

**Checkpoint**: Nexus running - repository configuration can begin

---

## Phase 3: User Story 1 - Docker Images Management (Priority: P1)

**Goal**: Enable push/pull of Docker container images via Nexus

**Independent Test**: `docker login docker.nexus.chocolandiadc.local && docker push/pull test-image`

### Implementation for User Story 1

- [ ] T017 [US1] Create Docker connector Service (port 8082) in terraform/modules/nexus/main.tf
- [ ] T018 [US1] Add DNS entry for docker.nexus.chocolandiadc.local in terraform/modules/pihole/main.tf
- [ ] T019 [US1] Create cert-manager Certificate for Docker hostname in terraform/modules/nexus/main.tf
- [ ] T020 [US1] Create Traefik IngressRoute for Docker API in terraform/modules/nexus/main.tf
- [ ] T021 [US1] Apply changes with tofu apply -target=module.nexus
- [ ] T022 [US1] Configure docker-hosted repository via Nexus UI (HTTP connector port 8082)
- [ ] T023 [US1] Create validation script at scripts/dev-tools/validate-nexus-docker.sh
- [ ] T024 [US1] Test docker login, push, and pull operations

**Checkpoint**: Docker registry fully functional - MVP complete

---

## Phase 4: User Story 2 - Helm Charts Repository (Priority: P2)

**Goal**: Enable storage and retrieval of Helm charts

**Independent Test**: `helm repo add nexus https://nexus.chocolandiadc.local/repository/helm-hosted/ && helm push/install`

### Implementation for User Story 2

- [ ] T025 [US2] Configure helm-hosted repository via Nexus UI
- [ ] T026 [US2] Add Helm repository usage instructions to quickstart.md
- [ ] T027 [US2] Create validation script at scripts/dev-tools/validate-nexus-helm.sh
- [ ] T028 [US2] Test helm repo add, push chart, and install operations

**Checkpoint**: Helm repository functional

---

## Phase 5: User Story 3 - NPM Package Repository (Priority: P3)

**Goal**: Enable publishing and installing NPM packages

**Independent Test**: `npm publish --registry https://nexus.../npm-hosted/ && npm install package`

### Implementation for User Story 3

- [ ] T029 [US3] Configure npm-hosted repository via Nexus UI
- [ ] T030 [US3] Add NPM repository usage instructions to quickstart.md
- [ ] T031 [US3] Create validation script at scripts/dev-tools/validate-nexus-npm.sh
- [ ] T032 [US3] Test npm publish and install operations

**Checkpoint**: NPM repository functional

---

## Phase 6: User Story 4 - Maven Artifacts Repository (Priority: P3)

**Goal**: Enable deploying and resolving Maven artifacts

**Independent Test**: `mvn deploy` to Nexus and `mvn install` from dependent project

### Implementation for User Story 4

- [ ] T033 [US4] Configure maven-releases repository via Nexus UI
- [ ] T034 [US4] Configure maven-snapshots repository via Nexus UI
- [ ] T035 [US4] Add Maven repository usage instructions to quickstart.md
- [ ] T036 [US4] Create validation script at scripts/dev-tools/validate-nexus-maven.sh
- [ ] T037 [US4] Test mvn deploy and dependency resolution

**Checkpoint**: Maven repository functional

---

## Phase 7: User Story 5 - APT Package Repository (Priority: P4)

**Goal**: Enable hosting and distributing Debian packages

**Independent Test**: Configure APT source, run `apt update && apt install` from Nexus

### Implementation for User Story 5

- [ ] T038 [US5] Configure apt-hosted repository via Nexus UI
- [ ] T039 [US5] Add APT repository usage instructions to quickstart.md
- [ ] T040 [US5] Create validation script at scripts/dev-tools/validate-nexus-apt.sh
- [ ] T041 [US5] Test apt repository configuration and package installation

**Checkpoint**: APT repository functional - All 5 repository types complete

---

## Phase 8: Observability & Integration

**Purpose**: Grafana metrics and Homepage dashboard integration

- [ ] T042 [P] Create ServiceMonitor for Prometheus metrics in terraform/modules/nexus/main.tf
- [ ] T043 [P] Add Nexus metrics panel to terraform/dashboards/homelab-overview.json
- [ ] T044 Add Nexus service entry to Homepage dashboard in kubernetes/homepage/config/services.yaml
- [ ] T045 Add basic usage instructions to Homepage (docker login, helm repo add commands)
- [ ] T046 Apply dashboard and Homepage updates

**Checkpoint**: Nexus fully integrated with cluster monitoring and documentation

---

## Phase 9: Cleanup & Migration

**Purpose**: Remove old Docker Registry and finalize deployment

- [ ] T047 Verify all critical images from old registry are pushed to Nexus
- [ ] T048 Update any cluster ImagePullSecrets to use Nexus credentials
- [ ] T049 Remove old registry module from terraform/environments/chocolandiadc-mvp/registry.tf
- [ ] T050 Remove old registry DNS entries from Pi-hole ConfigMap
- [ ] T051 Run tofu apply to destroy old registry resources
- [ ] T052 Delete old registry module directory terraform/modules/registry/
- [ ] T053 Run full validation: scripts/dev-tools/validate-nexus.sh (combines all repo tests)
- [ ] T054 Commit and push all changes to feature branch

**Checkpoint**: Migration complete - Old registry removed

---

## Phase 10: Polish & Documentation

**Purpose**: Final documentation and cleanup

- [ ] T055 [P] Update specs/016-nexus-repository/quickstart.md with final configurations
- [ ] T056 [P] Update CLAUDE.md with Nexus endpoint information
- [ ] T057 Verify all Grafana dashboards show Nexus metrics
- [ ] T058 Create PR for feature branch merge to main

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - MVP Docker registry
- **User Stories 2-5 (Phases 4-7)**: Can run in parallel after Phase 3 or sequentially
- **Observability (Phase 8)**: Can start after Phase 2, independent of repo configs
- **Cleanup (Phase 9)**: Depends on all user stories being validated
- **Polish (Phase 10)**: Depends on Cleanup

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|------------|-------------------|
| US1 (Docker) | Foundational | None (MVP first) |
| US2 (Helm) | Foundational | US3, US4, US5 |
| US3 (NPM) | Foundational | US2, US4, US5 |
| US4 (Maven) | Foundational | US2, US3, US5 |
| US5 (APT) | Foundational | US2, US3, US4 |

### Parallel Opportunities

**Within Phase 1 (Setup)**:
- T002, T003, T004 can run in parallel (different files)

**Within Phase 2 (Foundational)**:
- T008, T009 can run in parallel (same file but different sections)

**Across User Stories**:
- US2, US3, US4, US5 can all run in parallel after US1 MVP validated

**Within Phase 8 (Observability)**:
- T042, T043 can run in parallel (different files)

---

## Parallel Example: User Story 1

```bash
# After Foundational is complete, launch US1 infrastructure:
Task: "Create Docker connector Service (port 8082) in terraform/modules/nexus/main.tf"
Task: "Add DNS entry for docker.nexus.chocolandiadc.local"
Task: "Create cert-manager Certificate for Docker hostname"
# These modify same file but different resources - can be done sequentially or in sections
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T016)
3. Complete Phase 3: User Story 1 - Docker (T017-T024)
4. **STOP and VALIDATE**: Test Docker push/pull independently
5. This is your MVP - Nexus with Docker registry working

### Incremental Delivery

1. Setup + Foundational → Nexus running
2. Add US1 (Docker) → MVP deployed
3. Add US2 (Helm) → Extended functionality
4. Add US3 (NPM) → JavaScript support
5. Add US4 (Maven) → Java support
6. Add US5 (APT) → Debian support
7. Add Observability → Full monitoring
8. Cleanup → Old registry removed

### Estimated Task Counts

| Phase | Tasks | Parallel Opportunities |
|-------|-------|------------------------|
| Setup | 4 | 3 |
| Foundational | 12 | 2 |
| US1 Docker | 8 | 0 |
| US2 Helm | 4 | 0 |
| US3 NPM | 4 | 0 |
| US4 Maven | 5 | 0 |
| US5 APT | 4 | 0 |
| Observability | 5 | 2 |
| Cleanup | 8 | 0 |
| Polish | 4 | 2 |
| **Total** | **58** | **9** |

---

## Notes

- [P] tasks = different files, no blocking dependencies
- [Story] label maps task to specific user story for traceability
- Repository configurations (US2-US5) are via Nexus UI, not OpenTofu
- Validation scripts test each repository type independently
- Commit after each logical group of tasks
- Old registry removal only after all 5 repo types validated
