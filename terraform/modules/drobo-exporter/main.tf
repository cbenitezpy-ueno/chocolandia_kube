# ============================================================================
# Drobo Prometheus Exporter
# Exports metrics from Drobo storage devices for monitoring
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for the exporter"
  type        = string
  default     = "monitoring"
}

variable "node_selector" {
  description = "Node selector for the exporter pods"
  type        = map(string)
  default     = {}
}

variable "drobo_node" {
  description = "Node where Drobo is attached"
  type        = string
}

# ConfigMap with the exporter script
resource "kubernetes_config_map" "drobo_exporter_script" {
  metadata {
    name      = "drobo-exporter-script"
    namespace = var.namespace
  }

  data = {
    "drobo_exporter.py" = <<-EOF
#!/usr/bin/env python3
"""
Drobo Prometheus Exporter
Exports Drobo storage metrics for Prometheus scraping
"""

import subprocess
import re
import http.server
import socketserver
import time
import os

PORT = int(os.environ.get('EXPORTER_PORT', 9417))
DROBO_DEVICE = os.environ.get('DROBO_DEVICE', '/dev/sdb')

def get_drobo_info():
    """Run drobom info and parse output"""
    try:
        result = subprocess.run(
            ['python3', '/opt/drobo-utils/drobom', 'info'],
            capture_output=True, text=True, timeout=30
        )
        return result.stdout
    except Exception as e:
        return None

def parse_drobo_info(output):
    """Parse drobom info output into metrics"""
    metrics = {
        'drobo_up': 0,
        'drobo_capacity_total_bytes': 0,
        'drobo_capacity_used_bytes': 0,
        'drobo_capacity_free_bytes': 0,
        'drobo_redundancy': 0,
        'slots': []
    }

    if not output:
        return metrics

    metrics['drobo_up'] = 1

    # Parse capacity line: "Capacity (in GB):  used: 1, free: 1873, total: 1874"
    cap_match = re.search(r'Capacity \(in GB\):\s+used:\s*(\d+),\s*free:\s*(\d+),\s*total:\s*(\d+)', output)
    if cap_match:
        metrics['drobo_capacity_used_bytes'] = int(cap_match.group(1)) * 1024 * 1024 * 1024
        metrics['drobo_capacity_free_bytes'] = int(cap_match.group(2)) * 1024 * 1024 * 1024
        metrics['drobo_capacity_total_bytes'] = int(cap_match.group(3)) * 1024 * 1024 * 1024

    # Parse redundancy from status line
    if 'No redundancy' in output:
        metrics['drobo_redundancy'] = 0
    else:
        metrics['drobo_redundancy'] = 1

    # Parse slot info
    # slot   GB                Model               Status
    #    0    0                                       red
    #    1 4000 WDC WD4000FYYZ-0SATA                green
    slot_pattern = re.compile(r'^\s*(\d+)\s+(\d+)\s+(.{35})\s*(red|green|yellow|gray)', re.MULTILINE)
    for match in slot_pattern.finditer(output):
        slot_num = int(match.group(1))
        size_gb = int(match.group(2))
        model = match.group(3).strip()
        status = match.group(4)

        status_value = {'gray': 0, 'green': 1, 'yellow': 2, 'red': 3}.get(status, -1)

        metrics['slots'].append({
            'slot': slot_num,
            'size_bytes': size_gb * 1024 * 1024 * 1024,
            'status': status_value,
            'status_label': status,
            'model': model if model else 'empty'
        })

    # Parse firmware version
    fw_match = re.search(r'Firmware:\s*(\S+)', output)
    if fw_match:
        metrics['firmware_version'] = fw_match.group(1)

    return metrics

def format_prometheus_metrics(metrics):
    """Format metrics in Prometheus exposition format"""
    lines = []

    # Help and type declarations
    lines.append('# HELP drobo_up Whether the Drobo device is accessible (1=up, 0=down)')
    lines.append('# TYPE drobo_up gauge')
    lines.append(f'drobo_up{{device="{DROBO_DEVICE}"}} {metrics["drobo_up"]}')

    lines.append('# HELP drobo_capacity_total_bytes Total capacity in bytes')
    lines.append('# TYPE drobo_capacity_total_bytes gauge')
    lines.append(f'drobo_capacity_total_bytes{{device="{DROBO_DEVICE}"}} {metrics["drobo_capacity_total_bytes"]}')

    lines.append('# HELP drobo_capacity_used_bytes Used capacity in bytes')
    lines.append('# TYPE drobo_capacity_used_bytes gauge')
    lines.append(f'drobo_capacity_used_bytes{{device="{DROBO_DEVICE}"}} {metrics["drobo_capacity_used_bytes"]}')

    lines.append('# HELP drobo_capacity_free_bytes Free capacity in bytes')
    lines.append('# TYPE drobo_capacity_free_bytes gauge')
    lines.append(f'drobo_capacity_free_bytes{{device="{DROBO_DEVICE}"}} {metrics["drobo_capacity_free_bytes"]}')

    lines.append('# HELP drobo_redundancy Whether data redundancy is enabled (1=yes, 0=no)')
    lines.append('# TYPE drobo_redundancy gauge')
    lines.append(f'drobo_redundancy{{device="{DROBO_DEVICE}"}} {metrics["drobo_redundancy"]}')

    lines.append('# HELP drobo_slot_status Status of each drive slot (0=empty, 1=green, 2=yellow, 3=red)')
    lines.append('# TYPE drobo_slot_status gauge')
    for slot in metrics.get('slots', []):
        lines.append(f'drobo_slot_status{{device="{DROBO_DEVICE}",slot="{slot["slot"]}",model="{slot["model"]}",status_label="{slot["status_label"]}"}} {slot["status"]}')

    lines.append('# HELP drobo_slot_size_bytes Size of drive in each slot in bytes')
    lines.append('# TYPE drobo_slot_size_bytes gauge')
    for slot in metrics.get('slots', []):
        lines.append(f'drobo_slot_size_bytes{{device="{DROBO_DEVICE}",slot="{slot["slot"]}"}} {slot["size_bytes"]}')

    return '\n'.join(lines) + '\n'

class MetricsHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            output = get_drobo_info()
            metrics = parse_drobo_info(output)
            response = format_prometheus_metrics(metrics)

            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(response.encode())
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress logging

if __name__ == '__main__':
    print(f"Starting Drobo Exporter on port {PORT}")
    with socketserver.TCPServer(("", PORT), MetricsHandler) as httpd:
        httpd.serve_forever()
EOF

    "Drobo.py" = file("${path.module}/drobo-utils/Drobo.py")
    "DroboIOctl.py" = file("${path.module}/drobo-utils/DroboIOctl.py")
    "drobom" = file("${path.module}/drobo-utils/drobom")
  }
}

