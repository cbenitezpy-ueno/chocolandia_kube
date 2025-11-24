output "registry_url" {
  description = "Full registry URL for docker login"
  value       = "https://${var.hostname}"
}

output "credentials_secret_name" {
  description = "Name of the Kubernetes secret containing registry credentials"
  value       = var.auth_secret
}

output "namespace" {
  description = "Namespace where registry is deployed"
  value       = var.namespace
}

output "service_name" {
  description = "Name of the registry Kubernetes service"
  value       = "registry"
}

output "internal_endpoint" {
  description = "Internal cluster endpoint for registry"
  value       = "registry.${var.namespace}.svc.cluster.local:5000"
}
