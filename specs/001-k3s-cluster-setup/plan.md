# Implementation Plan: K3s HA Cluster Setup - ChocolandiaDC

**Branch**: `001-k3s-cluster-setup` | **Date**: 2025-11-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-k3s-cluster-setup/spec.md`

## Summary

This feature implements a production-grade K3s high-availability cluster in a homelab environment with FortiGate network infrastructure. The implementation includes:

- **Network Infrastructure**: FortiGate 100D configuration with 4-VLAN segmentation (Management 10.0.10.0/24, Cluster 10.0.20.0/24, Services 10.0.30.0/24, DMZ 10.0.40.0/24) managed via OpenTofu
- **K3s HA Cluster**: 3 control-plane nodes (Lenovo mini computers) with embedded etcd + 1 worker node (HP ProDesk), expandable to maximum 3 workers
- **Auxiliary Services**: Raspberry Pi running Pi-hole DNS, jump host, and internal DNS server
- **Monitoring Stack**: Prometheus + Grafana with pre-configured dashboards and three-tier alert severity (Critical/Warning/Info)
- **Infrastructure as Code**: Complete OpenTofu automation following network-first deployment order
- **Backup & Recovery**: Daily automated backups to local NAS/external drive for OpenTofu state, etcd snapshots, and FortiGate configuration

**Key Clarifications Incorporated** (Session 2025-11-08):
1. **FortiGate Bootstrap**: Manual initial GUI setup for API enablement, then OpenTofu takeover (FR-000, A-011)
2. **Backup Strategy**: Daily automated backups to local NAS/external drive (FR-020a/b/c, A-013)
3. **Alert Severity**: Critical (infrastructure down), Warning (resource thresholds), Info (normal ops) - three-tier classification (FR-017a, SC-012)
4. **Network Subnets**: 10.0.10.0/24 (Management VLAN 10), 10.0.20.0/24 (Cluster VLAN 20), 10.0.30.0/24 (Services VLAN 30), 10.0.40.0/24 (DMZ VLAN 40) - sequential numbering (FR-001, Key Entities)
5. **Worker Expansion**: Maximum 3 workers (nodo1-3) for balanced 3+3 topology (FR-006, FR-008, A-006)

## Technical Context

**Language/Version**:
- OpenTofu 1.6+ (Infrastructure as Code)
- K3s v1.28.3+k3s1 (Kubernetes distribution)
- Ubuntu Server 22.04 LTS (mini-PC OS)
- Raspberry Pi OS 64-bit (auxiliary services)
- FortiOS 6.4+ (FortiGate firmware)

**Primary Dependencies**:
- **FortiOS Provider**: `fortinetdev/fortios ~> 1.19.0` (FortiGate configuration)
- **Helm Provider**: `hashicorp/helm ~> 2.11.0` (monitoring stack deployment)
- **Kubernetes Provider**: `hashicorp/kubernetes ~> 2.23.0` (cluster resource management)
- **SSH Provisioner**: Built-in OpenTofu SSH provisioner (K3s installation, Raspberry Pi setup)

**Storage**:
- **etcd**: Embedded within K3s control-plane nodes (3 replicas for quorum)
- **Prometheus**: 20Gi PersistentVolume via local-path storage (15-day retention)
- **Grafana**: 5Gi PersistentVolume for dashboard persistence
- **Backup Storage**: Local NAS or external drive (NFS/SMB accessible) for daily automated backups

**Testing**:
- **OpenTofu**: `tofu validate`, `tofu plan` (syntax and plan validation)
- **Network Tests**: Connectivity validation scripts (`validate-network.sh`)
- **Cluster Tests**: Integration tests (`validate-cluster.sh`)
- **HA Tests**: Node failure simulation (shutdown master1, verify API availability)

**Target Platform**:
- **Hardware**: 3x Lenovo mini computers (control-plane), 1x HP ProDesk (worker), 1x FortiGate 100D (edge firewall), 1x Raspberry Pi (auxiliary services)
- **Network**: 4-VLAN architecture with FortiGate routing and firewall segmentation

**Project Type**: Infrastructure (multi-layer: network → cluster → monitoring → services)

**Performance Goals**:
- Cluster bootstrap: < 15 minutes from OpenTofu init to all nodes Ready
- API response time: < 2 seconds for `kubectl get nodes`
- Monitoring scrape interval: 30 seconds (all targets)
- Alert latency: < 2 minutes for node NotReady events

**Constraints**:
- **Hardware**: 4 mini-PCs available (3 Lenovo + 1 HP ProDesk) - limits initial topology to 3+1 nodes
- **Memory**: Prometheus + Grafana limited to ~2GB combined (resource-constrained worker node)
- **Network**: Single FortiGate physical uplink (no network redundancy unless multi-ISP)
- **Backup Storage**: Local NAS/external drive required on network (NFS or SMB accessible)

**Scale/Scope**:
- **Cluster**: 3 control-plane + 1 worker initially, expandable to 3 control-plane + 3 workers (maximum 6 nodes)
- **VLANs**: 4 VLANs (Management, Cluster, Services, DMZ)
- **Firewall Rules**: ~10-15 explicit policies (whitelist approach)
- **Services**: Prometheus, Grafana, Pi-hole, DNS server, jump host
- **Metrics Retention**: 15 days for learning and debugging

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Constitution Compliance Assessment

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Infrastructure as Code - OpenTofu First** | ✅ PASS | All infrastructure defined in OpenTofu: FortiGate VLANs/firewall/DHCP, K3s cluster, Helm charts, Raspberry Pi provisioning |
| **II. GitOps Workflow** | ✅ PASS | Git as single source of truth; PRs for OpenTofu changes; plan review before apply |
| **III. Container-First Development** | ✅ PASS | K3s cluster for container orchestration; monitoring stack via Helm (containerized Prometheus/Grafana) |
| **IV. Observability & Monitoring - Prometheus + Grafana (NON-NEGOTIABLE)** | ✅ PASS | kube-prometheus-stack deployed via Helm; scrapes all nodes, K3s components, FortiGate (if SNMP enabled); three-tier alert severity (Critical/Warning/Info) configured |
| **V. Security Hardening** | ✅ PASS | FortiGate perimeter security; VLAN segmentation (Management/Cluster/Services/DMZ); jump host pattern (Raspberry Pi bastion); SSH key-only auth; Kubernetes RBAC; default-deny firewall rules |
| **VI. High Availability Architecture** | ✅ PASS | 3 control-plane nodes (etcd quorum), load-balanced API, tolerates single node failure; balanced topology for expansion (3 control-plane + 3 workers maximum) |
| **VII. Test-Driven Learning (NON-NEGOTIABLE)** | ✅ PASS | Network validation scripts (`validate-network.sh`), cluster tests (`validate-cluster.sh`), HA failure tests (node shutdown simulation) |
| **VIII. Documentation-First** | ✅ PASS | ADRs in research.md (OpenTofu vs Terraform, FortiGate vs pfSense, 3+1 topology, VLAN design); runbooks for bootstrap, disaster recovery, backup/restore; network diagrams in research.md |
| **IX. Network-First Security** | ✅ PASS | FortiGate deployed before cluster; 4-VLAN segmentation (10.0.10.0/24, 10.0.20.0/24, 10.0.30.0/24, 10.0.40.0/24); default deny firewall; inter-VLAN routing controlled; network order: FortiGate → validation → cluster → services |

**Constitution Version**: 1.2.0

**Violations**: None

**Complexity Justification**: All complexity serves learning goals:
- FortiGate (enterprise firewall experience)
- VLANs (network segmentation concepts)
- HA etcd (distributed consensus learning)
- OpenTofu (IaC best practices)
- Multi-provider infrastructure (FortiOS + SSH + Helm + Kubernetes)

## Project Structure

### Documentation (this feature)

```text
specs/001-k3s-cluster-setup/
├── plan.md              # This file (/speckit.plan command output)
├── spec.md              # Feature specification (user stories, requirements, success criteria)
├── research.md          # Phase 0 output (technical decisions, alternatives, best practices)
├── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created yet)
└── clarifications/      # Clarification session records (integrated into spec.md)
```

### Source Code (repository root)

```text
chocolandia_kube/
├── terraform/                          # OpenTofu infrastructure code
│   ├── modules/
│   │   ├── fortigate-network/         # FortiGate VLANs, firewall, DHCP, routing
│   │   │   ├── main.tf
│   │   │   ├── interfaces.tf          # VLAN interfaces (Management/Cluster/Services/DMZ)
│   │   │   ├── dhcp.tf                # DHCP servers and static reservations
│   │   │   ├── addresses.tf           # Address objects and groups
│   │   │   ├── policies.tf            # Firewall policies (whitelist approach)
│   │   │   ├── routing.tf             # Static routes (if needed)
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   ├── k3s-cluster/               # K3s control-plane + worker nodes
│   │   │   ├── main.tf
│   │   │   ├── control-plane.tf       # master1, master2, master3 (Lenovo nodes)
│   │   │   ├── workers.tf             # nodo1 (HP ProDesk), nodo2/nodo3 (optional)
│   │   │   ├── ssh-provisioner.tf     # K3s installation via SSH
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   ├── monitoring-stack/          # Prometheus + Grafana via Helm
│   │   │   ├── main.tf
│   │   │   ├── prometheus.tf          # kube-prometheus-stack Helm chart
│   │   │   ├── alert-rules.tf         # Custom PrometheusRules (Critical/Warning/Info severity)
│   │   │   ├── monitoring-values.yaml # Helm values (resource limits, retention, severity config)
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   └── raspberry-pi-services/     # Pi-hole, DNS, jump host
│   │       ├── main.tf
│   │       ├── pihole.tf              # Pi-hole installation
│   │       ├── dns.tf                 # Custom DNS records (*.chocolandiadc.local)
│   │       ├── jump-host.tf           # SSH bastion configuration
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── versions.tf
│   ├── environments/
│   │   └── chocolandiadc/             # Production homelab environment
│   │       ├── main.tf                # Module composition
│   │       ├── variables.tf
│   │       ├── terraform.tfvars       # Environment-specific values (IPs, MACs, subnets)
│   │       ├── outputs.tf
│   │       └── versions.tf
│   └── providers.tf                   # FortiOS, Helm, Kubernetes provider config
├── scripts/                           # Validation and automation scripts
│   ├── validate-network.sh            # Network connectivity and firewall tests
│   ├── validate-cluster.sh            # Cluster health and readiness tests
│   ├── backup-state.sh                # Daily backup script (OpenTofu state to NAS)
│   ├── backup-etcd.sh                 # Daily backup script (etcd snapshots to NAS)
│   ├── backup-fortigate.sh            # Daily backup script (FortiGate config to NAS)
│   └── disaster-recovery.sh           # Restore procedures
├── docs/                              # Operational documentation
│   ├── runbooks/
│   │   ├── bootstrap.md               # Initial homelab setup (FortiGate manual bootstrap → OpenTofu)
│   │   ├── add-worker-node.md         # Procedure for adding nodo2, nodo3
│   │   ├── disaster-recovery.md       # Recovery from backups
│   │   └── network-changes.md         # VLAN/firewall modification procedures
│   ├── architecture/
│   │   ├── network-topology.md        # VLAN diagram, subnet allocations, firewall rules
│   │   └── cluster-topology.md        # Node roles, etcd quorum, HA design
│   └── troubleshooting/
│       ├── vlan-connectivity.md       # VLAN isolation issues
│       ├── firewall-rules.md          # Blocked traffic debugging
│       └── cluster-networking.md      # K3s networking problems
├── backups/                           # Local backup directory (synced to NAS)
│   ├── terraform-state/               # Daily OpenTofu state backups
│   ├── etcd-snapshots/                # Daily etcd snapshots
│   └── fortigate-config/              # Daily FortiGate configuration exports
└── .specify/                          # Speckit templates and memory
    └── memory/
        └── constitution.md            # Project constitution (version 1.2.0)
