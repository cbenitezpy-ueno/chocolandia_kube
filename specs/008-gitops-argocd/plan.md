# Implementation Plan: GitOps Continuous Deployment with ArgoCD

**Branch**: `008-gitops-argocd` | **Date**: 2025-11-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-gitops-argocd/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement automated continuous deployment for chocolandia_kube infrastructure using ArgoCD pull-based GitOps. When GitHub PRs are approved and merged to main branch, ArgoCD automatically detects changes and synchronizes Kubernetes manifests to the K3s cluster. Enables automated infrastructure deployment without manual `tofu apply`, and provides reusable Application template for future web development projects.

## Technical Context

**Language/Version**: HCL (OpenTofu) 1.6+, YAML (Kubernetes manifests), Bash scripting
**Primary Dependencies**:
- ArgoCD Helm chart v2.8+ (argo-helm/argo-cd)
- Cloudflare Terraform Provider ~> 4.0 (for Access policies)
- Kubernetes Terraform Provider ~> 2.23 (for RBAC, Secrets)
- Helm Terraform Provider ~> 2.11 (for ArgoCD deployment)
**Storage**:
- ArgoCD application state stored in etcd (Kubernetes backend)
- OpenTofu state file (local, `/terraform/environments/chocolandiadc-mvp/terraform.tfstate`)
- Git repository as source of truth (GitHub private repo: chocolandia_kube)
**Testing**:
- `tofu validate` and `tofu fmt -check` for HCL validation
- Bash scripts for ArgoCD health checks and sync validation
- `kubectl` smoke tests for Application resource verification
- ArgoCD CLI (`argocd app list`, `argocd app sync`) for operational testing
**Target Platform**: K3s v1.28+ cluster on Linux nodes (master1 + nodo1)
**Project Type**: Infrastructure (OpenTofu modules for ArgoCD deployment)
**Performance Goals**:
- ArgoCD installation: < 3 minutes
- Git repository change detection: < 3 minutes (polling interval)
- Sync completion: < 5 minutes for infrastructure changes
- Self-heal drift correction: < 3 minutes
**Constraints**:
- Pull-based GitOps only (no inbound webhooks from GitHub due to Cloudflare tunnel)
- ArgoCD polls GitHub repository periodically (no push-based triggers)
- Single K3s cluster (no multi-cluster support)
- Private GitHub repository requires Personal Access Token for ArgoCD authentication
**Scale/Scope**:
- Single K3s cluster with 2 nodes (master1 + nodo1)
- ~10 ArgoCD Applications expected (chocolandia_kube infra + future web projects)
- Repository size: < 100MB, ~50 OpenTofu modules
- Sync frequency: Every 3 minutes for change detection

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Infrastructure as Code - OpenTofu First
**Status**: ✅ PASS

ArgoCD deployment fully defined in OpenTofu modules (Helm chart, Kubernetes resources, Cloudflare Access policies). All ArgoCD configuration managed as code. Application manifests versioned in Git.

### II. GitOps Workflow
**Status**: ✅ PASS

This feature implements the GitOps principle! Git is the single source of truth. All infrastructure changes committed to Git trigger ArgoCD sync. Pull requests reviewed before merging. ArgoCD auto-sync provides continuous deployment from Git to cluster.

### III. Container-First Development
**Status**: ✅ PASS

ArgoCD components run as containers (argocd-server, argocd-repo-server, argocd-application-controller). Health checks configured (liveness/readiness probes). Resource limits defined for all workloads.

### IV. Observability & Monitoring - Prometheus + Grafana Stack
**Status**: ✅ PASS

Prometheus metrics integration included (US5). ArgoCD exposes /metrics endpoints for sync operations, application health, repository connection status. ServiceMonitor created for automatic scraping. Enables observability of GitOps platform itself.

### V. Security Hardening
**Status**: ✅ PASS

- **Access control**: Cloudflare Access + Google OAuth protects ArgoCD web UI (US4)
- **Secrets management**: GitHub token stored as Kubernetes Secret (not committed to Git)
- **RBAC**: ArgoCD ServiceAccount with appropriate cluster permissions
- **Principle of least privilege**: ArgoCD Application scoped to specific namespaces/resources
- **Network security**: ArgoCD runs within existing VLAN architecture
- **Resource limits**: CPU/memory limits defined for all ArgoCD components

### VI. High Availability (HA) Architecture
**Status**: ⚠️ DEVIATION (Justified)

**Deviation**: ArgoCD components deployed with single replicas (no HA)

**Justification**:
- **Learning priority**: Focus on GitOps workflow understanding, not ArgoCD HA
- **Homelab scale**: Single K3s cluster with 2 nodes; ArgoCD HA adds complexity without proportional learning value
- **Acceptable risk**: ArgoCD downtime doesn't affect running workloads, only sync operations
- **Future enhancement**: HA can be added after GitOps workflow is stable and understood

