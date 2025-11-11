# Traefik Module Variables
# Feature 005: Traefik Ingress Controller

variable "release_name" {
  description = "Helm release name for Traefik"
  type        = string
  default     = "traefik"
}

variable "chart_version" {
  description = "Traefik Helm chart version"
  type        = string
  default     = "30.0.2"  # Traefik v3.2.0
}

variable "namespace" {
  description = "Kubernetes namespace for Traefik deployment"
  type        = string
  default     = "traefik"
}

variable "replicas" {
  description = "Number of Traefik replicas for HA"
  type        = number
  default     = 2

  validation {
    condition     = var.replicas >= 2
    error_message = "Replicas must be at least 2 for HA (constitution requirement)."
  }
}

variable "loadbalancer_ip" {
  description = "Static LoadBalancer IP from MetalLB pool"
  type        = string
  default     = "192.168.4.201"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.loadbalancer_ip))
    error_message = "LoadBalancer IP must be a valid IPv4 address."
  }
}

variable "resources_requests_cpu" {
  description = "CPU resource request for Traefik pods"
  type        = string
  default     = "100m"
}

variable "resources_requests_memory" {
  description = "Memory resource request for Traefik pods"
  type        = string
  default     = "128Mi"
}

variable "resources_limits_cpu" {
  description = "CPU resource limit for Traefik pods"
  type        = string
  default     = "500m"
}

variable "resources_limits_memory" {
  description = "Memory resource limit for Traefik pods"
  type        = string
  default     = "256Mi"
}
