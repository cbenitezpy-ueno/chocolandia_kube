# ============================================================================
# Traefik IngressRoute and TLS Configuration for MinIO
# ============================================================================
# Exposes MinIO S3 API at https://s3.chocolandiadc.com and
# MinIO Console at https://minio.chocolandiadc.com with TLS certificates
# ============================================================================

# TLS Certificate for S3 API endpoint
resource "kubernetes_manifest" "minio_s3_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "minio-s3-tls"
      namespace = kubernetes_namespace.minio.metadata[0].name
    }
    spec = {
      secretName = "minio-s3-tls"
      issuerRef = {
        name = var.cluster_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [
        var.s3_domain
      ]
    }
  }
}

# TLS Certificate for Console
resource "kubernetes_manifest" "minio_console_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "minio-console-tls"
      namespace = kubernetes_namespace.minio.metadata[0].name
    }
    spec = {
      secretName = "minio-console-tls"
      issuerRef = {
        name = var.cluster_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [
        var.console_domain
      ]
    }
  }
}

# Traefik IngressRoute for S3 API (HTTPS)
resource "kubernetes_manifest" "minio_s3_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "minio-s3-api"
      namespace = kubernetes_namespace.minio.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = var.cluster_issuer
      }
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`${var.s3_domain}`)"
          kind  = "Rule"
          services = [
            {
              name = kubernetes_service.minio_api.metadata[0].name
              port = 9000
            }
          ]
        }
      ]
      tls = {
        secretName = "minio-s3-tls"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.minio_s3_certificate
  ]
}

# Traefik IngressRoute for Console (HTTPS)
resource "kubernetes_manifest" "minio_console_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "minio-console"
      namespace = kubernetes_namespace.minio.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = var.cluster_issuer
      }
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`${var.console_domain}`)"
          kind  = "Rule"
          services = [
            {
              name = kubernetes_service.minio_console.metadata[0].name
              port = 9001
            }
          ]
        }
      ]
      tls = {
        secretName = "minio-console-tls"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.minio_console_certificate
  ]
}
