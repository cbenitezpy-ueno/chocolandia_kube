# Implementation Plan: Homepage Dashboard

**Branch**: `009-homepage-dashboard` | **Date**: 2025-11-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-homepage-dashboard/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy Homepage (gethomepage.dev) as a centralized dashboard for K3s cluster services. The dashboard will display all deployed applications with their internal (cluster) and external (public) URLs, integrate specialized widgets for infrastructure monitoring (Pi-hole, Traefik, cert-manager, ArgoCD), provide real-time service status, and authenticate via existing Cloudflare Zero Trust + Google OAuth. Implementation follows GitOps workflow with OpenTofu for infrastructure and ArgoCD for continuous deployment.

## Technical Context

**Application**: Homepage v0.8.x (Docker image: ghcr.io/gethomepage/homepage:latest)
**Infrastructure as Code**: OpenTofu 1.6+ (HCL configuration)
**Deployment Method**: Helm chart (jameswynn/homepage) OR Kubernetes manifests via OpenTofu
**Target Platform**: K3s v1.28+ cluster (3 control-plane nodes + 1 worker node)
**Storage**: PersistentVolume via local-path-provisioner (Homepage configuration YAML files)
**Authentication**: Cloudflare Zero Trust Access + Google OAuth (external layer, no Homepage native auth)
**Certificate Management**: cert-manager v1.13.x with Let's Encrypt (TLS for homepage.chocolandiadc.com)
**Ingress/Routing**: NEEDS CLARIFICATION - Traefik IngressRoute OR Cloudflare Tunnel (or both)
**Service Discovery**: Kubernetes API integration (requires ServiceAccount with RBAC permissions)
**Widget APIs**: Pi-hole API, Traefik API, cert-manager CRDs (via kubectl), ArgoCD API
**Configuration Management**: YAML-based (services.yaml, widgets.yaml, settings.yaml, bookmarks.yaml)
**GitOps Tool**: ArgoCD Application resource tracking Git repository
**Testing Strategy**: Integration tests (kubectl validation, HTTP accessibility, widget functionality)
**Performance Goals**: Dashboard load time <3 seconds, widget refresh interval 30 seconds, service status update <30 seconds
**Constraints**: Read-only permissions (no deployment capabilities), single cluster scope, no custom widget development
**Scale/Scope**: ~10-15 services initially (Pi-hole, Traefik, cert-manager, ArgoCD, Headlamp, Homepage itself), expandable to 30+ services

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Infrastructure as Code - OpenTofu First
**Status**: ✅ PASS
- Homepage deployment will be defined in OpenTofu (Kubernetes manifests OR Helm chart resource)
- All configuration (YAML files) will be managed via ConfigMaps defined in OpenTofu
- Cloudflare Access policy for Homepage will be defined in OpenTofu
- ArgoCD Application resource will be defined in OpenTofu
- No manual kubectl apply or Helm install commands; all through OpenTofu workflow

### II. GitOps Workflow
**Status**: ✅ PASS
- Homepage configuration tracked in Git repository
- ArgoCD Application resource will auto-sync from Git
- Changes to services.yaml, widgets.yaml require Git commit + PR review
- Rollback via Git revert + ArgoCD sync

### III. Container-First Development
**Status**: ✅ PASS
- Homepage runs in container (ghcr.io/gethomepage/homepage:latest)
- Configuration stored in PersistentVolume (stateful data separated)
- Liveness and readiness probes will be configured
- Resource limits (CPU/memory) will be defined

### IV. Observability & Monitoring - Prometheus + Grafana Stack
**Status**: ✅ PASS
- Homepage exposes /metrics endpoint (can be scraped by Prometheus if needed)
- Structured logging to stdout/stderr
- Grafana dashboards can be created for Homepage metrics (future enhancement)
- No alerts required for this feature (non-critical service)

### V. Security Hardening
**Status**: ✅ PASS
- Cloudflare Access enforces authentication (Google OAuth)
- ServiceAccount with minimal RBAC permissions (read-only for service discovery)
- Kubernetes Secrets for widget API credentials (Pi-hole password, ArgoCD token)
- TLS certificate via cert-manager (HTTPS only)
- Resource limits to prevent resource exhaustion
- No jump host requirement (accessed via Cloudflare Tunnel)

### VI. High Availability (HA) Architecture
**Status**: ⚠️ PARTIAL PASS (Justified Deviation)
- **Deviation**: Single replica Homepage deployment (no HA)
- **Justification**: Homepage is a convenience dashboard (non-critical service). All services remain independently accessible if Homepage fails. Adding HA complexity for a read-only dashboard provides minimal learning value.
- PersistentVolume uses local-path-provisioner (single-point-of-failure acceptable for non-critical service)
- **Mitigation**: Quick recovery via ArgoCD auto-sync if pod fails

### VII. Test-Driven Learning
**Status**: ✅ PASS
- `tofu validate` and `tofu plan` before apply
- Integration tests:
  - Homepage pod status (Running, Ready)
  - HTTP accessibility (200 OK response)
  - Cloudflare Access authentication (unauthenticated request blocked)
  - Service discovery (services appear on dashboard)
  - Widget functionality (Pi-hole stats, Traefik status, cert-manager certs, ArgoCD apps)
- Test documentation with comments explaining validation purpose

### VIII. Documentation-First
**Status**: ✅ PASS
- Architecture Decision Records (ADRs): Why Homepage over alternatives (Dashy, Homarr)
- Runbooks: Homepage deployment, configuration updates, troubleshooting
- Troubleshooting guides: Widget not loading, service discovery issues, authentication failures
- Code comments in OpenTofu configuration
- README in Homepage module directory
- Quickstart guide (Phase 1 deliverable)

