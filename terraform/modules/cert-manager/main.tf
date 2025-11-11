# cert-manager Module
# Deploys cert-manager for automated SSL/TLS certificate management with Let's Encrypt

# Create namespace for cert-manager
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cert-manager"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Deploy cert-manager Helm chart
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.chart_version
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  # Wait for all resources to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600 # 10 minutes

  # Render Helm values template with variables
  values = [
    templatefile("${path.module}/helm-values.yaml", {
      namespace                 = var.namespace
      controller_replicas       = var.controller_replicas
      controller_cpu_request    = var.controller_cpu_request
      controller_memory_request = var.controller_memory_request
      controller_cpu_limit      = var.controller_cpu_limit
      controller_memory_limit   = var.controller_memory_limit
      webhook_replicas          = var.webhook_replicas
      webhook_cpu_request       = var.webhook_cpu_request
      webhook_memory_request    = var.webhook_memory_request
      webhook_cpu_limit         = var.webhook_cpu_limit
      webhook_memory_limit      = var.webhook_memory_limit
      cainjector_replicas       = var.cainjector_replicas
      cainjector_cpu_request    = var.cainjector_cpu_request
      cainjector_memory_request = var.cainjector_memory_request
      cainjector_cpu_limit      = var.cainjector_cpu_limit
      cainjector_memory_limit   = var.cainjector_memory_limit
      enable_metrics            = var.enable_metrics
    })
  ]

  depends_on = [
    kubernetes_namespace.cert_manager
  ]
}

# Create staging ClusterIssuer for Let's Encrypt (testing)
resource "kubernetes_manifest" "letsencrypt_staging" {
  count = var.enable_staging ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"

    metadata = {
      name = "letsencrypt-staging"

      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }

    spec = {
      acme = {
        # Staging ACME server (higher rate limits, fake certificates)
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"

        # Email for expiry notifications
        email = var.acme_email

        # Secret to store ACME account private key
        privateKeySecretRef = {
          name = "letsencrypt-staging-account-key"
        }

        # HTTP-01 challenge solver configuration
        solvers = [
          {
            http01 = {
              ingress = {
                class = "traefik"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [
    helm_release.cert_manager
  ]
}

# Create production ClusterIssuer for Let's Encrypt (trusted certificates)
resource "kubernetes_manifest" "letsencrypt_production" {
  count = var.enable_production ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"

    metadata = {
      name = "letsencrypt-production"

      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }

    spec = {
      acme = {
        # Production ACME server (rate limited, trusted certificates)
        server = "https://acme-v02.api.letsencrypt.org/directory"

        # Email for expiry notifications
        email = var.acme_email

        # Secret to store ACME account private key
        privateKeySecretRef = {
          name = "letsencrypt-production-account-key"
        }

        # HTTP-01 challenge solver configuration
        solvers = [
          {
            http01 = {
              ingress = {
                class = "traefik"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [
    helm_release.cert_manager
  ]
}
