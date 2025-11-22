# Alerting Rules Configuration
# Feature: 014-monitoring-alerts
# Deploys PrometheusRule CRDs for node and service monitoring

module "alerting_rules" {
  source = "../../modules/alerting-rules"

  namespace   = "monitoring"
  grafana_url = "http://192.168.4.101:30000"

  # Node alert thresholds
  node_down_threshold_minutes = 5

  # Disk thresholds
  disk_usage_warning_percent  = 80
  disk_usage_critical_percent = 90

  # Memory thresholds
  memory_usage_warning_percent  = 80
  memory_usage_critical_percent = 90

  # CPU thresholds
  cpu_usage_warning_percent  = 80
  cpu_usage_critical_percent = 90

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

# ============================================================================
# Outputs
# ============================================================================

output "alerting_rules_summary" {
  description = "Summary of deployed alert rules"
  value       = module.alerting_rules.alert_rules_summary
}
