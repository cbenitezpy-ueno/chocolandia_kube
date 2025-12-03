# Home Assistant Module Outputs
# Feature: 018-home-assistant
# Scope: Phase 1 - Base Installation + Prometheus Integration

output "namespace" {
  description = "Kubernetes namespace where Home Assistant is deployed"
  value       = kubernetes_namespace.home_assistant.metadata[0].name
}

output "service_name" {
  description = "Name of the Home Assistant service"
  value       = kubernetes_service.home_assistant.metadata[0].name
}

output "service_port" {
  description = "Port of the Home Assistant service"
  value       = var.service_port
}

output "local_url" {
  description = "Local domain URL for Home Assistant"
  value       = "https://${var.local_domain}"
}

output "external_url" {
  description = "External domain URL for Home Assistant"
  value       = "https://${var.external_domain}"
}

output "internal_endpoint" {
  description = "Internal Kubernetes endpoint for Home Assistant"
  value       = "${kubernetes_service.home_assistant.metadata[0].name}.${kubernetes_namespace.home_assistant.metadata[0].name}.svc.cluster.local:${var.service_port}"
}

output "pvc_name" {
  description = "Name of the PersistentVolumeClaim for config storage"
  value       = kubernetes_persistent_volume_claim.home_assistant_config.metadata[0].name
}
