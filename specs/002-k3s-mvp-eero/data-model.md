# Data Model: K3s MVP - 2-Node Cluster on Eero Network

**Feature**: 002-k3s-mvp-eero
**Date**: 2025-11-09
**Status**: Draft

## Overview

This data model defines the entities, attributes, and relationships for the K3s MVP cluster deployed on Eero mesh network. The model reflects the simplified architecture: 2 nodes (1 server + 1 agent), flat network, SQLite datastore, and local OpenTofu state.

---

## Entity Diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Cluster: chocolandiadc-mvp                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ name: "chocolandiadc-mvp"                                 │  │
│  │ mode: "single-server"                                     │  │
│  │ datastore: "sqlite"                                       │  │
│  │ network: "eero-flat"                                      │  │
│  │ state: "local"                                            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│         ┌────────────────────┴────────────────────┐             │
│         │                                         │             │
│         ▼                                         ▼             │
│  ┌─────────────────┐                      ┌─────────────────┐  │
│  │ ControlPlaneNode│                      │   WorkerNode    │  │
│  │   (master1)     │                      │    (nodo1)      │  │
│  ├─────────────────┤                      ├─────────────────┤  │
│  │ hostname: master1│◀────token────────── │ hostname: nodo1 │  │
│  │ role: server    │                      │ role: agent     │  │
│  │ ip: 192.168.4.x │                      │ ip: 192.168.4.y │  │
│  │ connection: eth │                      │ connection: eth │  │
│  │                 │                      │   or wifi       │  │
│  └─────────────────┘                      └─────────────────┘  │
│         │                                                       │
│         │ generates                                             │
│         ▼                                                       │
│  ┌─────────────────────────────────────────┐                   │
│  │      K3sClusterToken                    │                   │
│  │  token: "<secret>"                      │                   │
│  │  path: /var/lib/rancher/k3s/server/token│                   │
│  └─────────────────────────────────────────┘                   │
│         │                                                       │
│         │ generates                                             │
│         ▼                                                       │
│  ┌─────────────────────────────────────────┐                   │
│  │          Kubeconfig                     │                   │
│  │  path: /etc/rancher/k3s/k3s.yaml        │                   │
│  │  server: https://192.168.4.x:6443       │                   │
│  │  context: default                       │                   │
│  └─────────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│              OpenTofuState (Local)                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ path: terraform/environments/chocolandiadc-mvp/           │  │
│  │       terraform.tfstate                                   │  │
│  │ version: 4                                                │  │
│  │ resources:                                                │  │
│  │   - null_resource.master1_k3s_server                      │  │
│  │   - null_resource.nodo1_k3s_agent                         │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 EeroMeshNetwork                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ subnet: 192.168.4.0/24                                    │  │
│  │ dhcp_range: 192.168.4.100 - 192.168.4.254                 │  │
│  │ gateway: 192.168.4.1 (Eero primary node)                  │  │
│  │ dns: 192.168.4.1 (Eero DNS relay)                         │  │
│  │ connected_devices: [master1, nodo1, operator_laptop, ...]│  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Entities

### 1. Cluster (chocolandiadc-mvp)

**Description**: Logical representation of the K3s cluster. This is a temporary MVP cluster that will be migrated to feature 001 when FortiGate is repaired.

**Attributes**:

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `name` | string | Yes | Cluster identifier | `chocolandiadc-mvp` |
| `mode` | enum | Yes | K3s cluster mode | `single-server` (not `ha`) |
| `datastore` | enum | Yes | Backend datastore type | `sqlite` (not `etcd`) |
| `version` | string | Yes | K3s version | `v1.28.x-k3s1` |
| `network` | string | Yes | Network infrastructure | `eero-flat` (no VLANs) |
| `api_endpoint` | string | Yes | Kubernetes API URL | `https://192.168.4.x:6443` |
| `state_backend` | enum | Yes | OpenTofu state storage | `local` (not `remote`) |
| `created_at` | datetime | Yes | Cluster creation timestamp | `2025-11-09T10:30:00Z` |
| `status` | enum | Yes | Cluster operational status | `ready`, `degraded`, `unavailable` |

