# QuickStart Guide: ArgoCD GitOps Deployment

**Feature**: 008-gitops-argocd
**Target**: K3s cluster chocolandiadc-mvp (master1 + nodo1)
**Time Estimate**: 20-30 minutes

## Prerequisites

### Required Tools
- [x] OpenTofu 1.6+ installed (`tofu version`)
- [x] kubectl configured with cluster access (`kubectl cluster-info`)
- [x] Helm 3.0+ installed (`helm version`)
- [x] ArgoCD CLI installed (`argocd version` - optional but recommended)

### Cluster Requirements
- [x] K3s v1.28+ cluster running (2 nodes: master1 + nodo1)
- [x] Traefik ingress controller deployed (Feature 005)
- [x] cert-manager deployed (Feature 006)
- [x] Cloudflare Zero Trust tunnel configured (Feature 004)
- [x] Prometheus + Grafana stack deployed (kube-prometheus-stack)

### Configuration Requirements
- [x] GitHub Personal Access Token with `repo` scope (in ~/.env or terraform.tfvars)
- [x] Cloudflare API token with DNS edit permissions
- [x] Google OAuth credentials configured (for Cloudflare Access)

---

## Phase 1: Deploy ArgoCD Infrastructure

### Step 1.1: Configure ArgoCD Module Variables

Edit `terraform/environments/chocolandiadc-mvp/terraform.tfvars`:

```hcl
# ArgoCD Configuration
argocd_domain = "argocd.chocolandiadc.com"

# GitHub repository credentials
github_token = "ghp_xxxxxxxxxxxxxxxxxxxxx"  # Your GitHub PAT

# ArgoCD authorized users (same as Cloudflare Access)
argocd_authorized_emails = [
  "cbenitez@gmail.com",
  # Add additional emails here
]

# ArgoCD configuration (optional overrides)
argocd_enable_prometheus_metrics = true
argocd_cluster_issuer           = "letsencrypt-production"
```

### Step 1.2: Validate OpenTofu Configuration

```bash
cd terraform/environments/chocolandiadc-mvp

# Format HCL files
tofu fmt

# Validate configuration
tofu validate

# Review planned changes
tofu plan -target=module.argocd
```

**Expected output**: Plan should show:
- Helm release: `argocd` in `argocd` namespace
- Kubernetes Secret: `chocolandia-kube-repo` (GitHub credentials)
- Traefik IngressRoute: `argocd-server`
- cert-manager Certificate: `argocd-tls`
- Cloudflare Access Application: `ArgoCD GitOps Dashboard`
- Cloudflare Access Policy: `ArgoCD Authorized Users`
- ServiceMonitor: `argocd-metrics` (if Prometheus enabled)

### Step 1.3: Deploy ArgoCD

```bash
# Apply ArgoCD module
tofu apply -target=module.argocd

# Confirm when prompted (review output carefully)
# This will take 2-3 minutes
```

### Step 1.4: Verify ArgoCD Deployment

```bash
# Check namespace created
kubectl get namespace argocd

# Check all pods Running
kubectl get pods -n argocd

# Expected pods (may take 1-2 minutes to reach Running):
# - argocd-server-xxxxxxxxxx-xxxxx
# - argocd-repo-server-xxxxxxxxxx-xxxxx
# - argocd-application-controller-xxxxxxxxxx-xxxxx
# - argocd-redis-xxxxxxxxxx-xxxxx

# Wait for all pods to be Ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Check services
kubectl get svc -n argocd
# Expected: argocd-server (ClusterIP or LoadBalancer)
```

**Troubleshooting**: If pods crash or stay in Pending:
- Check logs: `kubectl logs -n argocd <pod-name>`
- Check events: `kubectl get events -n argocd --sort-by='.lastTimestamp'`
- Verify resource availability: `kubectl top nodes`

---

## Phase 2: Configure ArgoCD Access

### Step 2.1: Verify TLS Certificate Issued

