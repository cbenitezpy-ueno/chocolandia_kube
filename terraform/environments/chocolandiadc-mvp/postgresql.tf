# PostgreSQL HA Cluster Deployment
# Feature 011: PostgreSQL Cluster Database Service
#
# Deploys PostgreSQL HA cluster with primary-replica topology for:
# - Application database connectivity (User Story 1)
# - Internal network administrator access (User Story 2)

module "postgresql_cluster" {
  source = "../../modules/postgresql-cluster"

  # Basic configuration
  namespace        = "postgresql"
  release_name     = "postgres-ha"
  postgresql_version = "16"

  # High availability configuration
  replica_count    = 2  # 1 primary + 1 replica
  replication_mode = "async"

  # Storage configuration
  storage_size  = "50Gi"
  storage_class = "local-path"  # K3s local-path-provisioner

  # Resource limits (per pod)
  resources_limits_cpu    = "2"
  resources_limits_memory = "4Gi"
  resources_requests_cpu  = "500m"
  resources_requests_memory = "1Gi"

  # Network configuration
  enable_external_access = true
  metallb_ip_pool       = "eero-pool"

  # Monitoring configuration
  enable_metrics         = true
  enable_service_monitor = true

  # Security configuration
  create_random_passwords = true  # Auto-generate secure passwords

  # Helm chart configuration
  chart_version = "16.3.2"  # Latest Bitnami PostgreSQL HA chart version
  helm_timeout  = 600  # 10 minutes for initial deployment
}

# ==============================================================================
# Outputs for PostgreSQL Connection Information
# ==============================================================================

output "postgresql_cluster_ip_endpoint" {
  description = "PostgreSQL ClusterIP service endpoint for cluster-internal access"
  value       = module.postgresql_cluster.cluster_ip_service_endpoint
}

output "postgresql_read_replica_endpoint" {
  description = "PostgreSQL read replica service endpoint"
  value       = module.postgresql_cluster.read_replica_service_endpoint
}

output "postgresql_external_ip_command" {
  description = "Command to get PostgreSQL external IP (MetalLB LoadBalancer)"
  value       = module.postgresql_cluster.external_ip
}

output "postgresql_credentials_secret" {
  description = "Kubernetes Secret name containing PostgreSQL credentials"
  value       = module.postgresql_cluster.credentials_secret_name
}

output "postgresql_password_command" {
  description = "Command to retrieve postgres superuser password"
  value       = module.postgresql_cluster.postgres_password_command
  sensitive   = true
}

output "postgresql_verification_commands" {
  description = "Useful commands for verifying PostgreSQL deployment"
  value       = module.postgresql_cluster.verification_commands
}
