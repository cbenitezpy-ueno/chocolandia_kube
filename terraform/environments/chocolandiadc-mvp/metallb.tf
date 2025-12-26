# ============================================================================
# MetalLB Load Balancer Configuration
# ============================================================================
# Provides bare-metal LoadBalancer functionality for K3s cluster
# Replaces K3s ServiceLB (Klipper) for standard-port services

module "metallb" {
  source = "../../modules/metallb"

  depends_on = [
    module.master1,
    module.nodo1
  ]

  # MetalLB Helm chart version (update for upgrades)
  chart_version = "0.15.3"  # Upgraded from 0.14.8

  # IP pool configuration for LoadBalancer services
  # Range: 192.168.4.200-192.168.4.210 (11 IPs available)
  ip_range  = var.metallb_ip_range
  pool_name = "eero-pool"
  namespace = "metallb-system"
}

# ============================================================================
# Outputs
# ============================================================================

output "metallb_namespace" {
  description = "Namespace where MetalLB is deployed"
  value       = module.metallb.namespace
}

output "metallb_chart_version" {
  description = "Deployed MetalLB chart version"
  value       = module.metallb.chart_version
}

output "metallb_ip_range" {
  description = "IP range for LoadBalancer services"
  value       = module.metallb.ip_range
}
