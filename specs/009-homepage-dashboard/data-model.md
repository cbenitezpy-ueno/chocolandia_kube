# Data Model: Homepage Dashboard

**Feature**: 009-homepage-dashboard
**Date**: 2025-11-12
**Status**: Completed

## Overview

This document defines the key entities, their attributes, relationships, and state transitions for the Homepage Dashboard feature. Homepage is a configuration-driven application where all behavior is defined through YAML files stored as Kubernetes ConfigMaps.

---

## Entity Definitions

### 1. Homepage Instance

**Description**: Represents the deployed Homepage application running in the K3s cluster.

**Attributes**:
- `deployment_name` (string): Kubernetes Deployment name (e.g., "homepage")
- `namespace` (string): Kubernetes namespace where Homepage is deployed (e.g., "homepage")
- `image_version` (string): Docker image tag for Homepage (e.g., "v0.8.10", "latest")
- `replicas` (integer): Number of pod replicas (default: 1, no HA)
- `service_name` (string): Kubernetes Service name for internal access
- `service_type` (string): Service type (ClusterIP for Cloudflare Tunnel)
- `service_port` (integer): Internal service port (default: 3000)
- `resource_limits` (object): CPU and memory limits/requests
- `health_checks` (object): Liveness and readiness probe configuration

**Relationships**:
- Has many **Service Entries** (displayed applications)
- Has many **Widget Instances** (infrastructure monitoring widgets)
- Has one **Dashboard Configuration** (settings, theme, layout)
- Requires one **ServiceAccount** (RBAC for K8s API access)
- Exposes one **Cloudflare Tunnel Route** (external access)
- Protected by one **Cloudflare Access Policy** (authentication)

**State Transitions**:
1. **Not Deployed** → **Deploying** (OpenTofu apply starts)
2. **Deploying** → **Running** (Pod status becomes Ready)
3. **Running** → **Degraded** (Health check fails, pod CrashLoopBackOff)
4. **Running** → **Updating** (Configuration change, rolling update)
5. **Updating** → **Running** (New pod becomes Ready)
6. **Degraded** → **Running** (Pod recovers, health checks pass)
7. **Running** → **Terminated** (OpenTofu destroy)

---

### 2. Dashboard Configuration

**Description**: Represents the overall Homepage settings including theme, title, layout, and display preferences.

**Attributes**:
- `config_map_name` (string): Kubernetes ConfigMap storing settings.yaml
- `title` (string): Dashboard title displayed in browser (e.g., "Chocolandia Kube Dashboard")
- `favicon` (string): URL or path to favicon icon
- `theme` (string): Color theme (e.g., "dark", "light", "auto")
- `header_style` (string): Header layout style (e.g., "boxed", "underlined")
- `layout` (object): Widget layout configuration (columns, order)
- `quick_launch` (object): Quick launch settings (search, open new tab behavior)
- `language` (string): Dashboard language (default: "en")
- `status_style` (string): How service status is displayed (e.g., "dot", "pill")

**Relationships**:
- Belongs to one **Homepage Instance**
- Referenced by all **Service Entries** (for styling consistency)

**Configuration File**: `settings.yaml`

**Example**:
```yaml
title: Chocolandia Kube Dashboard
favicon: https://chocolandiadc.com/favicon.ico
theme: dark
headerStyle: boxed
layout:
  Infrastructure:
    style: row
    columns: 4
  Applications:
    style: row
    columns: 3
```

**State Transitions**:
1. **Not Configured** → **Active** (ConfigMap created, mounted in pod)
2. **Active** → **Updating** (ConfigMap updated, pod rolling restart triggered)
3. **Updating** → **Active** (New configuration loaded by Homepage)

---

### 3. Service Entry

**Description**: Represents a single application/service displayed on the Homepage dashboard with its URLs, status, and metadata.

**Attributes**:
- `name` (string): Service display name (e.g., "Pi-hole", "Traefik", "ArgoCD")
- `group` (string): Grouping category (e.g., "Infrastructure", "Applications", "Monitoring")
- `icon` (string): Icon identifier or URL (e.g., "pi-hole.png", "https://...")
- `href` (string): External public URL (e.g., "https://pihole.chocolandiadc.com")
- `internal_url` (string): Internal cluster URL (e.g., "http://pihole.pihole.svc.cluster.local")
- `description` (string): Brief service description
- `namespace` (string): Kubernetes namespace where service is deployed
- `status_enabled` (boolean): Whether to display real-time status
- `ping_enabled` (boolean): Whether to ping service for availability check
- `widget_config` (object, optional): Associated widget configuration if service has specialized widget

