# Feature Specification: K3s MVP - 2-Node Cluster on Eero Network

**Feature Branch**: `002-k3s-mvp-eero`
**Created**: 2025-11-09
**Status**: Draft
**Input**: User description: "MVP de K3s con 2 nodos conectados directamente a Eero sin FortiGate, expandible posteriormente"

## Context

FortiGate 100D has power supply issues requiring repair (estimated: several weeks). This MVP specification defines a simplified K3s cluster deployment to begin learning and testing while the FortiGate is out of service.

**Migration Path**: This MVP is designed to be expandable. When FortiGate is repaired, nodes can be migrated to the full architecture defined in feature 001-k3s-cluster-setup with VLANs, firewall segmentation, and HA control-plane.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Two-Node K3s Cluster Deployment (Priority: P1) 🎯 MVP

As an infrastructure operator, I need to deploy a functional K3s cluster with 2 nodes (1 control-plane + 1 worker) connected directly to my existing Eero mesh network, so that I can start learning Kubernetes operations and deploy test workloads while waiting for FortiGate repair.

**Why this priority**: Minimal viable cluster to begin hands-on learning. Unblocks progress while hardware issues are resolved.

**Independent Test**: Deploy 2 mini-PCs to Eero network, provision K3s, verify both nodes appear Ready in `kubectl get nodes`, and deploy a test workload that runs successfully.

**Acceptance Scenarios**:

1. **Given** 2 mini-PCs connected to Eero mesh network via Ethernet or WiFi, **When** OpenTofu provisions the first node as K3s control-plane, **Then** the node boots successfully, K3s server starts, and Kubernetes API is accessible from operator laptop on same Eero network
2. **Given** control-plane node is operational, **When** second node joins as K3s worker (agent), **Then** both nodes appear in `kubectl get nodes` with Ready status (1 control-plane, 1 worker/agent)
3. **Given** 2-node cluster is operational, **When** deploying a test workload (nginx pod), **Then** the pod schedules on the worker node and reaches Running state within 60 seconds

---

### User Story 2 - Basic Monitoring with Prometheus + Grafana (Priority: P2)

As an infrastructure operator, I need basic monitoring deployed on the 2-node cluster so that I can observe resource usage and cluster health while learning Kubernetes observability patterns.

**Why this priority**: Observability is essential for learning. Simplified monitoring setup without HA requirements.

**Independent Test**: Deploy Prometheus + Grafana via Helm, verify metrics are collected from both nodes, and access Grafana dashboards from laptop on Eero network.

**Acceptance Scenarios**:

1. **Given** 2-node cluster is operational, **When** Helm deploys Prometheus and Grafana, **Then** both applications reach Running state and are accessible via NodePort or port-forward
2. **Given** Prometheus is deployed, **When** checking Prometheus targets, **Then** both cluster nodes (control-plane and worker) appear as active scrape targets
3. **Given** Grafana is deployed, **When** accessing pre-configured dashboards, **Then** dashboards display real-time CPU, memory, and network metrics for both nodes

---

### User Story 3 - Future Expansion Preparation (Priority: P3)

As an infrastructure operator, I need the cluster architecture documented for future expansion so that when FortiGate is repaired, I can migrate nodes to the full HA setup with VLANs and add additional nodes.

**Why this priority**: Ensures MVP is not a throwaway effort. Clear migration path to production-grade architecture.

**Independent Test**: Documentation includes migration runbook describing steps to move from Eero flat network to FortiGate VLANs without data loss.

**Acceptance Scenarios**:

1. **Given** MVP cluster is operational, **When** reviewing architecture documentation, **Then** migration steps are clearly defined for adding FortiGate, creating VLANs, and moving nodes to segmented network
2. **Given** migration runbook exists, **When** executing preparation steps (backup etcd, document current IPs, test kubeconfig portability), **Then** all prerequisites for migration are validated and ready
3. **Given** future expansion is planned, **When** FortiGate becomes available, **Then** operator can execute migration with minimal cluster downtime (< 30 minutes)

