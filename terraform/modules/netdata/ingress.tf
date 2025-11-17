# ============================================================================
# Traefik IngressRoute and TLS Certificate for Netdata
# ============================================================================

# ============================================================================
# TLS Certificate (Let's Encrypt via cert-manager)
# ============================================================================

resource "kubernetes_manifest" "netdata_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "netdata-tls"
      namespace = kubernetes_namespace.netdata.metadata[0].name
    }
    spec = {
      secretName = "netdata-tls"
      issuerRef = {
        name = var.cluster_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [var.domain]
      duration    = "2160h"  # 90 days
      renewBefore = "720h"   # 30 days
    }
  }

  depends_on = [kubernetes_namespace.netdata]
}

# ============================================================================
# Traefik Middleware to Block Cloud Claim API
# ============================================================================

resource "kubernetes_manifest" "netdata_block_claim_middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "netdata-block-claim"
      namespace = kubernetes_namespace.netdata.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "netdata"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      replacePath = {
        path = "/api/v1/info"
      }
      replacePathRegex = {
        regex       = "^/api/v3/claim.*"
        replacement = "/api/v1/info"
      }
    }
  }

  depends_on = [kubernetes_namespace.netdata]
}

# ============================================================================
# Traefik IngressRoute (HTTPS)
# ============================================================================

resource "kubernetes_manifest" "netdata_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "netdata-https"
      namespace = kubernetes_namespace.netdata.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "netdata"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`${var.domain}`) && PathPrefix(`/api/v3/claim`)"
          kind  = "Rule"
          middlewares = [
            {
              name = kubernetes_manifest.netdata_block_claim_middleware.manifest.metadata.name
            }
          ]
          services = [
            {
              name = data.kubernetes_service.netdata_parent.metadata[0].name
              port = 19999
            }
          ]
          priority = 100
        },
        {
          match = "Host(`${var.domain}`)"
          kind  = "Rule"
          services = [
            {
              name = data.kubernetes_service.netdata_parent.metadata[0].name
              port = 19999
            }
          ]
        }
      ]
      tls = {
        secretName = "netdata-tls"
      }
    }
  }

  depends_on = [
    helm_release.netdata,
    kubernetes_manifest.netdata_certificate,
    kubernetes_manifest.netdata_block_claim_middleware
  ]
}

# ============================================================================
# HTTP to HTTPS Redirect (optional but recommended)
# ============================================================================

resource "kubernetes_manifest" "netdata_redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "netdata-http-redirect"
      namespace = kubernetes_namespace.netdata.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.domain}`)"
          kind  = "Rule"
          middlewares = [
            {
              name      = "redirect-https"
              namespace = "traefik"
            }
          ]
          services = [
            {
              name = data.kubernetes_service.netdata_parent.metadata[0].name
              port = 19999
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.netdata]
}
