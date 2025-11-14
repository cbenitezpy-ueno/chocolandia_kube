# PostgreSQL Cluster Module - Outputs
# Feature 011: PostgreSQL Cluster Database Service
#
# Outputs for PostgreSQL cluster connection endpoints and credentials

# ==============================================================================
# Connection Endpoints
# ==============================================================================

output "cluster_ip_service_name" {
  description = "Name of the ClusterIP Service for cluster-internal access"
  value       = "${var.release_name}-postgresql"
}

output "cluster_ip_service_endpoint" {
  description = "Full DNS name for PostgreSQL primary connection from within Kubernetes cluster"
  value       = "${var.release_name}-postgresql.${var.namespace}.svc.cluster.local"
}

output "read_replica_service_endpoint" {
  description = "Full DNS name for read-only replica connections from within Kubernetes cluster"
  value       = "${var.release_name}-postgresql-read.${var.namespace}.svc.cluster.local"
}

output "external_service_name" {
  description = "Name of the LoadBalancer Service for external network access"
  value       = var.enable_external_access ? "${var.release_name}-postgresql-external" : null
}

output "external_ip" {
  description = "MetalLB-assigned IP address for external network access (available after LoadBalancer service creation)"
  value       = var.enable_external_access ? "Check: kubectl get svc -n ${var.namespace} ${var.release_name}-postgresql-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'" : null
}

# ==============================================================================
# Connection Details
# ==============================================================================

output "port" {
  description = "PostgreSQL connection port"
  value       = 5432
}

output "database_name" {
  description = "Default PostgreSQL database name"
  value       = "postgres"
}

output "superuser_username" {
  description = "PostgreSQL superuser username"
  value       = "postgres"
}

# ==============================================================================
# Credentials (Kubernetes Secrets)
# ==============================================================================

output "credentials_secret_name" {
  description = "Name of Kubernetes Secret containing PostgreSQL credentials"
  value       = "${var.release_name}-postgresql-credentials"
}

output "postgres_password_command" {
  description = "kubectl command to retrieve postgres superuser password"
  value       = "kubectl get secret -n ${var.namespace} ${var.release_name}-postgresql-credentials -o jsonpath=\"{.data.postgres-password}\" | base64 -d"
}

output "replication_password_command" {
  description = "kubectl command to retrieve replication user password"
  value       = "kubectl get secret -n ${var.namespace} ${var.release_name}-postgresql-credentials -o jsonpath=\"{.data.replication-password}\" | base64 -d"
}

# ==============================================================================
# Connection Strings
# ==============================================================================

output "connection_string_cluster" {
  description = "PostgreSQL connection string template for applications running in Kubernetes cluster"
  value       = "postgresql://postgres:<password>@${var.release_name}-postgresql.${var.namespace}.svc.cluster.local:5432/postgres"
  sensitive   = true
}

output "connection_string_external" {
  description = "PostgreSQL connection string template for external network access (replace <external-ip> and <password>)"
  value       = var.enable_external_access ? "postgresql://postgres:<password>@<external-ip>:5432/postgres" : null
  sensitive   = true
}

# ==============================================================================
# Monitoring
# ==============================================================================

output "metrics_enabled" {
  description = "Whether PostgreSQL Exporter metrics are enabled"
  value       = var.enable_metrics
}

output "service_monitor_enabled" {
  description = "Whether Prometheus ServiceMonitor is created"
  value       = var.enable_service_monitor
}

# ==============================================================================
# Deployment Information
# ==============================================================================

output "namespace" {
  description = "Kubernetes namespace where PostgreSQL is deployed"
  value       = var.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = var.release_name
}

output "replica_count" {
  description = "Total number of PostgreSQL instances (primary + replicas)"
  value       = var.replica_count
}

output "postgresql_version" {
  description = "PostgreSQL major version"
  value       = var.postgresql_version
}

output "chart_version" {
  description = "Bitnami PostgreSQL HA Helm chart version"
  value       = var.chart_version
}

# ==============================================================================
# Quick Reference Commands
# ==============================================================================

output "verification_commands" {
  description = "Useful kubectl commands for verifying the PostgreSQL deployment"
  value = {
    check_pods              = "kubectl get pods -n ${var.namespace}"
    check_services          = "kubectl get svc -n ${var.namespace}"
    check_pvc               = "kubectl get pvc -n ${var.namespace}"
    get_postgres_password   = "kubectl get secret -n ${var.namespace} ${var.release_name}-postgresql-credentials -o jsonpath=\"{.data.postgres-password}\" | base64 -d"
    connect_to_primary      = "kubectl exec -it -n ${var.namespace} ${var.release_name}-postgresql-0 -- psql -U postgres"
    check_replication       = "kubectl exec -n ${var.namespace} ${var.release_name}-postgresql-0 -- psql -U postgres -c 'SELECT * FROM pg_stat_replication;'"
    port_forward            = "kubectl port-forward -n ${var.namespace} svc/${var.release_name}-postgresql 5432:5432"
  }
}
