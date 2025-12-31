# ============================================================================
# Loki Log Aggregation
# ============================================================================
# Deploys Grafana Loki for centralized log aggregation
# Promtail collects logs from all nodes and sends to Loki
# Integrated with existing Grafana for log visualization
# ============================================================================

module "loki" {
  source = "../../modules/loki"

  namespace         = "loki"
  grafana_namespace = "monitoring"

  # Storage (using Longhorn)
  persistence_enabled = true
  persistence_size    = "10Gi"
  storage_class_name  = "longhorn"

  # Retention: 7 days (same as Prometheus metrics)
  retention_period = "168h"

  # Loki resources (suitable for homelab)
  loki_resources_requests_cpu    = "100m"
  loki_resources_requests_memory = "256Mi"
  loki_resources_limits_cpu      = "500m"
  loki_resources_limits_memory   = "512Mi"

  # Promtail resources (runs on each node)
  promtail_resources_requests_cpu    = "50m"
  promtail_resources_requests_memory = "64Mi"
  promtail_resources_limits_cpu      = "200m"
  promtail_resources_limits_memory   = "128Mi"

  # Enable Prometheus monitoring
  enable_service_monitor = true
}

# ============================================================================
# Outputs
# ============================================================================

output "loki_namespace" {
  description = "Namespace where Loki is deployed"
  value       = module.loki.namespace
}

output "loki_url" {
  description = "Internal URL for Loki"
  value       = module.loki.loki_url
}

output "loki_grafana_usage" {
  description = "How to use Loki in Grafana"
  value = {
    datasource = "Loki datasource is auto-configured in Grafana"
    explore    = "Go to Grafana -> Explore -> Select 'Loki' datasource"
    query      = "Use LogQL: {namespace=\"default\"} or {app=\"myapp\"}"
  }
}
