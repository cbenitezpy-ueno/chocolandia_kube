<!--
Sync Impact Report:
- Version change: 1.1.0 → 1.2.0 (MINOR - new principle added, major tool change)
- Modified principles:
  * I. Infrastructure as Code - Changed from Terraform to OpenTofu (open-source fork)
  * V. Security Hardening - Expanded to include FortiGate network security
  * VI. High Availability - Updated for homelab with specific hardware (3 Lenovo + 1 HP ProDesk)
  * VII. Test-Driven Learning - Updated references from Terraform to OpenTofu
  * VIII. Documentation-First - Updated ADR examples to include OpenTofu and FortiGate decisions
- Added principles:
  * IX. Network-First Security - FortiGate-based network segmentation and VLAN management
- Removed sections: None
- Templates requiring validation:
  ⚠ plan-template.md - needs update for OpenTofu and FortiGate modules
  ⚠ spec-template.md - aligned with expanded functional requirements
  ⚠ tasks-template.md - needs network infrastructure phase added
- Project context updated:
  * Hardware: 3 Lenovo mini computers + 1 HP ProDesk + 1 FortiGate 100D + 1 Raspberry Pi
  * Primary tool: OpenTofu (replaces Terraform)
  * Network: FortiGate with VLANs (management, cluster, services, DMZ)
  * Auxiliary services: Raspberry Pi (Pi-hole, DNS, jump host)
  * Scope: Homelab completo (not just K3s cluster)
- Follow-up TODOs:
  * Regenerate plan.md with OpenTofu and FortiGate architecture
  * Regenerate tasks.md with network infrastructure phase
  * Update research.md with OpenTofu vs Terraform decision
-->

# Chocolandia Kube Constitution

## Core Principles

### I. Infrastructure as Code - OpenTofu First

All infrastructure MUST be defined, versioned, and managed as OpenTofu code.

- **OpenTofu is the primary IaC tool**: All FortiGate configuration, K3s cluster provisioning,
  and service deployment MUST be defined in OpenTofu (.tf files)
- **No manual changes**: All infrastructure modifications MUST go through OpenTofu plan/apply workflow
- **State management**: OpenTofu state MUST be versioned and backed up (local or remote backend)
- **Modular design**: OpenTofu modules MUST be used to organize infrastructure components
  (networking, cluster, monitoring, services)
- **Environment parity**: The same OpenTofu code MUST be able to recreate the homelab identically
- **Provider diversity**: Multi-provider usage (FortiOS, SSH, Helm, Kubernetes) is encouraged

**Rationale**: OpenTofu is the open-source fork of Terraform, maintaining compatibility while
ensuring community-driven development without vendor lock-in. It provides declarative infrastructure
management with state tracking, plan preview, and idempotent operations. For a learning environment,
OpenTofu's explicit planning phase teaches infrastructure changes before they happen, and its
open-source nature aligns with homelab philosophy.

### II. GitOps Workflow

All deployments MUST follow GitOps principles with Git as the single source of truth.

- Git commits trigger OpenTofu plan/apply workflows
- Pull requests MUST be reviewed before merging to main branch
- OpenTofu plans MUST be reviewed before applying changes
- Rollbacks MUST be performed via Git revert and OpenTofu apply

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

Prometheus and Grafana MUST be deployed and configured for comprehensive infrastructure observability.

- **Prometheus**: MUST scrape metrics from all cluster nodes, K3s components, FortiGate (if supported),
  and deployed workloads
- **Grafana**: MUST provide dashboards for cluster health, network metrics, resource usage, and
  application metrics
- **Structured logging**: Applications MUST log to stdout/stderr in structured format (JSON preferred)
- **Metrics exposure**: All custom services MUST expose Prometheus-compatible /metrics endpoints
- **Alerting**: Critical failure scenarios MUST have alerts configured in Prometheus/Alertmanager
  (node down, VLAN connectivity loss, high firewall rule hits, disk space)
- **Data retention**: Metrics MUST be retained for at least 15 days for learning and debugging

**Rationale**: Observability is essential for understanding infrastructure behavior (network, cluster,
services), diagnosing issues, and learning how distributed systems operate. Prometheus + Grafana
provide industry-standard monitoring that teaches cloud-native and enterprise network observability.

