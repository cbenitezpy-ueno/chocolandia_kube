# Redis Shared - Main Helm Release Configuration
# Deploys Bitnami Redis Helm chart with primary-replica architecture

# ==============================================================================
# Redis Helm Release
# ==============================================================================

resource "helm_release" "redis" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = "redis"
  version    = var.chart_version
  namespace  = kubernetes_namespace.redis.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = var.helm_timeout
  atomic        = true # Rollback on failure

  # ==============================================================================
  # Helm Values Configuration
  # ==============================================================================

  values = [
    yamlencode({
      # Architecture: Primary-Replica (no Sentinel)
      architecture = "replication"

      # ===========================================================================
      # Authentication
      # ===========================================================================
      auth = {
        enabled        = true
        existingSecret = kubernetes_secret.redis_credentials.metadata[0].name
        password       = "" # Uses existingSecret
      }

      # ===========================================================================
      # Primary Instance Configuration
      # ===========================================================================
      master = {
        count = 1

        # Persistence
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }

        # Resource Limits
        resources = {
          requests = {
            cpu    = var.master_cpu_request
            memory = var.master_memory_request
          }
          limits = {
            cpu    = var.master_cpu_limit
            memory = var.master_memory_limit
          }
        }

        # Service Type
        service = {
          type = "ClusterIP"
        }

        # Health Checks
        livenessProbe = {
          enabled             = true
          initialDelaySeconds = 20
          periodSeconds       = 5
          timeoutSeconds      = 5
          failureThreshold    = 5
          successThreshold    = 1
        }

        readinessProbe = {
          enabled             = true
          initialDelaySeconds = 20
          periodSeconds       = 5
          timeoutSeconds      = 1
          failureThreshold    = 5
          successThreshold    = 1
        }

        # Labels for Monitoring
        podLabels = merge(
          local.common_labels,
          {
            "app.kubernetes.io/component" = "master"
          }
        )

        # Annotations
        podAnnotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8080"
        }
      }

      # ===========================================================================
      # Replica Configuration
      # ===========================================================================
      replica = {
        replicaCount = var.replica_count

        # Persistence
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }

        # Resource Limits
        resources = {
          requests = {
            cpu    = var.replica_cpu_request
            memory = var.replica_memory_request
          }
          limits = {
            cpu    = var.replica_cpu_limit
            memory = var.replica_memory_limit
          }
        }

        # Health Checks
        livenessProbe = {
          enabled             = true
          initialDelaySeconds = 20
          periodSeconds       = 5
          timeoutSeconds      = 5
          failureThreshold    = 5
          successThreshold    = 1
        }

        readinessProbe = {
          enabled             = true
          initialDelaySeconds = 20
          periodSeconds       = 5
          timeoutSeconds      = 1
          failureThreshold    = 5
          successThreshold    = 1
        }

        # Labels for Monitoring
        podLabels = merge(
          local.common_labels,
          {
            "app.kubernetes.io/component" = "replica"
          }
        )

        # Annotations
        podAnnotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8080"
        }
      }

      # ===========================================================================
      # Prometheus Metrics Exporter
      # ===========================================================================
      metrics = {
        enabled = var.enable_metrics

        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }

        # ServiceMonitor for Prometheus Operator
        serviceMonitor = {
          enabled   = var.enable_service_monitor
          namespace = var.monitoring_namespace
          interval  = "30s"
          labels = {
            release = "kube-prometheus-stack"
          }
        }
      }

      # ===========================================================================
      # Redis Configuration
      # ===========================================================================
      commonConfiguration = var.redis_config

      # Disable dangerous commands
      disableCommands = var.disable_commands

      # ===========================================================================
      # Security
      # ===========================================================================
      volumePermissions = {
        enabled = false # Not needed for local-path-provisioner
      }

      # Pod Security Context
      podSecurityContext = {
        enabled = true
        fsGroup = 1001
      }

      containerSecurityContext = {
        enabled   = true
        runAsUser = 1001
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.redis,
    kubernetes_secret.redis_credentials,
    kubernetes_secret.redis_credentials_replica
  ]
}
