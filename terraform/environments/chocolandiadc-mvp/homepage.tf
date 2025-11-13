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
# Cloudflare Access for Homepage
# ==============================================================================

# Cloudflare Access Application for Homepage
resource "cloudflare_access_application" "homepage" {
  account_id                = var.cloudflare_account_id
  name                      = "Homepage Dashboard"
  domain                    = "homepage.${var.domain_name}"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true

  allowed_idps = [var.google_oauth_idp_id]
}

# Access Policy - Allow specific Google accounts
resource "cloudflare_access_policy" "homepage_google" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_access_application.homepage.id
  name           = "Allow Google OAuth Users"
  precedence     = 1
  decision       = "allow"

  include {
    email = var.authorized_emails
  }
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
