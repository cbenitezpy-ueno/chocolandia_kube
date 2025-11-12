# ArgoCD GitOps Deployment
# Feature 008: GitOps Continuous Deployment with ArgoCD
#
# Deploys ArgoCD using Helm chart for automated continuous deployment from GitHub.
# When PRs are approved and merged to main branch, ArgoCD automatically detects changes
# and synchronizes Kubernetes manifests to the K3s cluster.

module "argocd" {
  source = "../../modules/argocd"

  # Core Configuration
  argocd_domain        = var.argocd_domain
  argocd_namespace     = "argocd"
  argocd_chart_version = "5.51.0" # ArgoCD v2.9.x

  # GitHub Repository Authentication
  github_token    = var.github_token
  github_username = var.github_username
  github_repo_url = "https://github.com/cbenitezpy-ueno/chocolandia_kube"

  # TLS Certificate Configuration
  cluster_issuer           = var.cluster_issuer
  certificate_duration     = var.certificate_duration
  certificate_renew_before = var.certificate_renew_before

  # Cloudflare Access Configuration
  cloudflare_account_id       = var.cloudflare_account_id
  authorized_emails           = var.authorized_emails
  google_oauth_idp_id         = var.google_oauth_idp_id
  access_session_duration     = "24h"
  access_auto_redirect        = true
  access_app_launcher_visible = true

  # Prometheus Metrics
  enable_prometheus_metrics = true

  # ArgoCD Component Resources (homelab scale)
  server_replicas          = 1
  server_cpu_limit         = "200m"
  server_memory_limit      = "256Mi"
  repo_server_replicas     = 1
  repo_server_cpu_limit    = "200m"
  repo_server_memory_limit = "128Mi"
  controller_replicas      = 1
  controller_cpu_limit     = "500m"
  controller_memory_limit  = "512Mi"

  # Repository Polling Interval (3 minutes)
  repository_polling_interval = "180s"
}

# ==============================================================================
# Outputs
# ==============================================================================

output "argocd_url" {
  description = "ArgoCD web UI URL"
  value       = module.argocd.argocd_url
}

output "argocd_admin_password_command" {
  description = "Command to retrieve ArgoCD admin password"
  value       = module.argocd.admin_password_retrieval_command
}

output "argocd_cli_login" {
  description = "ArgoCD CLI login command"
  value       = module.argocd.cli_login_command
}
