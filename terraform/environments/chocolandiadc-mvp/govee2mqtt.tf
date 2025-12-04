# Govee2MQTT Integration - Environment Configuration
# Feature: 019-govee2mqtt
# Deploys Mosquitto MQTT broker and govee2mqtt bridge

# ============================================================================
# Mosquitto MQTT Broker
# ============================================================================

module "mosquitto" {
  source = "../../modules/mosquitto"

  namespace     = "home-assistant"
  app_name      = "mosquitto"
  image         = "eclipse-mosquitto:2.0.18"
  storage_size  = "1Gi"
  storage_class = "local-path"
  service_port  = 1883

  resources = {
    requests = {
      memory = "64Mi"
      cpu    = "50m"
    }
    limits = {
      memory = "128Mi"
      cpu    = "200m"
    }
  }

  allow_anonymous     = true
  persistence_enabled = true
}

# ============================================================================
# Govee2MQTT Bridge (added after Mosquitto is deployed)
# ============================================================================

module "govee2mqtt" {
  source = "../../modules/govee2mqtt"

  depends_on = [module.mosquitto]

  namespace = "home-assistant"
  app_name  = "govee2mqtt"
  image     = "ghcr.io/wez/govee2mqtt:latest"

  # Govee credentials (from environment variable)
  govee_api_key = var.govee_api_key

  # MQTT broker connection (using ClusterIP for hostNetwork compatibility)
  mqtt_host = module.mosquitto.cluster_ip
  mqtt_port = module.mosquitto.service_port

  timezone = "America/Asuncion"

  resources = {
    requests = {
      memory = "64Mi"
      cpu    = "50m"
    }
    limits = {
      memory = "256Mi"
      cpu    = "500m"
    }
  }
}

# ============================================================================
# Variables
# ============================================================================

variable "govee_api_key" {
  description = "Govee API key for device access"
  type        = string
  sensitive   = true
}

# Optional: Govee account credentials for IoT features
variable "govee_email" {
  description = "Govee account email (optional, for IoT features)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "govee_password" {
  description = "Govee account password (optional, for IoT features)"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================================
# Outputs
# ============================================================================

output "mosquitto_service_host" {
  description = "Mosquitto MQTT broker hostname"
  value       = module.mosquitto.service_host
}

output "mosquitto_service_port" {
  description = "Mosquitto MQTT broker port"
  value       = module.mosquitto.service_port
}

output "govee2mqtt_namespace" {
  description = "Namespace where govee2mqtt is deployed"
  value       = module.govee2mqtt.namespace
}

output "govee2mqtt_deployment" {
  description = "govee2mqtt deployment name"
  value       = module.govee2mqtt.deployment_name
}
