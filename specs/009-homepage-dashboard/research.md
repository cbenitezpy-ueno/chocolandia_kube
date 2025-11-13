# Research Phase: Homepage Dashboard

**Feature**: 009-homepage-dashboard
**Date**: 2025-11-12
**Status**: Completed

## Research Tasks

This document resolves all NEEDS CLARIFICATION items from Technical Context and documents best practices for Homepage deployment in K3s with Cloudflare Zero Trust.

---

## 1. Ingress/Routing Decision: Traefik IngressRoute vs Cloudflare Tunnel

### Context
Homepage needs to be accessible externally via HTTPS with Cloudflare Zero Trust authentication. The cluster has both Traefik (ingress controller) and Cloudflare Tunnel (secure external access) already deployed. Need to decide the routing architecture.

### Options Evaluated

#### Option A: Cloudflare Tunnel Only (Recommended)
**Architecture**: Internet → Cloudflare Tunnel → Homepage Service (ClusterIP) → Homepage Pod

**Pros**:
- Consistent with existing services (Headlamp, ArgoCD use this pattern)
- Cloudflare Access authentication at tunnel level (before traffic reaches cluster)
- No additional ingress configuration needed
- Simplified TLS (Cloudflare manages external certificate, internal can be HTTP)
- No exposure of cluster ingress to internet
- Cloudflare CDN benefits (caching, DDoS protection)

**Cons**:
- Requires Cloudflare Tunnel configuration update (add homepage.chocolandiadc.com route)
- Internal cluster access requires going through Cloudflare (unless separate internal ingress)

#### Option B: Traefik IngressRoute with Cloudflare Tunnel
**Architecture**: Internet → Cloudflare Tunnel → Traefik Ingress → Homepage Service → Homepage Pod

**Pros**:
- Unified ingress management via Traefik (all services use same pattern)
- Internal cluster access via Traefik (no Cloudflare dependency for internal use)
- TLS termination at Traefik (cert-manager certificates)
- Advanced routing features (middlewares, rate limiting, retries)

**Cons**:
- Additional complexity (two routing layers)
- Potential performance overhead (extra hop)
- Requires both Cloudflare Tunnel config AND Traefik IngressRoute
- TLS configuration more complex (Cloudflare → Traefik → Homepage)

#### Option C: Traefik IngressRoute Only (Internal Access)
**Architecture**: Internal Network → Traefik Ingress → Homepage Service → Homepage Pod

**Pros**:
- Simple internal access for cluster administrators
- Standard Kubernetes ingress pattern
- TLS via cert-manager

**Cons**:
- No external access (fails requirement for "access from anywhere")
- Would need Cloudflare Tunnel added later for external access
- No authentication layer (unless added to Homepage or Traefik middleware)

### Decision: **Option A - Cloudflare Tunnel Only**

**Rationale**:
1. **Consistency**: Aligns with existing architecture (Headlamp, ArgoCD deployed same way)
2. **Security**: Authentication enforced at tunnel level before traffic reaches cluster
3. **Simplicity**: Single routing layer reduces configuration complexity
4. **Learning Value**: Reinforces Cloudflare Zero Trust pattern established in Feature 004
5. **Operational**: Easier to manage (one configuration point vs two)

**Implementation Details**:
- Homepage Service type: `ClusterIP` (internal only)
- Cloudflare Tunnel: Add route `homepage.chocolandiadc.com` → `http://homepage.homepage.svc.cluster.local:3000`
- Cloudflare Access: Create policy for homepage.chocolandiadc.com (same Google OAuth as other services)
- Internal TLS: Optional (traffic encrypted by Cloudflare Tunnel)
- cert-manager Certificate: Not required (Cloudflare manages public certificate)

**Alternative for Internal Access** (Future Enhancement):
- If internal cluster access without Cloudflare is needed later, add separate Traefik IngressRoute with internal-only domain (e.g., homepage.internal.chocolandiadc.local)

---

## 2. Deployment Method: Helm Chart vs Kubernetes Manifests

### Context
Homepage can be deployed via official Helm chart (jameswynn/homepage) or raw Kubernetes manifests. Need to decide which approach aligns with project constitution and provides best learning value.

