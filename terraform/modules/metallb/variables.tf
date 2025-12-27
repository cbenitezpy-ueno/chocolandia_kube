# ============================================================================
# MetalLB Module Variables
# ============================================================================

variable "chart_version" {
  description = "MetalLB Helm chart version"
  type        = string
  default     = "0.15.3"  # Upgraded from 0.14.8
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
