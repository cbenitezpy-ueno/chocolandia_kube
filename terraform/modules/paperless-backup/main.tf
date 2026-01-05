# Paperless Backup Module - Main Resources
# Feature: 028-paperless-gdrive-backup

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
  }
}

# ============================================================================
# Local values
# ============================================================================

locals {
  app_name = "paperless-backup"

  common_labels = merge({
    "app.kubernetes.io/name"       = local.app_name
    "app.kubernetes.io/component"  = "backup"
    "app.kubernetes.io/managed-by" = "opentofu"
    "feature"                      = "028-paperless-gdrive-backup"
  }, var.labels)
}

# ============================================================================
# Data source to verify rclone secret exists
# ============================================================================

data "kubernetes_secret" "rclone_config" {
  metadata {
    name      = var.rclone_secret_name
    namespace = var.namespace
  }
}

# Data source for ntfy password (from monitoring namespace)
data "kubernetes_secret" "ntfy_password" {
  count = var.ntfy_enabled ? 1 : 0

  metadata {
    name      = var.ntfy_password_secret_name
    namespace = var.ntfy_password_secret_namespace
  }
}

# ============================================================================
# ConfigMap with backup script
# ============================================================================

resource "kubernetes_config_map" "backup_script" {
  metadata {
    name      = "${local.app_name}-script"
    namespace = var.namespace
    labels    = local.common_labels
  }

  data = {
    "backup.sh" = <<-EOT
      #!/bin/sh
      set -e

      # Configuration
      RCLONE_CONFIG=/config/rclone/rclone.conf
      GDRIVE_REMOTE="${var.gdrive_remote_path}"
      NTFY_ENABLED="${var.ntfy_enabled}"
      NTFY_URL="${var.ntfy_url}"
      NTFY_USER="${var.ntfy_user}"

      # Timestamp for backup-dir
      DATE=$(date +%Y%m%d)
      START_TIME=$(date +%s)

      echo "=========================================="
      echo "Paperless Backup Starting"
      echo "=========================================="
      echo "Date: $(date)"
      echo "Remote: $GDRIVE_REMOTE"
      echo ""

      # Install curl for notifications (Alpine-based image)
      if [ "$NTFY_ENABLED" = "true" ]; then
        apk add --no-cache curl > /dev/null 2>&1 || true
        NTFY_PASS=$(cat /secrets/ntfy/password 2>/dev/null || echo "")
      fi

      # Copy rclone config to writable location (for token refresh)
      cp $RCLONE_CONFIG /tmp/rclone.conf
      export RCLONE_CONFIG=/tmp/rclone.conf

      # Function to send notification
      send_notification() {
        local title="$1"
        local message="$2"
        local priority="$3"
        local tags="$4"

        if [ "$NTFY_ENABLED" = "true" ] && [ -n "$NTFY_PASS" ]; then
          curl -s -u "$NTFY_USER:$NTFY_PASS" \
            -H "Title: $title" \
            -H "Priority: $priority" \
            -H "Tags: $tags" \
            -d "$message" \
            "$NTFY_URL" || echo "Warning: Failed to send notification"
        fi
      }

      # Sync data directory
      echo "Syncing data directory..."
      DATA_RESULT=0
      rclone sync /data $GDRIVE_REMOTE/data \
        --backup-dir "$GDRIVE_REMOTE/.deleted/data-$DATE" \
        --checksum \
        --stats 1m \
        --stats-one-line \
        --verbose \
        2>&1 | tee /tmp/data-sync.log || DATA_RESULT=$?

      if [ $DATA_RESULT -ne 0 ]; then
        echo "ERROR: Data sync failed with exit code $DATA_RESULT"
      fi

      # Sync media directory
      echo ""
      echo "Syncing media directory..."
      MEDIA_RESULT=0
      rclone sync /media $GDRIVE_REMOTE/media \
        --backup-dir "$GDRIVE_REMOTE/.deleted/media-$DATE" \
        --checksum \
        --stats 1m \
        --stats-one-line \
        --verbose \
        2>&1 | tee /tmp/media-sync.log || MEDIA_RESULT=$?

      if [ $MEDIA_RESULT -ne 0 ]; then
        echo "ERROR: Media sync failed with exit code $MEDIA_RESULT"
      fi

      # Calculate duration
      END_TIME=$(date +%s)
      DURATION=$((END_TIME - START_TIME))
      DURATION_MIN=$((DURATION / 60))
      DURATION_SEC=$((DURATION % 60))

      # Extract stats from logs
      DATA_TRANSFERRED=$(grep -oP 'Transferred:\s+\K[^,]+' /tmp/data-sync.log 2>/dev/null | tail -1 || echo "unknown")
      MEDIA_TRANSFERRED=$(grep -oP 'Transferred:\s+\K[^,]+' /tmp/media-sync.log 2>/dev/null | tail -1 || echo "unknown")

      echo ""
      echo "=========================================="
      echo "Backup Summary"
      echo "=========================================="
      echo "Duration: $${DURATION_MIN}m $${DURATION_SEC}s"
      echo "Data transferred: $DATA_TRANSFERRED"
      echo "Media transferred: $MEDIA_TRANSFERRED"
      echo "Data result: $DATA_RESULT"
      echo "Media result: $MEDIA_RESULT"

      # Send notification and exit
      if [ $DATA_RESULT -eq 0 ] && [ $MEDIA_RESULT -eq 0 ]; then
        echo ""
        echo "SUCCESS: Backup completed successfully!"
        send_notification \
          "Paperless Backup OK" \
          "Backup completado en $${DURATION_MIN}m $${DURATION_SEC}s. Data: $DATA_TRANSFERRED, Media: $MEDIA_TRANSFERRED" \
          "default" \
          "white_check_mark"
        exit 0
      else
        echo ""
        echo "FAILED: Backup completed with errors!"
        send_notification \
          "Paperless Backup FAILED" \
          "Backup fallido despues de $${DURATION_MIN}m. Data: $DATA_RESULT, Media: $MEDIA_RESULT" \
          "high" \
          "x,rotating_light"
        exit 1
      fi
    EOT
  }
}

