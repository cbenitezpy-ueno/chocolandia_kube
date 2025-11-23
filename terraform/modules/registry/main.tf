# Registry Module - Docker Registry v2 Deployment
# Deploys a private container registry on K3s cluster

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# ==============================================================================
# Namespace
# ==============================================================================

resource "kubernetes_namespace" "registry" {
  metadata {
    name = var.namespace
    labels = {
      name       = "registry"
      managed-by = "opentofu"
      app        = "docker-registry"
    }
  }
}

# ==============================================================================
# Secret for htpasswd authentication
# ==============================================================================

resource "kubernetes_secret" "registry_auth" {
  metadata {
    name      = var.auth_secret
    namespace = kubernetes_namespace.registry.metadata[0].name
    labels = {
      app = "registry"
    }
  }

  type = "Opaque"

  data = {
    htpasswd = file("${path.root}/../../../kubernetes/dev-tools/secrets/htpasswd")
  }
}

# ==============================================================================
# ConfigMap for Registry Configuration
# ==============================================================================

resource "kubernetes_config_map" "registry_config" {
  metadata {
    name      = "registry-config"
    namespace = kubernetes_namespace.registry.metadata[0].name
    labels = {
      app = "registry"
    }
  }

  data = {
    "config.yml" = <<-EOT
      version: 0.1
      log:
        fields:
          service: registry
      storage:
        filesystem:
          rootdirectory: /var/lib/registry
        delete:
          enabled: true
      http:
        addr: :5000
        headers:
          X-Content-Type-Options: [nosniff]
        debug:
          addr: :5001
          prometheus:
            enabled: true
            path: /metrics
      auth:
        htpasswd:
          realm: "Registry Realm"
          path: /auth/htpasswd
      health:
        storagedriver:
          enabled: true
          interval: 10s
          threshold: 3
    EOT
  }
}

# ==============================================================================
# PersistentVolumeClaim for Registry Storage
# ==============================================================================

