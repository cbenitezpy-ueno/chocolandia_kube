# Implementation Plan: Nexus Repository Manager

**Branch**: `016-nexus-repository` | **Date**: 2025-11-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/016-nexus-repository/spec.md`

## Summary

Replace the existing Docker Registry with Sonatype Nexus Repository Manager OSS to provide a unified artifact repository supporting Docker, Helm, NPM, Maven, and APT formats. Deployment via OpenTofu module following existing cluster patterns, with Prometheus metrics integration for Grafana dashboard and Homepage service documentation.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), YAML (Kubernetes manifests)
**Primary Dependencies**: Nexus Repository OSS 3.x, Kubernetes provider ~> 2.23, cert-manager, Traefik
**Storage**: Kubernetes PersistentVolume via local-path-provisioner (50Gi recommended)
**Testing**: tofu validate, tofu plan, kubectl smoke tests, connectivity validation scripts
**Target Platform**: K3s cluster (ARM64/AMD64 mixed architecture)
**Project Type**: Infrastructure deployment (OpenTofu module)
**Performance Goals**: Docker push/pull < 30s for 500MB images, 99% availability
**Constraints**: Single replica (homelab), persistent storage required, HTTPS mandatory
**Scale/Scope**: Single Nexus instance serving 5 repository types, integrated with existing monitoring stack

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code - OpenTofu First | PASS | Module in terraform/modules/nexus/, instantiated via OpenTofu |
| II. GitOps Workflow | PASS | All changes via Git branches, PR review before merge |
| III. Container-First Development | PASS | Nexus runs as container with health probes, PV for persistence |
| IV. Observability & Monitoring | PASS | FR-014 requires Prometheus metrics, Grafana dashboard integration |
| V. Security Hardening | PASS | HTTPS via cert-manager, authentication required for writes |
| VI. High Availability | N/A | Single replica acceptable per spec (homelab scope) |
| VII. Test-Driven Learning | PASS | Validation scripts for each repository type |
| VIII. Documentation-First | PASS | FR-015 requires Homepage documentation, README in module |
| IX. Network-First Security | PASS | Traefik ingress, cluster DNS integration |

**Gate Result**: PASS - No violations requiring justification

## Project Structure

### Documentation (this feature)

```text
specs/016-nexus-repository/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - infrastructure only)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── nexus/                    # NEW: Nexus Repository module
│       ├── main.tf               # Deployment, Services, IngressRoutes
│       ├── variables.tf          # Configurable inputs
│       ├── outputs.tf            # Module outputs
│       └── README.md             # Module documentation
├── environments/
│   └── chocolandiadc-mvp/
│       ├── nexus.tf              # NEW: Module instantiation
│       └── registry.tf           # REMOVE: Existing Docker Registry
└── dashboards/
    └── homelab-overview.json     # UPDATE: Add Nexus metrics panel

kubernetes/
└── homepage/
    └── config/
        └── services.yaml         # UPDATE: Add Nexus service entry

scripts/
└── dev-tools/
    └── validate-nexus.sh         # NEW: Validation script

kubernetes/dev-tools/secrets/     # EXISTING: htpasswd file (reuse or migrate)
```

**Structure Decision**: Infrastructure-only deployment using OpenTofu module pattern consistent with existing modules (localstack, registry, pihole). No application source code - Nexus is deployed as a pre-built container image.

## Complexity Tracking

> No Constitution Check violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | - | - |
