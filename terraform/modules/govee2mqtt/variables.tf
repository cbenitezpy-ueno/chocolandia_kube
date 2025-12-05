# Govee2MQTT Module - Variables
# Feature: 019-govee2mqtt

variable "namespace" {
  description = "Kubernetes namespace for govee2mqtt deployment"
  type        = string
  default     = "home-assistant"
}

variable "app_name" {
  description = "Application name for labels and resource naming"
  type        = string
  default     = "govee2mqtt"
}

variable "image" {
  description = "govee2mqtt Docker image"
  type        = string
  default     = "ghcr.io/wez/govee2mqtt:2025.11.25-60a39bcc"
}

# ============================================================================
# Govee Credentials
# ============================================================================

variable "govee_api_key" {
  description = "Govee API key for Platform API access"
  type        = string
  sensitive   = true
}

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
# MQTT Configuration
# ============================================================================

variable "mqtt_host" {
  description = "MQTT broker hostname"
  type        = string
  default     = "mosquitto.home-assistant.svc.cluster.local"
}

variable "mqtt_port" {
  description = "MQTT broker port"
  type        = number
  default     = 1883
}

# ============================================================================
# Application Configuration
# ============================================================================

variable "timezone" {
  description = "Timezone for govee2mqtt"
  type        = string
  default     = "America/Asuncion"
}

variable "temperature_scale" {
  description = "Temperature scale (C or F)"
  type        = string
  default     = "C"

  validation {
    condition     = contains(["C", "F"], var.temperature_scale)
    error_message = "Temperature scale must be 'C' or 'F'."
  }
}

variable "resources" {
  description = "Resource requests and limits for govee2mqtt container"
  type = object({
    requests = object({
      memory = string
      cpu    = string
    })
    limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
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
