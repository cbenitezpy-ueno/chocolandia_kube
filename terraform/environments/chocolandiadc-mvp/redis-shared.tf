# Redis Shared Caching Service
# Feature 013: Redis Deployment with Beersystem Migration
#
# Deploys a shared Redis caching layer with 2 instances (primary + replica)
# accessible within the Kubernetes cluster and from the private network (192.168.4.0/24).
# Includes persistent storage, authentication, monitoring integration, and MetalLB LoadBalancer.
#
# Migration Path:
# 1. Deploy redis-shared (this module)
# 2. Validate connectivity and monitoring
# 3. Migrate beersystem application (see beersystem-migration.tf)
# 4. Decommission old beersystem Redis after 24+ hour validation

module "redis_shared" {
  source = "../../modules/redis-shared"

  # Core Configuration
  release_name = "redis-shared"
  namespace    = "redis"

  # Secret Replication for Cross-Namespace Access
  # Creates redis-credentials Secret in both "redis" and "beersystem" namespaces
  replica_namespaces = ["beersystem"]

  # Helm Chart Version
  chart_repository = "https://charts.bitnami.com/bitnami"
  chart_version    = "23.2.12"  # Keep: Bitnami images unavailable in newer versions
  helm_timeout     = 600       # 10 minutes

  # Storage Configuration
  storage_class = "local-path"
  storage_size  = "10Gi" # Per instance

  # Redis Architecture (1 primary + 1 replica = 2 instances total)
  replica_count = 1

  # Master Instance Resources
  master_cpu_request    = "500m"
  master_cpu_limit      = "1000m"
  master_memory_request = "1Gi"
  master_memory_limit   = "2Gi"

  # Replica Instance Resources
  replica_cpu_request    = "250m"
  replica_cpu_limit      = "1000m"
  replica_memory_request = "1Gi"
  replica_memory_limit   = "2Gi"

  # Monitoring Integration
  enable_metrics         = true
  enable_service_monitor = true
  monitoring_namespace   = "monitoring"

  # Private Network Access (MetalLB LoadBalancer)
  loadbalancer_ip = "192.168.4.203" # From MetalLB pool 192.168.4.200-210
  metallb_ip_pool = "eero-pool"

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

  # Security: Disable dangerous commands
  disable_commands = ["FLUSHDB", "FLUSHALL", "CONFIG", "SHUTDOWN"]
}

# ==============================================================================
# Outputs
# ==============================================================================

output "redis_master_service" {
  description = "Redis master service DNS (for write operations)"
  value       = module.redis_shared.redis_master_service
}

output "redis_replicas_service" {
  description = "Redis replicas service DNS (for read operations)"
  value       = module.redis_shared.redis_replicas_service
}

output "redis_external_ip" {
  description = "Redis LoadBalancer IP (private network 192.168.4.0/24)"
  value       = module.redis_shared.redis_external_ip
}

output "redis_secret_name" {
  description = "Kubernetes Secret containing Redis password"
  value       = module.redis_shared.redis_secret_name
}

output "redis_connection_url_internal" {
  description = "Redis connection URL for cluster applications"
  value       = module.redis_shared.redis_connection_url_internal
}

output "redis_connection_url_external" {
  description = "Redis connection URL for private network access"
  value       = module.redis_shared.redis_connection_url_external
}

output "redis_secret_replicated_namespaces" {
  description = "Namespaces where Redis credentials were replicated"
  value       = module.redis_shared.secret_replicated_namespaces
}

output "redis_total_instances" {
  description = "Total Redis instances (primary + replicas)"
  value       = module.redis_shared.total_instances
}
