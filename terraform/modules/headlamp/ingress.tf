# ==============================================================================
# Traefik Middleware - HTTPS Redirect
# ==============================================================================

resource "kubernetes_manifest" "https_redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "https-redirect"
      namespace = kubernetes_namespace.headlamp.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "headlamp"
        "app.kubernetes.io/component"  = "ingress"
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

  depends_on = [
    helm_release.headlamp
  ]
}

# ==============================================================================
# cert-manager Certificate
# ==============================================================================

resource "kubernetes_manifest" "certificate" {
  computed_fields = [
    "spec.duration",
    "spec.renewBefore"
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "headlamp-cert"
      namespace = kubernetes_namespace.headlamp.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "headlamp"
        "app.kubernetes.io/component"  = "certificate"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      secretName = "headlamp-tls"
      issuerRef = {
        name = var.cluster_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [
        var.domain
      ]
      duration    = var.certificate_duration
      renewBefore = var.certificate_renew_before
    }
  }

  depends_on = [
    helm_release.headlamp
  ]
}

# ==============================================================================
# Traefik IngressRoute - HTTP (Redirect to HTTPS)
# ==============================================================================

resource "kubernetes_manifest" "ingressroute_http" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "headlamp-http"
      namespace = kubernetes_namespace.headlamp.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "headlamp"
        "app.kubernetes.io/component"  = "ingress"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.domain}`)"
          kind  = "Rule"
          middlewares = [
            {
              name      = kubernetes_manifest.https_redirect.manifest.metadata.name
              namespace = kubernetes_namespace.headlamp.metadata[0].name
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
    helm_release.headlamp,
    kubernetes_manifest.https_redirect
  ]
}

# ==============================================================================
# Traefik IngressRoute - HTTPS
# ==============================================================================

resource "kubernetes_manifest" "ingressroute_https" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "headlamp-https"
      namespace = kubernetes_namespace.headlamp.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "headlamp"
        "app.kubernetes.io/component"  = "ingress"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`${var.domain}`)"
          kind  = "Rule"
          services = [
            {
              name      = helm_release.headlamp.name
              port      = 80
              namespace = kubernetes_namespace.headlamp.metadata[0].name
            }
          ]
        }
      ]
      tls = {
        secretName = kubernetes_manifest.certificate.manifest.spec.secretName
      }
    }
  }

  depends_on = [
    helm_release.headlamp,
    kubernetes_manifest.certificate
  ]
}

# ==============================================================================
# Notes on Traefik IngressRoute Configuration
# ==============================================================================

# HTTP Route (port 80):
# - Matches all traffic to var.domain
# - Applies https-redirect middleware
# - Routes to noop@internal (no backend, redirect only)
# - Result: All HTTP requests get 301 redirect to HTTPS

# HTTPS Route (port 443):
# - Matches all traffic to var.domain
# - Routes to Headlamp service on port 80
# - Uses TLS certificate from headlamp-tls secret
# - Result: Secure HTTPS access with valid Let's Encrypt certificate
