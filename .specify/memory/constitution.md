<!--
Sync Impact Report:
- Version change: 1.0.0 → 1.1.0 (MINOR - new project-specific principles added)
- Modified principles:
  * I. Infrastructure as Code - Expanded to mandate Terraform as primary IaC tool
  * IV. Observability & Monitoring - Expanded to mandate Prometheus + Grafana stack
- Added principles:
  * VI. High Availability (HA) Architecture - K3s-specific HA requirements for 4-node cluster
  * VII. Test-Driven Learning - Testing as educational tool, comprehensive test coverage
  * VIII. Documentation-First - Learning documentation, decision records, troubleshooting guides
- Removed sections: None
- Templates requiring validation:
  ✅ plan-template.md - aligned with Constitution Check section
  ✅ spec-template.md - aligned with functional requirements approach
  ✅ tasks-template.md - aligned with task categorization and testing discipline
- Project context:
  * Target: 4 mini-PC cluster running K3s in HA configuration
  * Primary tool: Terraform for all infrastructure provisioning
  * Monitoring: Prometheus + Grafana stack mandatory
  * Purpose: Learning platform with comprehensive testing and documentation
-->

# Chocolandia Kube Constitution

## Core Principles

### I. Infrastructure as Code - Terraform First

All infrastructure MUST be defined, versioned, and managed as Terraform code.

- **Terraform is the primary IaC tool**: All K3s cluster provisioning, configuration, and workload
  deployment MUST be defined in Terraform (.tf files)
- **No manual changes**: All cluster modifications MUST go through Terraform plan/apply workflow
- **State management**: Terraform state MUST be versioned and backed up (local or remote backend)
- **Modular design**: Terraform modules MUST be used to organize infrastructure components
  (cluster, monitoring, networking)
- **Environment parity**: The same Terraform code MUST be able to recreate the cluster identically

**Rationale**: Terraform provides declarative infrastructure management with state tracking,
plan preview, and idempotent operations. For a learning environment, Terraform's explicit planning
phase teaches infrastructure changes before they happen.

### II. GitOps Workflow

All deployments MUST follow GitOps principles with Git as the single source of truth.

- Git commits trigger Terraform plan/apply workflows
- Pull requests MUST be reviewed before merging to main branch
- Terraform plans MUST be reviewed before applying changes
- Rollbacks MUST be performed via Git revert and Terraform apply

**Rationale**: GitOps provides audit trails, enables collaborative review, and ensures that the
deployed state matches version control. This principle enforces traceability and safety.

### III. Container-First Development

All application components MUST be containerized and follow container best practices.

- Applications MUST run in containers with minimal, secure base images
- Containers MUST be stateless; persistent data MUST use Kubernetes PersistentVolumes
- Container images MUST be versioned and stored in a registry (Docker Hub, Harbor, or local)
- Multi-stage builds SHOULD be used to minimize image size
- Health checks (liveness/readiness probes) are MANDATORY for all workloads

**Rationale**: Containers ensure portability, consistency across environments, and alignment with
Kubernetes orchestration. Stateless containers enable horizontal scaling and resilience.

### IV. Observability & Monitoring - Prometheus + Grafana Stack (NON-NEGOTIABLE)

Prometheus and Grafana MUST be deployed and configured for comprehensive cluster observability.

- **Prometheus**: MUST scrape metrics from all cluster nodes, K3s components, and deployed workloads
- **Grafana**: MUST provide dashboards for cluster health, resource usage, and application metrics
- **Structured logging**: Applications MUST log to stdout/stderr in structured format (JSON preferred)
- **Metrics exposure**: All custom services MUST expose Prometheus-compatible /metrics endpoints
- **Alerting**: Critical failure scenarios MUST have alerts configured in Prometheus/Alertmanager
- **Data retention**: Metrics MUST be retained for at least 15 days for learning and debugging

**Rationale**: Observability is essential for understanding cluster behavior, diagnosing issues,
and learning how Kubernetes operates. Prometheus + Grafana provide industry-standard monitoring
that teaches cloud-native observability practices.

### V. Security Hardening

Security MUST be built into every layer: images, runtime, network, and access control.

- Container images SHOULD be scanned for vulnerabilities (recommended for production readiness)
- Principle of least privilege MUST be applied: minimal RBAC permissions
- Network policies SHOULD restrict pod-to-pod communication where applicable
- Secrets MUST be managed via Kubernetes Secrets (encrypted via etcd encryption at rest)
- Resource limits (CPU, memory) MUST be defined for all workloads to prevent resource exhaustion

**Rationale**: Even in learning environments, security best practices should be followed to build
good habits and protect against accidental misconfigurations.

### VI. High Availability (HA) Architecture

The K3s cluster MUST be configured for high availability across 4 mini-PC nodes.

- **Cluster topology**: 3 control-plane nodes + 1 worker node OR 2 control-plane + 2 worker nodes
  (topology MUST be documented and justified in plan.md)