### V. Security Hardening

Security MUST be built into every layer: network, images, runtime, and access control.

- **Network perimeter**: FortiGate MUST be the single entry/exit point with strict firewall rules
- **VLAN segmentation**: Traffic isolation MUST be enforced via VLANs (no cross-VLAN routing without
  explicit firewall rules)
- **Container security**: Images SHOULD be scanned for vulnerabilities (recommended for production
  readiness)
- **Principle of least privilege**: Minimal RBAC permissions (Kubernetes), minimal firewall rules
  (FortiGate), minimal SSH access (jump host only)
- **Network policies**: SHOULD restrict pod-to-pod communication where applicable (defense in depth)
- **Secrets management**: MUST use Kubernetes Secrets (encrypted via etcd) or external secret managers;
  NEVER hardcoded or in Git
- **Resource limits**: CPU/memory limits MUST be defined for all workloads to prevent resource
  exhaustion
- **Jump host pattern**: Direct SSH to cluster nodes SHOULD be disabled; access via Raspberry Pi
  jump host only

**Rationale**: Defense in depth approach with FortiGate as first layer (network security), VLANs
as second layer (traffic isolation), Kubernetes network policies as third layer (pod security).
Even in learning environments, security best practices build good habits and protect against
accidental exposure or misconfigurations.

### VI. High Availability (HA) Architecture

The K3s cluster MUST be configured for high availability across dedicated hardware.

- **Cluster topology**: 3 control-plane nodes (Lenovo mini computers) + 1 worker node (HP ProDesk)
  - Topology chosen to maximize etcd quorum (3 nodes) and learning value with available hardware
- **Etcd**: K3s embedded etcd MUST run in HA mode (minimum 3 replicas for quorum on Lenovo nodes)
- **Load balancing**: Control-plane API endpoints MUST be load-balanced (via K3s built-in LB or
  FortiGate virtual IP)
- **Node failure tolerance**: Cluster MUST survive single node failure without service interruption
- **Network redundancy**: Multiple network paths SHOULD exist where possible (HA uplinks on FortiGate
  if multiple ISPs available)
- **Persistent storage**: Workloads requiring persistence MUST use distributed storage solutions
  (Longhorn, NFS on Raspberry Pi, or local-path with awareness of single-point-of-failure)

**Rationale**: HA configuration teaches production-grade cluster design, failure handling, and
distributed system concepts. Physical hardware diversity (Lenovo + HP ProDesk) teaches heterogeneous
cluster management. It ensures the learning environment remains operational during experimentation.

### VII. Test-Driven Learning (NON-NEGOTIABLE)

Testing is a primary learning tool; comprehensive tests MUST validate all infrastructure.

- **OpenTofu tests**: `tofu validate`, `tofu plan` MUST pass before apply
- **Network tests**: Connectivity tests MUST validate VLAN segmentation and firewall rules
  (e.g., ping tests across VLANs, blocked ports confirmation)
- **Integration tests**: Cluster functionality MUST be validated with automated tests
  (e.g., kubectl smoke tests, workload deployment validation)
- **Infrastructure tests**: Tools like Terratest, InSpec, or custom scripts MUST verify:
  - FortiGate configuration (VLANs created, firewall rules active, routing tables correct)
  - Cluster health (all nodes Ready, correct roles)
  - Control-plane HA (API availability after node failure)
  - Network connectivity (pod-to-pod, pod-to-service, inter-VLAN where allowed)
  - Monitoring stack functionality (Prometheus scraping, Grafana accessibility)
  - Auxiliary services (Pi-hole resolving DNS, jump host accessible)
- **Failure injection**: HA behavior MUST be tested by simulating node failures, VLAN failures,
  firewall rule changes
- **Test documentation**: Every test MUST include comments explaining what it validates and why

**Rationale**: Testing is the best way to learn how systems work and fail. Automated tests provide
immediate feedback, document expected behavior, and build confidence in infrastructure changes.
Network testing teaches firewall troubleshooting and VLAN concepts.

### VIII. Documentation-First

Documentation is a primary learning artifact; every decision and component MUST be documented.

