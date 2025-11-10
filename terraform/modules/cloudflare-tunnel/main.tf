# Kubernetes Resources for Cloudflare Tunnel
# Feature 004: Cloudflare Zero Trust VPN Access

# ============================================================================
# Namespace
# ============================================================================

# Create dedicated namespace for Cloudflare Tunnel
resource "kubernetes_namespace" "cloudflare_tunnel" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cloudflare-tunnel"
      "app.kubernetes.io/component"  = "tunnel"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "description" = "Namespace for Cloudflare Zero Trust Tunnel (Feature 004)"
    }
  }
}

# ============================================================================
# Secret
# ============================================================================

# Store tunnel credentials as Kubernetes Secret
resource "kubernetes_secret" "tunnel_credentials" {
  metadata {
    name      = "cloudflared-credentials"
    namespace = kubernetes_namespace.cloudflare_tunnel.metadata[0].name

    labels = {
      "app.kubernetes.io/name"       = "cloudflare-tunnel"
      "app.kubernetes.io/component"  = "credentials"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    # Tunnel credentials in JSON format required by cloudflared
    "credentials.json" = jsonencode({
      AccountTag   = var.cloudflare_account_id
      TunnelID     = cloudflare_zero_trust_tunnel_cloudflared.main.id
      TunnelName   = cloudflare_zero_trust_tunnel_cloudflared.main.name
      TunnelSecret = base64encode(random_password.tunnel_secret.result)
    })
  }

  type = "Opaque"
}

# ============================================================================
# Deployment
# ============================================================================

# Deploy cloudflared as a Kubernetes Deployment
resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.cloudflare_tunnel.metadata[0].name

    labels = {
      "app.kubernetes.io/name"       = "cloudflare-tunnel"
      "app.kubernetes.io/component"  = "tunnel-daemon"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "description" = "Cloudflared tunnel daemon for secure remote access"
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        "app" = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          "app"                          = "cloudflared"
          "app.kubernetes.io/name"       = "cloudflare-tunnel"
          "app.kubernetes.io/component"  = "tunnel-daemon"
          "app.kubernetes.io/managed-by" = "terraform"
        }

        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "2000"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        # ====================================================================
        # Container Specification
        # ====================================================================

        container {
          name              = "cloudflared"
          image             = var.cloudflared_image
          image_pull_policy = "IfNotPresent"

          # Command: run tunnel with credentials from secret
          args = [
            "tunnel",
            "--no-autoupdate",
            "--metrics",
            "0.0.0.0:2000",
            "--credentials-file",
            "/etc/cloudflared/credentials.json",
            "run",
            cloudflare_zero_trust_tunnel_cloudflared.main.id
          ]

          # ================================================================
          # Resource Limits
          # ================================================================

          resources {
            limits = {
              cpu    = var.resource_limits_cpu
              memory = var.resource_limits_memory
            }
            requests = {
              cpu    = var.resource_requests_cpu
              memory = var.resource_requests_memory
            }
          }

          # ================================================================
          # Health Checks
          # ================================================================

          # Liveness probe: restart container if unhealthy
          liveness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Readiness probe: remove from service if not ready
          readiness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          # ================================================================
          # Volume Mounts
          # ================================================================

          volume_mount {
            name       = "credentials"
            mount_path = "/etc/cloudflared"
            read_only  = true
          }

          # ================================================================
          # Security Context
          # ================================================================

          security_context {
            run_as_non_root            = true
            run_as_user                = 65532 # nonroot user
            allow_privilege_escalation = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }
        }

        # ====================================================================
        # Volumes
        # ====================================================================

        volume {
          name = "credentials"
          secret {
            secret_name = kubernetes_secret.tunnel_credentials.metadata[0].name
            items {
              key  = "credentials.json"
              path = "credentials.json"
            }
          }
        }

        # ====================================================================
        # Pod Security
        # ====================================================================

        security_context {
          run_as_non_root = true
          run_as_user     = 65532
          fs_group        = 65532
        }

        # DNS Configuration (prevents DNS loop during initial image pull)
        dns_config {
          nameservers = ["8.8.8.8", "1.1.1.1"]
        }

        # Restart policy
        restart_policy = "Always"
      }
    }

    # ======================================================================
    # Deployment Strategy
    # ======================================================================

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_unavailable = 1
        max_surge       = 1
      }
    }
  }

  # Wait for deployment to be ready before completing
  wait_for_rollout = true

  # Cleanup on destroy
  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# Pod Disruption Budget
# ============================================================================

# Ensure at least 1 pod is always available during voluntary disruptions
# (e.g., node drains, updates, scaling operations)
resource "kubernetes_pod_disruption_budget_v1" "cloudflared" {
  metadata {
    name      = "cloudflared-pdb"
    namespace = kubernetes_namespace.cloudflare_tunnel.metadata[0].name

    labels = {
      "app.kubernetes.io/name"       = "cloudflare-tunnel"
      "app.kubernetes.io/component"  = "pdb"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    min_available = 1

    selector {
      match_labels = {
        "app" = "cloudflared"
      }
    }
  }
}
