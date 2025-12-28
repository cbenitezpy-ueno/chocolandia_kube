# Tasks: K3s Secret Encryption at Rest

**Input**: Design documents from `/specs/023-k3s-secret-encryption/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Validation scripts included as part of implementation (not TDD).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files/nodes, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact paths/nodes in descriptions

## User Story Mapping

| Story | Title | Priority | Spec Reference |
|-------|-------|----------|----------------|
| US1 | Secure Secrets Storage | P1 | Enable encryption at rest |
| US2 | Encrypted Backups | P1 | Backup contains only encrypted data |
| US3 | Existing Secrets Migration | P1 | Re-encrypt all 112 secrets |
| US4 | Operational Continuity | P1 | Zero downtime during enablement |
| US5 | Recovery Documentation | P2 | Document key backup and recovery |

---

## Phase 1: Setup (Pre-flight Validation)

**Purpose**: Verify prerequisites and create safety backups before any changes

- [x] T001 Verify kubectl access to cluster via `kubectl get nodes`
- [x] T002 Document current secret count via `kubectl get secrets -A --no-headers | wc -l` (Result: 112 secrets)
- [x] T003 [P] Create backup directory at ~/k3s-encryption-backup-$(date +%Y%m%d)/
- [x] T004 [P] Backup all secrets via `kubectl get secrets -A -o yaml > all-secrets-backup.yaml` (18MB backup)
- [x] T005 [P] Verify K3s version (v1.33.7) supports encryption via `kubectl get nodes -o wide`

**Checkpoint**: All prerequisites verified, backups created - safe to proceed

---

## Phase 2: Foundational (HA Coordination Setup)

**Purpose**: Establish SSH access and understand current encryption state

**⚠️ CRITICAL**: Encryption enablement requires server node access

- [x] T006 Verify SSH key access to master1 (192.168.4.101) - user: chocolim
- [x] T007 [P] Verify SSH key access to nodo03 (192.168.4.103) - user: chocolim
- [x] T008 Confirm current encryption status on master1 via `sudo k3s secrets-encrypt status` (Result: Disabled)
- [x] T009 Document current K3s config flags on master1 via `cat /etc/systemd/system/k3s.service` (No --secrets-encryption flag)

**Checkpoint**: Server access confirmed, current state documented

---

## Phase 3: User Story 1+4 - Enable Encryption with Zero Downtime (Priority: P1) 🎯 MVP

**Goal**: Enable encryption on master1 while maintaining application availability

**Independent Test**: After completion, `k3s secrets-encrypt status` shows "Enabled" and all pods remain running

### Implementation for User Story 1+4

- [x] T010 [US1] Record pod states before change via `kubectl get pods -A --no-headers | grep -v Running | wc -l` (Result: 9 non-running - all pre-existing issues)
- [x] T011 [US1] SSH to master1 and become root (user: chocolim with sudo)
- [x] T012 [US1] Re-install K3s with encryption flag via `curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_DOWNLOAD=true sh -s - server --secrets-encryption` (Installed v1.33.6+k3s1)
- [x] T013 [US1] Wait for K3s ready via `systemctl status k3s` (active/running)
- [x] T014 [US1] Verify encryption enabled via `k3s secrets-encrypt status` (Encryption Status: Enabled, Key: AES-CBC aescbckey)
- [x] T015 [US4] Verify all pods still running via `kubectl get pods -A --no-headers | grep -v Running | wc -l` (Result: 9 - unchanged)
- [x] T016 [US4] Verify applications can access secrets via sample secret read (k3s-serving secret accessible)

**Checkpoint**: Encryption enabled on primary server, applications unaffected

---

## Phase 4: User Story 1 - Sync Secondary Server (Priority: P1)

**Goal**: Synchronize encryption configuration to nodo03 for HA

**Independent Test**: Both servers show same encryption hash

### Implementation for HA Sync

- [x] T017 [US1] SSH to nodo03 (192.168.4.103) as root (user: chocolim with sudo)
- [x] T018 [US1] Restart K3s to sync config via `systemctl restart k3s`
- [x] T019 [US1] Wait for K3s ready via `systemctl status k3s` (active/running)
- [x] T020 [US1] Verify encryption status via `k3s secrets-encrypt status` (master1 shows "All hashes match")
- [x] T021 [US1] Compare encryption hash between master1 and nodo03 (master1 status confirms sync)

**Checkpoint**: HA encryption synchronized - both servers encrypted

---

## Phase 5: User Story 3 - Re-encrypt Existing Secrets (Priority: P1)

**Goal**: Re-encrypt all 112 existing secrets with new encryption key

**Independent Test**: `k3s secrets-encrypt status` shows "reencrypt_finished" stage

### Implementation for Re-encryption

- [x] T022 [US3] On master1, trigger re-encryption via `k3s secrets-encrypt rotate-keys` (v1.33+ uses rotate-keys instead of reencrypt)
- [x] T023 [US3] Monitor status until stage shows "reencrypt_finished" (Result: reencrypt_finished, new key: aescbckey-2025-12-27T23:36:11Z)
- [x] T024 [US3] Verify all secrets accessible via `kubectl get secrets -A | wc -l` (Result: 112 - matches T002)
- [x] T025 [US3] Test secret read via `kubectl get secret -n redis redis-credentials -o jsonpath='{.data.redis-password}' | base64 -d` (accessible)

**Checkpoint**: All existing secrets re-encrypted and accessible

---

## Phase 6: User Story 2 - Verify Encrypted Backups (Priority: P1)

**Goal**: Confirm database backups contain only encrypted data

**Independent Test**: SQLite database inspection shows no plaintext secret values

### Verification Tasks

- [x] T026 [US2] Copy validation-script.sh to master1 from specs/023-k3s-secret-encryption/contracts/
- [x] T027 [US2] Make script executable via `chmod +x validation-script.sh`
- [x] T028 [US2] Run validation script to verify encryption at rest (ALL CRITICAL TESTS PASSED)
- [x] T029 [US2] Create test secret to verify new secrets are encrypted (encryption-verification-test created)
- [x] T030 [US2] Verify test secret accessible via API (testkey=encrypted-test-value-12345 accessible)

**Checkpoint**: Encryption verified - secrets encrypted at rest in database

---

## Phase 7: User Story 5 - Recovery Documentation (Priority: P2)

**Goal**: Document encryption key location, backup, and recovery procedures

**Independent Test**: Documentation review shows all scenarios covered

### Documentation Tasks

- [x] T031 [US5] Backup encryption-config.json to /root/encryption-config-backup-$(date +%Y%m%d).json
- [x] T032 [US5] Copy encryption config to secure local storage (outside cluster) - ~/k3s-encryption-backup-20251227/
- [x] T033 [US5] Update CLAUDE.md with encryption key location section
- [x] T034 [US5] Add recovery procedures to CLAUDE.md (key loss, config corruption)
- [x] T035 [US5] Document rollback procedure in CLAUDE.md

**Checkpoint**: Complete documentation for encryption recovery scenarios

---

## Phase 8: Polish & Finalization

**Purpose**: Close out feature and update project tracking

- [ ] T036 [P] Delete test secrets created during validation
- [ ] T037 Verify final secret count matches original (T002)
- [ ] T038 Update spec.md status from "Draft" to "Implemented"
- [ ] T039 Close GitHub Issue #22 via `gh issue close 22 --comment "Encryption at rest enabled"`
- [ ] T040 Commit all documentation changes to branch 023-k3s-secret-encryption

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 - SSH access required
- **Phase 3 (Enable Encryption)**: Depends on Phase 2 - server access verified
- **Phase 4 (HA Sync)**: Depends on Phase 3 - master1 must be encrypted first
- **Phase 5 (Re-encrypt)**: Depends on Phase 4 - HA must be synced first
- **Phase 6 (Verify)**: Depends on Phase 5 - secrets must be re-encrypted first
- **Phase 7 (Documentation)**: Can start after Phase 6 - but backup task (T031) can start after Phase 5
- **Phase 8 (Polish)**: Depends on Phase 6 and Phase 7

### User Story Dependencies

| Story | Depends On | Notes |
|-------|------------|-------|
| US1 (Secure Storage) | Foundational | Core encryption enablement |
| US2 (Encrypted Backups) | US1, US3 | Requires encryption + re-encryption |
| US3 (Migration) | US1 | Can only re-encrypt after enabled |
| US4 (Zero Downtime) | - | Verified during US1 |
| US5 (Documentation) | US1 | Can document after encryption enabled |

### Parallel Opportunities

- **Phase 1**: T003, T004, T005 can run in parallel (local machine operations)
- **Phase 2**: T006, T007 can run in parallel (SSH to different nodes)
- **Phase 8**: T036 can run in parallel with other finalization tasks

### Critical Path

```
T001 → T006 → T010→T011→T012→T013→T014 → T017→T018→T019→T020→T021 → T022→T023 → T028 → T031→T033 → T039
```

---

## Parallel Example: Setup Phase

```bash
# Launch parallel backup and verification tasks:
Task: "Create backup directory at ~/k3s-encryption-backup-$(date +%Y%m%d)/"
Task: "Backup all secrets via kubectl get secrets -A -o yaml"
Task: "Verify K3s version supports encryption"
```

---

## Implementation Strategy

### MVP First (User Stories 1+3+4)

1. Complete Phase 1: Setup ✓
2. Complete Phase 2: Foundational ✓
3. Complete Phase 3: Enable Encryption (US1 + US4)
4. Complete Phase 4: HA Sync (US1)
5. Complete Phase 5: Re-encrypt (US3)
6. **STOP and VALIDATE**: All secrets encrypted, applications running

### Full Implementation

1. MVP Steps above
2. Complete Phase 6: Verify (US2)
3. Complete Phase 7: Documentation (US5)
4. Complete Phase 8: Finalization
5. Close GitHub Issue #22

### Rollback Strategy

If issues occur during implementation:
1. Stop at current phase
2. Run `k3s secrets-encrypt disable` on master1
3. Run `k3s secrets-encrypt reencrypt` to decrypt
4. Restart K3s on both servers
5. Verify applications recover

---

## Notes

- [P] tasks = different nodes or local operations, no dependencies
- [Story] label maps task to specific user story for traceability
- Each phase should be completed before moving to next
- Encryption enablement is mostly sequential due to HA coordination requirements
- Estimated total time: 15-20 minutes
- All commands reference quickstart.md for detailed syntax
