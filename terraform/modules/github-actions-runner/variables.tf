# GitHub Actions Runner Module - Variables
# T005: GitHub App credentials
# T011: Runner scale set variables (min/max, labels)
# T026: Scaling defaults

# =============================================================================
# Required Variables - GitHub App Credentials
# =============================================================================

variable "github_config_url" {
  description = "GitHub repository or organization URL (e.g., https://github.com/owner/repo)"
  type        = string

  validation {
    condition     = can(regex("^https://github.com/", var.github_config_url))
    error_message = "GitHub config URL must start with https://github.com/"
  }
}

variable "github_app_id" {
  description = "GitHub App ID"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9]+$", var.github_app_id))
    error_message = "GitHub App ID must be a numeric string"
  }
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9]+$", var.github_app_installation_id))
    error_message = "GitHub App Installation ID must be a numeric string"
  }
}

variable "github_app_private_key" {
  description = "GitHub App private key in PEM format"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^-----BEGIN", var.github_app_private_key))
    error_message = "GitHub App private key must be in PEM format (starting with -----BEGIN)"
  }
}

# =============================================================================
# Optional Variables - Namespace and Naming
# =============================================================================

variable "namespace" {
  description = "Kubernetes namespace for GitHub Actions runner resources"
  type        = string
  default     = "github-actions"
}

variable "runner_name" {
  description = "Name prefix for the runner scale set"
  type        = string
  default     = "homelab-runner"
}

# =============================================================================
# Optional Variables - Scaling Configuration (US3)
# =============================================================================

variable "min_runners" {
  description = "Minimum number of idle runners"
  type        = number
  default     = 1

  validation {
    condition     = var.min_runners >= 0
    error_message = "min_runners must be >= 0"
  }
}

variable "max_runners" {
  description = "Maximum number of concurrent runners"
  type        = number
  default     = 4

  validation {
    condition     = var.max_runners > 0
    error_message = "max_runners must be > 0"
  }
}

variable "runner_labels" {
  description = "Labels for runner identification in workflows"
  type        = list(string)
  default     = ["self-hosted", "linux", "x64", "homelab"]

  validation {
    condition     = contains(var.runner_labels, "self-hosted")
    error_message = "runner_labels must include 'self-hosted'"
  }
}

# =============================================================================
# Optional Variables - Resource Limits
# =============================================================================

variable "cpu_request" {
  description = "CPU request per runner pod"
  type        = string
  default     = "500m"
}

variable "memory_request" {
  description = "Memory request per runner pod"
  type        = string
  default     = "1Gi"
}

variable "cpu_limit" {
  description = "CPU limit per runner pod"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Memory limit per runner pod"
  type        = string
  default     = "4Gi"
}

# =============================================================================
# Optional Variables - ARC Configuration
# =============================================================================

variable "arc_controller_version" {
  description = "Version of ARC controller Helm chart"
  type        = string
  default     = "0.9.3"
}

variable "arc_runner_version" {
  description = "Version of ARC runner scale set Helm chart"
  type        = string
  default     = "0.9.3"
}

variable "enable_monitoring" {
  description = "Enable Prometheus ServiceMonitor and PrometheusRule"
  type        = bool
  default     = true
}
