# PostgreSQL Groundhog2k - Outputs
# Output values for PostgreSQL deployment

# ==============================================================================
# Service Endpoints
# ==============================================================================

output "postgresql_service" {
  description = "PostgreSQL service DNS name for internal cluster access"
  value       = "${var.release_name}.${var.namespace}.svc.cluster.local"
}

output "postgresql_service_port" {
  description = "PostgreSQL service port"
  value       = 5432
}

output "postgresql_external_ip" {
  description = "PostgreSQL LoadBalancer IP for private network access"
  value       = var.loadbalancer_ip != "" ? var.loadbalancer_ip : "N/A - No LoadBalancer configured"
}

# ==============================================================================
# Connection URLs
# ==============================================================================

output "postgresql_connection_url_internal" {
  description = "PostgreSQL connection URL for cluster applications"
  value       = "postgresql://${var.postgres_user}:PASSWORD@${var.release_name}.${var.namespace}.svc.cluster.local:5432/${var.postgres_database}"
  sensitive   = false
}

output "postgresql_connection_url_external" {
  description = "PostgreSQL connection URL for private network access"
  value       = var.loadbalancer_ip != "" ? "postgresql://${var.postgres_user}:PASSWORD@${var.loadbalancer_ip}:5432/${var.postgres_database}" : "N/A"
  sensitive   = false
}

# ==============================================================================
# Credentials
# ==============================================================================

output "postgresql_secret_name" {
  description = "Kubernetes Secret containing PostgreSQL credentials"
  value       = kubernetes_secret.postgresql_credentials.metadata[0].name
}

output "postgres_password_command" {
  description = "Command to retrieve PostgreSQL superuser password"
  value       = "kubectl get secret -n ${var.namespace} postgresql-credentials -o jsonpath='{.data.postgres-password}' | base64 -d"
  sensitive   = false
}

output "app_user_password_command" {
  description = "Command to retrieve application user password"
  value       = "kubectl get secret -n ${var.namespace} postgresql-credentials -o jsonpath='{.data.password}' | base64 -d"
  sensitive   = false
}

# ==============================================================================
# Deployment Info
# ==============================================================================

output "namespace" {
  description = "Namespace where PostgreSQL is deployed"
  value       = var.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = var.release_name
}

output "chart_version" {
  description = "Deployed Helm chart version"
  value       = var.chart_version
}

output "postgresql_image" {
  description = "PostgreSQL Docker image being used"
  value       = "docker.io/postgres:${var.postgres_image_tag}"
}

# ==============================================================================
# Verification Commands
# ==============================================================================

output "verification_commands" {
  description = "Commands to verify PostgreSQL deployment"
  value = {
    check_pods       = "kubectl get pods -n ${var.namespace} -l app.kubernetes.io/instance=${var.release_name}"
    check_services   = "kubectl get svc -n ${var.namespace}"
    get_password     = "kubectl get secret -n ${var.namespace} postgresql-credentials -o jsonpath='{.data.postgres-password}' | base64 -d"
    test_connection  = "kubectl run pg-test --rm -it --image=postgres:17-alpine -- psql -h ${var.release_name}.${var.namespace}.svc.cluster.local -U postgres -c '\\l'"
    check_databases  = "kubectl exec -n ${var.namespace} ${var.release_name}-0 -- psql -U postgres -c 'SELECT datname FROM pg_database;'"
  }
}
