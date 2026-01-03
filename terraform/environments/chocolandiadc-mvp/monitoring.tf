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

locals {
  prometheus_stack_version = "68.4.0" # Upgraded from 55.5.0 (021-monitoring-stack-upgrade)
}

resource "helm_release" "kube_prometheus_stack" {
  depends_on = [
    module.master1,
    module.nodo1,
    null_resource.monitoring_namespace
  ]

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = local.prometheus_stack_version
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
  # Note: hostNetwork disabled due to persistent K3s scheduler port conflict issue
  # The scheduler falsely reports port 9100 as in-use even when it's not
  set {
    name  = "prometheus-node-exporter.hostNetwork"
    value = "false"
  }

  set {
    name  = "prometheus-node-exporter.hostPID"
    value = "false"
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
      # Disable K3s components that don't expose metrics (false positives)
      # K3s embeds controller-manager, scheduler, and kube-proxy in the k3s binary
      kubeControllerManager = {
        enabled = false
      }
      kubeScheduler = {
        enabled = false
      }
      kubeProxy = {
        enabled = false
      }
      defaultRules = {
        rules = {
          kubeControllerManager = false
          kubeSchedulerAlerting = false
          kubeSchedulerRecording = false
          kubeProxy             = false
        }
      }

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

      # Alertmanager configuration for Ntfy notifications
      alertmanager = {
        alertmanagerSpec = {
          alertmanagerConfigMatcherStrategy = {
            type = "None"
          }
          # Mount ntfy password secret for authenticated webhooks
          secrets = ["ntfy-alertmanager-password"]
        }
        config = {
          global = {
            resolve_timeout = "5m"
          }
          route = {
            receiver        = "ntfy-homelab"
            group_by        = ["alertname", "namespace", "severity"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "4h"
            routes = [
              {
                receiver        = "ntfy-critical"
                matchers        = ["severity=critical"]
                repeat_interval = "1h"
                continue        = false
              },
              {
                receiver = "null"
                matchers = ["alertname=Watchdog"]
              }
            ]
          }
          receivers = [
            {
              name = "null"
            },
            {
              name = "ntfy-homelab"
              webhook_configs = [
                {
                  url           = "http://ntfy.ntfy.svc.cluster.local/homelab-alerts?template=alertmanager"
                  send_resolved = true
                  http_config = {
                    basic_auth = {
                      username      = "alertmanager"
                      password_file = "/etc/alertmanager/secrets/ntfy-alertmanager-password/password"
                    }
                  }
                }
              ]
            },
            {
              name = "ntfy-critical"
              webhook_configs = [
                {
                  url           = "http://ntfy.ntfy.svc.cluster.local/homelab-alerts?template=alertmanager"
                  send_resolved = true
                  http_config = {
                    basic_auth = {
                      username      = "alertmanager"
                      password_file = "/etc/alertmanager/secrets/ntfy-alertmanager-password/password"
                    }
                  }
                }
              ]
            }
          ]
          inhibit_rules = [
            {
              source_matchers = ["severity=critical"]
              target_matchers = ["severity=warning"]
              equal           = ["alertname", "namespace"]
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
                name            = "default"
                orgId           = 1
                folder          = ""
                type            = "file"
                disableDeletion = false
                editable        = true
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
            # Cluster Overview
            "k3s-cluster-overview" = {
              gnetId     = 15282 # K3s cluster monitoring dashboard
              revision   = 1
              datasource = "Prometheus"
            }
            "node-exporter-full" = {
              gnetId     = 1860 # Node Exporter Full
              revision   = 31
              datasource = "Prometheus"
            }
            "kubernetes-cluster-monitoring" = {
              gnetId     = 7249 # Kubernetes Cluster Monitoring
              revision   = 1
              datasource = "Prometheus"
            }
            # Application Dashboards (Golden Signals)
            "traefik" = {
              gnetId     = 17346 # Traefik Official Standalone Dashboard
              revision   = 9
              datasource = "Prometheus"
            }
            "redis" = {
              gnetId     = 763 # Redis Dashboard
              revision   = 6
              datasource = "Prometheus"
            }
            "postgresql" = {
              gnetId     = 9628 # PostgreSQL Database
              revision   = 7
              datasource = "Prometheus"
            }
            "longhorn" = {
              gnetId     = 16888 # Longhorn Dashboard
              revision   = 9
              datasource = "Prometheus"
            }
            "coredns" = {
              gnetId     = 15038 # CoreDNS
              revision   = 3
              datasource = "Prometheus"
            }
            "kubernetes-pods" = {
              gnetId     = 6417 # Kubernetes Pods
              revision   = 1
              datasource = "Prometheus"
            }
          }
        }

        # Configure sidecar to pick up ConfigMaps with dashboards
        sidecar = {
          dashboards = {
            enabled         = true
            label           = "grafana_dashboard"
            labelValue      = "1"
            searchNamespace = "ALL"
          }
        }
      }
    })
  ]
}

# ============================================================================
# Custom Dashboard - Homelab Overview
# ============================================================================

resource "kubernetes_config_map" "homelab_overview_dashboard" {
  depends_on = [null_resource.monitoring_namespace]

  metadata {
    name      = "homelab-overview-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "homelab-overview.json" = file("${path.module}/../../dashboards/homelab-overview.json")
  }
}

# ============================================================================
# Custom Dashboard - Drobo Storage
# ============================================================================

resource "kubernetes_config_map" "drobo_dashboard" {
  depends_on = [null_resource.monitoring_namespace]

  metadata {
    name      = "drobo-storage-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "drobo-storage.json" = file("${path.module}/../../dashboards/drobo-storage.json")
  }
}

# ============================================================================
# Drobo Exporter
# ============================================================================

module "drobo_exporter" {
  source = "../../modules/drobo-exporter"

  namespace  = "monitoring"
  drobo_node = "nodo05"

  depends_on = [helm_release.kube_prometheus_stack]
}

# ============================================================================
# Outputs
# ============================================================================

output "drobo_exporter_service" {
  description = "Drobo exporter service endpoint"
  value       = module.drobo_exporter.exporter_service
}

output "drobo_alerts" {
  description = "Configured Drobo alerts"
  value       = module.drobo_exporter.alerts_configured
}

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
