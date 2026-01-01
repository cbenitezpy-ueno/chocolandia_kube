# OpenTofu Module Contracts: Paperless-ngx

**Feature**: 027-paperless-ngx
**Date**: 2026-01-01

## Module: paperless-ngx

### Input Variables

```hcl
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
  description = "Samba sidecar container image"
  type        = string
  default     = "dperson/samba:latest"
}

# Database Configuration
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

# Redis Configuration
variable "redis_url" {
  description = "Redis connection URL"
  type        = string
  default     = "redis://192.168.4.203:6379"
}

# Storage Configuration
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

# Application Configuration
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

# Ingress Configuration
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

# Samba Configuration
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

# Resource Configuration
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

# Monitoring
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
```

### Output Values

```hcl
output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.paperless.metadata[0].name
}

output "service_name" {
  description = "Kubernetes service name"
  value       = kubernetes_service.paperless.metadata[0].name
}

output "service_port" {
  description = "Service port"
  value       = 8000
}

output "internal_url" {
  description = "Internal cluster URL"
  value       = "http://${kubernetes_service.paperless.metadata[0].name}.${kubernetes_namespace.paperless.metadata[0].name}.svc.cluster.local:8000"
}

output "public_url" {
  description = "Public URL (Cloudflare)"
  value       = "https://${var.public_host}"
}

output "local_url" {
  description = "Local LAN URL"
  value       = var.enable_local_ingress ? "https://${var.local_host}" : null
}

output "samba_service_name" {
  description = "Samba LoadBalancer service name"
  value       = kubernetes_service.samba.metadata[0].name
}

output "samba_endpoint" {
  description = "Samba SMB endpoint (for scanner configuration)"
  value       = "\\\\${kubernetes_service.samba.status[0].load_balancer[0].ingress[0].ip}\\${var.samba_share_name}"
}

output "consume_pvc_name" {
  description = "Consume folder PVC name"
  value       = kubernetes_persistent_volume_claim.consume.metadata[0].name
}
```

---

## Module: Cloudflare Tunnel Update

### Additional Ingress Rule

Add to existing `var.ingress_rules` in environment:

```hcl
# In terraform/environments/chocolandiadc-mvp/cloudflare.tf

ingress_rules = [
  # ... existing rules ...
  {
    hostname = "paperless.chocolandiadc.com"
    service  = "http://paperless-ngx.paperless.svc.cluster.local:8000"
  }
]
```

---

## Module: postgresql-database (Existing)

### Usage for Paperless

```hcl
module "paperless_database" {
  source = "../modules/postgresql-database"

  db_name     = "paperless"
  db_user     = "paperless"
  db_password = random_password.paperless_db.result
}

resource "random_password" "paperless_db" {
  length  = 32
  special = false
}
```

---

## Environment Module Instantiation

### File: terraform/environments/chocolandiadc-mvp/paperless.tf

```hcl
# Paperless-ngx Document Management
# Feature: 027-paperless-ngx

# Generate secrets
resource "random_password" "paperless_db" {
  length  = 32
  special = false
}

resource "random_password" "paperless_secret_key" {
  length  = 50
  special = true
}

resource "random_password" "paperless_admin" {
  length  = 16
  special = true
}

resource "random_password" "samba_password" {
  length  = 16
  special = false
}

# Create PostgreSQL database
module "paperless_database" {
  source = "../../modules/postgresql-database"

  db_name     = "paperless"
  db_user     = "paperless"
  db_password = random_password.paperless_db.result

  providers = {
    postgresql = postgresql
  }
}

# Deploy Paperless-ngx
module "paperless_ngx" {
  source = "../../modules/paperless-ngx"

  namespace = "paperless"

  # Database
  db_host     = "192.168.4.204"
  db_name     = module.paperless_database.database_name
  db_user     = module.paperless_database.username
  db_password = random_password.paperless_db.result

  # Redis
  redis_url = "redis://192.168.4.203:6379"

  # Application
  secret_key     = random_password.paperless_secret_key.result
  admin_user     = "admin"
  admin_password = random_password.paperless_admin.result
  admin_email    = "cbenitez@gmail.com"
  ocr_language   = "spa+eng"
  timezone       = "America/Asuncion"

  # Ingress
  public_host = "paperless.chocolandiadc.com"
  local_host  = "paperless.chocolandiadc.local"

  # Samba
  samba_user     = "scanner"
  samba_password = random_password.samba_password.result

  # Storage (50GB total)
  data_storage_size    = "5Gi"
  media_storage_size   = "40Gi"
  consume_storage_size = "5Gi"

  depends_on = [
    module.paperless_database
  ]
}

# Add to Cloudflare tunnel (if using dynamic ingress)
# Otherwise, add to ingress_rules in cloudflare.tf
```

---

## Service Contracts

### Paperless-ngx HTTP API

Paperless-ngx exposes a REST API at `/api/`:

| Endpoint | Method | Description |
|----------|--------|-------------|
| /api/documents/ | GET | List documents |
| /api/documents/{id}/ | GET | Get document details |
| /api/documents/post_document/ | POST | Upload new document |
| /api/correspondents/ | GET/POST | Manage correspondents |
| /api/document_types/ | GET/POST | Manage document types |
| /api/tags/ | GET/POST | Manage tags |
| /api/search/ | GET | Full-text search |

### Prometheus Metrics

When `PAPERLESS_ENABLE_METRICS=true`, metrics exposed at `/metrics`:

| Metric | Type | Description |
|--------|------|-------------|
| django_http_requests_total_by_method | Counter | HTTP requests by method |
| django_http_responses_total_by_status | Counter | HTTP responses by status |
| django_db_execute_total | Counter | Database queries |
| paperless_documents_total | Gauge | Total document count |
| paperless_inbox_documents | Gauge | Unprocessed documents |

### Samba Share

| Property | Value |
|----------|-------|
| Protocol | SMB2/SMB3 |
| Port | 445/TCP |
| Share Name | consume |
| Path | /consume (mapped to PVC) |
| Authentication | Username/Password |
| Permissions | Read/Write |
