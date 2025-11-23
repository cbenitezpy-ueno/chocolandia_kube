# Implementation Plan: LocalStack and Container Registry for Local Development

**Branch**: `015-dev-tools-local` | **Date**: 2025-11-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/015-dev-tools-local/spec.md`

## Summary

Deploy two development tools in the K3s homelab cluster: a private Docker Registry (with basic auth and HTTPS) to replace AWS ECR dependency, and LocalStack to emulate AWS services (S3, SQS, SNS, DynamoDB, Lambda) for local development and testing.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), YAML (Kubernetes manifests), Bash (validation scripts)
**Primary Dependencies**: Docker Registry v2, LocalStack (Community Edition), Traefik Ingress, cert-manager
**Storage**: PersistentVolumes via local-path-provisioner (30GB registry + 20GB LocalStack)
**Testing**: Bash scripts for validation (docker push/pull, aws cli against LocalStack)
**Target Platform**: K3s cluster on homelab (Linux ARM64/AMD64)
**Project Type**: Infrastructure deployment (Kubernetes + OpenTofu)
**Performance Goals**: Image push/pull < 30s for 500MB images, LocalStack API response < 1s
**Constraints**: Total storage 50GB, basic auth required, HTTPS only via Let's Encrypt
**Scale/Scope**: Single developer use, multiple projects, 5 AWS services emulated

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code - OpenTofu First | PASS | All deployment via OpenTofu modules |
| II. GitOps Workflow | PASS | Feature branch workflow followed |
| III. Container-First Development | PASS | Both services run as containers in K3s |
| IV. Observability & Monitoring | PASS | Services will expose metrics endpoints |
| V. Security Hardening | PASS | Basic auth + HTTPS + resource limits defined |
| VI. High Availability | PARTIAL | Single replica acceptable for dev tools (not production-critical) |
| VII. Test-Driven Learning | PASS | Validation scripts required for all acceptance criteria |
| VIII. Documentation-First | PASS | Runbooks and quickstart required |
| IX. Network-First Security | PASS | Services deployed on cluster VLAN, accessible via Traefik |

**Gate Status**: PASS (HA partial is acceptable - dev tools don't require HA)

## Project Structure

### Documentation (this feature)

```text
specs/015-dev-tools-local/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   ├── registry/           # Docker Registry module
│   │   ├── main.tf         # Deployment, Service, Ingress, PVC
│   │   ├── variables.tf    # Storage size, hostname, auth config
│   │   └── outputs.tf      # Registry URL, credentials secret name
│   └── localstack/         # LocalStack module
│       ├── main.tf         # Deployment, Service, Ingress, PVC
│       ├── variables.tf    # Services list, storage size, hostname
│       └── outputs.tf      # LocalStack endpoint URL
└── environments/
    └── chocolandiadc-mvp/
        ├── registry.tf     # Registry module instantiation
        └── localstack.tf   # LocalStack module instantiation

kubernetes/
└── dev-tools/
    ├── registry-ui/        # Registry UI deployment (optional P3)
    └── secrets/            # htpasswd for registry auth
```

**Structure Decision**: OpenTofu modules under `terraform/modules/` following existing project patterns. Each tool gets its own module for reusability and clear separation.

## Complexity Tracking

No violations requiring justification. Architecture uses existing patterns (OpenTofu modules, Traefik ingress, cert-manager).
