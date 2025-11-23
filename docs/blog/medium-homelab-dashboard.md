# Building a Beautiful Homelab Dashboard with Grafana: A HomeDash-Inspired Design

## Introduction

When it comes to monitoring a homelab Kubernetes cluster, the default Grafana dashboards get the job done, but they often feel utilitarian and lack visual appeal. Inspired by the popular HomeDash v3 design, I set out to create a custom dashboard that's both informative and visually stunning.

In this post, I'll walk you through the **Chocolandia Homelab Overview** dashboard - a custom Grafana dashboard designed for monitoring a K3s cluster running on mini PCs. I'll cover the metrics we're displaying, the technology stack powering it, and the customizations that make it stand out.

## The Technology Stack

### Infrastructure
- **K3s v1.28**: Lightweight Kubernetes distribution perfect for homelabs
- **4 Intel NUC/Mini PCs**: Running as cluster nodes
- **MetalLB**: For LoadBalancer services with real IPs

### Monitoring Stack
- **kube-prometheus-stack** (Helm chart v55.5.0): The backbone of our monitoring
  - **Prometheus**: Time-series database collecting all metrics
  - **Grafana**: Visualization and dashboarding
  - **node-exporter**: Hardware and OS metrics from each node
  - **kube-state-metrics**: Kubernetes object state metrics
  - **Alertmanager**: Alert routing (configured with ntfy notifications)

### Applications Being Monitored
- **Pi-hole**: Network-wide ad blocking and DNS
- **Traefik**: Ingress controller and reverse proxy
- **PostgreSQL HA**: Database cluster with CloudNativePG
- **ArgoCD**: GitOps continuous delivery

## Dashboard Sections

### 1. Cluster Overview (Top Row)

The first row provides an at-a-glance view of cluster health with stat panels featuring **sparkline graphs behind the values** - a key visual element borrowed from HomeDash v3.

| Panel | Metric | Color |
|-------|--------|-------|
| Nodes | `count(up{job=~".*node.*"} == 1)` | Green |
| CPUs | `sum(count by (instance) (node_cpu_seconds_total{mode="idle"}))` | Blue |
| RAM | `sum(node_memory_MemTotal_bytes)` | Purple |
| CPU % | `avg(100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))` | Green-Yellow-Red gradient |
| RAM % | `avg((1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)` | Green-Yellow-Red gradient |
| Disk % | `avg((1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)` | Blue-Purple gradient |
| Temp | `max(node_hwmon_temp_celsius{chip=~".*coretemp.*"})` | Yellow-Orange-Red gradient |
| Net RX/TX | `sum(rate(node_network_receive_bytes_total[5m]))` | Cyan/Green |

### 2. Time-Series Graphs (Middle Section)

Six graphs showing historical data with **smooth lines, gradient fills, and table legends**:

- **CPU Usage**: Per-node CPU utilization percentage
- **Memory Usage**: Per-node RAM usage percentage
- **Network I/O**: Bidirectional network traffic (RX positive, TX negative)
- **Temperature**: CPU temperature trends per node
- **Load Average**: 1-minute load average per node
- **Disk I/O**: Read/write throughput per node

### 3. Storage Visualization

- **Disk Usage by Node**: Horizontal bar gauge showing disk usage percentage per node
- **CPU Temperature by Node**: Timeseries graph converted from gauge for better historical visibility

### 4. Applications Section

This is where the HomeDash inspiration really shines. Each application gets **3 panels in a consistent color theme**:

