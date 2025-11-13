# Homepage Dashboard Troubleshooting Guide

Common issues and solutions for Homepage dashboard in chocolandiadc K3s cluster.

## Table of Contents

- [Dashboard Not Loading](#dashboard-not-loading)
- [Services Not Appearing](#services-not-appearing)
- [Widgets Showing Errors](#widgets-showing-errors)
- [Authentication Issues](#authentication-issues)
- [ArgoCD Sync Problems](#argocd-sync-problems)
- [Performance Issues](#performance-issues)
- [RBAC Permission Errors](#rbac-permission-errors)

---

## Dashboard Not Loading

### Symptom
Homepage dashboard (homepage.chocolandiadc.com) returns 502/503 error or times out.

### Quick Checks

```bash
export KUBECONFIG=/path/to/kubeconfig

# 1. Check pod status
kubectl get pods -n homepage

# 2. Check pod logs
kubectl logs -n homepage deployment/homepage --tail=50

# 3. Check service endpoints
kubectl get endpoints -n homepage

# 4. Check ingress
kubectl get ingress -n homepage
```

### Common Causes & Solutions

#### 1. Pod CrashLoopBackOff

**Cause**: Configuration error in ConfigMaps or missing Secret.

**Solution**:
```bash
# Check pod events
kubectl describe pod -n homepage -l app=homepage

# Verify ConfigMaps exist
kubectl get configmaps -n homepage

# Verify Secret exists
kubectl get secret homepage-widgets -n homepage

# Check logs for specific error
kubectl logs -n homepage -l app=homepage --previous
```

#### 2. Service Not Routing to Pod

**Cause**: Pod selector mismatch or service misconfiguration.

**Solution**:
```bash
# Verify service selector matches pod labels
kubectl get service homepage -n homepage -o yaml | grep -A 3 selector
kubectl get pods -n homepage --show-labels

# Test direct pod access
kubectl port-forward -n homepage deployment/homepage 8080:3000
# Then open http://localhost:8080
```

#### 3. Ingress Misconfiguration

**Cause**: Traefik can't route to service or certificate issue.

**Solution**:
```bash
# Check ingress details
kubectl describe ingress homepage -n homepage

# Verify certificate is ready
kubectl get certificate -n homepage

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=100 | grep homepage
```

#### 4. Cloudflare Tunnel Down

**Cause**: cloudflared pods not running or tunnel misconfiguration.

**Solution**:
```bash
# Check cloudflared pods
kubectl get pods -n cert-manager -l app=cloudflare-tunnel

# Check tunnel logs
kubectl logs -n cert-manager -l app=cloudflare-tunnel --tail=50

# Verify Cloudflare Access Application exists in dashboard
```

---

## Services Not Appearing

### Symptom
Some services don't show up in the Homepage dashboard or show as "Unknown".

### Quick Checks

```bash
# 1. Verify service exists in ConfigMap
kubectl get configmap homepage-services -n homepage -o yaml | grep -A 5 "ServiceName"

# 2. Check RBAC permissions for service namespace
kubectl auth can-i list pods --namespace=target-namespace --as=system:serviceaccount:homepage:homepage

# 3. Verify pods exist in target namespace
kubectl get pods -n target-namespace
```

### Common Causes & Solutions

#### 1. Missing RBAC Permissions

**Cause**: Homepage ServiceAccount doesn't have permission to query target namespace.

**Solution**:
```bash
# Check if Role exists for namespace
kubectl get role homepage-viewer -n target-namespace

# If missing, add namespace to monitored_namespaces in rbac.yaml:
# 1. Edit rbac.yaml
# 2. Update Role and RoleBinding for_each to include new namespace
# 3. Commit and push (GitOps will sync)

# Or add manually for testing:
kubectl create role homepage-viewer \
  --verb=get,list,watch \
  --resource=services,pods,deployments \
  -n target-namespace

kubectl create rolebinding homepage-viewer \
  --role=homepage-viewer \
  --serviceaccount=homepage:homepage \
  -n target-namespace
```

#### 2. Incorrect podSelector

**Cause**: Widget podSelector doesn't match actual pod labels.

**Solution**:
```bash
# Check actual pod labels
kubectl get pods -n target-namespace --show-labels

# Compare with podSelector in services.yaml
kubectl get configmap homepage-services -n homepage -o yaml | grep -A 2 podSelector

# Update podSelector in configmaps.yaml to match actual labels
# Example: If pods have label app.kubernetes.io/name=myapp, use:
#   podSelector: app.kubernetes.io/name=myapp
```

#### 3. Service Namespace Mismatch

**Cause**: Service defined in wrong namespace in services.yaml.

**Solution**:
```bash
# Verify correct namespace
kubectl get pods -n correct-namespace

# Update namespace in configmaps.yaml:
# widget:
#   type: kubernetes
#   namespace: correct-namespace  # Fix this
```

---

## Widgets Showing Errors

### Symptom
Kubernetes or ArgoCD widgets display error messages like "Permission denied" or "Authentication required".

### ArgoCD Widget Errors

#### Error: "Authentication required" or "401 Unauthorized"

**Cause**: Invalid or expired ArgoCD JWT token.

**Solution**:
```bash
# 1. Generate new token in ArgoCD UI
# Settings → Accounts → homepage → Tokens → Generate New

# 2. Update Secret
kubectl create secret generic homepage-widgets \
  --from-literal=HOMEPAGE_VAR_ARGOCD_TOKEN="NEW_TOKEN_HERE" \
  -n homepage \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Restart Homepage
kubectl rollout restart deployment/homepage -n homepage

# 4. Verify widget works
kubectl logs -n homepage -l app=homepage --tail=20 | grep argocd
```

#### Error: "URL not reachable" for ArgoCD widget

**Cause**: Incorrect ArgoCD service URL.

**Solution**:
```bash
# Verify ArgoCD service exists and is ClusterIP
kubectl get service argocd-server -n argocd

# Correct URL format (in configmaps.yaml):
# widget:
#   type: argocd
#   url: http://argocd-server.argocd.svc.cluster.local:80
#   key: {{HOMEPAGE_VAR_ARGOCD_TOKEN}}
```

### Kubernetes Widget Errors

#### Error: "Forbidden" or "403" accessing pods/metrics

**Cause**: Missing metrics-server or insufficient RBAC permissions.

**Solution**:
```bash
# 1. Verify metrics-server is installed
kubectl get deployment metrics-server -n kube-system

# 2. Verify Homepage can access metrics
kubectl auth can-i get pods.metrics.k8s.io \
  --as=system:serviceaccount:homepage:homepage

# 3. If missing, add to rbac.yaml ClusterRole:
# - apiGroups: ["metrics.k8s.io"]
#   resources: ["nodes", "pods"]
#   verbs: ["get", "list"]
```

---

## Authentication Issues

### Symptom
Cannot access homepage.chocolandiadc.com or getting "Access Denied" from Cloudflare.

### Quick Checks

```bash
# 1. Verify Cloudflare Access Application exists
# Check in Cloudflare dashboard → Zero Trust → Access → Applications

# 2. Verify user email is in authorized list
# Check Access Application → Policies → Allowed emails

# 3. Test certificate
openssl s_client -connect homepage.chocolandiadc.com:443 -servername homepage.chocolandiadc.com
```

### Common Causes & Solutions

#### 1. User Email Not Authorized

**Cause**: User's Google email not in Cloudflare Access allowed list.

**Solution**:
- Add email to `authorized_emails` variable in terraform/environments/chocolandiadc-mvp/terraform.tfvars
- Run `tofu apply` to update Cloudflare Access Application
- User must log out and re-authenticate

#### 2. Google OAuth IDP Misconfigured

**Cause**: Incorrect Google OAuth client ID or callback URL.

**Solution**:
```bash
# Verify OAuth IDP ID in terraform.tfvars matches Cloudflare
# Google OAuth redirect URI must be:
# https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/callback

# Update in Google Cloud Console if needed
```

#### 3. Certificate Not Valid

**Cause**: Let's Encrypt certificate expired or not issued.

**Solution**:
```bash
# Check certificate status
kubectl describe certificate homepage -n homepage

# If not ready, check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager --tail=50 | grep homepage

# Manually trigger certificate renewal
kubectl delete certificate homepage -n homepage
# ArgoCD will recreate from Git
```

---

## ArgoCD Sync Problems

### Symptom
ArgoCD Application shows "OutOfSync" or "Unknown" status.

### Quick Checks

```bash
# 1. Check Application status
kubectl get application homepage -n argocd

# 2. Check Application details
kubectl describe application homepage -n argocd

# 3. View sync errors
kubectl get application homepage -n argocd -o jsonpath='{.status.conditions[*].message}'
```

### Common Causes & Solutions

#### 1. GitHub Authentication Failed

**Cause**: Invalid or expired GitHub PAT in repository Secret.

**Solution**:
```bash
# Generate new GitHub PAT (repo scope)
# Then update Secret:
kubectl patch secret chocolandia-kube-repo -n argocd \
  -p '{"stringData":{"password":"NEW_GITHUB_PAT"}}'

# Force refresh
kubectl delete pod -n argocd -l app.kubernetes.io/component=repo-server
```

#### 2. YAML Syntax Error

**Cause**: Invalid YAML in kubernetes/homepage/ files.

**Solution**:
```bash
# Validate YAML locally before committing
kubectl apply --dry-run=client -f kubernetes/homepage/

# Check ArgoCD Application events
kubectl describe application homepage -n argocd
```

#### 3. Resource Conflict

**Cause**: Resource already exists outside ArgoCD management.

**Solution**:
```bash
# If resource was created manually, delete it
kubectl delete <resource-type> <resource-name> -n homepage

# ArgoCD will recreate from Git
kubectl patch application homepage -n argocd --type merge \
  -p '{"operation":{"sync":{}}}'
```

#### 4. Prune Disabled

**Cause**: Old resources not being deleted when removed from Git.

**Solution**:
```bash
# Verify prune is enabled in Application
kubectl get application homepage -n argocd -o jsonpath='{.spec.syncPolicy.automated.prune}'
# Should output: true

# If false, update kubernetes/argocd/applications/homepage.yaml:
# syncPolicy:
#   automated:
#     prune: true
```

---

## Performance Issues

### Symptom
Homepage dashboard slow to load or widgets take long to refresh.

### Quick Checks

```bash
# 1. Check pod resource usage
kubectl top pod -n homepage

# 2. Check pod events
kubectl describe pod -n homepage -l app=homepage

# 3. Check logs for slow queries
kubectl logs -n homepage -l app=homepage --tail=100 | grep -i "slow\|timeout\|error"
```

### Common Causes & Solutions

#### 1. Insufficient Resources

**Cause**: Pod hitting CPU or memory limits.

**Solution**:
```bash
# Check current resource usage
kubectl top pod -n homepage

# If consistently hitting limits, increase in deployment.yaml:
# resources:
#   requests:
#     cpu: "200m"      # Increase from 100m
#     memory: "256Mi"  # Increase from 128Mi
#   limits:
#     cpu: "400m"      # Increase from 200m
#     memory: "512Mi"  # Increase from 256Mi
```

#### 2. Too Many Widgets

**Cause**: Querying too many services/widgets simultaneously.

**Solution**:
- Reduce number of widgets in widgets.yaml
- Increase widget refresh interval
- Remove unused services from services.yaml

#### 3. Slow Kubernetes API Queries

**Cause**: Cluster under heavy load or too many pods being queried.

**Solution**:
```bash
# Reduce podSelector scope to specific labels
# Instead of querying all pods:
# podSelector: ""
# Use specific selector:
# podSelector: app.kubernetes.io/name=traefik
```

---

## RBAC Permission Errors

### Symptom
Widgets show "Forbidden" or logs show "User 'system:serviceaccount:homepage:homepage' cannot..."

### Quick Checks

```bash
# Test specific permission
kubectl auth can-i <verb> <resource> \
  --namespace=<namespace> \
  --as=system:serviceaccount:homepage:homepage

# Examples:
kubectl auth can-i list pods --namespace=traefik --as=system:serviceaccount:homepage:homepage
kubectl auth can-i get deployments.apps --namespace=argocd --as=system:serviceaccount:homepage:homepage
```

### Common Causes & Solutions

#### 1. Missing Namespace in RBAC

**Cause**: Namespace not in monitored_namespaces.

**Solution**:
Add namespace to rbac.yaml and create Role + RoleBinding for it.

#### 2. Missing API Group Permission

**Cause**: Permission granted for wrong API group.

**Solution**:
```yaml
# Example: For cert-manager Certificates (CRD):
rule:
  - apiGroups: ["cert-manager.io"]  # Must specify CRD API group
    resources: ["certificates"]
    verbs: ["get", "list", "watch"]
```

#### 3. Missing Resource in Role

**Cause**: Required resource not in Role permissions.

**Solution**:
```bash
# Identify missing resource
kubectl logs -n homepage -l app=homepage | grep -i "forbidden"

# Add resource to rbac.yaml Role:
# - apiGroups: ["apps"]
#   resources: ["statefulsets"]  # Add missing resource
#   verbs: ["get", "list", "watch"]
```

---

## Advanced Debugging

### Enable Debug Logging

Edit `deployment.yaml` to add debug environment variable:

```yaml
env:
  - name: LOG_LEVEL
    value: "debug"
```

Commit, push, wait for ArgoCD sync.

### Direct Container Access

```bash
# Execute shell in Homepage container
kubectl exec -it -n homepage deployment/homepage -- sh

# Test internal connectivity
wget -O- http://argocd-server.argocd.svc.cluster.local:80/api/version

# Check configuration files
cat /app/config/services.yaml
cat /app/config/widgets.yaml
```

### Check All Related Resources

```bash
# Complete Homepage status check
echo "=== Pods ===" && kubectl get pods -n homepage
echo "=== Services ===" && kubectl get services -n homepage
echo "=== Ingress ===" && kubectl get ingress -n homepage
echo "=== ConfigMaps ===" && kubectl get configmaps -n homepage
echo "=== Secrets ===" && kubectl get secrets -n homepage
echo "=== ServiceAccount ===" && kubectl get serviceaccount -n homepage
echo "=== ArgoCD Application ===" && kubectl get application homepage -n argocd
```

---

## Getting Help

If the above solutions don't resolve your issue:

1. **Gather diagnostic information**:
   ```bash
   kubectl describe pod -n homepage -l app=homepage > homepage-pod-describe.txt
   kubectl logs -n homepage -l app=homepage --tail=200 > homepage-logs.txt
   kubectl get application homepage -n argocd -o yaml > homepage-argocd-app.yaml
   ```

2. **Check Homepage GitHub Issues**: https://github.com/gethomepage/homepage/issues

3. **Review Homepage Documentation**: https://gethomepage.dev/

4. **Check Kubernetes cluster health**:
   ```bash
   kubectl get nodes
   kubectl top nodes
   kubectl get pods --all-namespaces | grep -v Running
   ```
