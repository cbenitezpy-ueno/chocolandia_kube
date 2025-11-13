# ArgoCD Applications

This directory contains ArgoCD Application manifests for managing deployments via GitOps.

## Contents

- **chocolandia-kube.yaml**: Infrastructure Application managing chocolandia_kube resources
- **web-app-template.yaml**: Reusable template for deploying web applications

## Web Application Template

The `web-app-template.yaml` provides a ready-to-use ArgoCD Application manifest for deploying web projects to the K3s cluster.

### Prerequisites

Before using the template, ensure:

1. **GitHub Repository**: Your web project is hosted on GitHub with Kubernetes manifests
   - Repository structure should include a directory with K8s resources (Deployment, Service, Ingress, ConfigMap, etc.)
   - Example structure:
     ```
     my-web-app/
     ├── kubernetes/
     │   ├── deployment.yaml
     │   ├── service.yaml
     │   └── ingress.yaml
     └── src/
         └── (application code)
     ```

2. **GitHub Access**: Repository is either public or private with credentials configured
   - For private repos: ArgoCD must have a Secret with GitHub Personal Access Token (PAT)
   - Credentials configured in ArgoCD via terraform/modules/argocd/github-credentials.tf

3. **Kubernetes Manifests**: Your repository contains valid Kubernetes YAML files
   - Files must be in the path specified by TARGET_PATH placeholder
   - Manifests should be compatible with K3s (avoid cloud-specific features)

4. **ArgoCD Deployed**: ArgoCD is installed and accessible in the cluster
   - Verify: `kubectl get pods -n argocd`

### Quick Start

#### Step 1: Copy Template

```bash
cd kubernetes/argocd/applications/
cp web-app-template.yaml my-app.yaml
```

#### Step 2: Replace Placeholders

Edit `my-app.yaml` and replace the 4 placeholders:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `APP_NAME` | Application name (lowercase, no spaces) | `portfolio-app` |
| `REPO_URL` | GitHub repository URL | `https://github.com/username/my-portfolio` |
| `TARGET_PATH` | Path to Kubernetes manifests in repo | `kubernetes/` |
| `NAMESPACE` | Target Kubernetes namespace | `web-apps` |

**Example replacement:**

```yaml
# Before:
metadata:
  name: APP_NAME
source:
  repoURL: REPO_URL
  path: TARGET_PATH
destination:
  namespace: NAMESPACE

# After:
metadata:
  name: portfolio-app
source:
  repoURL: https://github.com/cbenitez/my-portfolio
  path: kubernetes/
destination:
  namespace: web-apps
```

#### Step 3: Apply Application

```bash
kubectl apply -f my-app.yaml
```

**Expected output:**
```
application.argoproj.io/portfolio-app created
```

#### Step 4: Verify Application

```bash
# Check Application created
kubectl get application -n argocd portfolio-app

# Get Application details
argocd app get portfolio-app
```

**Expected status:**
- **Sync Status**: OutOfSync (before first sync)
- **Health Status**: Unknown (before first sync)

#### Step 5: Manual Sync (First Time)

```bash
# Sync via CLI
argocd app sync portfolio-app

# OR via ArgoCD UI:
# 1. Navigate to https://argocd.chocolandiadc.com
# 2. Click on your application
# 3. Click "SYNC" button → "SYNCHRONIZE"
```

**Expected result:**
- Sync Status: Synced
- Health Status: Healthy
- All resources deployed to target namespace

#### Step 6: Verify Deployment

```bash
# Check deployed resources
kubectl get all -n web-apps

# Expected output:
# - Pods: Running
# - Services: ClusterIP/NodePort/LoadBalancer
# - Ingress: (if configured)
```

#### Step 7: Enable Auto-Sync (Optional)

After validating your application works correctly, enable automatic synchronization:

1. Edit your Application manifest (`my-app.yaml`)
2. Uncomment the `automated:` section:

```yaml
syncPolicy:
  automated:
    prune: true       # Delete resources no longer in Git
    selfHeal: true    # Revert manual changes
    allowEmpty: false # Prevent accidental deletion
```

3. Apply changes:

```bash
kubectl apply -f my-app.yaml
```

4. Verify auto-sync enabled:

```bash
argocd app get portfolio-app | grep -A 3 "Sync Policy"

# Expected output:
# Sync Policy:     Automated (Prune)
# Self Heal:       Enabled
```

### Example: Portfolio App Deployment

Complete example for deploying a portfolio web application:

**Repository**: `https://github.com/cbenitez/my-portfolio`

**Repository structure:**
```
my-portfolio/
├── kubernetes/
│   ├── deployment.yaml      # Frontend deployment (nginx)
│   ├── service.yaml          # ClusterIP service
│   └── ingress.yaml          # Traefik IngressRoute (portfolio.chocolandiadc.com)
├── src/
│   └── (React application code)
└── Dockerfile
```