```bash
# Check Certificate status
kubectl get certificate -n argocd argocd-tls

# Expected output:
# NAME         READY   SECRET        AGE
# argocd-tls   True    argocd-tls    5m

# If READY=False, check cert-manager logs:
kubectl logs -n cert-manager deployment/cert-manager -f

# Verify TLS Secret created
kubectl get secret -n argocd argocd-tls
```

### Step 2.2: Verify Traefik IngressRoute

```bash
# Check IngressRoute created
kubectl get ingressroute -n argocd argocd-server

# Test HTTPS access (from localhost or jump host)
curl -I https://argocd.chocolandiadc.com

# Expected: HTTP/2 200 (or 302 redirect to Cloudflare Access)
```

### Step 2.3: Verify Cloudflare Access Policy

```bash
# Test unauthenticated access
curl https://argocd.chocolandiadc.com

# Expected: Cloudflare Access login page (HTML with Google OAuth button)

# Access ArgoCD UI via browser:
# 1. Navigate to https://argocd.chocolandiadc.com
# 2. Cloudflare Access should redirect to Google OAuth
# 3. Authenticate with authorized email (cbenitez@gmail.com)
# 4. Should redirect to ArgoCD login page
```

### Step 2.4: Get ArgoCD Admin Password

```bash
# Extract initial admin password from Secret
kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Save password for next step
```

### Step 2.5: Login to ArgoCD Web UI

1. **Navigate to**: https://argocd.chocolandiadc.com
2. **Authenticate** via Cloudflare Access (Google OAuth)
3. **ArgoCD Login**:
   - Username: `admin`
   - Password: (from Step 2.4)
4. **Verify Dashboard**: Should show empty applications list

---

## Phase 3: Deploy chocolandia_kube Application

### Step 3.1: Create ArgoCD Application Manifest

Create `kubernetes/argocd/applications/chocolandia-kube.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: chocolandia-kube
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/cbenitez/chocolandia_kube
    targetRevision: main
    path: kubernetes/argocd/applications

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated: null  # Manual sync initially
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

### Step 3.2: Apply Application Manifest

```bash
# Apply ArgoCD Application
kubectl apply -f kubernetes/argocd/applications/chocolandia-kube.yaml

# Verify Application created
kubectl get application -n argocd

# Expected output:
# NAME                SYNC STATUS   HEALTH STATUS
# chocolandia-kube    OutOfSync     Unknown

# Check Application details
kubectl describe application -n argocd chocolandia-kube
```

### Step 3.3: Manual Sync (First Time)

**Via ArgoCD Web UI**:
1. Navigate to https://argocd.chocolandiadc.com
2. Click on `chocolandia-kube` Application
3. Click **SYNC** button → **SYNCHRONIZE**
4. Wait for sync to complete (1-3 minutes)
5. Verify Application status: **Synced** + **Healthy**

**Via ArgoCD CLI** (Alternative):
```bash
# Login to ArgoCD CLI
argocd login argocd.chocolandiadc.com \
  --username admin \
  --password <admin-password> \
  --grpc-web

# Sync Application
argocd app sync chocolandia-kube

# Watch sync progress
argocd app wait chocolandia-kube --health

# Check Application status
argocd app get chocolandia-kube
```

**Via kubectl** (Alternative):
```bash
# Trigger sync by patching Application
kubectl patch application chocolandia-kube -n argocd \
  --type merge \
  -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {}}}'

# Watch sync status
kubectl get application -n argocd chocolandia-kube -w
```

### Step 3.4: Verify Sync Success

```bash
# Check Application status
kubectl get application -n argocd chocolandia-kube

# Expected:
# NAME                SYNC STATUS   HEALTH STATUS
# chocolandia-kube    Synced        Healthy

# Check synced resources
argocd app resources chocolandia-kube

# Verify resources deployed to cluster
kubectl get all -A | grep <resources-from-sync>
```

---

## Phase 4: Enable Auto-Sync (After Validation)

### Step 4.1: Update Application for Auto-Sync

Edit `kubernetes/argocd/applications/chocolandia-kube.yaml`:

```yaml
  syncPolicy:
    automated:
      prune: true       # Auto-delete resources removed from Git
      selfHeal: true    # Auto-revert manual changes
      allowEmpty: false # Prevent accidental deletion
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

