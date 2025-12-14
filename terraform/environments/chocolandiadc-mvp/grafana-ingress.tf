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
# Locals - Common values for DRY principle
# ==============================================================================

locals {
  grafana_namespace = "monitoring"
  grafana_app_name  = "grafana"
  grafana_common_labels = {
    "app.kubernetes.io/name"       = local.grafana_app_name
    "app.kubernetes.io/managed-by" = "opentofu"
  }
  grafana_service_name = "${helm_release.kube_prometheus_stack.name}-grafana"
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
      namespace = local.grafana_namespace
      labels = merge(local.grafana_common_labels, {
        "app.kubernetes.io/component" = "certificate"
      })
    }
    spec = {
      secretName = "grafana-tls"
      issuerRef = {
        name = module.local_ca.issuer_name
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
      namespace = local.grafana_namespace
      labels = merge(local.grafana_common_labels, {
        "app.kubernetes.io/component" = "middleware"
      })
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
      namespace = local.grafana_namespace
      labels = merge(local.grafana_common_labels, {
        "app.kubernetes.io/component" = "ingress"
      })
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
              namespace = local.grafana_namespace
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
      namespace = local.grafana_namespace
      labels = merge(local.grafana_common_labels, {
        "app.kubernetes.io/component" = "ingress"
      })
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`${var.grafana_hostname}`)"
          kind  = "Rule"
          services = [
            {
              name      = local.grafana_service_name
              port      = 80
              namespace = local.grafana_namespace
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
