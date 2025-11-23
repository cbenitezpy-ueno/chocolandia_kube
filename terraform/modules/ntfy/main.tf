# Ntfy Module - Main
# Feature: 014-monitoring-alerts
# Deploys Ntfy notification server

# Create namespace
resource "kubernetes_namespace" "ntfy" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "opentofu"
      "feature"                      = "014-monitoring-alerts"
    }
  }
}

# PersistentVolumeClaim for Ntfy data
resource "kubernetes_persistent_volume_claim" "ntfy_data" {
  metadata {
    name      = "ntfy-data"
    namespace = kubernetes_namespace.ntfy.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ntfy"
      "app.kubernetes.io/managed-by" = "opentofu"
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

  wait_until_bound = false  # local-path binds only when pod uses it
}

# ConfigMap for Ntfy server config
resource "kubernetes_config_map" "ntfy_config" {
  metadata {
    name      = "ntfy-config"
    namespace = kubernetes_namespace.ntfy.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ntfy"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "server.yml" = <<-EOT
      # Ntfy server configuration
      # Feature: 014-monitoring-alerts

      base-url: "https://${var.ingress_host}"
      listen-http: ":80"
      cache-file: "/var/cache/ntfy/cache.db"
      cache-duration: "24h"
      attachment-cache-dir: "/var/cache/ntfy/attachments"
      behind-proxy: true

      # Enable web UI with login
      enable-web: true
      enable-login: true
      enable-signup: false

      # Authentication
      auth-file: "/var/cache/ntfy/user.db"
      auth-default-access: "${var.auth_default_access}"

      # Logging
      log-level: "info"
      log-format: "json"

      # Rate limiting (prevent abuse)
      visitor-subscription-limit: 30
      visitor-request-limit-burst: 60
      visitor-request-limit-replenish: "5s"
    EOT
  }
}

# Deployment for Ntfy
resource "kubernetes_deployment" "ntfy" {
  metadata {
    name      = "ntfy"
    namespace = kubernetes_namespace.ntfy.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ntfy"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "ntfy"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "ntfy"
        }
      }

      spec {
        container {
          name  = "ntfy"
          image = "binwiederhier/ntfy:${var.image_tag}"
          args  = ["serve", "--config", "/etc/ntfy/server.yml"]

          port {
            container_port = 80
            name           = "http"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/ntfy"
            read_only  = true
          }

          volume_mount {
            name       = "cache"
            mount_path = "/var/cache/ntfy"
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "200m"
            }
          }

          liveness_probe {
            http_get {
              path = "/v1/health"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/v1/health"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.ntfy_config.metadata[0].name
          }
        }

        volume {
          name = "cache"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.ntfy_data.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.ntfy,
    kubernetes_config_map.ntfy_config,
    kubernetes_persistent_volume_claim.ntfy_data
  ]
}

# Service for Ntfy
resource "kubernetes_service" "ntfy" {
  metadata {
    name      = "ntfy"
    namespace = kubernetes_namespace.ntfy.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ntfy"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "ntfy"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.ntfy]
}

# Ingress for external access
resource "kubernetes_ingress_v1" "ntfy" {
  metadata {
    name      = "ntfy"
    namespace = kubernetes_namespace.ntfy.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ntfy"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
    annotations = {
      "cert-manager.io/cluster-issuer" = var.cluster_issuer
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [var.ingress_host]
      secret_name = "ntfy-tls"
    }

    rule {
      host = var.ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.ntfy.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.ntfy]
}

# ServiceMonitor for Prometheus scraping (optional)
resource "kubernetes_manifest" "ntfy_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "ntfy"
      namespace = kubernetes_namespace.ntfy.metadata[0].name
      labels = {
        "app.kubernetes.io/name" = "ntfy"
        "release"                = "prometheus-stack"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "ntfy"
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

  depends_on = [kubernetes_service.ntfy]
}
