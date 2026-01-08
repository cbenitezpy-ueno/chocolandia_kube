# Jenkins Module - Ingress Configuration
# Feature 029: Jenkins CI Deployment
#
# Traefik IngressRoutes and cert-manager Certificate for Jenkins web UI

# ==============================================================================
# Traefik Middleware - HTTPS Redirect
# ==============================================================================

resource "kubernetes_manifest" "jenkins_https_redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "jenkins-https-redirect"
      namespace = kubernetes_namespace.jenkins.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "jenkins"
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

resource "kubernetes_manifest" "jenkins_certificate" {
  computed_fields = [
    "spec.duration",
    "spec.renewBefore"
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "jenkins-tls"
      namespace = kubernetes_namespace.jenkins.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "jenkins"
        "app.kubernetes.io/component"  = "certificate"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      secretName = "jenkins-tls"
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

resource "kubernetes_manifest" "jenkins_ingressroute_http" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "jenkins-http"
      namespace = kubernetes_namespace.jenkins.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "jenkins"
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
              name      = "jenkins-https-redirect"
              namespace = kubernetes_namespace.jenkins.metadata[0].name
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
    kubernetes_manifest.jenkins_https_redirect
  ]
}

# ==============================================================================
# Traefik IngressRoute - HTTPS (Web UI)
# ==============================================================================

resource "kubernetes_manifest" "jenkins_ingressroute_https" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "jenkins-https"
      namespace = kubernetes_namespace.jenkins.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "jenkins"
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
              name      = "jenkins"
              port      = 8080
              namespace = kubernetes_namespace.jenkins.metadata[0].name
            }
          ]
        }
      ]
      tls = {
        secretName = "jenkins-tls"
      }
    }
  }

  depends_on = [
    helm_release.jenkins,
    kubernetes_manifest.jenkins_certificate
  ]
}
