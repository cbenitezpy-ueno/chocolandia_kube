# Homepage Dashboard

Unified dashboard for monitoring and managing chocolandiadc K3s homelab cluster.

## Overview

Homepage is a modern, customizable application dashboard that provides:
- **Service Status Monitoring**: Real-time status of all infrastructure services via Kubernetes widgets
- **Infrastructure Widgets**: Live metrics from ArgoCD, Traefik, cert-manager, and more
- **Kubernetes Integration**: Auto-discovery of pods, services, and resources with metrics-server data
- **External Access**: Secure access via Cloudflare Zero Trust with Google OAuth authentication
- **GitOps Management**: All configuration managed through Git, automatically synced via ArgoCD

## Architecture

### Deployment Model

```
GitHub Repository (chocolandia_kube/kubernetes/homepage/)
    ↓
ArgoCD Application (automated sync every 3 minutes)
    ↓
Kubernetes Namespace (homepage)
    ├── ServiceAccount (homepage) - RBAC permissions
    ├── ConfigMaps (services, widgets, settings, kubernetes)
    ├── Secret (ArgoCD JWT token)
    ├── Deployment (1 replica, homepage pod)
    ├── Service (ClusterIP on port 3000)
    └── Ingress (Cloudflare tunnel → homepage.chocolandiadc.com)
```

### RBAC Permissions

The Homepage ServiceAccount has read-only access to:
- **Cluster-wide resources**: nodes, namespaces, persistent volumes, ingresses
- **Metrics**: metrics-server (nodes, pods)
- **Namespaced resources** (6 monitored namespaces):
  - Core: services, pods, pods/log
  - Apps: deployments, replicasets, statefulsets, daemonsets
  - Networking: ingresses
  - CRDs: certificates (cert-manager), applications (ArgoCD)

See [RBAC.md](./RBAC.md) for detailed permissions explanation.

## GitOps Workflow

### Making Changes

1. **Modify YAML files** in `kubernetes/homepage/` directory
2. **Commit and push** to GitHub main branch
3. **ArgoCD detects** changes automatically (3-minute polling interval)
4. **ArgoCD syncs** changes to cluster (selfHeal + prune enabled)
5. **Changes apply** automatically without manual intervention

Example: Adding a new service to dashboard

```bash
# Edit services configuration
vim kubernetes/homepage/configmaps.yaml

# Add your service to the services.yaml section
# Example:
#   - My Services:
#       - MyApp:
#           icon: myapp.svg
#           href: https://myapp.example.com
#           description: My application description
#           widget:
#             type: kubernetes
#             podSelector: app=myapp

# Commit changes
git add kubernetes/homepage/configmaps.yaml
git commit -m "feat: Add MyApp service to Homepage dashboard"
git push

# Wait for ArgoCD to sync (max 3 minutes)
kubectl get applications homepage -n argocd -w
```

