# Implementation Plan: Cluster Version Audit & Update Plan

**Branch**: `020-cluster-version-audit` | **Date**: 2025-12-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/020-cluster-version-audit/spec.md`

## Summary

Comprehensive audit of all cluster component versions (K3s, Helm releases, container images) with a phased update plan to address security vulnerabilities (70+ CVEs), version drift (K3s 5 versions behind), and reproducibility issues ("latest" tags). Updates will be executed via OpenTofu modules following constitution principle I (Infrastructure as Code - OpenTofu First).

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), Bash scripting for validation
**Primary Dependencies**: OpenTofu, Helm provider (~> 2.12), Kubernetes provider (~> 2.23), kubectl
**Storage**: N/A (infrastructure operations only)
**Testing**: kubectl validation commands, `tofu validate`, `tofu plan`, Prometheus alert monitoring
**Target Platform**: K3s cluster (chocolandiadc-mvp) on Ubuntu 24.04.3 LTS
**Project Type**: Infrastructure operations (no source code changes)
**Performance Goals**: N/A (prioritize correctness over uptime per clarification)
**Constraints**: No strict RTO; prioritize quality and testing over minimizing downtime
**Scale/Scope**: 4-node cluster (2 control-plane + 2 workers), ~25 components to update

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Compliance Notes |
|-----------|--------|------------------|
| **I. Infrastructure as Code - OpenTofu First** | PASS | All Helm upgrades via `tofu apply -target=module.*`; no manual `helm upgrade` |
| **II. GitOps Workflow** | PASS | Changes committed to Git, reviewed before apply |
| **III. Container-First Development** | PASS | Pin "latest" tags to specific versions (FR-004) |
| **IV. Observability & Monitoring** | PASS | FR-007 requires Prometheus alerts during upgrades |
| **V. Security Hardening** | PASS | CVE remediation is core goal; no secrets exposed |
| **VI. High Availability** | PASS | Rolling upgrades preserve HA; etcd quorum maintained |
| **VII. Test-Driven Learning** | PASS | Validation steps after each phase; `tofu validate` required |
| **VIII. Documentation-First** | PASS | Compatibility matrix documented in research.md |
| **IX. Network-First Security** | N/A | No network changes in this feature |

**Gate Status**: PASSED - All applicable constitution principles satisfied.

## Project Structure

### Documentation (this feature)

```text
specs/020-cluster-version-audit/
├── plan.md              # This file
├── spec.md              # Feature specification (complete)
├── research.md          # Upgrade path research (Phase 0)
├── data-model.md        # Component version entities (Phase 1)
├── quickstart.md        # Quick reference commands (Phase 1)
└── tasks.md             # Implementation tasks (complete - 147 tasks)
```

### Source Code (repository root)

```text
terraform/
├── environments/
│   └── chocolandiadc-mvp/
│       ├── monitoring.tf      # kube-prometheus-stack (local.prometheus_stack_version)
│       ├── metallb.tf         # NEW: MetalLB module integration
│       └── variables.tf       # metallb_ip_range variable added
└── modules/
    ├── longhorn/
    │   ├── main.tf            # UPDATED: version = var.chart_version
    │   └── variables.tf       # ADDED: chart_version variable
    ├── metallb/               # NEW MODULE
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── traefik/               # Has chart_version variable
    ├── argocd/                # Has argocd_chart_version variable
    ├── cert-manager/          # Has chart_version variable
    ├── redis-shared/          # Needs chart_version variable
    └── postgresql-cluster/    # Needs chart_version variable
```

**Structure Decision**: Infrastructure operations feature - no new source code directories. All changes are to existing OpenTofu modules to support version parameterization for upgrades.

## Complexity Tracking

> No violations to justify - all constitution gates passed.

## Phase 0: Research Summary

**Objective**: Document upgrade paths, breaking changes, and compatibility requirements.

### Research Tasks

1. **K3s Upgrade Path** (v1.28.3 → v1.33.7)
   - Incremental upgrades required: v1.28 → v1.30 → v1.32 → v1.33
   - No skipping major versions

2. **Longhorn Upgrade Path** (v1.5.5 → v1.10.1)
   - CRITICAL: Must upgrade through each minor version (v1.5 → v1.6 → v1.7 → v1.8 → v1.9 → v1.10)
   - v1beta1 API deprecated in v1.9, removed in v1.10

3. **ArgoCD Upgrade Path** (v2.9 → v3.2)
   - Major version jump requires Helm chart update (5.51.0 → 7.9.0)
   - Review RBAC changes and CRD migrations

4. **kube-prometheus-stack** (55.5.0 → 80.6.0)
   - Backup Grafana dashboards before upgrade
   - CRD updates required

### Output

Detailed findings in [research.md](./research.md)

## Phase 1: Design Summary

**Objective**: Define component entities and validation procedures.

### Deliverables

1. **data-model.md**: Component version tracking entities
2. **quickstart.md**: Quick reference for common upgrade commands

### Output

- [data-model.md](./data-model.md)
- [quickstart.md](./quickstart.md)

## Phase 2: Task Generation

**Status**: COMPLETE (via previous session)

Tasks file contains 147 tasks organized in 7 phases:
- Phase 0: Preparation & Backups (T001-T008)
- Phase 0.5: Ubuntu Security Patches (T009-T030)
- Phase 1: K3s Upgrade (T031-T051)
- Phase 2: Storage & Data (T052-T079)
- Phase 3: Observability & Security (T080-T095)
- Phase 4: Ingress & GitOps (T096-T112)
- Phase 5: Applications & Tag Pinning (T113-T132)
- Phase 6: Documentation & Validation (T133-T147)

See [tasks.md](./tasks.md) for full task list.
