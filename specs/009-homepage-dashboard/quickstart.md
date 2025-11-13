# Quickstart Guide: Homepage Dashboard Deployment

**Feature**: 009-homepage-dashboard
**Date**: 2025-11-12
**Target Audience**: Cluster administrators deploying Homepage to K3s

## Overview

This guide provides step-by-step instructions to deploy Homepage (gethomepage.dev) as a centralized dashboard for your K3s cluster. Homepage will display all deployed services with their internal and external URLs, monitor infrastructure via specialized widgets (Pi-hole, Traefik, cert-manager, ArgoCD), and be accessible externally via Cloudflare Zero Trust authentication.

**Estimated Time**: 45-60 minutes
**Prerequisites**: K3s cluster operational, Cloudflare Zero Trust configured, cert-manager and ArgoCD deployed

---

## Architecture Diagram

```
Internet
   │
   ├─ Cloudflare Access (Google OAuth)
   │
   ├─ Cloudflare Tunnel
   │   (homepage.chocolandiadc.com)
   │
   ├─ K3s Cluster
   │   │
   │   ├─ homepage namespace
   │   │   ├─ Homepage Pod (ghcr.io/gethomepage/homepage:latest)
   │   │   ├─ Service (ClusterIP)
   │   │   ├─ ConfigMaps (services.yaml, widgets.yaml, settings.yaml)
   │   │   ├─ Secret (widget API credentials)
   │   │   └─ RBAC (ServiceAccount, Roles, RoleBindings)
   │   │
   │   └─ Monitored Services
   │       ├─ pihole namespace (Pi-hole)
   │       ├─ traefik namespace (Traefik)
   │       ├─ cert-manager namespace (cert-manager)
   │       ├─ argocd namespace (ArgoCD)
   │       └─ headlamp namespace (Headlamp)
```

---

## Prerequisites

### 1. Cluster Requirements
- **K3s v1.28+** operational with 3 control-plane + 1 worker node
- **kubectl** configured with cluster-admin access
- **OpenTofu 1.6+** installed locally
- **Git repository** for OpenTofu configurations (chocolandia_kube)

### 2. Existing Infrastructure
- **Cloudflare Zero Trust** account with tunnel configured
- **Cloudflare Access** with Google OAuth identity provider
- **ArgoCD** deployed and operational
- **cert-manager** deployed (optional, for TLS if using Traefik IngressRoute)
- **Traefik** deployed (optional, for internal ingress)

### 3. Service API Access
Gather required credentials for widgets:
- **Pi-hole API key**: From Pi-hole admin UI → Settings → API
- **ArgoCD API token**: Generate via `argocd account generate-token --account homepage` (or use admin token)
- **Traefik dashboard**: Ensure dashboard is enabled (port 9000)

### 4. DNS Configuration
- Subdomain ready: `homepage.chocolandiadc.com` (or your chosen domain)
- Cloudflare DNS configured (will be updated via Terraform)

---

## Deployment Steps

### Step 1: Create Homepage OpenTofu Module

**Location**: `terraform/modules/homepage/`

Create the module directory structure:

```bash
cd terraform/modules
mkdir -p homepage/configs
cd homepage
```

**Files to create**:
1. `main.tf` - Namespace, Deployment, Service, ConfigMaps
2. `rbac.tf` - ServiceAccount, Roles, RoleBindings
3. `variables.tf` - Input variables
4. `outputs.tf` - Output values
5. `configs/services.yaml` - Service entries configuration
6. `configs/widgets.yaml` - Standalone widgets configuration
7. `configs/settings.yaml` - Dashboard settings

**Example `main.tf`** (abbreviated):

