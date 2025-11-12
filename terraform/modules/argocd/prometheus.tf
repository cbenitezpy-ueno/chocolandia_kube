# ArgoCD Prometheus Integration
# Feature 008: GitOps Continuous Deployment with ArgoCD
#
# Creates ServiceMonitor for Prometheus Operator to scrape ArgoCD metrics.
# Metrics are exposed by argocd-server, argocd-repo-server, and argocd-application-controller.

# ==============================================================================
# ServiceMonitor for ArgoCD Metrics
# ==============================================================================

resource "kubernetes_manifest" "argocd_servicemonitor" {
  count = var.enable_prometheus_metrics ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "argocd-metrics"
      namespace = var.argocd_namespace
      labels = {
        "app.kubernetes.io/name"       = "argocd"
        "app.kubernetes.io/instance"   = "argocd"
        "app.kubernetes.io/component"  = "metrics"
        "app.kubernetes.io/managed-by" = "terraform"
        "release"                      = "kube-prometheus-stack"  # Required by Prometheus Operator
      }
    }

    spec = {
      # Selector to match ArgoCD services
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "argocd-server"
        }
      }

      # Namespace selector
      namespaceSelector = {
        matchNames = [var.argocd_namespace]
      }

      # Endpoints configuration for metrics scraping
      endpoints = [
        # ArgoCD Server metrics
        {
          port     = "metrics"
          path     = "/metrics"
          interval = "30s"
          scheme   = "http"
        }
      ]
    }
  }

  # Wait for ArgoCD Helm release to create services
  depends_on = [helm_release.argocd]
}

# ==============================================================================
# ServiceMonitor for ArgoCD Repository Server
# ==============================================================================

resource "kubernetes_manifest" "argocd_repo_server_servicemonitor" {
  count = var.enable_prometheus_metrics ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "argocd-repo-server-metrics"
      namespace = var.argocd_namespace
      labels = {
        "app.kubernetes.io/name"       = "argocd-repo-server"
        "app.kubernetes.io/instance"   = "argocd"
        "app.kubernetes.io/component"  = "repo-server"
        "app.kubernetes.io/managed-by" = "terraform"
        "release"                      = "kube-prometheus-stack"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "argocd-repo-server"
        }
      }

      namespaceSelector = {
        matchNames = [var.argocd_namespace]
      }

      endpoints = [
        {
          port     = "metrics"
          path     = "/metrics"
          interval = "30s"
          scheme   = "http"
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}

# ==============================================================================
# ServiceMonitor for ArgoCD Application Controller
# ==============================================================================

resource "kubernetes_manifest" "argocd_application_controller_servicemonitor" {
  count = var.enable_prometheus_metrics ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "argocd-application-controller-metrics"
      namespace = var.argocd_namespace
      labels = {
        "app.kubernetes.io/name"       = "argocd-application-controller"
        "app.kubernetes.io/instance"   = "argocd"
        "app.kubernetes.io/component"  = "application-controller"
        "app.kubernetes.io/managed-by" = "terraform"
        "release"                      = "kube-prometheus-stack"
      }
    }

    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "argocd-application-controller"
        }
      }

      namespaceSelector = {
        matchNames = [var.argocd_namespace]
      }

      endpoints = [
        {
          port     = "metrics"
          path     = "/metrics"
          interval = "30s"
          scheme   = "http"
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}
