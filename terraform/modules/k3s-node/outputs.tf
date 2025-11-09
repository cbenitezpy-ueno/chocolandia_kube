# K3s Node Module - Outputs
# Exposes node information, kubeconfig, and cluster join token

# ============================================================================
# Node Information
# ============================================================================

output "node_ip" {
  description = "IP address of the provisioned K3s node"
  value       = var.node_ip
}

output "hostname" {
  description = "Hostname of the provisioned K3s node"
  value       = var.hostname
}

output "node_role" {
  description = "Role of the node (server or agent)"
  value       = var.node_role
}

# ============================================================================
# Cluster Join Information (Server nodes only)
# ============================================================================

output "cluster_token" {
  description = "K3s cluster join token for agent nodes. Only populated for server nodes."
  value       = var.node_role == "server" ? try(data.external.cluster_token[0].result.token, "") : ""
  sensitive   = true
}

output "server_url" {
  description = "K3s API server URL for agent nodes to join. Only populated for server nodes."
  value       = var.node_role == "server" ? "https://${var.node_ip}:6443" : ""
}

# ============================================================================
# Kubeconfig Access (Server nodes only)
# ============================================================================

output "kubeconfig_content" {
  description = "Content of the kubeconfig file for kubectl access. Only populated for server nodes."
  value       = var.node_role == "server" ? try(data.external.kubeconfig[0].result.content, "") : ""
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Local path where kubeconfig has been saved. Only populated for server nodes."
  value       = var.node_role == "server" ? "${path.root}/kubeconfig" : ""
}

# ============================================================================
# Node Status
# ============================================================================

output "provisioning_complete" {
  description = "Indicates whether node provisioning completed successfully"
  value       = null_resource.k3s_install.id != "" ? true : false
}

output "k3s_version" {
  description = "K3s version installed on this node"
  value       = var.k3s_version
}