**Relationships**:
- **Has one** ControlPlaneNode (master1)
- **Has one** WorkerNode (nodo1)
- **Generates** K3sClusterToken
- **Generates** Kubeconfig
- **Managed by** OpenTofuState

**Constraints**:
- Single control-plane (no HA): only 1 server node allowed in MVP
- Maximum 2 nodes total (resource constraint for MVP)

---

### 2. ControlPlaneNode (master1)

**Description**: K3s server node running control-plane components (API server, scheduler, controller manager) with embedded SQLite datastore.

**Attributes**:

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `hostname` | string | Yes | Node hostname | `master1` |
| `role` | enum | Yes | K3s node role | `server` |
| `ip_address` | string | Yes | Eero DHCP-assigned IP | `192.168.4.10` (DHCP or static reservation) |
| `mac_address` | string | Yes | NIC MAC address | `aa:bb:cc:dd:ee:ff` |
| `connection_type` | enum | Yes | Network connectivity | `ethernet` (recommended) or `wifi` |
| `ssh_user` | string | Yes | SSH username | `ubuntu` or `cbenitez` |
| `ssh_key_path` | string | Yes | Private key for SSH | `/Users/cbenitez/.ssh/id_rsa` |
| `k3s_version` | string | Yes | K3s binary version | `v1.28.5+k3s1` |
| `k3s_flags` | string | No | Custom K3s server flags | `--disable traefik --disable servicelb` |
| `cpu_cores` | integer | Yes | Available CPU cores | `4` |
| `memory_gb` | integer | Yes | Available RAM | `8` |
| `disk_gb` | integer | Yes | Available disk space | `128` |
| `os` | string | Yes | Operating system | `Ubuntu Server 22.04 LTS` |
| `status` | enum | Yes | Node operational status | `Ready`, `NotReady`, `Unknown` |

**Relationships**:
- **Belongs to** Cluster (chocolandiadc-mvp)
- **Generates** K3sClusterToken (stored at `/var/lib/rancher/k3s/server/token`)
- **Generates** Kubeconfig (stored at `/etc/rancher/k3s/k3s.yaml`)
- **Connected to** EeroMeshNetwork

**Constraints**:
- Must have Ethernet or WiFi connectivity to Eero
- Must have SSH access configured (passwordless with key)
- Minimum resources: 2 CPU cores, 4GB RAM, 20GB disk

**Data Storage**:
- SQLite database: `/var/lib/rancher/k3s/server/db/state.db`
- Cluster token: `/var/lib/rancher/k3s/server/token`
- Kubeconfig: `/etc/rancher/k3s/k3s.yaml`
- K3s manifests: `/var/lib/rancher/k3s/server/manifests/`

---

### 3. WorkerNode (nodo1)

**Description**: K3s agent node for running workload pods (applications, monitoring, etc.). Does not participate in control-plane operations.

**Attributes**:

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `hostname` | string | Yes | Node hostname | `nodo1` |
| `role` | enum | Yes | K3s node role | `agent` |
| `ip_address` | string | Yes | Eero DHCP-assigned IP | `192.168.4.11` (DHCP or static reservation) |
| `mac_address` | string | Yes | NIC MAC address | `ff:ee:dd:cc:bb:aa` |
| `connection_type` | enum | Yes | Network connectivity | `ethernet` or `wifi` |
| `ssh_user` | string | Yes | SSH username | `ubuntu` or `cbenitez` |
| `ssh_key_path` | string | Yes | Private key for SSH | `/Users/cbenitez/.ssh/id_rsa` |
| `k3s_version` | string | Yes | K3s binary version | `v1.28.5+k3s1` (must match server) |
| `k3s_server_url` | string | Yes | Control-plane API endpoint | `https://192.168.4.10:6443` |
| `k3s_token` | string | Yes | Cluster join token | Retrieved from master1 |
| `k3s_flags` | string | No | Custom K3s agent flags | `--node-label role=worker` |
| `cpu_cores` | integer | Yes | Available CPU cores | `4` |
| `memory_gb` | integer | Yes | Available RAM | `8` |
| `disk_gb` | integer | Yes | Available disk space | `128` |
| `os` | string | Yes | Operating system | `Ubuntu Server 22.04 LTS` |
| `status` | enum | Yes | Node operational status | `Ready`, `NotReady`, `Unknown` |

