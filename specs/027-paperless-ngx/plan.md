# Implementation Plan: Paperless-ngx Document Management

**Branch**: `027-paperless-ngx` | **Date**: 2026-01-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/027-paperless-ngx/spec.md`

## Summary

Deploy Paperless-ngx document management system on the K3s cluster with:
- Internet access via Cloudflare Zero Trust tunnel (paperless.chocolandiadc.com)
- LAN access via local domain (paperless.chocolandiadc.local)
- Samba server for scanner integration (consume folder)
- Integration with existing PostgreSQL and Redis
- Prometheus metrics for Grafana monitoring
- 50GB persistent storage for documents

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), YAML (Kubernetes manifests)
**Primary Dependencies**:
- Paperless-ngx container (ghcr.io/paperless-ngx/paperless-ngx:2.14.7)
- Samba container (dperson/samba or samba-in-kubernetes)
- gabe565 Helm chart for Paperless-ngx
**Storage**:
- PostgreSQL (existing cluster at 192.168.4.204) - new database `paperless`
- Redis (existing at 192.168.4.203) - shared instance
- PersistentVolume 50GB via local-path-provisioner (documents)
**Testing**: `tofu validate`, `tofu plan`, connectivity tests, Kubernetes health checks
**Target Platform**: K3s cluster (Kubernetes 1.28+)
**Project Type**: Infrastructure deployment (OpenTofu modules)
**Performance Goals**: Document processing within 5 minutes, search under 3 seconds
**Constraints**: 50GB storage, existing PostgreSQL/Redis capacity, Cloudflare tunnel limits
**Scale/Scope**: Single user/household, thousands of documents

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Infrastructure as Code - OpenTofu First | PASS | All resources defined in OpenTofu modules |
| II. GitOps Workflow | PASS | Feature branch 027-paperless-ngx, PR workflow |
| III. Container-First Development | PASS | Paperless-ngx and Samba as containers with health probes |
| IV. Observability - Prometheus + Grafana | PASS | FR-007 requires Prometheus metrics export |
| V. Security Hardening | PASS | Cloudflare Zero Trust auth, Kubernetes secrets for credentials |
| VI. High Availability | PASS | Uses existing HA PostgreSQL/Redis, single replica acceptable for document processing |
| VII. Test-Driven Learning | PASS | Validation tests, connectivity tests planned |
| VIII. Documentation-First | PASS | Spec, plan, research, ADRs documented |
| IX. Network-First Security | PASS | Cloudflare tunnel for internet, Traefik for local, no direct exposure |

**Gate Result**: PASS - All principles satisfied

## Project Structure

### Documentation (this feature)

```text
specs/027-paperless-ngx/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (API contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   ├── paperless-ngx/           # NEW: Paperless-ngx deployment module
│   │   ├── main.tf              # Namespace, PVC, Deployment, Service
│   │   ├── variables.tf         # Configuration variables
│   │   ├── outputs.tf           # Service endpoints, credentials
│   │   ├── ingress.tf           # Traefik IngressRoute (local + public)
│   │   ├── cloudflare.tf        # Cloudflare tunnel ingress rule
│   │   └── README.md            # Module documentation
│   │
│   └── postgresql-database/     # EXISTING: Reuse for paperless database
│
└── environments/
    └── chocolandiadc-mvp/
        └── paperless.tf         # NEW: Module instantiation (includes Samba sidecar)
```

**Structure Decision**: Infrastructure deployment pattern - one new OpenTofu module (paperless-ngx with Samba sidecar) following existing module patterns (home-assistant, ntfy).

## Complexity Tracking

No violations requiring justification. Design follows existing patterns for service deployment in the cluster.