```

**Structure Decision**:

This structure follows a **multi-layer infrastructure project** approach with clear separation of concerns:

1. **OpenTofu Modules**: Each infrastructure layer (network, cluster, monitoring, services) is a reusable module with explicit inputs/outputs
2. **Environment Composition**: `environments/chocolandiadc/` composes modules for the production homelab
3. **Network-First Organization**: Modules are organized in dependency order (network → cluster → monitoring → services)
4. **Backup Integration**: Daily backup scripts and storage directories for disaster recovery
5. **Documentation Structure**: Runbooks, architecture diagrams, and troubleshooting guides support operational learning

**Key Directories**:
- `terraform/modules/fortigate-network/`: **MUST** be deployed first (network foundation)
- `terraform/modules/k3s-cluster/`: Depends on network module (requires VLANs and firewall rules)
- `terraform/modules/monitoring-stack/`: Depends on cluster (deployed via Helm after cluster is operational)
- `terraform/modules/raspberry-pi-services/`: Can be deployed in parallel with cluster (independent auxiliary services)
- `scripts/`: Validation scripts called after each module deployment
- `backups/`: Local staging for daily backups before sync to NAS/external drive

## Deployment Phases

### Phase 0: Prerequisites (Manual - One-Time)

**Objective**: Complete manual prerequisites before OpenTofu automation begins

**Tasks**:
1. **FortiGate Initial Bootstrap** (Manual GUI - FR-000, A-011):
   - Connect to FortiGate management port (default: 192.168.1.99)
   - Configure management IP address (e.g., 10.0.10.1)
   - Set admin password
   - Enable FortiOS API access:
     ```
     config system api-user
         edit "opentofu"
             set accprofile "super_admin"
             set vdom "root"
             config trusthost
                 edit 1
                     set ipv4-trusthost <workstation-ip>/32
                 next
             end
         next
     end
     ```
   - Generate API token (store securely - environment variable `TF_VAR_fortigate_api_token`)
   - Verify API access: `curl -k -H "Authorization: Bearer <token>" https://10.0.10.1/api/v2/cmdb/system/interface`

