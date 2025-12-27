# MetalLB Module Contract
# Purpose: Define the expected interface for the refactored MetalLB module
# Version: 2.0.0 (post-refactor)

# =============================================================================
# Input Variables Contract
# =============================================================================

variable "chart_version" {
  description = "MetalLB Helm chart version"
  type        = string
  default     = "0.15.3"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "Chart version must be semantic version (e.g., 0.15.3)."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for MetalLB deployment"
  type        = string
  default     = "metallb-system"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.namespace))
    error_message = "Namespace must be a valid Kubernetes namespace name."
  }
}

variable "pool_name" {
  description = "Name of the IP address pool"
  type        = string
  default     = "eero-pool"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.pool_name))
    error_message = "Pool name must be a valid Kubernetes resource name."
  }
}

variable "ip_range" {
  description = "IP range for LoadBalancer services (e.g., 192.168.4.200-192.168.4.210)"
  type        = string

  validation {
    condition = can(regex(
      "^([0-9]{1,3}\\.){3}[0-9]{1,3}-([0-9]{1,3}\\.){3}[0-9]{1,3}$|^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$",
      var.ip_range
    ))
    error_message = "IP range must be in format '192.168.4.200-192.168.4.210' or CIDR '192.168.4.0/24'."
  }
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

# =============================================================================
# Output Contract
# =============================================================================

output "namespace" {
  description = "Namespace where MetalLB is deployed"
  value       = var.namespace
}

output "chart_version" {
  description = "Deployed MetalLB Helm chart version"
  value       = var.chart_version
}

output "ip_range" {
  description = "Configured IP range for LoadBalancer services"
  value       = var.ip_range
}

output "pool_name" {
  description = "Name of the IP address pool"
  value       = var.pool_name
}

# =============================================================================
# Resource Dependencies Contract
# =============================================================================

# Execution order:
# 1. helm_release.metallb      - Deploy MetalLB controller and CRDs
# 2. time_sleep.wait_for_crds  - Wait for CRDs to be registered
# 3. kubernetes_manifest.ip_address_pool   - Create IPAddressPool
# 4. kubernetes_manifest.l2_advertisement  - Create L2Advertisement

# =============================================================================
# Provider Requirements Contract
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}
