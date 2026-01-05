# Paperless Backup Module - Outputs
# Feature: 028-paperless-gdrive-backup

output "cronjob_name" {
  description = "Name of the backup CronJob"
  value       = kubernetes_cron_job_v1.backup.metadata[0].name
}

output "configmap_name" {
  description = "Name of the ConfigMap containing the backup script"
  value       = kubernetes_config_map.backup_script.metadata[0].name
}

output "rclone_secret_name" {
  description = "Name of the secret that must contain rclone config (create manually)"
  value       = var.rclone_secret_name
}

output "backup_schedule" {
  description = "Cron schedule for the backup job"
  value       = var.backup_schedule
}

output "gdrive_remote_path" {
  description = "Google Drive path where backups are stored"
  value       = var.gdrive_remote_path
}

output "manual_job_command" {
  description = "Command to trigger a manual backup"
  value       = "kubectl create job --from=cronjob/${kubernetes_cron_job_v1.backup.metadata[0].name} manual-backup-$(date +%Y%m%d%H%M) -n ${var.namespace}"
}

output "view_logs_command" {
  description = "Command to view backup job logs"
  value       = "kubectl logs -l app.kubernetes.io/name=paperless-backup -n ${var.namespace} --tail=100"
}
