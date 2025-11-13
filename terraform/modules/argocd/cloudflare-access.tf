# ArgoCD Cloudflare Access Configuration
# Feature 008: GitOps Continuous Deployment with ArgoCD
#
# Protects ArgoCD web UI with Cloudflare Zero Trust Access using Google OAuth.
# Only authorized email addresses can access the ArgoCD interface.

# ==============================================================================
# Cloudflare Access Application
# ==============================================================================

resource "cloudflare_access_application" "argocd" {
  account_id = var.cloudflare_account_id

  name                      = "ArgoCD (${var.argocd_domain})"
  domain                    = var.argocd_domain # argocd.chocolandiadc.com
  type                      = "self_hosted"
  session_duration          = var.access_session_duration     # 24h
  auto_redirect_to_identity = var.access_auto_redirect        # true (skip Cloudflare login page)
  app_launcher_visible      = var.access_app_launcher_visible # true (show in Cloudflare App Launcher)

  # Required when auto_redirect_to_identity is true
  # Only allow Google OAuth identity provider (if configured)
  allowed_idps = var.google_oauth_idp_id != "" ? [var.google_oauth_idp_id] : []

  # CORS settings for ArgoCD API access
  cors_headers {
    allowed_methods   = ["GET", "POST", "OPTIONS"]
    allowed_origins   = ["https://${var.argocd_domain}"]
    allow_all_headers = true
    max_age           = 86400 # 24 hours
  }

  # Logo and appearance
  logo_url = "https://raw.githubusercontent.com/argoproj/argo-cd/master/assets/logo.png"

  # Tags removed: Cloudflare requires tags to be created before assigning
  # tags = ["argocd", "gitops", "kubernetes", "infrastructure", "feature-008"]
}

# ==============================================================================
# Cloudflare Access Policy - Authorized Users
# ==============================================================================

resource "cloudflare_access_policy" "argocd_authorized_users" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_access_application.argocd.id

  name       = "ArgoCD Authorized Users"
  decision   = "allow"
  precedence = 1

  # Include: Authorized email addresses
  include {
    email = var.authorized_emails # List of authorized email addresses
  }

  # Require: Google OAuth authentication
  # Only include if google_oauth_idp_id is provided (Phase 6 - US4)
  dynamic "require" {
    for_each = var.google_oauth_idp_id != "" ? [1] : []

    content {
      login_method = [var.google_oauth_idp_id] # Google OAuth IDP UUID
    }
  }

  # Session duration (24 hours)
  session_duration = var.access_session_duration
}

# ==============================================================================
# Note: Outputs defined in outputs.tf
# ==============================================================================
# - cloudflare_access_application_id
# - cloudflare_access_application_url (as argocd_url)
# - cloudflare_access_policy_id (if needed, add to outputs.tf)