---

### Edge Cases

- What happens when one of the 2 nodes loses Eero WiFi connectivity during bootstrap? (Cluster creation fails gracefully; operator must ensure stable Ethernet connections for critical nodes)
- What happens when the single control-plane node fails? (Cluster API becomes unavailable; no HA in MVP - documented limitation)
- What happens when Eero mesh network goes down? (Both nodes lose internet connectivity; cluster remains internally functional but cannot pull images or reach external services)
- What happens when migrating from Eero flat network to FortiGate VLANs? (Nodes must be reconfigured with new IPs; migration runbook provides step-by-step procedure with backup/restore)
- What happens if additional nodes connect via WiFi instead of Ethernet? (Performance may degrade; latency and packet loss risks documented; Ethernet strongly recommended for control-plane)

## Requirements *(mandatory)*

### Functional Requirements

#### Cluster Infrastructure (K3s on Eero Network)
- **FR-001**: System MUST provision a K3s cluster with 2 nodes: 1 control-plane (server) and 1 worker (agent) connected to Eero mesh network
- **FR-002**: System MUST configure control-plane node with hostname "master1" obtaining IP from Eero DHCP (typical range: 192.168.4.0/24)
- **FR-003**: System MUST configure worker node with hostname "nodo1" obtaining IP from Eero DHCP
- **FR-004**: System MUST configure K3s in single-server mode (no HA, no embedded etcd quorum) for MVP simplicity
- **FR-005**: System MUST ensure Kubernetes API is accessible from operator laptop on Eero network (no firewall restrictions)
- **FR-006**: System MUST support both Ethernet and WiFi connectivity to Eero mesh network (Ethernet strongly recommended for control-plane)

#### Monitoring & Observability (Simplified)
- **FR-007**: System MUST deploy Prometheus for metrics collection from both cluster nodes
- **FR-008**: System MUST deploy Grafana with basic dashboards for cluster observability (CPU, memory, network)
- **FR-009**: System MUST configure Prometheus scrape targets for kubelet and node-exporter on both nodes
- **FR-010**: System SHOULD expose Grafana via NodePort on port 30000 for easy access from Eero network (or via port-forward)

#### Infrastructure as Code (Simplified)
- **FR-011**: System MUST use OpenTofu as the exclusive provisioning tool for cluster infrastructure
- **FR-012**: System MUST store OpenTofu state locally (no remote backend required for MVP)
- **FR-013**: System MUST validate cluster health after provisioning (nodes Ready, pods Running)

#### Future Expansion Readiness
- **FR-014**: System MUST document current node IPs, cluster token, and kubeconfig for future migration
- **FR-015**: System MUST provide migration runbook describing steps to integrate with FortiGate VLANs when available
- **FR-016**: System SHOULD tag resources with "mvp-temporary" label to identify components requiring reconfiguration during migration

### Assumptions

- **A-001**: 2 mini-PCs (preferably Lenovo or HP ProDesk from original spec) are available and functional
- **A-002**: Both mini-PCs can connect to Eero mesh network via Ethernet (preferred) or WiFi
- **A-003**: Eero mesh network provides DHCP with stable IP assignments (IPs may change on reboot but cluster can tolerate this in MVP)
- **A-004**: Each mini-PC has minimum resources: 2 CPU cores, 4GB RAM, 20GB disk space
- **A-005**: SSH keys for passwordless authentication are configured on both mini-PCs
- **A-006**: OpenTofu is installed on operator laptop/workstation
- **A-007**: kubectl is installed on operator laptop
- **A-008**: Internet connectivity is available via Eero for downloading K3s binaries, Helm charts, container images
- **A-009**: Operator has root/sudo access on both mini-PCs for K3s installation
- **A-010**: FortiGate 100D is temporarily out of service; this MVP will be migrated to full architecture (feature 001) when FortiGate is repaired
- **A-011**: Operator accepts single point of failure (no HA control-plane) as acceptable risk for MVP learning environment
- **A-012**: Raspberry Pi is not required for MVP (can be added later for auxiliary services)

