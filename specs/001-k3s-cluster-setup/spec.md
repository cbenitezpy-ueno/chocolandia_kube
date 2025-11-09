# Feature Specification: K3s HA Cluster Setup - ChocolandiaDC

**Feature Branch**: `001-k3s-cluster-setup`
**Created**: 2025-11-08
**Status**: Draft
**Input**: User description: "quiero crear cluster, se va a llamar chocolandiadc, los nodos se van a llamar nodoX donde x es un numero y masterX, igual que nodos"

## Clarifications

### Session 2025-11-08

- Q: Alcance del Homelab → A: Homelab completo: FortiGate + VLANs + Cluster K3s + servicios adicionales (DNS, storage, etc.)
- Q: Rol del FortiGate en el Homelab → A: Edge firewall + router con VLANs (segmentación de red: management, cluster, DMZ, servicios)
- Q: Cantidad Total de Hardware → A: 6 dispositivos: 3 Lenovo mini computers, 1 HP ProDesk mini, 1 FortiGate 100D, 1 Raspberry Pi
- Q: Distribución de Roles de Hardware → A: 3 control-plane (3 Lenovo) + 1 worker (HP ProDesk) + Raspberry Pi para servicios auxiliares (DNS, Pi-hole, jump host)
- Q: Gestión de FortiGate con OpenTofu → A: Todo con OpenTofu: FortiGate (VLANs, firewall, routing) + cluster K3s + servicios (IaC completo)
- Q: FortiGate Initial Bootstrap Method → A: Manual initial GUI setup, then OpenTofu takes over - Initial configuration via GUI to enable API access, then all subsequent configuration managed via OpenTofu
- Q: Backup & Recovery Strategy → A: Daily automated backups to local NAS/external drive - Automated daily snapshots for OpenTofu state, etcd, and FortiGate config stored on local network storage
- Q: Alert Severity Classification → A: Critical: infrastructure down, Warning: resource thresholds, Info: normal operations - Three-tier classification for escalation and response priority
- Q: Network Subnet Ranges → A: Management 10.0.10.0/24, Cluster 10.0.20.0/24, Services 10.0.30.0/24, DMZ 10.0.40.0/24 - Sequential numbering matching VLAN IDs
- Q: Worker Node Expansion Limit → A: Maximum 3 workers (nodo1-3) - Balanced cluster topology (3 control-plane + 3 workers) suitable for homelab learning
- Q: FortiGate Network Topology → A: FortiGate WAN connects to Eero mesh (office node), not directly to internet. Port forwarding configured for Grafana, Prometheus, and Pi-hole admin access from Eero WiFi network

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Initial Cluster Bootstrap (Priority: P1)

As an infrastructure operator, I need to provision a basic K3s cluster with a single control-plane node (master1) so that I have a working Kubernetes API to build upon.

**Why this priority**: The first control-plane node is the foundation of the entire cluster. Without it, no other nodes can join, and no workloads can be deployed. This is the absolute minimum viable cluster.

**Independent Test**: Can be fully tested by deploying the first control-plane node and verifying that `kubectl get nodes` shows master1 in Ready state, and that the Kubernetes API is accessible. Delivers a functional single-node cluster.

**Acceptance Scenarios**:

1. **Given** no existing cluster infrastructure, **When** Terraform provisions the first control-plane node (master1), **Then** the node boots successfully, K3s control-plane starts, and the Kubernetes API is accessible
2. **Given** master1 is running, **When** executing `kubectl get nodes` against the cluster, **Then** master1 appears with status Ready and role control-plane
3. **Given** master1 is operational, **When** deploying a test pod, **Then** the pod schedules successfully and reaches Running state

---

### User Story 2 - High Availability Control Plane (Priority: P2)

As an infrastructure operator, I need to add additional control-plane nodes (master2, master3) to achieve high availability, so that the cluster survives single node failures without losing the Kubernetes API.

**Why this priority**: HA configuration is critical for production-grade clusters and is a primary learning goal. However, it depends on the initial cluster being operational first.

**Independent Test**: Can be tested by joining master2 and master3 to the existing cluster, then simulating master1 failure (shutdown or network partition) and verifying that the Kubernetes API remains accessible and operational.

**Acceptance Scenarios**:

1. **Given** master1 is running, **When** Terraform provisions master2 and master3 with K3s control-plane configuration, **Then** both nodes join the cluster and etcd quorum is established (3/3 nodes)
2. **Given** all three control-plane nodes are running, **When** master1 is shut down, **Then** the Kubernetes API remains accessible via master2 or master3, and etcd maintains quorum (2/3 nodes)
3. **Given** all three control-plane nodes are operational, **When** executing `kubectl get nodes`, **Then** all three master nodes appear with status Ready and role control-plane

