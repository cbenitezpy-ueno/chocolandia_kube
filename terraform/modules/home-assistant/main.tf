# Home Assistant Module - Main Resources
# Feature: 018-home-assistant
# Scope: Phase 1 - Base Installation + Prometheus Integration

# ============================================================================
# Namespace
# ============================================================================

resource "kubernetes_namespace" "home_assistant" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"    = var.app_name
      "app.kubernetes.io/part-of" = "homelab"
    }
  }
}

# ============================================================================
# PersistentVolumeClaim for Home Assistant config
# ============================================================================

resource "kubernetes_persistent_volume_claim" "home_assistant_config" {
  wait_until_bound = false # local-path binds on first pod mount

  metadata {
    name      = "${var.app_name}-config"
    namespace = kubernetes_namespace.home_assistant.metadata[0].name

    labels = {
      "app.kubernetes.io/name" = var.app_name
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

# ============================================================================
# Deployment
# ============================================================================

resource "kubernetes_deployment" "home_assistant" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.home_assistant.metadata[0].name

    labels = {
      "app.kubernetes.io/name" = var.app_name
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate" # PVC can only be mounted by one pod
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
      }

      spec {
        container {
          name  = var.app_name
          image = var.image

          port {
            name           = "http"
            container_port = var.service_port
            protocol       = "TCP"
          }

          env {
            name  = "TZ"
            value = var.timezone
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }

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

          liveness_probe {
            http_get {
              path = "/"
              port = var.service_port
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.service_port
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
          }

          security_context {
            privileged = false
          }
        }

        volume {
          name = "config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home_assistant_config.metadata[0].name
          }
        }

        restart_policy = "Always"
      }
    }
  }
}

# ============================================================================
# Service (ClusterIP)
# ============================================================================

resource "kubernetes_service" "home_assistant" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.home_assistant.metadata[0].name

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

# ============================================================================
# Ingress - Local Domain (local-ca certificate)
# ============================================================================

resource "kubernetes_ingress_v1" "home_assistant_local" {
  metadata {
    name      = "${var.app_name}-local"
    namespace = kubernetes_namespace.home_assistant.metadata[0].name

    annotations = {
      "cert-manager.io/cluster-issuer"                   = var.local_cluster_issuer
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
    }

    labels = {
      "app.kubernetes.io/name" = var.app_name
    }
  }

  spec {
    ingress_class_name = var.ingress_class

    rule {
      host = var.local_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.home_assistant.metadata[0].name
              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }

    tls {
      hosts       = [var.local_domain]
      secret_name = "${var.app_name}-local-tls"
    }
  }
}

# ============================================================================
# Ingress - External Domain (Let's Encrypt certificate)
# ============================================================================

resource "kubernetes_ingress_v1" "home_assistant_external" {
  metadata {
    name      = "${var.app_name}-external"
    namespace = kubernetes_namespace.home_assistant.metadata[0].name

    annotations = {
      "cert-manager.io/cluster-issuer"                   = var.external_cluster_issuer
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
    }

    labels = {
      "app.kubernetes.io/name" = var.app_name
    }
  }

  spec {
    ingress_class_name = var.ingress_class

    rule {
      host = var.external_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.home_assistant.metadata[0].name
              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }

    tls {
      hosts       = [var.external_domain]
      secret_name = "${var.app_name}-external-tls"
    }
  }
}
