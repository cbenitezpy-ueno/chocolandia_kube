# Research & Architectural Decisions: K3s MVP - 2-Node Cluster on Eero Network

**Feature**: 002-k3s-mvp-eero
**Date**: 2025-11-09
**Status**: Draft

## Context

This research document captures architectural decisions for the K3s MVP deployment. The primary constraint is FortiGate 100D hardware failure, forcing deployment on existing Eero mesh network without VLAN segmentation or firewall rules. The MVP is designed to unblock Kubernetes learning while maintaining a clear migration path to the full HA architecture (feature 001-k3s-cluster-setup) when FortiGate is repaired.

---

## Decision 1: K3s Single-Server vs HA Mode

**Question**: Should the MVP cluster use K3s single-server mode (1 control-plane) or HA mode (3 control-planes)?

**Options Considered**:

1. **Single-server mode** (SQLite datastore, 1 control-plane node)
   - **Pros**: Simplest configuration, minimal resource consumption (1 node instead of 3), faster bootstrap, sufficient for learning basic Kubernetes operations
   - **Cons**: Single point of failure (no HA), cluster API unavailable if control-plane node fails, not production-ready
   - **Resource allocation**: 1 control-plane (master1) + 1 worker (nodo1) = 2 nodes total, worker available for actual workload testing

2. **HA mode** (embedded etcd, 3 control-plane nodes)
   - **Pros**: Production-grade architecture, survives control-plane node failures, teaches etcd quorum and HA concepts
   - **Cons**: Requires 3 control-plane nodes, consumes all 3 Lenovo mini-PCs, no worker capacity remaining for workload testing (HP ProDesk alone is insufficient)
   - **Resource allocation**: 3 control-planes (all Lenovo) + 1 worker (HP ProDesk) = 4 nodes total (exceeds MVP scope)

**Decision**: **Single-server mode (Option 1)**

**Rationale**:
- MVP goal is rapid learning unblocking, not production deployment
- Single-server mode preserves worker node capacity (nodo1) for actual workload testing, which is essential for learning Kubernetes application deployment
- HA concepts will be learned when migrating to feature 001 (full 3-node HA cluster)
- Resource efficiency: 2 nodes (1 server + 1 agent) vs 4 nodes (3 servers + 1 agent)
- Single point of failure is acceptable for temporary learning environment
- Migration path documented: when FortiGate is repaired, MVP cluster can be decommissioned and nodes re-provisioned into HA cluster

**Implementation**:
- K3s server installation: `curl -sfL https://get.k3s.io | sh -s - server --cluster-init=false` (disables embedded etcd HA mode)
- SQLite datastore used by default when `--cluster-init=false` (no additional flags needed)
- K3s agent installation: `curl -sfL https://get.k3s.io | K3S_URL=https://master1:6443 K3S_TOKEN=<token> sh -`

---

## Decision 2: SQLite vs Embedded etcd

**Question**: Should the single-server control-plane use SQLite or embedded etcd as the datastore?

**Options Considered**:

1. **SQLite** (K3s default for single-server)
   - **Pros**: Simpler, zero configuration, adequate for small clusters (<10 nodes), faster bootstrap, smaller resource footprint
   - **Cons**: Not HA-capable, single point of failure, not suitable for production
   - **Performance**: Sufficient for 2-node learning cluster

2. **Embedded etcd** (single-node etcd)
   - **Pros**: More production-like, teaches etcd concepts, easier migration to HA mode later
   - **Cons**: More complex, higher resource consumption, unnecessary overhead for 2-node cluster
   - **Performance**: Overkill for MVP scope

**Decision**: **SQLite (Option 1)**

**Rationale**:
- Simplicity is paramount for MVP unblocking
- SQLite is K3s default for single-server mode (zero configuration required)
- 2-node cluster does not require etcd's distributed consensus features
- Resource efficiency: SQLite has lower memory/CPU footprint than single-node etcd
- Migration path: When moving to feature 001 (HA cluster), entire cluster will be re-provisioned with embedded etcd, so datastore choice in MVP is irrelevant for future state
- Learning focus: This MVP teaches Kubernetes workload deployment, not etcd operations (etcd will be covered in feature 001)

**Implementation**:
- K3s server started without `--cluster-init` flag (SQLite enabled by default)
- Datastore location: `/var/lib/rancher/k3s/server/db/state.db` on master1
- Backup strategy: SQLite database can be backed up with `cp` or K3s built-in etcd-snapshot command (which works with SQLite)

---

## Decision 3: Eero Flat Network vs VLANs

**Question**: Should the cluster use Eero's flat network or attempt VLAN segmentation?