---

### User Story 3 - Worker Node Addition (Priority: P3)

As an infrastructure operator, I need to add worker nodes (nodo1, nodo2, nodo3) to the cluster so that I have dedicated compute capacity for running application workloads separate from the control plane.

**Why this priority**: Worker nodes provide additional compute capacity and follow best practices of separating control-plane from workload execution. However, the cluster is functional without them (control-plane nodes can run workloads in learning environments).

**Independent Test**: Can be tested by joining worker nodes to the existing HA cluster and deploying workloads that schedule specifically on worker nodes (using node selectors or taints/tolerations).

**Acceptance Scenarios**:

1. **Given** the HA control-plane cluster is running (master1, master2, master3), **When** Terraform provisions worker nodes (nodo1, nodo2, nodo3), **Then** all worker nodes join the cluster successfully
2. **Given** worker nodes are joined, **When** executing `kubectl get nodes`, **Then** all worker nodes appear with status Ready and role worker/agent
3. **Given** worker nodes are operational, **When** deploying a workload with node affinity for workers, **Then** pods schedule exclusively on nodo1, nodo2, or nodo3 and not on master nodes

---

### User Story 4 - Monitoring Stack Deployment (Priority: P4)

As an infrastructure operator, I need Prometheus and Grafana deployed and configured in the cluster so that I can observe cluster health, resource usage, and learn about Kubernetes monitoring.

**Why this priority**: Observability is essential for learning and operations, but it requires a functional cluster with compute capacity. This is an enhancement to the base cluster.

**Independent Test**: Can be tested by verifying that Prometheus is scraping metrics from all cluster nodes and K3s components, and that Grafana dashboards display cluster health data. Delivers full observability.

**Acceptance Scenarios**:

1. **Given** the cluster is fully operational (control-plane + workers), **When** Terraform deploys Prometheus and Grafana via Helm charts, **Then** both applications reach Running state and are accessible via defined ingress/NodePort
2. **Given** Prometheus is deployed, **When** checking Prometheus targets, **Then** all cluster nodes (master1-3, nodo1-3) and K3s components (kubelet, apiserver, etcd) appear as active targets
3. **Given** Grafana is deployed, **When** accessing pre-configured dashboards, **Then** dashboards display real-time metrics for cluster CPU, memory, network, and storage usage
4. **Given** the monitoring stack is operational, **When** a node goes offline, **Then** Prometheus alerts fire and Grafana dashboards reflect the node's unavailability

---

### Network Topology Diagram

```
Internet
   │
   ├─── Eero Mesh Network (192.168.4.0/24)
   │        │
   │        ├─── Eero Office Node
   │        │         │
   │        │         └─── FortiGate 100D WAN (192.168.4.50 - DHCP/Static)
   │        │                   │
   │        │                   ├─── Management VLAN 10 (10.0.10.0/24)
   │        │                   │         └─── FortiGate Management (10.0.10.1)
   │        │                   │
   │        │                   ├─── Cluster VLAN 20 (10.0.20.0/24)
   │        │                   │         ├─── master1 (10.0.20.11)
   │        │                   │         ├─── master2 (10.0.20.12)
   │        │                   │         ├─── master3 (10.0.20.13)
   │        │                   │         └─── nodo1 (10.0.20.21)
   │        │                   │
   │        │                   ├─── Services VLAN 30 (10.0.30.0/24)
   │        │                   │         ├─── Raspberry Pi (10.0.30.10)
   │        │                   │         │         ├─── Pi-hole (DNS)
   │        │                   │         │         ├─── Jump Host (SSH)
   │        │                   │         │         └─── Internal DNS
   │        │                   │         ├─── Prometheus (10.0.30.20)
   │        │                   │         └─── Grafana (10.0.30.21)
   │        │                   │
   │        │                   └─── DMZ VLAN 40 (10.0.40.0/24)
   │        │                             └─── (Future: exposed services)
   │        │
   │        └─── WiFi Devices (Laptop, Phone, etc.)
   │                  │
   │                  └─── Access via Port Forwarding:
   │                            - 192.168.4.50:3000 → Grafana
   │                            - 192.168.4.50:9090 → Prometheus
   │                            - 192.168.4.50:8080 → Pi-hole Admin
```

