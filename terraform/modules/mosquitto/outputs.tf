# Mosquitto MQTT Broker Module - Outputs
# Feature: 019-govee2mqtt

output "service_name" {
  description = "Mosquitto Kubernetes service name"
  value       = kubernetes_service.mosquitto.metadata[0].name
}

output "service_host" {
  description = "Mosquitto service hostname (internal DNS)"
  value       = "${kubernetes_service.mosquitto.metadata[0].name}.${var.namespace}.svc.cluster.local"
}

output "service_port" {
  description = "Mosquitto MQTT port"
  value       = var.service_port
}

output "namespace" {
  description = "Namespace where Mosquitto is deployed"
  value       = var.namespace
}

output "deployment_name" {
  description = "Mosquitto Kubernetes deployment name"
  value       = kubernetes_deployment.mosquitto.metadata[0].name
}

output "cluster_ip" {
  description = "Mosquitto service ClusterIP (for hostNetwork pods)"
  value       = kubernetes_service.mosquitto.spec[0].cluster_ip
}
