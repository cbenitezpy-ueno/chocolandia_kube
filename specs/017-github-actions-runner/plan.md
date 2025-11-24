# Implementation Plan: GitHub Actions Self-Hosted Runner

**Branch**: `017-github-actions-runner` | **Date**: 2025-11-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/017-github-actions-runner/spec.md`

## Summary

Deploy a GitHub Actions self-hosted runner on the homelab K3s cluster to execute CI/CD workflows locally. The runner will be managed via OpenTofu/Kubernetes, use persistent storage for configuration state, and integrate with the existing Prometheus/Grafana monitoring stack. This enables cost savings, faster builds with local caching, and access to internal network resources for CI/CD pipelines.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), YAML (Kubernetes manifests), Bash (validation scripts)
**Primary Dependencies**: Actions Runner Controller (ARC) Helm chart, Kubernetes provider ~> 2.23, Helm provider ~> 2.12
**Storage**: Kubernetes PersistentVolume via local-path-provisioner (runner work directory, configuration state)
**Testing**: OpenTofu validate, kubectl smoke tests, workflow execution validation
**Target Platform**: K3s v1.28+ on Linux x64 (homelab cluster)
**Project Type**: Infrastructure deployment (OpenTofu + Kubernetes)
**Performance Goals**: Runner online within 2 minutes of deployment, job pickup within 30 seconds
**Constraints**: Must survive pod restarts without re-registration, must support 2+ concurrent jobs
**Scale/Scope**: Single repository or organization level, 2-4 runner replicas initially

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Infrastructure as Code - OpenTofu First | PASS | All infrastructure defined in OpenTofu (.tf files), no manual changes |
| II. GitOps Workflow | PASS | Git commits trigger deployments, PR review before merge |
| III. Container-First Development | PASS | Runner runs as containerized workload with health checks |
| IV. Observability & Monitoring | PASS | Prometheus metrics exposed, Grafana dashboard, alerting configured |
| V. Security Hardening | PASS | Secrets in K8s Secrets, least privilege RBAC, resource limits defined |
| VI. High Availability | PASS | Multiple runner replicas, survives single pod failure |
| VII. Test-Driven Learning | PASS | tofu validate, connectivity tests, workflow execution tests |
| VIII. Documentation-First | PASS | ADRs for technology choices, runbooks for operations |
| IX. Network-First Security | PASS | Uses existing VLAN segmentation, no new network requirements |

**Gate Result**: PASSED - All constitution principles satisfied

## Project Structure

### Documentation (this feature)

```text
specs/017-github-actions-runner/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - technology decisions
├── data-model.md        # Phase 1 output - entity definitions
├── quickstart.md        # Phase 1 output - deployment guide
├── contracts/           # Phase 1 output - N/A (no external APIs)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── github-actions-runner/
│       ├── main.tf           # ARC deployment, runner resources
│       ├── variables.tf      # Configurable inputs
│       ├── outputs.tf        # Runner status, endpoints
│       └── README.md         # Module documentation
│
├── environments/
│   └── chocolandiadc-mvp/
│       └── github-actions-runner.tf  # Module instantiation
│
kubernetes/
└── github-actions-runner/
    ├── namespace.yaml                    # Dedicated namespace
    ├── rbac.yaml                         # ServiceAccount and RBAC resources
    ├── github-app-secret.yaml.template   # GitHub App credentials template (not committed)
    ├── servicemonitor.yaml               # Prometheus scraping config
    └── prometheusrule.yaml               # Alerting rules for runner offline
    # Note: Runner deployment handled via Helm chart in OpenTofu module

scripts/
└── github-actions-runner/
    ├── validate-runner.sh    # Post-deployment validation
    └── test-workflow.sh      # Trigger test workflow
```

**Structure Decision**: Infrastructure deployment pattern using OpenTofu module under `terraform/modules/github-actions-runner/` with Kubernetes manifests for runner-specific resources. Follows existing project conventions from other features (pihole, postgresql, redis).

## Complexity Tracking

> No violations detected - all complexity justified by learning goals and constitution requirements.

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| ARC vs Direct Runner | ARC (Actions Runner Controller) | Kubernetes-native management, auto-scaling capability, better lifecycle handling |
| Helm vs Raw Manifests | Helm chart via OpenTofu | Simpler upgrades, maintained by GitHub community, proven in production |
| Runner Scope | Repository-level initially | Simpler token management, can expand to org-level later |