**Relationships**:
- Belongs to one **Homepage Instance**
- Belongs to one **Service Group** (logical grouping like "Infrastructure")
- May have one **Widget Instance** (specialized monitoring widget)
- References one **Kubernetes Service** (for service discovery)
- May reference one **Ingress** (for URL extraction)

**Configuration File**: `services.yaml`

**Example**:
```yaml
- Infrastructure:
    - Pi-hole:
        icon: pi-hole.png
        href: https://pihole.chocolandiadc.com
        description: Network-wide DNS ad blocker
        server: k3s-cluster
        namespace: pihole
        container: pihole
        widget:
          type: pihole
          url: http://pihole.pihole.svc.cluster.local
          key: {{HOMEPAGE_VAR_PIHOLE_API_KEY}}
```

**State Transitions**:
1. **Discovered** → **Active** (Service added to services.yaml, displayed on dashboard)
2. **Active** → **Healthy** (Service health check passes, green indicator)
3. **Active** → **Degraded** (Service health check fails, yellow indicator)
4. **Active** → **Failed** (Service unreachable, red indicator)
5. **Healthy/Degraded/Failed** → **Removed** (Service removed from services.yaml)

---

### 4. Widget Instance

**Description**: Represents a specialized monitoring widget for infrastructure services that displays real-time metrics and status information.

**Attributes**:
- `widget_type` (string): Type of widget (e.g., "pihole", "traefik", "kubernetes", "argocd")
- `service_name` (string): Associated service name (e.g., "Pi-hole", "Traefik")
- `api_url` (string): Internal cluster URL for widget API (e.g., "http://pihole.pihole.svc.cluster.local")
- `api_credentials` (object, optional): Authentication credentials (stored in Kubernetes Secret, referenced as env vars)
- `refresh_interval` (integer): Data refresh interval in seconds (default: 30)
- `display_metrics` (array): List of metrics to display (widget-specific)
- `custom_config` (object): Widget-specific configuration options

**Relationships**:
- Belongs to one **Homepage Instance**
- Associated with one **Service Entry**
- Requires **RBAC Permissions** (for Kubernetes-based widgets)
- May require **Kubernetes Secret** (for API authentication)

**Configuration File**: Embedded in `services.yaml` under service widget property

**Widget Types and Metrics**:

#### Pi-hole Widget
- Metrics: queries today, queries blocked today, percent blocked, domains on blocklist
- API: Pi-hole API (requires API key)

#### Traefik Widget
- Metrics: total routers, total services, average response time, HTTP status codes
- API: Traefik dashboard API (port 9000)

#### Kubernetes Widget (cert-manager)
- Metrics: Certificate resources (name, namespace, issuer, expiration date, ready status)
- API: Kubernetes API (via ServiceAccount RBAC)

#### ArgoCD Widget
- Metrics: Applications (name, sync status, health status, last sync time)
- API: ArgoCD API (requires auth token)

**State Transitions**:
1. **Configured** → **Active** (Widget config in services.yaml, credentials in Secret)
2. **Active** → **Fetching** (Widget fetches data from API)
3. **Fetching** → **Healthy** (Data fetch successful, metrics displayed)
4. **Fetching** → **Error** (API unreachable, credentials invalid, timeout)
5. **Healthy** → **Fetching** (Refresh interval triggers new data fetch)
6. **Error** → **Fetching** (Retry after error delay)

---

### 5. Service Group

**Description**: Logical grouping of services for dashboard organization (e.g., "Infrastructure", "Applications", "Monitoring").

**Attributes**:
- `group_name` (string): Display name for the group (e.g., "Infrastructure", "Applications")
- `display_order` (integer): Order in which group appears on dashboard
- `layout_style` (string): Layout style for services in group (e.g., "row", "column")
- `column_count` (integer): Number of columns for service cards in this group

**Relationships**:
- Contains many **Service Entries**
- Belongs to one **Dashboard Configuration**

**Configuration File**: Defined implicitly in `services.yaml` structure

