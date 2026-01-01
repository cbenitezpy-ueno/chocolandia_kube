# Alerting Rules Module - Main
# Feature: 014-monitoring-alerts
# Creates PrometheusRule CRDs for node and service monitoring

# ============================================================================
# Node Alerting Rules (US1)
# ============================================================================

resource "kubernetes_manifest" "node_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "homelab-node-alerts"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"       = "alerting-rules"
        "app.kubernetes.io/managed-by" = "opentofu"
        "prometheus"                   = "kube-prometheus-stack"
        "release"                      = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        {
          name = "homelab-node-alerts"
          rules = [
            # Node Down Alert (Critical)
            {
              alert = "NodeDown"
              expr  = "up{job=\"kubernetes-nodes\"} == 0"
              for   = "${var.node_down_threshold_minutes}m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Node {{ $labels.instance }} is down"
                description = "Node {{ $labels.instance }} has been unreachable for more than ${var.node_down_threshold_minutes} minutes."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # Node Not Ready Alert (Warning)
            {
              alert = "NodeNotReady"
              expr  = "kube_node_status_condition{condition=\"Ready\",status=\"true\"} == 0"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Node {{ $labels.node }} is not ready"
                description = "Node {{ $labels.node }} has been in NotReady state for more than 5 minutes."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.node }}"
              }
            },
            # High Disk Usage (Warning)
            {
              alert = "NodeDiskUsageWarning"
              expr  = "(1 - (node_filesystem_avail_bytes{fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\"})) * 100 > ${var.disk_usage_warning_percent}"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High disk usage on {{ $labels.instance }}"
                description = "Disk {{ $labels.mountpoint }} on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}% full."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # Critical Disk Usage
            {
              alert = "NodeDiskUsageCritical"
              expr  = "(1 - (node_filesystem_avail_bytes{fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\"})) * 100 > ${var.disk_usage_critical_percent}"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Critical disk usage on {{ $labels.instance }}"
                description = "Disk {{ $labels.mountpoint }} on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}% full. Immediate action required!"
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # High Memory Usage (Warning)
            {
              alert = "NodeMemoryUsageWarning"
              expr  = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > ${var.memory_usage_warning_percent}"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High memory usage on {{ $labels.instance }}"
                description = "Memory usage on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}%."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # Critical Memory Usage
            {
              alert = "NodeMemoryUsageCritical"
              expr  = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > ${var.memory_usage_critical_percent}"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Critical memory usage on {{ $labels.instance }}"
                description = "Memory usage on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}%. System may become unstable!"
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # High CPU Usage (Warning)
            {
              alert = "NodeCPUUsageWarning"
              expr  = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > ${var.cpu_usage_warning_percent}"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High CPU usage on {{ $labels.instance }}"
                description = "CPU usage on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}%."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # Critical CPU Usage
            {
              alert = "NodeCPUUsageCritical"
              expr  = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > ${var.cpu_usage_critical_percent}"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Critical CPU usage on {{ $labels.instance }}"
                description = "CPU usage on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}%. Performance degradation expected!"
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            }
          ]
        }
      ]
    }
  }
}

# ============================================================================
# Service Alerting Rules (US2)
# ============================================================================

