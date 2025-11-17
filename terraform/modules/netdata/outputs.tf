# ============================================================================
# Netdata Module Outputs
# ============================================================================

output "namespace" {
  description = "Kubernetes namespace where Netdata is deployed"
  value       = kubernetes_namespace.netdata.metadata[0].name
}

output "service_name" {
  description = "Netdata parent service name"
  value       = data.kubernetes_service.netdata_parent.metadata[0].name
}

output "service_port" {
  description = "Netdata parent service port"
  value       = 19999
}

output "web_ui_url" {
  description = "Netdata web UI URL"
  value       = "https://${var.domain}"
}

output "helm_release_name" {
  description = "Netdata Helm release name"
  value       = helm_release.netdata.name
}

output "helm_chart_version" {
  description = "Netdata Helm chart version deployed"
  value       = helm_release.netdata.version
}
