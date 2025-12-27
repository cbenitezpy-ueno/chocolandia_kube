# Redis Groundhog2k - Outputs
# Output values for Redis deployment

# ==============================================================================
# Service Endpoints
# ==============================================================================

output "redis_service" {
  description = "Redis service DNS name for internal cluster access"
  value       = "${var.release_name}.${var.namespace}.svc.cluster.local"
}

output "redis_service_port" {
  description = "Redis service port"
  value       = 6379
}

output "redis_external_ip" {
  description = "Redis LoadBalancer IP for private network access"
  value       = var.loadbalancer_ip != "" ? var.loadbalancer_ip : "N/A - No LoadBalancer configured"
}

# ==============================================================================
# Connection URLs
# ==============================================================================

output "redis_connection_url_internal" {
  description = "Redis connection URL for cluster applications"
  value       = "redis://:PASSWORD@${var.release_name}.${var.namespace}.svc.cluster.local:6379"
  sensitive   = false
}

output "redis_connection_url_external" {
  description = "Redis connection URL for private network access"
  value       = var.loadbalancer_ip != "" ? "redis://:PASSWORD@${var.loadbalancer_ip}:6379" : "N/A"
  sensitive   = false
}

# ==============================================================================
# Credentials
# ==============================================================================

output "redis_secret_name" {
  description = "Kubernetes Secret containing Redis password"
  value       = kubernetes_secret.redis_credentials.metadata[0].name
}

output "redis_password_command" {
  description = "Command to retrieve Redis password"
  value       = "kubectl get secret -n ${var.namespace} redis-credentials -o jsonpath='{.data.redis-password}' | base64 -d"
  sensitive   = false
}

output "secret_replicated_namespaces" {
  description = "Namespaces where Redis credentials were replicated"
  value       = var.replica_namespaces
}

# ==============================================================================
# Deployment Info
# ==============================================================================

output "namespace" {
  description = "Namespace where Redis is deployed"
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

output "redis_image" {
  description = "Redis Docker image being used"
  value       = "docker.io/redis:${var.redis_image_tag}"
}

output "ha_enabled" {
  description = "Whether HA mode is enabled"
  value       = var.ha_enabled
}

# ==============================================================================
# Verification Commands
# ==============================================================================

output "verification_commands" {
  description = "Commands to verify Redis deployment"
  value = {
    check_pods     = "kubectl get pods -n ${var.namespace} -l app.kubernetes.io/instance=${var.release_name}"
    check_service  = "kubectl get svc -n ${var.namespace}"
    get_password   = "kubectl get secret -n ${var.namespace} redis-credentials -o jsonpath='{.data.redis-password}' | base64 -d"
    test_connection = "kubectl run redis-test --rm -it --image=redis:8.4-alpine -- redis-cli -h ${var.release_name}.${var.namespace}.svc.cluster.local -a $(kubectl get secret -n ${var.namespace} redis-credentials -o jsonpath='{.data.redis-password}' | base64 -d) PING"
  }
}