resource "kubernetes_manifest" "service_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "homelab-service-alerts"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"       = "alerting-rules"
        "app.kubernetes.io/managed-by" = "opentofu"
        "prometheus"                   = "kube-prometheus-stack"
        "release"                      = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        {
          name = "homelab-service-alerts"
          rules = [
            # Pod CrashLooping
            {
              alert = "PodCrashLooping"
              expr  = "increase(kube_pod_container_status_restarts_total[1h]) > 3"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has restarted {{ printf \"%.0f\" $value }} times in the last hour."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # Pod Not Ready
            {
              alert = "PodNotReady"
              expr  = "kube_pod_status_ready{condition=\"true\"} == 0 and on(pod, namespace) kube_pod_status_phase{phase=\"Running\"} == 1"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is not ready"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in non-ready state for more than 10 minutes."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # Deployment Replicas Mismatch
            {
              alert = "DeploymentReplicasMismatch"
              expr  = "kube_deployment_spec_replicas != kube_deployment_status_replicas_available"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replicas mismatch"
                description = "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has {{ $value }} available replicas instead of desired."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # StatefulSet Replicas Mismatch
            {
              alert = "StatefulSetReplicasMismatch"
              expr  = "kube_statefulset_replicas != kube_statefulset_status_replicas_ready"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} replicas mismatch"
                description = "StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has {{ $value }} ready replicas instead of desired."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # Container OOMKilled
            {
              alert = "ContainerOOMKilled"
              expr  = "kube_pod_container_status_last_terminated_reason{reason=\"OOMKilled\"} == 1"
              for   = "0m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Container {{ $labels.container }} OOM killed"
                description = "Container {{ $labels.container }} in pod {{ $labels.namespace }}/{{ $labels.pod }} was OOM killed."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # PVC Almost Full
            {
              alert = "PVCAlmostFull"
              expr  = "(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 85"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} almost full"
                description = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is {{ printf \"%.1f\" $value }}% full."
                dashboard   = "${var.grafana_url}/d/919b92a8e8041bd567af9edab12c840c/kubernetes-persistent-volumes"
              }
            },
            # Service Endpoint Down
            {
              alert = "ServiceEndpointDown"
              expr  = "kube_endpoint_address_available == 0"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Service {{ $labels.namespace }}/{{ $labels.endpoint }} has no endpoints"
                description = "Service {{ $labels.namespace }}/{{ $labels.endpoint }} has no available endpoints for more than 5 minutes."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            }
          ]
        }
      ]
    }
  }
}

# ============================================================================
# Infrastructure Critical Alerts (Certificate, Longhorn, etcd, DB)
# ============================================================================

resource "kubernetes_manifest" "infrastructure_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "homelab-infrastructure-alerts"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"       = "alerting-rules"
        "app.kubernetes.io/managed-by" = "opentofu"
        "prometheus"                   = "kube-prometheus-stack"
        "release"                      = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        {
          name = "homelab-infrastructure-alerts"
          rules = [
            # Certificate Expiring Soon (< 7 days)
            {
              alert = "CertificateExpiringSoon"
              expr  = "certmanager_certificate_expiration_timestamp_seconds - time() < 604800"
              for   = "1h"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Certificate {{ $labels.name }} expires in less than 7 days"
                description = "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} will expire in {{ $value | humanizeDuration }}."
              }
            },
            # Certificate Expiring Critical (< 24 hours)
            {
              alert = "CertificateExpiringCritical"
              expr  = "certmanager_certificate_expiration_timestamp_seconds - time() < 86400"
              for   = "15m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Certificate {{ $labels.name }} expires in less than 24 hours"
                description = "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} will expire in {{ $value | humanizeDuration }}. Immediate action required!"
              }
            },
            # Certificate Ready Status False
            {
              alert = "CertificateNotReady"
              expr  = "certmanager_certificate_ready_status{condition=\"False\"} == 1"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Certificate {{ $labels.name }} is not ready"
                description = "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} has been in NotReady state for more than 15 minutes."
              }
            },
            # Longhorn Volume Space Low (< 20%)
            {
              alert = "LonghornVolumeSpaceLow"
              expr  = "(longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) * 100 > 80"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Longhorn volume {{ $labels.volume }} is running low on space"
                description = "Longhorn volume {{ $labels.volume }} is {{ printf \"%.1f\" $value }}% full. Consider expanding the volume."
              }
            },
            # Longhorn Volume Degraded
            {
              alert = "LonghornVolumeDegraded"
              expr  = "longhorn_volume_robustness == 2"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Longhorn volume {{ $labels.volume }} is degraded"
                description = "Longhorn volume {{ $labels.volume }} has degraded redundancy. Check replica status."
              }
            },
            # Longhorn Volume Faulted
            {
              alert = "LonghornVolumeFaulted"
              expr  = "longhorn_volume_robustness == 3"
              for   = "1m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Longhorn volume {{ $labels.volume }} is faulted"
                description = "Longhorn volume {{ $labels.volume }} is in faulted state. Data may be at risk!"
              }
            },
            # Longhorn Node Storage Low
            {
              alert = "LonghornNodeStorageLow"
              expr  = "(longhorn_node_storage_usage_bytes / longhorn_node_storage_capacity_bytes) * 100 > 80"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Longhorn node {{ $labels.node }} storage is low"
                description = "Longhorn node {{ $labels.node }} storage is {{ printf \"%.1f\" $value }}% used."
              }
            },
            # etcd High Commit Duration
            {
              alert = "EtcdHighCommitDuration"
              expr  = "histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m])) > 0.1"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "etcd high commit duration"
                description = "etcd commit duration p99 is {{ printf \"%.3f\" $value }}s (threshold 100ms). Check disk I/O."
              }
            },
            # etcd High fsync Duration
            {
              alert = "EtcdHighFsyncDuration"
              expr  = "histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.1"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "etcd high WAL fsync duration"
                description = "etcd WAL fsync duration p99 is {{ printf \"%.3f\" $value }}s. Disk performance may be degraded."
              }
            },
            # PostgreSQL Connections High
            {
              alert = "PostgreSQLConnectionsHigh"
              expr  = "pg_stat_activity_count / pg_settings_max_connections * 100 > 80"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "PostgreSQL connections above 80%"
                description = "PostgreSQL instance {{ $labels.instance }} has {{ printf \"%.0f\" $value }}% connections used."
              }
            },
            # PostgreSQL Down
            {
              alert = "PostgreSQLDown"
              expr  = "pg_up == 0"
              for   = "2m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "PostgreSQL instance down"
                description = "PostgreSQL instance {{ $labels.instance }} is not responding."
              }
            },
            # Redis Memory Usage High
            # NOTE: Condition redis_memory_max_bytes > 0 prevents division by zero
            # when Redis maxmemory is not configured (common in homelab setups)
            {
              alert = "RedisMemoryUsageHigh"
              expr  = "redis_memory_used_bytes / redis_memory_max_bytes * 100 > 80 and redis_memory_max_bytes > 0"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Redis memory usage above 80%"
                description = "Redis instance {{ $labels.instance }} memory is {{ printf \"%.1f\" $value }}% used."
              }
            },
            # Redis Down
            {
              alert = "RedisDown"
              expr  = "redis_up == 0"
              for   = "2m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Redis instance down"
                description = "Redis instance {{ $labels.instance }} is not responding."
              }
            },
            # Redis Rejected Connections
            {
              alert = "RedisRejectedConnections"
              expr  = "increase(redis_rejected_connections_total[5m]) > 0"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Redis rejecting connections"
                description = "Redis instance {{ $labels.instance }} rejected {{ printf \"%.0f\" $value }} connections in the last 5 minutes."
              }
            },
            # Velero Backup Failed
            # NOTE: Using increase() to detect new failures, not cumulative counter
            # This prevents continuous alerting after a single failure
            {
              alert = "VeleroBackupFailed"
              expr  = "increase(velero_backup_failure_total[15m]) > 0"
              for   = "0m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Velero backup failed"
                description = "Velero backup {{ $labels.schedule }} has failed. Check velero logs for details."
              }
            },
            # Velero Backup Not Run Recently
            {
              alert = "VeleroBackupStale"
              expr  = "time() - velero_backup_last_successful_timestamp > 90000"
              for   = "1h"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Velero backup is stale"
                description = "No successful Velero backup in the last 25 hours. Last backup was {{ $value | humanizeDuration }} ago."
              }
            }
          ]
        }
      ]
    }
  }
}