```hcl
# Namespace
resource "kubernetes_namespace" "homepage" {
  metadata {
    name = "homepage"
    labels = {
      name = "homepage"
      managed-by = "opentofu"
    }
  }
}

# ConfigMaps for Homepage configuration
resource "kubernetes_config_map" "homepage_services" {
  metadata {
    name      = "homepage-services"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    "services.yaml" = file("${path.module}/configs/services.yaml")
  }
}

resource "kubernetes_config_map" "homepage_widgets" {
  metadata {
    name      = "homepage-widgets"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    "widgets.yaml" = file("${path.module}/configs/widgets.yaml")
  }
}

resource "kubernetes_config_map" "homepage_settings" {
  metadata {
    name      = "homepage-settings"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    "settings.yaml" = file("${path.module}/configs/settings.yaml")
  }
}

# Secret for widget API credentials
resource "kubernetes_secret" "homepage_widgets" {
  metadata {
    name      = "homepage-widgets"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    PIHOLE_API_KEY = var.pihole_api_key
    ARGOCD_TOKEN   = var.argocd_token
  }
}

# Deployment
resource "kubernetes_deployment" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
    labels = {
      app = "homepage"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "homepage"
      }
    }

    template {
      metadata {
        labels = {
          app = "homepage"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.homepage.metadata[0].name

        container {
          name  = "homepage"
          image = var.homepage_image

          port {
            container_port = 3000
          }

          # Mount ConfigMaps
          volume_mount {
            name       = "services-config"
            mount_path = "/app/config/services.yaml"
            sub_path   = "services.yaml"
          }

          volume_mount {
            name       = "widgets-config"
            mount_path = "/app/config/widgets.yaml"
            sub_path   = "widgets.yaml"
          }

          volume_mount {
            name       = "settings-config"
            mount_path = "/app/config/settings.yaml"
            sub_path   = "settings.yaml"
          }

          # Inject secrets as environment variables
          env_from {
            secret_ref {
              name = kubernetes_secret.homepage_widgets.metadata[0].name
            }
          }

          # Resource limits
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          # Liveness probe
          liveness_probe {
            http_get {
              path = "/"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          # Readiness probe
          readiness_probe {
            http_get {
              path = "/"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }

        # Volumes
        volume {
          name = "services-config"
          config_map {
            name = kubernetes_config_map.homepage_services.metadata[0].name
          }
        }

        volume {
          name = "widgets-config"
          config_map {
            name = kubernetes_config_map.homepage_widgets.metadata[0].name
          }
        }

        volume {
          name = "settings-config"
          config_map {
            name = kubernetes_config_map.homepage_settings.metadata[0].name
          }
        }
      }
    }
  }
}

# Service (ClusterIP)
resource "kubernetes_service" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  spec {
    selector = {
      app = "homepage"
    }

    port {
      port        = 3000
      target_port = 3000
    }

    type = "ClusterIP"
  }
}
```

**Full module code**: See `terraform/modules/homepage/` after deployment.

---

### Step 2: Configure Homepage YAML Files

**2a. Create `configs/services.yaml`**:

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
          key: "{{HOMEPAGE_VAR_PIHOLE_API_KEY}}"

    - Traefik:
        icon: traefik.png
        href: https://traefik.chocolandiadc.com
        description: Cloud Native Ingress Controller
        server: k3s-cluster
        namespace: traefik
        widget:
          type: traefik
          url: http://traefik.traefik.svc.cluster.local:9000

    - cert-manager:
        icon: cert-manager.png
        href: https://cert-manager.io/docs
        description: TLS Certificate Management
        server: k3s-cluster
        namespace: cert-manager
        widget:
          type: kubernetes
          cluster:
            show: false
          nodes:
            show: false
          customResources:
            - group: cert-manager.io
              version: v1
              kind: Certificate
              namespace: traefik

- GitOps & Monitoring:
    - ArgoCD:
        icon: argocd.png
        href: https://argocd.chocolandiadc.com
        description: GitOps Continuous Deployment
        server: k3s-cluster
        namespace: argocd
        widget:
          type: argocd
          url: http://argocd-server.argocd.svc.cluster.local
          username: admin
          password: "{{HOMEPAGE_VAR_ARGOCD_TOKEN}}"

    - Headlamp:
        icon: headlamp.png
        href: https://headlamp.chocolandiadc.com
        description: Kubernetes Web UI
        server: k3s-cluster
        namespace: headlamp

- Applications:
    - Homepage:
        icon: homepage.png
        href: https://homepage.chocolandiadc.com
        description: Chocolandia Kube Dashboard
        server: k3s-cluster
        namespace: homepage
```

**2b. Create `configs/widgets.yaml`**:

```yaml
- datetime:
    text_size: lg
    format:
      timeStyle: short
      dateStyle: full
      hour12: false

- resources:
    cpu: true
    memory: true
    disk: /
    label: Cluster Resources
