# Ntfy Notification Server
# Feature: 014-monitoring-alerts
# Receives alerts from Alertmanager and delivers push notifications

module "ntfy" {
  source = "../../modules/ntfy"

  namespace      = "ntfy"
  image_tag      = "v2.8.0"
  ingress_host   = "ntfy.chocolandiadc.com"
  cluster_issuer = "letsencrypt-prod"
  storage_class  = "local-path"
  storage_size   = "1Gi"
  default_topic  = "homelab-alerts"

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

# ============================================================================
# Outputs
# ============================================================================

output "ntfy_external_url" {
  description = "External URL for Ntfy subscriptions"
  value       = module.ntfy.external_url
}

output "ntfy_webhook_url" {
  description = "Internal webhook URL for Alertmanager"
  value       = module.ntfy.webhook_url
}

output "ntfy_subscription_url" {
  description = "URL for mobile app subscription"
  value       = module.ntfy.subscription_url
}
