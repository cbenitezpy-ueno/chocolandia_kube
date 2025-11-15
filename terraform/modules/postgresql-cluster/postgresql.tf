# PostgreSQL Cluster Module - PostgreSQL HA Helm Chart Configuration
# Feature 011: PostgreSQL Cluster Database Service
#
# Configures Bitnami PostgreSQL HA Helm chart with primary-replica topology
# Tasks: T015-T021

# ==============================================================================
# PostgreSQL HA Helm Release
# ==============================================================================

resource "helm_release" "postgresql" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = "postgresql-ha"
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
      # Global Configuration
      # ========================================================================
      global = {
        # T016: PostgreSQL version 16.x
        postgresql = {
          version = var.postgresql_version
        }
      }

      # ========================================================================
      # PostgreSQL Primary and Replica Configuration
      # ========================================================================
      postgresql = {
        # T017: Primary-replica topology (replicaCount includes primary + replicas)
        # For HA: 1 primary + (replicaCount - 1) replicas
        replicaCount = var.replica_count

        # T018: Asynchronous replication mode
        replication = {
          enabled          = true
          synchronousCommit = var.replication_mode == "sync" ? "on" : "off"
          numSynchronousReplicas = var.replication_mode == "sync" ? 1 : 0
        }

        # Authentication - use existing secret created in secrets.tf
        existingSecret = kubernetes_secret.postgresql_credentials.metadata[0].name

        # Password keys in the secret
        secretKeys = {
          adminPasswordKey      = "postgres-password"
          replicationPasswordKey = "replication-password"
        }

        # T019: PersistentVolumeClaim configuration (50Gi per instance)
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }

        # T020: Resource limits (2 CPU, 4GB RAM per pod)
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

        # T021: Readiness and liveness probes
        livenessProbe = {
          enabled             = true
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 6
          successThreshold    = 1
        }

        readinessProbe = {
          enabled             = true
          initialDelaySeconds = 5
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 6
          successThreshold    = 1
        }

        # Startup probe for initial container startup
        startupProbe = {
          enabled             = true
          initialDelaySeconds = 0
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 15
          successThreshold    = 1
        }

        # Pod labels
        podLabels = local.common_labels

        # Pod affinity - spread replicas across nodes for HA
        podAntiAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name"     = "postgresql"
                    "app.kubernetes.io/instance" = var.release_name
                  }
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }
          ]
        }
      }

      # ========================================================================
      # Pgpool Configuration (Connection Pooling and Load Balancing)
      # ========================================================================
      pgpool = {
        # Enable Pgpool for connection pooling and read/write splitting
        enabled = true

        # Single Pgpool instance (sufficient for homelab)
        replicaCount = 1

        # Use existing secret for Pgpool admin password
        existingSecret = kubernetes_secret.postgresql_credentials.metadata[0].name
        secretKeys = {
          adminPasswordKey = "postgres-password"
        }

        # Resource limits for Pgpool
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }

        # Health probes
        livenessProbe = {
          enabled             = true
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 5
          successThreshold    = 1
        }

        readinessProbe = {
          enabled             = true
          initialDelaySeconds = 5
          periodSeconds       = 5
          timeoutSeconds      = 5
          failureThreshold    = 5
          successThreshold    = 1
        }
      }

      # ========================================================================
      # PostgreSQL Exporter for Prometheus Metrics
      # ========================================================================
      metrics = {
        enabled = var.enable_metrics

        # PostgreSQL Exporter configuration
        image = {
          registry   = "docker.io"
          repository = "bitnami/postgres-exporter"
          tag        = "latest"
        }

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
      # Service Configuration
      # ========================================================================
      service = {
        # ClusterIP service for cluster-internal access
        type = "ClusterIP"
        ports = {
          postgresql = local.postgresql_port
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
