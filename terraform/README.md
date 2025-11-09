# ChocolandiaDC K3s MVP - OpenTofu Infrastructure

This directory contains OpenTofu infrastructure-as-code for deploying a minimal K3s cluster with monitoring stack (Feature 002: MVP on Eero Network).

## Overview

**Purpose**: Deploy a 2-node K3s cluster (1 control-plane + 1 worker) on Eero mesh network as a temporary solution while FortiGate hardware is being repaired.

**Status**: ✅ Fully operational with monitoring stack deployed

**Architecture**:
- Single-server K3s (SQLite datastore, non-HA)
- Flat network topology (192.168.4.0/24)
- Prometheus + Grafana monitoring
- 2 nodes: master1 (192.168.4.101) + nodo1 (192.168.4.102)

## Project Structure

```
terraform/
├── modules/
│   └── k3s-node/          # Reusable module for K3s server/agent provisioning
│       ├── main.tf        # SSH provisioner for K3s installation
│       ├── variables.tf   # Node configuration (hostname, IP, role, etc.)
│       ├── outputs.tf     # Node outputs (status, kubeconfig, token)
│       └── scripts/       # Installation scripts for server and agent
│           ├── install-k3s-server.sh
│           └── install-k3s-agent.sh
│
└── environments/
    └── chocolandiadc-mvp/ # MVP environment (2 nodes + monitoring)
        ├── main.tf        # Cluster deployment (master1 + nodo1)
        ├── monitoring.tf  # Monitoring stack (Prometheus + Grafana)
        ├── variables.tf   # Environment variables
        ├── terraform.tfvars       # Actual configuration (gitignored)
        ├── terraform.tfvars.example  # Example configuration
        ├── outputs.tf     # Cluster outputs (endpoints, kubeconfig, etc.)
        ├── providers.tf   # Null, External, Local, Helm providers
        ├── kubeconfig     # Generated kubeconfig (gitignored)
        └── scripts/       # Backup and validation scripts
            ├── backup-state.sh
            ├── backup-cluster.sh
            ├── validate-cluster.sh
            ├── validate-single-node.sh
            └── deploy-test-workload.sh
```

## Quick Start

### Prerequisites

**Local Machine**:
- OpenTofu >= 1.6.0
- kubectl >= 1.28
- Helm >= 3.12 (for monitoring stack)
- SSH client
- jq (for integration tests)

**Cluster Nodes**:
- 2 mini-PCs (or VMs) running Ubuntu/Debian
- Connected to Eero network (Ethernet strongly recommended)
- SSH keys configured for passwordless access
- Passwordless sudo configured
- Static DHCP reservations configured in Eero app

### Initial Setup

**Step 1: Configure SSH Access**
```bash
# Generate SSH key for K3s cluster
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_k3s -N ""

# Copy public key to nodes
ssh-copy-id -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101
ssh-copy-id -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102

# Configure passwordless sudo on each node
ssh chocolim@192.168.4.101
echo "chocolim ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/chocolim
sudo chmod 0440 /etc/sudoers.d/chocolim
exit

# Repeat for nodo1
```

**Step 2: Configure Eero DHCP Reservations**
1. Open Eero app on mobile device
2. Navigate to Settings > Network Settings > Reservations & Port Forwarding
3. Reserve 192.168.4.101 for master1
4. Reserve 192.168.4.102 for nodo1

### Deploy Cluster

```bash
cd terraform/environments/chocolandiadc-mvp

# 1. Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# 2. Edit terraform.tfvars with your node IPs and SSH details
vim terraform.tfvars

# Example values:
# cluster_name = "chocolandiadc-mvp"
# k3s_version  = "v1.28.3+k3s1"
# master1_hostname = "master1"
# master1_ip       = "192.168.4.101"
# nodo1_hostname   = "nodo1"
# nodo1_ip         = "192.168.4.102"
# ssh_user             = "chocolim"
# ssh_private_key_path = "~/.ssh/id_ed25519_k3s"
# disable_components = ["traefik"]

# 3. Initialize OpenTofu (downloads providers)
tofu init

# 4. Review deployment plan
tofu plan

# 5. Deploy cluster (master1 + nodo1 + monitoring stack)
tofu apply

# This will:
# - Install K3s server on master1
# - Install K3s agent on nodo1
# - Deploy Prometheus + Grafana monitoring stack
# - Generate kubeconfig file

# 6. Export kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# 7. Verify cluster
kubectl get nodes -o wide
# Expected: master1 and nodo1 both Ready

kubectl get pods -A
# Expected: All system pods Running

# 8. Access Grafana
# URL: http://192.168.4.101:30000
# User: admin
# Password: (retrieve with command below)
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

### Post-Deployment Validation

Run the included validation and integration tests:

```bash
# Validate single node
bash scripts/validate-single-node.sh $(pwd)/kubeconfig master1

# Validate entire cluster
bash scripts/validate-cluster.sh $(pwd)/kubeconfig

# Test Prometheus integration
bash ../../tests/integration/test-prometheus.sh $(pwd)/kubeconfig

# Test Grafana integration
bash ../../tests/integration/test-grafana.sh $(pwd)/kubeconfig 192.168.4.101

