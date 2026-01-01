# ============================================================================
# Velero Backup Solution
# ============================================================================
# Deploys Velero for cluster backups with MinIO as S3 backend
# Configured for daily backups at 2am with 7-day retention
# ============================================================================

module "velero" {
  source = "../../modules/velero"

  namespace = "velero"

  # MinIO Configuration (using existing MinIO deployment)
  minio_url        = "http://minio-api.minio.svc.cluster.local:9000"
  minio_access_key = module.minio.root_user
  minio_secret_key = module.minio.root_password

  # Backup Schedule Configuration
  backup_schedule = "0 2 * * *" # Daily at 2am
  backup_ttl      = "168h0m0s"  # 7 days retention

  # Include all application namespaces, exclude system namespaces
  excluded_namespaces = [
    "kube-system",
    "kube-public",
    "kube-node-lease",
    "velero" # Don't backup Velero itself
  ]

  # Enable node agent for PV backups via filesystem
  enable_node_agent = true

  # Enable Prometheus monitoring
  enable_service_monitor = true

  # Resources (suitable for homelab)
  resource_requests_cpu    = "100m"
  resource_requests_memory = "128Mi"
  resource_limits_cpu      = "500m"
  resource_limits_memory   = "512Mi"

  depends_on = [module.minio]
}

# ============================================================================
# Outputs
# ============================================================================

output "velero_namespace" {
  description = "Namespace where Velero is deployed"
  value       = module.velero.namespace
}

output "velero_bucket_name" {
  description = "MinIO bucket name for Velero backups"
  value       = module.velero.velero_bucket_name
}

output "velero_backup_schedule" {
  description = "Configured backup schedule"
  value       = module.velero.backup_schedule
}

output "velero_backup_retention" {
  description = "Backup retention period"
  value       = module.velero.backup_ttl
}

output "velero_useful_commands" {
  description = "Useful Velero CLI commands"
  value = {
    install_cli     = "brew install velero"
    list_backups    = "velero backup get"
    create_backup   = "velero backup create my-backup --include-namespaces default,beersystem"
    describe_backup = "velero backup describe <backup-name>"
    restore_backup  = "velero restore create --from-backup <backup-name>"
    list_schedules  = "velero schedule get"
  }
}
