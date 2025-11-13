# Homepage Kubernetes Resources

# Namespace
resource "kubernetes_namespace" "homepage" {
  metadata {
    name = var.namespace
    labels = {
      name       = "homepage"
      managed-by = "opentofu"
      app        = "homepage-dashboard"
    }
  }
}

# Secret for widget API credentials
resource "kubernetes_secret" "homepage_widgets" {
  metadata {
    name      = "homepage-widgets"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    HOMEPAGE_VAR_ARGOCD_TOKEN = var.argocd_token
  }

  type = "Opaque"
}

# ConfigMap for services.yaml
resource "kubernetes_config_map" "homepage_services" {
  metadata {
    name      = "homepage-services"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    "services.yaml" = file("${path.module}/configs/services.yaml")
  }
}

# ConfigMap for widgets.yaml
resource "kubernetes_config_map" "homepage_widgets" {
  metadata {
    name      = "homepage-widgets"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    "widgets.yaml" = file("${path.module}/configs/widgets.yaml")
  }
}

# ConfigMap for settings.yaml
resource "kubernetes_config_map" "homepage_settings" {
  metadata {
    name      = "homepage-settings"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    "settings.yaml" = file("${path.module}/configs/settings.yaml")
  }
}

# ConfigMap for kubernetes.yaml
resource "kubernetes_config_map" "homepage_kubernetes" {
  metadata {
    name      = "homepage-kubernetes"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    "kubernetes.yaml" = file("${path.module}/configs/kubernetes.yaml")
  }
}

# Deployment
resource "kubernetes_deployment" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
    labels = {
      app = "homepage"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "homepage"
      }
    }

    template {
      metadata {
        labels = {
          app = "homepage"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.homepage.metadata[0].name

        container {
          name  = "homepage"
          image = var.homepage_image

          port {
            container_port = var.service_port
            name           = "http"
          }

          # Mount ConfigMaps
          volume_mount {
            name       = "services-config"
            mount_path = "/app/config/services.yaml"
            sub_path   = "services.yaml"
          }

          volume_mount {
            name       = "widgets-config"
            mount_path = "/app/config/widgets.yaml"
            sub_path   = "widgets.yaml"
          }

          volume_mount {
            name       = "settings-config"
            mount_path = "/app/config/settings.yaml"
            sub_path   = "settings.yaml"
          }

          volume_mount {
            name       = "kubernetes-config"
            mount_path = "/app/config/kubernetes.yaml"
            sub_path   = "kubernetes.yaml"
          }

          # Allow requests from Cloudflare domain
          env {
            name  = "HOMEPAGE_ALLOWED_HOSTS"
            value = "homepage.${var.domain_name}"
          }

          # Inject secrets as environment variables
          env_from {
            secret_ref {
              name = kubernetes_secret.homepage_widgets.metadata[0].name
            }
          }

          # Resource limits
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

          # Liveness probe
          liveness_probe {
            http_get {
              path = "/"
              port = var.service_port
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Readiness probe
          readiness_probe {
            http_get {
              path = "/"
              port = var.service_port
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }

        # Volumes from ConfigMaps
        volume {
          name = "services-config"
          config_map {
            name = kubernetes_config_map.homepage_services.metadata[0].name
          }
        }

        volume {
          name = "widgets-config"
          config_map {
            name = kubernetes_config_map.homepage_widgets.metadata[0].name
          }
        }

        volume {
          name = "settings-config"
          config_map {
            name = kubernetes_config_map.homepage_settings.metadata[0].name
          }
        }

        volume {
          name = "kubernetes-config"
          config_map {
            name = kubernetes_config_map.homepage_kubernetes.metadata[0].name
          }
        }
      }
    }
  }
}

# Service (ClusterIP)
resource "kubernetes_service" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
    labels = {
      app = "homepage"
    }
  }

  spec {
    selector = {
      app = "homepage"
    }

    port {
      port        = var.service_port
      target_port = var.service_port
      name        = "http"
    }

    type = "ClusterIP"
  }
}