**Application manifest (portfolio-app.yaml):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portfolio-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/cbenitez/my-portfolio
    targetRevision: main
    path: kubernetes/

  destination:
    server: https://kubernetes.default.svc
    namespace: web-apps

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Deployment commands:**

```bash
# Apply Application
kubectl apply -f portfolio-app.yaml

# Sync (first time)
argocd app sync portfolio-app

# Verify deployment
kubectl get all -n web-apps
kubectl get ingress -n web-apps

# Access application
# https://portfolio.chocolandiadc.com
```

### Auto-Sync Behavior

When auto-sync is enabled:

1. **Change Detection**: ArgoCD polls GitHub every 3 minutes (default)
2. **Automatic Sync**: Detects changes and automatically applies them to the cluster
3. **Self-Heal**: Reverts manual changes (e.g., `kubectl scale`, `kubectl edit`) to match Git state
4. **Prune**: Deletes resources removed from Git

**Example workflow:**

```bash
# Developer pushes changes to main branch
git add kubernetes/deployment.yaml
git commit -m "feat: Update deployment replicas"
git push origin main

# ArgoCD detects changes (within 3 minutes)
# ArgoCD automatically syncs changes to cluster
# Application status: Synced + Healthy

# No manual intervention required!
```

### Troubleshooting

#### Application OutOfSync

**Issue**: Application shows OutOfSync status

**Solutions**:
1. Check Git repository connectivity: `argocd repo list`
2. Verify target path exists in repo
3. Manual sync to see detailed errors: `argocd app sync <app-name>`
4. Check Application events: `kubectl describe application -n argocd <app-name>`

#### Sync Failed

**Issue**: Sync operation fails with errors

**Solutions**:
1. Check manifest validity: `kubectl apply --dry-run=client -f <manifest>`
2. Review sync errors in ArgoCD UI or CLI: `argocd app get <app-name>`
3. Check resource quotas in target namespace: `kubectl describe ns <namespace>`
4. Verify RBAC permissions for ArgoCD service account

#### Health Status Degraded

**Issue**: Application synced but health status is Degraded or Progressing

**Solutions**:
1. Check pod status: `kubectl get pods -n <namespace>`
2. Check pod logs: `kubectl logs -n <namespace> <pod-name>`
3. Check events: `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`
4. Common issues:
   - ImagePullBackOff: Image doesn't exist or credentials missing
   - CrashLoopBackOff: Application crashes on startup
   - Pending: Insufficient resources or PVC mount issues

#### Auto-Sync Not Triggering

**Issue**: Changes pushed to Git but ArgoCD doesn't sync

**Solutions**:
1. Verify auto-sync enabled: `argocd app get <app-name> | grep "Sync Policy"`
2. Check repository polling: ArgoCD polls every 3 minutes (default)
3. Force refresh: `argocd app get <app-name> --refresh`
4. Check ArgoCD repo-server logs: `kubectl logs -n argocd deployment/argocd-repo-server`

### Best Practices

1. **Start with Manual Sync**: Test your application with manual sync first before enabling auto-sync
2. **Use Separate Namespaces**: Deploy each application to its own namespace for isolation
3. **Git Branch Strategy**: Use feature branches for development, main/production for deployments
4. **Resource Limits**: Always set resource requests and limits in Deployment manifests
5. **Health Checks**: Configure liveness and readiness probes for all applications
6. **Ingress Configuration**: Use Traefik IngressRoute for HTTPS access via cert-manager
7. **Monitoring**: Add Prometheus ServiceMonitor for metrics collection
8. **Secrets Management**: Never commit secrets to Git; use Kubernetes Secrets or external secret managers

### Advanced Configuration

#### Multi-Environment Deployments

Deploy same application to different environments:

```yaml
# production-app.yaml
destination:
  namespace: production
source:
  targetRevision: main

# staging-app.yaml
destination:
  namespace: staging
source:
  targetRevision: develop
```

#### Helm-Based Applications

For Helm charts instead of plain manifests:

```yaml
source:
  repoURL: https://github.com/username/my-helm-app
  targetRevision: main
  path: charts/myapp
  helm:
    valueFiles:
      - values.yaml
    parameters:
      - name: replicas
        value: "3"
```

#### Kustomize-Based Applications

For Kustomize overlays:

```yaml
source:
  repoURL: https://github.com/username/my-kustomize-app
  targetRevision: main
  path: overlays/production
```

### Related Documentation

- [ArgoCD Applications Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
- [ArgoCD Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [ArgoCD Health Assessment](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/)

### Support

For issues or questions:
- Check ArgoCD UI: https://argocd.chocolandiadc.com
- View logs: `kubectl logs -n argocd deployment/argocd-server`
- Get application status: `argocd app get <app-name>`
