# ============================================================================
# Loki Log Aggregation Module (Loki 3.x)
# ============================================================================
# Deploys Grafana Loki 3.x in SingleBinary mode with Promtail
# for log collection from all cluster nodes
# ============================================================================

# Namespace for Loki
resource "kubernetes_namespace" "loki" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "loki"
      "app.kubernetes.io/part-of" = "logging-infrastructure"
    }
  }
}

# Helm Release for Loki 3.x (SingleBinary mode)
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_chart_version
  namespace  = kubernetes_namespace.loki.metadata[0].name

  values = [
    yamlencode({
      # SingleBinary mode for homelab (no object storage required)
      deploymentMode = "SingleBinary"

      loki = {
        auth_enabled = false

        # Common config for Loki 3.x
        commonConfig = {
          replication_factor = 1
        }

        # Storage config - filesystem for SingleBinary
        storage = {
          type = "filesystem"
        }

        # Schema config for Loki 3.x
        schemaConfig = {
          configs = [
            {
              from         = "2024-01-01"
              store        = "tsdb"
              object_store = "filesystem"
              schema       = "v13"
              index = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }

        # Limits config with volume_enabled for Grafana
        limits_config = {
          reject_old_samples            = true
          reject_old_samples_max_age    = "168h"
          ingestion_rate_mb             = 16
          ingestion_burst_size_mb       = 24
          max_streams_per_user          = 10000
          max_entries_limit_per_query   = 5000
          volume_enabled                = true
        }

        # Retention via compactor (filesystem for SingleBinary)
        compactor = {
          retention_enabled         = true
          delete_request_store      = "filesystem"
          working_directory         = "/var/loki/compactor"
          compaction_interval       = "10m"
          retention_delete_delay    = "2h"
          retention_delete_worker_count = 150
        }

        # Query scheduler for better performance
        query_scheduler = {
          max_outstanding_requests_per_tenant = 2048
        }
      }

      # SingleBinary configuration
      singleBinary = {
        replicas = 1

        persistence = {
          enabled          = var.persistence_enabled
          size             = var.persistence_size
          storageClassName = var.storage_class_name
        }

        resources = {
          requests = {
            cpu    = var.loki_resources_requests_cpu
            memory = var.loki_resources_requests_memory
          }
          limits = {
            cpu    = var.loki_resources_limits_cpu
            memory = var.loki_resources_limits_memory
          }
        }
      }

      # Disable other deployment modes
      read = {
        replicas = 0
      }
      write = {
        replicas = 0
      }
      backend = {
        replicas = 0
      }

      # Disable gateway (not needed for SingleBinary)
      gateway = {
        enabled = false
      }

      # Disable chunksCache and resultsCache for SingleBinary
      chunksCache = {
        enabled = false
      }
      resultsCache = {
        enabled = false
      }

      # Disable minio (we use filesystem)
      minio = {
        enabled = false
      }

      # Enable ServiceMonitor for Prometheus
      serviceMonitor = {
        enabled = var.enable_service_monitor
      }

      # Retention period
      tableManager = {
        retention_deletes_enabled = true
        retention_period          = var.retention_period
      }

      # Test disabled
      test = {
        enabled = false
      }

      # Lokicanary disabled
      lokiCanary = {
        enabled = false
      }
    })
  ]

  timeout = 600
}

# Helm Release for Promtail (log collector)
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = var.promtail_chart_version
  namespace  = kubernetes_namespace.loki.metadata[0].name

  values = [
    yamlencode({
      config = {
        clients = [
          {
            url = "http://loki:3100/loki/api/v1/push"
          }
        ]
      }

      resources = {
        requests = {
          cpu    = var.promtail_resources_requests_cpu
          memory = var.promtail_resources_requests_memory
        }
        limits = {
          cpu    = var.promtail_resources_limits_cpu
          memory = var.promtail_resources_limits_memory
        }
      }

      serviceMonitor = {
        enabled = var.enable_service_monitor
      }
    })
  ]

  depends_on = [helm_release.loki]
}

# Add Loki as datasource to existing Grafana
resource "kubernetes_config_map" "grafana_loki_datasource" {
  metadata {
    name      = "grafana-loki-datasource"
    namespace = var.grafana_namespace
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki-datasource.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name      = "Loki"
          type      = "loki"
          access    = "proxy"
          url       = "http://loki.${var.namespace}.svc.cluster.local:3100"
          isDefault = false
          editable  = true
        }
      ]
    })
  }
}