```

**2c. Create `configs/settings.yaml`**:

```yaml
title: Chocolandia Kube Dashboard
favicon: https://chocolandiadc.com/favicon.ico
theme: dark
color: slate
headerStyle: boxed
target: _blank

layout:
  Infrastructure:
    style: row
    columns: 3

  "GitOps & Monitoring":
    style: row
    columns: 2

  Applications:
    style: row
    columns: 4

language: en
```

---

### Step 3: Configure RBAC Permissions

**Create `rbac.tf`**:

```hcl
# ServiceAccount
resource "kubernetes_service_account" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
}

# Role (repeated for each namespace)
locals {
  monitored_namespaces = ["pihole", "traefik", "cert-manager", "argocd", "headlamp", "homepage"]
}

resource "kubernetes_role" "homepage_viewer" {
  for_each = toset(local.monitored_namespaces)

  metadata {
    name      = "homepage-viewer"
    namespace = each.value
  }

  rule {
    api_groups = [""]
    resources  = ["services", "pods"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["certificates"]
    verbs      = ["get", "list"]
  }
}

# RoleBinding (repeated for each namespace)
resource "kubernetes_role_binding" "homepage_viewer" {
  for_each = toset(local.monitored_namespaces)

  metadata {
    name      = "homepage-viewer"
    namespace = each.value
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.homepage_viewer[each.key].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.homepage.metadata[0].name
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
}
```

---

### Step 4: Configure Cloudflare Tunnel & Access

**Update `terraform/environments/chocolandiadc-mvp/cloudflare-access.tf`**:

Add Cloudflare Tunnel ingress rule for Homepage:

```hcl
# Add to existing cloudflare_tunnel_config resource
resource "cloudflare_tunnel_config" "chocolandiadc_tunnel" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.chocolandiadc_tunnel.id

  config {
    # ... existing ingress rules ...

    ingress_rule {
      hostname = "homepage.chocolandiadc.com"
      service  = "http://homepage.homepage.svc.cluster.local:3000"
    }

    # ... catch-all rule ...
  }
}

# Cloudflare Access Application for Homepage
resource "cloudflare_access_application" "homepage" {
  zone_id          = var.cloudflare_zone_id
  name             = "Homepage Dashboard"
  domain           = "homepage.chocolandiadc.com"
  type             = "self_hosted"
  session_duration = "24h"
}

# Cloudflare Access Policy
resource "cloudflare_access_policy" "homepage_google_auth" {
  application_id = cloudflare_access_application.homepage.id
  zone_id        = var.cloudflare_zone_id
  name           = "Google OAuth - Homepage Access"
  precedence     = 1
  decision       = "allow"

  include {
    google {
      identity_provider_id = var.cloudflare_google_idp_id
      emails               = var.allowed_user_emails
    }
  }
}
```

---

### Step 5: Create ArgoCD Application

**Update `terraform/environments/chocolandiadc-mvp/argocd.tf`**:

Add ArgoCD Application for Homepage (optional, for GitOps workflow):

```hcl
resource "kubernetes_manifest" "argocd_app_homepage" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "homepage"
      namespace = "argocd"
    }
    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/cbenitezpy-ueno/chocolandia_kube"
        targetRevision = "main"
        path           = "terraform/modules/homepage"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "homepage"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
}
```

---

### Step 6: Deploy Homepage via OpenTofu

**6a. Navigate to environment directory**:

```bash
cd terraform/environments/chocolandiadc-mvp
```

**6b. Create Homepage module invocation** (`homepage.tf`):

```hcl
module "homepage" {
  source = "../../modules/homepage"

  homepage_image  = "ghcr.io/gethomepage/homepage:v0.8.10"
  pihole_api_key  = var.pihole_api_key
  argocd_token    = var.argocd_token
}
```

**6c. Add variables to `variables.tf`**:

```hcl
variable "pihole_api_key" {
  description = "Pi-hole API key for Homepage widget"
  type        = string
  sensitive   = true
}

variable "argocd_token" {
  description = "ArgoCD API token for Homepage widget"
  type        = string
  sensitive   = true
}
```

**6d. Set secret variables** (environment variables or `.tfvars` file):

```bash
export TF_VAR_pihole_api_key="your-pihole-api-key"
export TF_VAR_argocd_token="your-argocd-token"
```

**6e. Deploy**:

```bash
tofu init
tofu validate
tofu plan
tofu apply
```

---

### Step 7: Verify Deployment

**7a. Check pod status**:

```bash
kubectl -n homepage get pods
# Expected: homepage-<hash> Running 1/1