**Relationships**:
- **Belongs to** Cluster (chocolandiadc-mvp)
- **Joins via** K3sClusterToken (from master1)
- **Connected to** EeroMeshNetwork

**Constraints**:
- Must have network connectivity to master1 (API server at `https://192.168.4.x:6443`)
- Must have valid cluster token from master1
- K3s version must match server version (version skew policy: +/- 1 minor version)

**Data Storage**:
- Node registration: `/var/lib/rancher/k3s/agent/`
- Kubelet data: `/var/lib/kubelet/`

---

### 4. K3sClusterToken

**Description**: Shared secret used by agent nodes to join the cluster. Generated automatically by K3s server on first boot.

**Attributes**:

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `token` | string | Yes | Secret token value | `K10abc123...::server:xyz789...` |
| `path` | string | Yes | Token file location on master1 | `/var/lib/rancher/k3s/server/token` |
| `generated_at` | datetime | Yes | Token creation timestamp | `2025-11-09T10:32:00Z` |
| `used_by` | array | No | Nodes that used this token | `[nodo1]` |

**Relationships**:
- **Generated by** ControlPlaneNode (master1)
- **Used by** WorkerNode (nodo1) to join cluster

**Constraints**:
- Token is sensitive and must not be committed to Git
- Token should be rotated periodically (learning exercise for security)

**Usage**:
```bash
# Retrieve token from master1
ssh ubuntu@192.168.4.10 "sudo cat /var/lib/rancher/k3s/server/token"

# Use token on nodo1 to join cluster
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.4.10:6443 K3S_TOKEN=<token> sh -
```

---

### 5. Kubeconfig

**Description**: Kubernetes client configuration file for `kubectl` access. Contains API server endpoint, client certificates, and context.

**Attributes**:

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `path_server` | string | Yes | Kubeconfig location on master1 | `/etc/rancher/k3s/k3s.yaml` |
| `path_client` | string | Yes | Kubeconfig location on operator laptop | `~/.kube/config` |
| `server` | string | Yes | API server URL | `https://192.168.4.10:6443` |
| `cluster_name` | string | Yes | Cluster identifier in kubeconfig | `default` |
| `user` | string | Yes | Client user name | `default` |
| `context` | string | Yes | Active context name | `default` |
| `client_certificate` | string | Yes | Base64-encoded client cert | Embedded in YAML |
| `client_key` | string | Yes | Base64-encoded client key | Embedded in YAML |
| `ca_certificate` | string | Yes | Base64-encoded cluster CA | Embedded in YAML |

**Relationships**:
- **Generated by** ControlPlaneNode (master1)
- **Used by** Operator (human or automation) for kubectl access

**Constraints**:
- Kubeconfig is sensitive (contains client certificates and keys)
- Must be copied from master1 to operator laptop and modified (replace `127.0.0.1` with `192.168.4.x`)

**Usage**:
```bash
# Copy from master1
scp ubuntu@192.168.4.10:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Modify server URL (replace 127.0.0.1 with master1 IP)
sed -i 's/127.0.0.1/192.168.4.10/g' ~/.kube/config

# Verify access
kubectl get nodes
```

---

### 6. OpenTofuState (Local)

**Description**: OpenTofu state file tracking provisioned infrastructure. Stored locally in the environment directory.

**Attributes**:

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `path` | string | Yes | State file location | `terraform/environments/chocolandiadc-mvp/terraform.tfstate` |
| `version` | integer | Yes | Terraform state schema version | `4` |
| `terraform_version` | string | Yes | OpenTofu binary version | `1.6.0` |
| `serial` | integer | Yes | State serial number (increments on apply) | `3` |
| `lineage` | string | Yes | State lineage UUID | `uuid-...` |
| `resources` | array | Yes | Managed resources | See below |

