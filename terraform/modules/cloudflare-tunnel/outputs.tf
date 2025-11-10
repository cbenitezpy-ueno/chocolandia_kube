# Cloudflare Tunnel Module Outputs
# Feature 004: Cloudflare Zero Trust VPN Access

# ============================================================================
# Tunnel Outputs
# ============================================================================

output "tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

output "tunnel_cname" {
  description = "Cloudflare Tunnel CNAME target for DNS records"
  value       = cloudflare_zero_trust_tunnel_cloudflared.main.cname
}

output "tunnel_name" {
  description = "Cloudflare Tunnel name"
  value       = cloudflare_zero_trust_tunnel_cloudflared.main.name
}

output "tunnel_token" {
  description = "Cloudflare Tunnel token (base64-encoded credentials)"
  value       = random_password.tunnel_secret.result
  sensitive   = true
}

# ============================================================================
# Kubernetes Outputs
# ============================================================================

output "namespace" {
  description = "Kubernetes namespace where cloudflared is deployed"
  value       = kubernetes_namespace.cloudflare_tunnel.metadata[0].name
}

output "deployment_name" {
  description = "Name of the cloudflared Kubernetes deployment"
  value       = kubernetes_deployment.cloudflared.metadata[0].name
}

output "secret_name" {
  description = "Name of the Kubernetes secret containing tunnel credentials"
  value       = kubernetes_secret.tunnel_credentials.metadata[0].name
}

# ============================================================================
# DNS Outputs
# ============================================================================

output "dns_records" {
  description = "Map of created DNS CNAME records (hostname -> CNAME target)"
  value = {
    for record in cloudflare_record.tunnel_dns :
    record.name => record.value
  }
}

output "ingress_hostnames" {
  description = "List of public hostnames exposed via the tunnel"
  value       = [for rule in var.ingress_rules : rule.hostname]
}

# ============================================================================
# Access Control Outputs
# ============================================================================

output "access_identity_provider_id" {
  description = "Cloudflare Access Identity Provider (Google OAuth) ID"
  value       = cloudflare_zero_trust_access_identity_provider.google_oauth.id
}

output "access_application_ids" {
  description = "Map of Cloudflare Access Application IDs (hostname -> app_id)"
  value = {
    for app in cloudflare_zero_trust_access_application.services :
    app.name => app.id
  }
}

output "access_policy_ids" {
  description = "Map of Cloudflare Access Policy IDs (hostname -> policy_id)"
  value = {
    for policy in cloudflare_zero_trust_access_policy.email_authorization :
    policy.name => policy.id
  }
}

# ============================================================================
# Service URLs
# ============================================================================

output "service_urls" {
  description = "Map of public service URLs (service_name -> https://hostname)"
  value = {
    for rule in var.ingress_rules :
    split(".", rule.hostname)[0] => "https://${rule.hostname}"
  }
}
