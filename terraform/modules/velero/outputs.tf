# ============================================================================
# Velero Module Outputs
# ============================================================================

output "namespace" {
  description = "Namespace where Velero is deployed"
  value       = kubernetes_namespace.velero.metadata[0].name
}

output "velero_bucket_name" {
  description = "MinIO bucket name for Velero backups"
  value       = var.velero_bucket_name
}

output "backup_schedule" {
  description = "Configured backup schedule"
  value       = var.backup_schedule
}

output "backup_ttl" {
  description = "Backup retention period"
  value       = var.backup_ttl
}

output "helm_release_name" {
  description = "Name of the Velero Helm release"
  value       = helm_release.velero.name
}

output "helm_release_version" {
  description = "Version of the Velero Helm chart"
  value       = helm_release.velero.version
}
