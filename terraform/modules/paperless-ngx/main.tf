# Paperless-ngx Module - Main Resources
# Feature: 027-paperless-ngx

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
  }
}

# ============================================================================
# Namespace
# ============================================================================

resource "kubernetes_namespace" "paperless" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/managed-by" = "opentofu"
      "feature"                      = "027-paperless-ngx"
    }
  }
}

# ============================================================================
# Secrets
# ============================================================================

resource "kubernetes_secret" "paperless_credentials" {
  metadata {
    name      = "paperless-credentials"
    namespace = kubernetes_namespace.paperless.metadata[0].name

    labels = {
      "app.kubernetes.io/name" = var.app_name
    }
  }

  data = {
    PAPERLESS_SECRET_KEY     = var.secret_key
    PAPERLESS_DBPASS         = var.db_password
    PAPERLESS_ADMIN_USER     = var.admin_user
    PAPERLESS_ADMIN_PASSWORD = var.admin_password
    PAPERLESS_ADMIN_MAIL     = var.admin_email
  }

  type = "Opaque"
}

resource "kubernetes_secret" "samba_credentials" {
  metadata {
    name      = "samba-credentials"
    namespace = kubernetes_namespace.paperless.metadata[0].name

    labels = {
      "app.kubernetes.io/name" = var.app_name
    }
  }

  data = {
    SMB_USER     = var.samba_user
    SMB_PASSWORD = var.samba_password
  }

  type = "Opaque"
}

# ============================================================================
# PersistentVolumeClaims
# ============================================================================

resource "kubernetes_persistent_volume_claim" "data" {
  wait_until_bound = false # local-path binds on first pod mount

  metadata {
    name      = "${var.app_name}-data"
    namespace = kubernetes_namespace.paperless.metadata[0].name

    labels = {
      "app.kubernetes.io/name"      = var.app_name
      "app.kubernetes.io/component" = "data"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.data_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "media" {
  wait_until_bound = false

  metadata {
    name      = "${var.app_name}-media"
    namespace = kubernetes_namespace.paperless.metadata[0].name

    labels = {
      "app.kubernetes.io/name"      = var.app_name
      "app.kubernetes.io/component" = "media"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.media_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "consume" {
  wait_until_bound = false

  metadata {
    name      = "${var.app_name}-consume"
    namespace = kubernetes_namespace.paperless.metadata[0].name

    labels = {
      "app.kubernetes.io/name"      = var.app_name
      "app.kubernetes.io/component" = "consume"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.consume_storage_size
      }
    }
  }
}

# ============================================================================
# Deployment
# ============================================================================

resource "kubernetes_deployment" "paperless" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.paperless.metadata[0].name

    labels = {
      "app.kubernetes.io/name" = var.app_name
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate" # PVCs can only be mounted by one pod
    }

    selector {
      match_labels = {
        "app.kubernetes.io/name" = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = var.app_name
        }

        annotations = {
          "prometheus.io/scrape" = tostring(var.enable_metrics)
          "prometheus.io/port"   = tostring(var.service_port)
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        # Paperless-ngx main container
        container {
          name  = "paperless-ngx"
          image = var.image

          port {
            name           = "http"
            container_port = var.service_port
            protocol       = "TCP"
          }

          # Environment variables
          env {
            name  = "PAPERLESS_URL"
            value = "https://${var.public_host}"
          }

          env {
            name  = "PAPERLESS_DBHOST"
            value = var.db_host
          }

          env {
            name  = "PAPERLESS_DBPORT"
            value = tostring(var.db_port)
          }

          env {
            name  = "PAPERLESS_DBNAME"
            value = var.db_name
          }

          env {
            name  = "PAPERLESS_DBUSER"
            value = var.db_user
          }

          env {
            name = "PAPERLESS_DBPASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.paperless_credentials.metadata[0].name
                key  = "PAPERLESS_DBPASS"
              }
            }
          }

          env {
            name  = "PAPERLESS_REDIS"
            value = var.redis_url
          }

          env {
            name = "PAPERLESS_SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.paperless_credentials.metadata[0].name
                key  = "PAPERLESS_SECRET_KEY"
              }
            }
          }

          env {
            name = "PAPERLESS_ADMIN_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.paperless_credentials.metadata[0].name
                key  = "PAPERLESS_ADMIN_USER"
              }
            }
          }

          env {
            name = "PAPERLESS_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.paperless_credentials.metadata[0].name
                key  = "PAPERLESS_ADMIN_PASSWORD"
              }
            }
          }

          env {
            name = "PAPERLESS_ADMIN_MAIL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.paperless_credentials.metadata[0].name
                key  = "PAPERLESS_ADMIN_MAIL"
              }
            }
          }

          env {
            name  = "PAPERLESS_OCR_LANGUAGE"
            value = var.ocr_language
          }

          env {
            name  = "PAPERLESS_TIME_ZONE"
            value = var.timezone
          }

          env {
            name  = "PAPERLESS_CONSUMPTION_DIR"
            value = "/usr/src/paperless/consume"
          }

          env {
            name  = "PAPERLESS_DATA_DIR"
            value = "/usr/src/paperless/data"
          }

          env {
            name  = "PAPERLESS_MEDIA_ROOT"
            value = "/usr/src/paperless/media"
          }

          env {
            name  = "PAPERLESS_ENABLE_HTTP_REMOTE_USER"
            value = "false"
          }

          env {
            name  = "PAPERLESS_ENABLE_UPDATE_CHECK"
            value = "false"
          }

          env {
            name  = "PAPERLESS_ENABLE_METRICS"
            value = tostring(var.enable_metrics)
          }

          # Volume mounts
          volume_mount {
            name       = "data"
            mount_path = "/usr/src/paperless/data"
          }

          volume_mount {
            name       = "media"
            mount_path = "/usr/src/paperless/media"
          }

          volume_mount {
            name       = "consume"
            mount_path = "/usr/src/paperless/consume"
          }

          # Resource limits
          resources {
            requests = {
              memory = var.resources.requests.memory
              cpu    = var.resources.requests.cpu
            }
            limits = {
              memory = var.resources.limits.memory
              cpu    = var.resources.limits.cpu
            }
          }

          # Health probes
          liveness_probe {
            http_get {
              path = "/api/"
              port = var.service_port
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/api/"
              port = var.service_port
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          security_context {
            privileged = false
          }
        }

        # Samba sidecar container
        container {
          name  = "samba"
          image = var.samba_image

          port {
            name           = "smb"
            container_port = 445
            protocol       = "TCP"
          }

          # Samba configuration via environment
          env {
            name = "SMB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.samba_credentials.metadata[0].name
                key  = "SMB_USER"
              }
            }
          }

          env {
            name = "SMB_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.samba_credentials.metadata[0].name
                key  = "SMB_PASSWORD"
              }
            }
          }

          # Share consume folder
          volume_mount {
            name       = "consume"
            mount_path = "/share/consume"
          }

          # Command to configure Samba share using env vars
          command = ["/bin/bash", "-c"]
          args = [
            <<-EOT
            samba.sh -s "${var.samba_share_name};/share/consume;yes;no;no;$SMB_USER;$SMB_USER" \
                     -u "$SMB_USER;$SMB_PASS" \
                     -p
            EOT
          ]

          # Resource limits
          resources {
            requests = {
              memory = var.samba_resources.requests.memory
              cpu    = var.samba_resources.requests.cpu
            }
            limits = {
              memory = var.samba_resources.limits.memory
              cpu    = var.samba_resources.limits.cpu
            }
          }

          security_context {
            privileged = false
          }
        }

        # Volumes
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.data.metadata[0].name
          }
        }

        volume {
          name = "media"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.media.metadata[0].name
          }
        }

        volume {
          name = "consume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.consume.metadata[0].name
          }
        }

        restart_policy = "Always"
      }
    }
  }
}

