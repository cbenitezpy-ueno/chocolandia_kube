# ============================================================================
# MinIO Module Outputs
# ============================================================================

output "namespace" {
  description = "Kubernetes namespace where MinIO is deployed"
  value       = kubernetes_namespace.minio.metadata[0].name
}

output "s3_endpoint" {
  description = "MinIO S3 API endpoint (internal cluster URL)"
  value       = "http://minio-api.${kubernetes_namespace.minio.metadata[0].name}.svc.cluster.local:9000"
}

output "console_endpoint" {
  description = "MinIO Console endpoint (internal cluster URL)"
  value       = "http://minio-console.${kubernetes_namespace.minio.metadata[0].name}.svc.cluster.local:9001"
}

output "s3_domain" {
  description = "Public S3 API domain name"
  value       = var.s3_domain
}

output "console_domain" {
  description = "Public Console domain name"
  value       = var.console_domain
}

output "credentials_secret_name" {
  description = "Name of the Kubernetes Secret containing MinIO credentials"
  value       = kubernetes_secret.minio_credentials.metadata[0].name
}

output "pvc_name" {
  description = "Name of the PersistentVolumeClaim for MinIO data"
  value       = kubernetes_persistent_volume_claim.minio_data.metadata[0].name
}

output "storage_size" {
  description = "Size of the MinIO data PersistentVolume"
  value       = var.storage_size
}

output "root_user" {
  description = "MinIO root user (access key)"
  value       = random_password.minio_root_user.result
  sensitive   = true
}

output "root_password" {
  description = "MinIO root password (secret key)"
  value       = random_password.minio_root_password.result
  sensitive   = true
}

output "api_service_name" {
  description = "MinIO S3 API service name (for IngressRoute)"
  value       = kubernetes_service.minio_api.metadata[0].name
}

output "console_service_name" {
  description = "MinIO Console service name (for IngressRoute)"
  value       = kubernetes_service.minio_console.metadata[0].name
}