kubectl -n homepage logs deployment/homepage
# Expected: No errors, Homepage started successfully
```

**7b. Check service**:

```bash
kubectl -n homepage get svc
# Expected: homepage ClusterIP 10.x.x.x:3000

kubectl -n homepage get configmaps
# Expected: homepage-services, homepage-widgets, homepage-settings

kubectl -n homepage get secrets
# Expected: homepage-widgets
```

**7c. Test internal access** (from within cluster):

```bash
kubectl run -n homepage test-curl --rm -it --image=curlimages/curl -- \
  curl http://homepage.homepage.svc.cluster.local:3000
# Expected: HTML response with Homepage dashboard
```

**7d. Test external access**:

1. Open browser: `https://homepage.chocolandiadc.com`
2. Should redirect to Google OAuth login (Cloudflare Access)
3. After authentication, Homepage dashboard should load
4. Verify services are displayed with correct URLs
5. Check widgets are loading data (Pi-hole stats, Traefik status, etc.)

---

### Step 8: Validation Tests

**8a. Service Discovery Test**:

```bash
# Homepage should discover services in monitored namespaces
kubectl -n homepage logs deployment/homepage | grep "Kubernetes"
# Expected: No RBAC errors, services discovered
```

**8b. Widget Functionality Test**:

Check each widget in the UI:
- **Pi-hole**: Queries today, blocked queries, percent blocked displayed
- **Traefik**: Routers, services, response times displayed
- **cert-manager**: Certificate list with expiration dates
- **ArgoCD**: Application sync status and health

**8c. Authentication Test**:

```bash
# Unauthenticated request should be blocked
curl -I https://homepage.chocolandiadc.com
# Expected: HTTP 302 redirect to Cloudflare Access login
```

**8d. Configuration Update Test**:

1. Edit `terraform/modules/homepage/configs/services.yaml`
2. Add a new service entry
3. Run `tofu apply`
4. Refresh Homepage dashboard
5. New service should appear

---

## Troubleshooting

### Issue 1: Pod CrashLoopBackOff

**Symptoms**: Homepage pod repeatedly crashes

**Diagnosis**:
```bash
kubectl -n homepage logs deployment/homepage
kubectl -n homepage describe pod <pod-name>
```

**Common Causes**:
- ConfigMap mount failure (check volume mounts)
- Invalid YAML syntax in configuration files
- Missing environment variables (check Secret)

**Solution**:
- Validate YAML files: `yamllint configs/*.yaml`
- Check ConfigMap data: `kubectl -n homepage get cm homepage-services -o yaml`
- Verify Secret exists: `kubectl -n homepage get secret homepage-widgets`

### Issue 2: Widgets Not Loading

**Symptoms**: Service cards display but widgets show errors

**Diagnosis**:
```bash
kubectl -n homepage logs deployment/homepage | grep -i error
```

**Common Causes**:
- Incorrect API URLs (typos in service names)
- Missing API credentials (Secret not injected)
- RBAC permissions missing
- Target service API unreachable

**Solution**:
- Test API connectivity from Homepage pod:
  ```bash
  kubectl -n homepage exec deployment/homepage -- curl http://pihole.pihole.svc.cluster.local
  ```
- Check RBAC permissions:
  ```bash
  kubectl auth can-i list pods --as=system:serviceaccount:homepage:homepage -n pihole
  # Expected: yes
  ```
- Verify Secret environment variables:
  ```bash
  kubectl -n homepage exec deployment/homepage -- env | grep HOMEPAGE_VAR
  ```

### Issue 3: Service Discovery Not Working

**Symptoms**: Services don't appear on dashboard, even with `server` and `namespace` configured

**Diagnosis**:
```bash
kubectl -n homepage logs deployment/homepage | grep "service discovery"
```

**Common Causes**:
- RBAC permissions not granted for target namespace
- Invalid `server` name in services.yaml
- Service doesn't exist in specified namespace

**Solution**:
- Verify RBAC:
  ```bash
  kubectl get role homepage-viewer -n pihole
  kubectl get rolebinding homepage-viewer -n pihole
  ```
- Check service exists:
  ```bash
  kubectl -n pihole get svc
  ```

