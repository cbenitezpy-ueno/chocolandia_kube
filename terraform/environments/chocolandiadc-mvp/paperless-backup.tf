# Paperless Backup Module Instance
# Feature: 028-paperless-gdrive-backup

module "paperless_backup" {
  source = "../../modules/paperless-backup"

  namespace       = "paperless"
  backup_schedule = "0 3 * * *" # 3 AM daily

  # PVC names (must match existing Paperless PVCs)
  data_pvc_name    = "paperless-ngx-data"
  media_pvc_name   = "paperless-ngx-media"
  paperless_app_name = "paperless-ngx"

  # rclone configuration
  rclone_secret_name = "rclone-gdrive-config"
  gdrive_remote_path = "gdrive:/Paperless-Backup"

  # Resource limits
  resources = {
    requests = {
      cpu    = "500m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "512Mi"
    }
  }

  # Timeout: 2 hours
  backup_timeout_seconds = 7200
  backup_retry_limit     = 2

  # Notifications via ntfy
  ntfy_enabled                   = true
  ntfy_url                       = "http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
  ntfy_user                      = "alertmanager"
  ntfy_password_secret_name      = "ntfy-alertmanager-password"
  ntfy_password_secret_namespace = "monitoring"
  ntfy_password_secret_key       = "password"

  # Monitoring
  create_prometheus_rule         = true
  backup_missing_threshold_hours = 48
}
