# Nexus Repository Manager Module
# Deploys Sonatype Nexus Repository OSS on K3s cluster

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

resource "kubernetes_namespace" "nexus" {
  metadata {
    name = var.namespace
    labels = {
      name       = "nexus"
      managed-by = "opentofu"
      app        = "nexus"
    }
  }
}

# ==============================================================================
# PersistentVolumeClaim for Nexus Storage
# ==============================================================================

resource "kubernetes_persistent_volume_claim" "nexus_data" {
  metadata {
    name      = "nexus-data"
    namespace = kubernetes_namespace.nexus.metadata[0].name
    labels = {
      app = "nexus"
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
# Nexus Deployment
# ==============================================================================

resource "kubernetes_deployment" "nexus" {
  metadata {
    name      = "nexus"
    namespace = kubernetes_namespace.nexus.metadata[0].name
    labels = {
      app = "nexus"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "8081"
      "prometheus.io/path"   = "/service/metrics/prometheus"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nexus"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "nexus"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8081"
          "prometheus.io/path"   = "/service/metrics/prometheus"
        }
      }

      spec {
        # Nexus runs as UID 200 (nexus user)
        security_context {
          fs_group = 200
        }

        container {
          name              = "nexus"
          image             = var.nexus_image
          image_pull_policy = "IfNotPresent"

          # Web UI and API port
          port {
            name           = "http"
            container_port = 8081
            protocol       = "TCP"
          }

          # Docker registry connector port
          port {
            name           = "docker"
            container_port = 8082
            protocol       = "TCP"
          }

          # JVM and security configuration
          env {
            name  = "INSTALL4J_ADD_VM_PARAMS"
            value = "-Xms${var.jvm_heap_size} -Xmx${var.jvm_heap_size} -XX:MaxDirectMemorySize=512m -Djava.util.prefs.userRoot=/nexus-data/javaprefs"
          }

          env {
            name  = "NEXUS_SECURITY_RANDOMPASSWORD"
            value = "true"
          }

          volume_mount {
            name       = "nexus-data"
            mount_path = "/nexus-data"
          }

          # Liveness Probe - Nexus status endpoint
          liveness_probe {
            http_get {
              path = "/service/rest/v1/status"
              port = 8081
            }
            initial_delay_seconds = 120
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          # Readiness Probe - Nexus status endpoint
          readiness_probe {
            http_get {
              path = "/service/rest/v1/status"
              port = 8081
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
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
          name = "nexus-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.nexus_data.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_rollout = true

  depends_on = [
    kubernetes_persistent_volume_claim.nexus_data
  ]
}

# ==============================================================================
# Nexus Service (Web UI/API) - ClusterIP
# ==============================================================================

resource "kubernetes_service" "nexus" {
  metadata {
    name      = "nexus"
    namespace = kubernetes_namespace.nexus.metadata[0].name
    labels = {
      app = "nexus"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "nexus"
    }

    port {
      name        = "http"
      port        = 8081
      target_port = 8081
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.nexus]
}

# ==============================================================================
# Nexus Docker Connector Service - ClusterIP
# ==============================================================================

resource "kubernetes_service" "nexus_docker" {
  metadata {
    name      = "nexus-docker"
    namespace = kubernetes_namespace.nexus.metadata[0].name
    labels = {
      app       = "nexus"
      component = "docker"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "nexus"
    }

    port {
      name        = "docker"
      port        = 8082
      target_port = 8082
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.nexus]
}

# ==============================================================================
# Traefik Middleware - HTTPS Redirect
# ==============================================================================

resource "kubernetes_manifest" "nexus_https_redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "nexus-https-redirect"
      namespace = kubernetes_namespace.nexus.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "nexus"
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
# cert-manager Certificate (Web UI)
# ==============================================================================

resource "kubernetes_manifest" "nexus_certificate" {
  computed_fields = [
    "spec.duration",
    "spec.renewBefore"
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "nexus-tls"
      namespace = kubernetes_namespace.nexus.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "nexus"
        "app.kubernetes.io/component"  = "certificate"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      secretName = "nexus-tls"
      issuerRef = {
        name = var.cluster_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [var.hostname]
    }
  }
}

# ==============================================================================
# cert-manager Certificate (Docker API)
# ==============================================================================

resource "kubernetes_manifest" "nexus_docker_certificate" {
  computed_fields = [
    "spec.duration",
    "spec.renewBefore"
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "nexus-docker-tls"
      namespace = kubernetes_namespace.nexus.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "nexus"
        "app.kubernetes.io/component"  = "certificate"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      secretName = "nexus-docker-tls"
      issuerRef = {
        name = var.cluster_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [var.docker_hostname]
    }
  }
}

# ==============================================================================
# Traefik IngressRoute - HTTP (Redirect to HTTPS)
# ==============================================================================

resource "kubernetes_manifest" "nexus_ingressroute_http" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "nexus-http"
      namespace = kubernetes_namespace.nexus.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "nexus"
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
              name      = "nexus-https-redirect"
              namespace = kubernetes_namespace.nexus.metadata[0].name
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
    kubernetes_manifest.nexus_https_redirect
  ]
}

# ==============================================================================
# Traefik IngressRoute - HTTPS (Web UI/API)
# ==============================================================================

resource "kubernetes_manifest" "nexus_ingressroute_https" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "nexus-https"
      namespace = kubernetes_namespace.nexus.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "nexus"
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
              name      = kubernetes_service.nexus.metadata[0].name
              port      = 8081
              namespace = kubernetes_namespace.nexus.metadata[0].name
            }
          ]
        }
      ]
      tls = {
        secretName = "nexus-tls"
      }
    }
  }

  depends_on = [
    kubernetes_service.nexus,
    kubernetes_manifest.nexus_certificate
  ]
}

# ==============================================================================
# Traefik IngressRoute - HTTP Docker (Redirect to HTTPS)
# ==============================================================================

resource "kubernetes_manifest" "nexus_docker_ingressroute_http" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "nexus-docker-http"
      namespace = kubernetes_namespace.nexus.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "nexus"
        "app.kubernetes.io/component"  = "ingress"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.docker_hostname}`)"
          kind  = "Rule"
          middlewares = [
            {
              name      = "nexus-https-redirect"
              namespace = kubernetes_namespace.nexus.metadata[0].name
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
    kubernetes_manifest.nexus_https_redirect
  ]
}

# ==============================================================================
# Traefik IngressRoute - HTTPS (Docker API)
# ==============================================================================

resource "kubernetes_manifest" "nexus_docker_ingressroute_https" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "nexus-docker-https"
      namespace = kubernetes_namespace.nexus.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "nexus"
        "app.kubernetes.io/component"  = "ingress"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      entryPoints = [var.traefik_entrypoint]
      routes = [
        {
          match = "Host(`${var.docker_hostname}`)"
          kind  = "Rule"
          services = [
            {
              name      = kubernetes_service.nexus_docker.metadata[0].name
              port      = 8082
              namespace = kubernetes_namespace.nexus.metadata[0].name
            }
          ]
        }
      ]
      tls = {
        secretName = "nexus-docker-tls"
      }
    }
  }

  depends_on = [
    kubernetes_service.nexus_docker,
    kubernetes_manifest.nexus_docker_certificate
  ]
}

# ==============================================================================
# Prometheus ServiceMonitor (Optional)
# ==============================================================================

resource "kubernetes_manifest" "nexus_servicemonitor" {
  count = var.enable_metrics ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "nexus-metrics"
      namespace = kubernetes_namespace.nexus.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "nexus"
        "app.kubernetes.io/component"  = "metrics"
        "app.kubernetes.io/managed-by" = "opentofu"
        "release"                      = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "nexus"
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/service/metrics/prometheus"
          interval = "30s"
        }
      ]
      namespaceSelector = {
        matchNames = [kubernetes_namespace.nexus.metadata[0].name]
      }
    }
  }

  depends_on = [kubernetes_service.nexus]
}
