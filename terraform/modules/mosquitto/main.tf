# Mosquitto MQTT Broker Module - Main Resources
# Feature: 019-govee2mqtt
# Scope: MQTT broker for govee2mqtt and Home Assistant communication

# ============================================================================
# ConfigMap - Mosquitto Configuration
# ============================================================================

resource "kubernetes_config_map" "mosquitto_config" {
  metadata {
    name      = "${var.app_name}-config"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"      = var.app_name
      "app.kubernetes.io/component" = "mqtt-broker"
    }
  }

  data = {
    "mosquitto.conf" = <<-EOF
      # Listener configuration
      listener ${var.service_port}
      protocol mqtt

      # Authentication
      allow_anonymous ${var.allow_anonymous}

      # Persistence - disabled to avoid permission issues
      persistence false

      # Logging
      log_dest stdout
      log_type error
      log_type warning
      log_type notice
      log_type information

      # Connection settings
      max_keepalive 300
      max_inflight_messages 0
      max_queued_messages 1000
      EOF
  }
}

# ============================================================================
# PersistentVolumeClaim - Data Storage
# ============================================================================

resource "kubernetes_persistent_volume_claim" "mosquitto_data" {
  wait_until_bound = false # local-path binds on first pod mount

  metadata {
    name      = "${var.app_name}-data"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name" = var.app_name
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
}

# ============================================================================
# Deployment
# ============================================================================

resource "kubernetes_deployment" "mosquitto" {
  metadata {
    name      = var.app_name
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"      = var.app_name
      "app.kubernetes.io/component" = "mqtt-broker"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate" # PVC can only be mounted by one pod
    }

    selector {
      match_labels = {
        "app.kubernetes.io/name" = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = var.app_name
          "app.kubernetes.io/component" = "mqtt-broker"
        }
      }

      spec {
        # Init container to fix permissions on data directory
        init_container {
          name  = "fix-permissions"
          image = "busybox:latest"
          command = ["sh", "-c", "chown -R 1883:1883 /mosquitto/data && chmod -R 755 /mosquitto/data"]

          volume_mount {
            name       = "data"
            mount_path = "/mosquitto/data"
          }

          security_context {
            run_as_user = 0
          }
        }

        container {
          name  = var.app_name
          image = var.image

          port {
            name           = "mqtt"
            container_port = var.service_port
            protocol       = "TCP"
          }

          volume_mount {
            name       = "config"
            mount_path = "/mosquitto/config"
          }

          volume_mount {
            name       = "data"
            mount_path = "/mosquitto/data"
          }

          resources {
            requests = {
              memory = var.resources.requests.memory
              cpu    = var.resources.requests.cpu
            }
            limits = {
              memory = var.resources.limits.memory
              cpu    = var.resources.limits.cpu
            }
          }

          liveness_probe {
            tcp_socket {
              port = var.service_port
            }
            initial_delay_seconds = 10
            period_seconds        = 30
            timeout_seconds       = 5
          }

          readiness_probe {
            tcp_socket {
              port = var.service_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 3
          }

          security_context {
            run_as_user                = 1883
            run_as_group               = 1883
            run_as_non_root            = true
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.mosquitto_config.metadata[0].name
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mosquitto_data.metadata[0].name
          }
        }

        restart_policy = "Always"
      }
    }
  }
}

# ============================================================================
# Service (ClusterIP)
# ============================================================================

resource "kubernetes_service" "mosquitto" {
  metadata {
    name      = var.app_name
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"      = var.app_name
      "app.kubernetes.io/component" = "mqtt-broker"
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "mqtt"
      port        = var.service_port
      target_port = var.service_port
      protocol    = "TCP"
    }

    selector = {
      "app.kubernetes.io/name" = var.app_name
    }
  }
}