### Key Entities

#### Cluster Infrastructure
- **Cluster (chocolandiadc-mvp)**: Logical Kubernetes cluster with 2 nodes connected to Eero flat network. Single control-plane (no HA). Temporary configuration for learning.
- **Control-Plane Node (master1)**: Mini-PC running K3s server components (API server, scheduler, controller manager). No embedded etcd (uses SQLite for simplicity). Connected to Eero via Ethernet or WiFi with DHCP IP.
- **Worker Node (nodo1)**: Mini-PC running K3s agent for workload execution. Does not participate in control-plane. Connected to Eero via Ethernet or WiFi with DHCP IP.
- **K3s Cluster Token**: Shared secret for node joining. Retrieved from master1 after installation, used by nodo1 to join cluster.

#### Network Infrastructure
- **Eero Mesh Network**: Primary home network providing connectivity and DHCP (typical subnet: 192.168.4.0/24). All cluster nodes and operator laptop connect to this flat network without VLANs or segmentation.

#### Monitoring & Observability (Simplified)
- **Prometheus Instance**: Lightweight monitoring application deployed as pod on worker node. Scrapes metrics from both nodes (kubelet, node-exporter). Retention: 7 days (reduced from 15 days for MVP).
- **Grafana Instance**: Lightweight visualization application deployed as pod on worker node. Basic dashboards for node metrics (CPU, memory, disk, network). Accessible via NodePort 30000 or kubectl port-forward.

#### Infrastructure as Code
- **OpenTofu State (Local)**: Stored in local file terraform.tfstate within environments/chocolandiadc-mvp/ directory. No remote backend (S3, Terraform Cloud) for MVP simplicity.
- **Kubeconfig**: Configuration file for kubectl access. Stored locally at ~/.kube/config or custom path. Contains Eero network IP of master1 as API endpoint.

#### Migration Artifacts
- **Migration Runbook**: Document describing step-by-step procedure to migrate from Eero flat network to FortiGate VLAN architecture when hardware is repaired.
- **Backup Snapshot**: Pre-migration backup containing etcd data (if SQLite), OpenTofu state, current node IP mappings, and kubeconfig.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Cluster bootstrap completes successfully within 10 minutes from OpenTofu initialization to both nodes Ready
- **SC-002**: Both nodes (master1, nodo1) appear in `kubectl get nodes` with status Ready within 3 minutes of nodo1 joining
- **SC-003**: Kubernetes API is accessible from operator laptop on Eero network without additional network configuration
- **SC-004**: Test workload (nginx pod) deploys successfully and reaches Running state within 60 seconds
- **SC-005**: Prometheus successfully scrapes metrics from both nodes (100% target availability in Prometheus UI)
- **SC-006**: Grafana dashboards load within 3 seconds and display real-time metrics for both nodes
- **SC-007**: Operator can access Grafana from laptop browser via http://[master1-or-nodo1-ip]:30000 (NodePort)
- **SC-008**: OpenTofu state accurately reflects provisioned resources (no drift detected by `tofu plan` after apply)
- **SC-009**: Migration runbook is complete with tested backup/restore procedures before attempting FortiGate integration
- **SC-010**: Cluster survives master1 reboot (SQLite data persists, cluster recovers automatically within 5 minutes)

### Learning Outcomes

- **LO-001**: Operator understands K3s single-server architecture and limitations (no HA, SQLite datastore)
- **LO-002**: Operator can deploy and troubleshoot workloads using kubectl
- **LO-003**: Operator can interpret Prometheus metrics and Grafana dashboards for cluster health
- **LO-004**: Operator can modify OpenTofu code to add/remove nodes or change cluster configuration
- **LO-005**: Operator understands migration path from MVP to production HA architecture (feature 001)

