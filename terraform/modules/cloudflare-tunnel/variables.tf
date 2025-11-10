# Cloudflare Tunnel Module Variables
# Feature 004: Cloudflare Zero Trust VPN Access

# ============================================================================
# Cloudflare Configuration
# ============================================================================

variable "tunnel_name" {
  description = "Human-readable name for the Cloudflare Tunnel"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.tunnel_name))
    error_message = "Tunnel name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string

  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.cloudflare_account_id))
    error_message = "Cloudflare Account ID must be a 32-character hexadecimal string."
  }
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for DNS record creation"
  type        = string

  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.cloudflare_zone_id))
    error_message = "Cloudflare Zone ID must be a 32-character hexadecimal string."
  }
}

variable "domain_name" {
  description = "Cloudflare-managed domain name (e.g., chocolandiadc.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid fully qualified domain name."
  }
}

# ============================================================================
# Kubernetes Configuration
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Cloudflare Tunnel deployment"
  type        = string
  default     = "cloudflare-tunnel"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "Namespace must follow Kubernetes naming conventions (lowercase alphanumeric with hyphens)."
  }
}

variable "replica_count" {
  description = "Number of cloudflared replicas (1 for MVP, 2+ for HA)"
  type        = number
  default     = 1

  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 10
    error_message = "Replica count must be between 1 and 10."
  }
}

variable "cloudflared_image" {
  description = "Cloudflared Docker image"
  type        = string
  default     = "cloudflare/cloudflared:latest"
}

variable "resource_limits_cpu" {
  description = "CPU limit for cloudflared pods"
  type        = string
  default     = "500m"
}

variable "resource_limits_memory" {
  description = "Memory limit for cloudflared pods"
  type        = string
  default     = "200Mi"
}

variable "resource_requests_cpu" {
  description = "CPU request for cloudflared pods"
  type        = string
  default     = "100m"
}

variable "resource_requests_memory" {
  description = "Memory request for cloudflared pods"
  type        = string
  default     = "100Mi"
}

# ============================================================================
# Ingress Configuration
# ============================================================================

variable "ingress_rules" {
  description = "List of ingress rules mapping public hostnames to internal Kubernetes services"
  type = list(object({
    hostname = string
    service  = string
  }))

  validation {
    condition     = length(var.ingress_rules) > 0
    error_message = "At least one ingress rule must be defined."
  }

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9-\\.]*[a-zA-Z0-9]$", rule.hostname))
    ])
    error_message = "All hostnames must be valid domain names."
  }

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      can(regex("^https?://", rule.service))
    ])
    error_message = "All services must start with http:// or https://."
  }
}

# ============================================================================
# Access Control Configuration
# ============================================================================

variable "google_oauth_client_id" {
  description = "Google OAuth 2.0 Client ID for Cloudflare Access"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+-[a-zA-Z0-9]+\\.apps\\.googleusercontent\\.com$", var.google_oauth_client_id))
    error_message = "Google OAuth Client ID must be in the format: <numbers>-<alphanumeric>.apps.googleusercontent.com"
  }
}

variable "google_oauth_client_secret" {
  description = "Google OAuth 2.0 Client Secret for Cloudflare Access"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.google_oauth_client_secret) > 0
    error_message = "Google OAuth Client Secret cannot be empty."
  }
}

variable "authorized_emails" {
  description = "List of email addresses authorized to access protected services via Cloudflare Access"
  type        = list(string)

  validation {
    condition     = length(var.authorized_emails) > 0
    error_message = "At least one authorized email must be specified."
  }

  validation {
    condition = alltrue([
      for email in var.authorized_emails :
      can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All authorized emails must be valid email addresses."
  }
}

variable "access_policy_name" {
  description = "Name for the Cloudflare Access policy"
  type        = string
  default     = "Email Authorization Policy"
}
