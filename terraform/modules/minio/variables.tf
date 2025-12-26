# ============================================================================
# MinIO Module Variables
# ============================================================================

variable "storage_size" {
  description = "Size of the PersistentVolume for MinIO data storage"
  type        = string
  default     = "100Gi"

  validation {
    condition     = can(regex("^[0-9]+[GMK]i$", var.storage_size))
    error_message = "storage_size must be in format like '100Gi', '500Mi', etc."
  }
}

variable "s3_domain" {
  description = "Domain name for MinIO S3 API endpoint (e.g., s3.chocolandiadc.com)"
  type        = string
}

variable "console_domain" {
  description = "Domain name for MinIO web console (e.g., minio.chocolandiadc.com)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for MinIO deployment"
  type        = string
  default     = "minio"
}

variable "storage_class_name" {
  description = "StorageClass name for MinIO PersistentVolume (should be Longhorn)"
  type        = string
  default     = "longhorn"
}

variable "replicas" {
  description = "Number of MinIO replicas (1 for single-server mode)"
  type        = number
  default     = 1

  validation {
    condition     = var.replicas == 1
    error_message = "Single-server mode requires replicas = 1"
  }
}

variable "resource_requests_cpu" {
  description = "CPU request for MinIO container"
  type        = string
  default     = "500m"
}

variable "resource_requests_memory" {
  description = "Memory request for MinIO container"
  type        = string
  default     = "1Gi"
}

variable "resource_limits_cpu" {
  description = "CPU limit for MinIO container"
  type        = string
  default     = "2000m"
}

variable "resource_limits_memory" {
  description = "Memory limit for MinIO container"
  type        = string
  default     = "4Gi"
}

variable "enable_metrics" {
  description = "Enable Prometheus metrics for MinIO"
  type        = bool
  default     = true
}

# ============================================================================
# Cloudflare and Ingress Variables
# ============================================================================

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for DNS record creation"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID for Zero Trust Access configuration"
  type        = string
}

variable "traefik_loadbalancer_ip" {
  description = "Traefik LoadBalancer IP address for DNS A records"
  type        = string
}

variable "authorized_emails" {
  description = "List of email addresses authorized to access MinIO Console via Cloudflare Access"
  type        = list(string)
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer name for TLS certificate issuance"
  type        = string
  default     = "letsencrypt-production"
}

variable "google_oauth_idp_id" {
  description = "Google OAuth Identity Provider ID from Cloudflare Zero Trust (UUID)"
  type        = string
  default     = ""
}

variable "access_auto_redirect" {
  description = "Automatically redirect to Google OAuth identity provider (skip Cloudflare login page)"
  type        = bool
  default     = true
}

variable "minio_image" {
  description = "MinIO container image"
  type        = string
  default     = "quay.io/minio/minio:RELEASE.2025-01-20T14-49-07Z"  # Upgraded from RELEASE.2024-01-01
}
