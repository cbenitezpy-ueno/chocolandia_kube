# ==============================================================================
# Required Variables
# ==============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Headlamp deployment"
  type        = string
  default     = "headlamp"
}

variable "domain" {
  description = "Domain name for Headlamp (e.g., headlamp.chocolandiadc.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.domain))
    error_message = "Domain must be a valid DNS name"
  }
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID for Zero Trust Access configuration (Phase 6 - US4)"
  type        = string
  default     = "" # Optional until Phase 6
}

variable "google_oauth_idp_id" {
  description = "Google OAuth identity provider ID for Cloudflare Access (Phase 6 - US4)"
  type        = string
  sensitive   = true
  default     = "" # Optional until Phase 6
}

variable "authorized_emails" {
  description = "List of authorized email addresses for Cloudflare Access policy (Phase 6 - US4)"
  type        = list(string)
  default     = [] # Optional until Phase 6
}

# ==============================================================================
# Optional Variables - Deployment Configuration
# ==============================================================================

variable "replicas" {
  description = "Number of Headlamp pod replicas for high availability"
  type        = number
  default     = 2

  validation {
    condition     = var.replicas >= 1
    error_message = "Replicas must be at least 1"
  }
}

variable "chart_version" {
  description = "Headlamp Helm chart version"
  type        = string
  default     = "0.38.0"
}

variable "chart_repository" {
  description = "Headlamp Helm chart repository URL"
  type        = string
  default     = "https://kubernetes-sigs.github.io/headlamp/"
}

# ==============================================================================
# Optional Variables - Resource Limits
# ==============================================================================

variable "cpu_request" {
  description = "CPU request for Headlamp pods"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request for Headlamp pods"
  type        = string
  default     = "128Mi"
}

variable "cpu_limit" {
  description = "CPU limit for Headlamp pods"
  type        = string
  default     = "200m"
}

variable "memory_limit" {
  description = "Memory limit for Headlamp pods"
  type        = string
  default     = "256Mi"
}

# ==============================================================================
# Optional Variables - TLS/Certificate Configuration
# ==============================================================================

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer name for TLS certificate"
  type        = string
  default     = "letsencrypt-production"
}

variable "certificate_duration" {
  description = "TLS certificate duration (e.g., 2160h = 90 days)"
  type        = string
  default     = "2160h"
}

variable "certificate_renew_before" {
  description = "Renew certificate before expiration (e.g., 720h = 30 days)"
  type        = string
  default     = "720h"
}

# ==============================================================================
# Optional Variables - Monitoring
# ==============================================================================

variable "prometheus_url" {
  description = "Prometheus server URL for metrics integration (empty to disable)"
  type        = string
  default     = ""
}

# ==============================================================================
# Optional Variables - Cloudflare Access
# ==============================================================================

variable "access_session_duration" {
  description = "Cloudflare Access session duration (e.g., 24h, 12h, 8h)"
  type        = string
  default     = "24h"
}

variable "access_auto_redirect" {
  description = "Automatically redirect to identity provider (Google OAuth)"
  type        = bool
  default     = true
}

variable "access_app_launcher_visible" {
  description = "Show application in Cloudflare Access App Launcher"
  type        = bool
  default     = true
}

# ==============================================================================
# Optional Variables - High Availability
# ==============================================================================

variable "pdb_enabled" {
  description = "Enable PodDisruptionBudget for high availability"
  type        = bool
  default     = true
}

variable "pdb_min_available" {
  description = "Minimum available pods for PodDisruptionBudget"
  type        = number
  default     = 1
}

variable "enable_pod_anti_affinity" {
  description = "Enable pod anti-affinity to spread replicas across nodes"
  type        = bool
  default     = true
}

# ==============================================================================
# Optional Variables - OIDC Authentication
# ==============================================================================

variable "enable_oidc" {
  description = "Enable OIDC authentication for Headlamp (requires K3s API server OIDC configuration)"
  type        = bool
  default     = true
}

variable "oidc_client_id" {
  description = "OIDC client ID (Google OAuth Client ID)"
  type        = string
  default     = ""
}

variable "oidc_client_secret" {
  description = "OIDC client secret (Google OAuth Client Secret)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL (e.g., https://accounts.google.com)"
  type        = string
  default     = "https://accounts.google.com"
}

variable "oidc_scopes" {
  description = "OIDC scopes to request"
  type        = string
  default     = "email,profile,openid"
}

# ==============================================================================
# Optional Variables - RBAC for Cloudflare Access Users
# ==============================================================================

variable "cloudflare_access_email" {
  description = "Email address of the user authenticated via Cloudflare Access (for RBAC)"
  type        = string
  default     = "cbenitez@gmail.com"
}
