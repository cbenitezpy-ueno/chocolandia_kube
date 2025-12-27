# ============================================================================
# MetalLB Module Variables
# ============================================================================

variable "chart_version" {
  description = "MetalLB Helm chart version"
  type        = string
  default     = "0.15.3" # Upgraded from 0.14.8
}

variable "namespace" {
  description = "Kubernetes namespace for MetalLB"
  type        = string
  default     = "metallb-system"
}

variable "pool_name" {
  description = "Name of the IP address pool"
  type        = string
  default     = "eero-pool"
}

variable "ip_range" {
  description = "IP range for LoadBalancer services (e.g., 192.168.4.200-192.168.4.210)"
  type        = string
}

variable "crd_wait_duration" {
  description = "Duration to wait for CRDs after Helm release (e.g., '30s', '1m')"
  type        = string
  default     = "30s"

  validation {
    condition     = can(regex("^[0-9]+(s|m)$", var.crd_wait_duration))
    error_message = "Duration must be in format '30s' or '1m'."
  }
}
