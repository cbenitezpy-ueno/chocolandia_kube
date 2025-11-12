# ArgoCD Module Outputs
# Feature 008: GitOps Continuous Deployment with ArgoCD

# ==============================================================================
# ArgoCD Deployment Information
# ==============================================================================

output "namespace" {
  description = "Kubernetes namespace where ArgoCD is deployed"
  value       = var.argocd_namespace
}

output "service_name" {
  description = "ArgoCD server service name for Traefik routing"
  value       = "argocd-server"
}

output "service_port" {
  description = "ArgoCD server service HTTPS port"
  value       = 443
}

output "admin_password_secret" {
  description = "Kubernetes Secret name containing ArgoCD initial admin password"
  value       = "argocd-initial-admin-secret"
  sensitive   = false
}

# ==============================================================================
# Access Information
# ==============================================================================

output "argocd_domain" {
  description = "ArgoCD web UI domain"
  value       = var.argocd_domain
}

output "argocd_url" {
  description = "ArgoCD web UI URL (HTTPS)"
  value       = "https://${var.argocd_domain}"
}

output "cloudflare_access_application_id" {
  description = "Cloudflare Access application ID for ArgoCD (Phase 6 - US4)"
  value       = null  # Created in Phase 6 (US4) - Traefik/HTTPS exposure
}

# ==============================================================================
# TLS Certificate Information
# ==============================================================================

output "certificate_name" {
  description = "cert-manager Certificate resource name"
  value       = "argocd-tls"
}

output "certificate_secret_name" {
  description = "Kubernetes Secret name storing TLS certificate"
  value       = "argocd-tls"
}

# ==============================================================================
# Repository Credentials
# ==============================================================================

output "github_credentials_secret" {
  description = "Kubernetes Secret name containing GitHub repository credentials"
  value       = "chocolandia-kube-repo"
  sensitive   = false
}

# ==============================================================================
# Prometheus Metrics
# ==============================================================================

output "servicemonitor_name" {
  description = "ServiceMonitor resource name for Prometheus scraping"
  value       = var.enable_prometheus_metrics ? "argocd-metrics" : null
}

output "metrics_endpoints" {
  description = "ArgoCD metrics endpoints for Prometheus"
  value = var.enable_prometheus_metrics ? [
    "${var.argocd_namespace}/argocd-server:8084/metrics",
    "${var.argocd_namespace}/argocd-repo-server:8084/metrics",
    "${var.argocd_namespace}/argocd-application-controller:8082/metrics"
  ] : []
}

# ==============================================================================
# Operational Commands
# ==============================================================================

output "cli_login_command" {
  description = "ArgoCD CLI login command for operational access"
  value       = "argocd login ${var.argocd_domain} --grpc-web"
  sensitive   = false
}

output "admin_password_retrieval_command" {
  description = "Command to retrieve ArgoCD initial admin password"
  value       = "kubectl get secret -n ${var.argocd_namespace} argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  sensitive   = false
}

output "port_forward_command" {
  description = "kubectl port-forward command for local UI access"
  value       = "kubectl port-forward -n ${var.argocd_namespace} svc/argocd-server 8080:443"
  sensitive   = false
}
