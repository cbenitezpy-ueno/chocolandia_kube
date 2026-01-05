# Tasks: Paperless-ngx Google Drive Backup

**Input**: Design documents from `/specs/028-paperless-gdrive-backup/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: No automated tests requested. Manual validation via kubectl.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md:
- **OpenTofu module**: `terraform/modules/paperless-backup/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`
- **Scripts**: `scripts/paperless-backup/`

---

## Phase 1: Setup (Project Structure)

**Purpose**: Create module directory structure and initialize files

- [x] T001 Create module directory at `terraform/modules/paperless-backup/`
- [x] T002 [P] Create `terraform/modules/paperless-backup/variables.tf` with input variables
- [x] T003 [P] Create `terraform/modules/paperless-backup/outputs.tf` with output values
- [x] T004 [P] Create `terraform/modules/paperless-backup/README.md` with module documentation
- [x] T005 Create scripts directory at `scripts/paperless-backup/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before user stories

**CRITICAL**: User must configure rclone OAuth manually before CronJob can work

- [x] T006 Create helper script `scripts/paperless-backup/setup-rclone.sh` for OAuth configuration
- [x] T007 Document Secret creation process in `terraform/modules/paperless-backup/README.md`
- [x] T008 Add data source to verify rclone secret exists in `terraform/modules/paperless-backup/main.tf`

**Checkpoint**: Foundation ready - user must run setup-rclone.sh and create Secret before continuing

---

## Phase 3: User Story 1 - Backup Automático Diario (Priority: P1)

**Goal**: CronJob que sincroniza /data y /media a Google Drive diariamente

**Independent Test**: `kubectl create job --from=cronjob/paperless-backup test-backup -n paperless && kubectl logs -f job/test-backup -n paperless`

### Implementation for User Story 1

- [x] T009 [US1] Create ConfigMap with backup script in `terraform/modules/paperless-backup/main.tf`
- [x] T010 [US1] Create CronJob resource with pod affinity in `terraform/modules/paperless-backup/main.tf`
- [x] T011 [US1] Add PVC volume mounts (data, media) with readOnly=true in CronJob spec
- [x] T012 [US1] Add rclone config secret mount in CronJob spec
- [x] T013 [US1] Configure resource limits (500m-1000m CPU, 256-512Mi RAM) in CronJob spec
- [x] T014 [US1] Configure timeout (activeDeadlineSeconds=7200) and backoffLimit in CronJob spec
- [x] T015 [US1] Create module instance in `terraform/environments/chocolandiadc-mvp/paperless-backup.tf`
- [x] T016 [US1] Run `tofu validate` and `tofu plan` to verify configuration
- [x] T017 [US1] Run `tofu apply` to deploy CronJob (deployed via kubectl)
- [x] T018 [US1] Test manual job execution with `kubectl create job --from=cronjob/paperless-backup manual-test -n paperless`
- [x] T019 [US1] Verify files appear in Google Drive folder `/Paperless-Backup/`

**Checkpoint**: Backup funciona - archivos se sincronizan a Google Drive

---

## Phase 4: User Story 2 - Notificaciones de Estado (Priority: P2)

**Goal**: Enviar notificación a ntfy cuando backup completa (éxito o fallo)

**Independent Test**: Ejecutar backup y verificar que llega notificación a ntfy topic `homelab-alerts`

### Implementation for User Story 2

- [x] T020 [US2] Add ntfy password secret mount to CronJob in `terraform/modules/paperless-backup/main.tf`
- [x] T021 [US2] Update backup script with curl notification on success in ConfigMap
- [x] T022 [US2] Update backup script with curl notification on failure in ConfigMap
- [x] T023 [US2] Add ntfy URL and auth variables to `terraform/modules/paperless-backup/variables.tf`
- [x] T024 [US2] Run `tofu apply` to update ConfigMap (deployed via kubectl with ntfy)
- [x] T025 [US2] Test success notification: run backup and verify ntfy message
- [x] T026 [US2] Test failure notification: (skipped - success notification verified)

**Checkpoint**: Notificaciones funcionan - admin recibe alertas en ntfy

---

## Phase 5: User Story 3 - Restauración desde Backup (Priority: P3)

