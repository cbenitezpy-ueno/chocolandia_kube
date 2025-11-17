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
      duration    = "2160h0m0s"  # 90 days
      renewBefore = "720h0m0s"   # 30 days
    }
  }

  field_manager {
    force_conflicts = true
  }

  depends_on = [kubernetes_namespace.netdata]
}

# ============================================================================
# Traefik IngressRoute (HTTPS)
# Routes /api/v3/claim to blocker service, all other traffic to Netdata
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
          match    = "Host(`${var.domain}`) && PathPrefix(`/api/v3/claim`)"
          kind     = "Rule"
          priority = 100
          services = [
            {
              name = kubernetes_service.claim_blocker.metadata[0].name
              port = 80
            }
          ]
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
    kubernetes_service.claim_blocker
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
              name = kubernetes_manifest.netdata_https_redirect_middleware.manifest.metadata.name
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

  depends_on = [
    helm_release.netdata,
    kubernetes_manifest.netdata_https_redirect_middleware
  ]
}

# ============================================================================
# HTTPS Redirect Middleware
# ============================================================================

resource "kubernetes_manifest" "netdata_https_redirect_middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "netdata-https-redirect"
      namespace = kubernetes_namespace.netdata.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "netdata"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      redirectScheme = {
        scheme    = "https"
        permanent = true
      }
    }
  }

  depends_on = [kubernetes_namespace.netdata]
}
