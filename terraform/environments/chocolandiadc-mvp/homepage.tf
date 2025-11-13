# ==============================================================================
# Homepage Dashboard Module
# Feature 009: Centralized Dashboard with Service Status and Widgets
# ==============================================================================

module "homepage" {
  source = "../../modules/homepage"

  # Basic configuration
  homepage_image = var.homepage_image
  namespace      = var.homepage_namespace
  service_port   = var.homepage_service_port
  domain_name    = var.domain_name

  # Widget API credentials
  argocd_token = var.argocd_token

  # Resource limits
  resource_requests_cpu    = var.homepage_resource_requests_cpu
  resource_requests_memory = var.homepage_resource_requests_memory
  resource_limits_cpu      = var.homepage_resource_limits_cpu
  resource_limits_memory   = var.homepage_resource_limits_memory

  # Service discovery namespaces
  monitored_namespaces = var.homepage_monitored_namespaces

  # Ensure cluster is ready before deploying
  depends_on = [
    null_resource.wait_for_cluster_ready
  ]
}

# ==============================================================================
# Outputs
# ==============================================================================

output "homepage_namespace" {
  description = "Homepage deployment namespace"
  value       = module.homepage.namespace
}

output "homepage_service_name" {
  description = "Homepage Kubernetes service name"
  value       = module.homepage.service_name
}

output "homepage_service_url" {
  description = "Internal cluster URL for Homepage"
  value       = module.homepage.service_url
}
