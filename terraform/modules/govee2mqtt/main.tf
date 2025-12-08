# Govee2MQTT Module - Main Resources
# Feature: 019-govee2mqtt
# Scope: Bridge between Govee devices and Home Assistant via MQTT

# ============================================================================
# Kubernetes Secret - Govee Credentials
# ============================================================================

resource "kubernetes_secret" "govee_credentials" {
  metadata {
    name      = "${var.app_name}-credentials"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"      = var.app_name
      "app.kubernetes.io/component" = "iot-bridge"
    }
  }

  data = {
    GOVEE_API_KEY = var.govee_api_key
  }

  type = "Opaque"
}

# ============================================================================
# Deployment
# ============================================================================

resource "kubernetes_deployment" "govee2mqtt" {
  metadata {
    name      = var.app_name
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"      = var.app_name
      "app.kubernetes.io/component" = "iot-bridge"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
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
          "app.kubernetes.io/component" = "iot-bridge"
        }
      }

      spec {
        # REQUIRED: hostNetwork for Govee LAN device discovery
        # govee2mqtt uses multicast/broadcast to find devices on local network
        # SECURITY NOTE: hostNetwork grants access to host's network namespace.
        # This is necessary for LAN discovery but increases attack surface.
        # Mitigations: dedicated namespace, no privileged mode, resource limits.
        host_network = true
        dns_policy   = "ClusterFirstWithHostNet"

        container {
          name  = var.app_name
          image = var.image

          env {
            name = "GOVEE_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.govee_credentials.metadata[0].name
                key  = "GOVEE_API_KEY"
              }
            }
          }

          # MQTT broker configuration
          env {
            name  = "GOVEE_MQTT_HOST"
            value = var.mqtt_host
          }

          env {
            name  = "GOVEE_MQTT_PORT"
            value = tostring(var.mqtt_port)
          }

          # Application settings
          env {
            name  = "TZ"
            value = var.timezone
          }

          env {
            name  = "GOVEE_TEMPERATURE_SCALE"
            value = var.temperature_scale
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

          # NOTE: Liveness probe removed because:
          # 1. govee2mqtt container is minimal (no pgrep, ls, or shell tools)
          # 2. No HTTP endpoint exposed for httpGet probe
          # 3. Kubernetes restart policy already handles container crashes
          # 4. Process is stable - if it fails, container exits and restarts
        }

        restart_policy = "Always"
      }
    }
  }
}