**Options Considered**:

1. **Eero flat network** (no VLANs, all devices on 192.168.4.0/24)
   - **Pros**: Only option available (Eero does not support VLANs), zero configuration required, simple troubleshooting
   - **Cons**: No network segmentation, no isolation between management/cluster/services traffic, violates Constitution Principle IX (Network-First Security)
   - **Security posture**: All cluster nodes, operator laptop, and home devices on same broadcast domain

2. **VLAN segmentation via external switch**
   - **Pros**: Would provide network isolation, align with Constitution Principle IX
   - **Cons**: Requires managed switch (not available in MVP), adds complexity and hardware cost, Eero would still be flat network (VLANs only between mini-PCs)
   - **Feasibility**: Blocked by lack of managed switch hardware

**Decision**: **Eero flat network (Option 1)**

**Rationale**:
- **Hardware constraint**: FortiGate 100D is offline (power supply failure), which was the intended device for VLAN management
- **Eero limitation**: Eero mesh routers do not support VLAN tagging or segmentation (consumer-grade device)
- **Temporary architecture**: This is an explicitly temporary deployment; full VLAN segmentation will be implemented when migrating to feature 001
- **Risk acceptance**: Flat network is acceptable for home learning environment with no external exposure
- **Alternative mitigation**: Firewall rules on individual nodes (iptables/ufw) could provide some isolation, but deferred to keep MVP simple
- **Constitution compliance**: Documented violation of Principle IX with clear migration path

**Implementation**:
- All cluster nodes connect to Eero via Ethernet (preferred) or WiFi
- DHCP IP assignment from Eero (subnet 192.168.4.0/24)
- No firewall rules between nodes (full trust within cluster)
- Static DHCP reservations recommended (configured in Eero app) to prevent IP changes on reboot
- Migration runbook (US3) will document VLAN architecture for feature 001

---

## Decision 4: Local vs Remote OpenTofu State

**Question**: Should OpenTofu state be stored locally or in a remote backend (S3, Terraform Cloud)?

**Options Considered**:

1. **Local state file** (`terraform.tfstate` in environments/chocolandiadc-mvp/)
   - **Pros**: Simple, zero configuration, no dependency on external services, fast iteration
   - **Cons**: Not suitable for team collaboration, no state locking, risk of accidental state corruption or loss
   - **Use case**: Solo learning environment, single operator, MVP simplicity

2. **Remote backend** (S3 + DynamoDB for locking, or Terraform Cloud)
   - **Pros**: State locking prevents concurrent modifications, versioned state history, suitable for team collaboration, production-ready
   - **Cons**: Requires external infrastructure (AWS account, S3 bucket, DynamoDB table), added complexity, unnecessary for solo MVP
   - **Use case**: Production environments, multi-operator teams

**Decision**: **Local state file (Option 1)**

**Rationale**:
- **Solo operator**: Single person learning environment, no concurrent modification risk
- **MVP simplicity**: Reduces dependencies and configuration overhead
- **Rapid iteration**: No network latency for state operations, faster plan/apply cycles
- **Learning focus**: State management best practices (remote backend) will be covered in feature 001 when deploying production HA cluster
- **Migration path**: OpenTofu state can be migrated to remote backend later using `tofu init -migrate-state`
- **Risk mitigation**: Local state file backed up to Git (in .gitignore, manual backup workflow), or exported before risky changes

**Implementation**:
- State file: `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfstate`
- `.gitignore` entry: `*.tfstate` (state file NOT committed to Git, contains sensitive data like IPs, tokens)
- Backup workflow: `cp terraform.tfstate terraform.tfstate.backup` before major changes
- Migration to remote backend documented in runbooks for future feature 001 deployment

---

## Decision 5: Ethernet vs WiFi Connectivity

**Question**: Should cluster nodes connect to Eero exclusively via Ethernet, or support both Ethernet and WiFi?

**Options Considered**:

1. **Ethernet only** (wired connection to Eero nodes)
   - **Pros**: Stable connectivity, predictable latency, higher throughput, recommended for Kubernetes control-plane
   - **Cons**: Requires physical Ethernet cables from mini-PCs to Eero nodes, may limit node placement flexibility
   - **Performance**: <1ms latency within local network, 1 Gbps throughput (Eero Pro 6E)

2. **WiFi only** (wireless connection to Eero mesh)
   - **Pros**: Flexible node placement, no cable management
   - **Cons**: Potential packet loss, variable latency, throughput dependent on WiFi signal strength, not recommended for control-plane
   - **Performance**: 10-50ms latency (depending on signal), 200-800 Mbps throughput (Eero mesh)

