# Homepage Module Outputs

output "namespace" {
  description = "Homepage namespace name"
  value       = kubernetes_namespace.homepage.metadata[0].name
}

output "service_name" {
  description = "Homepage service name"
  value       = kubernetes_service.homepage.metadata[0].name
}

output "service_url" {
  description = "Internal cluster URL for Homepage"
  value       = "http://${kubernetes_service.homepage.metadata[0].name}.${kubernetes_namespace.homepage.metadata[0].name}.svc.cluster.local:${var.service_port}"
}

output "configmap_names" {
  description = "List of ConfigMap names created for Homepage configuration"
  value = [
    kubernetes_config_map.homepage_services.metadata[0].name,
    kubernetes_config_map.homepage_widgets.metadata[0].name,
    kubernetes_config_map.homepage_settings.metadata[0].name
  ]
}

output "secret_name" {
  description = "Secret name for widget API credentials"
  value       = kubernetes_secret.homepage_widgets.metadata[0].name
  sensitive   = true
}

output "deployment_name" {
  description = "Homepage deployment name"
  value       = kubernetes_deployment.homepage.metadata[0].name
}

output "serviceaccount_name" {
  description = "ServiceAccount name for Homepage RBAC"
  value       = kubernetes_service_account.homepage.metadata[0].name
}
