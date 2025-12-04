# Govee2MQTT Module - Outputs
# Feature: 019-govee2mqtt

output "deployment_name" {
  description = "govee2mqtt Kubernetes deployment name"
  value       = kubernetes_deployment.govee2mqtt.metadata[0].name
}

output "namespace" {
  description = "Namespace where govee2mqtt is deployed"
  value       = var.namespace
}

output "secret_name" {
  description = "Name of the Kubernetes secret containing Govee credentials"
  value       = kubernetes_secret.govee_credentials.metadata[0].name
}