# ============================================================================
# CronJob for backup
# ============================================================================

resource "kubernetes_cron_job_v1" "backup" {
  metadata {
    name      = local.app_name
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    schedule                      = var.backup_schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = local.common_labels
      }

      spec {
        active_deadline_seconds = var.backup_timeout_seconds
        backoff_limit           = var.backup_retry_limit

        template {
          metadata {
            labels = local.common_labels
          }

          spec {
            restart_policy = "OnFailure"

            # Pod affinity: schedule on same node as Paperless
            affinity {
              pod_affinity {
                required_during_scheduling_ignored_during_execution {
                  label_selector {
                    match_labels = {
                      "app.kubernetes.io/name" = var.paperless_app_name
                    }
                  }
                  topology_key = "kubernetes.io/hostname"
                }
              }
            }

            container {
              name    = "rclone"
              image   = var.rclone_image
              command = ["/bin/sh", "/scripts/backup.sh"]

              resources {
                requests = {
                  cpu    = var.resources.requests.cpu
                  memory = var.resources.requests.memory
                }
                limits = {
                  cpu    = var.resources.limits.cpu
                  memory = var.resources.limits.memory
                }
              }

              # Paperless data PVC (read-only)
              volume_mount {
                name       = "data"
                mount_path = "/data"
                read_only  = true
              }

              # Paperless media PVC (read-only)
              volume_mount {
                name       = "media"
                mount_path = "/media"
                read_only  = true
              }

              # rclone config
              volume_mount {
                name       = "rclone-config"
                mount_path = "/config/rclone"
                read_only  = true
              }

              # Backup script
              volume_mount {
                name       = "backup-script"
                mount_path = "/scripts"
                read_only  = true
              }

              # ntfy password (if enabled)
              dynamic "volume_mount" {
                for_each = var.ntfy_enabled ? [1] : []
                content {
                  name       = "ntfy-password"
                  mount_path = "/secrets/ntfy"
                  read_only  = true
                }
              }
            }

            # Volumes
            volume {
              name = "data"
              persistent_volume_claim {
                claim_name = var.data_pvc_name
              }
            }

            volume {
              name = "media"
              persistent_volume_claim {
                claim_name = var.media_pvc_name
              }
            }

            volume {
              name = "rclone-config"
              secret {
                secret_name = var.rclone_secret_name
              }
            }

            volume {
              name = "backup-script"
              config_map {
                name         = kubernetes_config_map.backup_script.metadata[0].name
                default_mode = "0755"
              }
            }

            dynamic "volume" {
              for_each = var.ntfy_enabled ? [1] : []
              content {
                name = "ntfy-password"
                secret {
                  secret_name = var.ntfy_password_secret_name
                  items {
                    key  = var.ntfy_password_secret_key
                    path = "password"
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    data.kubernetes_secret.rclone_config
  ]
}

# ============================================================================
# PrometheusRule for backup monitoring (optional)
# ============================================================================

resource "kubernetes_manifest" "prometheus_rule" {
  count = var.create_prometheus_rule ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "${local.app_name}-alerts"
      namespace = var.namespace
      labels = merge(local.common_labels, {
        "release" = "kube-prometheus-stack"
      })
    }
    spec = {
      groups = [
        {
          name = "paperless-backup.rules"
          rules = [
            {
              alert = "PaperlessBackupMissing"
              expr  = "time() - kube_cronjob_status_last_successful_time{cronjob=\"${local.app_name}\",namespace=\"${var.namespace}\"} > ${var.backup_missing_threshold_hours * 3600}"
              for   = "1h"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Paperless backup no ejecutado en ${var.backup_missing_threshold_hours}+ horas"
                description = "El backup de Paperless no ha completado exitosamente en mas de ${var.backup_missing_threshold_hours} horas."
              }
            },
            {
              alert = "PaperlessBackupFailed"
              expr  = "kube_job_status_failed{namespace=\"${var.namespace}\",job_name=~\"${local.app_name}-.*\"} > 0"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Paperless backup job failed"
                description = "Un job de backup de Paperless ha fallado. Revisar logs con: kubectl logs -l app.kubernetes.io/name=${local.app_name} -n ${var.namespace}"
              }
            }
          ]
        }
      ]
    }
  }
}