**Managed Resources**:
- `null_resource.master1_k3s_server` (K3s server installation on master1)
- `null_resource.nodo1_k3s_agent` (K3s agent installation on nodo1)
- Optionally: `local_file.kubeconfig` (copied kubeconfig)

**Relationships**:
- **Tracks** Cluster infrastructure (nodes, K3s installations)

**Constraints**:
- State file must NOT be committed to Git (contains sensitive data: IPs, tokens)
- State file should be backed up before risky OpenTofu operations
- State locking not available (local backend limitation)

**Backup Strategy**:
```bash
# Manual backup before apply
cp terraform.tfstate terraform.tfstate.backup

# Restore if needed
cp terraform.tfstate.backup terraform.tfstate
```

---

### 7. EeroMeshNetwork

**Description**: Eero mesh network providing connectivity, DHCP, DNS, and gateway services for all cluster nodes.

**Attributes**:

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `subnet` | string | Yes | Network CIDR | `192.168.4.0/24` |
| `dhcp_range` | string | Yes | DHCP IP pool | `192.168.4.100 - 192.168.4.254` |
| `gateway` | string | Yes | Default gateway (Eero primary node) | `192.168.4.1` |
| `dns_servers` | array | Yes | DNS servers (Eero DNS relay) | `[192.168.4.1]` |
| `broadcast_domain` | string | Yes | All devices on same subnet | `flat` (no VLANs) |
| `connected_devices` | array | Yes | Devices on network | `[master1, nodo1, operator_laptop, ...]` |

**Relationships**:
- **Provides connectivity to** ControlPlaneNode (master1)
- **Provides connectivity to** WorkerNode (nodo1)
- **Provides connectivity to** Operator laptop (for kubectl access)

**Constraints**:
- No VLAN support (consumer-grade mesh router)
- No firewall rules (flat network, full trust between devices)
- DHCP IP addresses may change on reboot (recommend static DHCP reservations in Eero app)

**Configuration**:
- Static DHCP reservations recommended (map MAC addresses to fixed IPs)
- Example: `master1 (aa:bb:cc:dd:ee:ff) → 192.168.4.10`
- Example: `nodo1 (ff:ee:dd:cc:bb:aa) → 192.168.4.11`

---

## Relationships Summary

```text
Cluster
  ├── Has 1 ControlPlaneNode (master1)
  ├── Has 1 WorkerNode (nodo1)
  ├── Generates K3sClusterToken
  ├── Generates Kubeconfig
  └── Managed by OpenTofuState

ControlPlaneNode (master1)
  ├── Belongs to Cluster
  ├── Generates K3sClusterToken
  ├── Generates Kubeconfig
  └── Connected to EeroMeshNetwork

WorkerNode (nodo1)
  ├── Belongs to Cluster
  ├── Joins via K3sClusterToken
  └── Connected to EeroMeshNetwork

EeroMeshNetwork
  ├── Provides connectivity to master1
  ├── Provides connectivity to nodo1
  └── Provides connectivity to operator laptop
```

---

## Migration Considerations

When migrating to feature 001 (full HA cluster with FortiGate VLANs):

1. **Cluster entity** will change:
   - `mode: "ha"` (3 control-plane nodes)
   - `datastore: "etcd"` (embedded etcd quorum)
   - `network: "fortigate-vlan"` (VLAN segmentation)

2. **ControlPlaneNode entity** will have 3 instances:
   - `master1`, `master2`, `master3` (all Lenovo mini-PCs)
   - Each on Cluster VLAN (e.g., 10.100.20.0/24)

3. **WorkerNode entity** remains similar:
   - `nodo1` (HP ProDesk) also on Cluster VLAN

4. **Network entity** will change from EeroMeshNetwork to FortiGateVLANNetwork:
   - VLANs: Management, Cluster, Services, DMZ
   - Firewall rules: Default deny, explicit allow

5. **OpenTofuState** will migrate to remote backend:
   - S3 + DynamoDB or Terraform Cloud

**Data Preservation**:
- Workload data: Back up PersistentVolumes before migration
- Application state: Export from pods before cluster teardown
- Cluster token/kubeconfig: Will be regenerated in new cluster (not preserved)
