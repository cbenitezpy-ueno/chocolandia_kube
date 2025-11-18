# Data Model: Homepage Configuration Structure

**Feature**: Homepage Dashboard Update
**Date**: 2025-11-18
**Purpose**: Define the structure and relationships of Homepage configuration entities

## Overview

Homepage dashboard configuration is declarative, using YAML files that are mounted into the Homepage container via Kubernetes ConfigMaps. The data model consists of three primary configuration entities:

1. **Services** - Service links organized by category
2. **Widgets** - Dashboard widgets for system monitoring
3. **Kubernetes Integration** - Cluster resource discovery and display

## Entity Definitions

### 1. Service Entry

Represents a clickable service link with optional Kubernetes widget integration.

**Attributes**:
- `name` (string, required): Display name of the service
- `icon` (string, optional): Icon identifier (e.g., "grafana.svg", "minio.svg")
- `href` (string, optional): Primary access URL (public HTTPS preferred)
- `description` (string, required): Human-readable service description
- `namespace` (string, optional): Kubernetes namespace (required for widget)
- `app` (string, optional): Kubernetes app label (required for widget)
- `widget` (object, optional): Widget configuration for this service

**Relationships**:
- Belongs to exactly one **Service Category**
- May have zero or one **Widget Configuration**

**Structure**:
```yaml
- Service Name:
    icon: <icon-name>.svg
    href: <primary-url>
    description: <description>
    namespace: <k8s-namespace>
    app: <app-label>
    widget:
      type: <widget-type>
      # ... type-specific parameters
```

**Access Method Patterns**:

1. **Public + Private** (preferred for user-facing services):
   ```yaml
   - Grafana:
       icon: grafana.svg
       href: https://grafana.chocolandiadc.com  # 🌐 Public (Cloudflare tunnel)
       description: Metrics visualization - Also: http://192.168.4.101:30000  # 🏠 Private (NodePort)
   ```

2. **Public Only** (services without local network access):
   ```yaml
   - MinIO Console:
       icon: minio.svg
       href: https://minio.chocolandiadc.com  # 🌐 Public
       description: MinIO web console
   ```

3. **Private Only** (internal services, databases):
   ```yaml
   - PostgreSQL HA:
       icon: postgresql.svg
       href: http://192.168.4.200:5432  # 🏠 Private (LoadBalancer IP)
       description: PostgreSQL high-availability cluster
   ```

**Visual Distinction Rules**:
- Public URLs: Include "🌐 Public" in description or separate field
- Private URLs: Include "🏠 Private" in description with format `Also: <private-url>`
- If both exist: Public URL in `href`, private URL in `description`

### 2. Service Category

Logical grouping of related services.

**Attributes**:
- `name` (string, required): Category display name
- `services` (array, required): List of Service Entries

**Categories** (alphabetically ordered services within each):
1. **Applications**: User-facing applications (Beersystem)
2. **GitOps**: Continuous delivery tools (ArgoCD)
3. **Infrastructure**: Core cluster services (cert-manager, Pi-hole, Traefik)
4. **Monitoring**: Observability stack (Grafana, Homepage, Netdata, Prometheus)
5. **Storage**: Persistent storage solutions (Longhorn, MinIO, PostgreSQL)

**Structure**:
```yaml
- Category Name:
    - Service 1:
        # ... service attributes
    - Service 2:
        # ... service attributes
```

**Ordering Rules**:
- Categories: Fixed order (Applications, GitOps, Infrastructure, Monitoring, Storage)
- Services within category: Alphabetical by service name

### 3. Widget Configuration

Defines how Homepage integrates with external services to display metrics.

**Common Attributes**:
- `type` (string, required): Widget type identifier

**Widget Types**:

#### ArgoCD Widget
Displays GitOps application sync status.

```yaml
widget:
  type: argocd
  url: http://argocd-server.argocd.svc.cluster.local:80  # In-cluster service URL
  key: {{HOMEPAGE_VAR_ARGOCD_TOKEN}}                     # Injected from Kubernetes Secret
```

