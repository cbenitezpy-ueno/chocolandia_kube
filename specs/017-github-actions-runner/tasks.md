# Tasks: GitHub Actions Self-Hosted Runner

**Input**: Design documents from `/specs/017-github-actions-runner/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Validation scripts included as per constitution (Test-Driven Learning principle)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **OpenTofu modules**: `terraform/modules/github-actions-runner/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`
- **Kubernetes manifests**: `kubernetes/github-actions-runner/`
- **Validation scripts**: `scripts/github-actions-runner/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, directory structure, and prerequisites

- [x] T001 Create OpenTofu module directory structure at terraform/modules/github-actions-runner/
- [x] T002 [P] Create Kubernetes manifests directory at kubernetes/github-actions-runner/
- [x] T003 [P] Create validation scripts directory at scripts/github-actions-runner/
- [x] T004 [P] Create module README documentation at terraform/modules/github-actions-runner/README.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Define OpenTofu variables for GitHub App credentials in terraform/modules/github-actions-runner/variables.tf
- [x] T006 [P] Create Kubernetes namespace manifest at kubernetes/github-actions-runner/namespace.yaml
- [x] T007 [P] Create ServiceAccount and RBAC resources at kubernetes/github-actions-runner/rbac.yaml
- [x] T008 Create GitHub App Secret template at kubernetes/github-actions-runner/github-app-secret.yaml.template
- [x] T009 Add Helm provider configuration for ARC charts in terraform/modules/github-actions-runner/main.tf (provider block)
- [x] T010 Deploy ARC controller (gha-runner-scale-set-controller) in terraform/modules/github-actions-runner/main.tf

**Checkpoint**: Foundation ready - ARC controller running, namespace and RBAC in place

---

## Phase 3: User Story 1 - Run CI/CD Workflows on Local Infrastructure (Priority: P1)

**Goal**: Deploy functional self-hosted runner that can execute GitHub Actions workflows

**Independent Test**: Trigger test workflow with `runs-on: self-hosted` and verify execution on homelab runner

### Implementation for User Story 1

- [x] T011 [US1] Configure runner scale set variables (min/max runners, labels) in terraform/modules/github-actions-runner/variables.tf
- [x] T012 [US1] Deploy runner scale set (gha-runner-scale-set) Helm release in terraform/modules/github-actions-runner/main.tf
- [x] T013 [US1] Define runner pod template with resource limits in terraform/modules/github-actions-runner/main.tf
- [x] T014 [US1] Create outputs for runner status in terraform/modules/github-actions-runner/outputs.tf
- [x] T015 [US1] Create module instantiation in terraform/environments/chocolandiadc-mvp/github-actions-runner.tf
- [x] T016 [US1] Create validation script to check runner registration at scripts/github-actions-runner/validate-runner.sh
- [x] T017 [US1] Create test workflow file at .github/workflows/test-self-hosted-runner.yaml
- [x] T018 [US1] Create script to trigger and verify test workflow at scripts/github-actions-runner/test-workflow.sh

**Checkpoint**: Runner registered with GitHub, test workflow executes successfully on homelab

---

## Phase 4: User Story 2 - Monitor Runner Health and Status (Priority: P2)

**Goal**: Enable monitoring of runner health via Prometheus/Grafana with alerting

**Independent Test**: View runner metrics in Grafana dashboard and verify alert triggers when runner goes offline

### Implementation for User Story 2

- [x] T019 [US2] Create ServiceMonitor for ARC metrics at kubernetes/github-actions-runner/servicemonitor.yaml
- [x] T020 [US2] Add ServiceMonitor deployment to OpenTofu module in terraform/modules/github-actions-runner/main.tf
- [x] T021 [US2] Create PrometheusRule for runner offline alert at kubernetes/github-actions-runner/prometheusrule.yaml
- [x] T022 [US2] Add PrometheusRule deployment to OpenTofu module in terraform/modules/github-actions-runner/main.tf
- [x] T023 [US2] Create Grafana dashboard JSON at terraform/dashboards/github-actions-runner.json
- [x] T024 [US2] Create validation script for monitoring integration at scripts/github-actions-runner/validate-monitoring.sh

