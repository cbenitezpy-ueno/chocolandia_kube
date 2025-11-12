# ArgoCD Ingress Configuration
# Feature 008: GitOps Continuous Deployment with ArgoCD
#
# Exposes ArgoCD web UI via Traefik IngressRoute with HTTPS using cert-manager.
# TLS certificate issued by Let's Encrypt via cert-manager ClusterIssuer.

# ==============================================================================
# Traefik IngressRoute
# ==============================================================================

resource "kubernetes_manifest" "argocd_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"

    metadata = {
      name      = "argocd-server"
      namespace = var.argocd_namespace
      labels = {
        "app.kubernetes.io/name"       = "argocd-server"
        "app.kubernetes.io/instance"   = "argocd"
        "app.kubernetes.io/component"  = "server"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }

    spec = {
      entryPoints = ["websecure"]

      routes = [
        {
          kind  = "Rule"
          match = "Host(`${var.argocd_domain}`)"

          services = [
            {
              name = "argocd-server"
              port = 443 # ArgoCD server HTTPS port (insecure mode, TLS terminated at Traefik)
            }
          ]
        }
      ]

      tls = {
        secretName = "argocd-tls" # TLS certificate Secret created by cert-manager
      }
    }
  }

  # Wait for ArgoCD Helm release to create the service
  depends_on = [helm_release.argocd]
}

# ==============================================================================
# TLS Certificate (cert-manager)
# ==============================================================================

resource "kubernetes_manifest" "argocd_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"

    metadata = {
      name      = "argocd-tls"
      namespace = var.argocd_namespace
      labels = {
        "app.kubernetes.io/name"       = "argocd-server"
        "app.kubernetes.io/instance"   = "argocd"
        "app.kubernetes.io/component"  = "certificate"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }

    spec = {
      secretName = "argocd-tls" # Secret name where certificate will be stored

      # Certificate duration and renewal (using Go duration format)
      duration    = "2160h0m0s" # 90 days
      renewBefore = "720h0m0s"  # 30 days before expiration

      # Let's Encrypt ClusterIssuer (production or staging)
      issuerRef = {
        name  = var.cluster_issuer # letsencrypt-production or letsencrypt-staging
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }

      # DNS names for certificate
      dnsNames = [
        var.argocd_domain # argocd.chocolandiadc.com
      ]

      # Private key configuration
      privateKey = {
        algorithm = "RSA"
        size      = 2048
      }
    }
  }

  # Wait for cert-manager to be available
  depends_on = [helm_release.argocd]
}
