# Nexus Repository Manager - Module Outputs

output "web_url" {
  description = "Nexus Web UI URL"
  value       = "https://${var.hostname}"
}

output "docker_url" {
  description = "Docker registry URL"
  value       = "https://${var.docker_hostname}"
}

output "namespace" {
  description = "Kubernetes namespace where Nexus is deployed"
  value       = kubernetes_namespace.nexus.metadata[0].name
}

output "service_name" {
  description = "Nexus ClusterIP service name"
  value       = kubernetes_service.nexus.metadata[0].name
}

output "internal_endpoint" {
  description = "Internal cluster endpoint for Nexus"
  value       = "${kubernetes_service.nexus.metadata[0].name}.${kubernetes_namespace.nexus.metadata[0].name}.svc.cluster.local:8081"
}

output "docker_service_name" {
  description = "Docker connector ClusterIP service name"
  value       = kubernetes_service.nexus_docker.metadata[0].name
}
