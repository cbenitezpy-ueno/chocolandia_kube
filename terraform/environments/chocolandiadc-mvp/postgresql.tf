# PostgreSQL Database Service (Groundhog2k)
# Feature 011: PostgreSQL Cluster Database Service
#
# Deploys PostgreSQL using official Docker images (not Bitnami) for better
# long-term support and availability. Migrated from Bitnami due to
# licensing changes in August 2025.
#
# Uses groundhog2k/postgres chart with official docker.io/postgres images.

module "postgresql" {
  source = "../../modules/postgresql-groundhog2k"

  # Core Configuration
  release_name = "postgres-ha"
  namespace    = "postgresql"

  # Helm Chart Version
  chart_repository = "https://groundhog2k.github.io/helm-charts/"
  chart_version    = "1.6.1"
  helm_timeout     = 600

  # PostgreSQL Image (official)
  postgres_image_tag = "17-alpine"

  # Database Configuration
  postgres_database    = "app_db"
  postgres_user        = "app_user"
  additional_databases = ["beersystem_stage"]

  # Storage Configuration
  storage_class = "local-path"
  storage_size  = "50Gi"

  # Resource Limits
  cpu_request    = "500m"
  cpu_limit      = "2"
  memory_request = "1Gi"
  memory_limit   = "4Gi"

  # Private Network Access (MetalLB LoadBalancer)
  # Note: 192.168.4.200 is used by pihole-dns, using 192.168.4.204 (first available)
  loadbalancer_ip = "192.168.4.204"
  metallb_ip_pool = "eero-pool"

  # Monitoring Integration
  enable_metrics         = true
  enable_service_monitor = true
  monitoring_namespace   = "monitoring"
}

# ==============================================================================
# Outputs
# ==============================================================================

output "postgresql_service" {
  description = "PostgreSQL service DNS (for read/write operations)"
  value       = module.postgresql.postgresql_service
}

output "postgresql_external_ip" {
  description = "PostgreSQL LoadBalancer IP (private network 192.168.4.0/24)"
  value       = module.postgresql.postgresql_external_ip
}

output "postgresql_secret_name" {
  description = "Kubernetes Secret containing PostgreSQL credentials"
  value       = module.postgresql.postgresql_secret_name
}

output "postgresql_connection_url_internal" {
  description = "PostgreSQL connection URL for cluster applications"
  value       = module.postgresql.postgresql_connection_url_internal
}

output "postgresql_connection_url_external" {
  description = "PostgreSQL connection URL for private network access"
  value       = module.postgresql.postgresql_connection_url_external
}

output "postgresql_image" {
  description = "PostgreSQL Docker image being used"
  value       = module.postgresql.postgresql_image
}

output "postgresql_verification_commands" {
  description = "Commands to verify PostgreSQL deployment"
  value       = module.postgresql.verification_commands
}
