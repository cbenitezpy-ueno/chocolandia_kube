# Jenkins Module Outputs
# Feature 029: Jenkins CI Deployment

# ==============================================================================
# URLs
# ==============================================================================

output "jenkins_url" {
  description = "Jenkins web UI URL (LAN)"
  value       = "https://${var.hostname}"
}

output "jenkins_internal_url" {
  description = "Jenkins internal service URL"
  value       = "http://jenkins.${var.namespace}.svc.cluster.local:8080"
}

# ==============================================================================
# Credentials
# ==============================================================================

output "admin_user" {
  description = "Jenkins admin username"
  value       = var.admin_user
}

output "admin_password" {
  description = "Jenkins admin password"
  value       = local.admin_password
  sensitive   = true
}

# ==============================================================================
# Namespace
# ==============================================================================

output "namespace" {
  description = "Kubernetes namespace where Jenkins is deployed"
  value       = kubernetes_namespace.jenkins.metadata[0].name
}

# ==============================================================================
# Service Information
# ==============================================================================

output "service_name" {
  description = "Jenkins Kubernetes service name"
  value       = "jenkins"
}

output "service_port" {
  description = "Jenkins web UI service port"
  value       = 8080
}

output "agent_port" {
  description = "Jenkins agent connection port"
  value       = 50000
}

# ==============================================================================
# Monitoring
# ==============================================================================

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint"
  value       = var.enable_metrics ? "http://jenkins.${var.namespace}.svc.cluster.local:8080/prometheus" : null
}
