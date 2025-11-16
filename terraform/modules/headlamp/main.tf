# ==============================================================================
# Kubernetes Namespace
# ==============================================================================

resource "kubernetes_namespace" "headlamp" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "headlamp"
      "app.kubernetes.io/component"  = "dashboard"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ==============================================================================
# Helm Release - Headlamp Dashboard
# ==============================================================================

resource "helm_release" "headlamp" {
  name       = "headlamp"
  repository = var.chart_repository
  chart      = "headlamp"
  version    = var.chart_version
  namespace  = kubernetes_namespace.headlamp.metadata[0].name

  # High-level configuration
  values = [
    yamlencode({
      # Replica configuration
      replicaCount = var.replicas

      # Resource limits and requests
      resources = {
        requests = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      # Service configuration (ClusterIP, not exposed directly)
      service = {
        type = "ClusterIP"
        port = 80
      }

      # Ingress disabled (using Traefik IngressRoute instead)
      ingress = {
        enabled = false
      }

      # Base URL configuration (dedicated domain, no subpath)
      config = {
        baseURL = ""
        # Disable analytics for privacy
        disableAnalytics = true
      }

      # Environment variables
      env = [
        {
          name  = "HEADLAMP_DISABLE_ANALYTICS"
          value = "true"
        }
      ]

      # PodDisruptionBudget for high availability
      podDisruptionBudget = {
        enabled      = var.pdb_enabled
        minAvailable = var.pdb_min_available
      }

      # Pod anti-affinity to spread replicas across nodes
      affinity = var.enable_pod_anti_affinity ? {
        podAntiAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchExpressions = [
                    {
                      key      = "app.kubernetes.io/name"
                      operator = "In"
                      values   = ["headlamp"]
                    }
                  ]
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }
          ]
        }
      } : {}

      # Liveness and readiness probes
      livenessProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 3
      }

      readinessProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
        initialDelaySeconds = 10
        periodSeconds       = 5
        timeoutSeconds      = 3
        failureThreshold    = 3
      }

      # Prometheus and OIDC integration
      config = merge(
        {
          baseURL          = ""
          disableAnalytics = true
        },
        var.prometheus_url != "" ? {
          prometheusUrl = var.prometheus_url
        } : {},
        var.enable_oidc && var.oidc_client_id != "" ? {
          oidc = {
            clientID     = var.oidc_client_id
            clientSecret = var.oidc_client_secret
            issuerURL    = var.oidc_issuer_url
            scopes       = var.oidc_scopes
          }
        } : {}
      )
    })
  ]

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600 # 10 minutes

  depends_on = [
    kubernetes_namespace.headlamp
  ]
}

# ==============================================================================
# RBAC - ClusterRoleBinding for Cloudflare Access Users
# ==============================================================================

resource "kubernetes_manifest" "cloudflare_users_admin" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "headlamp-cloudflare-users-admin"
      labels = {
        "app.kubernetes.io/name"       = "headlamp"
        "app.kubernetes.io/component"  = "rbac"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "cluster-admin"
    }
    subjects = [
      {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "User"
        name     = var.cloudflare_access_email
      }
    ]
  }

  depends_on = [
    helm_release.headlamp
  ]
}
