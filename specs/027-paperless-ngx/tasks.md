# Tasks: Paperless-ngx Document Management

**Input**: Design documents from `/specs/027-paperless-ngx/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Infrastructure validation via `tofu validate` and `tofu plan` - no unit tests required for IaC.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Infrastructure deployment using OpenTofu modules:
- **Modules**: `terraform/modules/<module-name>/`
- **Environment**: `terraform/environments/chocolandiadc-mvp/`

---

## Phase 1: Setup (Module Structure)

**Purpose**: Create OpenTofu module directory structure and base files

- [x] T001 Create paperless-ngx module directory at terraform/modules/paperless-ngx/
- [x] T002 [P] Create variables.tf with all input variables per contracts in terraform/modules/paperless-ngx/variables.tf
- [x] T003 [P] Create outputs.tf with module outputs per contracts in terraform/modules/paperless-ngx/outputs.tf
- [x] T003b [P] Create README.md with module documentation in terraform/modules/paperless-ngx/README.md

---

## Phase 2: Foundational (Core Infrastructure)

**Purpose**: Database, namespace, secrets, and storage - MUST complete before user story implementation

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create paperless.tf with random_password resources for secrets in terraform/environments/chocolandiadc-mvp/paperless.tf
- [x] T005 Add paperless_database module instantiation using postgresql-database in terraform/environments/chocolandiadc-mvp/paperless.tf
- [x] T006 Create main.tf with kubernetes_namespace resource in terraform/modules/paperless-ngx/main.tf
- [x] T007 [P] Add kubernetes_secret for paperless-credentials in terraform/modules/paperless-ngx/main.tf
- [x] T008 [P] Add kubernetes_secret for samba-credentials in terraform/modules/paperless-ngx/main.tf
- [x] T009 [P] Add kubernetes_persistent_volume_claim for paperless-data (5Gi) in terraform/modules/paperless-ngx/main.tf
- [x] T010 [P] Add kubernetes_persistent_volume_claim for paperless-media (40Gi) in terraform/modules/paperless-ngx/main.tf
- [x] T011 [P] Add kubernetes_persistent_volume_claim for paperless-consume (5Gi) in terraform/modules/paperless-ngx/main.tf
- [x] T012 Run tofu init and tofu validate to verify module structure

**Checkpoint**: Foundation ready - namespace, secrets, and PVCs defined

---

## Phase 3: User Story 1+4 - Internet/LAN Access with HTTPS (Priority: P1/P4)

**Goal**: Deploy Paperless-ngx accessible via Cloudflare (paperless.chocolandiadc.com) and LAN (paperless.chocolandiadc.local) with valid HTTPS certificates

**Independent Test**: Access https://paperless.chocolandiadc.com from mobile data and verify login page loads; access https://paperless.chocolandiadc.local from LAN and verify TLS certificate is valid

### Implementation for User Story 1+4

- [x] T013 [US1] Add kubernetes_deployment for paperless-ngx with Samba sidecar (including Redis env vars, health probes, resource limits) in terraform/modules/paperless-ngx/main.tf
- [x] T013b [US1] Configure liveness/readiness probes for paperless-ngx container (httpGet /api/, initialDelaySeconds: 30) in terraform/modules/paperless-ngx/main.tf
- [x] T013c [US1] Configure resource requests/limits for paperless-ngx (512Mi-2Gi RAM, 250m-2000m CPU) and samba (64Mi-256Mi RAM, 50m-200m CPU) in terraform/modules/paperless-ngx/main.tf
- [x] T014 [US1] Add kubernetes_service for paperless-ngx (ClusterIP port 8000) in terraform/modules/paperless-ngx/main.tf
- [x] T015 [US1] Create ingress.tf with Traefik IngressRoute for .local domain in terraform/modules/paperless-ngx/ingress.tf
- [x] T016 [US1] Add kubernetes_manifest for Certificate (local-ca issuer) in terraform/modules/paperless-ngx/ingress.tf
- [x] T017 [US1] Create cloudflare.tf for Cloudflare tunnel ingress rule in terraform/modules/paperless-ngx/cloudflare.tf
- [x] T018 [US1] Update Cloudflare tunnel ingress_rules in terraform/environments/chocolandiadc-mvp/cloudflare.tf to add paperless hostname
- [x] T019 [US1] Add module instantiation for paperless_ngx in terraform/environments/chocolandiadc-mvp/paperless.tf
- [x] T020 [US1] Run tofu plan to verify Cloudflare and ingress configuration
- [x] T021 [US1] Run tofu apply to deploy Paperless-ngx with ingress

**Checkpoint**: Paperless-ngx accessible via internet (Cloudflare) and LAN (.local) with HTTPS

---

## Phase 4: User Story 2+5 - Document Upload and Scanner Integration (Priority: P2)

**Goal**: Enable document upload via web UI and scanner integration via Samba share, with OCR processing

**Independent Test**: Upload a PDF via web UI and verify it appears with searchable text; configure scanner to save to SMB share and verify document is processed

### Implementation for User Story 2+5

- [x] T022 [US2] Configure PAPERLESS_OCR_LANGUAGE environment variable (spa+eng) in terraform/modules/paperless-ngx/main.tf
- [x] T023 [US2] Configure PAPERLESS_CONSUMPTION_DIR environment variable in terraform/modules/paperless-ngx/main.tf
- [x] T024 [US5] Add kubernetes_service for samba (LoadBalancer port 445) in terraform/modules/paperless-ngx/main.tf
- [x] T025 [US5] Configure Samba sidecar with share pointing to consume PVC in terraform/modules/paperless-ngx/main.tf
- [x] T026 [US5] Add samba_endpoint output for scanner configuration in terraform/modules/paperless-ngx/outputs.tf
- [x] T027 [US2] Run tofu apply to update deployment with scanner integration
- [x] T028 [US2] Verify OCR processing by uploading test document via web UI
- [x] T029 [US5] Test SMB connectivity from LAN device to LoadBalancer IP

**Checkpoint**: Documents can be uploaded via web UI and scanner, OCR processing works

---

## Phase 5: User Story 3 - Grafana Monitoring (Priority: P3)

**Goal**: Monitor Paperless-ngx health metrics in Grafana dashboard

**Independent Test**: Open Grafana, navigate to Paperless-ngx dashboard, verify metrics are displayed

### Implementation for User Story 3

- [x] T030 [US3] Configure PAPERLESS_ENABLE_METRICS=true environment variable in terraform/modules/paperless-ngx/main.tf
- [x] T031 [US3] Add kubernetes_manifest for ServiceMonitor in terraform/modules/paperless-ngx/main.tf
- [x] T032 [US3] Create Grafana dashboard JSON ConfigMap for Paperless-ngx in terraform/modules/paperless-ngx/main.tf
- [x] T033 [US3] Add prometheus.io annotations to pod template in terraform/modules/paperless-ngx/main.tf
- [x] T034 [US3] Run tofu apply to deploy monitoring configuration
- [x] T035 [US3] Verify metrics endpoint accessible at /metrics
- [x] T036 [US3] Verify Grafana dashboard shows Paperless-ngx metrics
- [x] T036b [US3] Add PrometheusRule for paperless_up alert (fires if service down >5min) in terraform/modules/paperless-ngx/main.tf

**Checkpoint**: Paperless-ngx metrics visible in Grafana, ServiceMonitor scraping correctly

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validation, documentation, and cleanup

- [x] T037 [P] Add Homepage widget configuration for Paperless-ngx in terraform/environments/chocolandiadc-mvp/homepage.tf
- [x] T038 [P] Update CLAUDE.md with Paperless-ngx service documentation
- [x] T039 Run full tofu plan to verify complete configuration
- [x] T040 Run quickstart.md validation steps to verify deployment
- [ ] T041 Commit all changes with feature branch 027-paperless-ngx
- [ ] T042 Create PR for review

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1+4 (Phase 3)**: Depends on Foundational phase completion
- **User Story 2+5 (Phase 4)**: Depends on Phase 3 (needs deployment running)
- **User Story 3 (Phase 5)**: Depends on Phase 3 (needs deployment running)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1+4 (P1/P4)**: Can start after Foundational (Phase 2) - Base deployment + ingress
- **User Story 2+5 (P2)**: Depends on US1 completion (needs running deployment)
- **User Story 3 (P3)**: Depends on US1 completion (needs running deployment)

### Within Each User Story

- Module files before environment files
- Infrastructure resources before application deployment
- Deployment before ingress/services
- Apply before validation tests

### Parallel Opportunities

**Phase 1 (Setup)**:
```
T002 (variables.tf) || T003 (outputs.tf)
```

**Phase 2 (Foundational)**:
```
T007 (paperless-secret) || T008 (samba-secret) || T009 (data-pvc) || T010 (media-pvc) || T011 (consume-pvc)
```

**Phase 5 (US3) and Phase 4 (US2+5)** can potentially run in parallel after Phase 3 completes.

**Phase 6 (Polish)**:
```
T037 (Homepage) || T038 (CLAUDE.md)
```

---

## Parallel Example: Foundational Phase

```bash
# Launch all PVC tasks together (different resources, no dependencies):
Task: "Add kubernetes_persistent_volume_claim for paperless-data (5Gi) in terraform/modules/paperless-ngx/main.tf"
Task: "Add kubernetes_persistent_volume_claim for paperless-media (40Gi) in terraform/modules/paperless-ngx/main.tf"
Task: "Add kubernetes_persistent_volume_claim for paperless-consume (5Gi) in terraform/modules/paperless-ngx/main.tf"

