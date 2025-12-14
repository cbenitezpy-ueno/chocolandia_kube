# Grafana IngressRoute for .local domain
# Exposes Grafana via https://grafana.chocolandiadc.local

# ==============================================================================
# Variables
# ==============================================================================

variable "grafana_hostname" {
  description = "Hostname for Grafana on local network"
  type        = string
  default     = "grafana.chocolandiadc.local"
}

# ==============================================================================
# cert-manager Certificate
# ==============================================================================

resource "kubernetes_manifest" "grafana_certificate" {
  depends_on = [module.local_ca]

  computed_fields = [
    "spec.duration",
    "spec.renewBefore"
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "grafana-tls"
      namespace = "monitoring"
      labels = {
        "app.kubernetes.io/name"       = "grafana"
        "app.kubernetes.io/component"  = "certificate"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      secretName = "grafana-tls"
      issuerRef = {
        name = "local-ca"
        kind = "ClusterIssuer"
      }
      dnsNames = [var.grafana_hostname]
    }
  }
}

# ==============================================================================
# Traefik Middleware - HTTPS Redirect
# ==============================================================================

resource "kubernetes_manifest" "grafana_https_redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "grafana-https-redirect"
      namespace = "monitoring"
      labels = {
        "app.kubernetes.io/name"       = "grafana"
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
# Traefik IngressRoute - HTTP (Redirect to HTTPS)
# ==============================================================================

resource "kubernetes_manifest" "grafana_ingressroute_http" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "grafana-http"
      namespace = "monitoring"
      labels = {
        "app.kubernetes.io/name"       = "grafana"
        "app.kubernetes.io/component"  = "ingress"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.grafana_hostname}`)"
          kind  = "Rule"
          middlewares = [
            {
              name      = "grafana-https-redirect"
              namespace = "monitoring"
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
    kubernetes_manifest.grafana_https_redirect
  ]
}

# ==============================================================================
# Traefik IngressRoute - HTTPS
# ==============================================================================

resource "kubernetes_manifest" "grafana_ingressroute_https" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "grafana-https"
      namespace = "monitoring"
      labels = {
        "app.kubernetes.io/name"       = "grafana"
        "app.kubernetes.io/component"  = "ingress"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`${var.grafana_hostname}`)"
          kind  = "Rule"
          services = [
            {
              name      = "kube-prometheus-stack-grafana"
              port      = 80
              namespace = "monitoring"
            }
          ]
        }
      ]
      tls = {
        secretName = "grafana-tls"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.grafana_certificate,
    helm_release.kube_prometheus_stack
  ]
}

# ==============================================================================
# Outputs
# ==============================================================================

output "grafana_local_url" {
  description = "Grafana URL on local network"
  value       = "https://${var.grafana_hostname}"
}