**Metrics Displayed**:
- Total applications
- Synced / Out of Sync
- Healthy / Progressing / Degraded
- Suspended / Missing

**Refresh Interval**: 30 seconds (configured globally)
**Error Handling**: Single retry after 10 seconds, then display error message

#### Kubernetes Widget (Pod-level)
Displays pod-specific metrics for a service.

```yaml
widget:
  type: kubernetes
  cluster: default                    # Cluster name (use "default" for in-cluster)
  namespace: <namespace>
  app: <app-label>
  podSelector: <label-selector>      # e.g., "app.kubernetes.io/name=grafana"
```

**Metrics Displayed**:
- Pod count (running/total)
- CPU usage per pod
- Memory usage per pod
- Pod status (Running/Pending/Failed)

**Requirements**:
- Kubernetes metrics-server must be deployed (already present in cluster)
- ServiceAccount must have permissions to read pods and metrics

### 4. Kubernetes Cluster Widget

Global dashboard widget showing cluster-level metrics.

**Attributes**:
```yaml
- kubernetes:
    cluster:
      show: true
      cpu: true
      memory: true
      showLabel: true
      label: "cluster"
    nodes:
      show: true
      cpu: true
      memory: true
      showLabel: true
```

**Cluster Metrics**:
- Total CPU allocation / usage
- Total memory allocation / usage
- Node count (ready/total)

**Node Metrics** (per node):
- Hostname
- Private IP address (192.168.4.101, .102, .103, .104)
- Role labels (control-plane, etcd, master, worker)
- Status (Ready/NotReady)
- CPU usage %
- Memory usage %

**Refresh Interval**: 30 seconds
**Error Handling**: Single retry after 10 seconds, then display error

### 5. Resource Widget

System-level resource monitoring (CPU, memory, disk).

**Attributes**:
```yaml
- resources:
    backend: kubernetes              # Data source
    expanded: true                   # Show expanded view by default
    cpu: true                        # Show CPU metrics
    memory: true                     # Show memory metrics
```

**Metrics Displayed**:
- CPU usage (percentage)
- Memory usage (percentage)
- Disk usage (if supported)

## Complete Service Inventory

### Services to Add/Update

| Service | Category | Icon | Public URL | Private URL | Widget Type | Notes |
|---------|----------|------|------------|-------------|-------------|-------|
| **ArgoCD** | GitOps | argocd.svg | https://argocd.chocolandiadc.com | - | argocd | Fix widget auth |
| **Beersystem** | Applications | beer.svg | https://beer.chocolandiadc.com | http://192.168.4.101:3001 | kubernetes | NEW |
| **cert-manager** | Infrastructure | cert-manager.svg | - | - | kubernetes | Existing |
| **Grafana** | Monitoring | grafana.svg | https://grafana.chocolandiadc.com | http://192.168.4.101:30000 | kubernetes | Existing |
| **Headlamp** | Infrastructure | kubernetes-dashboard.svg | https://headlamp.chocolandiadc.com | - | kubernetes | Existing |
| **Homepage** | Monitoring | homepage.svg | https://homepage.chocolandiadc.com | - | kubernetes | Existing (self) |
| **Longhorn** | Storage | longhorn.svg | https://longhorn.chocolandiadc.com | - | - | NEW |
| **MinIO API** | Storage | minio.svg | https://s3.chocolandiadc.com | http://192.168.4.101:9000 | - | NEW |
| **MinIO Console** | Storage | minio.svg | https://minio.chocolandiadc.com | http://192.168.4.101:9001 | - | NEW |
| **Netdata** | Monitoring | netdata.svg | - | http://192.168.4.101:19999 | - | NEW (private) |
| **Pi-hole** | Infrastructure | pihole.svg | https://pihole.chocolandiadc.com | http://192.168.4.201:80, NodePort 30001 | - | NEW |
| **PostgreSQL** | Storage | postgresql.svg | - | 192.168.4.200:5432 | - | NEW (private) |
| **Prometheus** | Monitoring | prometheus.svg | - | Port-forward 9090 | - | NEW (private) |
| **Traefik** | Infrastructure | traefik.svg | - | - | kubernetes | Existing |

