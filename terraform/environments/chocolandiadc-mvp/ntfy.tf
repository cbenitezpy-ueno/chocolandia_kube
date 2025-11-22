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

  # Authentication settings
  enable_auth         = true
  auth_default_access = "read-only"  # Anyone can subscribe, only authenticated can publish

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

output "ntfy_admin_commands" {
  description = "Commands for Ntfy user management"
  value = {
    create_admin_user  = "kubectl exec -it -n ntfy deploy/ntfy -- ntfy user add --role=admin admin"
    list_users         = "kubectl exec -it -n ntfy deploy/ntfy -- ntfy user list"
    change_password    = "kubectl exec -it -n ntfy deploy/ntfy -- ntfy user change-pass admin"
    grant_topic_access = "kubectl exec -it -n ntfy deploy/ntfy -- ntfy access admin 'homelab-*' rw"
  }
}
