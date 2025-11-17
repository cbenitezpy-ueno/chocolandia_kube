# ============================================================================
# Longhorn Module Variables
# ============================================================================

variable "replica_count" {
  description = "Number of replicas for Longhorn volumes (balance capacity vs HA)"
  type        = number
  default     = 2

  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 3
    error_message = "replica_count must be between 1 and 3 for 4-node cluster"
  }
}

variable "usb_disk_path" {
  description = "Path to USB disk mount point on master1 for Longhorn storage"
  type        = string
  default     = "/media/usb/longhorn-storage"
}

variable "storage_class_name" {
  description = "Name of the Longhorn StorageClass"
  type        = string
  default     = "longhorn"
}

variable "storage_reserved_percentage" {
  description = "Percentage of disk to reserve for system (10% recommended)"
  type        = number
  default     = 10

  validation {
    condition     = var.storage_reserved_percentage >= 0 && var.storage_reserved_percentage <= 50
    error_message = "storage_reserved_percentage must be between 0 and 50"
  }
}

variable "enable_metrics" {
  description = "Enable Prometheus metrics for Longhorn components"
  type        = bool
  default     = true
}

# ============================================================================
# Cloudflare and Ingress Variables (User Story 2)
# ============================================================================

variable "longhorn_domain" {
  description = "Domain name for Longhorn web UI (e.g., longhorn.chocolandiadc.com)"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for DNS record creation"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID for Zero Trust Access configuration"
  type        = string
}

variable "traefik_loadbalancer_ip" {
  description = "Traefik LoadBalancer IP address for DNS A record"
  type        = string
}

variable "authorized_emails" {
  description = "List of email addresses authorized to access Longhorn UI via Cloudflare Access"
  type        = list(string)
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer name for TLS certificate issuance"
  type        = string
  default     = "letsencrypt-production"
}

variable "certificate_duration" {
  description = "TLS certificate duration"
  type        = string
  default     = "2160h" # 90 days
}

variable "certificate_renew_before" {
  description = "Renew certificate before expiration"
  type        = string
  default     = "720h" # 30 days
}
