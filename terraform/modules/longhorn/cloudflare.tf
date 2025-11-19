# ============================================================================
# Cloudflare Configuration for Longhorn Web UI
# ============================================================================
# Creates DNS record and Cloudflare Access application for secure access
# to Longhorn management UI at longhorn.chocolandiadc.com
# ============================================================================

# DNS A record for Longhorn UI
resource "cloudflare_record" "longhorn_ui" {
  zone_id = var.cloudflare_zone_id
  name    = var.longhorn_domain
  content = var.traefik_loadbalancer_ip
  type    = "A"
  proxied = false # Direct to Traefik, no Cloudflare proxy (Tunnel handles access)
  ttl     = 300

  comment = "Longhorn distributed storage web UI - managed by OpenTofu"
}

# Cloudflare Access Application for Longhorn UI
resource "cloudflare_access_application" "longhorn_ui" {
  account_id = var.cloudflare_account_id
  name       = "Longhorn Storage UI"
  domain     = var.longhorn_domain
  type       = "self_hosted"

  session_duration          = "24h"
  auto_redirect_to_identity = var.access_auto_redirect # true (skip Cloudflare login page)

  # Required when auto_redirect_to_identity is true
  # Only allow Google OAuth identity provider (if configured)
  allowed_idps = var.google_oauth_idp_id != "" ? [var.google_oauth_idp_id] : []

  # Logo and appearance
  logo_url = "https://raw.githubusercontent.com/longhorn/longhorn/master/app/public/logo.svg"
}

# Access Policy: Email-based authentication
resource "cloudflare_access_policy" "longhorn_ui" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_access_application.longhorn_ui.id
  name           = "Longhorn UI - Email Authorization"
  decision       = "allow"
  precedence     = 1

  include {
    email = var.authorized_emails
  }

  session_duration = "24h"
}
