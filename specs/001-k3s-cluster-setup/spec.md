# Feature Specification: K3s HA Cluster Setup - ChocolandiaDC

**Feature Branch**: `001-k3s-cluster-setup`
**Created**: 2025-11-08
**Status**: Draft
**Input**: User description: "quier crear cluster, se va a llamar chocolandiadc, los nodos se van a llamar nodoX donde x es un numero y masterX, igual que nodos"

## Clarifications

### Session 2025-11-08

- Q: Alcance del Homelab → A: Homelab completo: FortiGate + VLANs + Cluster K3s + servicios adicionales (DNS, storage, etc.)
- Q: Rol del FortiGate en el Homelab → A: Edge firewall + router con VLANs (segmentación de red: management, cluster, DMZ, servicios)
- Q: Cantidad Total de Hardware → A: 6 dispositivos: 3 Lenovo mini computers, 1 HP ProDesk mini, 1 FortiGate 100D, 1 Raspberry Pi
- Q: Distribución de Roles de Hardware → A: 3 control-plane (3 Lenovo) + 1 worker (HP ProDesk) + Raspberry Pi para servicios auxiliares (DNS, Pi-hole, jump host)
- Q: Gestión de FortiGate con OpenTofu → A: Todo con OpenTofu: FortiGate (VLANs, firewall, routing) + cluster K3s + servicios (IaC completo)

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

### Edge Cases

- What happens when a control-plane node loses network connectivity during cluster bootstrap? (Cluster creation should fail gracefully with clear error messages, allowing retry)
- What happens when etcd quorum is lost (2 out of 3 control-plane nodes fail simultaneously)? (Cluster API becomes read-only, no new workloads can be scheduled until quorum is restored)
- What happens when Terraform state is corrupted or lost? (Cluster becomes unmanaged; recovery requires importing existing resources or rebuilding from scratch)
- What happens when a mini-PC runs out of disk space? (K3s components may fail, pods may be evicted; monitoring should alert before critical thresholds)
- What happens when trying to join a node with an incorrect cluster token? (Node join fails with authentication error; Terraform should detect and report the failure)
- What happens when network configuration conflicts exist (duplicate IPs, incorrect subnets)? (Cluster networking fails; nodes appear NotReady; requires network troubleshooting)

## Requirements *(mandatory)*

### Functional Requirements

#### Network Infrastructure (FortiGate)
- **FR-001**: System MUST configure FortiGate 100D with VLANs for network segmentation (management, cluster, services, DMZ)
- **FR-002**: System MUST configure FortiGate firewall rules to allow K3s cluster communication (API, etcd, pod network)
- **FR-003**: System MUST configure FortiGate DHCP server with static reservations for all homelab devices
- **FR-004**: System MUST configure FortiGate routing between VLANs with appropriate security policies
- **FR-005**: System MUST use OpenTofu with FortiOS provider to manage FortiGate configuration

#### Cluster Infrastructure (K3s)
- **FR-006**: System MUST provision a K3s cluster named "chocolandiadc" across 4 mini-PC nodes (3 Lenovo + 1 HP ProDesk)
- **FR-007**: System MUST create control-plane nodes with hostnames master1, master2, and master3 on Lenovo mini computers (3 control-plane nodes for HA)
- **FR-008**: System MUST create worker node with hostname nodo1 on HP ProDesk mini (1 dedicated worker node)
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

#### Infrastructure as Code
- **FR-018**: System MUST use OpenTofu as the exclusive provisioning and configuration tool for all infrastructure
- **FR-019**: System MUST store OpenTofu state in a persistent location (local file or remote backend)
- **FR-020**: System MUST validate infrastructure health after each provisioning step (network connectivity, nodes Ready, services operational)

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
- **A-011**: FortiGate 100D has management access configured and FortiOS API enabled for OpenTofu provider
- **A-012**: Raspberry Pi runs Raspberry Pi OS or Ubuntu Server and has sufficient resources for auxiliary services (Pi-hole, DNS, jump host)

### Key Entities

#### Network Infrastructure
- **FortiGate 100D**: Edge firewall and router providing network segmentation via VLANs, firewall rules, DHCP services, and inter-VLAN routing. Managed via OpenTofu FortiOS provider.
- **VLANs**: Network segments for traffic isolation (management VLAN for admin access, cluster VLAN for K3s nodes, services VLAN for auxiliary services, DMZ for exposed services).
- **DHCP Reservations**: Static IP mappings configured on FortiGate for all homelab devices (mini-PCs, Raspberry Pi).

#### Cluster Infrastructure
- **Cluster (chocolandiadc)**: The logical Kubernetes cluster comprising all nodes, control-plane components, and networking. Identified by cluster name and API endpoint.
- **Control-Plane Node (master1, master2, master3)**: Lenovo mini computers running K3s control-plane components (API server, scheduler, controller manager, etcd). Participate in etcd quorum and serve the Kubernetes API.
- **Worker Node (nodo1)**: HP ProDesk mini computer running K3s agent for executing workload pods. Does not participate in control-plane or etcd operations.
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
- **SC-012**: Monitoring alerts fire within 2 minutes when a node becomes NotReady (validates alerting functionality)

### Learning Outcomes

- **LO-001**: Operator understands K3s HA architecture and can explain how etcd quorum works
- **LO-002**: Operator can troubleshoot common cluster issues using kubectl and Prometheus/Grafana
- **LO-003**: Operator can modify Terraform code to add/remove nodes or change cluster configuration
- **LO-004**: Operator can demonstrate cluster resilience by simulating node failures and observing recovery
