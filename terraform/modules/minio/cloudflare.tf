# ============================================================================
# Cloudflare Configuration for MinIO S3 API and Console
# ============================================================================
# Creates DNS records and Cloudflare Access applications for secure access
# to MinIO S3 API (s3.chocolandiadc.com) and Console (minio.chocolandiadc.com)
# ============================================================================

# DNS A record for MinIO S3 API
resource "cloudflare_record" "minio_s3" {
  zone_id = var.cloudflare_zone_id
  name    = var.s3_domain
  content = var.traefik_loadbalancer_ip
  type    = "A"
  proxied = false # Direct to Traefik, no Cloudflare proxy
  ttl     = 300

  comment = "MinIO S3 API endpoint - managed by OpenTofu"
}

# DNS A record for MinIO Console
resource "cloudflare_record" "minio_console" {
  zone_id = var.cloudflare_zone_id
  name    = var.console_domain
  content = var.traefik_loadbalancer_ip
  type    = "A"
  proxied = false
  ttl     = 300

  comment = "MinIO web console - managed by OpenTofu"
}

# Cloudflare Access Application for MinIO Console
resource "cloudflare_access_application" "minio_console" {
  account_id = var.cloudflare_account_id
  name       = "MinIO Object Storage Console"
  domain     = var.console_domain
  type       = "self_hosted"

  session_duration = "24h"

  # Logo and appearance
  logo_url = "https://raw.githubusercontent.com/minio/minio/master/.github/logo.svg"
}

# Access Policy: Email-based authentication for Console
resource "cloudflare_access_policy" "minio_console" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_access_application.minio_console.id
  name           = "MinIO Console - Email Authorization"
  decision       = "allow"
  precedence     = 1

  include {
    email = var.authorized_emails
  }

  session_duration = "24h"
}

# Note: S3 API endpoint (s3.chocolandiadc.com) does NOT have Cloudflare Access
# because S3 API clients (AWS CLI, SDKs) use programmatic access with credentials
# and cannot authenticate through Cloudflare Access web flow
