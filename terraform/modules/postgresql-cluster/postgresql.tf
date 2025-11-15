# PostgreSQL Cluster Module - PostgreSQL Helm Chart Configuration
# Feature 011: PostgreSQL Cluster Database Service
#
# Configures Bitnami PostgreSQL Helm chart with primary and read replicas
# Uses standard postgresql chart instead of postgresql-ha due to image availability
# Tasks: T015-T021

# ==============================================================================
# PostgreSQL HA Helm Release
# ==============================================================================

resource "helm_release" "postgresql" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = "postgresql"  # Using standard chart instead of postgresql-ha due to image availability
  version    = var.chart_version
  namespace  = var.namespace

  wait             = true
  timeout          = var.helm_timeout
  create_namespace = false # Namespace already created in Phase 1: Setup

  # ==============================================================================
  # Helm Values Configuration
  # ==============================================================================

  values = [
    yamlencode({
      # ========================================================================
      # Architecture - must be "replication" for read replicas
      # ========================================================================
      architecture = "replication"

      # ========================================================================
      # Authentication Configuration
      # ========================================================================
      auth = {
        postgresPassword = ""  # Will use existingSecret
        username         = "app_user"
        password         = ""  # Will use existingSecret
        database         = "app_db"
        existingSecret   = kubernetes_secret.postgresql_credentials.metadata[0].name
        secretKeys = {
          adminPasswordKey      = "postgres-password"
          userPasswordKey       = "password"
          replicationPasswordKey = "replication-password"
        }
      }

      # ========================================================================
      # Primary PostgreSQL Instance Configuration
      # ========================================================================
      primary = {
        # T019: PersistentVolumeClaim configuration (50Gi)
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }

        # T020: Resource limits (2 CPU, 4GB RAM)
        resources = {
          limits = {
            cpu    = var.resources_limits_cpu
            memory = var.resources_limits_memory
          }
          requests = {
            cpu    = var.resources_requests_cpu
            memory = var.resources_requests_memory
          }
        }

        # Pod labels
        podLabels = local.common_labels

        # Service configuration for external access
        service = {
          type = var.enable_external_access ? "LoadBalancer" : "ClusterIP"
          annotations = var.enable_external_access ? {
            "metallb.universe.tf/address-pool" = var.metallb_ip_pool
          } : {}
        }
      }

      # ========================================================================
      # Read Replicas for High Availability
      # ========================================================================
      readReplicas = {
        # T017: Enable read replicas (replica_count - 1, since 1 is primary)
        replicaCount = var.replica_count - 1

        # T019: PersistentVolumeClaim configuration (50Gi per replica)
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }

        # T020: Resource limits (2 CPU, 4GB RAM per replica)
        resources = {
          limits = {
            cpu    = var.resources_limits_cpu
            memory = var.resources_limits_memory
          }
          requests = {
            cpu    = var.resources_requests_cpu
            memory = var.resources_requests_memory
          }
        }

        # Pod labels
        podLabels = local.common_labels
      }

      # ========================================================================
      # PostgreSQL Exporter for Prometheus Metrics
      # ========================================================================
      metrics = {
        enabled = var.enable_metrics

        # Resource limits for metrics exporter
        resources = {
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }

        # ServiceMonitor for Prometheus Operator
        serviceMonitor = {
          enabled   = var.enable_service_monitor
          namespace = var.namespace
          interval  = "30s"
          labels    = local.common_labels
        }
      }

      # ========================================================================
      # Volume Permissions Init Container
      # ========================================================================
      # Disabled for local-path storage which handles permissions automatically
      volumePermissions = {
        enabled = false
      }
    })
  ]

  # Ensure secrets are created before Helm release
  depends_on = [
    kubernetes_secret.postgresql_credentials
  ]
}
