# Implementation Plan: PostgreSQL Cluster Database Service

**Branch**: `011-postgresql-cluster` | **Date**: 2025-11-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-postgresql-cluster/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy a highly available PostgreSQL database cluster (1 primary + 1 replica) accessible from both Kubernetes cluster applications and internal network administrators. The deployment uses OpenTofu for infrastructure definition, ArgoCD for GitOps-based deployment, and Kubernetes PersistentVolumes for data persistence. The cluster provides automatic failover, standard PostgreSQL connection protocols, and credential-based authentication.

## Technical Context

**Language/Version**: HCL (OpenTofu) 1.6+
**Primary Dependencies**:
- Bitnami PostgreSQL HA Helm Chart v12.x (deployment method - see research.md)
- Kubernetes provider for OpenTofu
- Helm provider for OpenTofu
- ArgoCD Application CRD for GitOps deployment
- MetalLB v0.14.x for LoadBalancer service (internal network access)

**Storage**: Kubernetes PersistentVolumes via local-path-provisioner (existing in cluster)
**Testing**:
- OpenTofu: `tofu validate`, `tofu plan`, `tofu apply`
- Network connectivity tests (K8s pod → database, internal network → database)
- PostgreSQL cluster health checks (replication status, failover testing)
- Integration tests via test application deployment

**Target Platform**: K3s cluster (3 control-plane nodes + 1 worker) on homelab hardware
**Project Type**: Infrastructure as Code (OpenTofu modules + Kubernetes manifests)
**Performance Goals**:
- Connection establishment: <5 seconds
- Concurrent connections: 100+ without degradation
- Query response time: <100ms for 95th percentile
- Availability: 99.9% uptime over 30 days

**Constraints**:
- Network access limited to Kubernetes cluster and internal network only (VLAN-based)
- Must integrate with existing ArgoCD deployment workflow
- Must use existing local-path-provisioner for storage (no external storage systems)
- Must not expose PostgreSQL to public internet
- All configuration must be declarative and version-controlled

**Scale/Scope**:
- 2 PostgreSQL instances (1 primary + 1 replica)
- Support for multiple application databases (shared cluster)
- Single cluster per homelab environment

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Infrastructure as Code - OpenTofu First
**Status**: ✅ PASS
- All PostgreSQL cluster configuration defined in OpenTofu (.tf files)
- ArgoCD Application manifests managed as code
- No manual kubectl or helm commands required
- State managed by OpenTofu

### II. GitOps Workflow
**Status**: ✅ PASS
- ArgoCD monitors Git repository for configuration changes
- Changes deployed automatically via ArgoCD sync
- Rollback via Git revert + ArgoCD sync
- Pull requests required for main branch changes

### III. Container-First Development
**Status**: ✅ PASS
- PostgreSQL runs in containers (official PostgreSQL image or operator-managed)
- Stateless PostgreSQL containers with PersistentVolume for data
- Health checks (liveness/readiness probes) configured
- Multi-stage approach not applicable (using official images)

### IV. Observability & Monitoring - Prometheus + Grafana Stack
**Status**: ✅ PASS
- PostgreSQL exporter exposes /metrics endpoint for Prometheus
- Grafana dashboard for PostgreSQL cluster health (connections, replication lag, query performance)
- Structured logging to stdout/stderr
- Alerts for cluster failures, replication lag, connection exhaustion

### V. Security Hardening
**Status**: ✅ PASS
- Network access via VLAN segmentation (cluster VLAN for K8s, management VLAN for internal network)
- Credentials stored in Kubernetes Secrets (never in Git)
- RBAC for PostgreSQL database users (principle of least privilege)
- Resource limits (CPU/memory) defined for all pods
- Network policies to restrict pod-to-pod access (defense in depth)

### VI. High Availability (HA) Architecture
**Status**: ✅ PASS
- Primary-replica topology (1 primary + 1 replica)
- Automatic failover via PostgreSQL streaming replication
- Service endpoint remains stable during failover
- Data persistence via PersistentVolumes survives pod restarts

### VII. Test-Driven Learning
**Status**: ✅ PASS
- OpenTofu validation tests (`tofu validate`, `tofu plan`)
- Network connectivity tests (cluster → database, internal network → database)
- PostgreSQL cluster health tests (replication status, failover simulation)
- Integration tests via test application (write data, verify replication, simulate failover)
- Failure injection tests (kill primary pod, verify replica promotion)

### VIII. Documentation-First
**Status**: ✅ PASS
- ADR: PostgreSQL deployment method (Helm vs operator)
- Runbook: Cluster bootstrap, failover handling, backup/restore
- Troubleshooting guide: Connection issues, replication lag, storage problems
- Code comments for OpenTofu configurations
- README in terraform module directory
- Network diagram showing PostgreSQL access paths

### IX. Network-First Security
**Status**: ✅ PASS
- PostgreSQL accessible via Kubernetes Service (ClusterIP for cluster access)
- Internal network access via LoadBalancer service (MetalLB with dedicated IP from cluster VLAN - see research.md)
- VLAN segmentation already in place (cluster VLAN, management VLAN)
- Firewall rules allow PostgreSQL traffic (port 5432) from authorized VLANs only
- No public internet exposure

**Overall Gate Status**: ✅ PASS - All NEEDS CLARIFICATION items resolved in research.md

## Project Structure

### Documentation (this feature)

