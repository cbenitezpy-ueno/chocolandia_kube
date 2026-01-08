# Tasks: Jenkins CI Deployment

**Input**: Design documents from `/specs/029-jenkins-ci/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Manual validation via smoke tests and build job execution (no automated test framework)

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Terraform module**: `terraform/modules/jenkins/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`
- **Scripts**: `scripts/jenkins/`

---

## Phase 1: Setup (Module Structure)

**Purpose**: Create Jenkins OpenTofu module structure

- [x] T001 Create module directory structure at terraform/modules/jenkins/
- [x] T002 [P] Create module variables in terraform/modules/jenkins/variables.tf
- [x] T003 [P] Create module outputs in terraform/modules/jenkins/outputs.tf
- [x] T004 Create values directory at terraform/modules/jenkins/values/

**Checkpoint**: Module structure ready for implementation

---

## Phase 2: Foundational (Core Jenkins Deployment)

**Purpose**: Core infrastructure that MUST be complete before user stories can be validated

**⚠️ CRITICAL**: No user story validation can begin until Jenkins is deployed and accessible

- [x] T005 Create namespace and PVC resources in terraform/modules/jenkins/main.tf
- [x] T006 Create Kubernetes secrets for admin password and Nexus credentials in terraform/modules/jenkins/main.tf
- [x] T007 Create Helm values template with JCasC base configuration in terraform/modules/jenkins/values/jenkins.yaml
- [x] T007a [P] Configure resource limits (CPU/memory) for Jenkins controller (500m-2000m, 1Gi-2Gi) and DinD sidecar (200m-1000m, 512Mi-1Gi) in terraform/modules/jenkins/values/jenkins.yaml
- [x] T008 Create Helm release resource with DinD sidecar in terraform/modules/jenkins/main.tf
- [x] T009 [P] Create Traefik IngressRoutes (HTTP redirect + HTTPS) in terraform/modules/jenkins/ingress.tf
- [x] T010 [P] Create cert-manager Certificate for jenkins.chocolandiadc.local in terraform/modules/jenkins/ingress.tf
- [x] T011 Create module instantiation in terraform/environments/chocolandiadc-mvp/jenkins.tf
- [x] T012 Add Jenkins variables to terraform/environments/chocolandiadc-mvp/terraform.tfvars
- [x] T013 Run tofu validate and tofu plan to verify configuration
- [x] T014 Apply Jenkins deployment with tofu apply -target=module.jenkins

**Checkpoint**: Jenkins deployed and accessible at https://jenkins.chocolandiadc.local

---

## Phase 3: User Story 1 - Build and Push Docker Image (Priority: P1) 🎯 MVP

**Goal**: Enable building Docker images and pushing to Nexus registry

**Independent Test**: Create test pipeline job, build simple Dockerfile, verify image in Nexus docker-hosted repository

### Implementation for User Story 1

- [ ] T015 [US1] Configure Docker plugins (docker-workflow, docker-commons) and ntfy plugin in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T016 [US1] Configure DinD sidecar with correct Docker socket mount in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T017 [US1] Add Nexus docker registry credentials to JCasC in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T018 [US1] Apply configuration changes with tofu apply -target=module.jenkins
- [ ] T019 [US1] Create test pipeline job in Jenkins UI to validate Docker build/push to Nexus
- [ ] T020 [US1] Verify image appears in Nexus at docker.nexus.chocolandiadc.local

**Checkpoint**: User Story 1 complete - Can build and push Docker images to Nexus

---

## Phase 4: User Story 2 - Java/Maven Project Build (Priority: P2)

**Goal**: Enable Java/Maven project compilation and testing before Docker build

**Independent Test**: Create Maven project pipeline, verify compilation and test execution

### Implementation for User Story 2

- [ ] T021 [P] [US2] Configure Maven plugin and JDK tool installations in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T022 [US2] Add Maven tool configuration (versions 3.9.x) to JCasC in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T023 [US2] Add JDK tool configuration (versions 17, 21) to JCasC in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T024 [US2] Apply configuration changes with tofu apply -target=module.jenkins
- [ ] T025 [US2] Create test Maven pipeline job in Jenkins UI to validate build/test cycle

**Checkpoint**: User Story 2 complete - Can build Java/Maven projects

---

## Phase 5: User Story 3 - Node.js Project Build (Priority: P2)

**Goal**: Enable Node.js project dependency installation and testing

**Independent Test**: Create Node.js project pipeline, verify npm install and test execution

### Implementation for User Story 3

- [ ] T026 [P] [US3] Configure NodeJS plugin in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T027 [US3] Add NodeJS tool configuration (versions 18, 20 LTS) to JCasC in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T028 [US3] Apply configuration changes with tofu apply -target=module.jenkins
- [ ] T029 [US3] Create test Node.js pipeline job in Jenkins UI to validate npm install/test cycle

**Checkpoint**: User Story 3 complete - Can build Node.js projects

---

## Phase 6: User Story 4 - Python Project Build (Priority: P2)

**Goal**: Enable Python project virtual environment setup and testing

**Independent Test**: Create Python project pipeline, verify pip install and pytest execution

### Implementation for User Story 4

- [ ] T030 [P] [US4] Configure pyenv-pipeline plugin in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T031 [US4] Apply configuration changes with tofu apply -target=module.jenkins
- [ ] T032 [US4] Create test Python pipeline job in Jenkins UI to validate venv/pip/pytest cycle

**Checkpoint**: User Story 4 complete - Can build Python projects

---

## Phase 7: User Story 5 - Go Project Build (Priority: P2)

**Goal**: Enable Go project compilation and testing

**Independent Test**: Create Go project pipeline, verify go build and go test execution

### Implementation for User Story 5

- [ ] T033 [P] [US5] Configure Go plugin in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T034 [US5] Add Go tool configuration (versions 1.21, 1.22) to JCasC in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T035 [US5] Apply configuration changes with tofu apply -target=module.jenkins
- [ ] T036 [US5] Create test Go pipeline job in Jenkins UI to validate go build/test cycle

**Checkpoint**: User Story 5 complete - Can build Go projects

---

## Phase 8: User Story 6 - Access Jenkins Web UI (Priority: P3)

**Goal**: Enable secure web access via LAN and Cloudflare Zero Trust

**Independent Test**: Access Jenkins at both URLs, login with admin credentials

### Implementation for User Story 6

- [ ] T037 [P] [US6] Add Cloudflare tunnel ingress rule for jenkins.chocolandiadc.com in terraform/environments/chocolandiadc-mvp/cloudflare-tunnel.tf
- [ ] T038 [P] [US6] Add Cloudflare Access application for Jenkins in terraform/environments/chocolandiadc-mvp/cloudflare-tunnel.tf
- [ ] T039 [US6] Apply Cloudflare configuration with tofu apply -target=module.cloudflare_tunnel
- [ ] T040 [US6] Verify LAN access at https://jenkins.chocolandiadc.local
- [ ] T041 [US6] Verify public access at https://jenkins.chocolandiadc.com (via Cloudflare Zero Trust)

**Checkpoint**: User Story 6 complete - Jenkins accessible via LAN and public URLs

---

## Phase 9: Monitoring & Notifications

**Purpose**: Integrate Jenkins with observability stack

- [ ] T042 [P] Create ServiceMonitor for Prometheus in terraform/modules/jenkins/monitoring.tf
- [ ] T043 [P] Create PrometheusRule for Jenkins alerts in terraform/modules/jenkins/monitoring.tf
- [ ] T044 [P] Create Grafana dashboard ConfigMap in terraform/modules/jenkins/monitoring.tf
- [ ] T045 Configure ntfy notification plugin in JCasC in terraform/modules/jenkins/values/jenkins.yaml
- [ ] T046 Apply monitoring configuration with tofu apply -target=module.jenkins
- [ ] T047 Verify Prometheus is scraping Jenkins metrics
- [ ] T048 Verify Grafana dashboard shows Jenkins data
- [ ] T049 Verify ntfy notification on test build failure

**Checkpoint**: Monitoring integration complete

---

## Phase 10: Polish & Documentation

**Purpose**: Final documentation and validation

- [ ] T050 [P] Create validation script at scripts/jenkins/validate-jenkins.sh
- [ ] T051 [P] Update CLAUDE.md with Jenkins section (URLs, credentials, usage)
- [ ] T052 [P] Create README.md for Jenkins module at terraform/modules/jenkins/README.md
- [ ] T053 Run full validation using quickstart.md scenarios
- [ ] T054 Commit all changes with descriptive message

**Checkpoint**: Feature complete and documented

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - can start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all user stories
- **Phases 3-8 (User Stories)**: All depend on Phase 2 completion
  - User Stories 2-5 (P2) can proceed in parallel after US1
  - US6 can proceed in parallel with US2-5
- **Phase 9 (Monitoring)**: Can start after Phase 2, parallel with user stories
- **Phase 10 (Polish)**: Depends on all phases complete

### User Story Dependencies

| Story | Depends On | Can Parallelize With |
|-------|------------|---------------------|
| US1 (P1) | Phase 2 | None (MVP baseline) |
| US2 (P2) | US1 | US3, US4, US5, US6 |
| US3 (P2) | US1 | US2, US4, US5, US6 |
| US4 (P2) | US1 | US2, US3, US5, US6 |
| US5 (P2) | US1 | US2, US3, US4, US6 |
| US6 (P3) | Phase 2 | US2, US3, US4, US5 |

### Parallel Opportunities

**Phase 1** (all parallel):
```
T002 (variables.tf) || T003 (outputs.tf)
```

**Phase 2** (partial parallel):
```
T009 (ingress.tf) || T010 (certificate)
```

**Phases 4-7** (all stories parallel after US1):
```
US2 || US3 || US4 || US5
```

**Phase 9** (all parallel):
```
T042 (ServiceMonitor) || T043 (PrometheusRule) || T044 (Dashboard)
```

**Phase 10** (all parallel):
```
T050 (validate script) || T051 (CLAUDE.md) || T052 (README.md)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (4 tasks)
2. Complete Phase 2: Foundational (11 tasks)
3. Complete Phase 3: User Story 1 (6 tasks)
4. **STOP and VALIDATE**: Test Docker build/push to Nexus
5. Deploy/demo if ready - **MVP delivered with 21 tasks**

### Incremental Delivery

1. MVP: Setup + Foundational + US1 → Docker builds work
2. Add US2 → Java/Maven builds work
3. Add US3 → Node.js builds work
4. Add US4 → Python builds work
5. Add US5 → Go builds work
6. Add US6 → Public access via Cloudflare
7. Add Monitoring → Prometheus/Grafana integration
8. Polish → Documentation complete

### Total Task Count

| Phase | Task Count | Cumulative |
|-------|------------|------------|
| Phase 1 (Setup) | 4 | 4 |
| Phase 2 (Foundational) | 11 | 15 |
| Phase 3 (US1 - MVP) | 6 | 21 |
| Phase 4 (US2 - Java) | 5 | 26 |
| Phase 5 (US3 - Node) | 4 | 30 |
| Phase 6 (US4 - Python) | 3 | 33 |
| Phase 7 (US5 - Go) | 4 | 37 |
| Phase 8 (US6 - Access) | 5 | 42 |
| Phase 9 (Monitoring) | 8 | 50 |
| Phase 10 (Polish) | 5 | 55 |
| **Total** | **55** | |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Commit after each phase or logical group
- Stop at any checkpoint to validate independently
- MVP scope: 21 tasks (Phases 1-3)