- **Architecture Decision Records (ADRs)**: Major decisions MUST be documented with context,
  options considered, and rationale:
  - Why OpenTofu over Terraform
  - Why FortiGate over pfSense/OPNsense
  - Why 3+1 node topology
  - Why VLAN segmentation (which VLANs, why)
  - Why Raspberry Pi for auxiliary services
- **Runbooks**: Operational procedures MUST be documented:
  - Homelab bootstrap (FortiGate first, then cluster)
  - Adding nodes (network registration, cluster join)
  - VLAN changes and firewall rule updates
  - Disaster recovery (network failure, cluster failure, service failure)
  - Backup/restore (OpenTofu state, etcd snapshots, FortiGate config)
- **Troubleshooting guides**: Common issues and solutions MUST be captured:
  - VLAN connectivity issues
  - Firewall blocking legitimate traffic
  - Cluster networking problems
  - DNS resolution failures (Pi-hole down)
- **Code comments**: Complex OpenTofu configurations MUST include inline comments explaining
  the why, not just the what (especially FortiGate firewall rules, VLAN routing logic)
- **README files**: Every directory MUST have a README explaining its purpose and usage
- **Network diagrams**: Visual network topology diagrams SHOULD be maintained showing VLANs,
  firewall rules, routing, and device placement

**Rationale**: Documentation serves dual purposes: teaching tool for the learner and reference
material for future maintenance. Well-documented infrastructure is more maintainable, transferable,
and helps others learn from your homelab design. Network documentation is critical for understanding
traffic flows and troubleshooting connectivity issues.

### IX. Network-First Security

Network security MUST be the foundation of the homelab; FortiGate configuration comes before cluster deployment.

- **VLAN segmentation MANDATORY**: Traffic MUST be isolated into VLANs by function:
  - **Management VLAN**: Administrative access (SSH, FortiGate GUI, jump host)
  - **Cluster VLAN**: K3s nodes communication (API, etcd, pod network)
  - **Services VLAN**: Auxiliary services (Pi-hole, DNS, future services)
  - **DMZ (optional)**: Exposed services accessible from internet (if homelab provides public services)
- **Default deny firewall posture**: All traffic MUST be blocked by default; only explicitly allowed
  traffic permitted (whitelist approach)
- **Inter-VLAN routing control**: Cross-VLAN traffic MUST require explicit firewall rules
  (no flat network, no unrestricted VLAN-to-VLAN)
- **Firewall rules as code**: All FortiGate firewall rules MUST be defined in OpenTofu
  (no manual GUI changes except initial bootstrap)
- **Network order of operations**:
  1. FortiGate configuration (VLANs, firewall, routing, DHCP)
  2. Network validation (connectivity tests, firewall rule tests)
  3. Cluster deployment (nodes join after network is stable)
  4. Service deployment (after cluster is operational)
- **Change management**: Network changes MUST be tested in staging/isolated VLAN before production

**Rationale**: Network security is the first line of defense and the foundation of a secure homelab.
VLAN segmentation teaches enterprise networking concepts (broadcast domains, routing, firewall zones).
FortiGate provides enterprise-grade security features (IDS/IPS, application control, web filtering)
that teach real-world network security. Deploying network infrastructure first (before cluster)
prevents connectivity issues during cluster bootstrap and teaches proper layered architecture.

## Project Context

**Hardware**:
- 3x Lenovo mini computers (control-plane nodes: master1, master2, master3)
- 1x HP ProDesk mini computer (worker node: nodo1)
- 1x FortiGate 100D (edge firewall/router)
- 1x Raspberry Pi (auxiliary services node)

**Network Architecture**:
- FortiGate 100D with VLAN segmentation (management, cluster, services, DMZ)
- DHCP server on FortiGate with static reservations
- Inter-VLAN routing controlled by firewall rules

**Kubernetes Distribution**: K3s (lightweight, HA-capable, ideal for edge/homelab)

**Primary IaC Tool**: OpenTofu (open-source Terraform fork, all infrastructure as code)

**Monitoring Stack**: Prometheus (metrics collection) + Grafana (visualization and dashboards)

**Auxiliary Services**:
- Pi-hole (network-wide DNS ad-blocking)
- Jump host/bastion (secure SSH access to cluster nodes)
- Internal DNS server (homelab domain resolution)

