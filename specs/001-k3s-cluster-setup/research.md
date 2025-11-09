# Research Documentation: K3s HA Cluster Setup - ChocolandiaDC

**Feature**: `001-k3s-cluster-setup`
**Date**: 2025-11-08
**Status**: Phase 0 Complete
**Related Documents**: [spec.md](./spec.md) | [plan.md](./plan.md)

## Purpose

This document captures the research, technical decisions, alternatives considered, and implementation guidance for building a production-grade K3s high-availability cluster in a homelab environment with FortiGate network infrastructure. It serves as both a learning artifact and operational reference for the ChocolandiaDC homelab project.

---

## Table of Contents

1. [Technical Decisions](#technical-decisions)
   - [1.1 OpenTofu vs Terraform](#11-opentofu-vs-terraform)
   - [1.2 FortiGate 100D vs pfSense/OPNsense](#12-fortigate-100d-vs-pfsenseopnsense)
   - [1.3 K3s vs K8s/RKE2/Kubeadm](#13-k3s-vs-k8srke2kubeadm)
   - [1.4 3+1 Node Topology](#14-31-node-topology)
   - [1.5 VLAN Segmentation Design](#15-vlan-segmentation-design)
   - [1.6 Prometheus + Grafana Stack](#16-prometheus--grafana-stack)
   - [1.7 Raspberry Pi for Auxiliary Services](#17-raspberry-pi-for-auxiliary-services)
   - [1.8 Embedded etcd vs External etcd](#18-embedded-etcd-vs-external-etcd)
   - [1.9 FortiOS Provider Usage Patterns](#19-fortios-provider-usage-patterns)
   - [1.10 Network-First Deployment Order](#110-network-first-deployment-order)

2. [Best Practices](#best-practices)
   - [2.1 OpenTofu Module Design](#21-opentofu-module-design)
   - [2.2 FortiGate VLAN Configuration](#22-fortigate-vlan-configuration)
   - [2.3 K3s HA Setup](#23-k3s-ha-setup)
   - [2.4 Network Testing & Validation](#24-network-testing--validation)

3. [Reference Architecture](#reference-architecture)
4. [Learning Resources](#learning-resources)

---

## Technical Decisions

### 1.1 OpenTofu vs Terraform

**Decision**: Use OpenTofu as the primary Infrastructure as Code tool for all provisioning.

#### Rationale

1. **Open Source Commitment**: OpenTofu is a Linux Foundation project and true open-source fork of Terraform, eliminating concerns about vendor lock-in or license changes (Terraform moved to BSL in 2023).

2. **Compatibility**: OpenTofu maintains HCL syntax compatibility with Terraform, allowing use of existing Terraform modules, providers (FortiOS, Helm, Kubernetes), and documentation.

3. **Community-Driven Development**: As a community-governed project, OpenTofu's roadmap aligns with user needs rather than commercial interests.

4. **Learning Value**: Understanding the Terraform→OpenTofu fork teaches valuable lessons about open-source governance, licensing, and tool selection in enterprise environments.

5. **Feature Parity**: OpenTofu 1.6+ provides equivalent functionality to Terraform 1.5.x with additional improvements (state encryption, improved testing framework).

#### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| **Terraform** | Industry standard, larger ecosystem, more documentation | BSL license (not fully open source), vendor lock-in risk, potential future licensing changes | Constitution Principle I requires open-source IaC; BSL license conflicts with homelab philosophy |
| **Ansible** | Agentless, simple YAML syntax, strong configuration management | Lacks native state management, imperative (less declarative), weaker provider ecosystem for networking | Poor fit for network infrastructure (FortiGate); state management critical for learning infrastructure drift |
| **Pulumi** | Real programming languages (Python, Go, TypeScript), type safety | Steeper learning curve, smaller provider ecosystem, less homelab-focused documentation | Over-engineering for homelab; HCL is industry standard for network/cloud infrastructure |
| **Manual Configuration** | No tooling overhead, full control | Not reproducible, no version control, error-prone, defeats learning goals | Violates Constitution Principle I (IaC first); eliminates learning value of declarative infrastructure |

#### Trade-offs

**Accepted**:
- Smaller community than Terraform (but growing rapidly)
- Newer project (less battle-tested in production, though based on mature Terraform codebase)
- Some providers may lag behind Terraform versions (requires monitoring)

**Mitigated**:
- OpenTofu maintains Terraform provider compatibility via registry mirroring
- Active development and monthly releases ensure rapid bug fixes
- For homelab, stability more important than cutting-edge features

#### Implementation Notes

**Installation**:
```bash
# macOS (Homebrew)
brew install opentofu

# Verify installation
tofu version
```

**Version Constraints** (`versions.tf`):
```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    fortios = {
      source  = "fortinetdev/fortios"
      version = "~> 1.19.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}
```

**Key Commands**:
- `tofu init` - Initialize providers and modules
- `tofu validate` - Validate HCL syntax
- `tofu fmt` - Format code (run before commits)
- `tofu plan` - Preview changes (ALWAYS review before apply)
- `tofu apply` - Apply changes (network first, then cluster)
- `tofu destroy` - Tear down infrastructure (for testing reproducibility)

**Constitution Alignment**: Principle I (Infrastructure as Code - OpenTofu First)

**References**:
- OpenTofu Documentation: https://opentofu.org/docs/
- OpenTofu GitHub: https://github.com/opentofu/opentofu
- Provider Registry: https://github.com/opentofu/registry

---

### 1.2 FortiGate 100D vs pfSense/OPNsense

**Decision**: Use FortiGate 100D as the network security platform for edge firewall, routing, and VLAN management.

#### Rationale

1. **Enterprise-Grade Learning**: FortiGate teaches enterprise networking and security concepts (FortiOS CLI, IDS/IPS, application control, centralized management) used in production environments.

2. **Advanced Security Features**:
   - Unified Threat Management (UTM): IPS/IDS, antivirus, web filtering, application control
   - VLAN management with advanced routing (policy-based routing, OSPF/BGP support)
   - VPN capabilities (IPsec, SSL VPN for remote access to homelab)
   - Centralized logging and reporting (FortiAnalyzer integration for advanced learning)

3. **IaC Support**: Official FortiOS Terraform provider enables full configuration as code (VLANs, firewall policies, routing, DHCP).

4. **Hardware Availability**: FortiGate 100D is available on secondary market at reasonable prices for homelabs (compared to new enterprise firewalls).

5. **Transferable Skills**: FortiGate experience directly transfers to enterprise roles (FortiGate is #3 firewall vendor globally).

#### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| **pfSense** | Free and open source, strong community, web GUI, hardware agnostic | No official Terraform provider (community providers are incomplete), primarily GUI-driven (less IaC-friendly) | Lack of mature IaC support conflicts with Constitution Principle I; GUI-first approach limits automation learning |
| **OPNsense** | pfSense fork with modern UI, more frequent updates, API support | Terraform provider is experimental, smaller plugin ecosystem, less enterprise adoption | Similar IaC limitations to pfSense; less enterprise learning value |
| **VyOS** | Fully open source, CLI-driven, strong routing features | Weaker firewall/security features vs UTM, smaller ecosystem, less GUI (steeper learning curve) | Lacks integrated security features (IPS, application control); would require separate solutions |
| **MikroTik** | Very affordable, powerful routing, VLAN support | Complex proprietary configuration language, weak IaC support, limited UTM features | Poor IaC integration; RouterOS syntax not transferable to enterprise environments |
| **Linux iptables/nftables** | Maximum flexibility, fully open source, lightweight | Manual configuration intensive, no unified management plane, steep learning curve | Too low-level for homelab efficiency; lacks integrated VLAN/routing management |

#### Trade-offs

**Accepted**:
- **Cost**: FortiGate 100D requires hardware purchase (vs free pfSense/OPNsense on generic hardware)
- **Licensing**: Advanced features (IPS, antivirus, web filtering) require FortiGuard subscription (optional for basic firewall/VLAN functions)
- **Vendor Lock-in**: FortiOS configuration is FortiGate-specific (not portable to other platforms)

**Mitigated**:
- Basic firewall, VLAN, routing, and DHCP features work without subscription
- FortiOS provider enables configuration portability across FortiGate models
- Learning FortiGate concepts (zones, policies, objects) transfers to other enterprise firewalls (Palo Alto, Cisco ASA)

#### Implementation Notes

**FortiGate Initial Setup** (Manual - One-Time Only):
1. Connect to management port (default IP: 192.168.1.99)
2. Configure admin password and management IP
3. Enable FortiOS API access:
   ```
   config system api-user
       edit "opentofu"
           set accprofile "super_admin"
           set vdom "root"
           config trusthost
               edit 1
                   set ipv4-trusthost <your-workstation-ip>/32
               next
           end
       next
   end
   ```
4. Generate API token (store securely - never commit to Git)

**OpenTofu Provider Configuration**:
```hcl
provider "fortios" {
  hostname = var.fortigate_ip
  token    = var.fortigate_api_token  # Store in environment variable or vault
  insecure = true  # For homelab self-signed certs; disable in production
}
```

**VLAN Configuration Pattern** (see section 1.5 for design details):
```hcl
resource "fortios_system_interface" "management_vlan" {
  name       = "management"
  vdom       = "root"
  mode       = "static"
  ip         = "10.0.10.1 255.255.255.0"
  vlanid     = 10
  interface  = "internal"  # Physical port on FortiGate
  allowaccess = "ping https ssh"  # Admin access
}
```

**Firewall Policy Pattern**:
```hcl
resource "fortios_firewall_policy" "cluster_to_internet" {
  name     = "cluster-to-internet"
  srcintf {
    name = "cluster"  # VLAN 20
  }
  dstintf {
    name = "wan1"
  }
  srcaddr {
    name = "cluster-subnet"  # 10.0.20.0/24
  }
  dstaddr {
    name = "all"
  }
  action   = "accept"
  schedule = "always"
  service {
    name = "ALL"  # Restrict to specific services in production
  }
  nat      = "enable"
  logtraffic = "all"  # Critical for learning traffic patterns
}
```

**Best Practices**:
- Always use FortiOS objects (address groups, service groups) instead of inline addresses
- Enable logging on all policies for learning and troubleshooting
- Test firewall rules with manual traffic before automating in OpenTofu
- Export FortiGate config backup before major changes: `execute backup config management-station <filename>`

**Constitution Alignment**: Principle IX (Network-First Security), Principle V (Security Hardening)

**References**:
- FortiOS Provider Documentation: https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs
- FortiGate 100D Datasheet: https://www.fortinet.com/content/dam/fortinet/assets/data-sheets/FortiGate_100D_Series.pdf
- FortiOS CLI Reference: https://docs.fortinet.com/document/fortigate/7.4.0/cli-reference/

---

### 1.3 K3s vs K8s/RKE2/Kubeadm

**Decision**: Use K3s as the Kubernetes distribution for the homelab cluster.

#### Rationale

1. **Lightweight & Resource-Efficient**: K3s has a small binary (<100MB) and minimal memory footprint, ideal for mini-PC hardware (4GB RAM minimum vs 8GB+ for full K8s).

2. **Batteries-Included**: K3s bundles essential components out-of-the-box:
   - Embedded etcd (no external datastore needed for HA)
   - Local-path storage provisioner (dynamic PVC creation)
   - Traefik ingress controller (immediate ingress support)
   - CoreDNS (cluster DNS)
   - Metrics server (resource metrics for HPA)

3. **HA-Capable**: K3s supports embedded etcd HA mode with quorum (3+ control-plane nodes), matching full Kubernetes capabilities.

4. **Production-Ready**: K3s is CNCF-certified Kubernetes, fully API-compatible, and used in production edge deployments (Rancher, SUSE).

5. **Simple Installation**: Single-command installation via shell script (ideal for OpenTofu SSH provisioner automation).

6. **Edge/IoT Optimized**: Designed for resource-constrained environments, making it perfect for homelab learning before scaling to full K8s.

#### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| **Kubeadm (Vanilla K8s)** | Official Kubernetes tooling, maximum configurability, most documentation | Complex HA setup, requires external etcd or stacked etcd configuration, higher resource requirements (8GB+ RAM), more components to manage | Over-engineering for homelab; mini-PCs lack resources; operational complexity outweighs learning value for basic Kubernetes |
| **RKE2** | Rancher's hardened K8s, CIS benchmark compliance, dual-stack networking | More complex than K3s, larger binary size, steeper learning curve | Security hardening (CIS compliance) is overkill for homelab; added complexity doesn't provide learning value for basic K8s concepts |
| **MicroK8s** | Snap-based, simple installation, addon system | Snap dependency (Ubuntu-specific), less common in production, smaller community | Snap limitation reduces portability; K3s has broader adoption in edge/IoT production environments |
| **K0s** | Zero-friction Kubernetes, single binary, good for edge | Newer project (less mature), smaller ecosystem, less HA documentation | K3s has more mature HA embedded etcd implementation and better OpenTofu integration patterns |
| **Kind (Kubernetes in Docker)** | Perfect for local development, fast iteration | Not designed for multi-node physical clusters, lacks persistence, no production use case | Kind is for development environments, not physical multi-node clusters; defeats homelab hardware learning |

#### Trade-offs

**Accepted**:
- **Opinionated Defaults**: K3s makes choices for you (Traefik ingress, SQLite/etcd storage) which reduces configurability vs kubeadm
- **Less Control**: Some components are embedded/hardcoded (harder to swap ingress controller or storage backend)
- **Production Perception**: Some enterprises view K3s as "toy Kubernetes" (despite being production-ready)

**Mitigated**:
- K3s allows disabling built-in components (`--disable traefik` for custom ingress)
- HA etcd mode provides production-grade reliability
- K3s is API-compatible with full Kubernetes (workloads are portable)
- Skills learned (kubectl, manifests, Helm, networking) transfer directly to full K8s

#### Implementation Notes

**Installation via OpenTofu SSH Provisioner**:

**First Control-Plane Node** (master1):
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san ${LOAD_BALANCER_IP} \
  --node-name master1
```

**Additional Control-Plane Nodes** (master2, master3):
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://${MASTER1_IP}:6443 \
  --token ${K3S_TOKEN} \
  --disable traefik \
  --node-name master2
```

**Worker Node** (nodo1):
```bash
curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://${MASTER1_IP}:6443 \
  --token ${K3S_TOKEN} \
  --node-name nodo1
```

**Critical Flags**:
- `--cluster-init`: Initialize embedded etcd (first control-plane node only)
- `--disable traefik`: Remove default ingress (we'll install custom stack later)
- `--write-kubeconfig-mode 644`: Make kubeconfig readable (for automation; secure in production)
- `--tls-san <IP>`: Add load balancer IP to API server certificate (for HA access)
- `--token`: Shared secret for node authentication (generate securely, rotate periodically)

**Retrieving kubeconfig**:
```bash
# On master1
sudo cat /etc/rancher/k3s/k3s.yaml

# Modify server URL to load balancer IP
# server: https://<LOAD_BALANCER_IP>:6443

# Copy to workstation ~/.kube/config
```

**Verification**:
```bash
kubectl get nodes -o wide
kubectl get pods -A  # All system pods should be Running
kubectl cluster-info
```

**Constitution Alignment**: Principle VI (High Availability Architecture), Principle III (Container-First)

**References**:
- K3s Documentation: https://docs.k3s.io/
- K3s High Availability: https://docs.k3s.io/datastore/ha-embedded
- K3s Installation Options: https://docs.k3s.io/installation/configuration

---

### 1.4 3+1 Node Topology

**Decision**: Deploy 3 control-plane nodes (Lenovo mini computers) + 1 worker node (HP ProDesk) for the initial cluster configuration.

#### Rationale

1. **Etcd Quorum Requirements**: Etcd requires a majority (quorum) to operate. With 3 nodes, the cluster can survive 1 node failure while maintaining quorum (2/3 nodes operational). This is the minimum viable HA configuration.

2. **Hardware Optimization**: Leveraging existing hardware (3 Lenovo + 1 HP ProDesk) to maximize learning value:
   - All 3 Lenovo nodes as control-plane ensures etcd HA (vs 2 control-plane which provides no HA benefit)
   - HP ProDesk as dedicated worker separates control-plane from workload execution (production best practice)

3. **Learning Goals**:
   - **Distributed consensus**: Understanding etcd quorum, leader election, and split-brain scenarios
   - **Control-plane HA**: Testing API availability during node failures
   - **Workload isolation**: Demonstrating control-plane taints and worker scheduling

4. **Scalability Path**: Starting with 1 worker allows future expansion to 3 workers (nodo2, nodo3) without control-plane changes, teaching horizontal scaling.

5. **Cost-Efficiency**: Uses all available hardware without requiring additional purchases for initial cluster.

#### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| **1 Control-Plane + 3 Workers** | Maximizes workload capacity, simpler initial setup | No HA (single point of failure), defeats learning goal of distributed systems | Violates Constitution Principle VI (HA Architecture); no learning value for etcd/quorum |
| **2 Control-Plane + 2 Workers** | Balanced compute/control, more worker capacity | 2-node etcd provides NO HA benefit (quorum still requires 2/2, same as 1/1), wastes hardware | Etcd with 2 replicas has no failure tolerance; logically equivalent to single control-plane |
| **5 Control-Plane + 0 Workers** | Maximum HA (tolerates 2 failures) | No dedicated workers (control-plane runs workloads, bad practice), requires 5 nodes (we have 4) | Requires additional hardware; control-plane running workloads is anti-pattern |
| **3 Control-Plane + 3 Workers** | Production-grade topology, full separation | Requires 6 total nodes (we have 4 mini-PCs), expensive hardware expansion | Hardware constraint (only 4 mini-PCs available); can expand later with nodo2, nodo3 |

#### Trade-offs

**Accepted**:
- **Limited Worker Capacity**: 1 worker node limits workload capacity (vs 2-3 workers)
- **Control-Plane Underutilization**: Control-plane nodes have idle CPU/memory (etcd/API server are lightweight)
- **Resource Imbalance**: HP ProDesk worker may have different specs than Lenovo control-plane nodes

**Mitigated**:
- Control-plane nodes can run workloads if needed (remove NoSchedule taint for testing)
- Single worker is sufficient for homelab services (Prometheus, Grafana, Pi-hole, testing apps)
- Future expansion: Add nodo2, nodo3 when additional mini-PCs are available
- Heterogeneous nodes teach resource-aware scheduling (node selectors, affinity, resource requests/limits)

#### Implementation Notes

**Etcd Quorum Calculation**:
| Total Nodes | Quorum Required | Max Failures Tolerated |
|-------------|-----------------|------------------------|
| 1           | 1               | 0 (no HA)              |
| 2           | 2               | 0 (no HA benefit)      |
| **3**       | **2**           | **1** ← Our choice     |
| 4           | 3               | 1 (waste of resources) |
| 5           | 3               | 2                      |

**Control-Plane Taints** (K3s default):
```bash
# K3s automatically taints control-plane nodes
kubectl describe node master1 | grep Taints
# Output: node-role.kubernetes.io/control-plane:NoSchedule
```

**Workload Scheduling**:
```yaml
# Tolerate control-plane taint (for testing only)
spec:
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

# Force scheduling on workers (production pattern)
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: "true"
```

**Testing HA Behavior**:
```bash
# Simulate master1 failure
ssh ubuntu@master1 "sudo systemctl stop k3s"

# Verify API availability via master2/master3
kubectl get nodes  # Should still work (via load balancer IP)

# Check etcd quorum
kubectl -n kube-system exec -it <etcd-pod> -- etcdctl member list

# Restore master1
ssh ubuntu@master1 "sudo systemctl start k3s"
kubectl get nodes  # master1 should rejoin
```

**Expansion Procedure** (Adding nodo2, nodo3 later):
1. Update OpenTofu `terraform.tfvars` with new worker nodes
2. Run `tofu apply` (new nodes auto-join via K3s agent command)
3. Verify with `kubectl get nodes`
4. No control-plane changes required (etcd quorum unchanged)

**Constitution Alignment**: Principle VI (High Availability Architecture)

**References**:
- Etcd Admin Guide: https://etcd.io/docs/v3.5/op-guide/runtime-configuration/
- K3s Server/Agent Configuration: https://docs.k3s.io/reference/server-config

---

### 1.5 VLAN Segmentation Design

**Decision**: Implement 4-VLAN architecture for traffic isolation and security.

#### Rationale

1. **Security Isolation**: VLANs create Layer 2 broadcast domains and enforce Layer 3 routing control via firewall, preventing lateral movement between network segments.

2. **Blast Radius Containment**: Compromised services in one VLAN cannot directly access other VLANs without passing through FortiGate firewall rules.

3. **Traffic Management**: VLAN segmentation enables:
   - QoS prioritization (cluster traffic prioritized over services traffic)
   - Bandwidth allocation (limit services VLAN to prevent cluster starvation)
   - Monitoring and logging per VLAN (identify traffic patterns and anomalies)

4. **Enterprise Learning**: VLAN design, inter-VLAN routing, and firewall zone concepts are fundamental to enterprise networking.

#### VLAN Allocation

| VLAN ID | Name         | Subnet         | Gateway      | Purpose                                      | Devices                          |
|---------|--------------|----------------|--------------|----------------------------------------------|----------------------------------|
| **10**  | Management   | 10.0.10.0/24   | 10.0.10.1    | Administrative access, FortiGate GUI, SSH    | Workstation, FortiGate, Jump Host|
| **20**  | Cluster      | 10.0.20.0/24   | 10.0.20.1    | K3s nodes communication (API, etcd, pods)    | master1-3, nodo1                 |
| **30**  | Services     | 10.0.30.0/24   | 10.0.30.1    | Auxiliary services (Pi-hole, DNS, future NFS)| Raspberry Pi                     |
| **40**  | DMZ          | 10.0.40.0/24   | 10.0.40.1    | Exposed services (optional - future use)     | (Reserved for public-facing apps)|

**Network IP Allocations** (DHCP Reservations on FortiGate):

**Management VLAN (10)**:
- 10.0.10.1 - FortiGate management interface
- 10.0.10.10 - Raspberry Pi (jump host, SSH bastion)
- 10.0.10.100-199 - DHCP pool for admin workstations

**Cluster VLAN (20)**:
- 10.0.20.1 - FortiGate gateway
- 10.0.20.11 - master1 (Lenovo 1)
- 10.0.20.12 - master2 (Lenovo 2)
- 10.0.20.13 - master3 (Lenovo 3)
- 10.0.20.21 - nodo1 (HP ProDesk)
- 10.0.20.22-23 - Reserved for nodo2, nodo3 (future expansion)

**Services VLAN (30)**:
- 10.0.30.1 - FortiGate gateway
- 10.0.30.10 - Raspberry Pi (Pi-hole, DNS server)

**DMZ VLAN (40)**:
- 10.0.40.1 - FortiGate gateway
- 10.0.40.0/24 - Reserved for future public services

#### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| **Flat Network (No VLANs)** | Simple, no routing complexity, all devices on one subnet | No traffic isolation, no security boundaries, no learning value | Violates Constitution Principle IX (Network-First Security); defeats enterprise networking learning goals |
| **2 VLANs (Management + Everything)** | Minimal complexity, basic isolation | Cluster and services in same VLAN (security risk), less granular control | Insufficient isolation (cluster compromise affects services); misses learning opportunity for multi-VLAN routing |
| **6+ VLANs (Hyper-segmentation)** | Maximum isolation, fine-grained control | Over-engineering for homelab, complex firewall rules, more failure points | Violates Constitution (avoid unnecessary complexity); 4 VLANs sufficient for learning and security |

#### Trade-offs

**Accepted**:
- **Routing Overhead**: Inter-VLAN traffic requires Layer 3 routing through FortiGate (slight latency increase)
- **Firewall Complexity**: More VLANs = more firewall rules to manage and test
- **DHCP Management**: Separate DHCP pools per VLAN requires careful IP allocation planning

**Mitigated**:
- FortiGate hardware routing is fast (negligible latency for homelab traffic)
- OpenTofu manages firewall rules declaratively (reducing manual errors)
- DHCP reservations prevent IP conflicts and simplify troubleshooting

#### Implementation Notes

**FortiGate VLAN Configuration** (OpenTofu):
```hcl
# Management VLAN
resource "fortios_system_interface" "management" {
  name       = "management"
  vdom       = "root"
  mode       = "static"
  ip         = "10.0.10.1 255.255.255.0"
  vlanid     = 10
  interface  = "internal"
  allowaccess = "ping https ssh"
}

# Cluster VLAN
resource "fortios_system_interface" "cluster" {
  name       = "cluster"
  vdom       = "root"
  mode       = "static"
  ip         = "10.0.20.1 255.255.255.0"
  vlanid     = 20
  interface  = "internal"
  allowaccess = "ping"  # No admin access from cluster VLAN
}

# Services VLAN
resource "fortios_system_interface" "services" {
  name       = "services"
  vdom       = "root"
  mode       = "static"
  ip         = "10.0.30.1 255.255.255.0"
  vlanid     = 30
  interface  = "internal"
  allowaccess = "ping"
}

# DMZ VLAN (future)
resource "fortios_system_interface" "dmz" {
  name       = "dmz"
  vdom       = "root"
  mode       = "static"
  ip         = "10.0.40.1 255.255.255.0"
  vlanid     = 40
  interface  = "internal"
  allowaccess = ""  # No direct access to FortiGate from DMZ
}
```

**DHCP Configuration** (OpenTofu):
```hcl
resource "fortios_system_dhcpserver" "cluster_dhcp" {
  interface       = "cluster"
  dns_service     = "local"
  default_gateway = "10.0.20.1"
  netmask         = "255.255.255.0"

  ip_range {
    start_ip = "10.0.20.100"
    end_ip   = "10.0.20.199"
  }

  # Static reservations for K3s nodes
  reserved_address {
    ip     = "10.0.20.11"
    mac    = "aa:bb:cc:dd:ee:11"  # master1 MAC
    action = "reserved"
  }
  # Repeat for master2, master3, nodo1...
}
```

**Firewall Policy Examples**:
```hcl
# 1. Management → Cluster (SSH access for administration)
resource "fortios_firewall_policy" "mgmt_to_cluster_ssh" {
  name     = "mgmt-to-cluster-ssh"
  srcintf {
    name = "management"
  }
  dstintf {
    name = "cluster"
  }
  srcaddr {
    name = "management-subnet"  # 10.0.10.0/24
  }
  dstaddr {
    name = "cluster-nodes"  # Address group: master1-3, nodo1
  }
  action   = "accept"
  service {
    name = "SSH"
  }
  logtraffic = "all"
}

# 2. Cluster → Internet (for pulling container images)
resource "fortios_firewall_policy" "cluster_to_internet" {
  name     = "cluster-to-internet"
  srcintf {
    name = "cluster"
  }
  dstintf {
    name = "wan1"
  }
  srcaddr {
    name = "cluster-subnet"
  }
  dstaddr {
    name = "all"
  }
  action   = "accept"
  service {
    name = "HTTPS"  # Only HTTPS for image pulls (restrict HTTP in production)
  }
  nat      = "enable"
  logtraffic = "all"
}

# 3. Cluster → Services (DNS queries to Pi-hole)
resource "fortios_firewall_policy" "cluster_to_pihole" {
  name     = "cluster-to-pihole-dns"
  srcintf {
    name = "cluster"
  }
  dstintf {
    name = "services"
  }
  srcaddr {
    name = "cluster-subnet"
  }
  dstaddr {
    name = "pihole-ip"  # 10.0.30.10
  }
  action   = "accept"
  service {
    name = "DNS"
  }
  logtraffic = "all"
}

# 4. Services → Internet (Pi-hole blocklist updates)
resource "fortios_firewall_policy" "services_to_internet" {
  name     = "services-to-internet"
  srcintf {
    name = "services"
  }
  dstintf {
    name = "wan1"
  }
  srcaddr {
    name = "services-subnet"
  }
  dstaddr {
    name = "all"
  }
  action   = "accept"
  service {
    name = "HTTPS"
  }
  nat      = "enable"
  logtraffic = "all"
}

# 5. DENY rule (default deny - log dropped traffic)
resource "fortios_firewall_policy" "deny_all" {
  name     = "deny-all-inter-vlan"
  srcintf {
    name = "any"
  }
  dstintf {
    name = "any"
  }
  srcaddr {
    name = "all"
  }
  dstaddr {
    name = "all"
  }
  action   = "deny"
  service {
    name = "ALL"
  }
  logtraffic = "all"  # Critical for learning blocked traffic patterns
}
```

**Testing VLAN Connectivity**:
```bash
# From workstation (Management VLAN) to cluster nodes
ping 10.0.20.11  # Should work (management → cluster allowed)

# From master1 to Raspberry Pi DNS
ssh ubuntu@10.0.20.11
ping 10.0.30.10  # Should work if cluster → services allowed

# From cluster to management (should fail - default deny)
ssh ubuntu@10.0.20.11
ping 10.0.10.1  # Should timeout (no rule allowing cluster → management)
```

**Constitution Alignment**: Principle IX (Network-First Security), Principle V (Security Hardening)

**References**:
- FortiGate VLAN Configuration: https://docs.fortinet.com/document/fortigate/7.4.0/administration-guide/983642/vlan-interfaces
- FortiGate Firewall Policies: https://docs.fortinet.com/document/fortigate/7.4.0/administration-guide/632378/firewall-policies

---

### 1.6 Prometheus + Grafana Stack

**Decision**: Deploy Prometheus and Grafana as the monitoring and observability solution using the kube-prometheus-stack Helm chart.

#### Rationale

1. **Industry Standard**: Prometheus is the de facto monitoring solution for Kubernetes and cloud-native applications (CNCF graduated project).

2. **Comprehensive Coverage**: kube-prometheus-stack includes:
   - Prometheus Operator (declarative monitoring configuration via CRDs)
   - Grafana (pre-configured dashboards for K8s cluster health)
   - Alertmanager (alert routing and silencing)
   - Node Exporter (host-level metrics: CPU, memory, disk, network)
   - kube-state-metrics (Kubernetes object state metrics)
   - Pre-built dashboards (cluster overview, node health, pod resources)

3. **Learning Value**: Teaches fundamental observability concepts:
   - Metrics collection (pull-based scraping)
   - PromQL (Prometheus Query Language for metric analysis)
   - Service discovery (automatic target discovery in Kubernetes)
   - Alerting rules and escalation
   - Dashboard design and visualization

4. **Declarative Configuration**: Prometheus Operator uses ServiceMonitor and PodMonitor CRDs, enabling GitOps-friendly monitoring configuration.

5. **Low Overhead**: Prometheus and Grafana are lightweight enough for homelab mini-PCs.

#### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| **ELK Stack (Elasticsearch, Logstash, Kibana)** | Powerful log aggregation, full-text search, rich visualizations | Heavy resource requirements (JVM), complex setup, primarily log-focused (not metrics) | Too resource-intensive for mini-PCs; Prometheus better suited for metrics in K8s environments |
| **Datadog / New Relic** | Managed SaaS, rich features, low operational overhead | Expensive for homelabs, vendor lock-in, data leaves homelab (privacy concern) | Cost prohibitive; defeats self-hosted homelab philosophy; no control over data |
| **VictoriaMetrics** | High-performance Prometheus alternative, better compression | Less mature ecosystem, steeper learning curve, fewer pre-built dashboards | Prometheus is industry standard; learning value is higher with widespread adoption |
| **Netdata** | Beautiful real-time dashboards, zero-configuration | Limited historical data retention, less query flexibility (no PromQL), weaker alerting | Lacks long-term metrics storage; PromQL is critical for learning advanced queries |
| **Manual Logging (syslog)** | Simple, lightweight, built-in | No structured metrics, no visualization, manual log parsing | Lacks metrics collection (only logs); no time-series data for performance analysis |

#### Trade-offs

**Accepted**:
- **Resource Usage**: Prometheus + Grafana consume ~2GB RAM combined (significant on 4GB nodes)
- **Learning Curve**: PromQL requires learning a new query language
- **Storage Requirements**: Metrics storage grows over time (15-day retention = ~10GB disk)

**Mitigated**:
- Deploy monitoring stack on dedicated worker node (nodo1) to isolate resource usage
- Set resource limits in Helm values to prevent memory exhaustion
- Configure Prometheus retention (15 days) and enable compression
- PromQL learning is a valuable transferable skill (used in production environments)

#### Implementation Notes

**Installation via Helm** (OpenTofu Helm Provider):
```hcl
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "51.0.0"
  namespace  = "monitoring"
  create_namespace = true

  values = [
    file("${path.module}/monitoring-values.yaml")
  ]
}
```

**Helm Values Configuration** (`monitoring-values.yaml`):
```yaml
prometheus:
  prometheusSpec:
    retention: 15d  # 15-day metrics retention (balance storage vs learning)
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi  # Local-path storage
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 1000m
        memory: 2Gi

grafana:
  adminPassword: "<SECURE_PASSWORD>"  # Store in vault, not Git
  persistence:
    enabled: true
    size: 5Gi
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
  ingress:
    enabled: true
    hosts:
      - grafana.chocolandiadc.local  # Internal DNS via Pi-hole

alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 200m
        memory: 512Mi

# Pre-configure Node Exporter for all nodes
nodeExporter:
  enabled: true

# Enable kube-state-metrics for K8s object metrics
kubeStateMetrics:
  enabled: true
```

**Custom ServiceMonitor Example** (Monitor FortiGate SNMP - Advanced):
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fortigate-snmp
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: snmp-exporter
  endpoints:
  - port: metrics
    interval: 30s
```

**Key Grafana Dashboards** (Pre-Installed):
- **Kubernetes / Compute Resources / Cluster**: Overall cluster CPU, memory, network
- **Kubernetes / Compute Resources / Namespace (Pods)**: Per-namespace resource usage
- **Node Exporter / Nodes**: Host-level metrics (disk, network interfaces)
- **Kubernetes / Persistent Volumes**: PVC usage and health

**Accessing Grafana**:
```bash
# Port-forward for initial access
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open browser: http://localhost:3000
# Default credentials: admin / <SECURE_PASSWORD from Helm values>
```

**PromQL Learning Examples**:
```promql
# CPU usage per node
sum(rate(node_cpu_seconds_total{mode!="idle"}[5m])) by (instance)

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod restart rate
rate(kube_pod_container_status_restarts_total[5m]) > 0

# etcd leader elections (HA health indicator)
rate(etcd_server_leader_changes_seen_total[5m]) > 0
```

**Alerting Rule Example**:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: node-alerts
  namespace: monitoring
spec:
  groups:
  - name: nodes
    interval: 30s
    rules:
    - alert: NodeDown
      expr: up{job="node-exporter"} == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Node {{ $labels.instance }} is down"
        description: "Node has been down for more than 2 minutes"
```

**Constitution Alignment**: Principle IV (Observability & Monitoring - NON-NEGOTIABLE)

**References**:
- kube-prometheus-stack Chart: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- Prometheus Documentation: https://prometheus.io/docs/introduction/overview/
- Grafana Dashboards: https://grafana.com/grafana/dashboards/
- PromQL Guide: https://prometheus.io/docs/prometheus/latest/querying/basics/

---

### 1.7 Raspberry Pi for Auxiliary Services

**Decision**: Use Raspberry Pi as a dedicated auxiliary services node for Pi-hole, DNS, and jump host/bastion.

#### Rationale

1. **Separation of Concerns**: Keeping DNS and jump host separate from K3s cluster prevents circular dependencies (cluster depends on DNS, DNS depends on cluster).

2. **Always-On Services**: Pi-hole and jump host should remain available even during cluster maintenance or failures.

3. **Resource Efficiency**: Raspberry Pi is low-power and sufficient for lightweight services (DNS, SSH bastion).

4. **Cost-Effective**: Raspberry Pi is inexpensive and doesn't consume a K3s node slot.

5. **Learning Value**: Demonstrates heterogeneous infrastructure management (ARM-based Pi + x86 mini-PCs).

#### Services on Raspberry Pi

| Service | Purpose | Justification |
|---------|---------|---------------|
| **Pi-hole** | Network-wide DNS ad-blocking | Centralized DNS for entire homelab; blocks ads for all devices |
| **DNS Server** | Internal DNS resolution (*.chocolandiadc.local) | Resolves cluster service names, FortiGate hostname, etc. |
| **Jump Host / Bastion** | SSH gateway to cluster nodes | Single entry point for cluster access (aligns with Principle V - least privilege) |

#### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| **DNS on FortiGate** | One less device, FortiGate has built-in DNS | No ad-blocking, limited DNS customization (no custom records), no learning value for service deployment | FortiGate DNS is basic; Pi-hole teaches DNS configuration, blocklists, and monitoring |
| **DNS as K8s Service** | Fully containerized, managed by K8s | Circular dependency (cluster needs DNS to bootstrap), cluster failure breaks DNS | DNS must be external to cluster to avoid bootstrap chicken-and-egg problem |
| **Jump Host on Workstation** | No additional hardware | Workstation not always-on, defeats separation of homelab/workstation | Jump host should be homelab-resident for 24/7 availability |
| **No Jump Host (Direct SSH)** | Simpler, fewer hops | Less secure (all nodes exposed to SSH), violates least privilege | Constitution Principle V requires jump host pattern for defense in depth |

#### Trade-offs

**Accepted**:
- **Single Point of Failure**: Raspberry Pi failure breaks DNS and SSH access
- **ARM Architecture**: Raspberry Pi uses ARM (vs x86 mini-PCs), requiring ARM-compatible images
- **Limited Resources**: Raspberry Pi has less CPU/RAM than mini-PCs

**Mitigated**:
- Pi-hole has minimal resource requirements (runs well on Raspberry Pi Zero)
- Fallback DNS: Configure FortiGate as secondary DNS (degraded mode without ad-blocking)
- Raspberry Pi reliability is high (solid-state SD card, UPS backup recommended)

#### Implementation Notes

**Raspberry Pi Setup** (Manual - One-Time):
1. Install Raspberry Pi OS Lite (64-bit for Pi 4/5)
2. Enable SSH: `sudo systemctl enable ssh`
3. Configure static IP via FortiGate DHCP reservation (10.0.30.10)
4. Harden SSH:
   ```bash
   # Disable password auth
   sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

**Pi-hole Installation** (via OpenTofu SSH Provisioner):
```bash
# One-step automated installer
curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended

# Configuration
pihole -a -p <ADMIN_PASSWORD>  # Set web admin password
pihole -a setdns 1.1.1.1 8.8.8.8  # Upstream DNS (Cloudflare, Google)

# Add custom DNS records (for homelab domains)
echo "10.0.20.11 master1.chocolandiadc.local" | sudo tee -a /etc/pihole/custom.list
echo "10.0.20.12 master2.chocolandiadc.local" | sudo tee -a /etc/pihole/custom.list
echo "10.0.20.13 master3.chocolandiadc.local" | sudo tee -a /etc/pihole/custom.list
echo "10.0.20.21 nodo1.chocolandiadc.local" | sudo tee -a /etc/pihole/custom.list

# Reload DNS
pihole restartdns
```

**Jump Host Configuration**:
```bash
# SSH bastion is already configured (SSH enabled)
# Users SSH to Raspberry Pi, then SSH to cluster nodes

# Example: From workstation
ssh ubuntu@10.0.10.10  # Jump host (Raspberry Pi)
# Then from jump host
ssh ubuntu@10.0.20.11  # master1
```

**SSH Config on Workstation** (Simplify access):
```bash
# ~/.ssh/config
Host jump
  HostName 10.0.10.10
  User ubuntu
  IdentityFile ~/.ssh/id_rsa

Host master1
  HostName 10.0.20.11
  User ubuntu
  ProxyJump jump

Host master2
  HostName 10.0.20.12
  User ubuntu
  ProxyJump jump

# Usage: ssh master1 (automatically routes through jump host)
```

**FortiGate DNS Configuration** (Point all VLANs to Pi-hole):
```hcl
resource "fortios_system_dhcpserver" "cluster_dhcp" {
  interface = "cluster"
  dns_server1 = "10.0.30.10"  # Pi-hole primary
  dns_server2 = "10.0.20.1"   # FortiGate fallback (if Pi-hole down)
  # ... other DHCP settings
}
```

**Testing Pi-hole DNS**:
```bash
# From any cluster node
nslookup master1.chocolandiadc.local 10.0.30.10
# Should resolve to 10.0.20.11

# Test ad-blocking
nslookup ads.example.com 10.0.30.10
# Should return 0.0.0.0 (blocked)
```

**Accessing Pi-hole Web Interface**:
```bash
# From workstation (Management VLAN)
http://10.0.30.10/admin

# Login with admin password set during installation
```

**Constitution Alignment**: Principle V (Security Hardening - jump host pattern), Principle IX (Network-First Security)

**References**:
- Pi-hole Documentation: https://docs.pi-hole.net/
- Pi-hole Custom DNS: https://docs.pi-hole.net/guides/dns/unbound/

---

### 1.8 Embedded etcd vs External etcd

**Decision**: Use K3s embedded etcd for the HA datastore.

#### Rationale

1. **Simplicity**: Embedded etcd runs within K3s server process (no separate etcd cluster to manage).

2. **Operational Overhead**: External etcd requires 3-5 additional VMs/containers, separate backups, and independent monitoring.

3. **Resource Efficiency**: Embedded etcd eliminates 3+ dedicated etcd nodes, saving hardware resources.

4. **K3s Native Support**: K3s is designed for embedded etcd HA (`--cluster-init` flag handles all etcd bootstrapping).

5. **Production-Ready**: K3s embedded etcd is production-grade and used in edge deployments.

#### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| **External etcd Cluster** | Separation of concerns, independent scaling, familiar to kubeadm users | Requires 3+ additional nodes, complex setup, more failure points, higher resource usage | Over-engineering for homelab; resource constraints (only 4 mini-PCs); operational complexity outweighs benefits |
| **MySQL / PostgreSQL** | K3s supports external databases, familiar SQL tooling | Single point of failure (unless clustered), worse performance than etcd, not etcd-compatible (no HA benefits) | No HA (defeats purpose); external DB adds complexity without benefits of etcd quorum |
| **SQLite (default K3s)** | Zero configuration, single binary | No HA support (single node only), not suitable for multi-control-plane | Cannot support HA cluster (single-node limitation) |

#### Trade-offs

**Accepted**:
- **Coupled Lifecycle**: etcd lifecycle is tied to K3s server process (etcd backup = K3s backup)
- **Resource Sharing**: etcd shares resources with control-plane components (API server, scheduler)

**Mitigated**:
- K3s provides `k3s etcd-snapshot` command for backups (automated via cron)
- Control-plane nodes have sufficient resources for embedded etcd (Lenovo mini-PCs with 8GB+ RAM)
- Monitoring Prometheus includes etcd metrics (etcd_server_leader_changes_seen_total, etcd_mvcc_db_total_size_in_bytes)

#### Implementation Notes

**Embedded etcd Initialization** (First Control-Plane Node):
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --token ${K3S_TOKEN}
```

**Joining Additional Control-Plane Nodes**:
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://${MASTER1_IP}:6443 \
  --token ${K3S_TOKEN}
```

**Verifying etcd Cluster Health**:
```bash
# From any control-plane node
sudo k3s etcd-snapshot ls  # List snapshots

# Check etcd members
sudo k3s kubectl get nodes -o wide

# Advanced: etcdctl commands (requires installing etcdctl)
export ETCDCTL_API=3
sudo etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  member list

# Expected output: 3 members (master1, master2, master3)
```

**Automated etcd Backups** (Cron on master1):
```bash
# /etc/cron.d/k3s-etcd-backup
0 2 * * * root /usr/local/bin/k3s etcd-snapshot save --name daily-backup-$(date +\%Y-\%m-\%d)
```

**Backup Retention** (Keep last 7 days):
```bash
# Cleanup old snapshots (run weekly)
sudo k3s etcd-snapshot prune --snapshot-retention 7
```

**Disaster Recovery** (Restore from Snapshot):
```bash
# Stop K3s on all control-plane nodes
sudo systemctl stop k3s

# On master1, restore from snapshot
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<snapshot-name>

# Restart K3s on master1
sudo systemctl start k3s

# Rejoin master2 and master3 (they will sync from master1)
```

**Constitution Alignment**: Principle VI (High Availability Architecture)

**References**:
- K3s Embedded etcd: https://docs.k3s.io/datastore/ha-embedded
- K3s Backup/Restore: https://docs.k3s.io/datastore/backup-restore

---

### 1.9 FortiOS Provider Usage Patterns

**Decision**: Use FortiOS Terraform provider for declarative FortiGate configuration management.

#### Rationale

1. **Infrastructure as Code**: Enables GitOps workflow for network configuration (version control, code review, automation).

2. **Idempotency**: FortiOS provider ensures consistent state (no manual drift from GUI changes).

3. **Reproducibility**: Entire FortiGate configuration can be recreated from code (disaster recovery, testing).

4. **Learning Value**: Teaches enterprise network automation patterns used in production (network-as-code).

#### FortiOS Provider Capabilities

| Resource Type | Purpose | Example Use Case |
|---------------|---------|------------------|
| `fortios_system_interface` | VLAN interfaces | Create management, cluster, services, DMZ VLANs |
| `fortios_firewall_address` | Address objects | Define cluster-subnet, pihole-ip address groups |
| `fortios_firewall_policy` | Firewall rules | Allow management→cluster SSH, block cluster→management |
| `fortios_system_dhcpserver` | DHCP configuration | Assign static IPs to K3s nodes, Raspberry Pi |
| `fortios_router_static` | Static routes | Add custom routes (if needed for advanced scenarios) |
| `fortios_firewall_service_custom` | Custom services | Define non-standard ports for homelab services |

#### Best Practices

**1. Use Address Objects (Not Inline IPs)**:
```hcl
# GOOD: Reusable address object
resource "fortios_firewall_address" "cluster_subnet" {
  name       = "cluster-subnet"
  subnet     = "10.0.20.0 255.255.255.0"
  comment    = "K3s cluster VLAN"
}

resource "fortios_firewall_policy" "example" {
  srcaddr {
    name = fortios_firewall_address.cluster_subnet.name  # Reference
  }
}

# BAD: Inline IP (not reusable, harder to audit)
resource "fortios_firewall_policy" "bad_example" {
  srcaddr {
    name = "10.0.20.0/24"  # Don't do this
  }
}
```

**2. Enable Logging on All Policies**:
```hcl
resource "fortios_firewall_policy" "example" {
  # ... other settings
  logtraffic = "all"  # Log all traffic (essential for learning and debugging)
}
```

**3. Use Descriptive Names and Comments**:
```hcl
resource "fortios_firewall_policy" "cluster_to_pihole_dns" {
  name    = "cluster-to-pihole-dns"  # Clear, descriptive name
  comment = "Allow K3s nodes to query Pi-hole for DNS resolution"
  # ...
}
```

**4. Order Policies Correctly** (Most Specific First):
```hcl
# Policy 1: Allow cluster → services (DNS)
resource "fortios_firewall_policy" "cluster_to_services_dns" {
  policyid = 10  # Explicit ordering
  # ...
}

# Policy 2: Deny all inter-VLAN (catch-all)
resource "fortios_firewall_policy" "deny_all_inter_vlan" {
  policyid = 9999  # Last policy
  # ...
}
```

**5. Separate Modules for Network Components**:
```
terraform/modules/fortigate-network/
├── interfaces.tf    # VLAN interfaces
├── dhcp.tf          # DHCP servers and reservations
├── addresses.tf     # Address objects and groups
├── policies.tf      # Firewall policies
├── routing.tf       # Static routes (if needed)
└── variables.tf     # Input variables
```

#### Common Pitfalls

| Pitfall | Problem | Solution |
|---------|---------|----------|
| **Manual GUI Changes** | Creates drift from Terraform state | Always use `tofu apply` for changes; import manual changes with `tofu import` |
| **Missing Dependencies** | Policy references non-existent address object | Use `depends_on` or implicit references (e.g., `fortios_firewall_address.name`) |
| **Policy Ordering Issues** | Specific rule after catch-all deny | Use explicit `policyid` to control order |
| **Hardcoded Secrets** | API token in code | Use environment variables: `export TF_VAR_fortigate_api_token=<token>` |
| **No State Backup** | Lost state = lost configuration | Use remote backend (S3, Terraform Cloud) or version control local state |

#### Testing FortiGate Configuration

**1. Syntax Validation**:
```bash
tofu validate
tofu fmt -check
```

**2. Plan Review** (Before Apply):
```bash
tofu plan -out=plan.tfplan
# Review output carefully for unexpected changes
tofu apply plan.tfplan
```

**3. Connectivity Testing**:
```bash
# From workstation (Management VLAN)
ping 10.0.20.11  # Should work (management → cluster allowed)
ssh ubuntu@10.0.20.11  # Should work

# From master1 (Cluster VLAN)
ssh ubuntu@10.0.20.11
ping 10.0.10.1  # Should FAIL (cluster → management denied)
ping 10.0.30.10  # Should work (cluster → services allowed for DNS)
```

**4. Log Analysis** (FortiGate GUI or CLI):
```bash
# SSH to FortiGate
execute log filter category traffic
execute log display

# Look for denied traffic (helps identify missing rules)
```

**Constitution Alignment**: Principle I (Infrastructure as Code - OpenTofu First), Principle IX (Network-First Security)

**References**:
- FortiOS Provider Docs: https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs
- FortiGate Administration Guide: https://docs.fortinet.com/document/fortigate/7.4.0/administration-guide/

---

### 1.10 Network-First Deployment Order

**Decision**: Deploy infrastructure in strict order: FortiGate → Network Validation → K3s Cluster → Monitoring → Auxiliary Services.

#### Rationale

1. **Dependency Management**: Network must exist before cluster nodes can communicate.

2. **Failure Isolation**: Network issues are caught early before cluster deployment (easier troubleshooting).

3. **Learning Value**: Teaches layered architecture and proper dependency ordering.

4. **Safety**: Firewall rules are in place before cluster traffic begins (security-first approach).

#### Deployment Phases

| Phase | Component | Validation Criteria | Rollback Plan |
|-------|-----------|---------------------|---------------|
| **Phase 0: Network** | FortiGate VLANs, firewall, DHCP | All VLANs reachable, DHCP assigning IPs | `tofu destroy` network module |
| **Phase 1: Validation** | Network connectivity tests | Ping between VLANs works/fails as expected | N/A (testing only) |
| **Phase 2: Cluster** | K3s control-plane + worker | All nodes Ready, API accessible | `tofu destroy` cluster module, preserve network |
| **Phase 3: Monitoring** | Prometheus, Grafana | All targets scraped, dashboards load | Helm uninstall, cluster remains operational |
| **Phase 4: Services** | Raspberry Pi (Pi-hole, DNS, jump host) | DNS resolves homelab domains, SSH via jump host | Stop services on Raspberry Pi, cluster unaffected |

#### Implementation Order

**Step 1: Deploy Network** (OpenTofu):
```bash
cd terraform/environments/chocolandiadc
tofu init
tofu plan -target=module.fortigate_network
tofu apply -target=module.fortigate_network
```

**Step 2: Validate Network** (Manual Testing):
```bash
# Run validation script
./scripts/validate-network.sh

# Expected checks:
# - Ping FortiGate gateways (10.0.10.1, 10.0.20.1, 10.0.30.1)
# - DHCP assigns IPs to test device
# - Firewall rules allow/block traffic as designed
```

**Step 3: Deploy Cluster** (OpenTofu):
```bash
tofu plan -target=module.k3s_cluster
tofu apply -target=module.k3s_cluster

# Validate
kubectl get nodes
kubectl get pods -A
```

**Step 4: Deploy Monitoring** (OpenTofu):
```bash
tofu plan -target=module.monitoring_stack
tofu apply -target=module.monitoring_stack

# Validate
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open http://localhost:3000
```

**Step 5: Deploy Services** (OpenTofu):
```bash
tofu plan -target=module.raspberry_pi_services
tofu apply -target=module.raspberry_pi_services

# Validate
nslookup master1.chocolandiadc.local 10.0.30.10
ssh ubuntu@10.0.10.10  # Jump host
```

#### Alternatives Considered

| Alternative | Pros | Cons | Rejection Reason |
|-------------|------|------|------------------|
| **All-at-Once Deployment** | Faster, single `tofu apply` command | Difficult to troubleshoot failures (network or cluster?), no incremental validation | Violates Constitution Principle IX (network-first); poor learning experience (opaque failures) |
| **Cluster-First, Network-Later** | Cluster deployment is primary goal | Impossible (cluster requires network), circular dependency | Technically infeasible; cluster nodes need network connectivity to bootstrap |
| **Manual Network, Automated Cluster** | Flexibility for network experimentation | Network drift from code, not reproducible | Violates Constitution Principle I (IaC first); defeats GitOps workflow |

#### Trade-offs

**Accepted**:
- **Longer Deployment Time**: Phased deployment takes longer than all-at-once
- **Manual Validation Steps**: Requires running test scripts between phases

**Mitigated**:
- Automation scripts (`validate-network.sh`, `validate-cluster.sh`) reduce manual effort
- Phased approach catches errors earlier, saving time in long run
- Learning value of incremental deployment outweighs time overhead

#### Network Validation Script Example

**`scripts/validate-network.sh`**:
```bash
#!/bin/bash
set -e

echo "=== Network Validation Script ==="

# Test 1: Ping FortiGate gateways
echo "Test 1: Pinging FortiGate VLAN gateways..."
ping -c 2 10.0.10.1 || { echo "FAIL: Management VLAN gateway unreachable"; exit 1; }
ping -c 2 10.0.20.1 || { echo "FAIL: Cluster VLAN gateway unreachable"; exit 1; }
ping -c 2 10.0.30.1 || { echo "FAIL: Services VLAN gateway unreachable"; exit 1; }
echo "PASS: All gateways reachable"

# Test 2: DNS resolution (requires Pi-hole running)
echo "Test 2: Testing Pi-hole DNS resolution..."
nslookup google.com 10.0.30.10 || { echo "FAIL: Pi-hole DNS not resolving external domains"; exit 1; }
echo "PASS: Pi-hole DNS working"

# Test 3: Firewall rule validation (management → cluster allowed)
echo "Test 3: Testing firewall allow rule (management → cluster SSH)..."
nc -zv 10.0.20.11 22 || { echo "FAIL: SSH to cluster node blocked"; exit 1; }
echo "PASS: Management → Cluster SSH allowed"

echo "=== All Network Tests Passed ==="
```

**Constitution Alignment**: Principle IX (Network-First Security)

**References**:
- OpenTofu Targeting: https://opentofu.org/docs/cli/commands/plan/#resource-targeting

---

## Best Practices

### 2.1 OpenTofu Module Design

**Principles**:
1. **Single Responsibility**: Each module manages one logical component (network, cluster, monitoring)
2. **Reusability**: Modules should be reusable across environments (dev, staging, prod)
3. **Clear Inputs/Outputs**: Variables and outputs should be well-documented
4. **State Isolation**: Use separate state files per environment if managing multiple clusters

**Module Structure Template**:
```
modules/<module-name>/
├── main.tf          # Primary resources
├── variables.tf     # Input variables (required + optional)
├── outputs.tf       # Exported values (IPs, kubeconfig path, etc.)
├── versions.tf      # Provider version constraints
└── README.md        # Usage documentation
```

**Variable Naming Conventions**:
```hcl
# Good variable names (descriptive, scoped)
variable "cluster_name" { }
variable "control_plane_count" { }
variable "vlan_id_management" { }

# Bad variable names (ambiguous, generic)
variable "name" { }  # Name of what?
variable "count" { }  # Count of what?
variable "id" { }  # Which ID?
```

**Output Best Practices**:
```hcl
# Export sensitive values with sensitivity flag
output "k3s_token" {
  value     = random_password.k3s_token.result
  sensitive = true  # Prevents display in logs
}

# Provide clear descriptions
output "api_endpoint" {
  value       = "https://${var.load_balancer_ip}:6443"
  description = "Kubernetes API endpoint for kubectl configuration"
}
```

**References**:
- OpenTofu Modules: https://opentofu.org/docs/language/modules/

---

### 2.2 FortiGate VLAN Configuration

**Best Practices**:

1. **Use 802.1Q VLAN Tagging** (Not Port-Based VLANs):
   - All VLANs trunk over single physical port (`internal`)
   - More scalable (no physical port exhaustion)
   - Industry standard for enterprise networks

2. **Document VLAN Purpose in Comments**:
   ```hcl
   resource "fortios_system_interface" "cluster" {
     name    = "cluster"
     comment = "K3s cluster nodes VLAN - API, etcd, pod network"
     # ...
   }
   ```

3. **Disable Unused Services on Interfaces**:
   ```hcl
   allowaccess = "ping"  # Only allow ping, no SSH/HTTPS from cluster VLAN
   ```

4. **Use DHCP Reservations (Not Static IPs on Nodes)**:
   - Centralized IP management on FortiGate
   - Easier to track assignments
   - Prevents IP conflicts

5. **Enable DHCP Snooping** (Security):
   ```hcl
   resource "fortios_system_interface" "cluster" {
     # ...
     dhcp_snooping = "enable"  # Prevents rogue DHCP servers
   }
   ```

**References**:
- FortiGate VLAN Best Practices: https://docs.fortinet.com/document/fortigate/7.4.0/administration-guide/983642/vlan-interfaces

---

### 2.3 K3s HA Setup

**Best Practices**:

1. **Generate Secure Cluster Token**:
   ```bash
   # Use strong random token (32+ characters)
   openssl rand -base64 32
   ```

2. **Use `--tls-san` for Load Balancer**:
   ```bash
   --tls-san 10.0.20.100  # Add load balancer IP to certificate
   ```

3. **Disable Unnecessary Components**:
   ```bash
   --disable traefik  # Use custom ingress (NGINX, Istio, etc.)
   --disable servicelb  # Use MetalLB for load balancing
   ```

4. **Configure Kubelet Resource Reservations** (Prevent resource exhaustion):
   ```bash
   --kubelet-arg="kube-reserved=cpu=500m,memory=512Mi"
   --kubelet-arg="system-reserved=cpu=500m,memory=512Mi"
   ```

5. **Enable Audit Logging** (Learning Tool):
   ```bash
   --kube-apiserver-arg="audit-log-path=/var/log/k3s-audit.log"
   --kube-apiserver-arg="audit-log-maxage=30"
   ```

6. **Automate etcd Snapshots**:
   ```bash
   --etcd-snapshot-schedule-cron="0 */12 * * *"  # Every 12 hours
   --etcd-snapshot-retention=7  # Keep 7 days
   ```

**References**:
- K3s Server Configuration: https://docs.k3s.io/reference/server-config
- K3s Advanced Options: https://docs.k3s.io/advanced

---

### 2.4 Network Testing & Validation

**Testing Layers**:

**Layer 1: Physical Connectivity**
```bash
# Ping tests (ICMP)
ping 10.0.20.11  # Cluster node
ping 10.0.30.10  # Raspberry Pi
```

**Layer 2: VLAN Isolation**
```bash
# From management VLAN, try to reach cluster VLAN (should work if firewall allows)
ping 10.0.20.11

# From cluster VLAN, try to reach management VLAN (should fail - no firewall rule)
ssh ubuntu@10.0.20.11
ping 10.0.10.1  # Should timeout
```

**Layer 3: Firewall Rules**
```bash
# Test allowed traffic (SSH from management to cluster)
ssh ubuntu@10.0.20.11  # Should work

# Test blocked traffic (SSH from cluster to management)
ssh ubuntu@10.0.20.11
ssh ubuntu@10.0.10.1  # Should fail (connection refused or timeout)
```

**Layer 4: Service Connectivity**
```bash
# DNS resolution (cluster → Pi-hole)
ssh ubuntu@10.0.20.11
nslookup google.com 10.0.30.10  # Should resolve

# Kubernetes API (from workstation)
kubectl get nodes  # Should work (API accessible via load balancer)
```

**Automated Testing Script**:
```bash
#!/bin/bash
# scripts/validate-cluster.sh

echo "=== Cluster Validation ==="

# Test 1: All nodes Ready
echo "Test 1: Checking node status..."
NODE_COUNT=$(kubectl get nodes --no-headers | grep -c "Ready")
if [ "$NODE_COUNT" -eq 4 ]; then
  echo "PASS: All 4 nodes Ready"
else
  echo "FAIL: Expected 4 Ready nodes, found $NODE_COUNT"
  exit 1
fi

# Test 2: System pods Running
echo "Test 2: Checking system pods..."
NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers | grep -v "Running" | wc -l)
if [ "$NOT_RUNNING" -eq 0 ]; then
  echo "PASS: All system pods Running"
else
  echo "FAIL: $NOT_RUNNING system pods not Running"
  kubectl get pods -n kube-system | grep -v "Running"
  exit 1
fi

echo "=== All Cluster Tests Passed ==="
```

**References**:
- Kubernetes Networking Troubleshooting: https://kubernetes.io/docs/tasks/debug/debug-cluster/

---

## Reference Architecture

### Network Topology Diagram

```
                      Internet
                         |
                    [WAN Router]
                         |
                   [FortiGate 100D]
                         |
        -----------------+------------------
        |                |                 |
   [VLAN 10]        [VLAN 20]         [VLAN 30]
  Management         Cluster           Services
  10.0.10.0/24      10.0.20.0/24      10.0.30.0/24
        |                |                 |
  Workstation       master1 (10.0.20.11)  Raspberry Pi
  Jump Host         master2 (10.0.20.12)  (10.0.30.10)
  (Raspberry Pi)    master3 (10.0.20.13)  Pi-hole DNS
  (10.0.10.10)      nodo1   (10.0.20.21)  Jump Host

[VLAN 40 - DMZ (Reserved)]
10.0.40.0/24
```

### Hardware Specifications

| Device | Role | Hostname | IP Address | Specs (Estimated) |
|--------|------|----------|------------|-------------------|
| Lenovo Mini 1 | Control-Plane | master1 | 10.0.20.11 | 8GB RAM, 4 cores, 256GB SSD |
| Lenovo Mini 2 | Control-Plane | master2 | 10.0.20.12 | 8GB RAM, 4 cores, 256GB SSD |
| Lenovo Mini 3 | Control-Plane | master3 | 10.0.20.13 | 8GB RAM, 4 cores, 256GB SSD |
| HP ProDesk | Worker | nodo1 | 10.0.20.21 | 8GB RAM, 4 cores, 256GB SSD |
| Raspberry Pi | Services | services | 10.0.30.10 | 4GB RAM (Pi 4), ARM, 32GB SD |
| FortiGate 100D | Firewall/Router | fortigate | 10.0.10.1 | N/A (network appliance) |

### Software Versions

| Component | Version | Notes |
|-----------|---------|-------|
| OpenTofu | 1.6+ | Infrastructure provisioning |
| K3s | v1.28.3+k3s1 | Kubernetes distribution |
| Ubuntu Server | 22.04 LTS | OS for mini-PCs |
| Raspberry Pi OS | 64-bit | OS for Raspberry Pi |
| FortiOS | 6.4+ | FortiGate firmware |
| Prometheus | (via Helm chart) | kube-prometheus-stack v51.0.0 |
| Grafana | (via Helm chart) | Bundled with kube-prometheus-stack |
| Pi-hole | Latest (v5.x) | DNS ad-blocking |

---

## Learning Resources

### Official Documentation

- **OpenTofu**: https://opentofu.org/docs/
- **K3s**: https://docs.k3s.io/
- **FortiGate**: https://docs.fortinet.com/
- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/
- **Pi-hole**: https://docs.pi-hole.net/

### Hands-On Tutorials

- **K3s HA Setup**: https://docs.k3s.io/datastore/ha-embedded
- **FortiGate Configuration**: https://training.fortinet.com/ (Free NSE courses)
- **Prometheus Basics**: https://prometheus.io/docs/tutorials/getting_started/
- **VLAN Configuration**: https://www.youtube.com/results?search_query=vlan+configuration+tutorial

### Advanced Topics

- **etcd Administration**: https://etcd.io/docs/v3.5/op-guide/
- **Kubernetes Networking**: https://kubernetes.io/docs/concepts/cluster-administration/networking/
- **Terraform Best Practices**: https://www.terraform-best-practices.com/
- **Network Security**: https://www.fortinet.com/resources/cyberglossary

### Books

- **"Kubernetes Up & Running"** by Kelsey Hightower (foundational K8s concepts)
- **"Prometheus: Up & Running"** by Brian Brazil (monitoring deep dive)
- **"Terraform: Up & Running"** by Yevgeniy Brikman (IaC patterns, applies to OpenTofu)

---

## Conclusion

This research document captures the technical decisions and best practices for the ChocolandiaDC K3s HA cluster homelab. The chosen architecture prioritizes:

1. **Learning Value**: Enterprise-grade tools (FortiGate, K3s HA, Prometheus) that transfer to production environments
2. **Reproducibility**: Full Infrastructure as Code with OpenTofu ensures the entire homelab can be rebuilt from scratch
3. **Security**: Network-first approach with VLAN segmentation and defense-in-depth (FortiGate → VLANs → Kubernetes policies)
4. **Operational Excellence**: Phased deployment, comprehensive testing, and monitoring provide hands-on experience with production workflows

The next phase (Phase 1) will produce `data-model.md`, `quickstart.md`, and `contracts/` for detailed implementation specifications.

---

**Document Status**: Complete
**Next Steps**: Proceed to Phase 1 (Design) via `/speckit.plan` command
**Approval**: Ready for implementation planning