# DaemonSet to run on nodes with Drobo attached
resource "kubernetes_daemon_set_v1" "drobo_exporter" {
  metadata {
    name      = "drobo-exporter"
    namespace = var.namespace
    labels = {
      app = "drobo-exporter"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "drobo-exporter"
      }
    }

    template {
      metadata {
        labels = {
          app = "drobo-exporter"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9417"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        node_selector = {
          "kubernetes.io/hostname" = var.drobo_node
        }

        host_network = true

        container {
          name  = "drobo-exporter"
          image = "python:3.12-slim"

          command = ["python3", "/opt/drobo-exporter/drobo_exporter.py"]

          port {
            container_port = 9417
            host_port      = 9417
            name           = "metrics"
          }

          env {
            name  = "EXPORTER_PORT"
            value = "9417"
          }

          env {
            name  = "DROBO_DEVICE"
            value = "/dev/sdb"
          }

          volume_mount {
            name       = "scripts"
            mount_path = "/opt/drobo-exporter"
          }

          volume_mount {
            name       = "drobo-utils"
            mount_path = "/opt/drobo-utils"
          }

          volume_mount {
            name       = "dev"
            mount_path = "/dev"
          }

          security_context {
            privileged = true
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "64Mi"
            }
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 9417
            }
            initial_delay_seconds = 10
            period_seconds        = 30
          }
        }

        volume {
          name = "scripts"
          config_map {
            name         = kubernetes_config_map.drobo_exporter_script.metadata[0].name
            default_mode = "0755"
            items {
              key  = "drobo_exporter.py"
              path = "drobo_exporter.py"
            }
          }
        }

        volume {
          name = "drobo-utils"
          config_map {
            name         = kubernetes_config_map.drobo_exporter_script.metadata[0].name
            default_mode = "0755"
            items {
              key  = "Drobo.py"
              path = "Drobo.py"
            }
            items {
              key  = "DroboIOctl.py"
              path = "DroboIOctl.py"
            }
            items {
              key  = "drobom"
              path = "drobom"
            }
          }
        }

        volume {
          name = "dev"
          host_path {
            path = "/dev"
          }
        }

        toleration {
          operator = "Exists"
        }
      }
    }
  }
}