2. **Hardware Preparation**:
   - Install Ubuntu Server 22.04 LTS on all mini-PCs (3 Lenovo + 1 HP ProDesk)
   - Install Raspberry Pi OS 64-bit on Raspberry Pi
   - Configure SSH key-based authentication on all devices (no password auth)
   - Record MAC addresses for DHCP reservations (critical for static IPs)

3. **Backup Storage Setup** (FR-020a/b/c, A-013):
   - Provision local NAS or external drive on network
   - Configure NFS or SMB share accessible from:
     - Control-plane nodes (for etcd snapshots)
     - Workstation (for OpenTofu state backups)
     - FortiGate (for config backups - via SFTP/SCP if supported)
   - Create backup directories:
     - `/mnt/nas/backups/terraform-state/`
     - `/mnt/nas/backups/etcd-snapshots/`
     - `/mnt/nas/backups/fortigate-config/`
   - Test write access from workstation

4. **OpenTofu Installation** (Workstation):
   ```bash
   # macOS
   brew install opentofu

   # Verify
   tofu version  # Should be >= 1.6.0
   ```

**Acceptance Criteria**:
- FortiGate API accessible via token authentication
- All mini-PCs and Raspberry Pi have SSH access via keys
- MAC addresses documented for all devices
- NAS/external drive accessible and writable
- OpenTofu installed on workstation

---

### Phase 1: Network Infrastructure (OpenTofu - FortiGate)

**Objective**: Deploy FortiGate VLANs, firewall rules, DHCP, and routing before cluster deployment (Principle IX - Network-First Security)

