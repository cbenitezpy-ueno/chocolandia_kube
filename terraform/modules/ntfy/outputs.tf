# Ntfy Module - Outputs
# Feature: 014-monitoring-alerts

output "namespace" {
  description = "Namespace where Ntfy is deployed"
  value       = var.namespace
}

output "internal_url" {
  description = "Internal Ntfy URL for Alertmanager webhook"
  value       = "http://ntfy.${var.namespace}.svc.cluster.local"
}

output "external_url" {
  description = "External Ntfy URL for subscriptions"
  value       = "https://${var.ingress_host}"
}

output "webhook_url" {
  description = "Full webhook URL for Alertmanager"
  value       = "http://ntfy.${var.namespace}.svc.cluster.local/${var.default_topic}"
}

output "default_topic" {
  description = "Default topic for homelab alerts"
  value       = var.default_topic
}

output "subscription_url" {
  description = "URL for mobile app subscription"
  value       = "https://${var.ingress_host}/${var.default_topic}"
}