# Launch all secret tasks together:
Task: "Add kubernetes_secret for paperless-credentials in terraform/modules/paperless-ngx/main.tf"
Task: "Add kubernetes_secret for samba-credentials in terraform/modules/paperless-ngx/main.tf"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1+4 (Internet/LAN Access)
4. **STOP and VALIDATE**: Test access from internet and LAN
5. Deploy if ready - Paperless-ngx is accessible!

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1+4 → Test access → Deploy (MVP!)
3. Add User Story 2+5 → Test upload/scanner → Deploy
4. Add User Story 3 → Test monitoring → Deploy
5. Each story adds value without breaking previous stories

### Recommended Execution Order

For a single developer:
1. T001-T003 (Setup)
2. T004-T012 (Foundational) - use parallel where marked
3. T013-T021 (US1+4) - deploy and validate
4. T022-T029 (US2+5) - scanner integration
5. T030-T036 (US3) - monitoring
6. T037-T042 (Polish)

---

## Notes

- [P] tasks = different files or resources, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Run `tofu validate` after each module file change
- Run `tofu plan` before any `tofu apply`
- Commit after each phase completion
- Stop at any checkpoint to validate functionality
- MetalLB LoadBalancer IP will be auto-assigned from pool 192.168.4.200-210 for Samba service