# Deploy test workload (nginx)
bash scripts/deploy-test-workload.sh $(pwd)/kubeconfig
```

## Deployed Components

### Core Infrastructure
- **K3s v1.28.3+k3s1**: Lightweight Kubernetes distribution
  - Server mode on master1 (control plane + SQLite datastore)
  - Agent mode on nodo1 (worker node)
- **Flannel CNI**: Pod networking with VXLAN overlay
- **CoreDNS**: Cluster DNS resolution
- **Local Path Provisioner**: Dynamic PV provisioning

### Monitoring Stack (namespace: `monitoring`)
- **Prometheus**: Metrics collection and storage (15d retention, 10Gi PVC)
  - 19 active scrape targets (nodes, pods, services)
  - Custom scrape config for node metrics
- **Grafana**: Visualization and dashboards (NodePort 30000, 5Gi PVC)
  - 30 pre-configured dashboards
  - K3s Cluster Overview, Node Exporter Full, Kubernetes Cluster Monitoring
- **Alertmanager**: Alert routing and management
- **Node Exporter**: System metrics from both nodes (DaemonSet)
- **Kube State Metrics**: Kubernetes object metrics

### Access URLs
- **Kubernetes API**: https://192.168.4.101:6443
- **Grafana**: http://192.168.4.101:30000
- **Prometheus**: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

## Backup and Restore

### Backup Scripts

The environment includes automated backup scripts for disaster recovery:

**Backup OpenTofu State and Cluster Token:**
```bash
cd terraform/environments/chocolandiadc-mvp
bash scripts/backup-state.sh

# Creates:
# - backups/terraform-state-TIMESTAMP.tar.gz
# - backups/cluster-token-TIMESTAMP.txt
# - backups/kubeconfig-TIMESTAMP.yaml
```

**Backup Complete Cluster:**
```bash
bash scripts/backup-cluster.sh

# Creates:
# - backups/k3s-state-db-TIMESTAMP.db (SQLite database)
# - backups/manifests-TIMESTAMP/ (all Kubernetes resources)
# - backups/helm-TIMESTAMP/ (Helm release values)
# - backups/persistent-volumes-TIMESTAMP/ (PV data)
# - backups/grafana-TIMESTAMP/ (dashboard exports)
```

**Backup Schedule Recommendation**: Daily backups before making changes

### Restore Procedures

See backup manifest files for detailed restore instructions:
- `backups/backup-manifest-TIMESTAMP.txt`
- `backups/cluster-backup-manifest-TIMESTAMP.txt`

## Troubleshooting

Common issues and solutions are documented in:
- **Network Issues**: `../../docs/runbooks/troubleshooting-eero-network.md`
- **Security Best Practices**: `../../docs/security-checklist.md`

### Quick Diagnostics

```bash
export KUBECONFIG=$(pwd)/kubeconfig

# Check node status
kubectl get nodes -o wide

# Check all pods
kubectl get pods -A

# Check monitoring stack
kubectl get pods -n monitoring

# View K3s logs on master1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 \
  "sudo journalctl -u k3s -n 50 --no-pager"

# View K3s agent logs on nodo1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102 \
  "sudo journalctl -u k3s-agent -n 50 --no-pager"
```

## Migration Path

**Status**: This MVP is **temporary**. It will be replaced by Feature 001 when FortiGate hardware is repaired.

**Target Architecture (Feature 001)**:
- 3-node HA control plane (embedded etcd)
- 2 worker nodes
- FortiGate 60F firewall with VLAN segmentation
- Longhorn replicated storage
- MetalLB load balancer

**Migration Resources**:
- Complete migration runbook: `../../docs/runbooks/migration-to-feature-001.md`
- Backup scripts ensure data preservation
- Zero-downtime migration strategy documented

## Development

### Code Quality

```bash
# Format all Terraform code
tofu fmt -recursive terraform/

# Validate configuration
cd terraform/environments/chocolandiadc-mvp
tofu validate

cd terraform/modules/k3s-node
tofu validate
```

### Testing

All validation and integration tests are located in:
- `terraform/environments/chocolandiadc-mvp/scripts/` - Cluster validation
- `tests/integration/` - Prometheus and Grafana integration tests

## Security Considerations

See `../../docs/security-checklist.md` for complete security documentation.

**Key Points**:
- ⚠️ Eero flat network (no VLAN isolation)
- ⚠️ No firewall between cluster and home network
- ✅ SSH key authentication only (no passwords)
- ✅ Kubeconfig with cluster-admin privileges (protect carefully)
- ✅ Grafana password changed from default
- ✅ All sensitive files excluded from Git

**DO NOT**:
- Expose cluster to public internet
- Commit terraform.tfvars, kubeconfig, or *.tfstate to Git
- Run untrusted workloads on this cluster
- Share kubeconfig or SSH keys

## Requirements

**Software:**
- OpenTofu >= 1.6.0
- K3s = v1.28.3+k3s1
- Helm >= 3.12
- kubectl >= 1.28

**Hardware:**
- 2 mini-PCs with >= 2GB RAM, >= 20GB disk each
- Ubuntu Server 22.04 LTS or Debian 11+
- Ethernet connection to Eero mesh network (WiFi not recommended)

**Network:**
- Eero mesh providing DHCP on 192.168.4.0/24
- Static DHCP reservations configured for cluster nodes
- No additional firewall rules (Eero default NAT)

## Related Documentation

- **Quickstart Guide**: `../../specs/002-k3s-mvp-eero/quickstart.md`
- **Feature Specification**: `../../specs/002-k3s-mvp-eero/spec.md`
- **Architecture Design**: `../../specs/002-k3s-mvp-eero/architecture.md`
- **Migration Runbook**: `../../docs/runbooks/migration-to-feature-001.md`
- **Troubleshooting**: `../../docs/runbooks/troubleshooting-eero-network.md`
- **Security Checklist**: `../../docs/security-checklist.md`

## Support

For issues or questions:
- **GitHub Issues**: https://github.com/cbenitezpy-ueno/chocolandia_kube/issues
- **Project Owner**: cbenitez@gmail.com

---

**Version**: 1.0
**Last Updated**: 2025-11-09
**Feature**: 002-k3s-mvp-eero
