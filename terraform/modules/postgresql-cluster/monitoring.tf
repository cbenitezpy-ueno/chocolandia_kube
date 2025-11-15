# PostgreSQL Cluster Module - Prometheus Alerts Configuration
# Feature: 011-postgresql-cluster
# Phase: 7 - Observability & Monitoring
#
# Creates PrometheusRule resources with alerts for PostgreSQL cluster health

# ==============================================================================
# PrometheusRule for PostgreSQL Alerts
# ==============================================================================

resource "kubernetes_manifest" "postgresql_prometheus_rules" {
  count = var.enable_service_monitor ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "${var.release_name}-postgresql-alerts"
      namespace = var.namespace
      labels = merge(
        local.common_labels,
        {
          prometheus = "kube-prometheus-stack"
          role       = "alert-rules"
        }
      )
    }

    spec = {
      groups = [
        # ======================================================================
        # PostgreSQL Instance Health
        # ======================================================================
        {
          name     = "postgresql-instance-health"
          interval = "30s"
          rules = [
            {
              alert = "PostgreSQLDown"
              expr  = "pg_up == 0"
              for   = "1m"
              labels = {
                severity = "critical"
                component = "postgresql"
              }
              annotations = {
                summary     = "PostgreSQL instance is down"
                description = "PostgreSQL instance {{ $labels.pod }} in namespace {{ $labels.namespace }} has been down for more than 1 minute."
              }
            },
            {
              alert = "PostgreSQLTooManyConnections"
              expr  = "(sum by (pod) (pg_stat_activity_count) / max by (pod) (pg_settings_max_connections) * 100) > 80"
              for   = "5m"
              labels = {
                severity = "warning"
                component = "postgresql"
              }
              annotations = {
                summary     = "PostgreSQL has too many connections"
                description = "PostgreSQL instance {{ $labels.pod }} is using {{ $value | humanizePercentage }} of max connections."
              }
            },
            {
              alert = "PostgreSQLDeadLocks"
              expr  = "rate(pg_stat_database_deadlocks[5m]) > 0"
              for   = "2m"
              labels = {
                severity = "warning"
                component = "postgresql"
              }
              annotations = {
                summary     = "PostgreSQL has deadlocks"
                description = "PostgreSQL database {{ $labels.datname }} on {{ $labels.pod }} has {{ $value }} deadlocks per second."
              }
            }
          ]
        },
        # ======================================================================
        # Replication Health
        # ======================================================================
        {
          name     = "postgresql-replication"
          interval = "30s"
          rules = [
            {
              alert = "PostgreSQLReplicationLagHigh"
              expr  = "pg_replication_lag > 60"
              for   = "5m"
              labels = {
                severity = "warning"
                component = "postgresql-replication"
              }
              annotations = {
                summary     = "PostgreSQL replication lag is high"
                description = "PostgreSQL replication lag on {{ $labels.pod }} is {{ $value }} seconds, which is above the 60 second threshold."
              }
            },
            {
              alert = "PostgreSQLReplicationLagCritical"
              expr  = "pg_replication_lag > 300"
              for   = "2m"
              labels = {
                severity = "critical"
                component = "postgresql-replication"
              }
              annotations = {
                summary     = "PostgreSQL replication lag is critically high"
                description = "PostgreSQL replication lag on {{ $labels.pod }} is {{ $value }} seconds, which is critically high (>5 minutes)."
              }
            },
            {
              alert = "PostgreSQLReplicationStopped"
              expr  = "pg_stat_replication_pg_current_wal_lsn_bytes - pg_stat_replication_sent_lsn_bytes > 1e9"
              for   = "5m"
              labels = {
                severity = "critical"
                component = "postgresql-replication"
              }
              annotations = {
                summary     = "PostgreSQL replication appears to be stopped"
                description = "PostgreSQL replication on {{ $labels.pod }} has a WAL lag of {{ $value | humanize }}B, indicating replication may be stopped."
              }
            },
            {
              alert = "PostgreSQLNoReplicaConnected"
              expr  = "sum by (pod) (pg_stat_replication_pg_current_wal_lsn_bytes) == 0"
              for   = "5m"
              labels = {
                severity = "warning"
                component = "postgresql-replication"
              }
              annotations = {
                summary     = "PostgreSQL has no replica connected"
                description = "PostgreSQL primary {{ $labels.pod }} has no replica connected for more than 5 minutes."
              }
            }
          ]
        },
        # ======================================================================
        # Storage and Performance
        # ======================================================================
        {
          name     = "postgresql-storage-performance"
          interval = "30s"
          rules = [
            {
              alert = "PostgreSQLHighDiskUsage"
              expr  = "((kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~\"data-.*postgresql.*\"} - kubelet_volume_stats_available_bytes{persistentvolumeclaim=~\"data-.*postgresql.*\"}) / kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~\"data-.*postgresql.*\"} * 100) > 80"
              for   = "5m"
              labels = {
                severity = "warning"
                component = "postgresql-storage"
              }
              annotations = {
                summary     = "PostgreSQL disk usage is high"
                description = "PostgreSQL volume {{ $labels.persistentvolumeclaim }} is {{ $value | humanizePercentage }} full."
              }
            },
            {
              alert = "PostgreSQLCriticalDiskUsage"
              expr  = "((kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~\"data-.*postgresql.*\"} - kubelet_volume_stats_available_bytes{persistentvolumeclaim=~\"data-.*postgresql.*\"}) / kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~\"data-.*postgresql.*\"} * 100) > 90"
              for   = "2m"
              labels = {
                severity = "critical"
                component = "postgresql-storage"
              }
              annotations = {
                summary     = "PostgreSQL disk usage is critically high"
                description = "PostgreSQL volume {{ $labels.persistentvolumeclaim }} is {{ $value | humanizePercentage }} full. Immediate action required."
              }
            },
            {
              alert = "PostgreSQLSlowQueries"
              expr  = "rate(pg_stat_activity_max_tx_duration[5m]) > 300"
              for   = "5m"
              labels = {
                severity = "warning"
                component = "postgresql-performance"
              }
              annotations = {
                summary     = "PostgreSQL has slow queries"
                description = "PostgreSQL on {{ $labels.pod }} has queries running for more than 5 minutes."
              }
            },
            {
              alert = "PostgreSQLCacheHitRatioLow"
              expr  = "((sum by (pod) (pg_stat_database_blks_hit) / (sum by (pod) (pg_stat_database_blks_hit) + sum by (pod) (pg_stat_database_blks_read))) * 100) < 90"
              for   = "10m"
              labels = {
                severity = "warning"
                component = "postgresql-performance"
              }
              annotations = {
                summary     = "PostgreSQL cache hit ratio is low"
                description = "PostgreSQL on {{ $labels.pod }} has a cache hit ratio of {{ $value | humanizePercentage }}, which is below 90%."
              }
            }
          ]
        },
        # ======================================================================
        # Transaction and Lock Monitoring
        # ======================================================================
        {
          name     = "postgresql-transactions-locks"
          interval = "30s"
          rules = [
            {
              alert = "PostgreSQLTooManyLocks"
              expr  = "((sum by (pod) (pg_locks_count)) / (sum by (pod) (pg_settings_max_locks_per_transaction) * sum by (pod) (pg_settings_max_connections))) > 0.8"
              for   = "5m"
              labels = {
                severity = "warning"
                component = "postgresql-locks"
              }
              annotations = {
                summary     = "PostgreSQL has too many locks"
                description = "PostgreSQL on {{ $labels.pod }} is using {{ $value | humanizePercentage }} of available locks."
              }
            },
            {
              alert = "PostgreSQLRollbackRateHigh"
              expr  = "rate(pg_stat_database_xact_rollback[5m]) / rate(pg_stat_database_xact_commit[5m]) > 0.1"
              for   = "5m"
              labels = {
                severity = "warning"
                component = "postgresql-transactions"
              }
              annotations = {
                summary     = "PostgreSQL rollback rate is high"
                description = "PostgreSQL database {{ $labels.datname }} on {{ $labels.pod }} has a rollback rate of {{ $value | humanizePercentage }}."
              }
            }
          ]
        }
      ]
    }
  }

  # Ensure PrometheusRule is created after ServiceMonitor
  depends_on = [
    helm_release.postgresql
  ]
}

# ==============================================================================
# Outputs for Monitoring
# ==============================================================================

output "prometheus_rule_created" {
  description = "Whether PrometheusRule for alerts was created"
  value       = var.enable_service_monitor
}

output "prometheus_metrics_endpoints" {
  description = "Prometheus metrics endpoints for PostgreSQL"
  value = var.enable_metrics ? {
    primary = "${var.release_name}-postgresql-primary-metrics.${var.namespace}.svc.cluster.local:9187"
    read    = "${var.release_name}-postgresql-read-metrics.${var.namespace}.svc.cluster.local:9187"
  } : null
}
