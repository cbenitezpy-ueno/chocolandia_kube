# Tasks: Longhorn and MinIO Storage Infrastructure

**Input**: Design documents from `/specs/001-longhorn-minio/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Validation tests are explicitly requested per Constitution Principle VII (Test-Driven Learning). Each user story includes validation tasks.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Terraform modules**: `terraform/modules/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`
- **Validation scripts**: `scripts/storage/`
- All paths relative to repository root: `/Users/cbenitez/chocolandia_kube/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure for Longhorn and MinIO modules

- [X] T001 Create Longhorn module directory structure in terraform/modules/longhorn/
- [X] T002 Create MinIO module directory structure in terraform/modules/minio/
- [X] T003 [P] Create validation scripts directory in scripts/storage/
- [X] T004 [P] Verify K3s cluster is running with 4 nodes (master1, nodo03, nodo1, nodo04)
- [X] T005 [P] Verify USB disk is mounted at /media/usb on master1 with 931GB capacity and writable by root (Longhorn will use /media/usb/longhorn-storage subdirectory)
- [X] T006 [P] Verify existing infrastructure dependencies (Traefik, cert-manager, Cloudflare Access)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T007 Configure OpenTofu providers (Helm, Kubernetes, Cloudflare) in terraform/environments/chocolandiadc-mvp/providers.tf
- [X] T008 [P] Define common variables for domains in terraform/environments/chocolandiadc-mvp/variables.tf (longhorn.chocolandiadc.com, minio.chocolandiadc.com, s3.chocolandiadc.com)
- [X] T009 [P] Configure Helm repository for Longhorn chart in terraform/modules/longhorn/main.tf
- [X] T010 [P] Verify Cloudflare API token and authorized emails environment variables are set
- [X] T011 Initialize OpenTofu in terraform/environments/chocolandiadc-mvp/ with `tofu init`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Distributed Storage with Longhorn (Priority: P1) 🎯 MVP

**Goal**: Deploy Longhorn distributed block storage across K3s cluster with 2-replica volumes using USB disk on master1

**Independent Test**: Create a PVC, deploy a test pod with data, verify data persists after pod restart and survives node failure simulation

### Implementation for User Story 1

- [X] T012 [P] [US1] Create Longhorn module variables.tf defining replica_count, usb_disk_path, storage_class_name in terraform/modules/longhorn/variables.tf
- [X] T013 [P] [US1] Create Longhorn Helm release configuration in terraform/modules/longhorn/main.tf with namespace=longhorn-system, replica_count=2
- [X] T014 [US1] Configure Longhorn default disk path for master1 (/media/usb/longhorn-storage) in terraform/modules/longhorn/main.tf Helm values
- [X] T015 [US1] Configure Longhorn node scheduling (all 4 nodes participate) in terraform/modules/longhorn/main.tf Helm values
- [X] T016 [US1] Configure Longhorn StorageClass with provisioner=driver.longhorn.io, allowVolumeExpansion=true in terraform/modules/longhorn/main.tf
- [X] T017 [P] [US1] Create Longhorn module outputs.tf exposing storageclass_name, ui_url, metrics_endpoint in terraform/modules/longhorn/outputs.tf
- [X] T018 [US1] Instantiate Longhorn module in terraform/environments/chocolandiadc-mvp/longhorn.tf
- [X] T019 [US1] Run `tofu plan` and verify Longhorn resources to be created
- [X] T020 [US1] Apply Longhorn deployment with `tofu apply -target=module.longhorn`
- [X] T021 [US1] Wait for Longhorn pods to be Ready in longhorn-system namespace (kubectl wait)

### Validation for User Story 1