**Checkpoint**: Runner metrics visible in Grafana, alerts configured for runner offline status

---

## Phase 5: User Story 3 - Scale Runners Based on Demand (Priority: P3)

**Goal**: Configure multiple runner replicas for concurrent workflow execution

**Independent Test**: Trigger multiple workflows simultaneously and verify parallel execution on different runners

### Implementation for User Story 3

- [x] T025 [US3] Update runner scale set configuration for multiple replicas in terraform/modules/github-actions-runner/main.tf
- [x] T026 [US3] Update variables with scaling defaults (minRunners=1, maxRunners=4) in terraform/modules/github-actions-runner/variables.tf
- [x] T027 [US3] Create script to test parallel workflow execution at scripts/github-actions-runner/test-parallel-workflows.sh
- [x] T028 [US3] Update outputs to include replica count and scaling status in terraform/modules/github-actions-runner/outputs.tf

**Checkpoint**: Multiple runners available, parallel workflows execute concurrently

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, security hardening, and final validation

- [x] T029 [P] Update module README with usage examples in terraform/modules/github-actions-runner/README.md
- [x] T030 [P] Add GitHub App setup instructions to specs/017-github-actions-runner/quickstart.md
- [x] T031 Run tofu validate and tofu fmt on all module files
- [ ] T032 Run full validation: scripts/github-actions-runner/validate-runner.sh
- [ ] T033 Verify monitoring: scripts/github-actions-runner/validate-monitoring.sh
- [ ] T034 Execute end-to-end test: scripts/github-actions-runner/test-workflow.sh

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - Core runner deployment
- **User Story 2 (Phase 4)**: Depends on User Story 1 - Monitoring requires running runner
- **User Story 3 (Phase 5)**: Depends on User Story 1 - Scaling requires basic runner working
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Depends on US1 completion - needs running runner to monitor
- **User Story 3 (P3)**: Depends on US1 completion - needs basic runner before scaling

### Within Each User Story

- OpenTofu variables before main resources
- Main resources before outputs
- Module before environment instantiation
- Deployment before validation scripts
- Validation before tests

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T002, T003, T004)
- Foundational tasks T006, T007 can run in parallel (different files)
- US2 tasks T019-T023 involve different files, some can be parallelized
- Polish tasks T029, T030 can run in parallel

---

## Parallel Example: Phase 1 Setup

```bash
# Launch all parallel setup tasks together:
Task: "Create Kubernetes manifests directory at kubernetes/github-actions-runner/"
Task: "Create validation scripts directory at scripts/github-actions-runner/"
Task: "Create module README documentation at terraform/modules/github-actions-runner/README.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - ARC controller must be running)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test workflow execution on self-hosted runner
5. Deploy/demo if ready - basic CI/CD on homelab is functional

### Incremental Delivery

1. Complete Setup + Foundational -> ARC controller ready
2. Add User Story 1 -> Test workflow execution -> Deploy/Demo (MVP!)
3. Add User Story 2 -> Verify monitoring dashboard -> Deploy/Demo
4. Add User Story 3 -> Test parallel execution -> Deploy/Demo
5. Each story adds value without breaking previous stories

### Suggested MVP Scope

**MVP = Phase 1 + Phase 2 + Phase 3 (User Story 1)**

This delivers:
- Functional self-hosted runner on homelab K3s
- Ability to run GitHub Actions workflows locally
- Basic validation of runner registration

US2 (monitoring) and US3 (scaling) are enhancements that can be added incrementally.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- GitHub App must be created manually before deployment (see quickstart.md)
- Runner token/credentials are sensitive - never commit to git
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
