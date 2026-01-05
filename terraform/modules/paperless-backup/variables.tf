# Paperless Backup Module - Variables
# Feature: 028-paperless-gdrive-backup

variable "namespace" {
  description = "Kubernetes namespace where Paperless is deployed"
  type        = string
  default     = "paperless"
}

variable "backup_schedule" {
  description = "Cron schedule for backup job (default: 3 AM daily)"
  type        = string
  default     = "0 3 * * *"
}

variable "backup_timeout_seconds" {
  description = "Maximum time for backup job to complete (default: 2 hours)"
  type        = number
  default     = 7200
}

variable "backup_retry_limit" {
  description = "Number of retries on backup failure"
  type        = number
  default     = 2
}

variable "rclone_image" {
  description = "rclone container image (pinned for supply-chain security)"
  type        = string
  default     = "rclone/rclone:1.72.0@sha256:0eb18825ac9732c21c11d654007170572bbd495352bb6dbb624f18e4f462c496"
}

variable "rclone_secret_name" {
  description = "Name of the Kubernetes secret containing rclone.conf"
  type        = string
  default     = "rclone-gdrive-config"
}

variable "gdrive_remote_path" {
  description = "Google Drive remote path for backups"
  type        = string
  default     = "gdrive:/Paperless-Backup"
}

variable "paperless_app_name" {
  description = "Name of the Paperless deployment (for pod affinity)"
  type        = string
  default     = "paperless-ngx"
}

variable "data_pvc_name" {
  description = "Name of the Paperless data PVC"
  type        = string
  default     = "paperless-ngx-data"
}

variable "media_pvc_name" {
  description = "Name of the Paperless media PVC"
  type        = string
  default     = "paperless-ngx-media"
}

variable "resources" {
  description = "Resource requests and limits for backup job"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "512Mi"
    }
  }
}

# Notification settings (ntfy)
variable "ntfy_enabled" {
  description = "Enable ntfy notifications"
  type        = bool
  default     = true
}

variable "ntfy_url" {
  description = "ntfy server URL"
  type        = string
  default     = "http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
}

variable "ntfy_user" {
  description = "ntfy username for authentication"
  type        = string
  default     = "alertmanager"
}

variable "ntfy_password_secret_name" {
  description = "Name of the secret containing ntfy password"
  type        = string
  default     = "ntfy-alertmanager-password"
}

variable "ntfy_password_secret_namespace" {
  description = "Namespace of the ntfy password secret"
  type        = string
  default     = "monitoring"
}

variable "ntfy_password_secret_key" {
  description = "Key in the secret containing the password"
  type        = string
  default     = "password"
}

# Monitoring settings
variable "create_prometheus_rule" {
  description = "Create PrometheusRule for backup monitoring"
  type        = bool
  default     = true
}

variable "backup_missing_threshold_hours" {
  description = "Hours after which to alert for missing backup"
  type        = number
  default     = 48
}

# Labels
variable "labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}
