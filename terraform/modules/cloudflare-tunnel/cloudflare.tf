# Cloudflare Resources
# Feature 004: Cloudflare Zero Trust VPN Access

# ============================================================================
# Tunnel Secret Generation
# ============================================================================

# Generate a random 32-character tunnel secret for authentication
resource "random_password" "tunnel_secret" {
  length  = 32
  special = false
}

# ============================================================================
# Cloudflare Tunnel
# ============================================================================

# Create the Cloudflare Tunnel (cloudflared)
resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = var.tunnel_name
  secret     = base64encode(random_password.tunnel_secret.result)
}

# Configure tunnel ingress rules (routing table)
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config {
    # Ingress rules: route public hostnames to internal K8s services
    dynamic "ingress_rule" {
      for_each = var.ingress_rules
      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
      }
    }

    # Catch-all rule: required by Cloudflare (returns 404 for undefined hostnames)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# ============================================================================
# DNS Records
# ============================================================================

# Create CNAME records for each ingress hostname
resource "cloudflare_record" "tunnel_dns" {
  for_each = { for rule in var.ingress_rules : rule.hostname => rule }

  zone_id = var.cloudflare_zone_id
  name    = split(".${var.domain_name}", each.value.hostname)[0]    # Extract subdomain (e.g., "pihole" from "pihole.chocolandiadc.com")
  content = cloudflare_zero_trust_tunnel_cloudflared.main.cname     # Point to tunnel CNAME (e.g., "<tunnel-id>.cfargotunnel.com")
  type    = "CNAME"
  proxied = true # Enable Cloudflare proxy (orange cloud) for DDoS protection + caching
  ttl     = 1    # Auto TTL when proxied=true

  comment = "Managed by Terraform - Feature 004 (Cloudflare Zero Trust Tunnel)"
}

# ============================================================================
# Cloudflare Access - Identity Provider
# ============================================================================

# Configure Google OAuth as identity provider for Cloudflare Access
resource "cloudflare_zero_trust_access_identity_provider" "google_oauth" {
  account_id = var.cloudflare_account_id
  name       = "Google OAuth - Homelab"
  type       = "google"

  config {
    client_id     = var.google_oauth_client_id
    client_secret = var.google_oauth_client_secret
  }
}

# ============================================================================
# Cloudflare Access - Applications
# ============================================================================

# Create Access Application for each ingress hostname
resource "cloudflare_zero_trust_access_application" "services" {
  for_each = { for rule in var.ingress_rules : rule.hostname => rule }

  account_id = var.cloudflare_account_id
  name       = title(split(".", each.value.hostname)[0]) # e.g., "Pihole" from "pihole.chocolandiadc.com"
  domain     = each.value.hostname                       # e.g., "pihole.chocolandiadc.com"
  type       = "self_hosted"

  # Session settings
  session_duration = "24h" # Users stay authenticated for 24 hours

  # Auto-redirect to identity provider
  auto_redirect_to_identity = true

  # Enable CORS
  cors_headers {
    allowed_origins = ["https://${each.value.hostname}"]
    allow_all_methods = true
    allow_all_headers = true
    allow_credentials = true
    max_age           = 86400
  }
}

# ============================================================================
# Cloudflare Access - Policies
# ============================================================================

# Create email-based authorization policy for each application
resource "cloudflare_zero_trust_access_policy" "email_authorization" {
  for_each = { for rule in var.ingress_rules : rule.hostname => rule }

  application_id = cloudflare_zero_trust_access_application.services[each.key].id
  account_id     = var.cloudflare_account_id
  name           = "${var.access_policy_name} - ${title(split(".", each.value.hostname)[0])}"
  precedence     = 1
  decision       = "allow"

  # Include rule: allow specified email addresses
  include {
    email = var.authorized_emails
  }

  # Require rule: must use Google OAuth
  require {
    auth_method = cloudflare_zero_trust_access_identity_provider.google_oauth.id
  }
}
