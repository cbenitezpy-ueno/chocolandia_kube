# Monitoring Stack Configuration
# Deploys kube-prometheus-stack (Prometheus + Grafana + Alertmanager)

# ============================================================================
# Monitoring Namespace
# ============================================================================

resource "null_resource" "monitoring_namespace" {
  depends_on = [module.master1]

  triggers = {
    kubeconfig = fileexists("${path.root}/kubeconfig") ? filemd5("${path.root}/kubeconfig") : ""
  }

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.root}/kubeconfig
      kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    EOT
  }
}

# ============================================================================
# Kube-Prometheus-Stack Helm Release
# ============================================================================

resource "helm_release" "kube_prometheus_stack" {
  depends_on = [
    module.master1,
    module.nodo1,
    null_resource.monitoring_namespace
  ]

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.5.0" # Compatible with K3s v1.28
  namespace  = "monitoring"

  timeout = 600 # 10 minutes for initial deployment

  # ============================================================================
  # Prometheus Configuration
  # ============================================================================

  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d" # Retain metrics for 15 days
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }

  # Prometheus service configuration
  set {
    name  = "prometheus.service.type"
    value = "ClusterIP" # Access via port-forward or Grafana
  }

  # ============================================================================
  # Grafana Configuration
  # ============================================================================

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.adminPassword"
    value = "prom-operator" # Default admin password
  }

  # Expose Grafana via NodePort on port 30000
  set {
    name  = "grafana.service.type"
    value = "NodePort"
  }

  set {
    name  = "grafana.service.nodePort"
    value = "30000"
  }

  # Grafana persistence
  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  set {
    name  = "grafana.persistence.size"
    value = "5Gi"
  }

  # ============================================================================
  # Node Exporter Configuration
  # ============================================================================

  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }

  # Deploy node-exporter on all nodes
  set {
    name  = "prometheus-node-exporter.hostNetwork"
    value = "true"
  }

  set {
    name  = "prometheus-node-exporter.hostPID"
    value = "true"
  }

  # ============================================================================
  # Kube-State-Metrics Configuration
  # ============================================================================

  set {
    name  = "kubeStateMetrics.enabled"
    value = "true"
  }

  # ============================================================================
  # Alertmanager Configuration
  # ============================================================================

  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  set {
    name  = "alertmanager.service.type"
    value = "ClusterIP" # Access via port-forward
  }

  # ============================================================================
  # Custom Scrape Configurations
  # ============================================================================

  # Additional scrape configs for node metrics
  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          # Service monitor selector to discover services
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false

          # Additional scrape configurations for node metrics
          additionalScrapeConfigs = [
            {
              job_name = "kubernetes-nodes"
              kubernetes_sd_configs = [
                {
                  role = "node"
                }
              ]
              relabel_configs = [
                {
                  source_labels = ["__address__"]
                  regex         = "([^:]+)(?::\\d+)?"
                  target_label  = "__address__"
                  replacement   = "$1:9100" # node-exporter port
                },
                {
                  source_labels = ["__meta_kubernetes_node_name"]
                  target_label  = "node"
                },
                {
                  source_labels = ["__meta_kubernetes_node_address_InternalIP"]
                  target_label  = "instance"
                }
              ]
            }
          ]
        }
      }

      # Grafana dashboards configuration
      grafana = {
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name    = "default"
                orgId   = 1
                folder  = ""
                type    = "file"
                disableDeletion = false
                editable       = true
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }

        # Pre-configured dashboards
        dashboards = {
          default = {
            "k3s-cluster-overview" = {
              gnetId    = 15282 # K3s cluster monitoring dashboard
              revision  = 1
              datasource = "Prometheus"
            }
            "node-exporter-full" = {
              gnetId    = 1860 # Node Exporter Full
              revision  = 31
              datasource = "Prometheus"
            }
            "kubernetes-cluster-monitoring" = {
              gnetId    = 7249 # Kubernetes Cluster Monitoring
              revision  = 1
              datasource = "Prometheus"
            }
          }
        }
      }
    })
  ]
}

# ============================================================================
# Outputs
# ============================================================================

output "grafana_url" {
  description = "Grafana access URL via NodePort"
  value       = "http://${var.master1_ip}:30000"
}

output "grafana_admin_password" {
  description = "Grafana admin password (default)"
  value       = "prom-operator"
  sensitive   = true
}

output "prometheus_port_forward_command" {
  description = "Command to access Prometheus UI via port-forward"
  value       = "kubectl --kubeconfig=${path.root}/kubeconfig port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
}

output "alertmanager_port_forward_command" {
  description = "Command to access Alertmanager UI via port-forward"
  value       = "kubectl --kubeconfig=${path.root}/kubeconfig port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
}
