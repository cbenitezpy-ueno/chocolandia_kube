# Implementation Plan: Jenkins CI Deployment

**Branch**: `029-jenkins-ci` | **Date**: 2026-01-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/029-jenkins-ci/spec.md`

## Summary

Deploy Jenkins CI server on K3s cluster to replace GitHub Actions for building Docker images and pushing them to Nexus registry. Jenkins will support Java/Maven, Node.js, Python, and Go projects with pre-configured plugins and toolchains.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), YAML (Kubernetes manifests)
**Primary Dependencies**: Jenkins Helm chart, kubernetes provider ~> 2.23, helm provider ~> 2.11
**Storage**: Kubernetes PersistentVolume via local-path-provisioner (20Gi for Jenkins home)
**Testing**: tofu validate, kubectl smoke tests, build job execution test
**Target Platform**: K3s cluster (Kubernetes 1.28)
**Project Type**: Infrastructure module (OpenTofu)
**Performance Goals**: Build and push Docker image within 10 minutes for typical project
**Constraints**: Single controller (no distributed agents for MVP), homelab resource limits
**Scale/Scope**: Single Jenkins controller with 4 language toolchains

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code - OpenTofu First | PASS | Jenkins deployed via OpenTofu Helm release |
| II. GitOps Workflow | PASS | Configuration managed in Git, PR-based workflow |
| III. Container-First Development | PASS | Jenkins runs as container, builds Docker images |
| IV. Observability & Monitoring | PASS | Prometheus metrics plugin, ServiceMonitor, ntfy notifications |
| V. Security Hardening | PASS | Credentials in K8s Secrets, TLS via cert-manager, Cloudflare Zero Trust |
| VI. High Availability | N/A | Single controller for MVP (out of scope) |
| VII. Test-Driven Learning | PASS | Validation tests for deployment and build jobs |
| VIII. Documentation-First | PASS | README, quickstart guide, and runbooks included |
| IX. Network-First Security | PASS | ClusterIP service, Traefik ingress, no direct exposure |

## Project Structure

### Documentation (this feature)

```text
specs/029-jenkins-ci/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # N/A (infrastructure feature)
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── jenkins/
│       ├── main.tf           # Helm release, namespace, PVC
│       ├── variables.tf      # Module inputs
│       ├── outputs.tf        # Module outputs
│       ├── ingress.tf        # Traefik IngressRoutes
│       ├── monitoring.tf     # ServiceMonitor, PrometheusRule
│       └── values/
│           └── jenkins.yaml  # Helm values template
└── environments/
    └── chocolandiadc-mvp/
        ├── jenkins.tf        # Module instantiation
        └── terraform.tfvars  # Jenkins variables

scripts/
└── jenkins/
    └── validate-jenkins.sh   # Deployment validation script
```

**Structure Decision**: OpenTofu module follows existing patterns (nexus, argocd, etc.) with module definition in `terraform/modules/jenkins/` and instantiation in environment directory.

## Complexity Tracking

No violations - feature follows established patterns and constitution principles.
