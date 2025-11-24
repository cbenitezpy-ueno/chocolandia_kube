# Registry Module Instantiation
# Deploys Docker Registry v2 for local container image storage

module "registry" {
  source = "../../modules/registry"

  namespace    = "registry"
  storage_size = "30Gi"
  hostname     = "registry.chocolandiadc.local"
  auth_secret  = "registry-auth"

  # Use existing cert-manager cluster issuer
  cluster_issuer = "letsencrypt-prod"

  # Resource configuration for homelab
  resource_limits_memory   = "512Mi"
  resource_limits_cpu      = "500m"
  resource_requests_memory = "256Mi"
  resource_requests_cpu    = "100m"

  # Enable Registry UI
  enable_ui   = true
  ui_hostname = "registry-ui.chocolandiadc.local"
}

# Outputs for registry
output "registry_url" {
  description = "Registry URL for docker login"
  value       = module.registry.registry_url
}

output "registry_internal_endpoint" {
  description = "Internal cluster endpoint for registry"
  value       = module.registry.internal_endpoint
}
