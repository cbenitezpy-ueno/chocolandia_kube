# Implementation Plan: Headlamp Web UI for K3s Cluster Management

**Branch**: `007-headlamp-web-ui` | **Date**: 2025-11-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-headlamp-web-ui/spec.md`

## Summary

Deploy Headlamp Kubernetes dashboard as a web-based UI for K3s cluster management, accessible via Traefik with automatic HTTPS (cert-manager) and protected by Cloudflare Access with Google OAuth authentication. Headlamp will be deployed using Helm chart managed through OpenTofu, configured with read-only RBAC permissions for safe cluster exploration, and integrated with Prometheus for observability.

**Technical Approach**: OpenTofu module for Helm deployment + Kubernetes manifests for RBAC + Traefik IngressRoute + Cloudflare Access configuration + ServiceMonitor for Prometheus integration.

## Technical Context

**Language/Version**: HCL (OpenTofu) 1.6+, YAML (Kubernetes manifests)
**Primary Dependencies**:
- Headlamp Helm chart (headlamp-k8s/headlamp from artifact.io)
- Traefik v3.1.0 (existing, Feature 005)
- cert-manager v1.13.x (existing, Feature 006)
- Cloudflare Terraform Provider ~> 4.0 (existing, Feature 004)
- Helm provider for OpenTofu
- Kubernetes provider for OpenTofu

**Storage**: Kubernetes Secrets (ServiceAccount tokens, TLS certificates), Kubernetes etcd (state for CRDs)
**Testing**:
- `tofu validate` and `tofu fmt` for HCL syntax
- `tofu plan` for infrastructure preview
- kubectl integration tests (pod health, service accessibility, RBAC validation)
- Browser-based UI tests (login flow, cluster resource visibility)

**Target Platform**: K3s v1.28+ cluster (2 nodes, existing HA setup)
**Project Type**: Infrastructure deployment (OpenTofu modules + Kubernetes resources)
**Performance Goals**:
- Headlamp pod startup < 60 seconds
- UI load time < 3 seconds after authentication
- Log streaming latency < 2 seconds
- Resource consumption < 128Mi memory, < 200m CPU

**Constraints**:
- Read-only RBAC (ClusterRole "view" only, no write/delete permissions)
- Single replica deployment (homelab, no HA requirement)
- Must integrate with existing Traefik + cert-manager + Cloudflare stack
- Domain: headlamp.chocolandiadc.com (subdomain pattern)

**Scale/Scope**:
- Single namespace deployment (default: headlamp)
- 1 Deployment (1 replica)
- 2 Services (ClusterIP for UI, metrics endpoint)
- 1 IngressRoute (Traefik CRD)
- 1 Certificate (cert-manager CRD)
- 1 ServiceAccount + 1 ClusterRoleBinding (RBAC)
- 1 ServiceMonitor (Prometheus)
- 1 Cloudflare Access Application + 1 Policy

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Infrastructure as Code - OpenTofu First ✅
- **Status**: PASS
- **Compliance**: All Headlamp infrastructure (Helm deployment, RBAC, IngressRoute, Cloudflare Access) will be defined in OpenTofu modules
- **Evidence**:
  - OpenTofu module structure: `terraform/modules/headlamp/`
  - Environment-specific variables: `terraform/environments/chocolandiadc-mvp/`
  - State management: Local OpenTofu state file

### II. GitOps Workflow ✅
- **Status**: PASS
- **Compliance**: Feature branch `007-headlamp-web-ui` follows GitOps workflow
- **Evidence**:
  - All changes committed to Git before apply
  - OpenTofu plan reviewed before apply
  - PR review before merging to main

### III. Container-First Development ✅
- **Status**: PASS
- **Compliance**: Headlamp runs as containerized workload
- **Evidence**:
  - Uses official Headlamp Docker image from Helm chart
  - Stateless container (no persistent volumes required)
  - Health checks: liveness/readiness probes configured
  - Resource limits: CPU 200m, Memory 128Mi

### IV. Observability & Monitoring ✅
- **Status**: PASS
- **Compliance**: Prometheus metrics integration via ServiceMonitor
- **Evidence**:
  - Headlamp metrics endpoint exposed at /metrics
  - ServiceMonitor CRD for automatic Prometheus scraping
  - Grafana dashboards available (existing stack)
  - Logs to stdout/stderr (captured by K3s)

### V. Security Hardening ✅
- **Status**: PASS
- **Compliance**: Multiple security layers applied
- **Evidence**:
  - **RBAC**: ServiceAccount with read-only ClusterRole "view" (principle of least privilege)
  - **Network security**: ClusterIP service (not exposed directly)
  - **Access control**: Cloudflare Access with Google OAuth (identity verification)
  - **Encryption**: HTTPS via cert-manager (Let's Encrypt TLS)
  - **Resource limits**: Prevents resource exhaustion
  - **Secrets management**: Bearer tokens stored in Kubernetes Secrets (not in Git)

### VI. High Availability ⚠️ JUSTIFIED DEVIATION
- **Status**: PARTIAL (single replica)
- **Justification**: Single replica acceptable for homelab web UI
- **Rationale**:
  - Headlamp is management UI, not critical service
  - Downtime during pod restart is acceptable (typically < 30 seconds)
  - HA would require shared session storage (adds complexity without learning value)
  - Can be upgraded to HA later if needed (trivial: increase replicas + add PDB)
- **Mitigation**: Kubernetes will auto-restart pod if it crashes

### VII. Test-Driven Learning ✅
- **Status**: PASS
- **Compliance**: Comprehensive test strategy defined
- **Evidence**:
  - **OpenTofu tests**: `tofu validate`, `tofu plan` before apply
  - **Deployment tests**: Pod Running status, service reachability
  - **RBAC tests**: Verify read-only access, block write operations
  - **Integration tests**: HTTPS certificate validation, OAuth flow, log streaming
  - **UI tests**: Browser-based verification of cluster resource visibility

### VIII. Documentation-First ✅
- **Status**: PASS
- **Compliance**: Full documentation workflow planned
- **Evidence**:
  - spec.md (requirements, user stories, success criteria)
  - plan.md (this file: technical design)
  - research.md (Phase 0 output: Helm chart selection, RBAC patterns)
  - data-model.md (Phase 1 output: entity relationships)
  - quickstart.md (Phase 1 output: deployment procedure)
  - tasks.md (Phase 2 output: implementation checklist)

### IX. Network-First Security ✅
- **Status**: PASS
- **Compliance**: Leverages existing network security stack
- **Evidence**:
  - **Cloudflare Access**: Identity verification before cluster access
  - **Traefik**: HTTPS termination, traffic routing
  - **cert-manager**: Automatic TLS certificate management
  - **ClusterIP**: Service not exposed outside cluster (Traefik handles ingress)
  - Note: FortiGate/VLAN integration deferred (homelab uses Eero network currently)

---

**GATE DECISION**: ✅ **PASS** - All constitution principles satisfied. 1 justified deviation (HA) with clear rationale. Proceed to Phase 0 research.

## Project Structure

### Documentation (this feature)

```text
specs/007-headlamp-web-ui/
├── spec.md              # Feature specification (COMPLETED)
├── plan.md              # This file (IN PROGRESS - /speckit.plan command output)
├── research.md          # Phase 0 output (PENDING)
├── data-model.md        # Phase 1 output (PENDING)
├── quickstart.md        # Phase 1 output (PENDING)
├── contracts/           # Phase 1 output (PENDING - N/A for infrastructure)
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── headlamp/                    # NEW: Headlamp deployment module
│       ├── main.tf                  # Helm release, RBAC resources
│       ├── variables.tf             # Module inputs (namespace, domain, replicas, etc.)
│       ├── outputs.tf               # Module outputs (service name, endpoints)
│       ├── versions.tf              # Provider requirements
│       ├── rbac.tf                  # ServiceAccount, ClusterRoleBinding
│       ├── ingress.tf               # Traefik IngressRoute, Certificate CRD
│       ├── monitoring.tf            # ServiceMonitor for Prometheus
│       ├── cloudflare.tf            # Cloudflare Access Application + Policy
│       └── README.md                # Module documentation
│
└── environments/
    └── chocolandiadc-mvp/
        ├── headlamp.tf              # NEW: Headlamp module invocation
        └── terraform.tfvars         # UPDATED: Add headlamp_* variables