```text
specs/011-postgresql-cluster/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── postgresql-service.yaml  # Kubernetes Service definition
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/
└── modules/
    └── postgresql-cluster/
        ├── main.tf                 # Main OpenTofu configuration
        ├── variables.tf            # Input variables
        ├── outputs.tf              # Output values (connection endpoints)
        ├── versions.tf             # Provider version constraints
        ├── postgresql.tf           # PostgreSQL Helm chart or operator resources
        ├── services.tf             # Kubernetes Services (ClusterIP, NodePort/LB)
        ├── secrets.tf              # Kubernetes Secrets for credentials
        ├── monitoring.tf           # ServiceMonitor for Prometheus
        └── README.md               # Module documentation

kubernetes/
└── applications/
    └── postgresql/
        ├── application.yaml        # ArgoCD Application manifest
        └── values/
            └── postgresql-values.yaml  # Helm values or operator config
```

**Structure Decision**: OpenTofu module approach for PostgreSQL cluster deployment. The module encapsulates all Kubernetes resources (Deployment/StatefulSet, Services, Secrets, PersistentVolumeClaims, ServiceMonitor). ArgoCD Application manifest references the OpenTofu-generated Kubernetes manifests or Helm chart with custom values. This aligns with existing infrastructure patterns (features 002, 006, 008).

## Complexity Tracking

No violations requiring justification. The design follows all constitution principles:
- OpenTofu for IaC (standard)
- ArgoCD for GitOps (existing pattern)
- Container-based PostgreSQL (standard)
- Primary-replica HA (justified by FR-005 requirement)
- VLAN-based network access (existing infrastructure)

---

## Post-Phase 1 Constitution Re-evaluation

**Date**: 2025-11-14
**Status**: ✅ ALL PRINCIPLES STILL PASS

After completing Phase 1 design (data-model.md, contracts/, quickstart.md), the implementation plan continues to align with all constitution principles:

### I. Infrastructure as Code - OpenTofu First ✅
- Bitnami PostgreSQL HA Helm chart deployed via OpenTofu Helm provider
- All configuration in version-controlled HCL files (terraform/modules/postgresql-cluster/)
- ArgoCD Application manifests as code (kubernetes/applications/postgresql/)
- No manual configuration required

### II. GitOps Workflow ✅
- ArgoCD monitors Git repository and auto-syncs changes
- All infrastructure changes flow through Git commits
- Pull request workflow for review before merge
- Documented rollback procedure via Git revert

### III. Container-First Development ✅
- PostgreSQL runs in official container images (Bitnami or official PostgreSQL)
- Stateless containers with data in PersistentVolumes
- Readiness/liveness probes configured (documented in contracts/)
- Health checks enable Kubernetes self-healing

### IV. Observability & Monitoring ✅
- PostgreSQL Exporter sidecar exposes /metrics for Prometheus
- Grafana dashboards for cluster health, replication, performance (documented in quickstart.md)
- Structured logging to stdout/stderr
- Alerts for replication lag, storage, connection exhaustion (documented in contracts/)
- Metrics retention 15+ days

### V. Security Hardening ✅
- Network access via VLAN segmentation (cluster VLAN, management VLAN)
- Credentials in Kubernetes Secrets (never in Git)
- MetalLB LoadBalancer IP restricted to internal network (FortiGate rules)
- PostgreSQL RBAC with least privilege (documented in quickstart.md)
- Resource limits (CPU/memory) configured
- No public internet exposure

### VI. High Availability (HA) Architecture ✅
- Primary-replica topology (1 primary + 1 replica)
- Automatic pod restart via Kubernetes (liveness probes)
- Data persistence via PersistentVolumes (survives pod restarts)
- Service endpoint stability during failover (documented in contracts/)
- Failover procedure documented in quickstart.md (manual promotion required for Bitnami chart)

### VII. Test-Driven Learning ✅
- OpenTofu validation tests (tofu validate, tofu plan)
- Network connectivity tests (cluster → database, internal network → database)
- Replication health tests (documented in quickstart.md)
- Failure injection tests (documented in quickstart.md - kill primary pod, verify recovery)
- Integration tests via test application deployment

### VIII. Documentation-First ✅
- ADR documented in research.md (Bitnami chart vs operators, LoadBalancer vs NodePort)
- Runbook procedures in quickstart.md (backup/restore, failover, troubleshooting)
- Troubleshooting guide in quickstart.md (connection issues, replication lag, storage)
- Code will include inline comments for OpenTofu configurations
- README will be created in terraform module directory
- Data model documented (data-model.md)
- Service contracts documented (contracts/postgresql-service.yaml)

### IX. Network-First Security ✅
- PostgreSQL accessible via Kubernetes Services (ClusterIP for cluster, LoadBalancer for internal network)
- VLAN segmentation leveraged (existing infrastructure)
- FortiGate firewall rules control access (port 5432 from authorized VLANs only)
- MetalLB IP pool coordinated with FortiGate DHCP exclusions (documented in research.md)
- No public internet exposure
- Network access patterns documented (contracts/, data-model.md)

**Conclusion**: The Phase 1 design artifacts (data-model.md, contracts/, quickstart.md) reinforce constitution compliance. All principles remain satisfied, with comprehensive documentation ensuring maintainability and learning value.

**Next Steps**: Phase 2 - `/speckit.tasks` to generate implementation task breakdown

