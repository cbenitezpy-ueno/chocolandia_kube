# Data Model: K3s HA Cluster Infrastructure

**Feature**: 001-k3s-cluster-setup
**Date**: 2025-11-08
**Purpose**: Define entities, configuration schemas, and relationships for the K3s HA cluster

## Overview

This document defines the logical entities and their relationships in the chocolandiadc K3s cluster infrastructure. These entities map to Terraform resources, Kubernetes objects, and configuration files.

## Core Entities

### 1. Cluster

**Description**: The top-level logical entity representing the entire K3s cluster

**Attributes**:
- `name` (string, required): Cluster identifier - "chocolandiadc"
- `version` (string, required): K3s version (e.g., "v1.28.3+k3s1")
- `api_endpoint` (string, computed): Kubernetes API URL (e.g., "https://master1:6443")
- `cluster_token` (string, sensitive, computed): Shared secret for node joining
- `kubeconfig` (string, sensitive, computed): Kubectl configuration for cluster access
- `state` (enum, computed): Cluster state - "provisioning", "ready", "degraded", "failed"

**Relationships**:
- Has many `ControlPlaneNode` (3 nodes: master1, master2, master3)
- Has many `WorkerNode` (1 node: nodo1, expandable to 3)
- Has one `EtcdCluster` (embedded in control-plane nodes)
- Has one `MonitoringStack` (Prometheus + Grafana)

**Validation Rules**:
- `name` must be DNS-compliant (lowercase, alphanumeric, hyphens)
- `version` must match K3s release format (e.g., v1.x.x+k3sX)
- Minimum 1 control-plane node required
- For HA: minimum 3 control-plane nodes required

**State Transitions**:
```
provisioning → ready (all nodes Ready, API responsive)
provisioning → failed (node provisioning error)
ready → degraded (node failure, quorum maintained)
degraded → ready (failed node recovered)
degraded → failed (quorum lost)
```

---

### 2. ControlPlaneNode

**Description**: A node running K3s control-plane components (API server, scheduler, controller manager, embedded etcd)

**Attributes**:
- `hostname` (string, required): Node hostname - "master1", "master2", "master3"
- `ip_address` (string, required): Static IP address (e.g., "192.168.1.101")
- `ssh_user` (string, required): SSH username for provisioning (e.g., "ubuntu")
- `ssh_key_path` (string, required): Path to SSH private key (e.g., "~/.ssh/id_rsa")
- `role` (string, constant): "control-plane"
- `is_first_node` (boolean, computed): True if this is the initial control-plane node
- `k3s_install_command` (string, computed): K3s installation command for this node
- `state` (enum, computed): "provisioning", "ready", "not-ready", "unknown"

**Relationships**:
- Belongs to `Cluster`
- Participates in `EtcdCluster` (if control-plane)
- Has one `KubeConfig` (generated after installation)

**Validation Rules**:
- `hostname` must match pattern: master[1-3]
- `ip_address` must be valid IPv4 address
- `ssh_user` must have sudo privileges on target node
- `ssh_key_path` must point to valid SSH private key file

**Derived Values**:
- `k3s_install_command` for first node (master1):
  ```bash
  curl -sfL https://get.k3s.io | sh -s - server \
    --cluster-init \
    --tls-san ${ip_address} \
    --node-name ${hostname}
  ```
- `k3s_install_command` for additional nodes (master2, master3):
  ```bash
  curl -sfL https://get.k3s.io | sh -s - server \
    --server https://${first_node_ip}:6443 \
    --token ${cluster_token} \
    --node-name ${hostname}
  ```

---

### 3. WorkerNode

**Description**: A node running K3s agent for executing workload pods (no control-plane components)

**Attributes**:
- `hostname` (string, required): Node hostname - "nodo1", "nodo2", "nodo3"
- `ip_address` (string, required): Static IP address (e.g., "192.168.1.104")
- `ssh_user` (string, required): SSH username for provisioning
- `ssh_key_path` (string, required): Path to SSH private key
- `role` (string, constant): "worker"
- `k3s_install_command` (string, computed): K3s agent installation command
- `state` (enum, computed): "provisioning", "ready", "not-ready", "unknown"

**Relationships**:
- Belongs to `Cluster`
- Does NOT participate in `EtcdCluster`

**Validation Rules**:
- `hostname` must match pattern: nodo[1-3]
- `ip_address` must be valid IPv4 address
- `ssh_user` must have sudo privileges on target node

**Derived Values**:
- `k3s_install_command`:
  ```bash
  curl -sfL https://get.k3s.io | sh -s - agent \
    --server https://${control_plane_ip}:6443 \
    --token ${cluster_token} \
    --node-name ${hostname}
  ```

---

### 4. EtcdCluster

**Description**: Distributed key-value store for cluster state, embedded in K3s control-plane nodes

**Attributes**:
- `members` (array of ControlPlaneNode, computed): List of etcd members (master1-3)
- `quorum_size` (integer, computed): Minimum nodes for quorum - (N/2)+1 = 2 for 3 nodes
- `leader` (string, computed): Current etcd leader hostname
- `state` (enum, computed): "forming", "quorum", "quorum-lost"

