# Tasks: K3s HA Cluster Setup - ChocolandiaDC

**Input**: Design documents from `/specs/001-k3s-cluster-setup/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: This feature explicitly requires comprehensive testing as per Constitution Principle VII (Test-Driven Learning). All test tasks are MANDATORY.

**Organization**: Tasks are grouped by phase with network-first deployment following Constitution Principle IX. User stories are implemented sequentially after network infrastructure is validated.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

This is an infrastructure project using OpenTofu modules:
- OpenTofu code: `terraform/modules/`, `terraform/environments/chocolandiadc/`
- Testing scripts: `scripts/`
- Documentation: `docs/runbooks/`, `docs/adrs/`
- Integration tests: `tests/integration/`

**NOTE**: Directory is named `terraform/` for tool compatibility, but all code uses OpenTofu exclusively.

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create project directory structure and initialize OpenTofu workspace

- [ ] T001 Create OpenTofu project structure per plan.md (terraform/modules/, terraform/environments/chocolandiadc/, scripts/, docs/, tests/)
- [ ] T002 Initialize OpenTofu backend configuration in terraform/environments/chocolandiadc/backend.tf (local state initially)
- [ ] T003 [P] Create .gitignore for OpenTofu (exclude terraform.tfstate, .terraform/, *.tfvars with sensitive data)
- [ ] T004 [P] Create .terraform-version file specifying OpenTofu 1.6+ requirement
- [ ] T005 [P] Create README.md in terraform/ directory with project overview and usage instructions
- [ ] T006 [P] Create terraform/modules/README.md explaining module organization

**Checkpoint**: Project structure ready for OpenTofu development

---

## Phase 2: Network Infrastructure (FortiGate) - NETWORK-FIRST DEPLOYMENT

**Purpose**: Configure FortiGate 100D with VLANs, firewall rules, DHCP, and routing BEFORE any cluster work

**CRITICAL**: This phase BLOCKS all subsequent phases. No cluster nodes can be provisioned until network infrastructure is validated.

**Implements**: FR-001 through FR-005 (Network Infrastructure requirements)

### FortiGate Network Module

- [ ] T007 Create fortigate-network module structure in terraform/modules/fortigate-network/ (main.tf, variables.tf, outputs.tf, README.md)
- [ ] T008 Define fortigate-network module variables in terraform/modules/fortigate-network/variables.tf (fortigate_hostname, fortigate_api_token, vlan_config, dhcp_reservations, firewall_rules)
- [ ] T009 Implement FortiOS provider configuration in terraform/modules/fortigate-network/main.tf (provider block with API credentials)
- [ ] T010 Implement VLAN creation in terraform/modules/fortigate-network/main.tf (management VLAN 10, cluster VLAN 20, services VLAN 30, DMZ VLAN 40)
- [ ] T011 Implement DHCP server configuration in terraform/modules/fortigate-network/main.tf with static reservations for all 6 devices (3 Lenovo, 1 HP ProDesk, 1 FortiGate management, 1 Raspberry Pi)
- [ ] T012 Implement firewall policies in terraform/modules/fortigate-network/main.tf for K3s cluster communication (K3s API TCP 6443, etcd TCP 2379-2380, VXLAN UDP 8472, kubelet TCP 10250)
- [ ] T013 Implement firewall policies in terraform/modules/fortigate-network/main.tf for management access (SSH TCP 22 from management VLAN only, DNS UDP 53)
- [ ] T014 Implement inter-VLAN routing configuration in terraform/modules/fortigate-network/main.tf with security policies (cluster VLAN to services VLAN for DNS, management VLAN to all VLANs)
- [ ] T015 Implement default deny firewall policy in terraform/modules/fortigate-network/main.tf (block all traffic not explicitly allowed)
- [ ] T016 Define fortigate-network module outputs in terraform/modules/fortigate-network/outputs.tf (vlan_ids, dhcp_reservation_ips, firewall_policy_ids)
- [ ] T017 Create terraform/modules/fortigate-network/README.md documenting network architecture, VLAN design, and firewall rules

### Network Validation Scripts

- [ ] T018 [P] Create network connectivity validation script scripts/validate-network.sh to test VLAN reachability (ping tests across VLANs, verify DHCP assignments)
- [ ] T019 [P] Create firewall rule validation script scripts/validate-firewall-rules.sh to verify allowed traffic (K3s API, etcd, SSH) and blocked traffic (default deny)
- [ ] T020 [P] Create DHCP reservation validation script scripts/validate-dhcp.sh to verify all 6 devices received correct static IPs

### Network Environment Configuration

- [ ] T021 Create terraform/environments/chocolandiadc/network.tf calling fortigate-network module
- [ ] T022 Add FortiGate configuration variables to terraform/environments/chocolandiadc/terraform.tfvars.example (fortigate_hostname, vlan_subnets, device_ips)
- [ ] T023 Configure FortiOS provider in terraform/environments/chocolandiadc/providers.tf (fortigate hostname, API token from environment variable)

**CHECKPOINT - NETWORK VALIDATION GATE**:
- Run scripts/validate-network.sh and verify all VLANs are reachable
- Run scripts/validate-firewall-rules.sh and verify firewall policies are active
- Run scripts/validate-dhcp.sh and verify all devices have correct IPs
- **NO CLUSTER WORK CAN BEGIN UNTIL THIS CHECKPOINT PASSES**

---

## Phase 3: Foundational (Cluster Modules)

**Purpose**: Core OpenTofu modules for K3s cluster provisioning

**Dependencies**: Phase 2 (Network Infrastructure) MUST be complete and validated

**Implements**: Cluster module foundations for FR-006 through FR-010

### K3s Node Module

- [ ] T024 Create k3s-node module structure in terraform/modules/k3s-node/ (main.tf, variables.tf, outputs.tf, README.md)
- [ ] T025 Define k3s-node module variables in terraform/modules/k3s-node/variables.tf (hostname, ip_address, ssh_user, ssh_key_path, role, is_first_node, cluster_token, k3s_version)
- [ ] T026 Implement SSH connection provisioner in terraform/modules/k3s-node/main.tf (null_resource with remote-exec)
- [ ] T027 Implement K3s control-plane installation logic in terraform/modules/k3s-node/main.tf (install script with --cluster-init for first node, --server for additional control-plane nodes)
- [ ] T028 Implement K3s worker installation logic in terraform/modules/k3s-node/main.tf (install script with --agent flag)
- [ ] T029 Define k3s-node module outputs in terraform/modules/k3s-node/outputs.tf (node_id, node_status, kubeconfig for control-plane nodes)
- [ ] T030 Create terraform/modules/k3s-node/README.md documenting module usage, variables, and outputs

### K3s Cluster Orchestration Module

- [ ] T031 Create k3s-cluster module structure in terraform/modules/k3s-cluster/ (main.tf, variables.tf, outputs.tf, README.md)
- [ ] T032 Define k3s-cluster module variables in terraform/modules/k3s-cluster/variables.tf (cluster_name, k3s_version, control_plane_nodes, worker_nodes)
- [ ] T033 Implement cluster token generation logic in terraform/modules/k3s-cluster/main.tf (retrieve from first control-plane node /var/lib/rancher/k3s/server/node-token)
- [ ] T034 Implement kubeconfig retrieval and processing in terraform/modules/k3s-cluster/main.tf (download from master1 /etc/rancher/k3s/k3s.yaml, update server URL)
- [ ] T035 Implement control-plane node orchestration in terraform/modules/k3s-cluster/main.tf (call k3s-node module for each control-plane node with dependencies)
- [ ] T036 Implement worker node orchestration in terraform/modules/k3s-cluster/main.tf (call k3s-node module for each worker node with depends_on all control-plane nodes)
- [ ] T037 Define k3s-cluster module outputs in terraform/modules/k3s-cluster/outputs.tf (cluster_name, api_endpoint, kubeconfig_path, cluster_token)
- [ ] T038 Create terraform/modules/k3s-cluster/README.md documenting cluster module architecture and usage

### Environment Configuration

- [ ] T039 Create terraform/environments/chocolandiadc/cluster.tf calling k3s-cluster module
- [ ] T040 Define cluster variables in terraform/environments/chocolandiadc/variables.tf (cluster_name, k3s_version, node configurations)
- [ ] T041 Add cluster configuration to terraform/environments/chocolandiadc/terraform.tfvars.example (node IPs from DHCP reservations, SSH user, hostnames)
- [ ] T042 Configure SSH provider in terraform/environments/chocolandiadc/providers.tf (SSH key path from environment variable)
- [ ] T043 Define cluster outputs in terraform/environments/chocolandiadc/outputs.tf (api_endpoint, kubeconfig_path)
- [ ] T044 Create terraform/environments/chocolandiadc/README.md with deployment instructions and prerequisites

**Checkpoint**: OpenTofu foundation ready - cluster modules complete, environment configured

---

## Phase 4: User Story 1 - Initial Cluster Bootstrap (Priority: P1) 🎯 MVP

**Goal**: Deploy a single control-plane node (master1) with a working Kubernetes API

**Independent Test**: Execute `kubectl get nodes` and verify master1 appears as Ready; deploy a test pod and verify it reaches Running state

**Implements**: FR-006, FR-007 (partial - first control-plane node), FR-009 (partial - cluster-init), FR-010 (partial - API accessible)

### Tests for User Story 1 ⚠️ MANDATORY

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T045 [P] [US1] Create validation script scripts/validate-single-node.sh to check master1 node Ready status (kubectl get nodes, verify role control-plane)
- [ ] T046 [P] [US1] Create smoke test script scripts/deploy-test-workload.sh to deploy nginx pod and validate Running state (kubectl apply, kubectl wait)

### Implementation for User Story 1

- [ ] T047 [US1] Update terraform/environments/chocolandiadc/terraform.tfvars to configure single control-plane node (master1 with IP from DHCP reservation, hostname master1, role control-plane, is_first_node true)
- [ ] T048 [US1] Implement first node bootstrap logic in k3s-cluster module to install K3s with --cluster-init flag
- [ ] T049 [US1] Implement cluster token retrieval via SSH from /var/lib/rancher/k3s/server/node-token in k3s-cluster module
- [ ] T050 [US1] Implement kubeconfig download and local storage in terraform/environments/chocolandiadc/kubeconfig
- [ ] T051 [US1] Add OpenTofu provisioner to wait for master1 node Ready status before completion (kubectl wait --for=condition=Ready)
- [ ] T052 [US1] Run scripts/validate-single-node.sh to verify master1 is Ready
- [ ] T053 [US1] Run scripts/deploy-test-workload.sh to verify workload deployment succeeds

**Checkpoint**: Single-node cluster operational - kubectl access verified, test pod deployed successfully

---

## Phase 5: User Story 2 - High Availability Control Plane (Priority: P2)

**Goal**: Add master2 and master3 to establish etcd quorum and HA capability

**Independent Test**: Shutdown master1, verify kubectl still works via master2/master3; verify etcd quorum is 2/3

**Implements**: FR-007 (complete - all 3 control-plane nodes), FR-009 (complete - HA etcd), FR-010 (complete - load-balanced API)

### Tests for User Story 2 ⚠️ MANDATORY

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T054 [P] [US2] Create HA failover test script scripts/test-ha-failover.sh to simulate master1 failure and verify API availability (shutdown master1, kubectl get nodes via master2/master3, verify success)
- [ ] T055 [P] [US2] Create etcd quorum validation script scripts/validate-etcd-quorum.sh to check 3/3 members and quorum status (kubectl exec etcdctl member list, verify health)

### Implementation for User Story 2

- [ ] T056 [US2] Update terraform/environments/chocolandiadc/terraform.tfvars to add master2 and master3 configurations (IPs from DHCP reservations, hostnames master2/master3, role control-plane)
- [ ] T057 [US2] Implement additional control-plane node join logic in k3s-cluster module (--server flag with master1 IP and cluster token)
- [ ] T058 [US2] Add OpenTofu provisioners to wait for all 3 control-plane nodes Ready status (kubectl wait for each node)
- [ ] T059 [US2] Add OpenTofu provisioner to verify etcd quorum established (kubectl exec on master1, etcdctl endpoint health --cluster)
- [ ] T060 [US2] Update kubeconfig handling to include all 3 control-plane IPs for HA API access (update server URL to round-robin or configure kube-vip if needed)
- [ ] T061 [US2] Run scripts/validate-etcd-quorum.sh to verify etcd quorum 3/3
- [ ] T062 [US2] Run scripts/test-ha-failover.sh to verify API survives master1 shutdown

**Checkpoint**: HA control-plane operational - all 3 masters Ready, etcd quorum verified, API survives master1 failure

---

## Phase 6: User Story 3 - Worker Node Addition (Priority: P3)

**Goal**: Add worker node (nodo1) for dedicated workload execution separate from control-plane

**Independent Test**: Deploy workload with node selector for workers, verify pod schedules on nodo1 not on master nodes

**Implements**: FR-008 (complete - worker node nodo1)

### Tests for User Story 3 ⚠️ MANDATORY

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T063 [P] [US3] Create worker node validation script scripts/validate-worker-nodes.sh to verify nodo1 is Ready with worker role (kubectl get nodes, check role and Ready status)
- [ ] T064 [P] [US3] Create workload scheduling test script scripts/test-worker-scheduling.sh to deploy pod with node affinity and verify scheduling on nodo1 (kubectl apply with nodeSelector, verify pod node placement)

### Implementation for User Story 3

- [ ] T065 [US3] Update terraform/environments/chocolandiadc/terraform.tfvars to add nodo1 configuration (IP from DHCP reservation, hostname nodo1, role worker)
- [ ] T066 [US3] Implement worker node join logic in k3s-node module (K3s agent installation with --server and --token flags)
- [ ] T067 [US3] Add OpenTofu provisioner to wait for nodo1 node Ready status (kubectl wait --for=condition=Ready node/nodo1)
- [ ] T068 [US3] Add optional OpenTofu configuration to taint control-plane nodes (NoSchedule) to prevent workload pods on masters (kubectl taint nodes master1-3 node-role.kubernetes.io/control-plane:NoSchedule)
- [ ] T069 [US3] Run scripts/validate-worker-nodes.sh to verify nodo1 is Ready
- [ ] T070 [US3] Run scripts/test-worker-scheduling.sh to verify workloads schedule on nodo1

**Checkpoint**: Worker node operational - nodo1 Ready, workloads schedule on worker, full 4-node cluster functional

---

## Phase 7: User Story 4 - Monitoring Stack Deployment (Priority: P4)

**Goal**: Deploy Prometheus and Grafana for comprehensive cluster observability with alerting

**Independent Test**: Verify Prometheus scrapes all nodes and K3s components; verify Grafana dashboards load with real-time metrics; verify alerts fire within 2 minutes when node becomes NotReady

**Implements**: FR-015, FR-016, FR-017 (Monitoring requirements), SC-012 (alerting requirement)

### Tests for User Story 4 ⚠️ MANDATORY

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T071 [P] [US4] Create Prometheus validation script scripts/validate-prometheus.sh to check all targets are up (curl Prometheus API /api/v1/targets, verify all nodes and K3s components)
- [ ] T072 [P] [US4] Create Grafana validation script scripts/validate-grafana.sh to verify Grafana API health and dashboard accessibility (curl Grafana API /api/health, verify dashboards exist)
- [ ] T073 [P] [US4] Create alerting validation script scripts/validate-alerting.sh to test alert delivery (trigger NodeDown condition, verify alert fires within 2 minutes - SC-012)

### Implementation for User Story 4

- [ ] T074 [US4] Create monitoring-stack module structure in terraform/modules/monitoring-stack/ (main.tf, variables.tf, outputs.tf, README.md, helm-values/)
- [ ] T075 [US4] Define monitoring-stack module variables in terraform/modules/monitoring-stack/variables.tf (namespace, prometheus_retention, prometheus_storage_size, grafana_admin_user, alertmanager_config)
- [ ] T076 [US4] Implement Helm provider configuration in terraform/modules/monitoring-stack/main.tf (using kubeconfig from cluster module)
- [ ] T077 [US4] Implement Prometheus deployment in terraform/modules/monitoring-stack/main.tf (kube-prometheus-stack Helm chart v51.0.0)
- [ ] T078 [US4] Create Prometheus values file in terraform/modules/monitoring-stack/helm-values/prometheus-values.yaml (retention 15 days, storage 10Gi, scrape configs for all K3s components)
- [ ] T079 [US4] Configure Prometheus scrape targets in helm-values/prometheus-values.yaml (kubelet, apiserver, etcd, scheduler, controller-manager, all cluster nodes)
- [ ] T080 [US4] Implement Grafana deployment in terraform/modules/monitoring-stack/main.tf (included in kube-prometheus-stack chart)
- [ ] T081 [US4] Create Grafana values file in terraform/modules/monitoring-stack/helm-values/grafana-values.yaml (admin user, pre-configured dashboards, Prometheus data source)
- [ ] T082 [US4] Configure Grafana dashboards in helm-values/grafana-values.yaml (import Kubernetes cluster overview dashboard, etcd dashboard, node exporter dashboard)
- [ ] T083 [US4] Implement Alertmanager configuration in terraform/modules/monitoring-stack/main.tf (included in kube-prometheus-stack chart)
- [ ] T084 [US4] Create Alertmanager values file in terraform/modules/monitoring-stack/helm-values/alertmanager-values.yaml (configure notification receivers - email, Slack, or webhook)
- [ ] T085 [US4] Create alert rules file in terraform/modules/monitoring-stack/helm-values/alert-rules.yaml (NodeDown, EtcdQuorumLost, HighCPUUsage, HighMemoryUsage, DiskSpaceLow)
- [ ] T086 [US4] Configure alert rules in helm-values/prometheus-values.yaml to reference alert-rules.yaml (ensure alerts are loaded into Prometheus)
- [ ] T087 [US4] Configure resource limits in helm-values/prometheus-values.yaml and helm-values/grafana-values.yaml (Prometheus: 2Gi memory, 1 CPU; Grafana: 512Mi memory, 0.5 CPU - FR-017)
- [ ] T088 [US4] Define monitoring-stack module outputs in terraform/modules/monitoring-stack/outputs.tf (prometheus_url, grafana_url, grafana_admin_password, alertmanager_url)
- [ ] T089 [US4] Update terraform/environments/chocolandiadc/cluster.tf to call monitoring-stack module with depends_on all nodes
- [ ] T090 [US4] Configure Kubernetes and Helm providers in terraform/environments/chocolandiadc/providers.tf (kubeconfig path from cluster module output)
- [ ] T091 [US4] Add OpenTofu provisioner to wait for Prometheus and Grafana pods Running status (kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus)
- [ ] T092 [US4] Create terraform/modules/monitoring-stack/README.md documenting monitoring stack configuration, accessing Grafana, and configuring alerts
- [ ] T093 [US4] Run scripts/validate-prometheus.sh to verify all targets are up
- [ ] T094 [US4] Run scripts/validate-grafana.sh to verify Grafana is accessible and dashboards load
- [ ] T095 [US4] Run scripts/validate-alerting.sh to verify alerts fire within 2 minutes (SC-012)

**Checkpoint**: Monitoring operational - Prometheus scraping all targets, Grafana dashboards display cluster metrics, Alertmanager configured and alerts firing correctly

---

## Phase 8: Auxiliary Services (Raspberry Pi)

**Purpose**: Deploy auxiliary homelab services on Raspberry Pi for DNS, ad-blocking, and jump host access

**Dependencies**: Phase 2 (Network Infrastructure) MUST be complete - Raspberry Pi must be on services VLAN with DHCP reservation

**Implements**: FR-011 through FR-014 (Auxiliary Services requirements)

### Raspberry Pi Services Module

- [ ] T096 Create raspberry-pi-services module structure in terraform/modules/raspberry-pi-services/ (main.tf, variables.tf, outputs.tf, README.md)
- [ ] T097 Define raspberry-pi-services module variables in terraform/modules/raspberry-pi-services/variables.tf (pi_hostname, pi_ip_address, pi_ssh_user, pi_ssh_key_path, pihole_version, dns_domains)
- [ ] T098 Implement SSH connection provisioner in terraform/modules/raspberry-pi-services/main.tf (null_resource with remote-exec for Raspberry Pi)
- [ ] T099 Implement Pi-hole installation logic in terraform/modules/raspberry-pi-services/main.tf (install script with docker-compose or native installation)
- [ ] T100 Implement DNS server configuration in terraform/modules/raspberry-pi-services/main.tf (configure dnsmasq or Pi-hole DNS for homelab internal domains)
- [ ] T101 Implement jump host/bastion configuration in terraform/modules/raspberry-pi-services/main.tf (SSH configuration, authorized_keys setup for cluster node access)
- [ ] T102 Define raspberry-pi-services module outputs in terraform/modules/raspberry-pi-services/outputs.tf (pihole_admin_url, dns_server_ip, jump_host_ip)
- [ ] T103 Create terraform/modules/raspberry-pi-services/README.md documenting auxiliary services configuration and usage

### Raspberry Pi Validation Scripts

- [ ] T104 [P] Create Pi-hole validation script scripts/validate-pihole.sh to verify Pi-hole is running and blocking ads (curl Pi-hole admin API, verify DNS resolution)
- [ ] T105 [P] Create DNS validation script scripts/validate-dns.sh to verify internal DNS resolution (nslookup homelab domains via Raspberry Pi DNS)
- [ ] T106 [P] Create jump host validation script scripts/validate-jumphost.sh to verify SSH access to cluster nodes via jump host (ssh through bastion to master1)

### Raspberry Pi Environment Configuration

- [ ] T107 Update terraform/environments/chocolandiadc/services.tf to call raspberry-pi-services module
- [ ] T108 Add Raspberry Pi configuration to terraform/environments/chocolandiadc/terraform.tfvars.example (pi_ip from DHCP reservation, pi_hostname services, SSH user)
- [ ] T109 Run scripts/validate-pihole.sh to verify Pi-hole is operational
- [ ] T110 Run scripts/validate-dns.sh to verify internal DNS resolution
- [ ] T111 Run scripts/validate-jumphost.sh to verify jump host access

**Checkpoint**: Auxiliary services operational - Pi-hole blocking ads, DNS resolving internal domains, jump host accessible for cluster management

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, testing infrastructure, and operational guides

**Dependencies**: All user stories and auxiliary services complete

### Architecture Decision Records

- [ ] T112 [P] Create Architecture Decision Record docs/adrs/001-opentofu-over-terraform.md documenting why OpenTofu was chosen over Terraform (open-source, community-driven, no vendor lock-in)
- [ ] T113 [P] Create Architecture Decision Record docs/adrs/002-fortigate-over-pfsense.md documenting why FortiGate was chosen over pfSense/OPNsense (enterprise features, learning value, IPS/IDS)
- [ ] T114 [P] Create Architecture Decision Record docs/adrs/003-k3s-over-k8s.md documenting why K3s was chosen over full Kubernetes (lightweight, edge-optimized, embedded etcd)
- [ ] T115 [P] Create Architecture Decision Record docs/adrs/004-3plus1-topology.md documenting 3 control-plane + 1 worker topology rationale (etcd quorum, HA learning, hardware constraints)
- [ ] T116 [P] Create Architecture Decision Record docs/adrs/005-vlan-segmentation.md documenting VLAN design (management, cluster, services, DMZ - why each VLAN exists)
- [ ] T117 [P] Create Architecture Decision Record docs/adrs/006-prometheus-grafana-stack.md documenting monitoring stack choice (industry standard, learning value, comprehensive observability)

### Runbooks

- [ ] T118 [P] Create runbook docs/runbooks/cluster-bootstrap.md with step-by-step bootstrap instructions (network first, then cluster, then monitoring, then services)
- [ ] T119 [P] Create runbook docs/runbooks/adding-nodes.md with instructions to add worker nodes (nodo2, nodo3) or additional control-plane nodes
- [ ] T120 [P] Create runbook docs/runbooks/vlan-changes.md with procedures for modifying VLAN configuration (adding VLANs, changing subnets, updating DHCP)
- [ ] T121 [P] Create runbook docs/runbooks/firewall-rules.md with procedures for adding/modifying FortiGate firewall rules (OpenTofu workflow, testing, validation)
- [ ] T122 [P] Create runbook docs/runbooks/disaster-recovery.md with cluster recovery procedures (backup/restore OpenTofu state, etcd snapshots, FortiGate config backup)
- [ ] T123 [P] Create runbook docs/runbooks/troubleshooting.md with common issues and solutions (VLAN connectivity, firewall blocking, cluster networking, DNS failures)
- [ ] T124 [P] Create docs/README.md as documentation index (links to all ADRs, runbooks, and architecture diagrams)

### Validation & Testing Infrastructure

- [ ] T125 Create comprehensive validation script scripts/validate-cluster.sh combining all validation checks (network, nodes, etcd, monitoring, services)
- [ ] T126 Create integration test suite in tests/integration/test-cluster-bootstrap.sh validating full cluster bootstrap (network validation, cluster creation, monitoring deployment)
- [ ] T127 Create integration test in tests/integration/test-ha-quorum.sh validating etcd HA and failover (shutdown nodes, verify quorum, verify API availability)
- [ ] T128 Create integration test in tests/integration/test-monitoring-stack.sh validating Prometheus and Grafana functionality (targets up, dashboards accessible, alerts firing)
- [ ] T129 Create integration test in tests/integration/test-network-security.sh validating firewall rules and VLAN segmentation (allowed traffic succeeds, blocked traffic fails)
- [ ] T130 Create tests/README.md documenting test execution, test coverage, and CI/CD integration
- [ ] T131 Create scripts/README.md documenting all validation and testing scripts

### OpenTofu Best Practices

- [ ] T132 Add OpenTofu fmt validation check to scripts/validate-cluster.sh (tofu fmt -check -recursive)
- [ ] T133 Add OpenTofu validate check to scripts/validate-cluster.sh (tofu validate in all module directories)
- [ ] T134 Configure OpenTofu state backup automation in terraform/environments/chocolandiadc/main.tf (local_file resource for state backups with timestamps)
- [ ] T135 Add .editorconfig file to enforce consistent code formatting (OpenTofu, YAML, Bash - 2 spaces for HCL, 2 spaces for YAML)

### Security & Compliance

- [ ] T136 Document SSH key management procedures in docs/runbooks/cluster-bootstrap.md (key generation, distribution, rotation)
- [ ] T137 Add kubeconfig file permissions enforcement (chmod 0600) in k3s-cluster module after kubeconfig download
- [ ] T138 Configure RBAC validation in scripts/validate-cluster.sh (verify default roles/bindings, verify no overly permissive rules)
- [ ] T139 Add resource limits validation to scripts/validate-cluster.sh (verify Prometheus/Grafana limits applied, verify no pods without limits)
- [ ] T140 Create security audit script scripts/security-audit.sh to validate security posture (firewall rules, SSH config, RBAC, secrets not in Git)

### Quickstart Validation

- [ ] T141 Execute quickstart.md end-to-end on test environment and validate all steps (network setup, cluster bootstrap, monitoring deployment, service deployment)
- [ ] T142 Update quickstart.md with any corrections or clarifications from validation
- [ ] T143 Create quickstart validation checklist in tests/quickstart-validation-checklist.md

---

## Dependencies & Execution Order

### Phase Dependencies (NETWORK-FIRST)

- **Phase 1 (Setup)**: No dependencies - can start immediately
- **Phase 2 (Network Infrastructure - FortiGate)**: Depends on Phase 1 completion - **BLOCKS ALL SUBSEQUENT PHASES**
- **Phase 3 (Foundational)**: Depends on Phase 2 completion and network validation checkpoint - BLOCKS all user stories
- **Phase 4 (User Story 1)**: Depends on Phase 3 completion - No dependencies on other stories
- **Phase 5 (User Story 2)**: Depends on Phase 4 completion (requires master1 as bootstrap node)
- **Phase 6 (User Story 3)**: Depends on Phase 5 completion (requires control-plane HA for production-grade cluster)
- **Phase 7 (User Story 4)**: Depends on Phase 6 completion (requires full cluster with compute capacity)
- **Phase 8 (Auxiliary Services)**: Depends on Phase 2 completion (network infrastructure) - Can run in parallel with user stories if needed
- **Phase 9 (Polish)**: Depends on all user stories and auxiliary services being complete

**CRITICAL NOTE**: Phase 2 (Network Infrastructure) is the foundation. The network validation checkpoint MUST pass before any cluster work begins. This enforces Constitution Principle IX (Network-First Security).

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 3) - Deploys master1 (MVP)
- **User Story 2 (P2)**: DEPENDS on User Story 1 - Requires master1 as bootstrap node for master2/master3 to join
- **User Story 3 (P3)**: DEPENDS on User Story 2 - Worker should join HA cluster (not single-node cluster)
- **User Story 4 (P4)**: DEPENDS on User Story 3 - Monitoring requires full cluster for comprehensive metrics

**NOTE**: Unlike typical user stories that are independent, this infrastructure project has sequential dependencies because:
- Network infrastructure must be validated before cluster nodes can communicate
- Master1 must exist before additional control-plane nodes can join (etcd cluster initialization)
- HA control-plane should be established before adding workers (production best practice)
- Monitoring stack requires compute capacity (all nodes operational)

### Within Each Phase

- Tests MUST be written and FAIL before implementation (Test-Driven Learning principle)
- OpenTofu modules before environment configuration
- Module variables/outputs before main.tf implementation
- Validation provisioners after resource creation
- Documentation after implementation

### Parallel Opportunities

**Phase 1 (Setup)**: T003, T004, T005, T006 can run in parallel (independent file creation)

**Phase 2 (Network Infrastructure)**:
- T018, T019, T020 (validation scripts) can run in parallel before network implementation
- T022, T023 (environment config) depend on module being complete

**Phase 3 (Foundational)**:
- T024-T030 (k3s-node module) can run in parallel with T031-T038 (k3s-cluster module)
- T039-T044 (environment config) depend on modules being complete

**User Story 1**: T045, T046 (test scripts) can run in parallel before implementation

**User Story 2**: T054, T055 (test scripts) can run in parallel before implementation

**User Story 3**: T063, T064 (test scripts) can run in parallel before implementation

**User Story 4**:
- T071, T072, T073 (test scripts) can run in parallel before implementation
- T078, T081, T084, T085 (Helm values files) can run in parallel during implementation

**Phase 8 (Auxiliary Services)**: T104, T105, T106 (validation scripts) can run in parallel before implementation

**Phase 9 (Polish)**:
- All ADRs (T112-T117) can run in parallel
- All runbooks (T118-T124) can run in parallel

---

## Implementation Strategy

### MVP First (Network + User Story 1 Only)

1. Complete Phase 1: Setup (6 tasks, ~30 minutes)
2. Complete Phase 2: Network Infrastructure (17 tasks, ~3-4 hours)
3. **NETWORK VALIDATION CHECKPOINT**: Validate network before proceeding
4. Complete Phase 3: Foundational (21 tasks, ~2-3 hours)
5. Complete Phase 4: User Story 1 (9 tasks, ~1-2 hours)
6. **STOP and VALIDATE**:
   - Run scripts/validate-single-node.sh (master1 Ready)
   - Run scripts/deploy-test-workload.sh (nginx pod Running)
   - Manually test kubectl access
7. **MVP DEPLOYED**: Single-node K3s cluster operational with validated network infrastructure

**MVP Scope**: 53 tasks, ~7-10 hours total
**Deliverable**: Functional single-node Kubernetes cluster with validated FortiGate network infrastructure and kubectl access

### Incremental Delivery

1. **Network Foundation (Phase 1-2)**: FortiGate configured → Validate → Demo network segmentation
   - Deliverable: VLANs operational, firewall rules active, DHCP reservations working

2. **MVP (Phases 1-4)**: Single-node cluster → Validate → Demo
   - Deliverable: Working Kubernetes API, kubectl access, basic workload deployment

3. **MVP + HA (Phases 1-5)**: Add HA control-plane → Validate → Demo
   - Deliverable: Fault-tolerant cluster, etcd quorum, API survives node failure

4. **Full Cluster (Phases 1-6)**: Add worker node → Validate → Demo
   - Deliverable: Production-grade 4-node cluster, workload/control-plane separation

5. **Complete (Phases 1-7)**: Add monitoring → Validate → Demo
   - Deliverable: Fully observable cluster, Prometheus metrics, Grafana dashboards, alerting

6. **Homelab Complete (Phases 1-8)**: Add auxiliary services → Validate → Demo
   - Deliverable: Pi-hole DNS, jump host access, internal DNS resolution

7. **Production-Ready (All Phases)**: Documentation, tests, runbooks → Validate → Handoff
   - Deliverable: Deployable, documented, tested infrastructure

### Sequential Execution (Solo Operator)

**Recommended approach for learning**:

1. **Week 1**: Setup + Network Infrastructure + Foundational (Phases 1-3)
   - Understand OpenTofu basics, FortiGate configuration, VLAN design

2. **Week 2**: US1 + US2 (MVP + HA Control Plane, Phases 4-5)
   - Learn K3s installation, etcd, distributed consensus, high availability

3. **Week 3**: US3 + US4 (Worker Nodes + Monitoring, Phases 6-7)
   - Learn workload scheduling, Prometheus, Grafana, alerting

4. **Week 4**: Auxiliary Services + Polish (Phases 8-9)
   - Deploy Pi-hole, DNS, jump host; complete documentation and testing

**Total Time Estimate**: 4 weeks part-time (~50-60 hours total)

---

## Notes

- **[P] tasks**: Different files, no dependencies - safe to parallelize
- **[Story] label**: Maps task to specific user story for traceability
- **Sequential dependencies**: Network infrastructure FIRST, then user stories in order (US1 → US2 → US3 → US4)
- **Test-First**: All test scripts must be written before implementation tasks (TDD approach)
- **Commit frequently**: Commit after each task or logical group (e.g., after completing a module)
- **Validate at checkpoints**: Run validation scripts after each phase before proceeding
- **Document as you go**: Update ADRs and runbooks during implementation, not after
- **IPs and SSH config**: Update terraform.tfvars with actual device IPs from DHCP reservations before OpenTofu apply
- **OpenTofu workflow**: Always run `tofu fmt`, `tofu validate`, `tofu plan` before `tofu apply`
- **State backup**: Manually backup terraform.tfstate after each successful apply
- **Learning focus**: This is a learning project - take time to understand each component, read FortiGate docs, K3s docs, experiment with failures
- **Network-first principle**: Never skip network validation checkpoint - cluster will fail without proper network foundation

---

## Success Criteria Checklist

After completing all tasks, verify against spec.md success criteria:

- [ ] **SC-001**: Cluster bootstrap completed in < 15 minutes (Phase 4 complete)
- [ ] **SC-002**: All 4 nodes Ready within 5 minutes of last node join (Phase 6 complete)
- [ ] **SC-003**: API responsive < 2s after master1 shutdown (Phase 5 HA test)
- [ ] **SC-004**: Prometheus scraping all nodes 100% (Phase 7 complete)
- [ ] **SC-005**: Grafana dashboards load < 3s (Phase 7 complete)
- [ ] **SC-006**: Test workload Running < 60s (Phase 4 smoke test)
- [ ] **SC-007**: Cluster survives master1 shutdown (Phase 5 HA test)
- [ ] **SC-008**: `tofu plan` shows no drift (validate after Phase 7)
- [ ] **SC-009**: kubectl works without manual config (Phase 4 kubeconfig)
- [ ] **SC-010**: `tofu destroy` and `tofu apply` reproduces cluster (validate after Phase 9)
- [ ] **SC-011**: Recovery runbook executable < 30 min (Phase 9, T122)
- [ ] **SC-012**: Monitoring alerts fire < 2 min for NotReady nodes (Phase 7, T095 - Alertmanager configuration)

---

## Functional Requirements Coverage

### Network Infrastructure (FortiGate) - Phase 2
- **FR-001**: ✅ T010 (VLAN creation)
- **FR-002**: ✅ T012, T013 (Firewall rules)
- **FR-003**: ✅ T011 (DHCP with static reservations)
- **FR-004**: ✅ T014 (Inter-VLAN routing)
- **FR-005**: ✅ T009 (FortiOS provider)

### Cluster Infrastructure (K3s) - Phases 3-6
- **FR-006**: ✅ T047, T056, T065 (Cluster chocolandiadc across 4 nodes)
- **FR-007**: ✅ T047, T056 (3 control-plane nodes master1-3)
- **FR-008**: ✅ T065 (Worker node nodo1)
- **FR-009**: ✅ T048, T057 (HA K3s with embedded etcd)
- **FR-010**: ✅ T050, T060 (Kubernetes API accessible and load-balanced)

### Auxiliary Services (Raspberry Pi) - Phase 8
- **FR-011**: ✅ T097, T108 (Raspberry Pi as services node)
- **FR-012**: ✅ T099 (Pi-hole deployment)
- **FR-013**: ✅ T101 (Jump host/bastion)
- **FR-014**: ✅ T100 (DNS server)

### Monitoring & Observability - Phase 7
- **FR-015**: ✅ T077, T079 (Prometheus deployment and scraping)
- **FR-016**: ✅ T080, T082 (Grafana with dashboards)
- **FR-017**: ✅ T087 (Resource limits)

### Infrastructure as Code - All Phases
- **FR-018**: ✅ All phases use OpenTofu exclusively
- **FR-019**: ✅ T002, T134 (State management and backup)
- **FR-020**: ✅ All validation scripts (T018-T020, T045-T046, T054-T055, T063-T064, T071-T073, T104-T106)

### Security & Access - Phases 3-9
- **FR-021**: ✅ T049 (Cluster token generation and management)
- **FR-022**: ✅ T050, T060 (kubectl context configuration)
- **FR-023**: ✅ T138 (RBAC validation)
- **FR-024**: ✅ T136 (SSH key-based authentication)

**Coverage**: 24/24 functional requirements (100% coverage)

---

## Task Summary

**Total Tasks**: 143
- Phase 1 (Setup): 6 tasks
- Phase 2 (Network Infrastructure - FortiGate): 17 tasks
- Phase 3 (Foundational): 21 tasks
- Phase 4 (User Story 1 - MVP): 9 tasks (2 tests + 7 implementation)
- Phase 5 (User Story 2 - HA): 9 tasks (2 tests + 7 implementation)
- Phase 6 (User Story 3 - Worker): 8 tasks (2 tests + 6 implementation)
- Phase 7 (User Story 4 - Monitoring): 25 tasks (3 tests + 22 implementation)
- Phase 8 (Auxiliary Services - Raspberry Pi): 16 tasks
- Phase 9 (Polish): 32 tasks (documentation, testing, validation)

**Parallel Opportunities**: 48 tasks marked [P] (34% of total)

**MVP Scope**: 53 tasks (Phases 1-4)
**HA Scope**: 62 tasks (Phases 1-5)
**Full Cluster**: 70 tasks (Phases 1-6)
**Complete with Monitoring**: 95 tasks (Phases 1-7)
**Homelab Complete**: 111 tasks (Phases 1-8)
**Production-Ready**: 143 tasks (All phases)

**Estimated Time**:
- Network Foundation (Phases 1-2): 4-5 hours
- MVP (Phases 1-4): 7-10 hours
- HA (Phases 1-5): 10-14 hours
- Full Cluster (Phases 1-6): 12-17 hours
- Complete with Monitoring (Phases 1-7): 20-30 hours
- Homelab Complete (Phases 1-8): 30-40 hours
- Production-Ready (All phases): 50-60 hours total

Ready for implementation via `/speckit.implement` or manual execution following network-first deployment order.
