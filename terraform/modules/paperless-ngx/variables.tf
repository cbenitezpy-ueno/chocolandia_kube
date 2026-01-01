# Paperless-ngx Module Variables
# Feature: 027-paperless-ngx

# ============================================================================
# Core Configuration
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Paperless-ngx"
  type        = string
  default     = "paperless"
}

variable "app_name" {
  description = "Application name for labels"
  type        = string
  default     = "paperless-ngx"
}

variable "image" {
  description = "Paperless-ngx container image"
  type        = string
  default     = "ghcr.io/paperless-ngx/paperless-ngx:2.14.7"
}

variable "samba_image" {
  description = "Samba sidecar container image (pinned to known working version)"
  type        = string
  default     = "dperson/samba@sha256:66088b78a19810dd1457a8f39340e95e663c728083efa5fe7dc0d40b2478e869"
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "db_host" {
  description = "PostgreSQL host address"
  type        = string
}

variable "db_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "paperless"
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "paperless"
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

# ============================================================================
# Redis Configuration
# ============================================================================

variable "redis_url" {
  description = "Redis connection URL"
  type        = string
  default     = "redis://192.168.4.203:6379"
}

# ============================================================================
# Storage Configuration
# ============================================================================

variable "storage_class" {
  description = "Kubernetes StorageClass for PVCs"
  type        = string
  default     = "local-path"
}

variable "data_storage_size" {
  description = "Size of data PVC"
  type        = string
  default     = "5Gi"
}

variable "media_storage_size" {
  description = "Size of media PVC"
  type        = string
  default     = "40Gi"
}

variable "consume_storage_size" {
  description = "Size of consume PVC"
  type        = string
  default     = "5Gi"
}

# ============================================================================
# Application Configuration
# ============================================================================

variable "secret_key" {
  description = "Django secret key for Paperless-ngx"
  type        = string
  sensitive   = true
}

variable "admin_user" {
  description = "Initial admin username"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Initial admin password"
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Admin email address"
  type        = string
  default     = ""
}

variable "ocr_language" {
  description = "OCR language(s) - Tesseract format"
  type        = string
  default     = "spa+eng"
}

variable "timezone" {
  description = "Application timezone"
  type        = string
  default     = "America/Asuncion"
}

# ============================================================================
# Ingress Configuration
# ============================================================================

variable "public_host" {
  description = "Public hostname (Cloudflare)"
  type        = string
  default     = "paperless.chocolandiadc.com"
}

variable "local_host" {
  description = "Local hostname (LAN access)"
  type        = string
  default     = "paperless.chocolandiadc.local"
}

variable "enable_local_ingress" {
  description = "Enable Traefik IngressRoute for local access"
  type        = bool
  default     = true
}

variable "local_tls_secret" {
  description = "TLS secret name for local ingress"
  type        = string
  default     = "paperless-local-tls"
}

variable "local_issuer" {
  description = "cert-manager issuer for local TLS"
  type        = string
  default     = "local-ca"
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

# ============================================================================
# Samba Configuration
# ============================================================================

variable "samba_user" {
  description = "Samba share username"
  type        = string
  default     = "scanner"
}

variable "samba_password" {
  description = "Samba share password"
  type        = string
  sensitive   = true
}

variable "samba_share_name" {
  description = "Name of the Samba share"
  type        = string
  default     = "consume"
}

# ============================================================================
# Resource Configuration
# ============================================================================

variable "resources" {
  description = "Container resource requests and limits"
  type = object({
    requests = object({
      memory = string
      cpu    = string
    })
    limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
    requests = {
      memory = "512Mi"
      cpu    = "250m"
    }
    limits = {
      memory = "2Gi"
      cpu    = "2000m"
    }
  }
}

variable "samba_resources" {
  description = "Samba sidecar resource requests and limits"
  type = object({
    requests = object({
      memory = string
      cpu    = string
    })
    limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
    requests = {
      memory = "64Mi"
      cpu    = "50m"
    }
    limits = {
      memory = "256Mi"
      cpu    = "200m"
    }
  }
}

# ============================================================================
# Monitoring Configuration
# ============================================================================

variable "enable_metrics" {
  description = "Enable Prometheus metrics endpoint"
  type        = bool
  default     = true
}

variable "create_service_monitor" {
  description = "Create Prometheus ServiceMonitor"
  type        = bool
  default     = true
}

variable "service_port" {
  description = "Paperless-ngx service port"
  type        = number
  default     = 8000
}
