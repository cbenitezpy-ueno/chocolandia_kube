# Implementation Plan: Homepage Dashboard Update

**Branch**: `001-homepage-update` | **Date**: 2025-11-18 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-homepage-update/spec.md`

## Summary

Update the Homepage dashboard to display comprehensive cluster infrastructure information, including all service links (public and private), node details with IP addresses, and fix broken ArgoCD/Kubernetes widgets. The dashboard will serve as a central hub for accessing all deployed services with clear visual distinction between public (internet-accessible via Cloudflare tunnels) and private (local network-only) access methods.

**Technical Approach**: Update existing Homepage Terraform module configuration files (services.yaml, widgets.yaml, kubernetes.yaml) to add missing services (Longhorn, MinIO, PostgreSQL, Netdata, Pi-hole), configure widgets with proper authentication and refresh intervals, and implement visual distinction using icons and labels. All changes managed via OpenTofu for infrastructure-as-code compliance.

## Technical Context

**Language/Version**: YAML (Homepage configuration), HCL (OpenTofu/Terraform 1.6+)
**Primary Dependencies**: Homepage Docker image (ghcr.io/gethomepage/homepage), Kubernetes 1.28 (K3s), Helm, OpenTofu 1.6+
**Storage**: Kubernetes ConfigMaps for configuration persistence (services.yaml, widgets.yaml, settings.yaml, kubernetes.yaml)
**Testing**: kubectl validation, Homepage pod health checks, widget functionality testing, link accessibility testing
**Target Platform**: Kubernetes (K3s v1.28.3) on Ubuntu 24.04 LTS, 4-node cluster (2 control-plane + 2 workers)
**Project Type**: Infrastructure configuration (YAML-based dashboard config + OpenTofu IaC)
**Performance Goals**: Dashboard loads in <3s on local network, widgets refresh every 30s, service links respond in <5s
**Constraints**: Must work with existing Cloudflare Zero Trust tunnels, maintain OpenTofu-managed state, preserve existing service configurations
**Scale/Scope**: 13 services across 5 categories, 4 cluster nodes, 2 widget types (ArgoCD, Kubernetes), public + private access for each service

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Phase 0 Evaluation

| Principle | Status | Compliance Notes |
|-----------|--------|------------------|
| **I. Infrastructure as Code - OpenTofu First** | ✅ PASS | All Homepage configuration managed via OpenTofu modules in `terraform/modules/homepage/`. Changes applied via `tofu plan` and `tofu apply` workflow. |
| **II. GitOps Workflow** | ✅ PASS | Changes committed to Git on feature branch `001-homepage-update`, will require PR review before merging to main, OpenTofu plans reviewed before apply. |
| **III. Container-First Development** | ✅ PASS | Homepage runs as containerized workload with Kubernetes Deployment, uses ConfigMaps for configuration (stateless pattern), health probes already configured. |
| **IV. Observability & Monitoring - Prometheus + Grafana** | ✅ PASS | Homepage itself doesn't generate metrics, but dashboard will display links to Grafana and Prometheus for cluster observability. Kubernetes widget shows cluster resource usage. |
| **V. Security Hardening** | ✅ PASS | No new firewall rules or VLAN changes required. Uses existing Cloudflare Zero Trust tunnels for public access. Kubernetes RBAC ServiceAccount with read-only permissions. ArgoCD widget uses read-only API token. |
| **VI. High Availability (HA) Architecture** | ⚠️ ACCEPTABLE | Homepage currently runs as single replica (not HA), but this is acceptable as it's a dashboard (not critical path). Failure only impacts visibility, not actual services. Could be enhanced to 2 replicas in future. |
| **VII. Test-Driven Learning** | ✅ PASS | Will validate with: `tofu validate`, `tofu plan`, kubectl checks for ConfigMap updates, pod restart verification, manual testing of all service links and widgets. |
| **VIII. Documentation-First** | ✅ PASS | This plan documents configuration structure, design decisions (widget intervals, visual distinction method), and testing procedures. No ADR needed (configuration update, not architectural change). |
| **IX. Network-First Security** | ✅ PASS | No network changes required. Leverages existing VLAN segmentation and Cloudflare tunnels. Private links use existing LoadBalancer IPs and NodePorts. |

**Gate Decision**: ✅ **PASS** - Proceed to Phase 0 Research

**Justification for HA deviation**: Homepage is a visibility tool, not a critical service. Single-node failure means dashboard is unavailable but actual services remain operational and accessible directly. Future enhancement to 2 replicas would improve availability but not required for MVP.

## Project Structure

### Documentation (this feature)

```text
specs/001-homepage-update/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (ArgoCD token generation, Homepage widget docs)
├── data-model.md        # Phase 1 output (Service configuration structure, widget config model)
├── quickstart.md        # Phase 1 output (How to apply changes and validate)
├── contracts/           # Phase 1 output (YAML schemas for Homepage configs)
│   ├── services-schema.yaml
│   ├── widgets-schema.yaml
│   └── kubernetes-schema.yaml
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/modules/homepage/
├── main.tf                      # Kubernetes resources (Namespace, Deployment, Service, ConfigMaps, ServiceAccount)
├── variables.tf                 # Module variables (image version, resource limits, domain name)
├── outputs.tf                   # Module outputs (service URLs, namespace, etc.)
├── rbac.tf                      # RBAC resources (ServiceAccount, ClusterRole, ClusterRoleBinding for node/pod read access)
└── configs/
    ├── services.yaml            # Service groups and links (UPDATE: add missing services with public/private URLs)
    ├── widgets.yaml             # Dashboard widgets (UPDATE: configure ArgoCD widget with auth, add refresh intervals)
    ├── settings.yaml            # Global dashboard settings (NO CHANGES)
    └── kubernetes.yaml          # Kubernetes integration config (UPDATE: add node display configuration)