scripts/
└── validation/
    └── test-headlamp.sh             # NEW: Integration tests (RBAC, UI, OAuth)
```

**Structure Decision**: Infrastructure-as-Code pattern using OpenTofu modules. Follows existing repository structure established in Features 001-006 (K3s, Pi-hole, Traefik, cert-manager, Cloudflare). Headlamp module is self-contained and reusable across environments.

## Complexity Tracking

> **This section documents justified deviations from constitution principles.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Single replica (Principle VI: HA) | Homelab management UI, downtime acceptable | HA would require session storage (Redis/Memcached), adding infrastructure complexity without learning value for this feature. Can be upgraded later if multi-user access becomes critical. |

---

## Phase 0: Research (PENDING)

**Output File**: `research.md`

**Research Tasks**:
1. **Headlamp Helm Chart Selection**: Identify official Helm chart repository, latest stable version, and required Helm values for OpenTofu integration
2. **RBAC Best Practices**: Research Kubernetes read-only RBAC patterns, ClusterRole "view" permissions scope, and ServiceAccount token generation
3. **Traefik IngressRoute Patterns**: Review Traefik v3.1.0 IngressRoute configuration for HTTP-to-HTTPS redirect, TLS termination, and middleware chaining
4. **cert-manager Integration**: Confirm annotation pattern for automatic certificate issuance (`cert-manager.io/cluster-issuer`)
5. **Cloudflare Access Configuration**: Review Terraform resource `cloudflare_access_application` and `cloudflare_access_policy` for Google OAuth integration
6. **Prometheus ServiceMonitor**: Research ServiceMonitor CRD structure for Prometheus Operator (label selectors, port configuration)
7. **Headlamp Configuration**: Review Headlamp Helm chart values for metrics enablement, OIDC/token authentication, and base URL configuration

**Unknowns to Resolve**:
- Which Headlamp Helm chart version is stable and compatible with K3s v1.28+?
- What Helm values are required to enable Prometheus metrics endpoint?
- Does Headlamp support token-based authentication natively or require external proxy?
- What is the recommended ServiceAccount token format for Headlamp (short-lived vs long-lived)?
- Should Headlamp be deployed in dedicated namespace or reuse existing namespace?

---

## Phase 1: Design (PENDING)

**Output Files**: `data-model.md`, `quickstart.md`, `contracts/` (N/A for infrastructure)

**Design Tasks**:
1. **Data Model**: Document Kubernetes resources and their relationships (Deployment → Service → IngressRoute → Certificate → ServiceAccount → ClusterRoleBinding)
2. **Quickstart Guide**: Step-by-step deployment procedure (tofu init → tofu plan → tofu apply → token generation → browser access → OAuth flow)
3. **Agent Context Update**: Run `.specify/scripts/bash/update-agent-context.sh claude` to add Headlamp, Helm provider, and Cloudflare Access to project context

**Key Decisions to Document**:
- Namespace choice (dedicated `headlamp` namespace vs existing `default`)
- ServiceAccount token lifecycle (how to generate, rotate, revoke)
- IngressRoute hostname (headlamp.chocolandiadc.com)
- Cloudflare Access policy rules (authorized email addresses)

---

## Phase 2: Tasks (NOT STARTED - requires /speckit.tasks command)

**Output File**: `tasks.md` (generated by `/speckit.tasks` command, not by this planning phase)

This phase will break down implementation into actionable tasks organized by user story priority (US1-US5).
