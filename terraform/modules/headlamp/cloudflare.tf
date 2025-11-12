# ==============================================================================
# Cloudflare Access Application - Headlamp Kubernetes Dashboard
# ==============================================================================

resource "cloudflare_zero_trust_access_application" "headlamp" {
  # Only create if Cloudflare account ID is provided
  count = var.cloudflare_account_id != "" ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = "Headlamp Kubernetes Dashboard"
  domain     = var.domain
  type       = "self_hosted"

  # Session configuration
  session_duration = var.access_session_duration

  # Authentication behavior
  # auto_redirect requires allowed_idps to have exactly one IDP
  auto_redirect_to_identity = var.google_oauth_idp_id != "" ? var.access_auto_redirect : false
  app_launcher_visible      = var.access_app_launcher_visible

  # Identity Provider configuration
  allowed_idps = [var.google_oauth_idp_id]

  # CORS configuration for API access
  cors_headers {
    allowed_methods = [
      "GET",
      "POST",
      "PUT",
      "DELETE",
      "PATCH",
      "OPTIONS"
    ]
    allowed_origins = [
      "https://${var.domain}"
    ]
    allow_all_headers = true
    max_age           = 86400 # 24 hours
  }
}

# ==============================================================================
# Cloudflare Access Policy - Allow Homelab Admins
# ==============================================================================

resource "cloudflare_zero_trust_access_policy" "headlamp_allow" {
  # Only create if Cloudflare account ID is provided
  count = var.cloudflare_account_id != "" ? 1 : 0

  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.headlamp[0].id
  name           = "Allow Homelab Admins"
  decision       = "allow"
  precedence     = 1

  # Include rule: Authorized email addresses
  include {
    email = var.authorized_emails
  }

  # Require rule: Google OAuth authentication
  require {
    login_method = [var.google_oauth_idp_id]
  }
}

# ==============================================================================
# Notes on Cloudflare Access Configuration
# ==============================================================================

# Application Configuration:
# - Type: self_hosted (application hosted on your infrastructure)
# - Session: 24h default (user stays logged in for 24 hours)
# - Auto-redirect: Automatically redirect to Google OAuth (no Access landing page)
# - App Launcher: Visible in Cloudflare Access App Launcher (https://team-name.cloudflareaccess.com)

# CORS Configuration:
# - Allows Headlamp frontend to make API calls to Kubernetes API via proxy
# - Supports standard HTTP methods for RESTful operations
# - Allows all headers (required for Kubernetes API authentication)
# - 24-hour cache for preflight requests

# Policy Configuration:
# - Decision: allow (grants access to matching users)
# - Precedence: 1 (highest priority - evaluated first)
# - Include: Email-based authorization (authorized_emails variable)
# - Require: Google OAuth authentication (enforces OAuth flow)

# Security Notes:
# - Only authorized emails can access Headlamp
# - Google OAuth provides identity verification
# - Session duration limits exposure if device is compromised
# - Access logs available in Cloudflare Zero Trust dashboard