**Purpose**: Homelab learning platform for enterprise networking (FortiGate, VLANs), Kubernetes,
HA architecture, Infrastructure as Code, and observability

## Security & Compliance

All infrastructure changes MUST follow security best practices for production readiness:

- **Network Security**:
  - FortiGate is the perimeter (single entry/exit point)
  - VLANs enforce traffic isolation (management, cluster, services separated)
  - Default deny firewall rules (whitelist approach)
  - Intrusion Prevention System (IPS) enabled on FortiGate (learning mode initially)
- **Access Control**:
  - SSH keys MUST be used (no password authentication)
  - Jump host (Raspberry Pi) is the only SSH entry point
  - Direct SSH to cluster nodes MUST be disabled from external networks
  - FortiGate admin access MUST be restricted to management VLAN only
- **Secrets Management**:
  - Kubeconfig, API tokens, FortiGate API keys MUST NOT be committed to Git
  - OpenTofu sensitive variables MUST use environment variables or vault
  - K3s cluster token MUST be rotated periodically (learning exercise)
- **Network Segmentation**:
  - Cluster network (pod CIDR, service CIDR) MUST NOT overlap with VLAN subnets
  - Cross-VLAN traffic MUST be logged for audit purposes
  - DMZ traffic (if enabled) MUST be strictly controlled (no direct access to cluster/management)
- **Audit Logging**:
  - FortiGate logs MUST be exported to syslog server or SIEM (future enhancement)
  - K3s audit logs SHOULD be enabled for learning about API interactions
  - All OpenTofu changes MUST be logged in Git history (commit messages, PR reviews)
- **Backup Strategy**:
  - FortiGate configuration MUST be backed up after changes (exported to Git or secure storage)
  - K3s etcd snapshots MUST be backed up regularly (automated or manual)
  - OpenTofu state MUST be backed up (version control or remote backend)

## Development Workflow

All changes MUST follow a structured, reviewable, and testable workflow:

1. **Branching Strategy**: Feature branches from main; no direct commits to main
2. **Testing Gates**:
   - `tofu validate` and `tofu fmt -check` MUST pass
   - `tofu plan` MUST be reviewed before apply (especially for FortiGate changes)
   - Network connectivity tests MUST pass after FortiGate changes
   - Integration tests MUST pass after infrastructure changes
   - Documentation MUST be updated alongside code changes (especially for network changes)
3. **Review Requirements**:
   - For solo learning: Self-review checklist MUST be completed before merge
   - For collaborative learning: PRs MUST be reviewed by at least one other person
   - Breaking changes MUST be documented in commit messages and ADRs (especially network changes
     that affect connectivity)
4. **Deployment Process**:
   - **Network-first**: FortiGate changes applied before cluster changes
   - `tofu apply` with explicit approval (review plan output carefully)
   - Validation tests run automatically after apply (network tests, cluster tests, service tests)
   - Rollback plan MUST be documented before risky changes (especially FortiGate changes)
5. **Emergency Procedures**:
   - FortiGate config backup MUST exist before making firewall changes
   - Out-of-band access to FortiGate MUST be available (console cable, management port)
   - Cluster nodes MUST be accessible via jump host even if FortiGate fails

## Governance

This constitution serves as the learning contract and operational guidelines:

- **Amendment Process**: Principles can be amended as learning progresses; amendments MUST be
  documented with rationale and version incremented
- **Learning Priorities**: When principles conflict, prioritize learning value over production
  perfection (e.g., experimentation over strict security in isolated environment, but never
  compromise network segmentation)
- **Compliance Verification**: Self-audit against principles before considering features "complete"
- **Complexity Justification**: Over-engineering MUST be avoided; complexity MUST serve learning
  goals:
  - FortiGate for learning enterprise firewalling (not just home router)
  - VLANs for learning network segmentation (not just flat network convenience)
  - HA for learning distributed systems (not just single-node simplicity)
  - OpenTofu for learning IaC at scale (not just manual configuration)
- **Template Synchronization**: Changes to principles MUST be reflected in plan-template.md,
  spec-template.md, and tasks-template.md

**Version**: 1.2.0 | **Ratified**: 2025-11-08 | **Last Amended**: 2025-11-08
