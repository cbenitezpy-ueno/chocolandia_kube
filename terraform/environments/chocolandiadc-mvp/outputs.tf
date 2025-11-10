# ChocolandiaDC MVP Environment Outputs
# Information about deployed cluster and access commands

# ============================================================================
# Cluster Endpoint
# ============================================================================

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = "https://${var.master1_ip}:6443"
}

output "cluster_name" {
  description = "Name of the deployed cluster"
  value       = var.cluster_name
}

# ============================================================================
# Node Information
# ============================================================================

output "master1_ip" {
  description = "IP address of master1 (control-plane)"
  value       = var.master1_ip
}

output "nodo1_ip" {
  description = "IP address of nodo1 (worker)"
  value       = var.nodo1_ip
}

output "node_count" {
  description = "Total number of nodes in the cluster"
  value       = 2
}

# ============================================================================
# Kubeconfig Access
# ============================================================================

output "kubeconfig_path" {
  description = "Path to the kubeconfig file for kubectl access"
  value       = "${path.module}/kubeconfig"
}

output "kubeconfig_command" {
  description = "Command to use kubectl with the cluster kubeconfig"
  value       = "export KUBECONFIG=${path.module}/kubeconfig"
}

# ============================================================================
# Validation Commands
# ============================================================================

output "validation_commands" {
  description = "Commands to validate cluster deployment"
  value = {
    check_nodes          = "kubectl --kubeconfig=${path.module}/kubeconfig get nodes -o wide"
    check_pods           = "kubectl --kubeconfig=${path.module}/kubeconfig get pods -A"
    validate_single_node = "bash ${path.module}/scripts/validate-single-node.sh ${path.module}/kubeconfig"
    validate_cluster     = "bash ${path.module}/scripts/validate-cluster.sh ${path.module}/kubeconfig"
    deploy_test_workload = "bash ${path.module}/scripts/deploy-test-workload.sh ${path.module}/kubeconfig"
  }
}

# ============================================================================
# SSH Access Commands
# ============================================================================

output "ssh_commands" {
  description = "SSH commands to access nodes directly"
  value = {
    master1 = "ssh ${var.ssh_user}@${var.master1_ip}"
    nodo1   = "ssh ${var.ssh_user}@${var.nodo1_ip}"
  }
}

# ============================================================================
# Cloudflare Tunnel Outputs (Feature 004)
# ============================================================================

output "tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = module.cloudflare_tunnel.tunnel_id
}

output "tunnel_cname" {
  description = "Cloudflare Tunnel CNAME target"
  value       = module.cloudflare_tunnel.tunnel_cname
}

output "tunnel_namespace" {
  description = "Kubernetes namespace where cloudflared is deployed"
  value       = module.cloudflare_tunnel.namespace
}

output "service_urls" {
  description = "Public URLs for exposed services"
  value       = module.cloudflare_tunnel.service_urls
}

output "dns_records" {
  description = "Created DNS CNAME records"
  value       = module.cloudflare_tunnel.dns_records
}

output "access_applications" {
  description = "Cloudflare Access Application IDs"
  value       = module.cloudflare_tunnel.access_application_ids
}

# ============================================================================
# Next Steps
# ============================================================================

output "next_steps" {
  description = "Recommended next steps after cluster deployment"
  value       = <<-EOT
    1. Export kubeconfig:
       export KUBECONFIG=${path.module}/kubeconfig

    2. Verify cluster nodes:
       kubectl get nodes -o wide

    3. Run validation scripts:
       bash ${path.module}/scripts/validate-cluster.sh

    4. Deploy test workload:
       bash ${path.module}/scripts/deploy-test-workload.sh

    5. Access cluster API:
       Endpoint: https://${var.master1_ip}:6443

    6. SSH to nodes:
       Master: ssh ${var.ssh_user}@${var.master1_ip}
       Worker: ssh ${var.ssh_user}@${var.nodo1_ip}

    7. Verify Cloudflare Tunnel (Feature 004):
       kubectl --kubeconfig=${path.module}/kubeconfig get pods -n cloudflare-tunnel
       kubectl --kubeconfig=${path.module}/kubeconfig logs -n cloudflare-tunnel -l app=cloudflared

    8. Access protected services:
       ${join("\n       ", [for name, url in module.cloudflare_tunnel.service_urls : "${name}: ${url}"])}
  EOT
}
