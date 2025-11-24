# Pi-hole Module - Main Configuration
# Deploys Pi-hole DNS ad blocker on K3s cluster using Kubernetes manifests

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# ============================================================================
# ConfigMap for Custom DNS Records
# ============================================================================

resource "kubernetes_config_map" "pihole_custom_dns" {
  metadata {
    name      = "pihole-custom-dns"
    namespace = var.namespace

    labels = {
      app = "pihole"
    }
  }

  data = {
    "02-custom.conf" = <<-EOT
      # Custom DNS records for local services
      # Format: address=/domain/ip
      # All services point to Traefik LoadBalancer IP: 192.168.4.202

      # ============================================
      # Production Services (.chocolandiadc.com)
      # ============================================
      # MinIO S3 API - accessible via Traefik on private network
      address=/s3.chocolandiadc.com/192.168.4.202

      # ============================================
      # Local Network Services (.chocolandiadc.local)
      # ============================================
      # Core Infrastructure
      address=/argocd.chocolandiadc.local/192.168.4.202
      address=/grafana.chocolandiadc.local/192.168.4.202
      address=/headlamp.chocolandiadc.local/192.168.4.202
      address=/homepage.chocolandiadc.local/192.168.4.202
      address=/longhorn.chocolandiadc.local/192.168.4.202
      address=/pihole.chocolandiadc.local/192.168.4.202
      address=/ntfy.chocolandiadc.local/192.168.4.202

      # Storage Services
      address=/minio.chocolandiadc.local/192.168.4.202

      # Applications
      address=/beer.chocolandiadc.local/192.168.4.202

      # Dev Tools - Local Container Registry
      address=/registry.chocolandiadc.local/192.168.4.202
      address=/registry-ui.chocolandiadc.local/192.168.4.202

      # Dev Tools - LocalStack (AWS emulation)
      address=/localstack.chocolandiadc.local/192.168.4.202
    EOT
  }
}

# ============================================================================
# Kubernetes Secret for Admin Password
# ============================================================================

resource "kubernetes_secret" "pihole_admin_password" {
  metadata {
    name      = "pihole-admin-password"
    namespace = var.namespace

    labels = {
      app = "pihole"
    }
  }

  type = "Opaque"

  data = {
    password = base64encode(var.admin_password)
  }
}

# ============================================================================
# PersistentVolumeClaim for Pi-hole Configuration
# ============================================================================

resource "kubernetes_persistent_volume_claim" "pihole_config" {
  metadata {
    name      = "pihole-config"
    namespace = var.namespace

    labels = {
      app = "pihole"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }

  # Do NOT wait for PVC to be bound (local-path storage class waits for first consumer)
  wait_until_bound = false
}

# ============================================================================
# Pi-hole Deployment
# ============================================================================

resource "kubernetes_deployment" "pihole" {
  metadata {
    name      = "pihole"
    namespace = var.namespace

    labels = {
      app = "pihole"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "pihole"
      }
    }

    template {
      metadata {
        labels = {
          app = "pihole"
        }
      }

      spec {
        container {
          name              = "pihole"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          # Environment Variables
          env {
            name  = "TZ"
            value = var.timezone
          }

          env {
            name = "FTLCONF_webserver_api_password"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.pihole_admin_password.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name  = "FTLCONF_dns_upstreams"
            value = var.upstream_dns
          }

          env {
            name  = "FTLCONF_dns_listeningMode"
            value = "all"
          }

          # Custom DNS hosts for local services (Pi-hole v6 format)
          # Format: "IP HOSTNAME" entries separated by semicolons
          env {
            name  = "FTLCONF_dns_hosts"
            value = join(";", var.custom_dns_hosts)
          }

          env {
            name  = "PIHOLE_UID"
            value = "1000"
          }

          env {
            name  = "PIHOLE_GID"
            value = "1000"
          }

          # Ports (no hostPort needed with hostNetwork)
          port {
            name           = "dns-tcp"
            container_port = 53
            protocol       = "TCP"
          }

          port {
            name           = "dns-udp"
            container_port = 53
            protocol       = "UDP"
          }

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          # Volume Mounts
          volume_mount {
            name       = "pihole-config"
            mount_path = "/etc/pihole"
          }

          volume_mount {
            name       = "custom-dns"
            mount_path = "/etc/dnsmasq.d/02-custom.conf"
            sub_path   = "02-custom.conf"
          }

          # Security Context
          security_context {
            capabilities {
              add = ["NET_BIND_SERVICE"]
            }
          }

          # Liveness Probe
          liveness_probe {
            http_get {
              path = "/admin/"
              port = 80
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 10
          }

          # Readiness Probe
          readiness_probe {
            http_get {
              path = "/admin/"
              port = 80
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          # Resource Limits
          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }
        }

        # Volumes
        volume {
          name = "pihole-config"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.pihole_config.metadata[0].name
          }
        }

        volume {
          name = "custom-dns"
          config_map {
            name = kubernetes_config_map.pihole_custom_dns.metadata[0].name
          }
        }

        # DNS Configuration (prevents DNS loop)
        dns_config {
          nameservers = ["8.8.8.8", "1.1.1.1"]
        }
      }
    }
  }

  # Wait for deployment to be ready
  wait_for_rollout = true

  # Ensure PVC, Secret and ConfigMap exist first
  depends_on = [
    kubernetes_persistent_volume_claim.pihole_config,
    kubernetes_secret.pihole_admin_password,
    kubernetes_config_map.pihole_custom_dns
  ]
}

# ============================================================================
# DNS Service (LoadBalancer)
# ============================================================================

resource "kubernetes_service" "pihole_dns" {
  metadata {
    name      = "pihole-dns"
    namespace = var.namespace

    labels = {
      app = "pihole"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "pihole"
    }

    port {
      name        = "dns-tcp"
      port        = 53
      target_port = 53
      protocol    = "TCP"
    }

    port {
      name        = "dns-udp"
      port        = 53
      target_port = 53
      protocol    = "UDP"
    }

    external_traffic_policy = "Local"
  }

  # Ensure deployment exists first
  depends_on = [kubernetes_deployment.pihole]
}

# ============================================================================
# Web Admin Service (NodePort)
# ============================================================================

resource "kubernetes_service" "pihole_web" {
  metadata {
    name      = "pihole-web"
    namespace = var.namespace

    labels = {
      app = "pihole"
    }
  }

  spec {
    type = "NodePort"

    selector = {
      app = "pihole"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      node_port   = var.web_nodeport
      protocol    = "TCP"
    }

    external_traffic_policy = "Local"
  }

  # Ensure deployment exists first
  depends_on = [kubernetes_deployment.pihole]
}
