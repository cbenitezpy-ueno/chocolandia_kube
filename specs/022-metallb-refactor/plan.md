# Implementation Plan: MetalLB Module Refactor

**Branch**: `022-metallb-refactor` | **Date**: 2025-12-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/022-metallb-refactor/spec.md`

## Summary

Refactor the MetalLB OpenTofu module to replace `null_resource` with provisioners with declarative `kubernetes_manifest` resources. This enables accurate `tofu plan` visibility, automatic state tracking, clean `tofu destroy` behavior, and drift detection for IPAddressPool and L2Advertisement custom resources.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+)
**Primary Dependencies**: hashicorp/kubernetes ~> 2.23, hashicorp/helm ~> 2.11, hashicorp/time ~> 0.11
**Storage**: Kubernetes CRDs (metallb.io/v1beta1), Terraform state file (local)
**Testing**: tofu validate, tofu plan, kubectl verification, manual LoadBalancer service tests
**Target Platform**: K3s 1.28+ cluster (chocolandiadc-mvp)
**Project Type**: Infrastructure module (OpenTofu)
**Performance Goals**: CRD wait <= 30 seconds, apply time <= 60 seconds
**Constraints**: Zero downtime for existing LoadBalancer services, backward compatible variables
**Scale/Scope**: Single module refactor, 4 services using MetalLB IPs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code - OpenTofu First | PASS | Uses kubernetes_manifest (native OpenTofu) |
| II. GitOps Workflow | PASS | Changes via PR, plan review before apply |
| III. Container-First Development | N/A | Infrastructure module, no containers |
| IV. Observability & Monitoring | N/A | No metrics changes required |
| V. Security Hardening | PASS | No new attack surface, same resources |
| VI. High Availability | PASS | No HA impact, same MetalLB config |
| VII. Test-Driven Learning | PASS | tofu validate, plan visibility tests |
| VIII. Documentation-First | PASS | ADR in research.md, quickstart.md |
| IX. Network-First Security | N/A | No network changes |

**Gate Status**: PASSED - No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/022-metallb-refactor/
├── spec.md              # Feature specification
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0 output - research decisions
├── data-model.md        # Phase 1 output - entity definitions
├── quickstart.md        # Phase 1 output - migration guide
├── contracts/           # Phase 1 output - API contracts
│   ├── metallb-crds.yaml      # CRD manifest templates
│   └── terraform-module.hcl   # Module interface contract
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── metallb/
│       ├── main.tf          # Refactored: kubernetes_manifest resources
│       ├── variables.tf     # Add crd_wait_duration variable
│       └── outputs.tf       # Add pool_name output if not present
│
└── environments/
    └── chocolandiadc-mvp/
        └── metallb.tf       # Module invocation (unchanged)
```

**Structure Decision**: Single module refactor within existing terraform/modules/metallb/ directory. No new directories needed.

## Complexity Tracking

> No constitution violations to justify.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |

## Implementation Approach

### Phase 1: Preparation
1. Backup current Terraform state
2. Document current LoadBalancer service IPs
3. Verify cluster connectivity

### Phase 2: Module Refactor
1. Add hashicorp/time provider to required_providers
2. Add crd_wait_duration variable
3. Replace null_resource.wait_for_crds with time_sleep
4. Replace null_resource.ip_address_pool with kubernetes_manifest resources
5. Update outputs if needed

### Phase 3: State Migration
1. Remove old null_resource entries from state
2. Apply new module (creates kubernetes_manifest state entries)
3. Verify Kubernetes resources unchanged

### Phase 4: Validation
1. Run tofu plan - verify no changes shown
2. Modify IP range - verify plan shows accurate diff
3. Verify LoadBalancer services retain IPs
4. Test tofu destroy/apply cycle (optional, in maintenance window)

## Key Design Decisions

From [research.md](./research.md):

1. **kubernetes_manifest over null_resource**: Native state tracking, plan visibility
2. **time_sleep over kubectl wait**: Declarative, no external dependencies
3. **field_manager with server_side_apply**: Conflict prevention, clear ownership
4. **State rm + fresh apply**: Cleaner than import for this migration

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| CRD not available at plan-time | Apply fails | time_sleep wait, targeted apply fallback |
| Services lose IPs | Service outage | IPAddressPool unchanged, retain same config |
| State corruption | Manual recovery needed | Backup state before migration |
| Webhook validation timeout | Apply fails | 30s wait covers webhook startup |

## Edge Case Handling

The following edge cases from spec.md are addressed by existing error handling:

| Edge Case | Handling |
|-----------|----------|
| Helm chart deleted externally while IPAddressPool exists | kubernetes_manifest will fail on next plan; manual state cleanup required |
| CRD registration timeout | time_sleep (30s default) covers typical scenarios; increase crd_wait_duration for slow clusters |
| Duplicate IPAddressPool names | Kubernetes API returns conflict error; user must resolve naming |
| Cluster unreachable during destroy | tofu destroy fails with connection error; requires cluster recovery first |

**Note**: These are infrastructure-level failures handled by Kubernetes/OpenTofu error messages, not application logic.

## Success Criteria Mapping

| Spec Criteria | Implementation Verification |
|---------------|----------------------------|
| SC-001: 100% plan accuracy | tofu plan shows manifest changes |
| SC-002: 95% first-apply success | time_sleep ensures CRD readiness |
| SC-003: 100% destroy cleanup | kubernetes_manifest auto-deletes |
| SC-004: Drift detection | Manual kubectl edit detected by plan |
| SC-005: Zero downtime | Same IPAddressPool config preserved |
| SC-006: IP assignment < 30s | MetalLB controller unchanged |

## Artifacts Generated

| Artifact | Purpose | Location |
|----------|---------|----------|
| research.md | Technical decisions and rationale | specs/022-metallb-refactor/ |
| data-model.md | Entity definitions and relationships | specs/022-metallb-refactor/ |
| quickstart.md | Migration and rollback guide | specs/022-metallb-refactor/ |
| metallb-crds.yaml | CRD manifest contract | specs/022-metallb-refactor/contracts/ |
| terraform-module.hcl | Module interface contract | specs/022-metallb-refactor/contracts/ |

## Next Steps

Run `/speckit.tasks` to generate the detailed task list for implementation.