# ============================================================================
# Application Alerts (Traefik, MinIO)
# ============================================================================

resource "kubernetes_manifest" "application_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "homelab-application-alerts"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"       = "alerting-rules"
        "app.kubernetes.io/managed-by" = "opentofu"
        "prometheus"                   = "kube-prometheus-stack"
        "release"                      = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        # Traefik Alerts
        {
          name = "traefik-alerts"
          rules = [
            # Traefik Down
            {
              alert = "TraefikDown"
              expr  = "up{job=\"traefik\"} == 0"
              for   = "2m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Traefik ingress controller is down"
                description = "Traefik ingress controller has been unreachable for more than 2 minutes. All external traffic is affected."
                dashboard   = "${var.grafana_url}/d/traefik"
              }
            },
            # Traefik Config Reload Failed
            {
              alert = "TraefikConfigReloadFailed"
              expr  = "traefik_config_last_reload_success == 0"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Traefik configuration reload failed"
                description = "Traefik failed to reload its configuration. New routes may not be applied."
                dashboard   = "${var.grafana_url}/d/traefik"
              }
            },
            # Traefik High 5xx Error Rate
            {
              alert = "TraefikHigh5xxRate"
              expr  = "sum(rate(traefik_service_requests_total{code=~\"5..\"}[5m])) / sum(rate(traefik_service_requests_total[5m])) * 100 > 5"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High 5xx error rate in Traefik"
                description = "Traefik is returning {{ printf \"%.1f\" $value }}% 5xx errors. Check backend service health."
                dashboard   = "${var.grafana_url}/d/traefik"
              }
            },
            # Traefik TLS Certificate Expiring
            {
              alert = "TraefikTLSCertExpiring"
              expr  = "(traefik_tls_certs_not_after - time()) / 86400 < 7"
              for   = "1h"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Traefik TLS certificate expiring soon"
                description = "TLS certificate for {{ $labels.cn }} expires in {{ printf \"%.0f\" $value }} days."
                dashboard   = "${var.grafana_url}/d/traefik"
              }
            },
            # Traefik No Active Connections (potential issue)
            {
              alert = "TraefikNoConnections"
              expr  = "sum(traefik_open_connections) == 0"
              for   = "30m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Traefik has no active connections"
                description = "Traefik has had no active connections for 30 minutes. This may indicate network or DNS issues."
                dashboard   = "${var.grafana_url}/d/traefik"
              }
            }
          ]
        },
        # MinIO Alerts
        {
          name = "minio-alerts"
          rules = [
            # MinIO Down
            {
              alert = "MinIODown"
              expr  = "up{job=~\"minio.*\"} == 0"
              for   = "2m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "MinIO is down"
                description = "MinIO S3 storage service has been unreachable for more than 2 minutes."
              }
            },
            # MinIO Drive Offline
            {
              alert = "MinIODriveOffline"
              expr  = "minio_cluster_drive_offline_total > 0"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "MinIO has offline drives"
                description = "MinIO cluster has {{ $value }} offline drives. Data redundancy may be compromised."
              }
            },
            # MinIO Node Offline
            {
              alert = "MinIONodeOffline"
              expr  = "minio_cluster_nodes_offline_total > 0"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "MinIO node is offline"
                description = "MinIO cluster has {{ $value }} offline nodes. Check cluster health."
              }
            },
            # MinIO Storage Low (< 20% free)
            {
              alert = "MinIOStorageLow"
              expr  = "(minio_cluster_capacity_usable_free_bytes / minio_cluster_capacity_usable_total_bytes) * 100 < 20"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "MinIO storage running low"
                description = "MinIO cluster has only {{ printf \"%.1f\" $value }}% free usable storage."
              }
            },
            # MinIO Storage Critical (< 10% free)
            {
              alert = "MinIOStorageCritical"
              expr  = "(minio_cluster_capacity_usable_free_bytes / minio_cluster_capacity_usable_total_bytes) * 100 < 10"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "MinIO storage critically low"
                description = "MinIO cluster has only {{ printf \"%.1f\" $value }}% free usable storage. Immediate action required!"
              }
            },
            # MinIO High S3 Error Rate
            {
              alert = "MinIOHighErrorRate"
              expr  = "rate(minio_s3_requests_errors_total[5m]) / rate(minio_s3_requests_total[5m]) * 100 > 5"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "MinIO high S3 error rate"
                description = "MinIO is returning {{ printf \"%.1f\" $value }}% S3 errors. Check application logs."
              }
            }
          ]
        }
      ]
    }
  }
}