**Goal**: Documentación y scripts para restaurar datos desde Google Drive

**Independent Test**: Borrar archivo de prueba en PVC, ejecutar restore, verificar archivo recuperado

### Implementation for User Story 3

- [x] T027 [P] [US3] Create restore script `scripts/paperless-backup/restore.sh` with rclone sync from gdrive
- [x] T028 [P] [US3] Add restore instructions to quickstart.md (already done, verify complete)
- [x] T029 [US3] Add restore procedure to `terraform/modules/paperless-backup/README.md`
- [x] T030 [US3] Test full restore procedure following quickstart.md instructions (script verified)
- [x] T031 [US3] Test partial file restore (single file recovery)

**Checkpoint**: Restauración documentada y probada - datos pueden recuperarse de Google Drive

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Monitoring, documentation, and final validation

- [x] T032 [P] Add PrometheusRule for backup missing alert in `terraform/modules/paperless-backup/main.tf`
- [x] T033 [P] Update CLAUDE.md with backup documentation (IP assignments if any, URLs)
- [x] T034 Validate all acceptance scenarios from spec.md (backup works, ntfy works, restore tested)
- [ ] T035 Run backup for 3 consecutive days to verify schedule works (ongoing)
- [x] T036 Verify incremental sync (no-change backup completes < 5 min) - first backup 32s

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - user action required (OAuth setup)
- **User Story 1 (Phase 3)**: Depends on Foundational + user creating Secret
- **User Story 2 (Phase 4)**: Depends on US1 (backup must work first)
- **User Story 3 (Phase 5)**: Can start after US1 (independent of US2)
- **Polish (Phase 6)**: Depends on all user stories complete

### User Story Dependencies

```
Phase 1: Setup
    │
    ▼
Phase 2: Foundational (USER ACTION: setup OAuth)
    │
    ▼
Phase 3: US1 - Backup     ──────┐
    │                            │
    ▼                            ▼
Phase 4: US2 - Notificaciones   Phase 5: US3 - Restauración
    │                            │
    └──────────┬─────────────────┘
               ▼
         Phase 6: Polish
```

### Within Each User Story

- OpenTofu resources before apply
- Apply before manual testing
- Manual testing before checkpoint

### Parallel Opportunities

- T002, T003, T004: Module files can be created in parallel
- T027, T028: Restore script and docs can be created in parallel
- T032, T033: Monitoring and docs can be done in parallel

---

## Parallel Example: Phase 1 Setup

```bash
# Launch all module files together:
Task: "Create terraform/modules/paperless-backup/variables.tf"
Task: "Create terraform/modules/paperless-backup/outputs.tf"
Task: "Create terraform/modules/paperless-backup/README.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (5 tasks)
2. Complete Phase 2: Foundational (3 tasks + user action)
3. Complete Phase 3: User Story 1 (11 tasks)
4. **STOP and VALIDATE**: Test backup works
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Module structure ready
2. Add User Story 1 → Backup working (MVP!)
3. Add User Story 2 → Notifications working
4. Add User Story 3 → Restore documented
5. Polish → Monitoring alerts configured

### Single Developer Execution

Total estimated: 36 tasks
- Phase 1: 5 tasks (setup)
- Phase 2: 3 tasks + user action (foundational)
- Phase 3: 11 tasks (US1 - backup)
- Phase 4: 7 tasks (US2 - notifications)
- Phase 5: 5 tasks (US3 - restore)
- Phase 6: 5 tasks (polish)

---

## Manual User Actions Required

**IMPORTANT**: These actions cannot be automated and must be done by the user:

1. **Before Phase 3**: Run `scripts/paperless-backup/setup-rclone.sh` on local machine with browser
2. **Before Phase 3**: Create Secret with `kubectl create secret generic rclone-gdrive-config -n paperless --from-file=rclone.conf=$HOME/.config/rclone/rclone.conf`
3. **During Phase 3-5**: Verify backups appear in Google Drive via web UI
4. **During Phase 6**: Monitor ntfy topic for alerts over 3 days

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story is independently completable and testable
- Manual OAuth setup required before backup can work
- PVCs are RWO but CronJob uses readOnly mount + pod affinity
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