**Relationships**:
- Composed of `ControlPlaneNode` (embedded etcd in each control-plane node)

**Validation Rules**:
- Minimum 3 members for HA (tolerates 1 failure)
- Odd number of members recommended (3, 5, 7) for quorum math
- For 4-node setup: exactly 3 control-plane nodes (not 4)

**Quorum Calculation**:
```
members = 3
quorum_size = (3 / 2) + 1 = 2
failure_tolerance = 3 - 2 = 1 node
```

**State Transitions**:
```
forming → quorum (when >= quorum_size members join)
quorum → quorum-lost (when < quorum_size members available)
quorum-lost → quorum (when failed members recover)
```

---

### 5. MonitoringStack

**Description**: Prometheus + Grafana deployment for cluster observability

**Attributes**:
- `namespace` (string, required): Kubernetes namespace - "monitoring"
- `prometheus_release_name` (string, required): Helm release name - "kube-prometheus-stack"
- `prometheus_chart_version` (string, required): Helm chart version (e.g., "51.0.0")
- `prometheus_retention` (string, required): Metrics retention period - "15d"
- `prometheus_storage_size` (string, required): PVC size for metrics - "10Gi"
- `grafana_admin_user` (string, required): Grafana admin username - "admin"
- `grafana_admin_password` (string, sensitive, generated): Grafana admin password
- `state` (enum, computed): "not-deployed", "deploying", "ready", "failed"

**Relationships**:
- Deployed to `Cluster`
- Scrapes metrics from all `ControlPlaneNode` and `WorkerNode`
- Stores data in `PersistentVolume` (via local-path provisioner)

**Components**:
- **Prometheus Server**: Metrics collection, storage, alerting
- **Grafana**: Dashboard visualization
- **Node Exporter** (DaemonSet): Hardware/OS metrics from each node
- **Kube-State-Metrics**: Kubernetes object state metrics
- **Alertmanager**: Alert routing and notification

**Validation Rules**:
- `namespace` must not conflict with existing namespaces
- `prometheus_retention` must be valid duration (e.g., "15d", "30d")
- `prometheus_storage_size` must fit on nodes (max 10Gi recommended for 20GB disk nodes)
- `grafana_admin_password` must be >= 8 characters

**Default Dashboards**:
- Cluster Overview: CPU, memory, disk, network across all nodes
- Etcd: Quorum status, leader elections, latency
- Kubernetes Components: API server, scheduler, controller-manager health
- Node Exporter: Per-node hardware metrics

---

### 6. KubeConfig

**Description**: Kubectl configuration file for cluster access

**Attributes**:
- `cluster_name` (string, required): "chocolandiadc"
- `server_url` (string, required): Kubernetes API URL - "https://<master1-ip>:6443"
- `certificate_authority_data` (string, base64, required): CA certificate
- `client_certificate_data` (string, base64, required): Client certificate
- `client_key_data` (string, base64, sensitive, required): Client private key
- `context_name` (string, computed): "chocolandiadc" (cluster name)
- `user_name` (string, computed): "default" (kubectl user)

**Relationships**:
- Generated by `ControlPlaneNode` (master1) during installation
- Used to access `Cluster` via kubectl

**File Structure** (YAML):
```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <base64>
    server: https://192.168.1.101:6443
  name: chocolandiadc
contexts:
- context:
    cluster: chocolandiadc
    user: default
  name: chocolandiadc
current-context: chocolandiadc
users:
- name: default
  user:
    client-certificate-data: <base64>
    client-key-data: <base64>
```

**Validation Rules**:
- `server_url` must use https protocol
- Certificates must be valid base64-encoded PEM
- Context name should match cluster name for clarity

---

### 7. OpenTofuState

**Description**: OpenTofu state file tracking managed infrastructure

**Attributes**:
- `version` (integer, required): OpenTofu state format version
- `opentofu_version` (string, required): OpenTofu binary version used
- `resources` (array of Resource, required): List of managed resources
- `outputs` (object, optional): OpenTofu outputs (kubeconfig, API endpoint, etc.)

**Relationships**:
- Tracks all infrastructure entities (Cluster, Nodes, MonitoringStack)

**Managed Resources** (subset):
- `null_resource.master1_install`: Master1 K3s installation
- `null_resource.master2_install`: Master2 K3s installation
- `null_resource.master3_install`: Master3 K3s installation
- `null_resource.nodo1_install`: Worker node installation
- `helm_release.kube_prometheus_stack`: Monitoring stack deployment
- `kubernetes_namespace.monitoring`: Monitoring namespace
- `local_file.kubeconfig`: Kubeconfig written to local disk

**State File Location**: `terraform/environments/chocolandiadc/terraform.tfstate`

**Backup Strategy**:
- Manual copy to `terraform/environments/chocolandiadc/backups/terraform.tfstate.backup.<timestamp>`
- Excluded from Git via `.gitignore` (contains sensitive data)

---

## Entity Relationships Diagram

