# ============================================================================
# Loki Log Aggregation Module
# ============================================================================
# Deploys Grafana Loki for centralized log aggregation with Promtail
# for log collection from all cluster nodes
# ============================================================================

# Helm Release for Loki Stack (Loki + Promtail)
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.loki_stack_version
  namespace  = var.namespace

  create_namespace = true

  values = [
    yamlencode({
      loki = {
        enabled = true

        persistence = {
          enabled          = var.persistence_enabled
          size             = var.persistence_size
          storageClassName = var.storage_class_name
        }

        config = {
          auth_enabled = false

          ingester = {
            chunk_idle_period   = "3m"
            chunk_block_size    = 262144
            chunk_retain_period = "1m"
            max_transfer_retries = 0
            lifecycler = {
              ring = {
                replication_factor = 1
              }
            }
          }

          limits_config = {
            enforce_metric_name         = false
            reject_old_samples          = true
            reject_old_samples_max_age  = "168h"
            ingestion_rate_mb           = 16
            ingestion_burst_size_mb     = 24
            max_streams_per_user        = 10000
            max_entries_limit_per_query = 5000
          }

          schema_config = {
            configs = [
              {
                from         = "2020-10-24"
                store        = "boltdb-shipper"
                object_store = "filesystem"
                schema       = "v11"
                index = {
                  prefix = "index_"
                  period = "24h"
                }
              }
            ]
          }

          storage_config = {
            boltdb_shipper = {
              active_index_directory = "/data/loki/boltdb-shipper-active"
              cache_location         = "/data/loki/boltdb-shipper-cache"
              cache_ttl              = "24h"
              shared_store           = "filesystem"
            }
            filesystem = {
              directory = "/data/loki/chunks"
            }
          }

          chunk_store_config = {
            max_look_back_period = "0s"
          }

          table_manager = {
            retention_deletes_enabled = true
            retention_period          = var.retention_period
          }

          compactor = {
            working_directory       = "/data/loki/boltdb-shipper-compactor"
            shared_store            = "filesystem"
            compaction_interval     = "10m"
            retention_enabled       = true
            retention_delete_delay  = "2h"
            retention_delete_worker_count = 150
          }
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

        serviceMonitor = {
          enabled = var.enable_service_monitor
        }
      }

      promtail = {
        enabled = true

        config = {
          clients = [
            {
              url = "http://loki:3100/loki/api/v1/push"
            }
          ]

          snippets = {
            pipelineStages = [
              {
                cri = {}
              }
            ]
          }
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
      }

      # Disable grafana in loki-stack (we already have one)
      grafana = {
        enabled = false
      }

      # Disable prometheus in loki-stack (we already have one)
      prometheus = {
        enabled = false
      }
    })
  ]
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