**OpenTofu Module**: `terraform/modules/fortigate-network/`

**Components**:
1. **VLAN Interfaces** (FR-001):
   - Management VLAN 10 (10.0.10.0/24, gateway 10.0.10.1)
   - Cluster VLAN 20 (10.0.20.0/24, gateway 10.0.20.1)
   - Services VLAN 30 (10.0.30.0/24, gateway 10.0.30.1)
   - DMZ VLAN 40 (10.0.40.0/24, gateway 10.0.40.1) - reserved for future use

2. **DHCP Servers** (FR-003):
   - Management VLAN: DHCP pool 10.0.10.100-199
     - Static reservation: Raspberry Pi (10.0.10.10)
   - Cluster VLAN: DHCP pool 10.0.20.100-199
     - Static reservations: master1 (10.0.20.11), master2 (10.0.20.12), master3 (10.0.20.13), nodo1 (10.0.20.21)
     - Reserved: nodo2 (10.0.20.22), nodo3 (10.0.20.23) for future expansion
   - Services VLAN: DHCP pool 10.0.30.100-199
     - Static reservation: Raspberry Pi (10.0.30.10)

3. **Firewall Policies** (FR-002, FR-004):
   - **Management → Cluster**: Allow SSH (TCP 22) for administration
   - **Management → Services**: Allow SSH, HTTP/HTTPS (Pi-hole access)
   - **Cluster → Internet**: Allow HTTPS (TCP 443) for image pulls, DNS (UDP 53)
   - **Cluster → Services**: Allow DNS (UDP 53) to Pi-hole (10.0.30.10)
   - **Cluster ↔ Cluster**: Allow K3s ports (TCP 6443, TCP 2379-2380, UDP 8472, TCP 10250)
   - **Services → Internet**: Allow HTTPS for Pi-hole blocklist updates
   - **Default Deny**: Block all other inter-VLAN traffic (log denied traffic)

4. **Address Objects** (Best Practice - research.md 2.1):
   - `cluster-subnet` (10.0.20.0/24)
   - `services-subnet` (10.0.30.0/24)
   - `pihole-ip` (10.0.30.10)
   - `master-nodes` (address group: 10.0.20.11-13)
   - `worker-nodes` (address group: 10.0.20.21-23)

**Deployment Commands**:
```bash
cd terraform/environments/chocolandiadc
tofu init
tofu plan -target=module.fortigate_network
tofu apply -target=module.fortigate_network
```

**Validation**: Run `scripts/validate-network.sh`
```bash
#!/bin/bash
# Test 1: Ping FortiGate gateways
ping -c 2 10.0.10.1  # Management
ping -c 2 10.0.20.1  # Cluster
ping -c 2 10.0.30.1  # Services

# Test 2: Verify VLAN isolation (should timeout - no firewall rule)
# From workstation (Management VLAN), try cluster VLAN (should work if rule exists)
ping -c 2 10.0.20.11  # Should work (management → cluster allowed for SSH)

# Test 3: Verify firewall allow/deny
ssh ubuntu@10.0.20.11  # Should work (SSH allowed)
```

**Acceptance Criteria**:
- All 4 VLANs created with correct subnets (10.0.10.0/24, 10.0.20.0/24, 10.0.30.0/24, 10.0.40.0/24)
- DHCP assigns static IPs to mini-PCs and Raspberry Pi
- Firewall rules allow only explicitly permitted traffic
- `validate-network.sh` passes all tests
- FortiGate logs show denied traffic for unauthorized inter-VLAN communication

---

### Phase 2: Cluster Infrastructure (OpenTofu - K3s)

**Objective**: Deploy K3s HA cluster with 3 control-plane nodes and 1 worker node

**OpenTofu Module**: `terraform/modules/k3s-cluster/`

**Components**:
1. **Control-Plane Nodes** (FR-007, FR-009):
   - master1 (10.0.20.11): First control-plane with `--cluster-init` (embedded etcd leader)
   - master2 (10.0.20.12): Second control-plane (joins etcd cluster)
   - master3 (10.0.20.13): Third control-plane (joins etcd cluster)
   - K3s version: v1.28.3+k3s1
   - Flags: `--cluster-init`, `--disable traefik`, `--write-kubeconfig-mode 644`, `--tls-san <load-balancer-ip>`

2. **Worker Node** (FR-008):
   - nodo1 (10.0.20.21): Dedicated worker for application workloads
   - K3s agent mode: `--server https://<master1-ip>:6443 --token <cluster-token>`
   - Future expansion: nodo2 (10.0.20.22), nodo3 (10.0.20.23) up to 3 workers maximum

3. **Cluster Token** (FR-021):
   - Generate secure random token: `openssl rand -base64 32`
   - Store in OpenTofu sensitive variable
   - Distribute to all nodes via SSH provisioner

4. **Kubeconfig** (FR-022):
   - Retrieve from master1: `/etc/rancher/k3s/k3s.yaml`
   - Modify server URL to load balancer IP
   - Copy to workstation `~/.kube/config`

**K3s Installation Script** (SSH Provisioner):
```bash
# master1 (first control-plane)
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san 10.0.20.100 \
  --node-name master1 \
  --token ${K3S_TOKEN}

# master2, master3 (additional control-plane)
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://10.0.20.11:6443 \
  --disable traefik \
  --node-name master2 \
  --token ${K3S_TOKEN}

# nodo1 (worker)
curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://10.0.20.11:6443 \
  --node-name nodo1 \
  --token ${K3S_TOKEN}
```

