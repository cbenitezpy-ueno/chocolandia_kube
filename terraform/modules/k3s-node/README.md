# K3s Node Module

Reusable OpenTofu module for provisioning K3s nodes (server or agent) via SSH.

## Overview

This module installs and configures K3s on bare-metal or VM nodes using SSH provisioners. It supports both **server** (control-plane) and **agent** (worker) roles.

**Key Features**:
- Idempotent installation scripts (safe to re-run)
- Automatic kubeconfig retrieval (server nodes)
- Cluster join token extraction (server nodes)
- Node readiness validation
- Configurable K3s flags and component disabling
- SQLite or external etcd datastore support

## Architecture

```
┌─────────────────────────────────────────────────┐
│  k3s-node Module                                │
│                                                 │
│  ┌──────────────┐         ┌──────────────┐     │
│  │ Server Mode  │         │ Agent Mode   │     │
│  │ (Control)    │────────▶│ (Worker)     │     │
│  └──────────────┘  Token  └──────────────┘     │
│         │                         │             │
│         │                         │             │
│         ▼                         ▼             │
│  ┌──────────────┐         ┌──────────────┐     │
│  │ SSH          │         │ SSH          │     │
│  │ Provisioner  │         │ Provisioner  │     │
│  └──────────────┘         └──────────────┘     │
│         │                         │             │
└─────────┼─────────────────────────┼─────────────┘
          │                         │
          ▼                         ▼
    ┌──────────┐             ┌──────────┐
    │ Node 1   │             │ Node 2   │
    │ (Server) │             │ (Agent)  │
    └──────────┘             └──────────┘
```

## Prerequisites

1. **SSH Access**: Passwordless SSH key authentication configured on target nodes
2. **Sudo Access**: SSH user must have passwordless sudo (`NOPASSWD` in sudoers)
3. **Network Connectivity**: OpenTofu host can reach nodes via SSH (port 22 or custom)
4. **Node Requirements**:
   - Ubuntu Server 22.04 LTS (recommended) or compatible Linux distro
   - At least 2GB RAM (4GB+ recommended)
   - At least 20GB disk space
   - Static IP address or DHCP reservation

## Usage

### Server Node (Control-Plane)

```hcl
module "k3s_server" {
  source = "../../modules/k3s-node"

  # Node identity
  hostname = "master1"
  node_ip  = "192.168.4.10"
  node_role = "server"

  # SSH access
  ssh_user             = "cbenitez"
  ssh_private_key_path = "~/.ssh/id_rsa"

  # K3s configuration
  k3s_version = "v1.28.3+k3s1"
  k3s_flags   = [
    "--write-kubeconfig-mode=644"
  ]

  # Disable default components (using custom alternatives)
  disable_components = ["traefik", "servicelb"]

  # Add additional TLS SANs
  tls_san = ["master1.local", "192.168.4.10"]
}

# Outputs for use in agent nodes
output "server_url" {
  value = module.k3s_server.server_url
}

output "cluster_token" {
  value     = module.k3s_server.cluster_token
  sensitive = true
}

output "kubeconfig_path" {
  value = module.k3s_server.kubeconfig_path
}
```

### Agent Node (Worker)

```hcl
module "k3s_agent" {
  source = "../../modules/k3s-node"

  # Node identity
  hostname = "nodo1"
  node_ip  = "192.168.4.11"
  node_role = "agent"

  # SSH access
  ssh_user             = "cbenitez"
  ssh_private_key_path = "~/.ssh/id_rsa"

  # K3s configuration
  k3s_version = "v1.28.3+k3s1"

  # Cluster join configuration
  server_url = module.k3s_server.server_url
  join_token = module.k3s_server.cluster_token

  # Ensure server is ready before provisioning agent
  depends_on = [module.k3s_server]
}
```

### Complete 2-Node Cluster Example

```hcl
# Server node
module "k3s_server" {
  source = "../../modules/k3s-node"

  hostname             = "master1"
  node_ip              = "192.168.4.10"
  node_role            = "server"
  ssh_user             = "cbenitez"
  ssh_private_key_path = "~/.ssh/id_rsa"
  k3s_version          = "v1.28.3+k3s1"
  disable_components   = ["traefik"]
}

# Worker node
module "k3s_agent" {
  source = "../../modules/k3s-node"

  hostname             = "nodo1"
  node_ip              = "192.168.4.11"
  node_role            = "agent"
  ssh_user             = "cbenitez"
  ssh_private_key_path = "~/.ssh/id_rsa"
  k3s_version          = "v1.28.3+k3s1"
  server_url           = module.k3s_server.server_url
  join_token           = module.k3s_server.cluster_token

  depends_on = [module.k3s_server]
}

# Verify cluster
output "cluster_endpoint" {
  value = module.k3s_server.server_url
}

output "kubeconfig_path" {
  value = module.k3s_server.kubeconfig_path
}
```

## Input Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `hostname` | `string` | Hostname for the K3s node (e.g., "master1", "nodo1") |
| `node_ip` | `string` | Static IP address of the node (e.g., "192.168.4.10") |
| `node_role` | `string` | Role of the node: "server" or "agent" |

### Optional Variables (Common)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ssh_user` | `string` | `"cbenitez"` | SSH username for connecting to the node |
| `ssh_private_key_path` | `string` | `"~/.ssh/id_rsa"` | Path to SSH private key |
| `ssh_port` | `number` | `22` | SSH port for connections |
| `k3s_version` | `string` | `"v1.28.3+k3s1"` | K3s version to install |
| `k3s_channel` | `string` | `"stable"` | K3s release channel: "stable", "latest", or "testing" |
| `k3s_flags` | `list(string)` | `[]` | Additional flags to pass to K3s |
| `disable_components` | `list(string)` | `["traefik"]` | K3s components to disable |
| `tls_san` | `list(string)` | `[]` | Additional TLS Subject Alternative Names |

