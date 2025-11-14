# K3s Node Module - Main Configuration
# Provisions K3s server (control-plane) or agent (worker) nodes via SSH

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

# ============================================================================
# SSH Connection Configuration
# ============================================================================

locals {
  ssh_connection = {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.node_ip
    port        = var.ssh_port
    private_key = file(var.ssh_private_key_path)
  }

  # Script paths
  server_script_path = "${path.module}/scripts/install-k3s-server.sh"
  agent_script_path  = "${path.module}/scripts/install-k3s-agent.sh"

  # K3s flags joined as string
  k3s_flags_str = join(" ", concat(
    var.k3s_flags,
    var.node_role == "server" ? [for comp in var.disable_components : "--disable=${comp}"] : [],
    var.node_role == "server" ? ["--write-kubeconfig-mode=644"] : [],
    var.node_role == "server" && var.cluster_init ? ["--cluster-init"] : []
  ))

  # TLS SAN joined as comma-separated string
  tls_san_str = join(",", concat([var.node_ip], var.tls_san))
}

# ============================================================================
# K3s Installation (Server or Agent)
# ============================================================================

resource "null_resource" "k3s_install" {
  # Trigger re-provisioning on configuration changes
  triggers = {
    node_ip     = var.node_ip
    node_role   = var.node_role
    k3s_version = var.k3s_version
    k3s_flags   = local.k3s_flags_str
    server_url  = var.server_url
    # Don't include join_token in triggers (it's sensitive and shouldn't force recreation)
  }

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    port        = local.ssh_connection.port
    private_key = local.ssh_connection.private_key
  }

  # Upload installation script
  provisioner "file" {
    source      = var.node_role == "server" ? local.server_script_path : local.agent_script_path
    destination = "/tmp/install-k3s.sh"
  }

  # Execute installation script
  provisioner "remote-exec" {
    inline = var.node_role == "server" ? [
      # Server installation (standalone or HA mode)
      "chmod +x /tmp/install-k3s.sh",
      var.server_url != "" ?
        # HA mode: joining existing cluster as additional control plane
        "sudo /tmp/install-k3s.sh '${var.k3s_version}' '${local.k3s_flags_str}' '${var.node_ip}' '${local.tls_san_str}' '${var.server_url}' '${var.join_token}'" :
        # Standalone mode: first control plane
        "sudo /tmp/install-k3s.sh '${var.k3s_version}' '${local.k3s_flags_str}' '${var.node_ip}' '${local.tls_san_str}'"
      ] : [
      # Agent installation
      "chmod +x /tmp/install-k3s.sh",
      "sudo /tmp/install-k3s.sh '${var.k3s_version}' '${var.server_url}' '${var.join_token}' '${var.node_ip}' '${local.k3s_flags_str}'"
    ]
  }

  # Cleanup
  provisioner "remote-exec" {
    inline = [
      "rm -f /tmp/install-k3s.sh"
    ]
  }
}

# ============================================================================
# Kubeconfig Retrieval (Server nodes only)
# ============================================================================

# Retrieve kubeconfig from server node
data "external" "kubeconfig" {
  count = var.node_role == "server" ? 1 : 0

  depends_on = [null_resource.k3s_install]

  program = ["bash", "-c", <<-EOT
    ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ${var.ssh_user}@${var.node_ip} \
      'sudo cat /etc/rancher/k3s/k3s.yaml' | \
      sed "s/127.0.0.1/${var.node_ip}/g" | \
      jq -Rs '{content: .}'
  EOT
  ]
}

# Save kubeconfig to local file
resource "null_resource" "save_kubeconfig" {
  count = var.node_role == "server" ? 1 : 0

  depends_on = [data.external.kubeconfig]

  triggers = {
    kubeconfig_content = data.external.kubeconfig[0].result.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${data.external.kubeconfig[0].result.content}' > ${path.root}/kubeconfig
      chmod 600 ${path.root}/kubeconfig
    EOT
  }
}

# ============================================================================
# Cluster Token Retrieval (Server nodes only)
# ============================================================================

# Retrieve cluster join token from server node
data "external" "cluster_token" {
  count = var.node_role == "server" ? 1 : 0

  depends_on = [null_resource.k3s_install]

  program = ["bash", "-c", <<-EOT
    ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ${var.ssh_user}@${var.node_ip} \
      'sudo cat /var/lib/rancher/k3s/server/node-token' | \
      jq -Rs '{token: .}'
  EOT
  ]
}

# ============================================================================
# Node Readiness Check
# ============================================================================

# Wait for node to be ready in the cluster
resource "null_resource" "wait_for_node_ready" {
  depends_on = [null_resource.k3s_install]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    port        = local.ssh_connection.port
    private_key = local.ssh_connection.private_key
  }

  provisioner "remote-exec" {
    inline = var.node_role == "server" ? [
      # For server nodes, check with k3s kubectl
      <<-EOT
        echo "Waiting for node ${var.hostname} to be Ready..."
        for i in {1..60}; do
          if sudo k3s kubectl get nodes ${var.hostname} 2>/dev/null | grep -q "Ready"; then
            echo "Node ${var.hostname} is Ready"
            sudo k3s kubectl get nodes ${var.hostname}
            exit 0
          fi
          echo "Attempt $i/60: Node not ready yet..."
          sleep 5
        done
        echo "ERROR: Node ${var.hostname} did not become Ready after 5 minutes"
        exit 1
      EOT
      ] : [
      # For agent nodes, just verify the service is running
      # (server will check node status via kubectl)
      <<-EOT
        echo "Verifying K3s agent is running on ${var.hostname}..."
        for i in {1..30}; do
          if sudo systemctl is-active --quiet k3s-agent; then
            echo "K3s agent is active on ${var.hostname}"
            sudo systemctl status k3s-agent --no-pager
            exit 0
          fi
          echo "Attempt $i/30: Agent not active yet..."
          sleep 2
        done
        echo "ERROR: K3s agent did not start after 1 minute"
        exit 1
      EOT
    ]
  }
}