terraform/environments/chocolandiadc-mvp/
├── main.tf                      # Environment-level configuration (calls homepage module)
├── variables.tf                 # Environment variables
└── terraform.tfvars             # Variable values (POTENTIAL UPDATE: argocd_token)

# Configuration applied to cluster as:
# kubectl get configmap -n homepage
# - homepage-services  (from configs/services.yaml)
# - homepage-widgets   (from configs/widgets.yaml)
# - homepage-settings  (from configs/settings.yaml)
# - homepage-kubernetes (from configs/kubernetes.yaml)
```

**Structure Decision**: This is an infrastructure configuration update, not application code. Changes are made to existing OpenTofu module configuration files that get applied to Kubernetes as ConfigMaps. The Homepage container image itself is not modified—only its YAML configuration inputs.

## Complexity Tracking

> This feature has no constitutional violations requiring justification.

## Phase 0: Research & Technology Decisions

### Research Questions

1. **ArgoCD API Token Generation**
   - How to generate a read-only ArgoCD API token for Homepage widget authentication?
   - Token permissions required (read-only access to applications)
   - Token storage mechanism (Kubernetes Secret via OpenTofu)

2. **Homepage Widget Configuration**
   - ArgoCD widget syntax and authentication method
   - Kubernetes widget syntax for node/pod display
   - Refresh interval configuration method
   - Error retry configuration (if supported by Homepage)

3. **Cloudflare Tunnel URL Discovery**
   - Current tunnel configuration for each service
   - Verify domain pattern: `<service>.chocolandiadc.com`
   - List of services with public tunnel access

4. **Service Discovery**
   - Complete inventory of deployed services (Longhorn, MinIO, PostgreSQL, Netdata, etc.)
   - Service types (ClusterIP, LoadBalancer, NodePort) and ports
   - LoadBalancer IP assignments from MetalLB

5. **Node Information Retrieval**
   - Kubernetes API method for displaying nodes in Homepage
   - Node labels for roles (control-plane, worker)
   - Homepage kubernetes.yaml configuration for node display

### Technology Decisions (to be documented in research.md)

1. **ArgoCD Token Type**: Project token vs Account token (lean toward Account token with read-only role)
2. **Widget Refresh Strategy**: Homepage built-in refresh vs custom implementation (use built-in)
3. **Visual Distinction Method**: Confirmed as icons + text labels (from clarifications)
4. **Service Categorization**: Infrastructure, Monitoring, Storage, Applications, GitOps (from spec)

### Research Tasks

- **Task 1**: Generate ArgoCD read-only API token and store in Kubernetes Secret
- **Task 2**: Document Homepage widget syntax from official documentation
- **Task 3**: Inventory all current Cloudflare tunnel configurations
- **Task 4**: List all services with current access methods (public URL, LoadBalancer IP, NodePort)
- **Task 5**: Test Homepage node display configuration options

**Output**: `research.md` with all decisions documented and unknowns resolved

## Phase 1: Design & Data Models

### Data Model: Service Configuration Structure

**File**: `data-model.md`

Service configuration entries will follow this structure:

```yaml
- Category Name:
    - Service Name:
        icon: <icon-name>.svg           # Homepage built-in icon or custom
        href: <url>                     # Primary access URL (public preferred)
        description: <text>             # Service description
        namespace: <k8s-namespace>      # Kubernetes namespace (for widget)
        app: <app-label>                # Kubernetes app label (for widget)
        widget:                         # Optional widget configuration
          type: <widget-type>           # kubernetes, argocd, etc.
          <type-specific-params>        # Varies by widget type
