# ============================================================================
# Longhorn Distributed Block Storage Module
# ============================================================================
# This module deploys Longhorn v1.5.x to provide distributed block storage
# across the K3s cluster with configurable replica count and USB disk support.
# ============================================================================

# Longhorn Helm Release
resource "helm_release" "longhorn" {
  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = "~> 1.5.0"
  namespace  = "longhorn-system"

  create_namespace = true

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600 # 10 minutes

  # Helm values configuration
  values = [
    yamlencode({
      # Persistence settings
      persistence = {
        defaultClass          = true
        defaultClassReplicaCount = var.replica_count
      }

      # Default settings for Longhorn
      defaultSettings = {
        # Replica configuration
        defaultReplicaCount = var.replica_count

        # Use USB disk on master1 as primary storage
        # This will be configured via node disk configuration
        # Longhorn will discover available disks on each node

        # Backup configuration (will be set later via MinIO integration)
        backupTarget = ""
        backupTargetCredentialSecret = ""

        # Storage reservation (reserve configured percentage for system)
        storageReservedPercentageForDefaultDisk = var.storage_reserved_percentage

        # Enable auto-salvage for degraded volumes
        autoSalvage = true

        # Replica placement
        replicaAutoBalance = "best-effort"
      }

      # Service configuration for Longhorn UI
      service = {
        ui = {
          type = "ClusterIP"
          port = 80
        }
      }

      # Resource limits for Longhorn components
      resources = {
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
      }

      # Enable Prometheus metrics
      metrics = {
        serviceMonitor = {
          enabled = var.enable_metrics
        }
      }
    })
  ]

  # Ensure Longhorn is deployed after namespace is ready
  depends_on = []
}

# StorageClass for Longhorn (explicit definition for clarity)
resource "kubernetes_storage_class_v1" "longhorn" {
  metadata {
    name = var.storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "driver.longhorn.io"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"

  parameters = {
    numberOfReplicas    = tostring(var.replica_count)
    staleReplicaTimeout = "30"
    fromBackup          = ""
    fsType              = "ext4"
    dataLocality        = "disabled"
  }

  depends_on = [helm_release.longhorn]
}
