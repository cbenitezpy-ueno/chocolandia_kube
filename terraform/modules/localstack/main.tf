# LocalStack Module - AWS Service Emulation
# Deploys LocalStack Community Edition on K3s cluster

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

resource "kubernetes_namespace" "localstack" {
  metadata {
    name = var.namespace
    labels = {
      name       = "localstack"
      managed-by = "opentofu"
      app        = "localstack"
    }
  }
}

# ==============================================================================
# PersistentVolumeClaim for LocalStack Data
# ==============================================================================

resource "kubernetes_persistent_volume_claim" "localstack_storage" {
  metadata {
    name      = "localstack-storage"
    namespace = kubernetes_namespace.localstack.metadata[0].name
    labels = {
      app = "localstack"
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
# LocalStack Deployment
# ==============================================================================

resource "kubernetes_deployment" "localstack" {
  metadata {
    name      = "localstack"
    namespace = kubernetes_namespace.localstack.metadata[0].name
    labels = {
      app = "localstack"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "localstack"
      }
    }

    template {
      metadata {
        labels = {
          app = "localstack"
        }
      }

      spec {
        container {
          name              = "localstack"
          image             = var.localstack_image
          image_pull_policy = "IfNotPresent"

          # Environment Variables
          env {
            name  = "SERVICES"
            value = var.services_list
          }

          env {
            name  = "PERSISTENCE"
            value = var.enable_persistence ? "1" : "0"
          }

          env {
            name  = "DATA_DIR"
            value = "/var/lib/localstack"
          }

          env {
            name  = "LAMBDA_EXECUTOR"
            value = var.lambda_executor
          }

          env {
            name  = "DOCKER_HOST"
            value = "unix:///var/run/docker.sock"
          }

          env {
            name  = "DEBUG"
            value = "0"
          }

          env {
            name  = "DEFAULT_REGION"
            value = "us-east-1"
          }

          # Edge port for all services
          port {
            name           = "edge"
            container_port = 4566
            protocol       = "TCP"
          }

          volume_mount {
            name       = "localstack-storage"
            mount_path = "/var/lib/localstack"
          }

          volume_mount {
            name       = "docker-sock"
            mount_path = "/var/run/docker.sock"
          }

          # Liveness Probe on /_localstack/health
          liveness_probe {
            http_get {
              path = "/_localstack/health"
              port = 4566
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          # Readiness Probe on /_localstack/health
          readiness_probe {
            http_get {
              path = "/_localstack/health"
              port = 4566
            }
            initial_delay_seconds = 30
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
          name = "localstack-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.localstack_storage.metadata[0].name
          }
        }

        volume {
          name = "docker-sock"
          host_path {
            path = "/var/run/docker.sock"
            type = "Socket"
          }
        }
      }
    }
  }

  wait_for_rollout = true

  depends_on = [
    kubernetes_persistent_volume_claim.localstack_storage
  ]
}

# ==============================================================================
# LocalStack Service (ClusterIP)
# ==============================================================================

resource "kubernetes_service" "localstack" {
  metadata {
    name      = "localstack"
    namespace = kubernetes_namespace.localstack.metadata[0].name
    labels = {
      app = "localstack"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "localstack"
    }

    port {
      name        = "edge"
      port        = 4566
      target_port = 4566
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.localstack]
}

# ==============================================================================
# Traefik Middleware - HTTPS Redirect
# ==============================================================================

resource "kubernetes_manifest" "localstack_https_redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "localstack-https-redirect"
      namespace = kubernetes_namespace.localstack.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "localstack"
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

resource "kubernetes_manifest" "localstack_certificate" {
  computed_fields = [
    "spec.duration",
    "spec.renewBefore"
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "localstack-tls"
      namespace = kubernetes_namespace.localstack.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "localstack"
        "app.kubernetes.io/component"  = "certificate"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      secretName = "localstack-tls"
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

resource "kubernetes_manifest" "localstack_ingressroute_http" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "localstack-http"
      namespace = kubernetes_namespace.localstack.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "localstack"
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
              name      = "localstack-https-redirect"
              namespace = kubernetes_namespace.localstack.metadata[0].name
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
    kubernetes_manifest.localstack_https_redirect
  ]
}

# ==============================================================================
# Traefik IngressRoute - HTTPS
# ==============================================================================

resource "kubernetes_manifest" "localstack_ingressroute_https" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "localstack-https"
      namespace = kubernetes_namespace.localstack.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "localstack"
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
              name      = kubernetes_service.localstack.metadata[0].name
              port      = 4566
              namespace = kubernetes_namespace.localstack.metadata[0].name
            }
          ]
        }
      ]
      tls = {
        secretName = "localstack-tls"
      }
    }
  }

  depends_on = [
    kubernetes_service.localstack,
    kubernetes_manifest.localstack_certificate
  ]
}
