# ============================================================================
# MetalLB Module Outputs
# ============================================================================

output "namespace" {
  description = "Namespace where MetalLB is deployed"
  value       = helm_release.metallb.namespace
}

output "chart_version" {
  description = "Deployed MetalLB chart version"
  value       = helm_release.metallb.version
}

output "pool_name" {
  description = "Name of the IP address pool"
  value       = var.pool_name
}

output "ip_range" {
  description = "IP range for LoadBalancer services"
  value       = var.ip_range
}
