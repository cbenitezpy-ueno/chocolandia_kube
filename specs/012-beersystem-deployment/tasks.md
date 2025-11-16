# Tasks: BeerSystem Cluster Deployment

**Input**: Design documents from `/specs/012-beersystem-deployment/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cloudflare-tunnel-spec.yaml, quickstart.md

**Tests**: Tests are NOT explicitly requested in the feature specification. Tasks focus on infrastructure provisioning and validation steps per quickstart.md.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This feature involves multiple repositories:
- **chocolandia_kube**: Infrastructure code (`terraform/`, `specs/`)
- **beersystem**: Application code and Kubernetes manifests (`/Users/cbenitez/beersystem/k8s/`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and directory structure

- [ ] T001 Create OpenTofu module directory structure at terraform/modules/postgresql-database/
- [ ] T002 Create environment directory for beersystem database at terraform/environments/chocolandiadc-mvp/beersystem-db/
- [ ] T003 Create Kubernetes manifests directory in beersystem repository at /Users/cbenitez/beersystem/k8s/
- [ ] T004 Verify Cloudflare Tunnel configuration directory exists at terraform/environments/chocolandiadc-mvp/cloudflare/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Verify existing infrastructure that MUST be operational before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Verify K3s cluster is operational using kubectl get nodes
- [ ] T006 Verify PostgreSQL cluster is operational using kubectl get pods -n postgres
- [ ] T007 Verify ArgoCD is operational using kubectl get pods -n argocd
- [ ] T008 Verify Cloudflare Tunnel is operational using kubectl get pods -n cloudflare-tunnel
- [ ] T009 Obtain PostgreSQL cluster admin credentials from feature 011 setup
- [ ] T010 Obtain Cloudflare Tunnel ID from feature 004 configuration at terraform/environments/chocolandiadc-mvp/cloudflare/

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 2 - Database Schema Management (Priority: P2) 🎯 PREREQUISITE

**Goal**: Provision PostgreSQL database "beersystem_stage" with admin user having DDL privileges so the application can manage its schema

**Independent Test**: Connect to database with beersystem_admin credentials and execute CREATE TABLE, ALTER TABLE, DROP TABLE statements successfully

**Note**: Implementing US2 before US1 because the database is a prerequisite for the application deployment

### Implementation for User Story 2

- [ ] T011 [P] [US2] Create OpenTofu module main.tf at terraform/modules/postgresql-database/main.tf with postgresql_database, postgresql_role, and postgresql_grant resources
- [ ] T012 [P] [US2] Create OpenTofu module variables.tf at terraform/modules/postgresql-database/variables.tf for database name, admin username, and admin password
- [ ] T013 [P] [US2] Create OpenTofu module outputs.tf at terraform/modules/postgresql-database/outputs.tf for connection string and credentials
- [ ] T014 [US2] Create environment main.tf at terraform/environments/chocolandiadc-mvp/beersystem-db/main.tf instantiating the postgresql-database module
- [ ] T015 [US2] Create environment variables file at terraform/environments/chocolandiadc-mvp/beersystem-db/terraform.tfvars with beersystem_stage configuration
- [ ] T016 [US2] Configure PostgreSQL provider in terraform/environments/chocolandiadc-mvp/beersystem-db/main.tf to connect to cluster from feature 011
- [ ] T017 [US2] Run tofu init in terraform/environments/chocolandiadc-mvp/beersystem-db/
- [ ] T018 [US2] Run tofu validate in terraform/environments/chocolandiadc-mvp/beersystem-db/
- [ ] T019 [US2] Run tofu plan in terraform/environments/chocolandiadc-mvp/beersystem-db/ and review planned changes
- [ ] T020 [US2] Run tofu apply in terraform/environments/chocolandiadc-mvp/beersystem-db/ to provision database
- [ ] T021 [US2] Test database connectivity using kubectl run with psql client connecting to postgres-rw.postgres.svc.cluster.local
- [ ] T022 [US2] Test DDL privileges by executing CREATE TABLE, INSERT, DROP TABLE in beersystem_stage database
- [ ] T023 [US2] Create Kubernetes Secret manifest template at /Users/cbenitez/beersystem/k8s/secret.yaml.template with DATABASE_URL placeholders
- [ ] T024 [US2] Generate actual Kubernetes Secret using database credentials from OpenTofu outputs (manual step, not committed)
- [ ] T025 [US2] Test database persistence (FR-007): Insert test data, restart PostgreSQL pod, verify data survives restart

**Checkpoint**: At this point, beersystem_stage database exists with admin user, persistence validated, and application can connect to it

---

## Phase 4: User Story 1 - Application Accessible via Domain (Priority: P1) 🎯 MVP

**Goal**: Deploy beersystem application to cluster and make it accessible at beer.chocolandiadc.com with TLS

**Independent Test**: Navigate to beer.chocolandiadc.com in browser and verify application loads with valid TLS certificate

### Container Image Preparation

- [ ] T026 [US1] Build Docker image for beersystem application using docker build -t cbenitez/beersystem:latest /Users/cbenitez/beersystem
- [ ] T027 [US1] Tag Docker image with version using docker tag cbenitez/beersystem:latest cbenitez/beersystem:v1.0.0
- [ ] T028 [US1] Push Docker image to Docker Hub using docker push cbenitez/beersystem:latest && docker push cbenitez/beersystem:v1.0.0

### Kubernetes Manifests Creation

- [ ] T029 [P] [US1] Create namespace manifest at /Users/cbenitez/beersystem/k8s/namespace.yaml for beersystem namespace
- [ ] T030 [P] [US1] Create ConfigMap manifest at /Users/cbenitez/beersystem/k8s/configmap.yaml for application configuration
- [ ] T031 [P] [US1] Create Deployment manifest at /Users/cbenitez/beersystem/k8s/deployment.yaml with health probes, resource limits, and security context
- [ ] T032 [P] [US1] Create Service manifest at /Users/cbenitez/beersystem/k8s/service.yaml as ClusterIP type on port 80 targeting port 8000
- [ ] T033 [US1] Verify Deployment manifest includes liveness probe (HTTP GET /health on port 8000, initialDelaySeconds: 30)
- [ ] T034 [US1] Verify Deployment manifest includes readiness probe (HTTP GET /health/ready on port 8000, initialDelaySeconds: 10)
- [ ] T035 [US1] Verify Deployment manifest includes resource requests (cpu: 100m, memory: 256Mi) and limits (cpu: 500m, memory: 512Mi)
- [ ] T036 [US1] Verify Deployment manifest references database Secret for DATABASE_URL environment variable

### Cloudflare Tunnel Configuration

- [ ] T037 [US1] Update cloudflare_tunnel_config resource in terraform/environments/chocolandiadc-mvp/cloudflare/main.tf to add beersystem ingress_rule
- [ ] T038 [US1] Create cloudflare_record resource for beer.chocolandiadc.com CNAME in terraform/environments/chocolandiadc-mvp/cloudflare/main.tf
- [ ] T039 [US1] Run tofu init in terraform/environments/chocolandiadc-mvp/cloudflare/
- [ ] T040 [US1] Run tofu plan in terraform/environments/chocolandiadc-mvp/cloudflare/ and review DNS and tunnel changes
- [ ] T041 [US1] Run tofu apply in terraform/environments/chocolandiadc-mvp/cloudflare/ to configure tunnel route
- [ ] T042 [US1] Verify DNS propagation using nslookup beer.chocolandiadc.com
- [ ] T043 [US1] Verify Cloudflare Tunnel configuration using kubectl logs -n cloudflare-tunnel -l app=cloudflared

### Application Deployment and Validation

- [ ] T044 [US1] Apply namespace manifest using kubectl apply -f /Users/cbenitez/beersystem/k8s/namespace.yaml
- [ ] T045 [US1] Apply Secret using kubectl apply -f /Users/cbenitez/beersystem/k8s/secret.yaml (from generated secret in T024)
- [ ] T046 [US1] Apply ConfigMap using kubectl apply -f /Users/cbenitez/beersystem/k8s/configmap.yaml
- [ ] T047 [US1] Apply Deployment using kubectl apply -f /Users/cbenitez/beersystem/k8s/deployment.yaml
- [ ] T048 [US1] Apply Service using kubectl apply -f /Users/cbenitez/beersystem/k8s/service.yaml
- [ ] T049 [US1] Verify pods are running using kubectl get pods -n beersystem
- [ ] T050 [US1] Verify Service endpoints using kubectl get endpoints beersystem-service -n beersystem
- [ ] T051 [US1] Check pod logs for startup errors using kubectl logs -n beersystem -l app=beersystem
- [ ] T052 [US1] Test internal connectivity using kubectl run curl-test with curl http://beersystem-service.beersystem.svc.cluster.local
- [ ] T053 [US1] Test external access by navigating to https://beer.chocolandiadc.com in browser
- [ ] T054 [US1] Verify TLS certificate is valid (issued by Cloudflare) in browser
- [ ] T055 [US1] Test application functionality through web interface

**Checkpoint**: At this point, User Story 1 should be fully functional - application accessible via beer.chocolandiadc.com with HTTPS

---

## Phase 5: User Story 3 - Automated GitOps Deployment (Priority: P3)

**Goal**: Configure ArgoCD to automatically synchronize application changes from beersystem git repository to cluster

**Independent Test**: Make a change to application manifests in git, commit, and verify ArgoCD detects and applies the change automatically

### ArgoCD Application Configuration

- [ ] T056 [US3] Create ArgoCD Application manifest at terraform/environments/chocolandiadc-mvp/argocd-apps/beersystem.yaml
- [ ] T057 [US3] Configure Application spec.source.repoURL to point to beersystem repository
- [ ] T058 [US3] Configure Application spec.source.path to k8s directory
- [ ] T059 [US3] Configure Application spec.destination.namespace to beersystem
- [ ] T060 [US3] Enable auto-sync with prune and selfHeal in spec.syncPolicy
- [ ] T061 [US3] Enable CreateNamespace=true in spec.syncPolicy.syncOptions
- [ ] T062 [US3] Apply ArgoCD Application using kubectl apply -f terraform/environments/chocolandiadc-mvp/argocd-apps/beersystem.yaml
- [ ] T063 [US3] Verify ArgoCD Application status using kubectl get application beersystem -n argocd
- [ ] T064 [US3] Access ArgoCD dashboard to view beersystem application sync status
- [ ] T065 [US3] Verify application shows as "Healthy" and "Synced" in ArgoCD dashboard

### GitOps Workflow Testing

- [ ] T066 [US3] Test auto-sync by updating ConfigMap in beersystem repository k8s/ directory
- [ ] T067 [US3] Commit and push ConfigMap change to beersystem repository
- [ ] T068 [US3] Monitor ArgoCD for automatic detection of change (check within 3 minutes)
- [ ] T069 [US3] Verify ArgoCD automatically applies the ConfigMap change to cluster
- [ ] T070 [US3] Verify application pods restart with new configuration
- [ ] T071 [US3] Test rollback by reverting git commit and verifying ArgoCD syncs previous state

**Checkpoint**: All user stories should now be independently functional - application is accessible, database is provisioned, and GitOps is automated

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and final validation

- [ ] T072 [P] Update feature branch status to "Complete" in specs/012-beersystem-deployment/spec.md
- [ ] T073 [P] Document database connection details in specs/012-beersystem-deployment/data-model.md outputs section
- [ ] T074 [P] Document Cloudflare Tunnel configuration in specs/012-beersystem-deployment/contracts/cloudflare-tunnel-spec.yaml
- [ ] T075 Verify all quickstart.md validation steps pass end-to-end
- [ ] T076 Clean up any temporary test resources (curl-test pods, psql-test pods)
- [ ] T077 Commit all OpenTofu changes in chocolandia_kube repository with message "feat: Add beersystem database and Cloudflare tunnel configuration"
- [ ] T078 Create git commit in beersystem repository with message "feat: Add Kubernetes manifests for cluster deployment"
- [ ] T079 Update chocolandia_kube CLAUDE.md with beersystem deployment technologies
- [ ] T080 Create README.md in /Users/cbenitez/beersystem/k8s/ documenting manifest structure
- [ ] T081 Run final smoke test: access beer.chocolandiadc.com, perform application operations, verify database persistence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 2 - Database (Phase 3)**: Depends on Foundational phase completion - BLOCKS User Story 1
- **User Story 1 - Domain Access (Phase 4)**: Depends on User Story 2 (database must exist for app deployment)
- **User Story 3 - GitOps (Phase 5)**: Depends on User Story 1 (application must be deployed before ArgoCD can sync it)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 2 (P2) - Database**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 1 (P1) - Domain Access**: Depends on User Story 2 (database provisioning) - Application needs database to function
- **User Story 3 (P3) - GitOps**: Depends on User Story 1 (application deployment) - ArgoCD syncs existing application

**Note**: Despite priority labels (P1, P2, P3), implementation order is US2 → US1 → US3 due to technical dependencies

### Within Each User Story

#### User Story 2 (Database):
- Module creation (T011-T013) can run in parallel [P]
- Module must exist before environment configuration (T014-T016)
- tofu init → validate → plan → apply must run sequentially (T017-T020)
- Testing (T021-T024) after database provisioned

#### User Story 1 (Domain Access):
- Container image tasks must run sequentially (T025-T027) - build before tag before push
- Kubernetes manifests (T028-T031) can be created in parallel [P]
- Manifest verification (T032-T035) after creation
- Cloudflare configuration must run sequentially (T036-T042)
- Deployment tasks must run after manifests created and Cloudflare configured (T043-T054)

#### User Story 3 (GitOps):
- ArgoCD Application configuration (T055-T061) sequential
- ArgoCD verification (T062-T064) after application created
- GitOps workflow testing (T065-T070) after ArgoCD verified

### Parallel Opportunities

#### Phase 1 (Setup):
- All directory creation tasks (T001-T004) can run in parallel

#### Phase 2 (Foundational):
- All verification tasks (T005-T010) can run in parallel - just reading state

#### User Story 2 (Database):
- Module files creation (T011-T013) can run in parallel [P]

#### User Story 1 (Domain Access):
- Kubernetes manifests creation (T028-T031) can run in parallel [P]

#### Phase 6 (Polish):
- Documentation updates (T071-T073) can run in parallel [P]

---

## Parallel Example: User Story 1 - Kubernetes Manifests

```bash
# Launch all Kubernetes manifest creation tasks together:
Task: "Create namespace manifest at /Users/cbenitez/beersystem/k8s/namespace.yaml"
Task: "Create ConfigMap manifest at /Users/cbenitez/beersystem/k8s/configmap.yaml"
Task: "Create Deployment manifest at /Users/cbenitez/beersystem/k8s/deployment.yaml"
Task: "Create Service manifest at /Users/cbenitez/beersystem/k8s/service.yaml"