### Issue 4: Cloudflare Access Redirect Loop

**Symptoms**: Browser keeps redirecting, never reaches Homepage

**Diagnosis**: Check Cloudflare Access logs in Cloudflare dashboard

**Common Causes**:
- Cloudflare Access policy misconfigured
- User email not in allowed list
- Session cookie issues

**Solution**:
- Verify Access policy:
  ```bash
  tofu show | grep cloudflare_access_policy
  ```
- Check allowed emails match user attempting access
- Clear browser cookies and try again
- Test with different browser/incognito mode

---

## Maintenance

### Updating Homepage Configuration

**Method 1: GitOps (Recommended)**:
1. Edit YAML files in `terraform/modules/homepage/configs/`
2. Commit changes to Git
3. Run `tofu apply`
4. Homepage pod will restart with new configuration

**Method 2: Manual kubectl (For testing only)**:
```bash
kubectl -n homepage edit cm homepage-services
# Edit YAML, save
kubectl -n homepage rollout restart deployment/homepage
```

### Updating Homepage Image Version

```bash
# Update homepage_image in terraform/environments/chocolandiadc-mvp/homepage.tf
homepage_image = "ghcr.io/gethomepage/homepage:v0.9.0"

# Apply
tofu apply
```

### Adding New Services

1. Edit `configs/services.yaml`
2. Add service entry with appropriate group
3. If widget needed, configure widget section
4. Apply changes: `tofu apply`

### Rotating API Credentials

```bash
# Update secret
kubectl -n homepage create secret generic homepage-widgets \
  --from-literal=PIHOLE_API_KEY="new-key" \
  --from-literal=ARGOCD_TOKEN="new-token" \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Homepage
kubectl -n homepage rollout restart deployment/homepage
```

---

## Security Best Practices

1. **Secrets Management**:
   - Never commit API keys to Git
   - Use environment variables or external secret managers
   - Rotate credentials periodically

2. **RBAC**:
   - Homepage ServiceAccount has read-only permissions only
   - Namespace-scoped (not cluster-wide ClusterRole)
   - Only granted access to necessary namespaces

3. **Network Security**:
   - Homepage Service is ClusterIP (not exposed directly)
   - External access only via Cloudflare Tunnel
   - Cloudflare Access enforces authentication

4. **Configuration Validation**:
   - Validate YAML before applying
   - Test changes in non-production environment first
   - Use GitOps workflow for audit trail

---

## Success Criteria Checklist

- [✓] Homepage pod running (1/1 Ready)
- [✓] Dashboard accessible via https://homepage.chocolandiadc.com
- [✓] Cloudflare Access authentication working (Google OAuth)
- [✓] All services displayed with correct internal and external URLs
- [✓] Pi-hole widget showing DNS statistics
- [✓] Traefik widget showing router/service status
- [✓] cert-manager widget showing certificate expiration dates
- [✓] ArgoCD widget showing application sync status
- [✓] Service discovery working (services automatically detected)
- [✓] Configuration managed via GitOps (OpenTofu + ArgoCD)
- [✓] RBAC permissions minimal and scoped correctly
- [✓] No errors in Homepage pod logs
- [✓] Dashboard loads in < 3 seconds
- [✓] Widgets refresh data every 30 seconds

---

## Next Steps

1. **Add More Services**: As you deploy new applications, add them to services.yaml
2. **Custom Widgets**: Explore additional Homepage widgets (Docker, Prometheus, etc.)
3. **Theming**: Customize colors, icons, and layout in settings.yaml
4. **Bookmarks**: Add frequently accessed external links in bookmarks.yaml
5. **Monitoring**: Create Grafana dashboard for Homepage metrics (if Prometheus scraping enabled)

---

## Additional Resources

- **Homepage Official Docs**: https://gethomepage.dev/latest/
- **Widgets Documentation**: https://gethomepage.dev/latest/widgets/
- **Kubernetes Integration**: https://gethomepage.dev/latest/configs/kubernetes/
- **Service Discovery**: https://gethomepage.dev/latest/configs/service-discovery/
- **Troubleshooting**: https://gethomepage.dev/latest/troubleshooting/

---

**Quickstart Complete!** Your Homepage dashboard should now be operational. For implementation details, see `tasks.md` (generated via `/speckit.tasks`).
