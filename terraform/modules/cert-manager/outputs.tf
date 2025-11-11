# Namespace outputs
output "namespace" {
  description = "Kubernetes namespace where cert-manager is deployed"
  value       = var.namespace
}

# Helm chart outputs
output "chart_version" {
  description = "Deployed cert-manager Helm chart version"
  value       = var.chart_version
}

# ClusterIssuer outputs
output "staging_issuer_name" {
  description = "Name of the staging ClusterIssuer for testing (if enabled)"
  value       = var.enable_staging ? "letsencrypt-staging" : null
}

output "production_issuer_name" {
  description = "Name of the production ClusterIssuer for trusted certificates (if enabled)"
  value       = var.enable_production ? "letsencrypt-production" : null
}

# Monitoring outputs
output "metrics_port" {
  description = "Port number for Prometheus metrics endpoints"
  value       = var.enable_metrics ? 9402 : null
}

output "metrics_enabled" {
  description = "Whether Prometheus metrics are enabled"
  value       = var.enable_metrics
}