**Legend**:
- 🌐 Public URL: Accessible via Cloudflare Zero Trust tunnel from internet
- 🏠 Private URL: Accessible only from local network (192.168.4.x)
- NEW: Service not currently in Homepage configuration
- Existing: Service already configured (may need updates)

## Configuration File Mapping

```text
terraform/modules/homepage/configs/
├── services.yaml       → Service Categories + Service Entries
├── widgets.yaml        → Kubernetes Cluster Widget + Resource Widget + DateTime
├── kubernetes.yaml     → Kubernetes integration settings (auto-discovery)
└── settings.yaml       → Global settings (title, theme, layout)
```

## State Persistence

**Storage Mechanism**: Kubernetes ConfigMaps
- `homepage-services`: Mounted to /app/config/services.yaml
- `homepage-widgets`: Mounted to /app/config/widgets.yaml
- `homepage-kubernetes`: Mounted to /app/config/kubernetes.yaml
- `homepage-settings`: Mounted to /app/config/settings.yaml

**Update Process**:
1. Update YAML file in `terraform/modules/homepage/configs/`
2. Run `tofu plan` to preview ConfigMap changes
3. Run `tofu apply` to update ConfigMaps in cluster
4. Restart Homepage pod to reload configuration: `kubectl rollout restart deployment/homepage -n homepage`

**State Management**: ConfigMaps are declaratively managed via OpenTofu, ensuring GitOps compliance and reproducibility.

## Validation Rules

1. **Service Entry**:
   - Must have either `href` or widget configuration
   - If widget configured, must have `namespace` and `app`
   - Description should indicate access method (🌐 Public, 🏠 Private, or both)

2. **Category**:
   - Services must be alphabetically sorted within category
   - Category names must match defined list

3. **Widget**:
   - ArgoCD widget requires `url` and `key` (token)
   - Kubernetes widget requires `namespace` and valid pod selector
   - Refresh intervals set globally (30 seconds)

4. **URLs**:
   - Public URLs must use HTTPS and chocolandiadc.com domain
   - Private URLs may use HTTP with IP addresses or NodePort numbers
   - LoadBalancer IPs: 192.168.4.200-210 range

## Example Complete Service Entry

```yaml
- Monitoring:
    - Grafana:
        icon: grafana.svg
        href: https://grafana.chocolandiadc.com
        description: "🌐 Public: Metrics visualization and monitoring dashboards | 🏠 Private: http://192.168.4.101:30000"
        namespace: monitoring
        app: grafana
        widget:
          type: kubernetes
          cluster: default
          namespace: monitoring
          app: grafana
          podSelector: app.kubernetes.io/name=grafana
```

## Security Considerations

1. **ArgoCD Token**:
   - Stored in Kubernetes Secret `homepage-widgets`
   - Read-only permissions (role:readonly)
   - Rotated periodically (manual process)

2. **ServiceAccount Permissions**:
   - ClusterRole: read-only access to nodes, pods, services
   - No write permissions
   - No secret access (except mounted tokens)

3. **URL Exposure**:
   - Private IPs (192.168.4.x) only accessible from local network
   - Public URLs protected by Cloudflare Zero Trust (Google OAuth)
   - No credentials embedded in configuration

## Future Enhancements

1. **Additional Widgets**:
   - Longhorn widget (if Homepage adds support)
   - MinIO widget (custom development)
   - PostgreSQL widget (connection status)

2. **Automatic Discovery**:
   - Use IngressRoute annotations (`gethomepage.dev/*`) for auto-discovery
   - Reduce manual configuration maintenance

3. **High Availability**:
   - Increase Homepage replicas to 2 for HA
   - Add PodDisruptionBudget

4. **Metrics**:
   - Expose Homepage metrics to Prometheus
   - Create Grafana dashboard for Homepage usage