**Example**:
```yaml
- Infrastructure:  # Service Group
    - Pi-hole:     # Service Entry
        ...
    - Traefik:     # Service Entry
        ...

- Applications:    # Service Group
    - Headlamp:    # Service Entry
        ...
```

---

### 6. RBAC Configuration

**Description**: Kubernetes ServiceAccount, Roles, and RoleBindings that grant Homepage read-only access to Kubernetes API for service discovery.

**Attributes**:
- `service_account_name` (string): ServiceAccount name (e.g., "homepage")
- `namespace` (string): Namespace where ServiceAccount exists (e.g., "homepage")
- `roles` (array): List of Role resources granting permissions
- `role_bindings` (array): List of RoleBindings connecting ServiceAccount to Roles
- `permissions` (object): Map of namespace → resources → verbs
  - Namespaces: pihole, traefik, cert-manager, argocd, headlamp, homepage
  - Resources: services, pods, ingresses, certificates (CRD)
  - Verbs: get, list (read-only)

**Relationships**:
- Belongs to one **Homepage Instance**
- Grants access to multiple **Kubernetes Namespaces**
- Required by **Kubernetes-based Widgets** (service discovery, certificate status)

**State Transitions**:
1. **Not Created** → **Active** (ServiceAccount, Roles, RoleBindings created via OpenTofu)
2. **Active** → **In Use** (Homepage pod uses ServiceAccount for API calls)
3. **Active** → **Updated** (Permissions modified, new Roles/RoleBindings added)
4. **Active** → **Revoked** (ServiceAccount deleted, permissions removed)

---

### 7. Cloudflare Tunnel Route

**Description**: Configuration entry in Cloudflare Tunnel that routes external traffic from public domain to Homepage service.

**Attributes**:
- `public_hostname` (string): External domain (e.g., "homepage.chocolandiadc.com")
- `service_url` (string): Internal cluster URL (e.g., "http://homepage.homepage.svc.cluster.local:3000")
- `tunnel_id` (string): Cloudflare Tunnel UUID
- `tunnel_name` (string): Tunnel name (e.g., "chocolandiadc-tunnel")
- `ingress_rule_order` (integer): Order in tunnel ingress rules

**Relationships**:
- Routes traffic to one **Homepage Instance**
- Protected by one **Cloudflare Access Policy**

**State Transitions**:
1. **Not Configured** → **Pending** (OpenTofu defines route, not yet applied)
2. **Pending** → **Active** (Tunnel configuration applied, DNS resolves, traffic flows)
3. **Active** → **Updated** (Service URL or hostname changed)
4. **Active** → **Removed** (Route deleted from tunnel configuration)

---

### 8. Cloudflare Access Policy

**Description**: Authentication policy enforcing Google OAuth for Homepage access before traffic reaches cluster.

**Attributes**:
- `policy_name` (string): Policy name (e.g., "Homepage Dashboard Access")
- `application_domain` (string): Protected domain (e.g., "homepage.chocolandiadc.com")
- `identity_provider` (string): OAuth provider (e.g., "Google")
- `allowed_emails` (array): List of authorized email addresses (e.g., ["cbenitez@gmail.com"])
- `session_duration` (string): How long authentication session lasts (e.g., "24h")
- `policy_action` (string): Action to take (e.g., "allow")

**Relationships**:
- Protects one **Cloudflare Tunnel Route**
- Associated with one **Homepage Instance**

**State Transitions**:
1. **Not Configured** → **Pending** (OpenTofu defines policy, not yet applied)
2. **Pending** → **Active** (Policy deployed, authentication required)
3. **Active** → **Enforcing** (Unauthenticated request blocked, redirect to OAuth)
4. **Active** → **Updated** (Allowed emails or session duration changed)
5. **Active** → **Disabled** (Policy removed, authentication bypassed - NOT RECOMMENDED)

---