**Deployment Commands**:
```bash
tofu plan -target=module.k3s_cluster
tofu apply -target=module.k3s_cluster
```

**Validation**: Run `scripts/validate-cluster.sh`
```bash
#!/bin/bash
# Test 1: All nodes Ready
kubectl get nodes
# Expected: 4 nodes (master1, master2, master3, nodo1) with status Ready

# Test 2: Control-plane HA (etcd quorum)
kubectl -n kube-system get pods -l component=etcd
# Expected: 3 etcd pods running on master1, master2, master3

# Test 3: Deploy test workload
kubectl run nginx --image=nginx:latest
kubectl wait --for=condition=ready pod/nginx --timeout=60s
kubectl delete pod nginx
```

**Acceptance Criteria** (SC-001, SC-002, SC-003, SC-007):
- Cluster bootstrap completes in < 15 minutes
- All 4 nodes show Ready status within 5 minutes of last node joining
- `kubectl get nodes` responds in < 2 seconds
- Simulating master1 shutdown: API remains accessible via master2/master3
- Test nginx pod deploys and reaches Running state in < 60 seconds

---

### Phase 3: Monitoring Stack (OpenTofu - Prometheus + Grafana)

**Objective**: Deploy observability stack with three-tier alert severity classification

**OpenTofu Module**: `terraform/modules/monitoring-stack/`

**Components**:
1. **kube-prometheus-stack Helm Chart** (FR-015, FR-016, FR-017, FR-017a):
   - Chart version: v51.0.0
   - Namespace: `monitoring`
   - Prometheus retention: 15 days
   - Prometheus storage: 20Gi PersistentVolume
   - Grafana storage: 5Gi PersistentVolume
   - Resource limits: Prometheus (2Gi RAM max), Grafana (1Gi RAM max)

2. **Alert Rules - Three-Tier Severity** (FR-017a):

   **Critical Alerts** (infrastructure down):
   - Node offline (node_exporter down for 2+ minutes)
   - etcd quorum lost (< 2 of 3 etcd members healthy)
   - Kubernetes API unavailable (apiserver pods down)
   - Control-plane components down (scheduler, controller-manager)

   **Warning Alerts** (resource thresholds):
   - High CPU usage (> 80% for 5 minutes)
   - High memory usage (> 85% for 5 minutes)
   - High disk usage (> 80%)
   - Pod restart rate (> 5 restarts in 10 minutes)
   - Approaching etcd storage limit (> 2GB)

   **Info Alerts** (normal operations):
   - Backup completed successfully
   - Configuration change applied (FortiGate, K3s)
   - Node joined cluster
   - Prometheus target discovered

3. **Grafana Dashboards**:
   - Kubernetes / Compute Resources / Cluster (pre-installed)
   - Node Exporter / Nodes (host-level metrics)
   - Kubernetes / Persistent Volumes (storage health)

4. **ServiceMonitors** (automatic target discovery):
   - node-exporter (all cluster nodes)
   - kube-state-metrics (K8s object state)
   - kubelet (node metrics)
   - kube-apiserver (API metrics)

**Helm Values Configuration** (`monitoring-values.yaml`):
```yaml
prometheus:
  prometheusSpec:
    retention: 15d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
    resources:
      limits:
        cpu: 1000m
        memory: 2Gi

grafana:
  adminPassword: "<SECURE_PASSWORD>"
  persistence:
    enabled: true
    size: 5Gi
  resources:
    limits:
      cpu: 500m
      memory: 1Gi

alertmanager:
  alertmanagerSpec:
    resources:
      limits:
        cpu: 200m
        memory: 512Mi
```

**Deployment Commands**:
```bash
tofu plan -target=module.monitoring_stack
tofu apply -target=module.monitoring_stack
```

**Validation**:
```bash
# Test 1: All monitoring pods Running
kubectl get pods -n monitoring
# Expected: prometheus, grafana, alertmanager, node-exporter (DaemonSet), kube-state-metrics all Running

# Test 2: Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets - all targets should be UP (100% availability)

# Test 3: Grafana dashboards
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open http://localhost:3000 (admin / <SECURE_PASSWORD>)
# Verify dashboards load in < 3 seconds and display metrics

# Test 4: Alert severity validation (SC-012)
# Simulate node down: ssh ubuntu@10.0.20.11 "sudo systemctl stop k3s"
# Expected: Critical alert fires within 2 minutes ("NodeDown" with severity: critical)
# Restore: ssh ubuntu@10.0.20.11 "sudo systemctl start k3s"
```

**Acceptance Criteria** (SC-004, SC-005, SC-012):
- Prometheus scrapes 100% of targets (all 4 nodes + K3s components)
- Grafana dashboards load in < 3 seconds
- Critical alerts fire within 2 minutes when node becomes NotReady
- Alert severity classification working (Critical/Warning/Info labels visible in Alertmanager)

---

### Phase 4: Auxiliary Services (OpenTofu - Raspberry Pi)

**Objective**: Deploy Pi-hole DNS, jump host, and internal DNS server on Raspberry Pi

