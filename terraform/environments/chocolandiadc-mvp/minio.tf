# ============================================================================
# MinIO S3-Compatible Object Storage Instance
# ============================================================================
# Deploys MinIO in single-server mode (1 replica) with 100Gi Longhorn volume
# for S3-compatible object storage, backups, and application data
# ============================================================================

module "minio" {
  source = "../../modules/minio"

  # Storage configuration (using Longhorn)
  storage_size        = var.minio_storage_size
  storage_class_name  = "longhorn"
  namespace           = "minio"
  replicas            = 1 # Single-server mode

  # Domain configuration
  s3_domain      = var.minio_s3_domain
  console_domain = var.minio_console_domain

  # Resource limits (suitable for homelab)
  resource_requests_cpu    = "500m"
  resource_requests_memory = "1Gi"
  resource_limits_cpu      = "2000m"
  resource_limits_memory   = "4Gi"

  # Enable Prometheus metrics
  enable_metrics = true

  # Cloudflare and Ingress configuration
  cloudflare_zone_id      = var.cloudflare_zone_id
  cloudflare_account_id   = var.cloudflare_account_id
  traefik_loadbalancer_ip = "192.168.4.201" # MetalLB assigned IP
  authorized_emails       = var.authorized_emails
  cluster_issuer          = var.cluster_issuer
}

# ============================================================================
# Outputs
# ============================================================================

output "minio_namespace" {
  description = "Kubernetes namespace where MinIO is deployed"
  value       = module.minio.namespace
}

output "minio_s3_endpoint" {
  description = "MinIO S3 API endpoint (internal cluster URL)"
  value       = module.minio.s3_endpoint
}

output "minio_console_endpoint" {
  description = "MinIO Console endpoint (internal cluster URL)"
  value       = module.minio.console_endpoint
}

output "minio_s3_domain" {
  description = "Public S3 API domain name"
  value       = module.minio.s3_domain
}

output "minio_console_domain" {
  description = "Public Console domain name"
  value       = module.minio.console_domain
}

output "minio_credentials_secret" {
  description = "Name of the Kubernetes Secret containing MinIO credentials"
  value       = module.minio.credentials_secret_name
}

output "minio_pvc_name" {
  description = "Name of the PersistentVolumeClaim for MinIO data"
  value       = module.minio.pvc_name
}

output "minio_storage_size" {
  description = "Size of the MinIO data PersistentVolume"
  value       = module.minio.storage_size
}

output "minio_root_user" {
  description = "MinIO root user (access key)"
  value       = module.minio.root_user
  sensitive   = true
}

output "minio_root_password" {
  description = "MinIO root password (secret key)"
  value       = module.minio.root_password
  sensitive   = true
}

output "minio_credential_retrieval_commands" {
  description = "Commands to retrieve MinIO credentials"
  value = {
    root_user     = "kubectl get secret -n ${module.minio.namespace} ${module.minio.credentials_secret_name} -o jsonpath='{.data.rootUser}' | base64 -d"
    root_password = "kubectl get secret -n ${module.minio.namespace} ${module.minio.credentials_secret_name} -o jsonpath='{.data.rootPassword}' | base64 -d"
  }
}
