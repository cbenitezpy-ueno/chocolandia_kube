# ArgoCD Module - Main Configuration
# Feature 008: GitOps Continuous Deployment with ArgoCD
#
# Deploys ArgoCD using Helm chart with single-replica configuration for homelab scale.
# Configuration optimized for K3s cluster with 2 nodes (master1 + nodo1).

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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# ==============================================================================
# ArgoCD Helm Release
# ==============================================================================

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = var.argocd_namespace

  create_namespace = true
  wait             = true
  timeout          = 600  # 10 minutes for initial deployment

  values = [
    yamlencode({
      # ==========================================================================
      # Global Configuration
      # ==========================================================================
      global = {
        domain = var.argocd_domain  # argocd.chocolandiadc.com
      }

      # ==========================================================================
      # ArgoCD Server (Web UI + gRPC API)
      # ==========================================================================
      server = {
        replicas = var.server_replicas  # 1 for homelab

        resources = {
          limits = {
            cpu    = var.server_cpu_limit       # 200m
            memory = var.server_memory_limit    # 256Mi
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }

        # Prometheus metrics exposure
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = var.enable_prometheus_metrics
          }
        }

        # Ingress disabled - managed by Traefik IngressRoute (ingress.tf)
        ingress = {
          enabled = false
        }

        # Insecure mode for TLS termination at Traefik
        extraArgs = [
          "--insecure"  # Traefik handles TLS, ArgoCD serves HTTP internally
        ]
      }

      # ==========================================================================
      # ArgoCD Repository Server (Git Operations)
      # ==========================================================================
      repoServer = {
        replicas = var.repo_server_replicas  # 1 for homelab

        resources = {
          limits = {
            cpu    = var.repo_server_cpu_limit      # 200m
            memory = var.repo_server_memory_limit   # 128Mi
          }
          requests = {
            cpu    = "100m"
            memory = "64Mi"
          }
        }

        # Prometheus metrics exposure
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = var.enable_prometheus_metrics
          }
        }
      }

      # ==========================================================================
      # ArgoCD Application Controller (Sync Engine)
      # ==========================================================================
      controller = {
        replicas = var.controller_replicas  # 1 for homelab

        resources = {
          limits = {
            cpu    = var.controller_cpu_limit       # 500m
            memory = var.controller_memory_limit    # 512Mi
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }

        # Prometheus metrics exposure
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = var.enable_prometheus_metrics
          }
        }
      }

      # ==========================================================================
      # Redis (Caching Layer)
      # ==========================================================================
      redis = {
        enabled = true  # Embedded Redis (not HA for homelab)

        resources = {
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      }

      # ==========================================================================
      # Dex (OIDC Provider) - Disabled
      # ==========================================================================
      # Cloudflare Access handles authentication via Google OAuth
      dex = {
        enabled = false
      }

      # ==========================================================================
      # ArgoCD Configuration
      # ==========================================================================
      configs = {
        cm = {
          # Repository polling interval (3 minutes)
          "timeout.reconciliation" = var.repository_polling_interval  # 180s

          # Custom health checks for CRDs
          # Format: resource.customizations as multiline YAML string
          "resource.customizations" = <<-YAML
            traefik.io/IngressRoute:
              health.lua: |
                hs = {}
                hs.status = "Healthy"
                return hs
            cert-manager.io/Certificate:
              health.lua: |
                hs = {}
                if obj.status ~= nil then
                  if obj.status.conditions ~= nil then
                    for i, condition in ipairs(obj.status.conditions) do
                      if condition.type == "Ready" and condition.status == "False" then
                        hs.status = "Degraded"
                        hs.message = condition.message
                        return hs
                      end
                      if condition.type == "Ready" and condition.status == "True" then
                        hs.status = "Healthy"
                        hs.message = condition.message
                        return hs
                      end
                    end
                  end
                end
                hs.status = "Progressing"
                hs.message = "Waiting for certificate"
                return hs
          YAML
        }
      }
    })
  ]

  # Dependency: Ensure namespace exists before deploying Helm chart
  depends_on = []
}
