# OpenTofu Modules - ChocolandiaDC K3s Cluster

This directory contains reusable OpenTofu modules for K3s cluster infrastructure.

## Module Organization

### `k3s-node/` - K3s Node Provisioning Module

**Purpose**: Provisions and configures individual K3s nodes (server or agent) via SSH.

**Responsibilities**:
- Install K3s binary on target node via SSH provisioner
- Configure K3s in server mode (control-plane) or agent mode (worker)
- Generate and distribute cluster join tokens
- Configure K3s systemd service
- Return kubeconfig for kubectl access

**Usage Example**:

```hcl
module "k3s_server" {
  source = "../../modules/k3s-node"

  # Node identity
  hostname    = "master1"
  node_ip     = "192.168.4.10"
  node_role   = "server"  # or "agent" for worker nodes

  # SSH access
  ssh_user    = "cbenitez"
  ssh_key     = file("~/.ssh/id_rsa")

  # K3s configuration
  k3s_version = "v1.28.3+k3s1"
  k3s_flags   = [
    "--disable=traefik",
    "--write-kubeconfig-mode=644"
  ]

  # Cluster join (for agents only)
  server_url  = "https://192.168.4.10:6443"  # Only required for agent nodes
  join_token  = module.k3s_server.cluster_token  # Only required for agent nodes
}
```

**Outputs**:
- `node_ip`: IP address of the provisioned node
- `cluster_token`: K3s join token (server nodes only)
- `kubeconfig_path`: Path to generated kubeconfig file (server nodes only)

## Module Development Guidelines

1. **Idempotency**: All modules must be idempotent (safe to run multiple times)
2. **SSH Access**: Modules assume SSH key-based authentication is pre-configured
3. **K3s Versions**: Pin K3s versions in module variables for reproducibility
4. **Error Handling**: Use provisioner failure handlers for robust deployments
5. **Documentation**: Inline comments for all non-obvious configuration

## Adding New Modules

When adding new modules to this directory:

1. Create module directory: `terraform/modules/{module-name}/`
2. Required files:
   - `main.tf` - Primary resources and provisioners
   - `variables.tf` - Input variables with descriptions and validation
   - `outputs.tf` - Module outputs
   - `README.md` - Module-specific documentation with usage examples
3. Update this file with module description and usage example

## Testing Modules

Test modules in isolation before using in environments:

```bash
cd modules/k3s-node
tofu init
tofu validate
```

For full integration testing, use test fixtures in `tests/integration/`.