### Options Evaluated

#### Option A: Helm Chart (jameswynn/homepage)
**Source**: https://github.com/jameswynn/helm-charts/tree/main/charts/homepage

**Pros**:
- Official chart maintained by Homepage developers
- Pre-configured templates for Deployment, Service, ConfigMaps, RBAC
- Parameterized configuration (values.yaml)
- Community best practices baked in
- Easy upgrades (helm upgrade)
- Can be managed via OpenTofu (helm_release resource)

**Cons**:
- Less transparency (templates abstract K8s resources)
- Learning value reduced (don't see raw manifests)
- Customization requires understanding Helm templating
- Additional dependency (Helm)

#### Option B: Kubernetes Manifests via OpenTofu
**Approach**: Define raw Kubernetes resources using OpenTofu kubernetes_manifest or kubernetes_deployment resources

**Pros**:
- Full transparency (see exact K8s resources created)
- Maximum learning value (understand every field)
- No Helm dependency
- Direct control over all configurations
- Easier to customize (no template indirection)
- Aligns with "Infrastructure as Code" principle (explicit resource definitions)

**Cons**:
- More verbose (manual resource definitions)
- Need to write RBAC, ConfigMaps, PVC, Deployment, Service manually
- Upgrades require manual manifest updates
- More maintenance burden

#### Option C: Hybrid Approach
**Approach**: Use Helm chart via OpenTofu helm_release resource, override values with custom configurations

**Pros**:
- Balance between convenience and control
- Helm chart handles boilerplate, OpenTofu manages values
- Easy upgrades while maintaining IaC principles
- GitOps friendly (values in Git)

**Cons**:
- Still requires understanding Helm values structure
- Less learning value than raw manifests

### Decision: **Option B - Kubernetes Manifests via OpenTofu**

**Rationale**:
1. **Learning Value**: Primary homelab goal is education. Writing raw manifests teaches K8s resource structure.
2. **Constitution Alignment**: "Infrastructure as Code" principle emphasizes explicit, versioned configuration.
3. **Transparency**: Easier to troubleshoot and understand when resources are explicit.
4. **Consistency**: Previous features (Pi-hole, Headlamp) used raw manifests, maintaining pattern consistency.
5. **Control**: Homepage configuration is straightforward enough that Helm abstraction doesn't provide significant value.

**Implementation Details**:
- OpenTofu kubernetes_deployment resource for Homepage pod
- OpenTofu kubernetes_service resource for ClusterIP service
- OpenTofu kubernetes_persistent_volume_claim for configuration storage
- OpenTofu kubernetes_config_map resources for services.yaml, widgets.yaml, settings.yaml
- OpenTofu kubernetes_service_account, kubernetes_role, kubernetes_role_binding for RBAC
- Module structure: `terraform/modules/homepage/`

---

## 3. RBAC Permissions for Service Discovery

### Context
Homepage requires Kubernetes API access to discover services, read pod status, and query ingress configurations for automatic service display.

### Research Findings

**Homepage Documentation**: https://gethomepage.dev/latest/configs/kubernetes/

**Required Permissions**:
- **Services**: `get`, `list` (read service metadata, ports, labels)
- **Pods**: `get`, `list` (read pod status, health)
- **Ingresses**: `get`, `list` (read ingress hostnames, paths)
- **Namespaces**: `get`, `list` (optional, for namespace filtering)

**Scope Options**:
1. **Cluster-wide (ClusterRole)**: Access to all namespaces
2. **Namespace-scoped (Role)**: Access to specific namespaces only

### Decision: **Namespace-scoped Role with explicit namespace list**

**Rationale**:
- **Principle of Least Privilege**: Only grant access to namespaces where services should be displayed
- **Security**: Prevent Homepage from accessing sensitive namespaces (kube-system, cert-manager internals)
- **Learning Value**: Demonstrates proper RBAC scoping

**Implementation**:
```yaml
# ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: homepage
  namespace: homepage

---
# Role (per namespace where services should be discovered)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: homepage-viewer
  namespace: <target-namespace>  # Repeat for: pihole, traefik, argocd, headlamp, homepage
rules:
- apiGroups: [""]
  resources: ["services", "pods"]
  verbs: ["get", "list"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list"]

---
# RoleBinding (per namespace)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: homepage-viewer
  namespace: <target-namespace>
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: homepage-viewer
subjects:
- kind: ServiceAccount
  name: homepage
  namespace: homepage
```

**Namespaces to Grant Access**:
- `pihole` (Pi-hole service)
- `traefik` (Traefik ingress controller)
- `cert-manager` (cert-manager for certificate status)
- `argocd` (ArgoCD applications)
- `headlamp` (Headlamp web UI)
- `homepage` (Homepage itself, for self-monitoring)

---

## 4. Widget Configuration Best Practices

### Context
Homepage supports specialized widgets for Pi-hole, Traefik, cert-manager (via Kubernetes), and ArgoCD. Need to determine best way to configure these for security and maintainability.

### Research Findings

#### Pi-hole Widget
**Documentation**: https://gethomepage.dev/latest/widgets/services/pihole/

**Configuration**:
```yaml
- Pi-hole:
    icon: pi-hole.png
    href: http://pihole.chocolandiadc.com
    description: Network-wide DNS ad blocker
    widget:
      type: pihole
      url: http://pihole.pihole.svc.cluster.local
      key: {{HOMEPAGE_VAR_PIHOLE_API_KEY}}  # Stored in Kubernetes Secret
```

**Security**:
- Pi-hole API key stored in Kubernetes Secret
- Referenced via environment variable in Homepage pod
- Homepage widget uses internal cluster URL (pihole.pihole.svc.cluster.local)

#### Traefik Widget
**Documentation**: https://gethomepage.dev/latest/widgets/services/traefik/

**Configuration**:
```yaml
- Traefik:
    icon: traefik.png
    href: https://traefik.chocolandiadc.com
    description: Cloud Native Ingress Controller
    widget:
      type: traefik
      url: http://traefik.traefik.svc.cluster.local:9000  # Traefik dashboard port
```

**Security**:
- Traefik dashboard typically requires basic auth or no auth (internal only)
- If auth required, credentials in Kubernetes Secret
- Dashboard port (9000) not exposed externally (internal ClusterIP only)

#### cert-manager Widget (Kubernetes CRD)
**Documentation**: https://gethomepage.dev/latest/widgets/services/kubernetes/

**Configuration**:
```yaml
- Certificates:
    icon: cert-manager.png
    description: TLS Certificate Status
    widget:
      type: kubernetes
      cluster:
        show: false
        cpu: false
        memory: false
      nodes:
        show: false
      customResources:
      - group: cert-manager.io
        version: v1
        kind: Certificate
        namespace: traefik  # Or cert-manager, depending on where certs are
```

**Security**:
- Uses Homepage's ServiceAccount with RBAC permissions
- Reads Certificate CRDs (read-only)
- No API keys required

#### ArgoCD Widget
**Documentation**: https://gethomepage.dev/latest/widgets/services/argocd/

**Configuration**:
```yaml
- ArgoCD:
    icon: argocd.png
    href: https://argocd.chocolandiadc.com
    description: GitOps Continuous Deployment
    widget:
      type: argocd
      url: http://argocd-server.argocd.svc.cluster.local
      username: admin  # Or service account
      password: {{HOMEPAGE_VAR_ARGOCD_TOKEN}}  # ArgoCD API token in Secret
```

**Security**:
- ArgoCD API token stored in Kubernetes Secret
- Token can be read-only service account token (not admin password)
- Widget uses internal cluster URL

### Decision: **Kubernetes Secrets for Sensitive Credentials**

**Implementation Pattern**:
1. Create Kubernetes Secret in Homepage namespace with widget API credentials
2. Mount secret as environment variables in Homepage Deployment
3. Reference environment variables in widgets.yaml using {{HOMEPAGE_VAR_*}} syntax
4. Store non-sensitive configs (URLs, icons, descriptions) in ConfigMap

**Example OpenTofu Configuration**:
```hcl
resource "kubernetes_secret" "homepage_widgets" {
  metadata {
    name      = "homepage-widgets"
    namespace = "homepage"
  }

  data = {
    PIHOLE_API_KEY  = var.pihole_api_key   # Provided via environment or vault
    ARGOCD_TOKEN    = var.argocd_token     # Provided via environment or vault
  }
}

resource "kubernetes_deployment" "homepage" {
  # ... other configuration ...

  spec {
    template {
      spec {
        container {
          name  = "homepage"
          image = "ghcr.io/gethomepage/homepage:latest"

          env_from {
            secret_ref {
              name = kubernetes_secret.homepage_widgets.metadata[0].name
            }
          }
        }
      }
    }
  }
}
```

---

## 5. Storage Requirements

### Context
Homepage stores configuration YAML files (services.yaml, widgets.yaml, settings.yaml) that need to persist across pod restarts.

### Research Findings

**Homepage Data Path**: `/app/config/` (default container path)

**Storage Options**:
1. **ConfigMaps Only**: Store all YAML files as ConfigMaps, mount as volumes
2. **PersistentVolume + ConfigMaps**: Initial config via ConfigMaps, user edits stored on PV
3. **PersistentVolume Only**: All configuration on PV, managed manually or via init container

### Decision: **ConfigMaps for Static Configuration**

**Rationale**:
- Homepage configuration managed via GitOps (changes committed to Git, applied via ArgoCD)
- No manual edits via Homepage UI required (read-only dashboard philosophy)
- ConfigMaps provide versioned, declarative configuration aligned with IaC principles
- Simpler than PersistentVolume (no storage class, provisioning, or backup concerns)

**Implementation**:
```hcl
resource "kubernetes_config_map" "homepage_services" {
  metadata {
    name      = "homepage-services"
    namespace = "homepage"
  }

  data = {
    "services.yaml" = file("${path.module}/configs/services.yaml")
  }
}

resource "kubernetes_config_map" "homepage_widgets" {
  metadata {
    name      = "homepage-widgets"
    namespace = "homepage"
  }

  data = {
    "widgets.yaml" = file("${path.module}/configs/widgets.yaml")
  }
}

# Mount in Deployment
resource "kubernetes_deployment" "homepage" {
  spec {
    template {
      spec {
        container {
          volume_mount {
            name       = "services"
            mount_path = "/app/config/services.yaml"
            sub_path   = "services.yaml"
          }
          volume_mount {
            name       = "widgets"
            mount_path = "/app/config/widgets.yaml"
            sub_path   = "widgets.yaml"
          }
        }

        volume {
          name = "services"
          config_map {
            name = kubernetes_config_map.homepage_services.metadata[0].name
          }
        }
        volume {
          name = "widgets"
          config_map {
            name = kubernetes_config_map.homepage_widgets.metadata[0].name
          }
        }
      }
    }
  }
}
```

**Future Enhancement**: If user edits via UI become needed, add PersistentVolume with init container to copy ConfigMap contents on first boot.

---

## Research Summary

### All NEEDS CLARIFICATION Resolved

| Item | Resolution |
|------|------------|
| **Ingress/Routing** | Cloudflare Tunnel only (ClusterIP service, no Traefik IngressRoute) |
| **Deployment Method** | Kubernetes manifests via OpenTofu (no Helm chart) |
| **RBAC Scope** | Namespace-scoped Roles for specific service namespaces |
| **Widget Security** | Kubernetes Secrets for API credentials, environment variable injection |
| **Storage** | ConfigMaps for static configuration (no PersistentVolume) |

### Key Architectural Decisions

1. **Routing**: Cloudflare Tunnel → ClusterIP Service → Homepage Pod
2. **Authentication**: Cloudflare Access with Google OAuth at tunnel level
3. **Configuration**: GitOps workflow (ConfigMaps in Git, applied via ArgoCD)
4. **RBAC**: Minimal read-only permissions scoped to specific namespaces
5. **Secrets**: Kubernetes Secrets for widget API keys (Pi-hole, ArgoCD)

### Implementation Readiness

All technical unknowns resolved. Ready to proceed to Phase 1 (Design & Contracts).

**Next Steps**:
- Generate data-model.md (Homepage configuration entities)
- Generate contracts/ (YAML schemas for services.yaml, widgets.yaml, settings.yaml)
- Generate quickstart.md (deployment procedure)
- Update agent context (CLAUDE.md)