**OpenTofu Module**: `terraform/modules/raspberry-pi-services/`

**Components**:
1. **Pi-hole** (FR-012):
   - Automated installation via SSH provisioner
   - Upstream DNS: Cloudflare (1.1.1.1), Google (8.8.8.8)
   - Web admin password: Secure password (stored in vault)
   - Custom DNS records for homelab:
     - `master1.chocolandiadc.local` → 10.0.20.11
     - `master2.chocolandiadc.local` → 10.0.20.12
     - `master3.chocolandiadc.local` → 10.0.20.13
     - `nodo1.chocolandiadc.local` → 10.0.20.21
     - `grafana.chocolandiadc.local` → (ingress IP or NodePort)

2. **Jump Host / Bastion** (FR-013):
   - SSH access enabled (already configured in prerequisites)
   - SSH config on workstation for ProxyJump:
     ```
     Host jump
       HostName 10.0.10.10
       User ubuntu

     Host master1
       HostName 10.0.20.11
       ProxyJump jump
     ```

3. **DNS Server** (FR-014):
   - Pi-hole handles DNS (dual role: ad-blocking + internal resolution)
   - FortiGate DHCP configured to point all VLANs to Pi-hole (10.0.30.10 primary, 10.0.20.1 fallback)

**Pi-hole Installation Script** (SSH Provisioner):
```bash
# Automated Pi-hole installation
curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended

# Set admin password
pihole -a -p ${PIHOLE_ADMIN_PASSWORD}

# Configure upstream DNS
pihole -a setdns 1.1.1.1 8.8.8.8

# Add custom DNS records
echo "10.0.20.11 master1.chocolandiadc.local" | sudo tee -a /etc/pihole/custom.list
echo "10.0.20.12 master2.chocolandiadc.local" | sudo tee -a /etc/pihole/custom.list
echo "10.0.20.13 master3.chocolandiadc.local" | sudo tee -a /etc/pihole/custom.list
echo "10.0.20.21 nodo1.chocolandiadc.local" | sudo tee -a /etc/pihole/custom.list

# Reload DNS
pihole restartdns
```

**Deployment Commands**:
```bash
tofu plan -target=module.raspberry_pi_services
tofu apply -target=module.raspberry_pi_services
```

**Validation**:
```bash
# Test 1: Pi-hole DNS resolution (external)
nslookup google.com 10.0.30.10
# Expected: Resolves successfully

# Test 2: Pi-hole DNS resolution (internal homelab domains)
nslookup master1.chocolandiadc.local 10.0.30.10
# Expected: Returns 10.0.20.11

# Test 3: Ad-blocking (query known ad domain)
nslookup ads.google.com 10.0.30.10
# Expected: Returns 0.0.0.0 (blocked)

# Test 4: Jump host SSH access
ssh ubuntu@10.0.10.10  # Jump host
ssh ubuntu@10.0.20.11  # From jump host to master1
# Expected: Both SSH sessions succeed

# Test 5: Pi-hole web interface
# Open http://10.0.30.10/admin (from Management VLAN workstation)
# Expected: Pi-hole dashboard loads, shows queries and blocklist stats
```

**Acceptance Criteria**:
- Pi-hole resolves external domains and internal homelab domains
- Ad-blocking functional (known ad domains blocked)
- Jump host accessible via SSH
- Cluster nodes accessible via ProxyJump
- Pi-hole web interface accessible from Management VLAN

---

### Phase 5: Backup & Recovery Automation (Scripts + Cron)

**Objective**: Implement daily automated backups to local NAS/external drive (FR-020a/b/c, A-013)

**Components**:

1. **OpenTofu State Backup** (`scripts/backup-state.sh`):
   ```bash
   #!/bin/bash
   # Daily backup of OpenTofu state to NAS
   BACKUP_DIR="/mnt/nas/backups/terraform-state"
   STATE_FILE="terraform/environments/chocolandiadc/terraform.tfstate"
   TIMESTAMP=$(date +%Y-%m-%d)

   cp "$STATE_FILE" "$BACKUP_DIR/terraform-$TIMESTAMP.tfstate"

   # Retain last 30 days
   find "$BACKUP_DIR" -name "terraform-*.tfstate" -mtime +30 -delete
   ```

2. **etcd Snapshot Backup** (`scripts/backup-etcd.sh`):
   ```bash
   #!/bin/bash
   # Daily backup of etcd snapshots to NAS
   BACKUP_DIR="/mnt/nas/backups/etcd-snapshots"
   TIMESTAMP=$(date +%Y-%m-%d)

   # SSH to master1 and create snapshot
   ssh ubuntu@10.0.20.11 "sudo k3s etcd-snapshot save --name backup-$TIMESTAMP"

   # Copy snapshot to NAS
   scp ubuntu@10.0.20.11:/var/lib/rancher/k3s/server/db/snapshots/backup-$TIMESTAMP "$BACKUP_DIR/"

   # Retain last 30 days
   find "$BACKUP_DIR" -name "backup-*" -mtime +30 -delete
   ```