### IX. Network-First Security
**Status**: ✅ PASS
- Homepage accessed via Cloudflare Tunnel (no direct cluster ingress required)
- Cloudflare Access provides authentication layer before traffic reaches cluster
- HTTPS enforced (cert-manager TLS certificate)
- No changes to FortiGate firewall rules required (traffic routes through existing Cloudflare Tunnel)
- Default deny maintained (Homepage not exposed without authentication)

### Summary
**Overall Status**: ✅ PASS with 1 justified deviation (no HA for non-critical dashboard)

**Gates Cleared**: All 9 constitution principles satisfied or justified deviations documented.

**Proceed to Phase 0**: Research can begin.

## Project Structure

### Documentation (this feature)

```text
specs/009-homepage-dashboard/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (Homepage YAML schemas)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── homepage/
│       ├── main.tf                  # Homepage Deployment, Service, PVC, ConfigMaps
│       ├── rbac.tf                  # ServiceAccount, Role, RoleBinding for K8s API access
│       ├── ingress.tf               # IngressRoute (Traefik) or Cloudflare Tunnel config
│       ├── variables.tf             # Input variables (domain, image version, widget configs)
│       ├── outputs.tf               # Output values (service URL, pod status)
│       ├── configs/
│       │   ├── services.yaml        # Homepage services configuration
│       │   ├── widgets.yaml         # Homepage widgets configuration
│       │   ├── settings.yaml        # Homepage settings (theme, title, icons)
│       │   └── bookmarks.yaml       # Homepage bookmarks (optional)
│       └── README.md                # Module documentation
│
└── environments/
    └── chocolandiadc-mvp/
        ├── homepage.tf              # Homepage module invocation
        ├── cloudflare-access.tf     # Cloudflare Access policy for Homepage (updated)
        ├── argocd.tf                # ArgoCD Application for Homepage (updated)
        └── variables.tf             # Environment-specific variables

kubernetes/
└── homepage/                        # Alternative: Pure Kubernetes manifests (if not using Helm)
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── configmaps/
    │   ├── services.yaml
    │   ├── widgets.yaml
    │   └── settings.yaml
    └── rbac/
        ├── serviceaccount.yaml
        ├── role.yaml
        └── rolebinding.yaml

tests/
└── homepage/
    ├── test_deployment.sh           # Integration test: Homepage pod running
    ├── test_accessibility.sh        # Integration test: HTTP 200 response
    ├── test_authentication.sh       # Integration test: Cloudflare Access working
    ├── test_widgets.sh              # Integration test: Widget APIs responding
    └── README.md                    # Test documentation
```

**Structure Decision**: Infrastructure as Code approach with OpenTofu modules. Homepage configuration managed as Kubernetes ConfigMaps (services.yaml, widgets.yaml, settings.yaml) defined in OpenTofu. Deployment via OpenTofu + ArgoCD for GitOps workflow. Integration tests validate deployment, accessibility, authentication, and widget functionality.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Single replica (no HA) | Homepage is non-critical convenience service | HA adds complexity (StatefulSet, shared storage, load balancing) with minimal learning value for read-only dashboard. Quick recovery via ArgoCD auto-sync is sufficient. |

---

## Post-Design Constitution Re-Check

**Status**: ✅ ALL GATES STILL PASS

**Re-evaluation Date**: 2025-11-12 (after Phase 1 design complete)

### Changes from Initial Check
None. All design decisions align with initial constitution evaluation.

### Design Artifacts Confirm:
1. **research.md**: Resolved routing decision (Cloudflare Tunnel only), deployment method (raw manifests), RBAC scoping (namespace-level), widget security (Kubernetes Secrets), storage (ConfigMaps)
2. **data-model.md**: Defined 8 entities with clear state transitions, validation rules, and relationships
3. **contracts/**: Created YAML schemas for services.yaml, widgets.yaml, settings.yaml with comprehensive documentation
4. **quickstart.md**: Documented full deployment procedure following constitution principles (OpenTofu, GitOps, Testing, Documentation)

### Constitution Principle Alignment (Post-Design):

**I. Infrastructure as Code**: ✅ Confirmed - All resources defined in OpenTofu (Deployment, Service, ConfigMaps, RBAC, Cloudflare)

**II. GitOps Workflow**: ✅ Confirmed - Configuration in Git, ArgoCD auto-sync, PR review workflow documented

**III. Container-First**: ✅ Confirmed - Homepage container, ConfigMap storage, health probes, resource limits defined

**IV. Observability**: ✅ Confirmed - Structured logging, metrics endpoint, integration test procedures documented

**V. Security Hardening**: ✅ Confirmed - Cloudflare Access auth, namespace-scoped RBAC, Secrets for credentials, resource limits

**VI. High Availability**: ⚠️ Confirmed - Single replica justified (non-critical service, quick recovery via ArgoCD)

**VII. Test-Driven Learning**: ✅ Confirmed - Integration tests defined (pod status, HTTP, auth, widgets), tofu validate/plan workflow

**VIII. Documentation-First**: ✅ Confirmed - ADRs in research.md, quickstart guide, troubleshooting section, code comments planned

**IX. Network-First Security**: ✅ Confirmed - Cloudflare Tunnel routing, no direct cluster ingress, HTTPS enforced, default deny maintained

**Final Verdict**: ✅ Design phase complete. All constitution gates pass. Ready for Phase 2 (task generation via `/speckit.tasks`).
