# ============================================================================
# Traefik IngressRoute and TLS Configuration for Longhorn Web UI
# ============================================================================
# Exposes Longhorn UI at https://longhorn.chocolandiadc.com with
# cert-manager TLS certificates (Let's Encrypt production)
# ============================================================================

# TLS Certificate from cert-manager (Let's Encrypt)
resource "kubernetes_manifest" "longhorn_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "longhorn-ui-tls"
      namespace = helm_release.longhorn.namespace
    }
    spec = {
      secretName = "longhorn-ui-tls"
      issuerRef = {
        name = var.cluster_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [
        var.longhorn_domain
      ]
      # Removed duration and renewBefore due to Kubernetes provider normalization bug
      # cert-manager will use default values: 90 days duration, 30 days renewBefore
    }
  }
}

# Traefik IngressRoute for HTTPS traffic
resource "kubernetes_manifest" "longhorn_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "longhorn-ui"
      namespace = helm_release.longhorn.namespace
      annotations = {
        "cert-manager.io/cluster-issuer" = var.cluster_issuer
      }
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`${var.longhorn_domain}`)"
          kind  = "Rule"
          services = [
            {
              name = "longhorn-frontend"
              port = 80
            }
          ]
        }
      ]
      tls = {
        secretName = "longhorn-ui-tls"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.longhorn_certificate
  ]
}
