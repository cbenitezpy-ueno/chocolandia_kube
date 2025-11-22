# Alerting Rules Module - Outputs
# Feature: 014-monitoring-alerts

output "node_alerts_name" {
  description = "Name of the node alerts PrometheusRule"
  value       = "homelab-node-alerts"
}

output "service_alerts_name" {
  description = "Name of the service alerts PrometheusRule"
  value       = "homelab-service-alerts"
}

output "alert_rules_summary" {
  description = "Summary of configured alert rules"
  value = {
    node_alerts = [
      "NodeDown",
      "NodeNotReady",
      "NodeDiskUsageWarning",
      "NodeDiskUsageCritical",
      "NodeMemoryUsageWarning",
      "NodeMemoryUsageCritical",
      "NodeCPUUsageWarning",
      "NodeCPUUsageCritical"
    ]
    service_alerts = [
      "PodCrashLooping",
      "PodNotReady",
      "DeploymentReplicasMismatch",
      "StatefulSetReplicasMismatch",
      "ContainerOOMKilled",
      "PVCAlmostFull",
      "ServiceEndpointDown"
    ]
  }
}
