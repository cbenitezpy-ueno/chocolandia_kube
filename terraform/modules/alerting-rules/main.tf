# Alerting Rules Module - Main
# Feature: 014-monitoring-alerts
# Creates PrometheusRule CRDs for node and service monitoring

# ============================================================================
# Node Alerting Rules (US1)
# ============================================================================

resource "kubernetes_manifest" "node_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "homelab-node-alerts"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"       = "alerting-rules"
        "app.kubernetes.io/managed-by" = "opentofu"
        "prometheus"                   = "kube-prometheus-stack"
        "release"                      = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        {
          name = "homelab-node-alerts"
          rules = [
            # Node Down Alert (Critical)
            {
              alert = "NodeDown"
              expr  = "up{job=\"kubernetes-nodes\"} == 0"
              for   = "${var.node_down_threshold_minutes}m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Node {{ $labels.instance }} is down"
                description = "Node {{ $labels.instance }} has been unreachable for more than ${var.node_down_threshold_minutes} minutes."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # Node Not Ready Alert (Warning)
            {
              alert = "NodeNotReady"
              expr  = "kube_node_status_condition{condition=\"Ready\",status=\"true\"} == 0"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Node {{ $labels.node }} is not ready"
                description = "Node {{ $labels.node }} has been in NotReady state for more than 5 minutes."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.node }}"
              }
            },
            # High Disk Usage (Warning)
            {
              alert = "NodeDiskUsageWarning"
              expr  = "(1 - (node_filesystem_avail_bytes{fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\"})) * 100 > ${var.disk_usage_warning_percent}"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High disk usage on {{ $labels.instance }}"
                description = "Disk {{ $labels.mountpoint }} on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}% full."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # Critical Disk Usage
            {
              alert = "NodeDiskUsageCritical"
              expr  = "(1 - (node_filesystem_avail_bytes{fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\"})) * 100 > ${var.disk_usage_critical_percent}"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Critical disk usage on {{ $labels.instance }}"
                description = "Disk {{ $labels.mountpoint }} on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}% full. Immediate action required!"
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # High Memory Usage (Warning)
            {
              alert = "NodeMemoryUsageWarning"
              expr  = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > ${var.memory_usage_warning_percent}"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High memory usage on {{ $labels.instance }}"
                description = "Memory usage on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}%."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # Critical Memory Usage
            {
              alert = "NodeMemoryUsageCritical"
              expr  = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > ${var.memory_usage_critical_percent}"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Critical memory usage on {{ $labels.instance }}"
                description = "Memory usage on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}%. System may become unstable!"
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # High CPU Usage (Warning)
            {
              alert = "NodeCPUUsageWarning"
              expr  = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > ${var.cpu_usage_warning_percent}"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High CPU usage on {{ $labels.instance }}"
                description = "CPU usage on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}%."
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            },
            # Critical CPU Usage
            {
              alert = "NodeCPUUsageCritical"
              expr  = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > ${var.cpu_usage_critical_percent}"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Critical CPU usage on {{ $labels.instance }}"
                description = "CPU usage on {{ $labels.instance }} is {{ printf \"%.1f\" $value }}%. Performance degradation expected!"
                dashboard   = "${var.grafana_url}/d/rYdddlPWk/node-exporter-full?var-node={{ $labels.instance }}"
              }
            }
          ]
        }
      ]
    }
  }
}

# ============================================================================
# Service Alerting Rules (US2)
# ============================================================================

resource "kubernetes_manifest" "service_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "homelab-service-alerts"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"       = "alerting-rules"
        "app.kubernetes.io/managed-by" = "opentofu"
        "prometheus"                   = "kube-prometheus-stack"
        "release"                      = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        {
          name = "homelab-service-alerts"
          rules = [
            # Pod CrashLooping
            {
              alert = "PodCrashLooping"
              expr  = "increase(kube_pod_container_status_restarts_total[1h]) > 3"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has restarted {{ printf \"%.0f\" $value }} times in the last hour."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # Pod Not Ready
            {
              alert = "PodNotReady"
              expr  = "kube_pod_status_ready{condition=\"true\"} == 0 and on(pod, namespace) kube_pod_status_phase{phase=\"Running\"} == 1"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is not ready"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in non-ready state for more than 10 minutes."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # Deployment Replicas Mismatch
            {
              alert = "DeploymentReplicasMismatch"
              expr  = "kube_deployment_spec_replicas != kube_deployment_status_replicas_available"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replicas mismatch"
                description = "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has {{ $value }} available replicas instead of desired."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # StatefulSet Replicas Mismatch
            {
              alert = "StatefulSetReplicasMismatch"
              expr  = "kube_statefulset_replicas != kube_statefulset_status_replicas_ready"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} replicas mismatch"
                description = "StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has {{ $value }} ready replicas instead of desired."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # Container OOMKilled
            {
              alert = "ContainerOOMKilled"
              expr  = "kube_pod_container_status_last_terminated_reason{reason=\"OOMKilled\"} == 1"
              for   = "0m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Container {{ $labels.container }} OOM killed"
                description = "Container {{ $labels.container }} in pod {{ $labels.namespace }}/{{ $labels.pod }} was OOM killed."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            },
            # PVC Almost Full
            {
              alert = "PVCAlmostFull"
              expr  = "(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 85"
              for   = "15m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} almost full"
                description = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is {{ printf \"%.1f\" $value }}% full."
                dashboard   = "${var.grafana_url}/d/919b92a8e8041bd567af9edab12c840c/kubernetes-persistent-volumes"
              }
            },
            # Service Endpoint Down
            {
              alert = "ServiceEndpointDown"
              expr  = "kube_endpoint_address_available == 0"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Service {{ $labels.namespace }}/{{ $labels.endpoint }} has no endpoints"
                description = "Service {{ $labels.namespace }}/{{ $labels.endpoint }} has no available endpoints for more than 5 minutes."
                dashboard   = "${var.grafana_url}/d/85a562078cdf77779eaa1add43ccec1e/kubernetes-compute-resources-namespace-pods?var-namespace={{ $labels.namespace }}"
              }
            }
          ]
        }
      ]
    }
  }
}