3. **FortiGate Config Backup** (`scripts/backup-fortigate.sh`):
   ```bash
   #!/bin/bash
   # Daily backup of FortiGate configuration to NAS
   BACKUP_DIR="/mnt/nas/backups/fortigate-config"
   TIMESTAMP=$(date +%Y-%m-%d)

   # Use FortiOS API to export configuration
   curl -k -H "Authorization: Bearer $FORTIGATE_API_TOKEN" \
     "https://10.0.10.1/api/v2/monitor/system/config/backup?scope=global" \
     -o "$BACKUP_DIR/fortigate-$TIMESTAMP.conf"

   # Retain last 30 days
   find "$BACKUP_DIR" -name "fortigate-*.conf" -mtime +30 -delete
   ```

4. **Cron Scheduling** (Workstation or dedicated management node):
   ```cron
   # Daily backups at 2 AM
   0 2 * * * /path/to/scripts/backup-state.sh >> /var/log/backup-state.log 2>&1
   0 2 * * * /path/to/scripts/backup-etcd.sh >> /var/log/backup-etcd.log 2>&1
   0 2 * * * /path/to/scripts/backup-fortigate.sh >> /var/log/backup-fortigate.log 2>&1
   ```

5. **Prometheus Info Alerts** (backup success notifications):
   ```yaml
   # PrometheusRule for backup completion alerts
   - alert: BackupCompleted
     expr: backup_last_success_timestamp_seconds{job="backup-cron"} > 0
     labels:
       severity: info
     annotations:
       summary: "Daily backup completed successfully"
       description: "Backup job {{ $labels.job }} completed at {{ $value }}"
   ```

**Validation**:
```bash
# Test 1: Manual backup execution
./scripts/backup-state.sh
ls -lh /mnt/nas/backups/terraform-state/
# Expected: New terraform-<date>.tfstate file created

./scripts/backup-etcd.sh
ls -lh /mnt/nas/backups/etcd-snapshots/
# Expected: New backup-<date> snapshot file created

./scripts/backup-fortigate.sh
ls -lh /mnt/nas/backups/fortigate-config/
# Expected: New fortigate-<date>.conf file created

# Test 2: Verify backup retention (after 30 days)
# Expected: Files older than 30 days are automatically deleted

# Test 3: Test restore procedure (disaster recovery)
# Restore OpenTofu state:
cp /mnt/nas/backups/terraform-state/terraform-<date>.tfstate terraform/environments/chocolandiadc/terraform.tfstate

# Restore etcd snapshot:
ssh ubuntu@10.0.20.11 "sudo k3s server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/backup-<date>"

# Restore FortiGate config (manual via GUI or CLI)
```

**Acceptance Criteria**:
- Daily backups run automatically via cron
- OpenTofu state, etcd snapshots, and FortiGate config backed up to NAS
- Backup retention: 30 days (old backups auto-deleted)
- Backup logs written to `/var/log/backup-*.log`
- Restore procedures documented in `docs/runbooks/disaster-recovery.md`

---

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations detected.** All complexity serves documented learning goals:

| Component | Complexity | Learning Justification |
|-----------|------------|------------------------|
| FortiGate VLAN Segmentation | 4 VLANs, 10+ firewall rules | Enterprise networking concepts: VLANs, inter-VLAN routing, firewall zones, default-deny policies |
| K3s HA with Embedded etcd | 3-node etcd quorum, distributed consensus | Production-grade distributed systems: leader election, quorum, split-brain scenarios, failure handling |
| Multi-Provider OpenTofu | FortiOS + SSH + Helm + Kubernetes providers | IaC best practices: provider diversity, declarative infrastructure, state management across heterogeneous systems |
| Prometheus Alert Severity | Critical/Warning/Info three-tier classification | Operational maturity: alert escalation, on-call response priority, reducing alert fatigue |
| Daily Backup Automation | 3 backup scripts (state, etcd, FortiGate) to NAS | Disaster recovery: backup strategies, retention policies, restore procedures |

**Total Estimated Complexity**:
- **OpenTofu Modules**: 4 modules (network, cluster, monitoring, services)
- **Firewall Policies**: ~12 explicit rules (whitelist approach)
- **Infrastructure Components**: 6 devices (3 Lenovo, 1 HP ProDesk, 1 FortiGate, 1 Raspberry Pi)
- **Deployment Phases**: 5 phases (prerequisites → network → cluster → monitoring → services → backups)

**Complexity Budget Remaining**: Within Constitution limits (no unnecessary over-engineering detected)

---

## Risk Assessment & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **FortiGate misconfiguration blocks cluster traffic** | High (cluster bootstrap fails) | Medium (complex firewall rules) | Phase 1 network validation tests (`validate-network.sh`) before cluster deployment; out-of-band FortiGate console access |
| **Single Raspberry Pi failure breaks DNS/SSH** | Medium (no DNS resolution, no jump host access) | Low (Raspberry Pi reliability) | FortiGate as fallback DNS (degraded mode without ad-blocking); direct SSH to cluster nodes from Management VLAN as emergency access |
| **etcd quorum loss (2+ control-plane nodes fail)** | High (cluster API read-only) | Very Low (requires simultaneous failures) | Daily automated etcd snapshots to NAS; documented restore procedure; UPS backup for power failures |
| **Worker node resource exhaustion (Prometheus + workloads)** | Medium (OOM kills, pod evictions) | Medium (4GB RAM constraint) | Resource limits enforced on all pods; monitoring alerts for high memory usage (Warning threshold 85%) |
| **NAS/external drive failure loses backups** | Medium (no disaster recovery) | Low (local storage typically reliable) | Secondary backup location recommended (cloud storage, off-site drive); test restore procedures quarterly |
| **VLAN isolation breach (firewall rule error)** | Low (unauthorized lateral movement) | Low (OpenTofu code review catches errors) | Default-deny firewall posture; logging all denied traffic; regular firewall rule audits |

