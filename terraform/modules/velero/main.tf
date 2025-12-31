# ============================================================================
# Velero Backup Module
# ============================================================================
# Deploys Velero for Kubernetes cluster backups with MinIO as S3 backend
# Includes daily scheduled backups with 7-day retention
# ============================================================================

# Namespace for Velero
resource "kubernetes_namespace" "velero" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "velero"
      "app.kubernetes.io/part-of" = "backup-infrastructure"
    }
  }
}

# Job to create the velero bucket in MinIO
resource "kubernetes_job" "create_velero_bucket" {
  metadata {
    name      = "create-velero-bucket"
    namespace = kubernetes_namespace.velero.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "velero-bucket-creator"
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "mc"
          image = var.minio_client_image

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOF
            mc alias set minio ${var.minio_url} ${var.minio_access_key} ${var.minio_secret_key} --insecure
            mc mb minio/${var.velero_bucket_name} --ignore-existing --insecure
            mc anonymous set download minio/${var.velero_bucket_name} --insecure || true
            echo "Bucket ${var.velero_bucket_name} created successfully"
            EOF
          ]
        }
      }
    }

    backoff_limit = 4
  }

  wait_for_completion = true

  timeouts {
    create = "5m"
  }
}

# Velero Helm Release
resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = var.velero_chart_version
  namespace  = kubernetes_namespace.velero.metadata[0].name

  values = [
    yamlencode({
      initContainers = [
        {
          name            = "velero-plugin-for-aws"
          image           = var.velero_aws_plugin_image
          imagePullPolicy = "IfNotPresent"
          volumeMounts = [
            {
              mountPath = "/target"
              name      = "plugins"
            }
          ]
        }
      ]

      configuration = {
        backupStorageLocation = [
          {
            name     = "default"
            provider = "aws"
            bucket   = var.velero_bucket_name
            default  = true
            config = {
              region           = "us-east-1"
              s3ForcePathStyle = "true"
              s3Url            = var.minio_url
              insecureSkipTLSVerify = "true"
            }
          }
        ]

        volumeSnapshotLocation = []

        defaultBackupStorageLocation = "default"
        defaultVolumeSnapshotLocations = {}

        features = "EnableCSI"
      }

      credentials = {
        useSecret = true
        # Let the chart create the secret with credentials and extra env vars
        secretContents = {
          cloud = <<-EOF
[default]
aws_access_key_id = ${var.minio_access_key}
aws_secret_access_key = ${var.minio_secret_key}
EOF
        }
        # Extra env vars as key=value pairs (added to secret and loaded as env vars)
        extraEnvVars = {
          AWS_EC2_METADATA_DISABLED    = "true"
          AWS_ACCESS_KEY_ID            = var.minio_access_key
          AWS_SECRET_ACCESS_KEY        = var.minio_secret_key
        }
      }

      snapshotsEnabled = false

      deployNodeAgent = var.enable_node_agent

      nodeAgent = {
        podVolumePath = "/var/lib/kubelet/pods"
        privileged    = true
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      resources = {
        requests = {
          cpu    = var.resource_requests_cpu
          memory = var.resource_requests_memory
        }
        limits = {
          cpu    = var.resource_limits_cpu
          memory = var.resource_limits_memory
        }
      }

      schedules = {
        daily-backup = {
          disabled = false
          schedule = var.backup_schedule
          useOwnerReferencesInBackup = false
          template = {
            ttl                    = var.backup_ttl
            includedNamespaces     = var.included_namespaces
            excludedNamespaces     = var.excluded_namespaces
            includedResources      = ["*"]
            excludedResources      = []
            includeClusterResources = true
            snapshotVolumes        = false
            storageLocation        = "default"
            defaultVolumesToFsBackup = var.enable_node_agent
          }
        }
      }

      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = var.enable_service_monitor
        }
      }

      # Use official kubectl image instead of bitnami (licensing issues)
      kubectl = {
        image = {
          repository = "docker.io/rancher/kubectl"
          tag        = "v1.31.4"
        }
      }

      # Disable CRD upgrade job (we'll manage CRDs separately if needed)
      upgradeCRDs = false
    })
  ]

  depends_on = [
    kubernetes_job.create_velero_bucket
  ]
}
