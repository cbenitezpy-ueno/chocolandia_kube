# Tasks: MetalLB Module Refactor - Declarative Resources

**Input**: Design documents from `/specs/022-metallb-refactor/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Manual validation via tofu commands (no automated tests required per spec)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Module path**: `terraform/modules/metallb/`
- **Environment path**: `terraform/environments/chocolandiadc-mvp/`

---

## Phase 1: Setup (Preparation)

**Purpose**: Backup state and document current configuration before changes

- [ ] T001 Backup current Terraform state file from terraform/environments/chocolandiadc-mvp/
- [ ] T002 Document current LoadBalancer service IPs via `kubectl get svc -A | grep LoadBalancer`
- [ ] T003 Verify cluster connectivity via `kubectl get nodes`
- [ ] T004 Verify current MetalLB resources via `kubectl get ipaddresspools,l2advertisements -n metallb-system`

---

## Phase 2: Foundational (Module Refactor)

**Purpose**: Core module changes that enable ALL user stories

**WARNING**: No user story work can begin until this phase is complete

- [ ] T005 Add hashicorp/time provider to required_providers in terraform/modules/metallb/main.tf
- [ ] T006 Add crd_wait_duration variable with validation in terraform/modules/metallb/variables.tf
- [ ] T007 Replace null_resource.wait_for_crds with time_sleep.wait_for_crds in terraform/modules/metallb/main.tf
- [ ] T008 Create kubernetes_manifest.ip_address_pool resource in terraform/modules/metallb/main.tf
- [ ] T009 Create kubernetes_manifest.l2_advertisement resource in terraform/modules/metallb/main.tf
- [ ] T010 Remove null_resource.wait_for_crds from terraform/modules/metallb/main.tf
- [ ] T011 Remove null_resource.ip_address_pool from terraform/modules/metallb/main.tf
- [ ] T012 Add pool_name output to terraform/modules/metallb/outputs.tf (if not present)
- [ ] T013 Run tofu validate in terraform/environments/chocolandiadc-mvp/
- [ ] T014 Run tofu fmt -recursive in terraform/modules/metallb/

**Checkpoint**: Module refactored - ready for state migration and user story validation

---

## Phase 3: User Story 1 - Predictable Infrastructure Plan (Priority: P1) MVP

**Goal**: Enable accurate `tofu plan` visibility for MetalLB configuration changes

**Independent Test**: Run `tofu plan` after modifying IP range and verify planned changes match expected manifest updates

### State Migration for User Story 1

- [ ] T015 [US1] Remove null_resource.wait_for_crds from state via `tofu state rm module.metallb.null_resource.wait_for_crds`
- [ ] T016 [US1] Remove null_resource.ip_address_pool from state via `tofu state rm module.metallb.null_resource.ip_address_pool`

### Validation for User Story 1

- [ ] T017 [US1] Run `tofu plan` and verify new resources shown: time_sleep, kubernetes_manifest.ip_address_pool, kubernetes_manifest.l2_advertisement
- [ ] T018 [US1] Apply changes via `tofu apply` and verify success
- [ ] T019 [US1] Verify IPAddressPool exists via `kubectl get ipaddresspools -n metallb-system`
- [ ] T020 [US1] Verify L2Advertisement exists via `kubectl get l2advertisements -n metallb-system`
- [ ] T021 [US1] Temporarily modify ip_range in metallb.tf, run `tofu plan`, verify manifest diff shown
- [ ] T022 [US1] Revert ip_range change in metallb.tf, confirm `tofu plan` shows no changes

**Checkpoint**: User Story 1 complete - tofu plan accurately shows MetalLB manifest changes

---

## Phase 4: User Story 2 - Clean Resource Destruction (Priority: P1)

**Goal**: Enable automatic cleanup of all MetalLB resources via `tofu destroy`

**Independent Test**: Run `tofu destroy -target=module.metallb` and verify all resources removed from cluster

### Validation for User Story 2

- [ ] T023 [US2] Verify current LoadBalancer services still have IPs via `kubectl get svc -A | grep LoadBalancer`
- [ ] T024 [US2] Run `tofu destroy -target=module.metallb -auto-approve` (CAUTION: affects services)
- [ ] T025 [US2] Verify IPAddressPool removed via `kubectl get ipaddresspools -n metallb-system`
- [ ] T026 [US2] Verify L2Advertisement removed via `kubectl get l2advertisements -n metallb-system`
- [ ] T027 [US2] Verify Helm release removed via `helm list -n metallb-system`
- [ ] T028 [US2] Re-apply MetalLB via `tofu apply`
- [ ] T029 [US2] Verify all 4 LoadBalancer services recovered original IPs: pihole-dns (192.168.4.200), traefik (192.168.4.202), redis (192.168.4.203), postgres (192.168.4.204)

**Checkpoint**: User Story 2 complete - tofu destroy cleanly removes all MetalLB resources

---

## Phase 5: User Story 3 - State Drift Detection (Priority: P2)

**Goal**: Enable detection of manual cluster changes via `tofu plan`

**Independent Test**: Manually edit IPAddressPool via kubectl, run `tofu plan`, verify drift detected

### Validation for User Story 3

- [ ] T030 [US3] Patch IPAddressPool spec via `kubectl patch ipaddresspool eero-pool -n metallb-system --type='json' -p='[{"op": "add", "path": "/spec/addresses/-", "value": "192.168.4.211/32"}]'`
- [ ] T031 [US3] Run `tofu plan` and verify drift detected (extra address shown for removal)
- [ ] T032 [US3] Run `tofu apply` to reconcile state
- [ ] T033 [US3] Verify IPAddressPool restored to original config via `kubectl get ipaddresspool eero-pool -n metallb-system -o yaml`

**Checkpoint**: User Story 3 complete - drift detection working for manual cluster changes

---

## Phase 6: User Story 4 - Reliable CRD Initialization (Priority: P2)

**Goal**: Ensure module reliably waits for CRDs before creating custom resources

**Independent Test**: Fresh cluster deployment succeeds on first `tofu apply` without timing errors

### Validation for User Story 4

- [ ] T034 [US4] Verify time_sleep duration is configurable by checking variables.tf
- [ ] T035 [US4] Verify time_sleep depends on helm_release in main.tf
- [ ] T036 [US4] Verify kubernetes_manifest resources depend on time_sleep in main.tf
- [ ] T037 [US4] (Optional) Destroy and re-apply MetalLB to test full initialization sequence

**Checkpoint**: User Story 4 complete - CRD initialization is reliable and configurable

---

## Phase 7: Polish & Documentation

**Purpose**: Final verification and documentation updates

- [ ] T038 [P] Update CLAUDE.md MetalLB section if any IP assignments changed
- [ ] T039 Run final `tofu plan` to confirm no unexpected changes
- [ ] T040 Verify all 4 LoadBalancer services have correct IPs (pihole-dns, traefik, redis, postgres)
- [ ] T041 Commit all changes with descriptive message referencing GitHub Issue #23
- [ ] T042 Create PR from 022-metallb-refactor branch to main

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - document current state
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories 1-4 (Phase 3-6)**: All depend on Foundational phase
  - US1 and US2 are both P1 priority but should run sequentially (state changes)
  - US3 and US4 are P2 priority and depend on US1/US2 completion
- **Polish (Phase 7)**: Depends on all user stories

### User Story Dependencies

| User Story | Priority | Depends On | Blocks |
|------------|----------|------------|--------|
| US1: Predictable Plan | P1 | Foundational | US2, US3, US4 |
| US2: Clean Destroy | P1 | US1 | US3, US4 |
| US3: Drift Detection | P2 | US2 | - |
| US4: CRD Initialization | P2 | US2 | - |

### Within Each User Story

- State migration before validation
- kubectl verification after tofu operations
- Revert test changes before completing

### Parallel Opportunities

- T001-T004 (Setup verification commands) can run in parallel
- T005-T006 (provider and variable changes) can run in parallel
- T030-T031 (US3 drift test) sequential within story
- US3 and US4 can potentially run in parallel after US2

---

## Execution Example: MVP (User Story 1 Only)

```bash
# Phase 1: Setup
kubectl get svc -A | grep LoadBalancer  # T002
kubectl get ipaddresspools,l2advertisements -n metallb-system  # T004

