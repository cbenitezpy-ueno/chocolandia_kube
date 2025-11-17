# ============================================================================
# Claim Blocker Pod and Service
# Intercepts /api/v3/claim requests to prevent Netdata Cloud authentication
# ============================================================================

# ============================================================================
# ConfigMap for nginx configuration
# ============================================================================

resource "kubernetes_config_map" "claim_blocker" {
  metadata {
    name      = "claim-blocker-config"
    namespace = kubernetes_namespace.netdata.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "netdata"
      "app.kubernetes.io/component"  = "claim-blocker"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "default.conf" = <<-EOT
      server {
          listen 80;
          location / {
              return 200 '{"status": "ok"}';
              add_header Content-Type application/json;
          }
      }
    EOT
  }

  depends_on = [kubernetes_namespace.netdata]
}

# ============================================================================
# Claim Blocker Pod
# ============================================================================

resource "kubernetes_pod" "claim_blocker" {
  metadata {
    name      = "claim-blocker"
    namespace = kubernetes_namespace.netdata.metadata[0].name
    labels = {
      "app"                          = "claim-blocker"
      "app.kubernetes.io/name"       = "netdata"
      "app.kubernetes.io/component"  = "claim-blocker"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    container {
      name  = "nginx"
      image = "nginx:alpine"

      port {
        container_port = 80
      }

      volume_mount {
        name       = "config"
        mount_path = "/etc/nginx/conf.d/default.conf"
        sub_path   = "default.conf"
      }
    }

    volume {
      name = "config"
      config_map {
        name = kubernetes_config_map.claim_blocker.metadata[0].name
      }
    }
  }

  depends_on = [kubernetes_config_map.claim_blocker]
}

# ============================================================================
# Claim Blocker Service
# ============================================================================

resource "kubernetes_service" "claim_blocker" {
  metadata {
    name      = "netdata-claim-blocker"
    namespace = kubernetes_namespace.netdata.metadata[0].name
    labels = {
      "app"                          = "claim-blocker"
      "app.kubernetes.io/name"       = "netdata"
      "app.kubernetes.io/component"  = "claim-blocker"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    selector = {
      app = "claim-blocker"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_pod.claim_blocker]
}