# Then verify them sequentially (T032-T035) as they reference each other
```

---

## Implementation Strategy

### MVP First (User Story 2 + User Story 1)

1. Complete Phase 1: Setup (directory structure)
2. Complete Phase 2: Foundational (verify existing infrastructure - CRITICAL)
3. Complete Phase 3: User Story 2 (database provisioning - prerequisite)
4. Complete Phase 4: User Story 1 (application deployment and domain access)
5. **STOP and VALIDATE**: Test application at beer.chocolandiadc.com
6. Deploy/demo if ready

**Why this is MVP**: Users can access the application with database, which delivers core value. GitOps automation (US3) is enhancement for operational efficiency.

### Incremental Delivery

1. Complete Setup + Foundational → Infrastructure verified
2. Add User Story 2 (Database) → Test database connectivity → Database ready ✓
3. Add User Story 1 (Domain Access) → Test beer.chocolandiadc.com → Application accessible ✓ **(MVP!)**
4. Add User Story 3 (GitOps) → Test auto-sync → Automated deployments ✓
5. Each story adds value without breaking previous stories

### Sequential Team Strategy

For homelab/single developer:

1. Complete Setup + Foundational phases first
2. Implement User Story 2 (Database) completely before moving to US1
3. Implement User Story 1 (Domain Access) completely before moving to US3
4. Implement User Story 3 (GitOps) after US1 is stable
5. Test independently at each checkpoint

**Rationale**: Infrastructure deployment has natural sequential dependencies (database before app, app before GitOps). Parallel work not practical for single developer homelab environment.

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently testable at its checkpoint
- Implementation order differs from priority (US2→US1→US3) due to technical dependencies
- Database (US2) is prerequisite for application (US1)
- Application deployment (US1) is prerequisite for GitOps (US3)
- Commits should happen after logical groups: after database provisioning, after app deployment, after GitOps setup
- All OpenTofu changes use tofu (not terraform) per project configuration
- No tests tasks included - validation steps are manual verification per quickstart.md
- Security: Database credentials stored in Kubernetes Secret, never committed to git
- Avoid: Committing database passwords, skipping validation steps, deploying without health checks
