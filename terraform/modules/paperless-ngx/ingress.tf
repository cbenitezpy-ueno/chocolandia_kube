# Paperless-ngx Ingress Configuration
# Feature: 027-paperless-ngx
# Local access via Traefik + local-ca certificate

# ============================================================================
# TLS Certificate (local-ca issuer)
# ============================================================================

resource "kubernetes_manifest" "certificate_local" {
  count = var.enable_local_ingress ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "${var.app_name}-local-tls"
      namespace = kubernetes_namespace.paperless.metadata[0].name
    }
    spec = {
      secretName = var.local_tls_secret
      issuerRef = {
        name = var.local_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [var.local_host]
    }
  }
}

# ============================================================================
# Ingress - Local Domain (local-ca certificate)
# ============================================================================

resource "kubernetes_ingress_v1" "paperless_local" {
  count = var.enable_local_ingress ? 1 : 0

  metadata {
    name      = "${var.app_name}-local"
    namespace = kubernetes_namespace.paperless.metadata[0].name

    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
    }

    labels = {
      "app.kubernetes.io/name" = var.app_name
    }
  }

  spec {
    ingress_class_name = var.ingress_class

    rule {
      host = var.local_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.paperless.metadata[0].name
              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }

    tls {
      hosts       = [var.local_host]
      secret_name = var.local_tls_secret
    }
  }
}
