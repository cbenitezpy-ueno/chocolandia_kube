# ============================================================================
# Netdata Module Variables
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Netdata deployment"
  type        = string
  default     = "netdata"
}

variable "chart_version" {
  description = "Netdata Helm chart version"
  type        = string
  default     = "3.7.151"
}

# ============================================================================
# Parent Node Resources (central UI + data aggregation)
# ============================================================================

variable "parent_cpu_request" {
  description = "CPU request for Netdata parent (central node)"
  type        = string
  default     = "200m"
}

variable "parent_memory_request" {
  description = "Memory request for Netdata parent"
  type        = string
  default     = "256Mi"
}

variable "parent_cpu_limit" {
  description = "CPU limit for Netdata parent"
  type        = string
  default     = "1000m"
}

variable "parent_memory_limit" {
  description = "Memory limit for Netdata parent"
  type        = string
  default     = "1Gi"
}

# ============================================================================
# Child Node Resources (per-node monitoring DaemonSet)
# ============================================================================

variable "child_cpu_request" {
  description = "CPU request for Netdata child (per node)"
  type        = string
  default     = "100m"
}

variable "child_memory_request" {
  description = "Memory request for Netdata child (per node)"
  type        = string
  default     = "128Mi"
}

variable "child_cpu_limit" {
  description = "CPU limit for Netdata child"
  type        = string
  default     = "500m"
}

variable "child_memory_limit" {
  description = "Memory limit for Netdata child"
  type        = string
  default     = "512Mi"
}

# ============================================================================
# Storage Configuration
# ============================================================================

variable "storage_class_name" {
  description = "Storage class for Netdata persistent volume (historical metrics)"
  type        = string
  default     = "longhorn"
}

variable "storage_size" {
  description = "Storage size for Netdata parent database (historical data)"
  type        = string
  default     = "10Gi"
}

# ============================================================================
# Ingress Configuration
# ============================================================================

variable "domain" {
  description = "Domain name for Netdata web UI"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for TLS certificates"
  type        = string
  default     = "letsencrypt-production"
}

# ============================================================================
# Cloudflare Configuration
# ============================================================================

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for DNS record creation"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID for Access application"
  type        = string
}

variable "traefik_loadbalancer_ip" {
  description = "Traefik LoadBalancer IP for DNS A record"
  type        = string
}

variable "authorized_emails" {
  description = "List of email addresses authorized to access Netdata UI"
  type        = list(string)
}

variable "google_oauth_idp_id" {
  description = "Google OAuth Identity Provider ID from Cloudflare Zero Trust"
  type        = string
  sensitive   = true
}