- **Etcd**: K3s embedded etcd MUST run in HA mode (minimum 3 replicas for quorum)
- **Load balancing**: Control-plane API endpoints MUST be load-balanced (via k3s built-in LB or
  external HAProxy/nginx)
- **Node failure tolerance**: Cluster MUST survive single node failure without service interruption
- **Persistent storage**: Workloads requiring persistence MUST use distributed storage solutions
  (Longhorn, NFS, or local-path with replication)

**Rationale**: HA configuration teaches production-grade cluster design, failure handling, and
distributed system concepts. It ensures the learning environment remains operational during
experimentation.

### VII. Test-Driven Learning (NON-NEGOTIABLE)

Testing is a primary learning tool; comprehensive tests MUST validate all infrastructure.

- **Terraform tests**: `terraform validate`, `terraform plan` MUST pass before apply
- **Integration tests**: Cluster functionality MUST be validated with automated tests
  (e.g., kubectl smoke tests, workload deployment validation)
- **Infrastructure tests**: Tools like Terratest, InSpec, or custom scripts MUST verify:
  - Cluster health (all nodes Ready)
  - Control-plane HA (API availability after node failure)
  - Network connectivity (pod-to-pod, pod-to-service)
  - Monitoring stack functionality (Prometheus scraping, Grafana accessibility)
- **Failure injection**: HA behavior MUST be tested by simulating node failures
- **Test documentation**: Every test MUST include comments explaining what it validates and why

**Rationale**: Testing is the best way to learn how systems work and fail. Automated tests provide
immediate feedback, document expected behavior, and build confidence in infrastructure changes.

### VIII. Documentation-First

Documentation is a primary learning artifact; every decision and component MUST be documented.

- **Architecture Decision Records (ADRs)**: Major decisions MUST be documented with context,
  options considered, and rationale (e.g., why 3+1 node topology, why Terraform over Ansible)
- **Runbooks**: Operational procedures MUST be documented (cluster bootstrap, adding nodes,
  disaster recovery, backup/restore)
- **Troubleshooting guides**: Common issues and their solutions MUST be captured as they are
  encountered (learning opportunity documentation)
- **Code comments**: Complex Terraform configurations MUST include inline comments explaining
  the why, not just the what
- **README files**: Every directory MUST have a README explaining its purpose and usage

**Rationale**: Documentation serves dual purposes: teaching tool for the learner and reference
material for future maintenance. Well-documented infrastructure is more maintainable and
transferable.

## Project Context

**Hardware**: 4 mini-PCs (specifications to be documented in plan.md)
**Kubernetes Distribution**: K3s (lightweight, HA-capable, ideal for edge/homelab)
**Primary IaC Tool**: Terraform (all provisioning and configuration)
**Monitoring Stack**: Prometheus (metrics collection) + Grafana (visualization and dashboards)
**Purpose**: Learning platform for Kubernetes, HA architecture, IaC, and observability

## Security & Compliance

All infrastructure changes SHOULD follow security best practices for production readiness:

- **Access Control**: SSH keys for mini-PC access MUST be managed securely
- **Secrets Management**: Kubeconfig, API tokens, and credentials MUST NOT be committed to Git
- **Network Segmentation**: Cluster network SHOULD be isolated from public internet where possible
- **Audit Logging**: K3s audit logs SHOULD be enabled for learning about API interactions
- **Backup Strategy**: Cluster state (etcd snapshots) MUST be backed up regularly

## Development Workflow

All changes MUST follow a structured, reviewable, and testable workflow:

1. **Branching Strategy**: Feature branches from main; no direct commits to main
2. **Testing Gates**:
   - `terraform validate` and `terraform fmt -check` MUST pass
   - `terraform plan` MUST be reviewed before apply
   - Integration tests MUST pass after infrastructure changes
   - Documentation MUST be updated alongside code changes
3. **Review Requirements**:
   - For solo learning: Self-review checklist MUST be completed before merge
   - For collaborative learning: PRs MUST be reviewed by at least one other person
   - Breaking changes MUST be documented in commit messages and ADRs
4. **Deployment Process**:
   - `terraform apply` with explicit approval
   - Cluster validation tests run automatically after apply
   - Rollback plan MUST be documented before risky changes

## Governance

This constitution serves as the learning contract and operational guidelines:

- **Amendment Process**: Principles can be amended as learning progresses; amendments MUST be
  documented with rationale and version incremented
- **Learning Priorities**: When principles conflict, prioritize learning value over production
  perfection (e.g., experimentation over strict security in isolated environment)
- **Compliance Verification**: Self-audit against principles before considering features "complete"
- **Complexity Justification**: Over-engineering MUST be avoided; complexity MUST serve learning
  goals (e.g., HA for learning distributed systems, not just for the sake of complexity)
- **Template Synchronization**: Changes to principles MUST be reflected in plan-template.md,
  spec-template.md, and tasks-template.md

**Version**: 1.1.0 | **Ratified**: 2025-11-08 | **Last Amended**: 2025-11-08