**Critical Failure Scenarios**:
1. **FortiGate total failure**: Cluster nodes can communicate within Cluster VLAN (Layer 2), but no internet access or inter-VLAN routing
2. **All control-plane nodes down**: Cluster API unavailable; worker node workloads may continue running but no scheduling
3. **etcd corruption**: Restore from daily snapshot (maximum 24 hours data loss)

**Rollback Procedures**:
- **Network changes**: `tofu apply` previous FortiGate config; FortiGate config backup restore
- **Cluster changes**: Destroy cluster module (`tofu destroy -target=module.k3s_cluster`), redeploy
- **Monitoring stack**: Helm uninstall, redeploy chart

---

## Success Criteria Validation

**How to validate all Success Criteria from spec.md**:

| Success Criteria | Validation Method | Target |
|------------------|-------------------|--------|
| **SC-001**: Cluster bootstrap < 15 minutes | Measure time from `tofu apply` start to last node Ready | < 15 min |
| **SC-002**: All nodes Ready < 5 minutes after last join | `kubectl get nodes` timestamps | < 5 min |
| **SC-003**: API response < 2 seconds after node failure | Shutdown master1, run `kubectl get nodes`, measure latency | < 2 sec |
| **SC-004**: Prometheus 100% target availability | Check Prometheus UI `/targets` - all UP | 100% |
| **SC-005**: Grafana dashboards load < 3 seconds | Measure time to load "Cluster Overview" dashboard | < 3 sec |
| **SC-006**: Test workload (nginx) Running < 60 seconds | `kubectl run nginx --image=nginx; kubectl wait --timeout=60s` | < 60 sec |
| **SC-007**: Cluster survives master1 shutdown | Shutdown master1, verify API available, existing pods running | Pass/Fail |
| **SC-008**: No Terraform drift | `tofu plan` shows no changes after successful apply | 0 changes |
| **SC-009**: kubectl access without manual config | Kubeconfig auto-generated and copied to workstation | Pass/Fail |
| **SC-010**: Infrastructure reproducible | `tofu destroy && tofu apply` recreates identical cluster | Pass/Fail |
| **SC-011**: Recovery runbook execution < 30 minutes | Test disaster recovery procedure, measure time | < 30 min |
| **SC-012**: Alerts fire < 2 minutes when node NotReady with Critical severity | Shutdown node, measure alert latency, verify severity label | < 2 min, severity=critical |

**Test Execution Order**:
1. SC-001, SC-002: During initial cluster deployment
2. SC-003, SC-007, SC-012: After cluster operational (HA failure tests)
3. SC-004, SC-005: After monitoring stack deployed
4. SC-006: After cluster operational (workload test)
5. SC-008, SC-009: After full deployment complete
6. SC-010, SC-011: Final validation (destructive tests)

---

## Next Steps

**Immediate Actions** (After Plan Approval):
1. Execute `/speckit.tasks` command to generate `tasks.md` with dependency-ordered implementation tasks
2. Review generated tasks for network-first ordering: FortiGate → validation → cluster → monitoring → services
3. Begin Phase 0 (Prerequisites): FortiGate manual bootstrap, hardware preparation, backup storage setup

**Implementation Workflow**:
1. **Phase 0** (Manual): FortiGate bootstrap, hardware prep, NAS setup
2. **Phase 1** (OpenTofu): Deploy `fortigate-network` module → run `validate-network.sh`
3. **Phase 2** (OpenTofu): Deploy `k3s-cluster` module → run `validate-cluster.sh`
4. **Phase 3** (OpenTofu): Deploy `monitoring-stack` module → verify Prometheus targets, Grafana dashboards
5. **Phase 4** (OpenTofu): Deploy `raspberry-pi-services` module → verify Pi-hole DNS, jump host SSH
6. **Phase 5** (Scripts): Configure daily backup cron jobs → test backup/restore procedures

**Learning Milestones**:
- After Phase 1: Understand VLAN segmentation, firewall policies, inter-VLAN routing
- After Phase 2: Understand K3s HA architecture, etcd quorum, distributed consensus
- After Phase 3: Understand Prometheus metrics collection, PromQL queries, alert severity classification
- After Phase 4: Understand DNS resolution, jump host security pattern
- After Phase 5: Understand disaster recovery, backup strategies, infrastructure reproducibility

**Documentation Updates Required**:
- `docs/runbooks/bootstrap.md`: Document FortiGate manual bootstrap steps with screenshots
- `docs/architecture/network-topology.md`: Create network diagram showing VLANs, subnets, firewall rules
- `docs/troubleshooting/`: Capture any issues encountered during implementation for future reference

---

**Plan Status**: Complete and Ready for Task Generation
**Next Command**: `/speckit.tasks` (generates dependency-ordered tasks.md)
**Estimated Implementation Time**: 3-5 days (assuming hardware ready, network prerequisites complete)