### Step 4.2: Apply Updated Application

```bash
# Apply changes
kubectl apply -f kubernetes/argocd/applications/chocolandia-kube.yaml

# Verify auto-sync enabled
kubectl get application -n argocd chocolandia-kube -o yaml | grep -A 3 automated

# Expected output:
# automated:
#   prune: true
#   selfHeal: true
#   allowEmpty: false
```

### Step 4.3: Test Auto-Sync

**Test 1: Verify Change Detection**
```bash
# Make a test change in Git repository
# Example: Update README or add comment to a Kubernetes manifest
echo "# Test auto-sync" >> kubernetes/argocd/README.md
git add kubernetes/argocd/README.md
git commit -m "test: Verify ArgoCD auto-sync detection"
git push origin main

# Wait 3 minutes (polling interval)
# Check ArgoCD detected change
argocd app get chocolandia-kube

# Expected: Auto-sync should trigger within 3 minutes
```

**Test 2: Verify Self-Heal**
```bash
# Make manual change to cluster (simulate drift)
kubectl scale deployment <some-deployment> --replicas=5

# Wait for self-heal (should revert within 3 minutes)
# Check deployment replica count
kubectl get deployment <some-deployment>

# Expected: Replicas should revert to Git-defined value
```

---

## Phase 5: Configure Prometheus Monitoring

### Step 5.1: Verify ServiceMonitor Created

```bash
# Check ServiceMonitor exists
kubectl get servicemonitor -n argocd argocd-metrics

# Verify Prometheus scraping ArgoCD
kubectl get servicemonitor -n argocd argocd-metrics -o yaml
```

### Step 5.2: Verify Prometheus Targets

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser: http://localhost:9090/targets
# Search for "argocd"
# Expected: 3 targets (server, repo-server, controller) with state=UP
```

### Step 5.3: Query ArgoCD Metrics

```promql
# Prometheus queries to verify metrics:

# Total sync operations
argocd_app_sync_total

# Application health status (0-4 scale)
argocd_app_health_status

# Application sync status (0=Synced, 1=OutOfSync, 2=Unknown)
argocd_app_sync_status

# Git request duration
argocd_git_request_duration_seconds
```

### Step 5.4: Create Grafana Dashboard (Optional)

```bash
# Import ArgoCD dashboard to Grafana
# Dashboard ID: 14584 (official ArgoCD dashboard from Grafana.com)

# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open browser: http://localhost:3000
# Login: admin / <grafana-password>
# Import Dashboard: 14584
```

---

## Phase 6: Deploy Web Application (Template Test)

### Step 6.1: Prepare Web App Repository

**Prerequisites**: Web project repository with Kubernetes manifests
- Example: `github.com/cbenitez/portfolio`
- Manifests location: `kubernetes/` directory
- Required resources: Deployment, Service, Ingress/IngressRoute

### Step 6.2: Create Application from Template

```bash
# Copy template
cp kubernetes/argocd/applications/web-app-template.yaml \
   kubernetes/argocd/applications/portfolio-app.yaml

# Edit portfolio-app.yaml:
# - Replace APP_NAME with "portfolio-app"
# - Replace REPO_URL with "https://github.com/cbenitez/portfolio"
# - Replace TARGET_PATH with "kubernetes/"
# - Replace NAMESPACE with "web-apps"

# Apply Application
kubectl apply -f kubernetes/argocd/applications/portfolio-app.yaml

# Verify Application created
kubectl get application -n argocd portfolio-app

# Manual sync (first time)
argocd app sync portfolio-app

# Wait for sync + health check
argocd app wait portfolio-app --health
```

### Step 6.3: Enable Auto-Sync for Web App

```bash
# Edit portfolio-app.yaml (same as Phase 4)
# Add syncPolicy.automated section

# Apply changes
kubectl apply -f kubernetes/argocd/applications/portfolio-app.yaml

