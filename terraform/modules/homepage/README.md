# Homepage Dashboard Module

## Overview

This OpenTofu/Terraform module deploys Homepage (gethomepage.dev) as a centralized dashboard for monitoring and accessing Kubernetes services in the Chocolandia Kube cluster.

## Features

- **Service Discovery**: Automatically displays all deployed services with internal and external URLs
- **Real-Time Status**: Shows current operational status of services via Kubernetes API integration
- **Infrastructure Widgets**: Specialized widgets for Pi-hole, Traefik, cert-manager, and ArgoCD
- **Secure Access**: External access via Cloudflare Zero Trust with Google OAuth authentication
- **GitOps Ready**: Configuration managed as code, deployable via ArgoCD

## Architecture

```
Internet → Cloudflare Access (OAuth) → Cloudflare Tunnel → Homepage Service (ClusterIP) → Homepage Pod
                                                                    ↓
                                                            Kubernetes API (RBAC read-only)
                                                                    ↓
                                                Service Discovery (pihole, traefik, argocd, etc.)
```

## Module Usage

```hcl
module "homepage" {
  source = "../../modules/homepage"

  homepage_image  = "ghcr.io/gethomepage/homepage:v0.8.10"
  pihole_api_key  = var.pihole_api_key
  argocd_token    = var.argocd_token
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| homepage_image | Docker image for Homepage | string | "ghcr.io/gethomepage/homepage:latest" | no |
| pihole_api_key | Pi-hole API key for widget | string | - | yes |
| argocd_token | ArgoCD API token for widget | string | - | yes |
| namespace | Kubernetes namespace for Homepage | string | "homepage" | no |
| service_port | Internal service port | number | 3000 | no |
| resource_requests_cpu | CPU request | string | "100m" | no |
| resource_requests_memory | Memory request | string | "128Mi" | no |
| resource_limits_cpu | CPU limit | string | "500m" | no |
| resource_limits_memory | Memory limit | string | "512Mi" | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Homepage namespace name |
| service_name | Homepage service name |
| service_url | Internal cluster URL for Homepage |
| configmap_names | List of ConfigMap names created |
| secret_name | Secret name for widget credentials |

## Configuration Files

The module includes three YAML configuration files mounted as ConfigMaps:

### services.yaml
Defines all services displayed on the dashboard with their URLs, icons, and widget configurations.

Example:
```yaml
- Infrastructure:
    - Pi-hole:
        icon: pi-hole.png
        href: https://pihole.chocolandiadc.com
        description: Network-wide DNS ad blocker
        server: k3s-cluster
        namespace: pihole
        widget:
          type: pihole
          url: http://pihole.pihole.svc.cluster.local
          key: "{{HOMEPAGE_VAR_PIHOLE_API_KEY}}"
```

### settings.yaml
Defines global Homepage configuration (theme, layout, title).

Example:
```yaml
title: Chocolandia Kube Dashboard
theme: dark
layout:
  Infrastructure:
    columns: 3
```

### widgets.yaml
Defines standalone widgets (resources, datetime, search).

Example:
```yaml
- datetime:
    text_size: lg
    format:
      timeStyle: short
      dateStyle: full
```

## RBAC Configuration

Homepage requires read-only access to Kubernetes API for service discovery and status monitoring. The module creates:

- **ServiceAccount**: `homepage` in `homepage` namespace
- **Roles**: Namespace-scoped roles in each monitored namespace
- **RoleBindings**: Connect ServiceAccount to Roles

**Permissions granted** (read-only):
- `services`: get, list
- `pods`: get, list
- `ingresses`: get, list
- `certificates` (cert-manager CRD): get, list

**Monitored namespaces**:
- pihole
- traefik
- cert-manager
- argocd
- headlamp
- homepage

## Widget Configuration

### Pi-hole Widget
**Requirements**: Pi-hole API key from Settings → API in Pi-hole admin UI

Displays DNS statistics (queries today, blocked queries, top domains).

### Traefik Widget
**Requirements**: Traefik dashboard enabled (port 9000)

Displays router/service status and request metrics.

### cert-manager Widget
**Requirements**: ServiceAccount with read access to Certificate CRDs

Displays certificate expiration dates and renewal status.

### ArgoCD Widget
**Requirements**: ArgoCD API token (read-only)

Generate token:
```bash
argocd account generate-token --account homepage
```

Displays application sync status and health.

## Deployment

1. **Set secret variables**:
```bash
export TF_VAR_pihole_api_key="your-pihole-api-key"
export TF_VAR_argocd_token="your-argocd-token"
```

2. **Deploy module**:
```bash
cd terraform/environments/chocolandiadc-mvp
tofu init
tofu validate
tofu plan
tofu apply
```

3. **Verify deployment**:
```bash
kubectl -n homepage get pods
kubectl -n homepage logs deployment/homepage
```

4. **Access dashboard**:
- Internal: `http://homepage.homepage.svc.cluster.local:3000`
- External: `https://homepage.chocolandiadc.com` (via Cloudflare Tunnel)

## Troubleshooting

### Pod CrashLoopBackOff
**Check**: ConfigMap mount failure, invalid YAML syntax, missing environment variables

```bash
kubectl -n homepage logs deployment/homepage
kubectl -n homepage describe pod <pod-name>
```

### Widgets Not Loading
**Check**: Incorrect API URLs, missing credentials, RBAC permissions, service unreachable

```bash
# Test API connectivity from Homepage pod
kubectl -n homepage exec deployment/homepage -- curl http://pihole.pihole.svc.cluster.local

# Check RBAC permissions
kubectl auth can-i list pods --as=system:serviceaccount:homepage:homepage -n pihole
```

### Service Discovery Not Working
**Check**: RBAC permissions, invalid server name, service doesn't exist

```bash
kubectl get role homepage-viewer -n pihole
kubectl -n pihole get svc
```

## Maintenance

### Updating Configuration
Edit YAML files in `configs/`, commit to Git, run `tofu apply`:

```bash
# Edit configs/services.yaml
git add terraform/modules/homepage/configs/
git commit -m "Update Homepage services"
tofu apply
```

### Rotating API Credentials
Update Secret and restart Homepage:

```bash
kubectl -n homepage create secret generic homepage-widgets \
  --from-literal=PIHOLE_API_KEY="new-key" \
  --from-literal=ARGOCD_TOKEN="new-token" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n homepage rollout restart deployment/homepage
```

### Adding New Services
1. Edit `configs/services.yaml`
2. Add service entry with appropriate group
3. If widget needed, configure widget section
4. Run `tofu apply`

## Security

- **Authentication**: Handled by Cloudflare Access (Google OAuth)
- **RBAC**: Read-only namespace-scoped permissions
- **Secrets**: Widget credentials stored in Kubernetes Secrets
- **Network**: ClusterIP service (not exposed directly)
- **TLS**: HTTPS via Cloudflare Tunnel

## Resources

- **Homepage Official Docs**: https://gethomepage.dev/latest/
- **Widgets Documentation**: https://gethomepage.dev/latest/widgets/
- **Kubernetes Integration**: https://gethomepage.dev/latest/configs/kubernetes/
- **Troubleshooting**: https://gethomepage.dev/latest/troubleshooting/

## License

This module is part of the Chocolandia Kube project. See project LICENSE for details.