```

**New Services to Add**:

1. **Storage Category**:
   - Longhorn (icon: longhorn.svg, href: https://longhorn.chocolandiadc.com, ClusterIP + Cloudflare tunnel)
   - MinIO API (icon: minio.svg, href: https://minio.chocolandiadc.com, ClusterIP + Cloudflare tunnel)
   - MinIO Console (icon: minio.svg, href: https://minio-console.chocolandiadc.com)
   - PostgreSQL HA (icon: postgresql.svg, private only: 192.168.4.200:5432)

2. **Monitoring Category** (additions):
   - Netdata (icon: netdata.svg, private only: NodePort or direct IP)
   - Prometheus (icon: prometheus.svg, ClusterIP, port-forward or Cloudflare tunnel)

3. **Infrastructure Category** (additions):
   - Pi-hole (icon: pihole.svg, href: https://pihole.chocolandiadc.com, private: 192.168.4.201:80 + NodePort 30001)
   - Kubernetes Nodes (special widget for node display)

**Widget Configuration Model**:

```yaml
# ArgoCD Widget (fixed)
widget:
  type: argocd
  url: http://argocd-server.argocd.svc.cluster.local:80
  key: {{HOMEPAGE_VAR_ARGOCD_TOKEN}}    # Injected from Secret

# Kubernetes Cluster Widget (enhanced)
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

### API Contracts

**File**: `contracts/services-schema.yaml`

Schema defining valid service configuration structure (for validation).

**File**: `contracts/widgets-schema.yaml`

Schema defining valid widget configuration structure.

**File**: `contracts/kubernetes-schema.yaml`

Schema defining Kubernetes widget options (node display, resource metrics).

### Quickstart Guide

**File**: `quickstart.md`

Step-by-step instructions for:
1. Generating ArgoCD token
2. Updating OpenTofu variable files
3. Applying configuration changes (`tofu apply`)
4. Verifying ConfigMap updates
5. Restarting Homepage pod
6. Testing all service links and widgets

**Output**: Data model, contracts, and quickstart guide for implementation phase

## Phase 2: Task Generation

> **NOTE**: Phase 2 task generation is handled by the `/speckit.tasks` command, NOT by `/speckit.plan`.

This command stops after Phase 1 design artifacts are generated. The next command to run is `/speckit.tasks` which will:
- Generate dependency-ordered tasks in `tasks.md`
- Break down implementation into atomic, testable steps
- Map tasks to files that need modification
- Provide validation steps for each task

## Post-Phase 1 Constitution Re-Check

| Principle | Status | Compliance Notes |
|-----------|--------|------------------|
| **I. Infrastructure as Code** | ✅ PASS | All changes managed via OpenTofu module config files. No manual kubectl edits. |
| **II. GitOps Workflow** | ✅ PASS | Git branch created, changes committed, PR review before merge. |
| **III. Container-First** | ✅ PASS | Homepage remains containerized with ConfigMap-based config. |
| **VII. Test-Driven Learning** | ✅ PASS | Quickstart includes validation steps for each change. |
| **VIII. Documentation-First** | ✅ PASS | Research, data model, and quickstart provide complete documentation. |

**Final Gate Decision**: ✅ **PASS** - Design phase complete, ready for task generation via `/speckit.tasks`

## Next Steps

1. **Review this plan** with any stakeholders or for self-validation
2. **Run `/speckit.tasks`** to generate implementation tasks in `tasks.md`
3. **Execute tasks** in dependency order as defined by tasks.md
4. **Test thoroughly** following quickstart validation steps
5. **Create PR** for review before merging to main branch

## Implementation Notes

- **Cloudflare Domain**: All public services use `<service>.chocolandiadc.com` pattern
- **Private Network**: 192.168.4.x subnet, LoadBalancer IPs from MetalLB pool (192.168.4.200-210)
- **Node IPs**: master1 (192.168.4.101), nodo1 (192.168.4.102), nodo03 (192.168.4.103), nodo04 (192.168.4.104)
- **ArgoCD Token**: Must be generated manually and stored in OpenTofu variable or Kubernetes Secret
- **Visual Distinction**: Public links use 🌐 icon/label, Private links use 🏠 icon/label (clarified in spec)
- **Widget Refresh**: 30-second intervals for ArgoCD and Kubernetes widgets (clarified in spec)
- **Error Handling**: Single retry after 10 seconds, then display error message (clarified in spec)
- **Service Ordering**: Alphabetical within each category (clarified in spec)
