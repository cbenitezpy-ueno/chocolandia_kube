# ============================================================================
# Loki Module Outputs
# ============================================================================

output "namespace" {
  description = "Namespace where Loki is deployed"
  value       = var.namespace
}

output "loki_url" {
  description = "Internal URL for Loki"
  value       = "http://loki.${var.namespace}.svc.cluster.local:3100"
}

output "helm_release_name" {
  description = "Name of the Loki Helm release"
  value       = helm_release.loki.name
}

output "helm_release_version" {
  description = "Version of the Loki Helm chart"
  value       = helm_release.loki.version
}

output "retention_period" {
  description = "Log retention period"
  value       = var.retention_period
}