```
Cluster (chocolandiadc)
├── ControlPlaneNode (master1) ──┐
├── ControlPlaneNode (master2) ──┼── EtcdCluster (3 members, quorum=2)
├── ControlPlaneNode (master3) ──┘
├── WorkerNode (nodo1)
└── MonitoringStack
    ├── Prometheus (deployed as Helm release)
    └── Grafana (deployed as Helm release)

ControlPlaneNode (master1)
├── generates → KubeConfig (kubeconfig file)
└── generates → ClusterToken (for node joining)

MonitoringStack
├── scrapes → ControlPlaneNode (metrics from master1-3)
└── scrapes → WorkerNode (metrics from nodo1)

TerraformState
└── tracks → [Cluster, Nodes, MonitoringStack, KubeConfig]
```

---

## Configuration Schema

### OpenTofu Variables (`terraform.tfvars`)

```hcl
# Cluster configuration
cluster_name    = "chocolandiadc"
k3s_version     = "v1.28.3+k3s1"  # Latest stable as of 2025-11-08

# Control-plane nodes
control_plane_nodes = [
  {
    hostname    = "master1"
    ip_address  = "192.168.1.101"  # Replace with actual IP
    ssh_user    = "ubuntu"         # Replace with actual SSH user
    ssh_key_path = "~/.ssh/id_rsa" # Replace with actual key path
  },
  {
    hostname    = "master2"
    ip_address  = "192.168.1.102"
    ssh_user    = "ubuntu"
    ssh_key_path = "~/.ssh/id_rsa"
  },
  {
    hostname    = "master3"
    ip_address  = "192.168.1.103"
    ssh_user    = "ubuntu"
    ssh_key_path = "~/.ssh/id_rsa"
  }
]

# Worker nodes
worker_nodes = [
  {
    hostname    = "nodo1"
    ip_address  = "192.168.1.104"
    ssh_user    = "ubuntu"
    ssh_key_path = "~/.ssh/id_rsa"
  }
]

# Monitoring stack configuration
monitoring_namespace        = "monitoring"
prometheus_retention        = "15d"
prometheus_storage_size     = "10Gi"
grafana_admin_user          = "admin"
# grafana_admin_password will be auto-generated
```

### OpenTofu Outputs

```hcl
output "cluster_name" {
  value       = var.cluster_name
  description = "K3s cluster name"
}

output "api_endpoint" {
  value       = "https://${var.control_plane_nodes[0].ip_address}:6443"
  description = "Kubernetes API endpoint (master1 URL)"
}

output "kubeconfig_path" {
  value       = "${path.module}/kubeconfig"
  description = "Path to generated kubeconfig file"
  sensitive   = true
}

output "cluster_token" {
  value       = "<retrieved from master1 /var/lib/rancher/k3s/server/node-token>"
  description = "K3s cluster join token"
  sensitive   = true
}

output "grafana_admin_password" {
  value       = "<auto-generated password>"
  description = "Grafana admin password"
  sensitive   = true
}

output "prometheus_url" {
  value       = "http://<prometheus-service-ip>:9090"
  description = "Prometheus web UI URL (use kubectl port-forward)"
}

output "grafana_url" {
  value       = "http://<grafana-service-ip>:80"
  description = "Grafana web UI URL (use kubectl port-forward)"
}
```

---

## Validation & Constraints

### Cluster-Level Constraints

- **Total nodes**: 4 (3 control-plane + 1 worker)
- **Etcd quorum**: Minimum 3 control-plane nodes for HA
- **Node resources**: Minimum 2 CPU cores, 4GB RAM, 20GB disk per node
- **Network**: All nodes must be on same L2 network (local subnet)
- **SSH access**: Passwordless SSH required for all nodes

### Configuration Constraints

- **Cluster name**: Must be DNS-compliant (lowercase, alphanumeric, hyphens only)
- **Node hostnames**: Must match pattern master[1-3] or nodo[1-3]
- **IP addresses**: Must be static (DHCP reservations or static configuration)
- **K3s version**: Must be valid K3s release (e.g., v1.28.3+k3s1)
- **Prometheus retention**: Must be valid duration (e.g., "15d", "30d")
- **Storage sizes**: Must fit on node disk capacity

### Resource Limits

**Prometheus Resource Limits**:
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

**Grafana Resource Limits**:
```yaml
resources:
  requests:
    memory: "200Mi"
    cpu: "100m"
  limits:
    memory: "500Mi"
    cpu: "500m"
```

---

## Summary

This data model defines 7 core entities for the K3s HA cluster:

1. **Cluster**: Top-level logical entity representing the entire cluster
2. **ControlPlaneNode**: Nodes running K3s control-plane and embedded etcd (master1-3)
3. **WorkerNode**: Nodes running K3s agent for workloads (nodo1)
4. **EtcdCluster**: Distributed key-value store embedded in control-plane nodes
5. **MonitoringStack**: Prometheus + Grafana for observability
6. **KubeConfig**: Configuration file for kubectl cluster access
7. **TerraformState**: State file tracking managed infrastructure

These entities map directly to Terraform resources and will be implemented in the Terraform modules defined in the project structure (plan.md).
