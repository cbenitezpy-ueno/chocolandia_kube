# Tasks: Documentation Audit and Wiki Sync

**Input**: Design documents from `/specs/024-docs-wiki-sync/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Manual verification only. No automated tests - this is a documentation task.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files/operations, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact paths in descriptions

## User Story Mapping

| Story | Title | Priority | Spec Reference |
|-------|-------|----------|----------------|
| US1 | Audit All Feature Documentation | P1 | Review all 24 feature specs |
| US2 | Update CLAUDE.md Project Guidelines | P1 | Verify and update project context |
| US3 | Sync Documentation to GitHub Wiki | P2 | Run wiki sync and verify |
| US4 | Verify Wiki Script Functionality | P2 | Test scripts before full sync |

---

## Phase 1: Setup (Pre-flight Validation)

**Purpose**: Verify prerequisites and access before starting audit

- [ ] T001 Verify kubectl access to cluster via `kubectl get nodes`
- [ ] T002 Verify gh CLI authenticated via `gh auth status`
- [ ] T003 [P] Verify SSH access to master1 via `ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101`
- [ ] T004 [P] List all feature directories via `ls specs/`

**Checkpoint**: All access verified - safe to proceed with audit

---

## Phase 2: Foundational (Current State Capture)

**Purpose**: Capture current cluster state for comparison with documentation

**⚠️ CRITICAL**: Must complete before any documentation updates

- [ ] T005 Get LoadBalancer services via `kubectl get svc -A -o wide | grep LoadBalancer` and save output
- [ ] T006 [P] Get monitoring stack version via `helm list -n monitoring`
- [ ] T007 [P] Get K3s encryption status via SSH command on master1
- [ ] T008 [P] Get K3s version via `kubectl get nodes -o wide`
- [ ] T009 Document current state in specs/024-docs-wiki-sync/contracts/audit-checklist.yaml

**Checkpoint**: Current state documented - ready for comparison

---

## Phase 3: User Story 1 - Audit All Feature Documentation (Priority: P1) 🎯 MVP

**Goal**: Review all 24 feature specifications and identify outdated or incomplete documentation

**Independent Test**: All features audited, findings documented, no critical issues remain

### Implementation for User Story 1

- [ ] T010 [US1] List features 001-009 and check for spec.md presence
- [ ] T011 [P] [US1] List features 010-014 and check for spec.md presence
- [ ] T012 [P] [US1] List features 015-019 and check for spec.md presence
- [ ] T013 [P] [US1] List features 020-024 and check for spec.md presence
- [ ] T014 [US1] Verify recent features (020-023) have accurate implementation status
- [ ] T015 [US1] Check for any [NEEDS CLARIFICATION] markers remaining in specs
- [ ] T016 [US1] Verify no sensitive information (passwords, API keys) in any spec files
- [ ] T017 [US1] Update audit-checklist.yaml with findings for feature specs section

**Checkpoint**: All 24 features audited, findings documented

---

## Phase 4: User Story 2 - Update CLAUDE.md Project Guidelines (Priority: P1)

**Goal**: Verify and update CLAUDE.md to match current cluster state

**Independent Test**: CLAUDE.md matches kubectl output for all verifiable sections

### Implementation for User Story 2

- [ ] T018 [US2] Compare CLAUDE.md MetalLB IP Assignments against T005 output
- [ ] T019 [US2] Compare CLAUDE.md Monitoring Stack version against T006 output
- [ ] T020 [US2] Verify K3s Secret Encryption section matches T007 output
- [ ] T021 [US2] Verify Recent Changes section includes features 020-024
- [ ] T022 [US2] Update CLAUDE.md if any discrepancies found (document changes)
- [ ] T023 [US2] Update audit-checklist.yaml with findings for CLAUDE.md section

**Checkpoint**: CLAUDE.md verified and updated if needed

---

## Phase 5: User Story 4 - Verify Wiki Script Functionality (Priority: P2)

**Goal**: Test wiki sync scripts before full sync

**Independent Test**: `./scripts/wiki/sync-to-wiki.sh --dry-run` completes without errors

**Note**: US4 comes before US3 because script validation must pass before sync

### Implementation for User Story 4

- [ ] T024 [US4] Check wiki scripts exist in scripts/wiki/
- [ ] T025 [US4] Verify scripts are executable via `ls -la scripts/wiki/*.sh`
- [ ] T026 [US4] Run `./scripts/wiki/sync-to-wiki.sh --dry-run` from repo root
- [ ] T027 [US4] Verify all 24 features appear in generated output
- [ ] T028 [US4] Check for any errors or warnings in dry-run output
- [ ] T029 [US4] Examine generated files in /tmp/chocolandia_kube.wiki/ for correctness
- [ ] T030 [US4] Update audit-checklist.yaml with wiki sync section status

**Checkpoint**: Wiki scripts validated - ready for full sync

---

## Phase 6: User Story 3 - Sync Documentation to GitHub Wiki (Priority: P2)

**Goal**: Sync all documentation to GitHub Wiki and verify accessibility

**Independent Test**: GitHub Wiki displays all 24 features with working navigation

### Implementation for User Story 3

- [ ] T031 [US3] Check if GitHub Wiki is initialized via `git ls-remote https://github.com/cbenitezpy-ueno/chocolandia_kube.wiki.git`
- [ ] T032 [US3] Initialize Wiki if needed (create first page via GitHub UI)
- [ ] T033 [US3] Run full wiki sync via `./scripts/wiki/sync-to-wiki.sh`
- [ ] T034 [US3] Verify Wiki homepage at https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki
- [ ] T035 [P] [US3] Verify 3 random feature pages load correctly
- [ ] T036 [P] [US3] Verify navigation links work (home -> feature -> home)
- [ ] T037 [US3] Update audit-checklist.yaml with GitHub Wiki section status

**Checkpoint**: GitHub Wiki synchronized and verified

---

## Phase 7: Polish & Finalization

**Purpose**: Complete documentation, commit changes, close feature

- [ ] T038 Update spec.md status from "Draft" to "Implemented"
- [ ] T039 Finalize audit-checklist.yaml with all sections complete
- [ ] T040 Commit all documentation changes to branch 024-docs-wiki-sync
- [ ] T041 Create PR for review
- [ ] T042 Merge to main after approval

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 - captures current state
- **Phase 3 (US1)**: Depends on Phase 2 - needs state for comparison
- **Phase 4 (US2)**: Depends on Phase 2 - needs state for comparison
- **Phase 5 (US4)**: Can run after Phase 2 - independent of US1/US2
- **Phase 6 (US3)**: Depends on Phase 5 (scripts must work before full sync)
- **Phase 7 (Polish)**: Depends on all user stories

### User Story Dependencies

| Story | Depends On | Notes |
|-------|------------|-------|
| US1 (Audit Specs) | Foundational | Needs cluster state |
| US2 (CLAUDE.md) | Foundational | Needs cluster state |
| US3 (Wiki Sync) | US4 (Scripts) | Scripts must work first |
| US4 (Script Test) | Foundational | Just needs access |

### Parallel Opportunities

- **Phase 1**: T003, T004 can run in parallel
- **Phase 2**: T006, T007, T008 can run in parallel
- **Phase 3**: T010-T013 can run in parallel (different feature ranges)
- **Phase 6**: T035, T036 can run in parallel (verification steps)

---

## Parallel Example: Phase 2

```bash
# Launch state capture tasks in parallel:
Task: "Get monitoring stack version via helm list -n monitoring"
Task: "Get K3s encryption status via SSH"
Task: "Get K3s version via kubectl get nodes"
```

---

## Implementation Strategy

### MVP First (User Stories 1+2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (capture current state)
3. Complete Phase 3: US1 - Audit all specs
4. Complete Phase 4: US2 - Update CLAUDE.md
5. **STOP and VALIDATE**: Documentation accurate, no sensitive info

### Full Implementation

1. MVP Steps above
2. Complete Phase 5: US4 - Validate wiki scripts
3. Complete Phase 6: US3 - Full wiki sync
4. Complete Phase 7: Polish and finalize
5. Create PR, merge to main

### Rollback Strategy

If wiki sync fails:
1. Preserve dry-run output for debugging
2. Fix identified issues in scripts
3. Re-run dry-run to validate fix
4. Retry full sync

---

## Notes

- [P] tasks = different operations, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- US4 must complete before US3 (scripts validated before sync)
- Commit after each phase or logical group
- Total estimated time: 30-45 minutes
