# ============================================================================
# Velero Module Variables
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Velero"
  type        = string
  default     = "velero"
}

# MinIO Configuration
variable "minio_url" {
  description = "MinIO S3 API URL (internal cluster URL)"
  type        = string
  default     = "http://minio-api.minio.svc.cluster.local:9000"
}

variable "minio_access_key" {
  description = "MinIO access key (root user)"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key (root password)"
  type        = string
  sensitive   = true
}

variable "velero_bucket_name" {
  description = "Name of the bucket in MinIO for Velero backups"
  type        = string
  default     = "velero-backups"
}

# Velero Configuration
variable "velero_chart_version" {
  description = "Velero Helm chart version"
  type        = string
  default     = "8.1.0"
}

variable "velero_aws_plugin_image" {
  description = "Velero AWS plugin image for S3 compatibility"
  type        = string
  # Using v1.10.x which uses AWS SDK v1 and works better with MinIO/static credentials
  default     = "velero/velero-plugin-for-aws:v1.10.1"
}

variable "minio_client_image" {
  description = "MinIO client image for bucket creation"
  type        = string
  default     = "minio/mc:RELEASE.2024-11-17T19-35-25Z"
}

# Backup Schedule Configuration
variable "backup_schedule" {
  description = "Cron schedule for automatic backups (default: daily at 2am)"
  type        = string
  default     = "0 2 * * *"
}

variable "backup_ttl" {
  description = "Time to live for backups (default: 7 days)"
  type        = string
  default     = "168h0m0s"
}

variable "included_namespaces" {
  description = "Namespaces to include in backups (empty = all)"
  type        = list(string)
  default     = []
}

variable "excluded_namespaces" {
  description = "Namespaces to exclude from backups"
  type        = list(string)
  default     = ["kube-system", "kube-public", "kube-node-lease"]
}

# Node Agent (for PV backups via file system)
variable "enable_node_agent" {
  description = "Enable node agent (restic/kopia) for PV file-level backups"
  type        = bool
  default     = true
}

# Resources
variable "resource_requests_cpu" {
  description = "CPU requests for Velero server"
  type        = string
  default     = "100m"
}

variable "resource_requests_memory" {
  description = "Memory requests for Velero server"
  type        = string
  default     = "128Mi"
}

variable "resource_limits_cpu" {
  description = "CPU limits for Velero server"
  type        = string
  default     = "500m"
}

variable "resource_limits_memory" {
  description = "Memory limits for Velero server"
  type        = string
  default     = "512Mi"
}

# Monitoring
variable "enable_service_monitor" {
  description = "Enable Prometheus ServiceMonitor for Velero metrics"
  type        = bool
  default     = true
}