# ============================================================================
# Services
# ============================================================================

resource "kubernetes_service" "paperless" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.paperless.metadata[0].name

    labels = {
      "app.kubernetes.io/name" = var.app_name
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "http"
      port        = var.service_port
      target_port = var.service_port
      protocol    = "TCP"
    }

    selector = {
      "app.kubernetes.io/name" = var.app_name
    }
  }
}

resource "kubernetes_service" "samba" {
  metadata {
    name      = "samba-smb"
    namespace = kubernetes_namespace.paperless.metadata[0].name

    labels = {
      "app.kubernetes.io/name"      = var.app_name
      "app.kubernetes.io/component" = "samba"
    }

    annotations = {
      # Disable K3s ServiceLB for MetalLB
      "svccontroller.k3s.cattle.io/enablelb" = "false"
    }
  }

  spec {
    type = "LoadBalancer"

    port {
      name        = "smb"
      port        = 445
      target_port = 445
      protocol    = "TCP"
    }

    selector = {
      "app.kubernetes.io/name" = var.app_name
    }
  }
}

# ============================================================================
# ServiceMonitor for Prometheus
# ============================================================================

resource "kubernetes_manifest" "service_monitor" {
  count = var.create_service_monitor ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = var.app_name
      namespace = kubernetes_namespace.paperless.metadata[0].name
      labels = {
        "app.kubernetes.io/name" = var.app_name
        "release"                = "kube-prometheus-stack"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = var.app_name
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
}

# ============================================================================
# PrometheusRule for Alerts
# ============================================================================

resource "kubernetes_manifest" "prometheus_rule" {
  count = var.create_service_monitor ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "${var.app_name}-alerts"
      namespace = kubernetes_namespace.paperless.metadata[0].name
      labels = {
        "app.kubernetes.io/name" = var.app_name
        "release"                = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        {
          name = "paperless.rules"
          rules = [
            {
              alert = "PaperlessDown"
              expr  = "up{job=\"${var.app_name}\"} == 0"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Paperless-ngx is down"
                description = "Paperless-ngx has been unreachable for more than 5 minutes."
              }
            },
            {
              alert = "PaperlessHighMemory"
              expr  = "container_memory_usage_bytes{namespace=\"${var.namespace}\",container=\"paperless-ngx\"} / container_spec_memory_limit_bytes{namespace=\"${var.namespace}\",container=\"paperless-ngx\"} > 0.9"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Paperless-ngx high memory usage"
                description = "Paperless-ngx is using more than 90% of its memory limit for over 10 minutes."
              }
            }
          ]
        }
      ]
    }
  }
}
