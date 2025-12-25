# Home Assistant Module Variables
# Feature: 018-home-assistant
# Scope: Phase 1 - Base Installation + Prometheus Integration

variable "namespace" {
  description = "Kubernetes namespace for Home Assistant"
  type        = string
  default     = "home-assistant"
}

variable "app_name" {
  description = "Application name for labeling"
  type        = string
  default     = "home-assistant"
}

variable "image" {
  description = "Home Assistant container image"
  type        = string
  default     = "ghcr.io/home-assistant/home-assistant:2025.12.4"  # Pinned from :stable
}

variable "timezone" {
  description = "Timezone for Home Assistant"
  type        = string
  default     = "America/Chicago"
}

variable "storage_size" {
  description = "PVC storage size for config"
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "Storage class for PVC"
  type        = string
  default     = "local-path"
}

variable "local_domain" {
  description = "Local domain for Home Assistant (uses local-ca)"
  type        = string
  default     = "homeassistant.chocolandiadc.local"
}

variable "external_domain" {
  description = "External domain for Home Assistant (uses Let's Encrypt)"
  type        = string
  default     = "homeassistant.chocolandiadc.com"
}

variable "local_cluster_issuer" {
  description = "cert-manager ClusterIssuer for local domain"
  type        = string
  default     = "local-ca"
}

variable "external_cluster_issuer" {
  description = "cert-manager ClusterIssuer for external domain"
  type        = string
  default     = "letsencrypt-production"
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "service_port" {
  description = "Home Assistant service port"
  type        = number
  default     = 8123
}

variable "resources" {
  description = "Container resource requests and limits"
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
      memory = "512Mi"
      cpu    = "250m"
    }
    limits = {
      memory = "2Gi"
      cpu    = "2000m"
    }
  }
}
