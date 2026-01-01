# Paperless-ngx Document Management
# Feature: 027-paperless-ngx
# Deploys Paperless-ngx with Samba sidecar for scanner integration

# ============================================================================
# Secret Generation
# ============================================================================

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

# ============================================================================
# PostgreSQL Database
# ============================================================================

module "paperless_database" {
  source = "../../modules/postgresql-database"

  db_name     = "paperless"
  db_user     = "paperless"
  db_password = random_password.paperless_db.result

  providers = {
    postgresql = postgresql
  }
}

# ============================================================================
# Paperless-ngx Deployment
# ============================================================================

module "paperless_ngx" {
  source = "../../modules/paperless-ngx"

  namespace = "paperless"

  # Database
  db_host     = "192.168.4.204"
  db_name     = module.paperless_database.database_name
  db_user     = module.paperless_database.db_user
  db_password = random_password.paperless_db.result

  # Redis (with authentication, using DB 1 to isolate from other services)
  redis_url = "redis://:${var.redis_password}@192.168.4.203:6379/1"

  # Application
  secret_key     = random_password.paperless_secret_key.result
  admin_user     = "admin"
  admin_password = random_password.paperless_admin.result
  admin_email    = var.paperless_admin_email
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

# ============================================================================
# Outputs
# ============================================================================

output "paperless_admin_password" {
  description = "Initial admin password for Paperless-ngx"
  value       = random_password.paperless_admin.result
  sensitive   = true
}

output "paperless_samba_password" {
  description = "Samba share password for scanner"
  value       = random_password.samba_password.result
  sensitive   = true
}

output "paperless_public_url" {
  description = "Paperless-ngx public URL (Cloudflare)"
  value       = module.paperless_ngx.public_url
}

output "paperless_local_url" {
  description = "Paperless-ngx local URL (LAN)"
  value       = module.paperless_ngx.local_url
}

output "paperless_samba_service" {
  description = "Samba service for scanner configuration"
  value       = module.paperless_ngx.samba_service_name
}

output "paperless_samba_endpoint" {
  description = "SMB endpoint for scanner (smb://IP/consume)"
  value       = module.paperless_ngx.samba_endpoint
}