# Phase 2: Foundational (edit files)
# Edit terraform/modules/metallb/main.tf - add time provider, kubernetes_manifest
# Edit terraform/modules/metallb/variables.tf - add crd_wait_duration
cd terraform/environments/chocolandiadc-mvp
tofu validate  # T013
tofu fmt -recursive ../../../terraform/modules/metallb/  # T014

# Phase 3: User Story 1
tofu state rm module.metallb.null_resource.wait_for_crds  # T015
tofu state rm module.metallb.null_resource.ip_address_pool  # T016
tofu plan  # T017 - verify new resources
tofu apply  # T018
kubectl get ipaddresspools,l2advertisements -n metallb-system  # T019-T020

# MVP COMPLETE - tofu plan now shows accurate MetalLB changes
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (backup, document)
2. Complete Phase 2: Foundational (module refactor)
3. Complete Phase 3: User Story 1 (state migration + plan validation)
4. **STOP and VALIDATE**: Run `tofu plan` with IP range change
5. Commit and deploy if MVP acceptable

### Full Implementation

1. Complete Phases 1-3 (MVP)
2. Complete Phase 4: User Story 2 (destroy/apply cycle)
3. Complete Phase 5: User Story 3 (drift detection)
4. Complete Phase 6: User Story 4 (CRD timing verification)
5. Complete Phase 7: Polish
6. Create PR and merge

### Rollback Plan

If issues occur after applying changes:

```bash
# Option 1: Git revert module changes
git checkout HEAD~1 -- terraform/modules/metallb/
tofu init
tofu apply

# Option 2: Manual kubectl restore (if state corrupted)
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: eero-pool
  namespace: metallb-system
spec:
  addresses:
    - "192.168.4.200-192.168.4.210"
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: eero-pool-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - eero-pool
EOF
```

---

## Notes

- All kubectl commands assume KUBECONFIG is set correctly
- State rm commands are safe - they don't delete Kubernetes resources
- US2 destroy/apply cycle will briefly affect LoadBalancer services
- Run during maintenance window for US2 validation
- Commit after each user story completion
