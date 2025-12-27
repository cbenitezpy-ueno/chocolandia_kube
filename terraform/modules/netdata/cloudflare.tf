# ============================================================================
# Cloudflare DNS and Access Configuration for Netdata
# ============================================================================

# ============================================================================
# DNS A Record
# ============================================================================

resource "cloudflare_record" "netdata" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  content = var.traefik_loadbalancer_ip
  type    = "A"
  proxied = false # Direct to Traefik, no Cloudflare proxy
  ttl     = 1     # Auto TTL

  comment = "Netdata hardware monitoring dashboard - Managed by Terraform"
}

# ============================================================================
# Cloudflare Access Application
# ============================================================================

resource "cloudflare_zero_trust_access_application" "netdata" {
  account_id       = var.cloudflare_account_id
  name             = "Netdata Hardware Monitoring"
  domain           = var.domain
  session_duration = "24h"
  type             = "self_hosted"

  # Disable auto-redirect for now to avoid IDP configuration issues
  # Can be enabled later when Google OAuth IDP is configured
  auto_redirect_to_identity = false

  # CORS configuration for Netdata API
  cors_headers {
    allowed_origins = ["https://${var.domain}"]
    allow_all_methods = true
    allow_all_headers = true
    max_age           = 600
  }

  # Tags removed: Cloudflare requires tags to be created before assigning
  # tags = ["monitoring", "hardware", "k3s"]
}

# ============================================================================
# Access Policy - Google OAuth Email Authorization
# ============================================================================

resource "cloudflare_zero_trust_access_policy" "netdata_email" {
  application_id = cloudflare_zero_trust_access_application.netdata.id
  account_id     = var.cloudflare_account_id
  name           = "Allow authorized emails"
  precedence     = 1
  decision       = "allow"

  # Email-based authorization
  include {
    email = var.authorized_emails
  }
}
