# ============================================================================
# Longhorn Module Outputs
# ============================================================================

output "storageclass_name" {
  description = "Name of the Longhorn StorageClass for PVC provisioning"
  value       = kubernetes_storage_class_v1.longhorn.metadata[0].name
}

output "namespace" {
  description = "Kubernetes namespace where Longhorn is deployed"
  value       = helm_release.longhorn.namespace
}

output "helm_release_name" {
  description = "Helm release name for Longhorn"
  value       = helm_release.longhorn.name
}

output "helm_release_version" {
  description = "Deployed Longhorn Helm chart version"
  value       = helm_release.longhorn.version
}

output "ui_service_name" {
  description = "Longhorn UI service name (for IngressRoute configuration)"
  value       = "longhorn-frontend"
}

output "ui_service_port" {
  description = "Longhorn UI service port"
  value       = 80
}

output "metrics_enabled" {
  description = "Whether Prometheus metrics are enabled"
  value       = var.enable_metrics
}

output "replica_count" {
  description = "Configured replica count for Longhorn volumes"
  value       = var.replica_count
}
