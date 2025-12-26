# Redis Caching Service (Groundhog2k)
# Feature 013: Redis Deployment
#
# Deploys Redis using official Docker images (not Bitnami) for better
# long-term support and availability. Migrated from Bitnami due to
# licensing changes in August 2025.
#
# Uses groundhog2k/redis chart with official docker.io/redis images.

module "redis" {
  source = "../../modules/redis-groundhog2k"

  # Core Configuration
  release_name = "redis-shared"
  namespace    = "redis"

  # Secret Replication for Cross-Namespace Access
  replica_namespaces = ["beersystem"]

  # Helm Chart Version
  chart_repository = "https://groundhog2k.github.io/helm-charts/"
  chart_version    = "2.2.1"
  helm_timeout     = 600

  # Redis Image (official)
  redis_image_tag = "8.4.0-alpine"

  # Single instance mode (no HA for homelab)
  ha_enabled    = false
  replica_count = 1

  # Storage Configuration
  storage_class = "local-path"
  storage_size  = "10Gi"

  # Resource Limits
  cpu_request    = "250m"
  cpu_limit      = "1000m"
  memory_request = "512Mi"
  memory_limit   = "2Gi"

  # Private Network Access (MetalLB LoadBalancer)
  loadbalancer_ip = "192.168.4.203"
  metallb_ip_pool = "eero-pool"

  # Monitoring Integration
  enable_metrics         = true
  enable_service_monitor = true
  monitoring_namespace   = "monitoring"

  # Redis Configuration
  redis_config = <<-EOT
    maxmemory 1536mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly no
    loglevel notice
    slowlog-log-slower-than 10000
    slowlog-max-len 128
  EOT
}

# ==============================================================================
# Outputs
# ==============================================================================

output "redis_service" {
  description = "Redis service DNS (for read/write operations)"
  value       = module.redis.redis_service
}

output "redis_external_ip" {
  description = "Redis LoadBalancer IP (private network 192.168.4.0/24)"
  value       = module.redis.redis_external_ip
}

output "redis_secret_name" {
  description = "Kubernetes Secret containing Redis password"
  value       = module.redis.redis_secret_name
}

output "redis_connection_url_internal" {
  description = "Redis connection URL for cluster applications"
  value       = module.redis.redis_connection_url_internal
}

output "redis_connection_url_external" {
  description = "Redis connection URL for private network access"
  value       = module.redis.redis_connection_url_external
}

output "redis_secret_replicated_namespaces" {
  description = "Namespaces where Redis credentials were replicated"
  value       = module.redis.secret_replicated_namespaces
}

output "redis_image" {
  description = "Redis Docker image being used"
  value       = module.redis.redis_image
}

output "redis_verification_commands" {
  description = "Commands to verify Redis deployment"
  value       = module.redis.verification_commands
}