**Key Points**:
- FortiGate performs double NAT (Eero NAT + FortiGate NAT for VLANs)
- No static routes needed in Eero (port forwarding on FortiGate provides access)
- All VLAN traffic isolated, inter-VLAN routing controlled by FortiGate firewall
- From Eero WiFi network: access monitoring via FortiGate WAN IP + port

### Edge Cases

- What happens when a control-plane node loses network connectivity during cluster bootstrap? (Cluster creation should fail gracefully with clear error messages, allowing retry)
- What happens when etcd quorum is lost (2 out of 3 control-plane nodes fail simultaneously)? (Cluster API becomes read-only, no new workloads can be scheduled until quorum is restored)
- What happens when Terraform state is corrupted or lost? (Cluster becomes unmanaged; recovery requires importing existing resources or rebuilding from scratch)
- What happens when a mini-PC runs out of disk space? (K3s components may fail, pods may be evicted; monitoring should alert before critical thresholds)
- What happens when trying to join a node with an incorrect cluster token? (Node join fails with authentication error; Terraform should detect and report the failure)
- What happens when network configuration conflicts exist (duplicate IPs, incorrect subnets)? (Cluster networking fails; nodes appear NotReady; requires network troubleshooting)
- What happens when Eero mesh network goes down or office node loses connectivity? (FortiGate WAN loses internet access, cluster remains operational internally but cannot download images or reach external services; monitoring should alert on WAN connectivity loss)

## Requirements *(mandatory)*

### Functional Requirements

#### Network Infrastructure (FortiGate)
- **FR-000**: Operator MUST perform initial FortiGate bootstrap via GUI (WAN IP from Eero subnet, admin password, API access enablement) before OpenTofu provisioning begins
- **FR-001**: System MUST configure FortiGate 100D with VLANs for network segmentation: Management VLAN 10 (10.0.10.0/24), Cluster VLAN 20 (10.0.20.0/24), Services VLAN 30 (10.0.30.0/24), DMZ VLAN 40 (10.0.40.0/24)
- **FR-002**: System MUST configure FortiGate firewall rules to allow K3s cluster communication (API TCP 6443, etcd TCP 2379-2380, VXLAN UDP 8472, kubelet TCP 10250)
- **FR-003**: System MUST configure FortiGate DHCP server with static reservations for all homelab devices (3 Lenovo on Cluster VLAN, 1 HP ProDesk on Cluster VLAN, Raspberry Pi on Services VLAN)
- **FR-004**: System MUST configure FortiGate routing between VLANs with appropriate security policies (default deny, explicit allow rules for required traffic)
- **FR-005**: System MUST use OpenTofu with FortiOS provider to manage all FortiGate configuration after initial bootstrap
- **FR-005a**: System MUST configure FortiGate WAN interface to obtain IP from Eero mesh network (DHCP or static reservation in Eero subnet, typically 192.168.4.0/24)
- **FR-005b**: System MUST configure port forwarding (Virtual IPs) on FortiGate WAN for external access: Grafana (TCP 3000 → Services VLAN Grafana), Prometheus (TCP 9090 → Services VLAN Prometheus), Pi-hole Admin (TCP 8080 → Services VLAN Pi-hole:80)

#### Cluster Infrastructure (K3s)
- **FR-006**: System MUST provision a K3s cluster named "chocolandiadc" across 4 mini-PC nodes initially (3 Lenovo + 1 HP ProDesk), expandable to maximum 6 nodes (3 control-plane + 3 workers)
- **FR-007**: System MUST create control-plane nodes with hostnames master1, master2, and master3 on Lenovo mini computers (3 control-plane nodes for HA)
- **FR-008**: System MUST create worker node with hostname nodo1 on HP ProDesk mini initially (1 dedicated worker node), with support for adding nodo2 and nodo3 up to 3 total workers
- **FR-009**: System MUST configure K3s in HA mode with embedded etcd across all control-plane nodes
- **FR-010**: System MUST ensure the Kubernetes API is accessible and load-balanced across all control-plane nodes

#### Auxiliary Services (Raspberry Pi)
- **FR-011**: System MUST configure Raspberry Pi as services node with hostname "services" for auxiliary services
- **FR-012**: System MUST deploy Pi-hole on Raspberry Pi for network-wide DNS ad-blocking
- **FR-013**: System MUST configure jump host/bastion on Raspberry Pi for secure SSH access to cluster nodes
- **FR-014**: System MUST configure DNS server on Raspberry Pi for homelab internal DNS resolution