# Verify web app deployed
kubectl get all -n web-apps
```

---

## Validation Checklist

### ArgoCD Infrastructure
- [x] All ArgoCD pods Running (4 pods)
- [x] ArgoCD server accessible via HTTPS (argocd.chocolandiadc.com)
- [x] TLS certificate issued and valid (cert-manager)
- [x] Cloudflare Access protecting ArgoCD UI (Google OAuth)
- [x] Prometheus scraping ArgoCD metrics (3 targets UP)

### GitOps Workflow
- [x] chocolandia-kube Application created and synced
- [x] Auto-sync enabled and detecting Git changes (< 3min)
- [x] Self-heal reverting manual changes (< 3min)
- [x] Sync history visible in ArgoCD UI
- [x] Application health status: Healthy

### Web App Template
- [x] Template Application deploys successfully
- [x] Web app pods Running in target namespace
- [x] Web app accessible via ingress

---

## Troubleshooting

### Issue: ArgoCD pods not starting

**Symptoms**: Pods stuck in Pending or CrashLoopBackOff

**Solutions**:
```bash
# Check pod logs
kubectl logs -n argocd <pod-name>

# Check resource availability
kubectl top nodes
kubectl describe node <node-name>

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Restart pods if needed
kubectl rollout restart deployment -n argocd
```

### Issue: Application stuck in OutOfSync

**Symptoms**: Application shows OutOfSync but sync doesn't progress

**Solutions**:
```bash
# Check Application status details
argocd app get chocolandia-kube

# Check sync operation logs
argocd app logs chocolandia-kube

# Check if manifests are valid
kubectl apply --dry-run=client -f <manifest-file>

# Force refresh
argocd app get chocolandia-kube --refresh

# Manual sync with prune
argocd app sync chocolandia-kube --prune
```

### Issue: Cannot access ArgoCD UI

**Symptoms**: HTTPS timeout or 502/503 error

**Solutions**:
```bash
# Check IngressRoute
kubectl get ingressroute -n argocd argocd-server
kubectl describe ingressroute -n argocd argocd-server

# Check argocd-server service
kubectl get svc -n argocd argocd-server

# Check Cloudflare Access application
# Verify domain: argocd.chocolandiadc.com
# Verify policy: authorized emails

# Test direct access (bypass Cloudflare)
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Open: https://localhost:8080 (accept self-signed cert warning)
```

### Issue: Git repository authentication failed

**Symptoms**: "unable to connect to repository" error

**Solutions**:
```bash
# Verify GitHub token in Secret
kubectl get secret -n argocd chocolandia-kube-repo \
  -o jsonpath='{.data.password}' | base64 -d

# Test GitHub token manually
curl -H "Authorization: token $(kubectl get secret -n argocd chocolandia-kube-repo -o jsonpath='{.data.password}' | base64 -d)" \
  https://api.github.com/repos/cbenitez/chocolandia_kube

# Rotate token if expired
# 1. Generate new GitHub PAT
# 2. Update terraform.tfvars: github_token = "new-token"
# 3. Re-apply: tofu apply -target=module.argocd
```

### Issue: Auto-sync not detecting changes

**Symptoms**: Git changes not triggering sync after 3+ minutes

**Solutions**:
```bash
# Check Application polling configuration
kubectl get application -n argocd chocolandia-kube -o yaml | grep timeout

# Force refresh
argocd app get chocolandia-kube --refresh --hard-refresh

# Check argocd-application-controller logs
kubectl logs -n argocd deployment/argocd-application-controller -f

# Verify Git repository connectivity
kubectl exec -n argocd deployment/argocd-repo-server -- \
  git ls-remote https://github.com/cbenitez/chocolandia_kube
```

---

## Next Steps

1. **Explore ArgoCD UI**: Familiarize with application tree view, sync options, logs
2. **Create additional Applications**: Deploy more web projects using template
3. **Configure notifications** (optional): Slack/email alerts for sync events
4. **Implement pre-sync hooks** (optional): Run tests before applying changes
5. **Set up ArgoCD projects** (optional): Multi-tenant RBAC for team collaboration

---

## References

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://opengitops.dev/)
- [Traefik IngressRoute CRD](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
- [cert-manager Certificate CRD](https://cert-manager.io/docs/usage/certificate/)
