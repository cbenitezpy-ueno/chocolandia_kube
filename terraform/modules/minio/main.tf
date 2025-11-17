# ============================================================================
# MinIO S3-Compatible Object Storage Module
# ============================================================================
# Deploys MinIO in single-server mode (1 replica) with 100Gi Longhorn volume
# for S3-compatible object storage and backup capabilities
# ============================================================================

# Namespace for MinIO
resource "kubernetes_namespace" "minio" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "minio"
      "app.kubernetes.io/part-of" = "storage-infrastructure"
    }
  }
}

# Generate random credentials for MinIO
resource "random_password" "minio_root_user" {
  length  = 20
  special = false
}

resource "random_password" "minio_root_password" {
  length  = 32
  special = true
}

# Kubernetes Secret for MinIO credentials
resource "kubernetes_secret" "minio_credentials" {
  metadata {
    name      = "minio-credentials"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  data = {
    rootUser     = random_password.minio_root_user.result
    rootPassword = random_password.minio_root_password.result
  }

  type = "Opaque"
}

# PersistentVolumeClaim for MinIO data storage
resource "kubernetes_persistent_volume_claim" "minio_data" {
  metadata {
    name      = "minio-data"
    namespace = kubernetes_namespace.minio.metadata[0].name
    labels = {
      "app" = "minio"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }

  wait_until_bound = false
}

# MinIO Deployment
resource "kubernetes_deployment" "minio" {
  metadata {
    name      = "minio"
    namespace = kubernetes_namespace.minio.metadata[0].name
    labels = {
      "app"                       = "minio"
      "app.kubernetes.io/name"    = "minio"
      "app.kubernetes.io/version" = "RELEASE.2024-01-01T16-36-33Z"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app" = "minio"
      }
    }

    template {
      metadata {
        labels = {
          "app"                       = "minio"
          "app.kubernetes.io/name"    = "minio"
          "app.kubernetes.io/version" = "RELEASE.2024-01-01T16-36-33Z"
        }
      }

      spec {
        container {
          name  = "minio"
          image = "quay.io/minio/minio:RELEASE.2024-01-01T16-36-33Z"

          args = [
            "server",
            "/data",
            "--console-address",
            ":9001"
          ]

          env {
            name = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_credentials.metadata[0].name
                key  = "rootUser"
              }
            }
          }

          env {
            name = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_credentials.metadata[0].name
                key  = "rootPassword"
              }
            }
          }

          env {
            name  = "MINIO_PROMETHEUS_AUTH_TYPE"
            value = "public"
          }

          port {
            name           = "api"
            container_port = 9000
            protocol       = "TCP"
          }

          port {
            name           = "console"
            container_port = 9001
            protocol       = "TCP"
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          liveness_probe {
            http_get {
              path   = "/minio/health/live"
              port   = 9000
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/minio/health/ready"
              port   = 9000
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = var.resource_requests_cpu
              memory = var.resource_requests_memory
            }
            limits = {
              cpu    = var.resource_limits_cpu
              memory = var.resource_limits_memory
            }
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.minio_data.metadata[0].name
          }
        }

        # Security context
        security_context {
          fs_group = 1000
        }
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim.minio_data
  ]
}

# MinIO Service - S3 API (port 9000)
resource "kubernetes_service" "minio_api" {
  metadata {
    name      = "minio-api"
    namespace = kubernetes_namespace.minio.metadata[0].name
    labels = {
      "app" = "minio"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app" = "minio"
    }

    port {
      name        = "api"
      port        = 9000
      target_port = 9000
      protocol    = "TCP"
    }
  }
}

# MinIO Service - Console (port 9001)
resource "kubernetes_service" "minio_console" {
  metadata {
    name      = "minio-console"
    namespace = kubernetes_namespace.minio.metadata[0].name
    labels = {
      "app" = "minio"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app" = "minio"
    }

    port {
      name        = "console"
      port        = 9001
      target_port = 9001
      protocol    = "TCP"
    }
  }
}