#### Monitoring & Observability
- **FR-015**: System MUST deploy Prometheus for metrics collection from all cluster nodes and K3s components
- **FR-016**: System MUST deploy Grafana with pre-configured dashboards for cluster observability
- **FR-017**: System MUST configure resource limits for Prometheus and Grafana to prevent resource exhaustion
- **FR-017a**: System MUST configure Prometheus alerts with three severity levels: Critical (infrastructure down - node offline, etcd quorum lost, API unavailable), Warning (resource thresholds - high CPU/memory/disk, approaching limits), Info (normal operations - backups completed, configuration changes)

#### Infrastructure as Code
- **FR-018**: System MUST use OpenTofu as the exclusive provisioning and configuration tool for all infrastructure
- **FR-019**: System MUST store OpenTofu state in a persistent location (local file or remote backend)
- **FR-020**: System MUST validate infrastructure health after each provisioning step (network connectivity, nodes Ready, services operational)
- **FR-020a**: System MUST perform automated daily backups of OpenTofu state to local NAS/external drive
- **FR-020b**: System MUST perform automated daily backups of etcd snapshots to local NAS/external drive
- **FR-020c**: System MUST perform automated daily backups of FortiGate configuration to local NAS/external drive

#### Security & Access
- **FR-021**: System MUST generate and securely manage the K3s cluster token for node joining
- **FR-022**: System MUST configure kubectl context to access the chocolandiadc cluster
- **FR-023**: System MUST implement Kubernetes RBAC with secure default permissions
- **FR-024**: System MUST configure SSH key-based authentication for all nodes (no password authentication)

### Assumptions

- **A-001**: All 4 mini-PCs (3 Lenovo + 1 HP ProDesk) are on the same local network with SSH access enabled
- **A-002**: Each mini-PC has a static IP address or DHCP reservation configured via FortiGate DHCP server (IPs do not change across reboots)
- **A-003**: Mini-PCs run Ubuntu Server LTS (22.04 or 24.04 recommended)
- **A-004**: Each mini-PC has sufficient resources: minimum 2 CPU cores, 4GB RAM, 20GB disk space
- **A-005**: SSH keys for passwordless authentication are configured on all mini-PCs and Raspberry Pi
- **A-006**: OpenTofu is installed on the control machine (laptop/workstation) from which provisioning is executed
- **A-007**: kubectl is installed on the control machine for cluster interaction
- **A-008**: Internet connectivity is available for downloading K3s binaries, Helm charts, and container images
- **A-009**: The operator has root/sudo access on all mini-PCs and Raspberry Pi for K3s installation
- **A-010**: Cluster name "chocolandiadc" is unique and does not conflict with existing kubeconfig contexts
- **A-011**: FortiGate 100D has completed initial manual bootstrap via GUI (WAN IP assigned from Eero subnet, admin password set, FortiOS API enabled, API admin user created with token) before OpenTofu provisioning begins
- **A-011a**: Eero mesh network provides connectivity to internet and has DHCP enabled for FortiGate WAN interface (typical subnet: 192.168.4.0/24 or similar)
- **A-012**: Raspberry Pi runs Raspberry Pi OS or Ubuntu Server and has sufficient resources for auxiliary services (Pi-hole, DNS, jump host)
- **A-013**: Local NAS or external drive is available on the network for automated daily backups (OpenTofu state, etcd snapshots, FortiGate config), accessible via NFS or SMB

### Key Entities

#### Network Infrastructure
- **Eero Mesh Network**: Primary home network providing internet connectivity and WiFi coverage. FortiGate WAN interface connects to Eero office node (typical subnet: 192.168.4.0/24).
- **FortiGate 100D**: Edge firewall and router providing network segmentation via VLANs, firewall rules, DHCP services, and inter-VLAN routing. WAN interface connects to Eero mesh, LAN interfaces serve VLANs. Managed via OpenTofu FortiOS provider.
- **VLANs**: Network segments for traffic isolation with assigned subnets:
  - Management VLAN 10 (10.0.10.0/24): Admin access to FortiGate, jump host, infrastructure management
  - Cluster VLAN 20 (10.0.20.0/24): K3s nodes communication (API, etcd, pod network)
  - Services VLAN 30 (10.0.30.0/24): Auxiliary services (Pi-hole, DNS, internal services)
  - DMZ VLAN 40 (10.0.40.0/24): Exposed services accessible from internet (if enabled)