# Service for the exporter
resource "kubernetes_service_v1" "drobo_exporter" {
  metadata {
    name      = "drobo-exporter"
    namespace = var.namespace
    labels = {
      app = "drobo-exporter"
    }
  }

  spec {
    selector = {
      app = "drobo-exporter"
    }

    port {
      port        = 9417
      target_port = 9417
      name        = "metrics"
    }

    type = "ClusterIP"
  }
}

# ServiceMonitor for Prometheus
resource "kubernetes_manifest" "drobo_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "drobo-exporter"
      namespace = var.namespace
      labels = {
        app     = "drobo-exporter"
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "drobo-exporter"
        }
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "60s"
          path     = "/metrics"
        }
      ]
    }
  }
}

# PrometheusRule for Drobo alerts
resource "kubernetes_manifest" "drobo_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "drobo-alerts"
      namespace = var.namespace
      labels = {
        app     = "drobo-exporter"
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        {
          name = "drobo"
          rules = [
            {
              alert = "DroboDown"
              expr  = "drobo_up == 0"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Drobo device is down"
                description = "Drobo device {{ $labels.device }} has been unreachable for more than 5 minutes."
              }
            },
            {
              alert = "DroboNoRedundancy"
              expr  = "drobo_redundancy == 0"
              for   = "1h"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Drobo has no data redundancy"
                description = "Drobo device {{ $labels.device }} has no data redundancy. Add another drive to enable protection."
              }
            },
            {
              alert = "DroboSlotRed"
              expr  = "drobo_slot_status == 3"
              for   = "1m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Drobo drive slot is red (failed)"
                description = "Drobo device {{ $labels.device }} slot {{ $labels.slot }} has a failed drive ({{ $labels.model }}). Replace immediately."
              }
            },
            {
              alert = "DroboSlotYellow"
              expr  = "drobo_slot_status == 2"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Drobo drive slot is yellow (warning)"
                description = "Drobo device {{ $labels.device }} slot {{ $labels.slot }} has a warning status. Check the drive."
              }
            },
            {
              alert = "DroboCapacityLow"
              expr  = "(drobo_capacity_free_bytes / drobo_capacity_total_bytes) < 0.15"
              for   = "30m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Drobo capacity is low"
                description = "Drobo device {{ $labels.device }} has less than 15% free capacity."
              }
            },
            {
              alert = "DroboCapacityCritical"
              expr  = "(drobo_capacity_free_bytes / drobo_capacity_total_bytes) < 0.05"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Drobo capacity is critically low"
                description = "Drobo device {{ $labels.device }} has less than 5% free capacity."
              }
            }
          ]
        }
      ]
    }
  }
}

output "exporter_service" {
  value = "${kubernetes_service_v1.drobo_exporter.metadata[0].name}.${var.namespace}.svc.cluster.local:9417"
}

output "alerts_configured" {
  value = ["DroboDown", "DroboNoRedundancy", "DroboSlotRed", "DroboSlotYellow", "DroboCapacityLow", "DroboCapacityCritical"]
}
