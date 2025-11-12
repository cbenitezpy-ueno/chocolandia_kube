# ==============================================================================
# Headlamp Web UI Module
# Feature 007: Kubernetes Dashboard with RBAC, HTTPS, and OAuth
# ==============================================================================

module "headlamp" {
  source = "../../modules/headlamp"

  # Basic configuration - Phase 3 (US1)
  namespace = "headlamp"
  domain    = var.headlamp_domain

  # High availability - Phase 3 (US1)
  replicas                 = 2
  pdb_enabled              = true
  pdb_min_available        = 1
  enable_pod_anti_affinity = true

  # Prometheus integration - Phase 3 (US1)
  prometheus_url = "http://kube-prometheus-stack-prometheus.monitoring:9090"

  # ============================================================================
  # Phase 6 (US4): Cloudflare Access - UNCOMMENT AFTER IMPLEMENTATION
  # ============================================================================

  # Cloudflare Access authentication
  cloudflare_account_id = var.cloudflare_account_id
  google_oauth_idp_id   = var.google_oauth_idp_id
  authorized_emails     = var.headlamp_authorized_emails

  # Cloudflare Access session
  access_session_duration     = "24h"
  access_auto_redirect        = true
  access_app_launcher_visible = true

  # ============================================================================
  # Phase 5 (US3): cert-manager TLS - UNCOMMENT AFTER IMPLEMENTATION
  # ============================================================================

  # cert-manager TLS certificate
  cluster_issuer           = "letsencrypt-production"
  certificate_duration     = "2160h" # 90 days
  certificate_renew_before = "720h"  # 30 days
}

# ==============================================================================
# Outputs - Phase 3 (US1)
# ==============================================================================

output "headlamp_namespace" {
  description = "Headlamp deployment namespace"
  value       = module.headlamp.namespace
}

output "headlamp_service_name" {
  description = "Headlamp Kubernetes service name"
  value       = module.headlamp.service_name
}

output "headlamp_replicas" {
  description = "Number of Headlamp replicas deployed"
  value       = module.headlamp.replicas
}

# ==============================================================================
# Outputs - Phase 4 (US2) RBAC
# ==============================================================================

output "headlamp_serviceaccount_token_secret" {
  description = "ServiceAccount token secret name for UI authentication"
  value       = module.headlamp.serviceaccount_token_secret
}

output "headlamp_serviceaccount_name" {
  description = "ServiceAccount name for Headlamp admin"
  value       = module.headlamp.serviceaccount_name
}

# ==============================================================================
# Outputs - Later Phases (Uncomment after implementation)
# ==============================================================================

# output "headlamp_url" {
#   description = "Headlamp web UI URL"
#   value       = module.headlamp.ingress_hostname
# }
