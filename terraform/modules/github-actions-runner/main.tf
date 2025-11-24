# GitHub Actions Runner Module - Main Configuration
# Feature 017: GitHub Actions Self-Hosted Runner
#
# Deploys Actions Runner Controller (ARC) using Helm charts with runner scale set mode.
# Configuration optimized for K3s cluster homelab scale.

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# ==============================================================================
# Kubernetes Namespace
# ==============================================================================

resource "kubernetes_namespace" "github_actions" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "github-actions-runner"
      "app.kubernetes.io/component"  = "namespace"
      "app.kubernetes.io/part-of"    = "github-actions"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }
}

# ==============================================================================
# GitHub App Secret
# ==============================================================================

resource "kubernetes_secret" "github_app" {
  metadata {
    name      = "github-app-secret"
    namespace = kubernetes_namespace.github_actions.metadata[0].name

    labels = {
      "app.kubernetes.io/name"       = "github-actions-runner"
      "app.kubernetes.io/component"  = "credentials"
      "app.kubernetes.io/part-of"    = "github-actions"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    github_app_id              = var.github_app_id
    github_app_installation_id = var.github_app_installation_id
    github_app_private_key     = var.github_app_private_key
  }

  type = "Opaque"
}

# ==============================================================================
# T009: ARC Controller Helm Release (gha-runner-scale-set-controller)
# Cluster-wide controller that manages runner scale sets
# ==============================================================================

resource "helm_release" "arc_controller" {
  name       = "arc-controller"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  version    = var.arc_controller_version
  namespace  = kubernetes_namespace.github_actions.metadata[0].name

  wait    = true
  timeout = 300 # 5 minutes

  values = [
    yamlencode({
      # ==========================================================================
      # Controller Configuration
      # ==========================================================================
      replicaCount = 1 # Single replica for homelab

      # Resource limits for controller pod
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      # ==========================================================================
      # Metrics Configuration
      # ==========================================================================
      metrics = {
        controllerManagerAddr = ":8080"
        listenerAddr          = ":8080"
        listenerEndpoint      = "/metrics"
      }

      # ==========================================================================
      # Service Account
      # ==========================================================================
      serviceAccount = {
        create = true
        name   = "arc-controller-sa"
      }
    })
  ]

  depends_on = [kubernetes_namespace.github_actions]
}

# ==============================================================================
# T012: Runner Scale Set Helm Release (gha-runner-scale-set)
# Manages runner pods for GitHub Actions workflows
# ==============================================================================

resource "helm_release" "arc_runner_scale_set" {
  name       = var.runner_name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = var.arc_runner_version
  namespace  = kubernetes_namespace.github_actions.metadata[0].name

  wait    = true
  timeout = 300 # 5 minutes

  values = [
    yamlencode({
      # ==========================================================================
      # GitHub Configuration
      # ==========================================================================
      githubConfigUrl    = var.github_config_url
      githubConfigSecret = kubernetes_secret.github_app.metadata[0].name

      # ==========================================================================
      # Runner Configuration (T011, T013)
      # ==========================================================================
      runnerGroup = "default"

      # Runner scale configuration (T025, T026)
      minRunners = var.min_runners
      maxRunners = var.max_runners

      # Runner labels for workflow targeting
      # Usage in workflow: runs-on: [self-hosted, linux, x64, homelab]
      runnerScaleSetName = var.runner_name

      # ==========================================================================
      # Container Mode Configuration
      # ==========================================================================
      # Using Kubernetes mode (not DinD) for better security
      containerMode = {
        type = "kubernetes"
        kubernetesModeWorkVolumeClaim = {
          accessModes      = ["ReadWriteOnce"]
          storageClassName = "local-path"
          resources = {
            requests = {
              storage = "10Gi"
            }
          }
        }
      }

      # ==========================================================================
      # Pod Template (T013)
      # ==========================================================================
      template = {
        spec = {
          containers = [
            {
              name = "runner"
              resources = {
                limits = {
                  cpu    = var.cpu_limit
                  memory = var.memory_limit
                }
                requests = {
                  cpu    = var.cpu_request
                  memory = var.memory_request
                }
              }
            }
          ]
        }
      }

      # ==========================================================================
      # Controller Reference
      # ==========================================================================
      controllerServiceAccount = {
        namespace = kubernetes_namespace.github_actions.metadata[0].name
        name      = "arc-controller-sa"
      }
    })
  ]

  depends_on = [helm_release.arc_controller, kubernetes_secret.github_app]
}

# ==============================================================================
# T019, T020: ServiceMonitor for Prometheus Integration
# ==============================================================================

resource "kubernetes_manifest" "servicemonitor" {
  count = var.enable_monitoring ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "github-actions-runner"
      namespace = kubernetes_namespace.github_actions.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "github-actions-runner"
        "app.kubernetes.io/component"  = "monitoring"
        "app.kubernetes.io/part-of"    = "github-actions"
        "app.kubernetes.io/managed-by" = "opentofu"
        "release"                      = "kube-prometheus-stack" # Required for Prometheus discovery
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "gha-runner-scale-set-controller"
        }
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }

  depends_on = [helm_release.arc_controller]
}

# ==============================================================================
# T021, T022: PrometheusRule for Alerting
# ==============================================================================

resource "kubernetes_manifest" "prometheusrule" {
  count = var.enable_monitoring ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "github-actions-runner"
      namespace = kubernetes_namespace.github_actions.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "github-actions-runner"
        "app.kubernetes.io/component"  = "alerting"
        "app.kubernetes.io/part-of"    = "github-actions"
        "app.kubernetes.io/managed-by" = "opentofu"
        "release"                      = "kube-prometheus-stack" # Required for Prometheus discovery
      }
    }
    spec = {
      groups = [
        {
          name = "github-actions-runner"
          rules = [
            {
              alert = "GitHubRunnerOffline"
              expr  = "absent(github_runner_busy) == 1"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "GitHub Actions Runner is offline"
                description = "No GitHub Actions runner metrics have been received for more than 5 minutes. The runner may be offline or disconnected."
              }
            },
            {
              alert = "GitHubRunnerHighUtilization"
              expr  = "github_runner_busy == 1"
              for   = "30m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "GitHub Actions Runner continuously busy"
                description = "GitHub Actions runner has been continuously busy for more than 30 minutes. Consider adding more runners."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.arc_controller]
}
