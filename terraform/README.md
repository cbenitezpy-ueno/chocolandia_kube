# ChocolandiaDC K3s MVP - OpenTofu Infrastructure

This directory contains OpenTofu infrastructure-as-code for deploying a minimal K3s cluster (Feature 002: MVP).

## Overview

**Purpose**: Deploy a 2-node K3s cluster (1 control-plane + 1 worker) on Eero mesh network for learning while FortiGate 100D is being repaired.

**Architecture**: Simplified MVP - no HA, no VLANs, no FortiGate. Direct connection to Eero flat network (192.168.4.0/24).

## Project Structure

```
terraform/
├── modules/
│   └── k3s-node/          # Reusable module for K3s server/agent provisioning
│       ├── main.tf        # SSH provisioner for K3s installation
│       ├── variables.tf   # Node configuration (hostname, IP, role, etc.)
│       └── outputs.tf     # Node outputs (status, kubeconfig, token)
│
└── environments/
    └── chocolandiadc-mvp/ # MVP environment (2 nodes)
        ├── main.tf        # Root module calling k3s-node module
        ├── variables.tf   # Environment variables
        ├── terraform.tfvars.example  # Example configuration
        ├── outputs.tf     # Cluster outputs (API endpoint, kubeconfig path)
        ├── providers.tf   # Provider configuration
        └── versions.tf    # OpenTofu version constraints
```

## Quick Start

### Prerequisites

- 2 mini-PCs connected to Eero network (Ethernet recommended)
- SSH keys configured on both nodes
- OpenTofu 1.6+ installed
- kubectl installed

### Deploy Cluster

```bash
cd environments/chocolandiadc-mvp

# 1. Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# 2. Edit terraform.tfvars with your node IPs and SSH details
vim terraform.tfvars

# 3. Initialize OpenTofu
tofu init

# 4. Review plan
tofu plan

# 5. Deploy cluster
tofu apply

# 6. Verify cluster
kubectl --kubeconfig=./kubeconfig get nodes
```

## Migration Path

This MVP is temporary. When FortiGate 100D is repaired, migrate to **Feature 001** (full HA architecture with VLANs).

See migration runbook: `docs/runbooks/migration-to-feature-001.md`

## Requirements

- OpenTofu >= 1.6.0
- K3s >= v1.28.3
- Ubuntu Server 22.04 LTS on nodes
- Eero mesh network providing DHCP