**Mitigation**:
- ArgoCD state persisted in etcd (survives pod restarts)
- K3s will automatically restart ArgoCD pods if they fail
- Manual sync capability via ArgoCD CLI if web UI unavailable

### VII. Test-Driven Learning
**Status**: ✅ PASS

Comprehensive testing strategy defined:
- **OpenTofu tests**: `tofu validate`, `tofu plan` before apply
- **Health checks**: Bash scripts verify ArgoCD components Running status
- **Sync validation**: ArgoCD Application status checks (Synced, Healthy)
- **Integration tests**: End-to-end sync workflow validation (commit → detection → sync → verify)
- **Failure simulation**: Test manual drift correction (self-heal), sync retry on errors

### VIII. Documentation-First
**Status**: ✅ PASS

- **Specification**: Comprehensive spec.md with user stories, requirements, success criteria
- **Implementation plan**: This document (plan.md) with technical context and design decisions
- **Research**: research.md will document ArgoCD best practices and architecture decisions
- **Quickstart**: quickstart.md will provide step-by-step deployment and validation guide
- **Comments**: OpenTofu modules will include inline comments explaining ArgoCD configuration choices

### IX. Network-First Security
**Status**: ✅ PASS

ArgoCD deployment respects existing network architecture:
- **VLAN compatibility**: ArgoCD pods run in cluster VLAN (existing configuration)
- **FortiGate integration**: ArgoCD web UI exposed via Traefik (already configured with firewall rules)
- **No network changes required**: ArgoCD operates within existing network security model
- **Pull-based architecture**: No inbound firewall rules needed (ArgoCD polls GitHub, no webhooks)
- **Cloudflare tunnel**: ArgoCD web UI secured via existing Cloudflare Zero Trust tunnel

### Gate Summary

**Overall Status**: ✅ PASS (1 justified deviation)

- **9 principles evaluated**
- **8 principles passing**
- **1 principle deviation (HA) with justified rationale**
- **Learning value**: Introduces production GitOps patterns without over-engineering for homelab scale
- **Risk**: Low - ArgoCD downtime doesn't affect running workloads

**Proceed to Phase 0 (Research)**: ✅ APPROVED

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── argocd/                          # New ArgoCD module
│       ├── main.tf                      # Helm chart deployment, namespace, RBAC
│       ├── variables.tf                 # Module input variables
│       ├── outputs.tf                   # Module outputs (namespace, service name)
│       ├── ingress.tf                   # Traefik IngressRoute + TLS certificate
│       ├── cloudflare-access.tf         # Cloudflare Access application + policy
│       ├── prometheus.tf                # ServiceMonitor for metrics
│       ├── github-credentials.tf        # Kubernetes Secret with GitHub PAT
│       └── README.md                    # Module documentation
│
└── environments/
    └── chocolandiadc-mvp/
        ├── argocd.tf                    # ArgoCD module invocation (NEW)
        ├── terraform.tfvars             # ArgoCD config variables (github_token, authorized_emails)
        └── variables.tf                 # Variable declarations for ArgoCD

kubernetes/
└── argocd/                              # ArgoCD Application manifests
    ├── applications/
    │   ├── chocolandia-kube.yaml        # Application for infrastructure repo
    │   └── web-app-template.yaml        # Template for web projects
    └── projects/
        └── default.yaml                 # ArgoCD Project for RBAC scoping

scripts/
└── argocd/
    ├── validate-sync.sh                 # Verify ArgoCD sync status
    ├── health-check.sh                  # Check ArgoCD components health
    └── enable-auto-sync.sh              # Enable auto-sync after validation

tests/
└── argocd/
    ├── test-deployment.sh               # Validate ArgoCD pods Running
    ├── test-sync-workflow.sh            # End-to-end sync test (commit → sync → verify)
    └── test-self-heal.sh                # Verify drift correction behavior
```

**Structure Decision**: Infrastructure feature following existing OpenTofu module pattern. New `terraform/modules/argocd/` module encapsulates ArgoCD Helm deployment, Traefik ingress, Cloudflare Access, and Prometheus integration. Environment-specific configuration in `terraform/environments/chocolandiadc-mvp/argocd.tf`. Kubernetes manifests in separate `kubernetes/argocd/` directory for ArgoCD Application CRDs (not managed by OpenTofu). Testing scripts in `scripts/argocd/` for operational validation.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Single-replica ArgoCD (no HA) | Focus learning on GitOps workflow, not ArgoCD HA implementation | HA ArgoCD (3 replicas, Redis HA) adds complexity without proportional learning value for homelab. ArgoCD downtime doesn't affect running workloads, only sync operations. Future enhancement after GitOps workflow stable. |