- [X] T022 [US1] Create validation script scripts/storage/validate-longhorn.sh to verify Longhorn deployment
- [X] T023 [US1] Verify all 4 nodes appear as Longhorn storage nodes with disk capacity (kubectl get nodes.longhorn.io)
- [X] T024 [US1] Create test PVC requesting Longhorn storage (1Gi, StorageClass=longhorn)
- [X] T025 [US1] Verify test PVC is bound and volume provisioned with 2 replicas across nodes
- [X] T026 [US1] Deploy test pod using test PVC, write test data to volume
- [X] T027 [US1] Delete and recreate test pod, verify data persists
- [X] T028 [US1] Simulate node failure (cordon node with replica), verify volume remains accessible
- [X] T029 [US1] Cleanup test PVC and pod

**Checkpoint**: At this point, Longhorn distributed storage should be fully functional with 2-replica volumes, independently testable via PVC provisioning and data persistence

---

## Phase 4: User Story 2 - Longhorn Web UI Access (Priority: P2)

**Goal**: Expose Longhorn web UI at https://longhorn.chocolandiadc.com with Cloudflare Access authentication and cert-manager TLS

**Independent Test**: Navigate to https://longhorn.chocolandiadc.com, authenticate via Cloudflare Access, view volumes/nodes/snapshots in UI

### Implementation for User Story 2

- [X] T030 [P] [US2] Create Cloudflare DNS A record for longhorn.chocolandiadc.com pointing to Traefik LoadBalancer IP in terraform/modules/longhorn/cloudflare.tf
- [X] T031 [P] [US2] Create Cloudflare Access application for longhorn.chocolandiadc.com with email-based policy in terraform/modules/longhorn/cloudflare.tf
- [X] T032 [P] [US2] Create Traefik IngressRoute for Longhorn UI with TLS via cert-manager in terraform/modules/longhorn/ingress.tf
- [X] T033 [US2] Configure cert-manager Certificate resource for longhorn.chocolandiadc.com using letsencrypt-production ClusterIssuer in terraform/modules/longhorn/ingress.tf
- [X] T034 [US2] Update Longhorn module to include ingress and Cloudflare resources in terraform/modules/longhorn/main.tf
- [X] T035 [US2] Run `tofu plan` and verify Ingress and Cloudflare resources to be created
- [X] T036 [US2] Apply Longhorn UI ingress with `tofu apply -target=module.longhorn`
- [X] T037 [US2] Wait for TLS certificate to be issued (kubectl wait for Certificate ready)

### Validation for User Story 2

