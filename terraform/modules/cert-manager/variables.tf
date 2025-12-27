# Namespace configuration
variable "namespace" {
  description = "Kubernetes namespace for cert-manager"
  type        = string
  default     = "cert-manager"
}

# Helm chart configuration
variable "chart_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.19.2"
}

# ACME configuration
variable "acme_email" {
  description = "Email address for Let's Encrypt ACME account notifications"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.acme_email))
    error_message = "acme_email must be a valid email address format"
  }
}

# ClusterIssuer configuration
variable "enable_staging" {
  description = "Create staging ClusterIssuer for Let's Encrypt (recommended for testing)"
  type        = bool
  default     = true
}

variable "enable_production" {
  description = "Create production ClusterIssuer for Let's Encrypt (trusted certificates)"
  type        = bool
  default     = true
}

# Monitoring configuration
variable "enable_metrics" {
  description = "Enable Prometheus metrics endpoints for cert-manager components"
  type        = bool
  default     = true
}

variable "enable_servicemonitor" {
  description = "Enable ServiceMonitor for Prometheus Operator (requires Prometheus Operator)"
  type        = bool
  default     = false
}

# High availability configuration
variable "controller_replicas" {
  description = "Number of cert-manager controller replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.controller_replicas >= 1 && var.controller_replicas <= 5
    error_message = "controller_replicas must be between 1 and 5"
  }
}

variable "webhook_replicas" {
  description = "Number of cert-manager webhook replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.webhook_replicas >= 1 && var.webhook_replicas <= 5
    error_message = "webhook_replicas must be between 1 and 5"
  }
}

variable "cainjector_replicas" {
  description = "Number of cert-manager cainjector replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.cainjector_replicas >= 1 && var.cainjector_replicas <= 5
    error_message = "cainjector_replicas must be between 1 and 5"
  }
}

# Resource limits
variable "controller_cpu_request" {
  description = "CPU request for controller pod"
  type        = string
  default     = "10m"
}

variable "controller_memory_request" {
  description = "Memory request for controller pod"
  type        = string
  default     = "32Mi"
}

variable "controller_cpu_limit" {
  description = "CPU limit for controller pod"
  type        = string
  default     = "100m"
}

variable "controller_memory_limit" {
  description = "Memory limit for controller pod"
  type        = string
  default     = "128Mi"
}

variable "webhook_cpu_request" {
  description = "CPU request for webhook pod"
  type        = string
  default     = "10m"
}

variable "webhook_memory_request" {
  description = "Memory request for webhook pod"
  type        = string
  default     = "32Mi"
}

variable "webhook_cpu_limit" {
  description = "CPU limit for webhook pod"
  type        = string
  default     = "100m"
}

variable "webhook_memory_limit" {
  description = "Memory limit for webhook pod"
  type        = string
  default     = "128Mi"
}

variable "cainjector_cpu_request" {
  description = "CPU request for cainjector pod"
  type        = string
  default     = "10m"
}

variable "cainjector_memory_request" {
  description = "Memory request for cainjector pod"
  type        = string
  default     = "32Mi"
}

variable "cainjector_cpu_limit" {
  description = "CPU limit for cainjector pod"
  type        = string
  default     = "100m"
}

variable "cainjector_memory_limit" {
  description = "Memory limit for cainjector pod"
  type        = string
  default     = "128Mi"
}

# Cloudflare DNS-01 challenge configuration
variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS-01 challenge (optional, enables DNS-01 if provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_email" {
  description = "Cloudflare account email (required if cloudflare_api_token is provided)"
  type        = string
  default     = ""
}