### Agent-Specific Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `server_url` | `string` | `""` | **Required for agents**: K3s server URL (e.g., "https://192.168.4.10:6443") |
| `join_token` | `string` (sensitive) | `""` | **Required for agents**: Cluster join token from server |

## Outputs

### Common Outputs

| Output | Type | Description |
|--------|------|-------------|
| `node_ip` | `string` | IP address of the provisioned node |
| `hostname` | `string` | Hostname of the provisioned node |
| `node_role` | `string` | Role of the node (server or agent) |
| `provisioning_complete` | `bool` | Whether provisioning completed successfully |
| `k3s_version` | `string` | K3s version installed on the node |

### Server-Specific Outputs

| Output | Type | Description |
|--------|------|-------------|
| `cluster_token` | `string` (sensitive) | K3s cluster join token for agent nodes |
| `server_url` | `string` | K3s API server URL (https://NODE_IP:6443) |
| `kubeconfig_content` | `string` (sensitive) | Content of the kubeconfig file |
| `kubeconfig_path` | `string` | Local path where kubeconfig has been saved |

## How It Works

### Server Provisioning Flow

1. **Upload Script**: Copy `install-k3s-server.sh` to target node via SSH
2. **Execute Installation**: Run script with sudo (installs K3s, configures systemd)
3. **Wait for Ready**: Poll node status until it reports "Ready"
4. **Retrieve Kubeconfig**: Fetch `/etc/rancher/k3s/k3s.yaml` and replace `127.0.0.1` with node IP
5. **Retrieve Token**: Fetch `/var/lib/rancher/k3s/server/node-token` for agent join
6. **Save Kubeconfig**: Write kubeconfig to `{environment}/kubeconfig`

### Agent Provisioning Flow

1. **Upload Script**: Copy `install-k3s-agent.sh` to target node via SSH
2. **Execute Installation**: Run script with sudo, passing server URL and join token
3. **Join Cluster**: K3s agent connects to server and joins cluster
4. **Wait for Ready**: Verify K3s agent systemd service is active

## Troubleshooting

### SSH Connection Issues

**Problem**: `Error: timeout - last error: dial tcp X.X.X.X:22: i/o timeout`

**Solution**:
1. Verify node is reachable: `ping <node_ip>`
2. Check SSH service is running: `ssh <user>@<node_ip>`
3. Verify SSH key authentication: `ssh -i ~/.ssh/id_rsa <user>@<node_ip>`
4. Check firewall rules on node: `sudo ufw status`

### Installation Script Failures

**Problem**: K3s installation fails with "permission denied"

**Solution**:
1. Verify SSH user has passwordless sudo:
   ```bash
   echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER
   ```
2. Test sudo access: `ssh <user>@<node_ip> 'sudo whoami'` (should return "root")

### Kubeconfig Retrieval Fails

**Problem**: `data.external.kubeconfig: external program exited with error`

**Solution**:
1. SSH into server node: `ssh <user>@<server_ip>`
2. Check kubeconfig exists: `sudo ls -la /etc/rancher/k3s/k3s.yaml`
3. Verify K3s is running: `sudo systemctl status k3s`
4. Check permissions: `sudo chmod 600 /etc/rancher/k3s/k3s.yaml` (secure: only root can read)

### Node Not Joining Cluster

**Problem**: Agent node installed but not visible in `kubectl get nodes`

**Solution**:
1. Check K3s agent service on worker: `sudo systemctl status k3s-agent`
2. View agent logs: `sudo journalctl -u k3s-agent -f`
3. Verify server URL is correct: `echo $K3S_URL` (should be `https://<server_ip>:6443`)
4. Verify join token is valid: SSH to server and check `/var/lib/rancher/k3s/server/node-token`
5. Check network connectivity: From agent, run `curl -k https://<server_ip>:6443`

## Security Considerations

1. **SSH Keys**: Never commit private keys to Git (`.gitignore` protects `*.pem`, `*.key`)
2. **Kubeconfig**: Stored with `chmod 600` permissions in environment directory
3. **Join Token**: Marked `sensitive = true` in OpenTofu outputs
4. **Sudo Access**: Required for installation; review sudoers configuration
5. **Network Exposure**: K3s API server (6443) exposed on all interfaces by default

## Migration Notes

This module is designed for the **MVP deployment (Feature 002)**. When migrating to the full HA architecture (Feature 001):

- Add support for external etcd datastore (`datastore = "etcd"`)
- Implement multi-master setup (3 server nodes)
- Add VIP (Virtual IP) configuration for control-plane HA
- Integrate with FortiGate VLAN configuration
- Add backup/restore automation for etcd data

See `docs/runbooks/migration-to-feature-001.md` for migration runbook.

## Development

### Testing Module Locally

```bash
cd modules/k3s-node
tofu init
tofu validate
```

### Updating Installation Scripts

After modifying `scripts/install-k3s-server.sh` or `scripts/install-k3s-agent.sh`:

1. Test script manually on a test node
2. Run `tofu validate` to check syntax
3. Run `tofu apply` in a test environment before production

## References

- [K3s Documentation](https://docs.k3s.io/)
- [K3s Installation Options](https://docs.k3s.io/installation/configuration)
- [OpenTofu Null Provider](https://registry.terraform.io/providers/hashicorp/null/latest/docs)
- [Feature 002 Specification](../../../specs/002-k3s-mvp-eero/spec.md)
