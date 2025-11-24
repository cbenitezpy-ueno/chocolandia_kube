output "endpoint_url" {
  description = "LocalStack endpoint URL for AWS CLI/SDK"
  value       = "https://${var.hostname}"
}

output "services_enabled" {
  description = "List of enabled AWS services"
  value       = var.services_list
}

output "namespace" {
  description = "Namespace where LocalStack is deployed"
  value       = var.namespace
}

output "service_name" {
  description = "Name of the LocalStack Kubernetes service"
  value       = "localstack"
}

output "internal_endpoint" {
  description = "Internal cluster endpoint for LocalStack"
  value       = "localstack.${var.namespace}.svc.cluster.local:4566"
}

output "health_endpoint" {
  description = "Health check endpoint URL"
  value       = "https://${var.hostname}/_localstack/health"
}
