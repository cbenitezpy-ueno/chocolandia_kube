# Mosquitto MQTT Broker Module - Variables
# Feature: 019-govee2mqtt

variable "namespace" {
  description = "Kubernetes namespace for Mosquitto deployment"
  type        = string
  default     = "home-assistant"
}

variable "app_name" {
  description = "Application name for labels and resource naming"
  type        = string
  default     = "mosquitto"
}

variable "image" {
  description = "Mosquitto Docker image"
  type        = string
  default     = "eclipse-mosquitto:2.0.18"
}

variable "storage_size" {
  description = "PersistentVolumeClaim storage size"
  type        = string
  default     = "1Gi"
}

variable "storage_class" {
  description = "Kubernetes StorageClass for PVC"
  type        = string
  default     = "local-path"
}

variable "service_port" {
  description = "MQTT service port"
  type        = number
  default     = 1883
}

variable "resources" {
  description = "Resource requests and limits for Mosquitto container"
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
      memory = "128Mi"
      cpu    = "200m"
    }
  }
}

variable "allow_anonymous" {
  description = "Allow anonymous MQTT connections (true for internal cluster use)"
  type        = bool
  default     = true
}

variable "persistence_enabled" {
  description = "Enable message persistence"
  type        = bool
  default     = true
}