- **DHCP Reservations**: Static IP mappings configured on FortiGate for all homelab devices (mini-PCs on Cluster VLAN, Raspberry Pi on Services VLAN, management interfaces on Management VLAN).
- **Port Forwarding (Virtual IPs)**: FortiGate WAN interface exposes monitoring services to Eero network:
  - FortiGate WAN IP:3000 → Grafana (10.0.30.X:3000)
  - FortiGate WAN IP:9090 → Prometheus (10.0.30.X:9090)
  - FortiGate WAN IP:8080 → Pi-hole Admin (10.0.30.10:80)

#### Cluster Infrastructure
- **Cluster (chocolandiadc)**: The logical Kubernetes cluster comprising all nodes, control-plane components, and networking. Identified by cluster name and API endpoint. Initial deployment: 4 nodes (3 control-plane + 1 worker). Maximum supported: 6 nodes (3 control-plane + 3 workers).
- **Control-Plane Node (master1, master2, master3)**: Lenovo mini computers running K3s control-plane components (API server, scheduler, controller manager, etcd). Participate in etcd quorum and serve the Kubernetes API.
- **Worker Node (nodo1, nodo2, nodo3)**: Mini computers running K3s agent for executing workload pods. Initial deployment includes nodo1 (HP ProDesk), expandable to nodo2 and nodo3 (maximum 3 workers total). Workers do not participate in control-plane or etcd operations.
- **K3s Cluster Token**: Shared secret used for authenticating nodes when joining the cluster. Must be securely distributed to all nodes.
- **Etcd Cluster**: Distributed key-value store providing cluster state persistence. Runs embedded within K3s control-plane nodes. Requires 3 replicas for quorum.

#### Auxiliary Services
- **Services Node (Raspberry Pi)**: Raspberry Pi device providing auxiliary homelab services (Pi-hole DNS, jump host, internal DNS server).
- **Pi-hole**: Network-wide DNS ad-blocking and DNS server running on Raspberry Pi.
- **Jump Host/Bastion**: SSH bastion on Raspberry Pi for secure access to cluster nodes.

#### Monitoring & Observability
- **Prometheus Instance**: Monitoring application deployed as a pod, configured to scrape metrics from all cluster nodes and components. Stores time-series data.
- **Grafana Instance**: Visualization application deployed as a pod, configured to query Prometheus and display dashboards. Provides web UI for observability.

#### Infrastructure as Code
- **OpenTofu State**: Persistent record of managed infrastructure. Tracks FortiGate configuration, K3s cluster resources, and auxiliary services provisioning.
- **Kubeconfig**: Configuration file containing cluster API endpoint, authentication credentials, and kubectl context for accessing chocolandiadc.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Cluster bootstrap completes successfully within 15 minutes from Terraform initialization to all nodes Ready
- **SC-002**: All 4 nodes (master1, master2, master3, nodo1) appear in `kubectl get nodes` with status Ready within 5 minutes of the last node joining
- **SC-003**: Kubernetes API remains accessible and responsive (responds to `kubectl get nodes` in under 2 seconds) after simulating single control-plane node failure
- **SC-004**: Prometheus successfully scrapes metrics from all 4 cluster nodes and all K3s components (100% target availability in Prometheus UI)
- **SC-005**: Grafana dashboards load within 3 seconds and display real-time cluster metrics (CPU, memory, network) for all nodes
- **SC-006**: Test workload (nginx pod) deploys successfully and reaches Running state within 60 seconds on any cluster node
- **SC-007**: Cluster survives master1 shutdown without service interruption (API remains available, existing pods continue running)
- **SC-008**: Terraform state accurately reflects all provisioned resources (no drift detected by `terraform plan` after successful apply)
- **SC-009**: Operator can access the cluster via kubectl from the control machine without manual configuration (kubeconfig auto-generated)
- **SC-010**: All infrastructure can be destroyed and recreated using Terraform commands (`terraform destroy` followed by `terraform apply`) with identical results
- **SC-011**: Documentation includes runbook for cluster recovery that can be executed by a new operator in under 30 minutes
- **SC-012**: Monitoring alerts fire within 2 minutes when a node becomes NotReady with Critical severity (validates alerting functionality and severity classification)

### Learning Outcomes

- **LO-001**: Operator understands K3s HA architecture and can explain how etcd quorum works
- **LO-002**: Operator can troubleshoot common cluster issues using kubectl and Prometheus/Grafana
- **LO-003**: Operator can modify Terraform code to add/remove nodes or change cluster configuration
- **LO-004**: Operator can demonstrate cluster resilience by simulating node failures and observing recovery
