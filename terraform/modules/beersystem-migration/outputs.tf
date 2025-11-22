# Beersystem Migration - Outputs
# Information about the migrated beersystem-backend deployment

output "deployment_name" {
  description = "Name of the beersystem-backend deployment"
  value       = "beersystem-backend"
}

output "namespace" {
  description = "Namespace where beersystem-backend is deployed"
  value       = "beersystem"
}

output "redis_host" {
  description = "Redis host configured for beersystem-backend"
  value       = var.redis_host
}

output "redis_port" {
  description = "Redis port configured for beersystem-backend"
  value       = var.redis_port
}

output "current_replicas" {
  description = "Current replica count (0 during migration, 1 after)"
  value       = var.replicas
}

output "backend_image" {
  description = "Backend container image in use"
  value       = var.backend_image
}

output "migration_label" {
  description = "Label indicating migration completion"
  value       = "migrated-to-redis-shared=true"
}

output "redis_secret_name" {
  description = "Secret name used for Redis password"
  value       = var.redis_secret_name
}
