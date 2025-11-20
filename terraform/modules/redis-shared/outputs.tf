# Redis Shared - Module Outputs

# ==============================================================================
# Service Information
# ==============================================================================

output "redis_namespace" {
  description = "Kubernetes namespace where Redis is deployed"
  value       = kubernetes_namespace.redis.metadata[0].name
}

output "redis_master_service" {
  description = "Redis master ClusterIP service DNS name (for write operations)"
  value       = local.master_dns
}

output "redis_replicas_service" {
  description = "Redis replicas ClusterIP service DNS name (for read operations)"
  value       = local.replicas_dns
}

output "redis_external_service" {
  description = "Redis LoadBalancer service name (for private network access)"
  value       = "${var.release_name}-external"
}

output "redis_external_ip" {
  description = "Redis LoadBalancer external IP (accessible from 192.168.4.0/24)"
  value       = var.loadbalancer_ip
}

output "redis_port" {
  description = "Redis service port"
  value       = 6379
}

# ==============================================================================
# Authentication
# ==============================================================================

output "redis_secret_name" {
  description = "Kubernetes Secret name containing Redis password"
  value       = "redis-credentials"
}

output "redis_password" {
  description = "Redis authentication password (sensitive - use for automation only)"
  value       = random_password.redis_password.result
  sensitive   = true
}

# ==============================================================================
# Deployment Information
# ==============================================================================

output "helm_release_name" {
  description = "Helm release name for Redis deployment"
  value       = var.release_name
}

output "helm_release_status" {
  description = "Helm release deployment status"
  value       = helm_release.redis.status
}

output "replica_count" {
  description = "Number of Redis replica instances (not including primary)"
  value       = var.replica_count
}

output "total_instances" {
  description = "Total number of Redis instances (primary + replicas)"
  value       = 1 + var.replica_count
}

# ==============================================================================
# Connection Strings
# ==============================================================================

output "redis_connection_url_internal" {
  description = "Redis connection URL for cluster-internal access (requires password)"
  value       = "redis://${local.master_dns}:6379"
}

output "redis_connection_url_external" {
  description = "Redis connection URL for private network access (requires password)"
  value       = "redis://${var.loadbalancer_ip}:6379"
}

# ==============================================================================
# Replicated Secrets
# ==============================================================================

output "secret_replicated_namespaces" {
  description = "List of namespaces where Redis credentials Secret was replicated"
  value       = concat([var.namespace], var.replica_namespaces)
}