See [Adding New Services](#adding-new-services) section below for detailed guide.

## Configuration Files

### namespace.yaml
Defines the `homepage` namespace with labels for ArgoCD management.

### rbac.yaml
Complete RBAC configuration:
- ServiceAccount `homepage`
- ClusterRole `homepage-cluster-viewer` (cluster-wide read permissions)
- 6 Roles `homepage-viewer` (one per monitored namespace)
- ClusterRoleBinding and 6 RoleBindings

### configmaps.yaml
Four ConfigMaps containing Homepage configuration:

1. **homepage-services**: Service groups, links, and Kubernetes widgets
2. **homepage-widgets**: Infrastructure widgets (ArgoCD, cluster stats)
3. **homepage-settings**: Dashboard layout, theme, and behavior
4. **homepage-kubernetes**: Kubernetes integration configuration (service discovery)

### secret.yaml
Sensitive credentials:
- `HOMEPAGE_VAR_ARGOCD_TOKEN`: JWT token for ArgoCD widget authentication

**⚠️ Security Note**: Never commit real tokens to Git. Use placeholders and update via kubectl after deployment.

### deployment.yaml
Homepage Deployment and Service:
- **Image**: `ghcr.io/gethomepage/homepage:latest`
- **Replicas**: 1 (sufficient for homelab)
- **Resources**: 100m CPU / 128Mi RAM (requests), 200m CPU / 256Mi RAM (limits)
- **Probes**: Liveness and readiness checks on port 3000
- **Service**: ClusterIP on port 3000

### ingress.yaml
Traefik Ingress with Cloudflare Access:
- **Domain**: homepage.chocolandiadc.com
- **TLS**: Let's Encrypt certificate via cert-manager
- **Authentication**: Cloudflare Zero Trust with Google OAuth

## Adding New Services

To add a new service to the Homepage dashboard:

### 1. Update services.yaml in configmaps.yaml

Edit `kubernetes/homepage/configmaps.yaml` and add your service under the appropriate group:

```yaml
data:
  services.yaml: |
    - Your Service Group:
        - ServiceName:
            icon: service-icon.svg  # Icon from https://github.com/walkxcode/dashboard-icons
            href: https://service.chocolandiadc.com  # Optional external link
            description: Service description
            namespace: service-namespace
            app: service-app-name
            widget:
              type: kubernetes
              cluster: default
              namespace: service-namespace
              app: service-app-name
              podSelector: app.kubernetes.io/name=service-app-name
```

### 2. Add RBAC Permissions (if new namespace)

If your service is in a **new namespace** not currently monitored, update `rbac.yaml`:

1. Add namespace to `monitored_namespaces` variable
2. Add Role and RoleBinding for the new namespace

### 3. Commit and Push

```bash
git add kubernetes/homepage/configmaps.yaml
# If RBAC changed:
git add kubernetes/homepage/rbac.yaml

git commit -m "feat: Add ServiceName to Homepage dashboard"
git push
```

### 4. Verify Sync

Wait for ArgoCD to sync (max 3 minutes) or trigger manual sync:

```bash
# Watch ArgoCD Application
kubectl get applications homepage -n argocd -w

# Or trigger immediate sync
kubectl patch application homepage -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

### 5. Verify Service Appears

Open https://homepage.chocolandiadc.com and verify your service appears with correct status.

## Widget Configuration

Homepage supports various widget types. See [WIDGETS.md](./WIDGETS.md) for detailed examples.

### Available Widget Types

1. **Kubernetes**: Pod status, resource usage, metrics
2. **ArgoCD**: Application sync status, health
3. **Traefik**: Request metrics (via Prometheus)
4. **Custom**: External APIs, scripts, webhooks

Example Kubernetes widget:

```yaml
widget:
  type: kubernetes
  cluster: default
  namespace: traefik
  app: traefik
  podSelector: app.kubernetes.io/name=traefik
```

## Credential Management

### ArgoCD Token Rotation

The Homepage dashboard uses an ArgoCD JWT token to query application status. To rotate:

1. Generate new token in ArgoCD UI (Settings → Accounts → homepage → Tokens)
2. Update Secret in cluster:

```bash
export KUBECONFIG=/path/to/kubeconfig
kubectl create secret generic homepage-widgets \
  --from-literal=HOMEPAGE_VAR_ARGOCD_TOKEN="NEW_TOKEN_HERE" \
  -n homepage \
  --dry-run=client -o yaml | kubectl apply -f -
```

3. Restart Homepage pod to pick up new token:

```bash
kubectl rollout restart deployment/homepage -n homepage
```

**⚠️ Note**: Do NOT commit real tokens to Git. The token in `secret.yaml` should remain a placeholder.

### GitHub PAT for ArgoCD

ArgoCD uses a GitHub Personal Access Token to pull from the chocolandia_kube repository.

To rotate the GitHub PAT:

1. Create new PAT in GitHub (Settings → Developer settings → Personal access tokens)
   - Scopes needed: `repo` (full control of private repositories)
2. Update ArgoCD repository Secret:

```bash
kubectl patch secret chocolandia-kube-repo -n argocd \
  -p '{"stringData":{"password":"NEW_GITHUB_PAT_HERE"}}'
```

3. Verify ArgoCD can authenticate:

```bash
kubectl get applications homepage -n argocd
# Should show "Synced" status
```

## Backup Procedures

### Configuration Backup

All Homepage configuration is stored in Git, providing automatic version control and backup. To create a point-in-time backup:

```bash
# Export all Homepage Kubernetes resources
kubectl get all,configmaps,secrets,ingress,serviceaccounts,roles,rolebindings \
  -n homepage -o yaml > homepage-backup-$(date +%Y%m%d).yaml

# Export ArgoCD Application definition
kubectl get application homepage -n argocd -o yaml > homepage-argocd-backup-$(date +%Y%m%d).yaml
```

### Disaster Recovery

To restore Homepage from backup:

1. **Restore from Git** (preferred):

```bash
# ArgoCD will automatically sync from Git
kubectl get application homepage -n argocd

# If Application doesn't exist, recreate:
kubectl apply -f kubernetes/argocd/applications/homepage.yaml
```

2. **Restore from backup file** (if Git unavailable):

```bash
kubectl apply -f homepage-backup-20250113.yaml
kubectl apply -f homepage-argocd-backup-20250113.yaml
```

### Backup Schedule Recommendation

- **Git commits**: Automatic backup on every change
- **Manual backups**: Monthly exports for offline recovery
- **ArgoCD repository**: Ensure GitHub repository has regular backups

## Monitoring & Alerting

### Prometheus Metrics

Homepage exposes basic HTTP metrics via the application endpoint. To scrape with Prometheus:

1. Add ServiceMonitor (if using Prometheus Operator):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: homepage
  namespace: homepage
spec:
  selector:
    matchLabels:
      app: homepage
  endpoints:
    - port: http
      interval: 30s
```

2. Create Grafana dashboard for Homepage metrics:
   - HTTP request rates
   - Response times
   - Pod CPU/Memory usage
   - Widget refresh latency

### Recommended Alerts

1. **Homepage Pod Down**: Alert if homepage pod is not Running
2. **High Memory Usage**: Alert if homepage pod exceeds 200Mi RAM
3. **ArgoCD Sync Failure**: Alert if Homepage Application shows "OutOfSync" for > 10 minutes
4. **Certificate Expiry**: Alert if homepage.chocolandiadc.com certificate expires in < 14 days

Example Prometheus alert rule:

```yaml
- alert: HomepagePodDown
  expr: kube_pod_status_phase{namespace="homepage", pod=~"homepage-.*", phase!="Running"} == 1
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Homepage dashboard pod is down"
    description: "Homepage pod {{ $labels.pod }} has been down for more than 5 minutes."
```

## Troubleshooting

For common issues and solutions, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

Quick checks:

1. **Dashboard not loading**: Check pod status `kubectl get pods -n homepage`
2. **Service not appearing**: Verify RBAC permissions for service namespace
3. **Widget showing error**: Check ServiceAccount token and widget configuration
4. **ArgoCD not syncing**: Verify GitHub token in ArgoCD repository Secret

## Directory Structure

```
kubernetes/homepage/
├── README.md              # This file - main documentation
├── TROUBLESHOOTING.md     # Common issues and solutions
├── WIDGETS.md             # Widget configuration examples
├── RBAC.md                # RBAC permissions explanation
├── namespace.yaml         # Homepage namespace definition
├── rbac.yaml              # ServiceAccount, Roles, ClusterRole, Bindings
├── configmaps.yaml        # Four ConfigMaps (services, widgets, settings, kubernetes)
├── secret.yaml            # ArgoCD token (placeholder - update in cluster)
├── deployment.yaml        # Deployment + Service
└── ingress.yaml           # Traefik IngressRoute with Let's Encrypt TLS
```

## External Links

- **Homepage Documentation**: https://gethomepage.dev/
- **Dashboard Icons**: https://github.com/walkxcode/dashboard-icons
- **Widget Configuration**: https://gethomepage.dev/en/widgets/
- **Kubernetes Widget**: https://gethomepage.dev/en/widgets/services/kubernetes/
- **ArgoCD Widget**: https://gethomepage.dev/en/widgets/services/argocd/

## Version History

- **v1.0.0** (2025-01-13): Initial GitOps deployment
  - Migrated from Terraform module to pure YAML manifests
  - ArgoCD automated sync enabled
  - Full Kubernetes integration with metrics-server
  - ArgoCD widget with JWT authentication
  - Cloudflare Zero Trust with Google OAuth
  - 6 monitored namespaces (traefik, cert-manager, argocd, headlamp, homepage, monitoring)