3. **Hybrid** (support both, recommend Ethernet)
   - **Pros**: Maximum flexibility, operators can choose based on their setup, gradual migration from WiFi to Ethernet
   - **Cons**: Inconsistent performance across deployments, troubleshooting complexity
   - **Best practice**: Recommend Ethernet for control-plane (master1), allow WiFi for worker (nodo1)

**Decision**: **Hybrid (Option 3) - Support both, recommend Ethernet for master1**

**Rationale**:
- **Flexibility**: Different operators may have different physical constraints (cable access, node placement)
- **Learning value**: Understanding network connectivity impact on cluster stability is valuable
- **Best practice documentation**: Quickstart guide clearly recommends Ethernet for control-plane, documents WiFi performance trade-offs
- **Realistic scenario**: Many homelabs and edge deployments use WiFi for some nodes; learning to troubleshoot WiFi issues is practical
- **Migration consideration**: When migrating to feature 001, Ethernet will be required for all control-plane nodes (documented in runbook)

**Implementation**:
- OpenTofu module supports both connection types (no provider-level distinction needed; SSH works over both)
- Quickstart guide includes connectivity recommendations:
  - **master1 (control-plane)**: Ethernet strongly recommended (API server stability critical)
  - **nodo1 (worker)**: Ethernet preferred, WiFi acceptable (workload pods less sensitive to latency)
- Troubleshooting guide includes WiFi-specific issues:
  - Intermittent node NotReady status (WiFi packet loss)
  - Slow pod startup (image pull over WiFi)
  - etcd/API timeouts (if master1 on WiFi)

---

## Decision 6: Monitoring Deployment Strategy

**Question**: Should Prometheus + Grafana be deployed in Phase 1 (US1) or Phase 2 (US2)?

**Options Considered**:

1. **Phase 1 (with cluster deployment)**
   - **Pros**: Immediate observability, aligns with Constitution Principle IV (Prometheus + Grafana mandatory)
   - **Cons**: Increases complexity of initial deployment, delays cluster availability for workload testing
   - **Timeline**: Longer bootstrap time (15-20 minutes vs 10 minutes)

2. **Phase 2 (after cluster is stable)**
   - **Pros**: Faster MVP unblocking, simpler initial deployment, allows learning basic Kubernetes operations before adding monitoring
   - **Cons**: Temporary violation of Constitution Principle IV, no observability during initial cluster validation
   - **Timeline**: Cluster available in 10 minutes, monitoring added later (US2)

**Decision**: **Phase 2 (Option 2) - Defer to US2**

**Rationale**:
- **MVP focus**: US1 is about getting a functional cluster as quickly as possible to unblock learning
- **Phased learning**: Learn cluster operations first (kubectl, pod deployment), then add monitoring (Prometheus queries, Grafana dashboards)
- **Constitution compliance**: Principle IV compliance deferred but documented in plan; monitoring is planned (US2), not omitted
- **Complexity reduction**: Separating cluster deployment from monitoring deployment simplifies troubleshooting (if cluster fails, it's not a monitoring issue)
- **User story alignment**: Spec clearly separates US1 (cluster) from US2 (monitoring), indicating phased approach

**Implementation**:
- Phase 1 (US1): Cluster deployment only (K3s server + agent, kubeconfig, basic validation)
- Phase 2 (US2): Monitoring deployment (Prometheus + Grafana via Helm, dashboards, scrape targets)
- tasks.md will have separate phases for cluster and monitoring
- Constitution Check marks Principle IV as "DEFERRED" (not "VIOLATED")

---

## Summary of Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **K3s Mode** | Single-server (not HA) | Preserves worker capacity for workload testing; HA learned in feature 001 |
| **Datastore** | SQLite (not etcd) | Simpler, zero config, adequate for 2-node learning cluster |
| **Network** | Eero flat network (no VLANs) | FortiGate offline, Eero doesn't support VLANs; temporary until migration |
| **OpenTofu State** | Local file (not remote backend) | Solo operator, MVP simplicity, rapid iteration |
| **Connectivity** | Hybrid (support Ethernet + WiFi) | Flexibility for operators; recommend Ethernet for master1 |
| **Monitoring** | Deferred to Phase 2 (US2) | Faster MVP unblocking; phased learning approach |

**Constitution Alignment**: These decisions intentionally trade HA and network security (Principles V, VI, IX) for rapid learning unblocking. All trade-offs are documented, temporary, and have clear migration paths to full compliance via feature 001.

**Next Phase**: Proceed to Phase 1 (Design) to generate data-model.md, contracts/, and quickstart.md based on these architectural decisions.