- [X] T038 [US2] Verify DNS resolution for longhorn.chocolandiadc.com resolves to Traefik IP
- [X] T039 [US2] Access https://longhorn.chocolandiadc.com and verify redirect to Cloudflare Access login
- [X] T040 [US2] Authenticate with authorized Google account via Cloudflare Access
- [X] T041 [US2] Verify Longhorn UI dashboard loads showing volumes, nodes, and disk usage
- [X] T042 [US2] Create manual snapshot of test volume via Longhorn UI, verify snapshot appears in list
- [X] T043 [US2] Verify TLS certificate is valid (issued by Let's Encrypt)

**Checkpoint**: At this point, Longhorn UI should be accessible via HTTPS with Cloudflare Access authentication, independently testable via browser access

---

## Phase 5: User Story 3 - Object Storage with MinIO (Priority: P1) 🎯 MVP

**Goal**: Deploy MinIO S3-compatible object storage in single-server mode with 100Gi Longhorn volume, expose S3 API at s3.chocolandiadc.com

**Independent Test**: Deploy MinIO, create bucket via S3 API, upload/download object using AWS CLI, verify data persists after pod restart

### Implementation for User Story 3

- [ ] T044 [P] [US3] Create MinIO module variables.tf defining storage_size, s3_domain, console_domain in terraform/modules/minio/variables.tf
- [ ] T045 [P] [US3] Create MinIO Deployment YAML (1 replica, single-server mode) in terraform/modules/minio/main.tf
- [ ] T046 [US3] Create MinIO PersistentVolumeClaim (100Gi, StorageClass=longhorn) in terraform/modules/minio/main.tf
- [ ] T047 [US3] Generate MinIO access key and secret key credentials using random provider in terraform/modules/minio/main.tf
- [ ] T048 [US3] Create Kubernetes Secret for MinIO credentials (minio-credentials) in terraform/modules/minio/main.tf
- [ ] T049 [US3] Create MinIO Service (ClusterIP) exposing ports 9000 (S3 API) and 9001 (Console) in terraform/modules/minio/main.tf
- [ ] T050 [P] [US3] Create MinIO module outputs.tf exposing s3_endpoint, console_url, access_key (sensitive), secret_key (sensitive) in terraform/modules/minio/outputs.tf
- [ ] T051 [US3] Instantiate MinIO module in terraform/environments/chocolandiadc-mvp/minio.tf
- [ ] T052 [US3] Run `tofu plan` and verify MinIO resources to be created
- [ ] T053 [US3] Apply MinIO deployment with `tofu apply -target=module.minio`
- [ ] T054 [US3] Wait for MinIO pod to be Ready and PVC bound (kubectl wait)

### Validation for User Story 3

- [ ] T055 [US3] Create validation script scripts/storage/validate-minio.sh to verify MinIO deployment
- [ ] T056 [US3] Verify MinIO PVC is bound with 100Gi capacity on Longhorn volume
- [ ] T057 [US3] Verify Longhorn created volume for MinIO with 2 replicas
- [ ] T058 [US3] Retrieve MinIO access key and secret key from Kubernetes Secret
- [ ] T059 [US3] Configure AWS CLI with MinIO credentials and endpoint https://s3.chocolandiadc.com
- [ ] T060 [US3] Create test bucket via S3 API (aws s3 mb s3://test-bucket)
- [ ] T061 [US3] Upload test object to bucket (aws s3 cp test.txt s3://test-bucket/)
- [ ] T062 [US3] Download test object and verify content matches
- [ ] T063 [US3] Restart MinIO pod, verify buckets and objects remain accessible
- [ ] T064 [US3] Cleanup test bucket and object

**Checkpoint**: At this point, MinIO S3 API should be fully functional with persistent storage on Longhorn, independently testable via S3 CLI operations

---

## Phase 6: User Story 4 - MinIO Web Console Access (Priority: P2)

**Goal**: Expose MinIO Console at https://minio.chocolandiadc.com and S3 API at https://s3.chocolandiadc.com with Cloudflare Access authentication and cert-manager TLS

**Independent Test**: Navigate to https://minio.chocolandiadc.com, authenticate via Cloudflare Access, create bucket via UI, view storage usage

### Implementation for User Story 4

- [ ] T065 [P] [US4] Create Cloudflare DNS A record for minio.chocolandiadc.com pointing to Traefik LoadBalancer IP in terraform/modules/minio/cloudflare.tf
- [ ] T066 [P] [US4] Create Cloudflare DNS A record for s3.chocolandiadc.com pointing to Traefik LoadBalancer IP in terraform/modules/minio/cloudflare.tf
- [ ] T067 [P] [US4] Create Cloudflare Access application for minio.chocolandiadc.com (Console) with email-based policy in terraform/modules/minio/cloudflare.tf
- [ ] T068 [P] [US4] Configure s3.chocolandiadc.com DNS record WITHOUT Cloudflare Access (S3 API uses MinIO credentials only, not OAuth) in terraform/modules/minio/cloudflare.tf
- [ ] T069 [P] [US4] Create Traefik IngressRoute for MinIO Console (port 9001) with TLS in terraform/modules/minio/ingress.tf
- [ ] T070 [P] [US4] Create Traefik IngressRoute for MinIO S3 API (port 9000) with TLS in terraform/modules/minio/ingress.tf
- [ ] T071 [US4] Configure cert-manager Certificate for minio.chocolandiadc.com using letsencrypt-production ClusterIssuer in terraform/modules/minio/ingress.tf
- [ ] T072 [US4] Configure cert-manager Certificate for s3.chocolandiadc.com using letsencrypt-production ClusterIssuer in terraform/modules/minio/ingress.tf
- [ ] T073 [US4] Update MinIO module to include ingress and Cloudflare resources in terraform/modules/minio/main.tf
- [ ] T074 [US4] Run `tofu plan` and verify MinIO Ingress and Cloudflare resources to be created
- [ ] T075 [US4] Apply MinIO ingress with `tofu apply -target=module.minio`
- [ ] T076 [US4] Wait for TLS certificates to be issued (kubectl wait for Certificates ready)

### Validation for User Story 4

- [ ] T077 [US4] Verify DNS resolution for minio.chocolandiadc.com and s3.chocolandiadc.com resolve to Traefik IP
- [ ] T078 [US4] Access https://minio.chocolandiadc.com and verify redirect to Cloudflare Access login
- [ ] T079 [US4] Authenticate with authorized Google account via Cloudflare Access
- [ ] T080 [US4] Login to MinIO Console with access key and secret key
- [ ] T081 [US4] Verify MinIO Console dashboard loads showing buckets and storage usage
- [ ] T082 [US4] Create test bucket via MinIO Console UI
- [ ] T083 [US4] Upload test file via MinIO Console UI
- [ ] T084 [US4] Verify test file appears in bucket and can be downloaded
- [ ] T085 [US4] Verify S3 API endpoint https://s3.chocolandiadc.com accessible via AWS CLI
- [ ] T086 [US4] Verify TLS certificates are valid for both domains (issued by Let's Encrypt)
- [ ] T087 [US4] Cleanup test bucket via MinIO Console

**Checkpoint**: At this point, MinIO Console and S3 API should be accessible via HTTPS with Cloudflare Access authentication, independently testable via browser and CLI

---

## Phase 7: User Story 5 - Longhorn Backup to MinIO (Priority: P3)

**Goal**: Configure Longhorn to use MinIO as backup target for volume snapshots, enable disaster recovery capabilities

**Independent Test**: Create Longhorn volume snapshot, trigger backup to MinIO, verify backup appears in MinIO bucket, restore volume from backup

### Implementation for User Story 5

- [ ] T088 [US5] Create MinIO bucket for Longhorn backups (longhorn-backups) via S3 API in scripts/storage/configure-backup-target.sh
- [ ] T089 [US5] Configure Longhorn backup target settings (S3 URL, bucket, credentials) in terraform/modules/minio/backup-config.tf
- [ ] T090 [US5] Reference MinIO credentials Secret (minio-credentials) in Longhorn backup target configuration in terraform/modules/minio/backup-config.tf
- [ ] T091 [US5] Update MinIO module to include backup target configuration in terraform/modules/minio/main.tf
- [ ] T092 [US5] Run `tofu plan` and verify Longhorn backup target resources to be updated
- [ ] T093 [US5] Apply backup target configuration with `tofu apply -target=module.minio`

### Validation for User Story 5

- [ ] T094 [US5] Create validation script scripts/storage/test-backup-restore.sh for backup/restore workflow
- [ ] T095 [US5] Verify Longhorn backup target is configured (kubectl get settings.longhorn.io default-setting)
- [ ] T096 [US5] Verify Longhorn can connect to MinIO S3 endpoint
- [ ] T097 [US5] Create test volume with data via PVC and pod
- [ ] T098 [US5] Create Longhorn snapshot of test volume via Longhorn UI or kubectl
- [ ] T099 [US5] Trigger backup of snapshot to MinIO via Longhorn UI
- [ ] T100 [US5] Wait for backup to complete (Status=Completed in Longhorn)
- [ ] T101 [US5] Verify backup appears in MinIO bucket longhorn-backups via S3 API
- [ ] T102 [US5] Delete original test volume
- [ ] T103 [US5] Restore volume from MinIO backup via Longhorn UI
- [ ] T104 [US5] Create PVC from restored volume, mount in pod
- [ ] T105 [US5] Verify restored data matches original data
- [ ] T106 [US5] Test scheduled backup configuration (create recurring backup job)
- [ ] T107 [US5] Verify retention policy for old backups
- [ ] T108 [US5] Cleanup test volumes and backups

**Checkpoint**: At this point, Longhorn backup to MinIO should be fully functional, disaster recovery capability verified via backup/restore workflow

---

## Phase 8: Observability & Monitoring

**Purpose**: Prometheus metrics integration and Grafana dashboards for storage monitoring

- [ ] T109 [P] Configure Prometheus metrics for Longhorn (ServiceMonitor) in terraform/modules/longhorn/main.tf
- [ ] T110 [P] Configure Prometheus metrics for MinIO (ServiceMonitor with bearer token) in terraform/modules/minio/main.tf
- [ ] T111 [P] Verify Longhorn metrics endpoint is accessible (http://longhorn-backend:9500/metrics)
- [ ] T112 [P] Verify MinIO metrics endpoint is accessible (http://minio:9000/minio/v2/metrics/cluster)
- [ ] T113 [P] Apply observability configuration with `tofu apply`
- [ ] T114 [P] Verify Prometheus is scraping Longhorn and MinIO metrics (check Prometheus targets)
- [ ] T114a [P] Verify Grafana Prometheus data source is configured and querying Longhorn/MinIO metrics successfully
- [ ] T115 Import Longhorn Grafana dashboard (ID 13032) for volume health and capacity monitoring
- [ ] T116 Import MinIO Grafana dashboard (ID 13502) for S3 API metrics and object storage usage
- [ ] T117 Verify Grafana dashboards display real-time metrics for Longhorn and MinIO

---

## Phase 9: HA Testing & Resilience Validation

**Purpose**: Validate high availability and failure recovery scenarios

- [ ] T118 Create HA testing script scripts/storage/test-ha-failover.sh for node failure simulation
- [ ] T119 Test Longhorn volume availability during node failure (cordon master1 with USB disk)
- [ ] T120 Verify volumes remain accessible from replicas on other nodes
- [ ] T121 Test MinIO pod restart and data persistence (delete pod, wait for recreation)
- [ ] T122 Verify MinIO buckets and objects intact after pod restart
- [ ] T123 Test Longhorn replica synchronization after node recovery (uncordon node)
- [ ] T124 Verify degraded volumes return to healthy state with 2 replicas
- [ ] T125 Test volume expansion (resize PVC, verify Longhorn expands volume online)
- [ ] T126 Test network partition scenario (firewall rules to simulate partition)
- [ ] T127 Document observed failure modes and recovery times

---

## Phase 10: Documentation & Polish

**Purpose**: Finalize documentation, code cleanup, and deployment readiness

- [ ] T128 [P] Create Longhorn module README.md with usage examples, variables, outputs in terraform/modules/longhorn/README.md
- [ ] T129 [P] Create MinIO module README.md with usage examples, variables, outputs in terraform/modules/minio/README.md
- [ ] T130 [P] Document validation scripts usage in scripts/storage/README.md
- [ ] T131 Update repository CLAUDE.md with Longhorn and MinIO technologies
- [ ] T132 Update quickstart.md with actual deployment experience and troubleshooting tips
- [ ] T133 Create runbook for common operations (volume expansion, backup restoration, credential rotation)
- [ ] T134 Add storage capacity planning guidelines based on USB disk size and replica count
- [ ] T135 Document edge cases and known limitations (USB disk failure, capacity constraints)
- [ ] T136 Run complete validation workflow from quickstart.md
- [ ] T137 Verify all Success Criteria from spec.md are met (SC-001 through SC-010)
- [ ] T138 Code review OpenTofu modules for best practices and security
- [ ] T139 Clean up any temporary test resources or validation artifacts
- [ ] T140 Prepare feature branch for PR merge to main

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - **User Story 1 (Longhorn - P1)**: Can start after Foundational - No dependencies on other stories
  - **User Story 2 (Longhorn UI - P2)**: Depends on User Story 1 (requires Longhorn deployed)
  - **User Story 3 (MinIO - P1)**: Depends on User Story 1 (requires Longhorn StorageClass for PVC)
  - **User Story 4 (MinIO Console - P2)**: Depends on User Story 3 (requires MinIO deployed)
  - **User Story 5 (Backup Integration - P3)**: Depends on User Story 1 AND User Story 3 (requires both Longhorn and MinIO)
- **Observability (Phase 8)**: Can run after User Stories 1 and 3 complete
- **HA Testing (Phase 9)**: Requires all user stories complete
- **Documentation (Phase 10)**: Depends on all phases complete

### User Story Dependencies

```
Foundational (Phase 2) - MUST COMPLETE FIRST
    ↓
    ├─→ User Story 1 (Longhorn) - P1 MVP
    │       ↓
    │       ├─→ User Story 2 (Longhorn UI) - P2
    │       │
    │       └─→ User Story 3 (MinIO) - P1 MVP (also depends on US1 for StorageClass)
    │               ↓
    │               └─→ User Story 4 (MinIO Console) - P2
    │
    └─→ User Story 5 (Backup) - P3 (depends on US1 AND US3)
```

### Critical Path

1. **Setup** (T001-T006)
2. **Foundational** (T007-T011) - BLOCKER
3. **User Story 1 - Longhorn** (T012-T029) - P1 MVP
4. **User Story 3 - MinIO** (T044-T064) - P1 MVP (depends on US1 for StorageClass)
5. **User Story 5 - Backup** (T088-T108) - P3 (depends on US1 + US3)

### Parallel Opportunities

**Within Setup (Phase 1)**:
- T003 (scripts directory) can run parallel with T001-T002 (module directories)
- T004, T005, T006 (verification tasks) can all run in parallel

**Within Foundational (Phase 2)**:
- T008, T009, T010 can all run in parallel after T007 completes

**Within User Story 1 (Longhorn)**:
- T012 and T013 (variables and main.tf) can run in parallel
- T017 (outputs.tf) can run in parallel with T012-T016

**Within User Story 2 (Longhorn UI)**:
- T030, T031, T032 (DNS, Access, Ingress) can all run in parallel

**Within User Story 3 (MinIO)**:
- T044 and T045 (variables and deployment) can run in parallel
- T050 (outputs.tf) can run in parallel with T044-T049

**Within User Story 4 (MinIO Console)**:
- T065, T066, T067, T068 (DNS and Access apps) can all run in parallel
- T069, T070 (IngressRoutes) can run in parallel

**Within Observability (Phase 8)**:
- T109-T117 all tasks can run in parallel (different resources)

**Within Documentation (Phase 10)**:
- T128, T129, T130, T131 (READMEs) can all run in parallel

---

## Parallel Example: User Story 1 (Longhorn)

```bash
# Launch module file creation in parallel:
Task T012: "Create Longhorn module variables.tf"
Task T013: "Create Longhorn Helm release configuration in main.tf"

# After T012-T016 complete, can parallelize:
Task T017: "Create Longhorn module outputs.tf"
Task T022: "Create validation script validate-longhorn.sh"
```

---

## Parallel Example: User Story 3 (MinIO)

```bash
# Launch module file creation in parallel:
Task T044: "Create MinIO module variables.tf"
Task T045: "Create MinIO Deployment YAML"

# After T044-T049 complete:
Task T050: "Create MinIO module outputs.tf"
Task T055: "Create validation script validate-minio.sh"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 3 Only)

**Recommended approach for homelab deployment**:

1. Complete **Phase 1: Setup** (T001-T006)
2. Complete **Phase 2: Foundational** (T007-T011) - CRITICAL BLOCKER
3. Complete **Phase 3: User Story 1 - Longhorn** (T012-T029)
   - **STOP and VALIDATE**: Test Longhorn independently via PVC provisioning
4. Complete **Phase 5: User Story 3 - MinIO** (T044-T064)
   - **STOP and VALIDATE**: Test MinIO S3 API independently via AWS CLI
5. **Deploy/Demo MVP**: Core storage infrastructure (Longhorn + MinIO) functional

At this point, you have:
- ✅ Distributed block storage (Longhorn with 2 replicas)
- ✅ S3-compatible object storage (MinIO on Longhorn volume)
- ✅ Validated data persistence and basic HA

### Incremental Delivery (Add UI and Backup)

**After MVP validation**:

6. Complete **Phase 4: User Story 2 - Longhorn UI** (T030-T043)
   - **STOP and VALIDATE**: Access Longhorn UI via browser
7. Complete **Phase 6: User Story 4 - MinIO Console** (T065-T087)
   - **STOP and VALIDATE**: Access MinIO Console via browser
8. Complete **Phase 7: User Story 5 - Backup Integration** (T088-T108)
   - **STOP and VALIDATE**: Backup and restore workflow
9. Complete **Phase 8: Observability** (T109-T117) - Grafana dashboards
10. Complete **Phase 9: HA Testing** (T118-T127) - Validate resilience
11. Complete **Phase 10: Documentation** (T128-T140) - Finalize

### Parallel Team Strategy

**If multiple team members available**:

1. Complete Setup + Foundational together (T001-T011)
2. Once Foundational done, split work:
   - **Developer A**: User Story 1 (Longhorn core) - T012-T029
   - **Developer B**: Prepare User Story 3 files (MinIO module structure) - T044-T050 (can prep, wait for US1)
3. After US1 validates:
   - **Developer A**: User Story 2 (Longhorn UI) - T030-T043
   - **Developer B**: User Story 3 (MinIO deployment) - T051-T064 (now unblocked)
4. After US3 validates:
   - **Developer A**: User Story 5 (Backup) - T088-T108 (requires US1 + US3)
   - **Developer B**: User Story 4 (MinIO Console) - T065-T087
5. Both join for Observability, HA Testing, Documentation

---

## Notes

- [P] tasks = different files, no dependencies - can execute in parallel
- [Story] label maps task to specific user story (US1, US2, US3, US4, US5) for traceability
- Each user story should be independently completable and testable (except dependencies noted)
- Validation scripts are critical per Constitution Principle VII (Test-Driven Learning)
- Commit after each logical task group (e.g., after T012-T017 for Longhorn module files)
- Stop at checkpoints to validate each story independently before proceeding
- **USB disk path**: Ensure /media/usb is mounted on master1 before starting Phase 3
- **Cloudflare credentials**: Verify TF_VAR_cloudflare_api_token and TF_VAR_authorized_emails before Phase 2
- **MinIO credentials**: Auto-generated by OpenTofu, retrieve from Kubernetes Secret after deployment
- **Backup testing**: Requires both Longhorn (US1) and MinIO (US3) deployed - do NOT attempt before both complete

---

## Task Count Summary

- **Phase 1 (Setup)**: 6 tasks
- **Phase 2 (Foundational)**: 5 tasks (BLOCKER)
- **Phase 3 (US1 - Longhorn)**: 18 tasks (P1 MVP)
- **Phase 4 (US2 - Longhorn UI)**: 14 tasks (P2)
- **Phase 5 (US3 - MinIO)**: 21 tasks (P1 MVP)
- **Phase 6 (US4 - MinIO Console)**: 23 tasks (P2)
- **Phase 7 (US5 - Backup)**: 21 tasks (P3)
- **Phase 8 (Observability)**: 10 tasks
- **Phase 9 (HA Testing)**: 10 tasks
- **Phase 10 (Documentation)**: 13 tasks

**Total**: 141 tasks

**MVP Scope (US1 + US3)**: 50 tasks (Phases 1, 2, 3, 5)
**Full Feature**: 141 tasks (All phases)

**Parallel Opportunities**: 35+ tasks marked [P] can run concurrently