## Relationships Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                       Homepage Instance                          │
│  (Deployment, Service, Pod)                                     │
└───────────────┬─────────────────────────────────────────────────┘
                │
                ├─ has one ──> Dashboard Configuration
                │              (settings.yaml in ConfigMap)
                │
                ├─ has many ──> Service Entry
                │               (services.yaml in ConfigMap)
                │               │
                │               ├─ belongs to ──> Service Group
                │               │
                │               └─ may have ──> Widget Instance
                │                                (specialized monitoring)
                │
                ├─ requires ──> RBAC Configuration
                │               (ServiceAccount, Roles, RoleBindings)
                │
                ├─ exposes ──> Cloudflare Tunnel Route
                │              (public domain → internal service)
                │              │
                │              └─ protected by ──> Cloudflare Access Policy
                │                                   (Google OAuth authentication)
                │
                └─ may have ──> Kubernetes Secret
                                (widget API credentials)
```

---

## Configuration Files Structure

### services.yaml
Defines all service entries displayed on Homepage dashboard.

**Schema**:
```yaml
# Array of Service Groups
- <Group Name>:
    # Array of Service Entries
    - <Service Name>:
        icon: <icon-name.png or URL>
        href: <external public URL>
        description: <brief description>
        server: <kubernetes server name>  # For service discovery
        namespace: <kubernetes namespace>  # For service discovery
        container: <container name>        # Optional: specific container
        widget:                            # Optional: specialized widget
          type: <widget-type>
          url: <internal API URL>
          # Widget-specific configuration
```

### widgets.yaml
Defines standalone widgets not associated with specific services (e.g., cluster resources, datetime, search).

**Schema**:
```yaml
# Array of Widget Groups
- resources:
    cpu: true
    memory: true
    disk: /
- datetime:
    format:
      timeStyle: short
      dateStyle: short
```

### settings.yaml
Defines global Homepage configuration.

**Schema**:
```yaml
title: <dashboard title>
favicon: <favicon URL or path>
theme: <dark|light|auto>
headerStyle: <boxed|underlined|clean>
language: <language code>
layout:
  <Group Name>:
    style: <row|column>
    columns: <integer>
```

---

## Validation Rules

### Service Entry Validation
- `name` must be unique within a Service Group
- `href` must be valid URL (http:// or https://)
- If `widget` defined, `widget.type` must be supported type (pihole, traefik, kubernetes, argocd)
- If `server` defined, must match kubernetes server name in docker.yaml (service discovery config)

### Widget Instance Validation
- `api_url` must be reachable from Homepage pod (internal cluster URL)
- If `api_credentials` required, corresponding Kubernetes Secret must exist
- `refresh_interval` must be between 10 and 300 seconds

### Dashboard Configuration Validation
- `theme` must be one of: dark, light, auto
- `headerStyle` must be one of: boxed, underlined, clean
- `layout` group names must match Service Groups in services.yaml

### RBAC Configuration Validation
- ServiceAccount must exist before Deployment references it
- Roles must grant only read-only permissions (get, list verbs only)
- RoleBindings must reference existing ServiceAccount and Role
- Permissions must be scoped to specific namespaces (no cluster-wide ClusterRole)

---

## State Consistency Rules

1. **Service Entry ↔ Kubernetes Service**: Service Entry's `namespace` and `name` should match actual Kubernetes Service for service discovery to work
2. **Widget Instance ↔ Kubernetes Secret**: If widget requires API credentials, Secret must exist before pod starts
3. **RBAC ↔ Service Discovery**: ServiceAccount permissions must grant access to namespaces listed in Service Entries
4. **Cloudflare Tunnel Route ↔ Homepage Service**: Tunnel `service_url` must match actual Homepage Service cluster URL
5. **Cloudflare Access Policy ↔ Tunnel Route**: Policy `application_domain` must match Tunnel Route `public_hostname`

---

## Data Model Summary

**Total Entities**: 8

1. Homepage Instance (deployment/pod)
2. Dashboard Configuration (settings)
3. Service Entry (displayed apps)
4. Widget Instance (monitoring widgets)
5. Service Group (logical grouping)
6. RBAC Configuration (K8s permissions)
7. Cloudflare Tunnel Route (external access)
8. Cloudflare Access Policy (authentication)

**Primary Configuration Files**: 3
- `services.yaml` (Service Entries, Widget Instances)
- `widgets.yaml` (Standalone widgets)
- `settings.yaml` (Dashboard Configuration)

**External Dependencies**: 5
- Kubernetes API (service discovery)
- Cloudflare API (tunnel, access policies)
- Pi-hole API (widget)
- Traefik API (widget)
- ArgoCD API (widget)

All entities defined. Ready for contract generation (YAML schemas) and quickstart guide.