| Application | Color | Status Metric | Metric 1 | Metric 2 |
|-------------|-------|---------------|----------|----------|
| **Pi-hole** | Pink (#ec4899) | Pod Running | DNS Traffic | Memory |
| **Traefik** | Cyan (#06b6d4) | Config Reload Success | Requests/s | Open Connections |
| **PostgreSQL** | Blue (#3b82f6) | Exporter Scrape OK | DB Size | Locks |
| **ArgoCD** | Green (#22c55e) | Cluster Connection | Apps Count | Syncs/24h |

The status panels show:
- **UP** in the app's theme color when healthy
- **DOWN** in red (#ef4444) when there's a problem

### 5. Resource Tables

- **Top Pods by CPU**: Table showing the 10 most CPU-intensive pods with gauge visualization
- **Node Hardware Inventory** (collapsed): Detailed hardware info including Vendor, Model, IP, CPUs, RAM, Uptime, and real-time CPU/RAM percentages

## Key Customizations

### 1. Transparent Panels (No Borders)

Every panel has `"transparent": true` set, removing the default panel borders and creating a seamless, modern look that blends with the dark theme.

```json
{
  "transparent": true,
  "type": "stat"
}
```

### 2. Sparklines Behind Values

Stat panels use `colorMode: "background_solid"` with `graphMode: "area"` to show mini sparkline graphs behind the numeric values:

```json
{
  "options": {
    "colorMode": "background_solid",
    "graphMode": "area",
    "textMode": "value_and_name"
  }
}
```

### 3. Gradient Color Fills

Time-series graphs have a 35% fill opacity with gradient mode for a polished look:

```json
{
  "custom": {
    "fillOpacity": 35,
    "gradientMode": "opacity",
    "lineWidth": 1,
    "lineInterpolation": "smooth"
  }
}
```

### 4. Y-Axis as Title

Instead of traditional panel titles above the graph, we use the Y-axis label as the title, saving vertical space:

```json
{
  "custom": {
    "axisLabel": "CPU Usage",
    "axisPlacement": "left"
  },
  "title": ""
}
```

### 5. Table Legend Below Graphs

Legends are displayed as tables below the graph with calculated values (mean, max):

```json
{
  "options": {
    "legend": {
      "displayMode": "table",
      "placement": "bottom",
      "calcs": ["mean", "max"]
    }
  }
}
```

### 6. Continuous Color Gradients

For percentage-based stats, we use Grafana's continuous color modes for smooth gradients:

```json
{
  "color": {
    "mode": "continuous-GrYlRd"  // Green -> Yellow -> Red
  }
}
```

Available modes: `continuous-GrYlRd`, `continuous-BlPu`, `continuous-YlRd`

### 7. Value Mappings for Status

Status panels map numeric values to meaningful text with appropriate colors:

```json
{
  "mappings": [{
    "type": "value",
    "options": {
      "0": { "text": "DOWN", "color": "#ef4444" },
      "1": { "text": "UP", "color": "#ec4899" }
    }
  }]
}
```

### 8. Deduplicating Node Data

When joining metrics from multiple sources, we use `max by (nodename)` to prevent duplicate entries:

```promql
max by (nodename) (
  (1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100
  * on(instance) group_left(nodename) node_uname_info
)
```

## Deployment Architecture

The dashboard is deployed as Infrastructure as Code using **OpenTofu**:

```hcl
resource "kubernetes_config_map" "homelab_overview_dashboard" {
  metadata {
    name      = "homelab-overview-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"  # Picked up by Grafana sidecar
    }
  }

  data = {
    "homelab-overview.json" = file("${path.module}/../../dashboards/homelab-overview.json")
  }
}
```

Grafana's sidecar container automatically discovers ConfigMaps with the `grafana_dashboard: "1"` label and loads them as dashboards.

## The Result

The final dashboard provides:

1. **Instant cluster health visibility** - One glance tells you if everything is running
2. **Historical trends** - Smooth graphs show patterns over time
3. **Application status** - Quickly see if Pi-hole, Traefik, PostgreSQL, and ArgoCD are healthy
4. **Resource details on demand** - Collapsed sections for when you need to dig deeper
5. **Beautiful aesthetics** - A dashboard you actually want to look at

## Metrics Sources Reference

| Metric Prefix | Source | Description |
|---------------|--------|-------------|
| `node_*` | node-exporter | Hardware metrics (CPU, memory, disk, network, temperature) |
| `kube_*` | kube-state-metrics | Kubernetes object states (pods, deployments) |
| `container_*` | cAdvisor (kubelet) | Container resource usage |
| `traefik_*` | Traefik | Ingress controller metrics |
| `pg_*` | PostgreSQL Exporter | Database metrics |
| `argocd_*` | ArgoCD | GitOps application metrics |

## Conclusion

Building a custom Grafana dashboard takes time, but the result is worth it. By combining the power of Prometheus metrics with Grafana's visualization capabilities and some creative customizations, you can create a monitoring experience that's both functional and beautiful.

The key takeaways:
- **Use transparent panels** for a modern, borderless look
- **Enable sparklines** in stat panels for at-a-glance trends
- **Apply gradient fills** to time-series for visual depth
- **Group related panels by color** for quick visual parsing
- **Use PromQL joins** (`on() group_left()`) to combine metrics with node labels

Feel free to use this as inspiration for your own homelab dashboard. The full JSON is available in my GitHub repository.

---

*This dashboard was created for the Chocolandia Homelab running on K3s with the kube-prometheus-stack. Built with love and a lot of Grafana JSON tweaking.*