resource "kubernetes_persistent_volume_claim" "registry_storage" {
  metadata {
    name      = "registry-storage"
    namespace = kubernetes_namespace.registry.metadata[0].name
    labels = {
      app = "registry"
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

  wait_until_bound = false
}

# ==============================================================================
# Registry Deployment
# ==============================================================================

resource "kubernetes_deployment" "registry" {
  metadata {
    name      = "registry"
    namespace = kubernetes_namespace.registry.metadata[0].name
    labels = {
      app = "registry"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "5001"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "registry"
      }
    }

    template {
      metadata {
        labels = {
          app = "registry"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "5001"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        container {
          name              = "registry"
          image             = var.registry_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 5000
            protocol       = "TCP"
          }

          port {
            name           = "metrics"
            container_port = 5001
            protocol       = "TCP"
          }

          volume_mount {
            name       = "registry-storage"
            mount_path = "/var/lib/registry"
          }

          volume_mount {
            name       = "registry-config"
            mount_path = "/etc/docker/registry/config.yml"
            sub_path   = "config.yml"
          }

          volume_mount {
            name       = "registry-auth"
            mount_path = "/auth"
            read_only  = true
          }

          # Liveness Probe on /v2/
          liveness_probe {
            http_get {
              path = "/v2/"
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Readiness Probe on /v2/
          readiness_probe {
            http_get {
              path = "/v2/"
              port = 5000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
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
          name = "registry-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.registry_storage.metadata[0].name
          }
        }

        volume {
          name = "registry-config"
          config_map {
            name = kubernetes_config_map.registry_config.metadata[0].name
          }
        }

        volume {
          name = "registry-auth"
          secret {
            secret_name = kubernetes_secret.registry_auth.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_rollout = true

  depends_on = [
    kubernetes_persistent_volume_claim.registry_storage,
    kubernetes_config_map.registry_config,
    kubernetes_secret.registry_auth
  ]
}

# ==============================================================================
# Registry Service (ClusterIP)
# ==============================================================================

resource "kubernetes_service" "registry" {
  metadata {
    name      = "registry"
    namespace = kubernetes_namespace.registry.metadata[0].name
    labels = {
      app = "registry"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "registry"
    }

    port {
      name        = "http"
      port        = 5000
      target_port = 5000
      protocol    = "TCP"
    }

    port {
      name        = "metrics"
      port        = 5001
      target_port = 5001
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.registry]
}

# ==============================================================================
# Traefik Middleware for Basic Auth
# ==============================================================================

resource "kubernetes_manifest" "registry_basic_auth" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "registry-basic-auth"
      namespace = kubernetes_namespace.registry.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "registry"
        "app.kubernetes.io/component"  = "middleware"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      basicAuth = {
        secret = kubernetes_secret.registry_auth.metadata[0].name
      }
    }
  }

  depends_on = [kubernetes_secret.registry_auth]
}

# ==============================================================================
# Traefik Middleware - HTTPS Redirect
# ==============================================================================

resource "kubernetes_manifest" "registry_https_redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "registry-https-redirect"
      namespace = kubernetes_namespace.registry.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "registry"
        "app.kubernetes.io/component"  = "middleware"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      redirectScheme = {
        scheme    = "https"
        permanent = true
      }
    }
  }
}

# ==============================================================================
# cert-manager Certificate
# ==============================================================================

resource "kubernetes_manifest" "registry_certificate" {
  computed_fields = [
    "spec.duration",
    "spec.renewBefore"
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "registry-tls"
      namespace = kubernetes_namespace.registry.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "registry"
        "app.kubernetes.io/component"  = "certificate"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      secretName = "registry-tls"
      issuerRef = {
        name = var.cluster_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [var.hostname]
    }
  }
}

# ==============================================================================
# Traefik IngressRoute - HTTP (Redirect to HTTPS)
# ==============================================================================

resource "kubernetes_manifest" "registry_ingressroute_http" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "registry-http"
      namespace = kubernetes_namespace.registry.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "registry"
        "app.kubernetes.io/component"  = "ingress"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.hostname}`)"
          kind  = "Rule"
          middlewares = [
            {
              name      = "registry-https-redirect"
              namespace = kubernetes_namespace.registry.metadata[0].name
            }
          ]
          services = [
            {
              name = "noop@internal"
              kind = "TraefikService"
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.registry_https_redirect
  ]
}

# ==============================================================================
# Traefik IngressRoute - HTTPS
# ==============================================================================

resource "kubernetes_manifest" "registry_ingressroute_https" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "registry-https"
      namespace = kubernetes_namespace.registry.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "registry"
        "app.kubernetes.io/component"  = "ingress"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      entryPoints = [var.traefik_entrypoint]
      routes = [
        {
          match = "Host(`${var.hostname}`)"
          kind  = "Rule"
          services = [
            {
              name      = kubernetes_service.registry.metadata[0].name
              port      = 5000
              namespace = kubernetes_namespace.registry.metadata[0].name
            }
          ]
        }
      ]
      tls = {
        secretName = "registry-tls"
      }
    }
  }

  depends_on = [
    kubernetes_service.registry,
    kubernetes_manifest.registry_certificate
  ]
}

# ==============================================================================
# Registry UI Deployment (Optional)
# ==============================================================================

resource "kubernetes_deployment" "registry_ui" {
  count = var.enable_ui && var.ui_hostname != "" ? 1 : 0

  metadata {
    name      = "registry-ui"
    namespace = kubernetes_namespace.registry.metadata[0].name
    labels = {
      app = "registry-ui"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "registry-ui"
      }
    }

    template {
      metadata {
        labels = {
          app = "registry-ui"
        }
      }

      spec {
        container {
          name              = "registry-ui"
          image             = var.ui_image
          image_pull_policy = "IfNotPresent"

          env {
            name  = "REGISTRY_TITLE"
            value = "Homelab Registry"
          }

          env {
            name  = "REGISTRY_URL"
            value = "https://${var.hostname}"
          }

          env {
            name  = "SINGLE_REGISTRY"
            value = "true"
          }

          env {
            name  = "DELETE_IMAGES"
            value = "true"
          }

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.registry]
}

# ==============================================================================
# Registry UI Service
# ==============================================================================

resource "kubernetes_service" "registry_ui" {
  count = var.enable_ui && var.ui_hostname != "" ? 1 : 0

  metadata {
    name      = "registry-ui"
    namespace = kubernetes_namespace.registry.metadata[0].name
    labels = {
      app = "registry-ui"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "registry-ui"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.registry_ui]
}

# ==============================================================================
# Registry UI Certificate
# ==============================================================================

resource "kubernetes_manifest" "registry_ui_certificate" {
  count = var.enable_ui && var.ui_hostname != "" ? 1 : 0

  computed_fields = [
    "spec.duration",
    "spec.renewBefore"
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "registry-ui-tls"
      namespace = kubernetes_namespace.registry.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "registry-ui"
        "app.kubernetes.io/component"  = "certificate"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      secretName = "registry-ui-tls"
      issuerRef = {
        name = var.cluster_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [var.ui_hostname]
    }
  }
}

# ==============================================================================
# Registry UI IngressRoute - HTTPS
# ==============================================================================

resource "kubernetes_manifest" "registry_ui_ingressroute_https" {
  count = var.enable_ui && var.ui_hostname != "" ? 1 : 0

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "registry-ui-https"
      namespace = kubernetes_namespace.registry.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "registry-ui"
        "app.kubernetes.io/component"  = "ingress"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      entryPoints = [var.traefik_entrypoint]
      routes = [
        {
          match = "Host(`${var.ui_hostname}`)"
          kind  = "Rule"
          services = [
            {
              name      = kubernetes_service.registry_ui[0].metadata[0].name
              port      = 80
              namespace = kubernetes_namespace.registry.metadata[0].name
            }
          ]
        }
      ]
      tls = {
        secretName = "registry-ui-tls"
      }
    }
  }

  depends_on = [
    kubernetes_service.registry_ui,
    kubernetes_manifest.registry_ui_certificate
  ]
}
