# Quickstart: Headlamp Web UI Deployment

**Feature**: 007-headlamp-web-ui
**Date**: 2025-11-12
**Estimated Time**: 20-30 minutes

## Prerequisites

Before deploying Headlamp, ensure you have:

✅ **Infrastructure**:
- K3s cluster v1.28+ running (Feature 001)
- Traefik v3.1.0 deployed (Feature 005)
- cert-manager v1.13.x deployed (Feature 006)
- Cloudflare Zero Trust configured (Feature 004)
- Prometheus + Grafana stack deployed

✅ **Tools**:
- OpenTofu 1.6+ installed
- kubectl configured for your cluster
- Helm 3.x (for chart management)
- Git (for repository operations)

✅ **Access**:
- Cloudflare account with DNS management
- Google Cloud Console access (for OAuth credentials)
- Kubernetes cluster admin access

✅ **DNS**:
- Domain `headlamp.chocolandiadc.com` pointing to cluster (Cloudflare Tunnel)

---

## Step 1: Clone Repository and Switch Branch

```bash
# Navigate to repository
cd /Users/cbenitez/chocolandia_kube

# Switch to feature branch
git checkout 007-headlamp-web-ui

# Verify branch
git status
# Should show: On branch 007-headlamp-web-ui
```

---

## Step 2: Configure Google OAuth (One-Time Setup)

If you haven't configured Google OAuth for Cloudflare Access yet:

1. **Go to Google Cloud Console**:
   ```
   https://console.cloud.google.com/apis/credentials
   ```

2. **Create OAuth 2.0 Client ID**:
   - Click "Create Credentials" → "OAuth 2.0 Client ID"
   - Application type: **Web application**
   - Name: `Headlamp Cloudflare Access`

3. **Configure Redirect URIs**:
   ```
   Authorized redirect URIs:
   https://chocolandiadc.cloudflareaccess.com/cdn-cgi/access/callback

   Authorized JavaScript origins:
   https://headlamp.chocolandiadc.com
   ```

4. **Copy Credentials**:
   - Copy **Client ID** (save for terraform.tfvars)
   - Copy **Client Secret** (save for terraform.tfvars)

---

## Step 3: Update OpenTofu Variables

Edit `terraform/environments/chocolandiadc-mvp/terraform.tfvars`:

```hcl
# Add these variables (if not already present from Feature 004)
google_oauth_client_id     = "YOUR_CLIENT_ID_HERE.apps.googleusercontent.com"
google_oauth_client_secret = "YOUR_CLIENT_SECRET_HERE"

# Add Headlamp-specific variables
headlamp_enabled = true
headlamp_domain  = "headlamp.chocolandiadc.com"
headlamp_authorized_emails = [
  "cbenitez@gmail.com",
  # Add more authorized emails here
]
```

**Security Note**: For production, use environment variables or secret management:
```bash
export TF_VAR_google_oauth_client_secret="YOUR_SECRET"
```

---

## Step 4: Initialize OpenTofu

```bash
# Navigate to environment directory
cd terraform/environments/chocolandiadc-mvp

# Initialize OpenTofu (downloads providers, modules)
tofu init

# Expected output:
# Initializing modules...
# - headlamp in ../../modules/headlamp
# Initializing provider plugins...
# - Finding latest version of hashicorp/helm
# - Finding latest version of hashicorp/kubernetes
# - Finding latest version of cloudflare/cloudflare
```

---

## Step 5: Review Infrastructure Plan

```bash
# Generate execution plan
tofu plan

# Review output carefully:
# - Should show: Namespace creation (headlamp)
# - Should show: Helm release (headlamp)
# - Should show: RBAC resources (ServiceAccount, ClusterRoleBinding)
# - Should show: IngressRoute (HTTP + HTTPS)
# - Should show: Certificate (cert-manager)
# - Should show: Cloudflare Access (Application + Policy)
#
# Expected resource count: ~12-15 resources to add
```

**Important Checks**:
- ✅ No unexpected deletions
- ✅ Domain name is correct (`headlamp.chocolandiadc.com`)
- ✅ Namespace is `headlamp`
- ✅ ClusterRole binding references `view` role

---

## Step 6: Apply Infrastructure

```bash
# Apply changes (requires confirmation)
tofu apply

# Type 'yes' when prompted

# Expected output:
# module.headlamp.kubernetes_namespace.headlamp: Creating...
# module.headlamp.helm_release.headlamp: Creating...
# module.headlamp.kubernetes_manifest.certificate: Creating...
# ...
# Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
```

**Deployment Duration**: 2-5 minutes
- Namespace creation: ~5 seconds
- Helm release: ~60 seconds (image pull)
- Certificate issuance: ~2 minutes (Let's Encrypt DNS-01 challenge)
- IngressRoute sync: ~10 seconds

---

## Step 7: Verify Deployment

### Check Pod Status
```bash
# Verify pods are running
export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig
kubectl get pods -n headlamp

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# headlamp-58d7f9b7c4-abc12   1/1     Running   0          2m
# headlamp-58d7f9b7c4-def34   1/1     Running   0          2m

# Check pod logs (optional)
kubectl logs -n headlamp -l app.kubernetes.io/name=headlamp
```

### Check Service
```bash
# Verify service is created
kubectl get svc -n headlamp

# Expected output:
# NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# headlamp   ClusterIP   10.43.xxx.xxx   <none>        80/TCP    2m
```

### Check IngressRoute
```bash
# Verify IngressRoute is configured
kubectl get ingressroute -n headlamp

# Expected output:
# NAME             AGE
# headlamp-http    2m
# headlamp-https   2m

# Check IngressRoute details
kubectl describe ingressroute headlamp-https -n headlamp
```

### Check Certificate
```bash
# Verify certificate is issued
kubectl get certificate -n headlamp

# Expected output:
# NAME            READY   SECRET         AGE
# headlamp-cert   True    headlamp-tls   2m

# Check certificate details
kubectl describe certificate headlamp-cert -n headlamp

# Should show:
# Status:
#   Conditions:
#     Type: Ready
#     Status: True
#   Not After: [90 days from now]
```

---

## Step 8: Extract ServiceAccount Token

```bash
# Get token for Headlamp UI login
kubectl get secret headlamp-admin-token -n headlamp \
  -o jsonpath='{.data.token}' | base64 -d

# Copy the output token (long string starting with "eyJ...")
# You'll need this for Step 10
```

**Important**:
- Token is long-lived (does not expire)
- Store securely (password manager or encrypted note)
- If lost, regenerate with same command

---

## Step 9: Verify Cloudflare Access

1. **Check Access Application**:
   - Go to Cloudflare Zero Trust dashboard
   - Navigate to Access → Applications
   - Verify "Headlamp Kubernetes Dashboard" application exists
   - Domain should be `headlamp.chocolandiadc.com`

2. **Check Access Policy**:
   - Click on "Headlamp Kubernetes Dashboard"
   - Verify policy "Allow Homelab Admins" exists
   - Verify your email is in the include list
   - Verify Google OAuth is required

---

## Step 10: Access Headlamp UI

1. **Open Browser**:
   ```
   https://headlamp.chocolandiadc.com
   ```

2. **Cloudflare Access Login**:
   - You'll be redirected to Cloudflare Access
   - Click "Sign in with Google"
   - Authenticate with your Google account
   - Cloudflare validates your email against policy

3. **Headlamp Token Login**:
   - After Cloudflare Access, you'll see Headlamp login page
   - **Authentication Method**: Select "Token"
   - **Token**: Paste the ServiceAccount token from Step 8
   - Click "Authenticate"

4. **Dashboard Loads**:
   - You should see the Headlamp dashboard
   - Cluster resources visible (Pods, Services, Deployments, etc.)
   - Left sidebar shows namespaces
   - Top bar shows cluster info

---

## Step 11: Validate Functionality

### Test Read-Only RBAC
```bash
# In Headlamp UI, try to:
1. View pods in any namespace ✅ (should work)
2. View services ✅ (should work)
3. View deployments ✅ (should work)
4. Try to delete a pod ❌ (should fail with "Forbidden")
5. Try to edit a deployment ❌ (should fail with "Forbidden")
```

### Test Custom CRD Visibility
```bash
# In Headlamp UI:
1. Navigate to "Custom Resources"
2. Check if you see:
   - IngressRoutes (Traefik) ✅
   - Certificates (cert-manager) ✅
   - ServiceMonitors (Prometheus) ✅
```

### Test Log Streaming
```bash
# In Headlamp UI:
1. Navigate to a pod (any namespace)
2. Click "Logs" tab
3. Verify real-time log streaming works ✅
```

### Test Prometheus Integration (if configured)
```bash
# In Headlamp UI:
1. Navigate to a pod
2. Look for "Metrics" tab or charts
3. Verify metrics are displayed ✅
```

---

## Troubleshooting

### Issue: Certificate Not Ready

**Symptoms**:
```bash
kubectl get certificate -n headlamp
# NAME            READY   SECRET         AGE
# headlamp-cert   False   headlamp-tls   5m
```

**Diagnosis**:
```bash
# Check certificate events
kubectl describe certificate headlamp-cert -n headlamp

# Check CertificateRequest
kubectl get certificaterequest -n headlamp
kubectl describe certificaterequest [NAME] -n headlamp

# Common issues:
# - DNS not pointing to cluster
# - Cloudflare API token invalid
# - Rate limit hit (Let's Encrypt)
```

**Solution**:
```bash
# Verify DNS resolution
dig headlamp.chocolandiadc.com

# Delete and recreate certificate (if stuck)
kubectl delete certificate headlamp-cert -n headlamp
tofu apply  # Will recreate
```

---

### Issue: Cloudflare Access Denies Login

**Symptoms**:
- "Access Denied" after Google OAuth
- 403 Forbidden error

**Diagnosis**:
```bash
# Check Cloudflare Access logs:
# 1. Go to Cloudflare Zero Trust dashboard
# 2. Navigate to Logs → Access
# 3. Filter by application: "Headlamp"
# 4. Check rejection reason
```

**Common Causes**:
- Email not in authorized list
- Policy not attached to application
- Google OAuth misconfigured

**Solution**:
```bash
# Update terraform.tfvars
headlamp_authorized_emails = [
  "your_email@gmail.com",  # Add your email
]

# Reapply
tofu apply
```

---

### Issue: Pods Not Running

**Symptoms**:
```bash
kubectl get pods -n headlamp
# NAME                        READY   STATUS             RESTARTS   AGE
# headlamp-58d7f9b7c4-abc12   0/1     ImagePullBackOff   0          5m
```

**Diagnosis**:
```bash
# Check pod events
kubectl describe pod -n headlamp -l app.kubernetes.io/name=headlamp

# Check pod logs
kubectl logs -n headlamp -l app.kubernetes.io/name=headlamp
```

**Common Causes**:
- Image pull failure (check registry)
- Resource limits too low
- Liveness probe failing

**Solution**:
```bash
# Increase resource limits (if OOMKilled)
# Edit terraform/modules/headlamp/values.yaml
resources:
  limits:
    memory: 512Mi  # Increase from 256Mi

# Reapply
tofu apply
```

---

### Issue: IngressRoute Not Working

**Symptoms**:
- 404 Not Found when accessing URL
- ERR_CONNECTION_REFUSED

**Diagnosis**:
```bash
# Check IngressRoute status
kubectl get ingressroute -n headlamp
kubectl describe ingressroute headlamp-https -n headlamp

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

**Common Causes**:
- Service not reachable
- TLS Secret missing
- Traefik not synced

**Solution**:
```bash
# Test service internally
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://headlamp.headlamp.svc.cluster.local

# Should return HTTP 200
```

---

### Issue: Token Authentication Fails

**Symptoms**:
- "Invalid token" in Headlamp UI
- "Unauthorized" error

**Diagnosis**:
```bash
# Verify ServiceAccount exists
kubectl get sa headlamp-admin -n headlamp

# Verify ClusterRoleBinding exists
kubectl get clusterrolebinding headlamp-view-binding

# Test token manually
TOKEN=$(kubectl get secret headlamp-admin-token -n headlamp \
  -o jsonpath='{.data.token}' | base64 -d)

curl -k -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces

# Should return namespace list (not error)
```

**Solution**:
```bash
# Regenerate token Secret
kubectl delete secret headlamp-admin-token -n headlamp
# Wait 10 seconds for auto-regeneration

# Extract new token
kubectl get secret headlamp-admin-token -n headlamp \
  -o jsonpath='{.data.token}' | base64 -d
```

---

## Cleanup (Optional)

To remove Headlamp deployment:

```bash
# Navigate to environment directory
cd terraform/environments/chocolandiadc-mvp

# Plan destruction
tofu plan -destroy

# Confirm and destroy
tofu destroy

# Type 'yes' when prompted

# Verify namespace is deleted
kubectl get namespace headlamp
# Error: namespaces "headlamp" not found (expected)
```

**Note**: This will:
- Delete Headlamp deployment and pods
- Delete IngressRoute and Certificate
- Delete ServiceAccount and RBAC
- Delete Cloudflare Access application
- **NOT** delete Traefik, cert-manager, or Cloudflare Zero Trust (shared resources)

---

## Post-Deployment Tasks

1. **Add to Monitoring**:
   ```bash
   # (Optional) Create Grafana dashboard for pod metrics
   # Import dashboard ID: [find community dashboard]
   ```

2. **Document Token Location**:
   ```bash
   # Store token in password manager:
   # - Service: Headlamp K3s Homelab
   # - Username: headlamp-admin
   # - Token: [paste token]
   ```

3. **Test from External Device**:
   ```bash
   # From phone/tablet browser:
   https://headlamp.chocolandiadc.com

   # Verify Cloudflare Access + token login works
   ```

4. **Add More Users (Optional)**:
   ```bash
   # Edit terraform.tfvars
   headlamp_authorized_emails = [
     "cbenitez@gmail.com",
     "friend@example.com",  # Add new user
   ]

   # Create separate ServiceAccount for friend (optional)
   # Or share same token (not recommended for audit)
   ```

---

## Next Steps

✅ **Feature Complete**: Headlamp Web UI deployed and accessible

**Optional Enhancements**:
1. Enable OIDC authentication (instead of token)
2. Add NetworkPolicy for pod isolation
3. Configure Headlamp plugins
4. Create custom Grafana dashboard for Headlamp pod metrics
5. Set up automated token rotation

**Related Features**:
- Feature 008: K9s TUI (alternative local dashboard)
- Feature 009: Monitoring dashboards (Grafana)
- Feature 010: FortiGate network security (if not using Eero)

---

## Success Criteria Validation

Verify all success criteria from spec.md:

- [x] **SC-001**: Headlamp pod reaches Running status in < 60 seconds ✅
- [x] **SC-002**: Web UI loads in < 3 seconds after authentication ✅
- [x] **SC-003**: Cluster resources visible within 2 clicks ✅
- [x] **SC-004**: HTTPS certificate issued within 5 minutes ✅
- [x] **SC-005**: Unauthorized users blocked (100% denial rate) ✅
- [x] **SC-006**: Google OAuth authentication < 30 seconds ✅
- [x] **SC-007**: Resource consumption under limits (128Mi/200m) ✅
- [x] **SC-008**: Log streaming < 2 seconds ✅
- [x] **SC-009**: Prometheus metrics N/A (Headlamp is consumer) -
- [x] **SC-010**: Custom CRDs visible in UI ✅
- [x] **SC-011**: Read-only RBAC prevents destructive ops ✅
- [x] **SC-012**: Accessible from any device with browser ✅

---

## Support and Resources

- **Headlamp Documentation**: https://headlamp.dev/docs/
- **Headlamp GitHub**: https://github.com/headlamp-k8s/headlamp
- **Traefik IngressRoute**: https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/
- **cert-manager**: https://cert-manager.io/docs/
- **Cloudflare Access**: https://developers.cloudflare.com/cloudflare-one/applications/

**Project Specific**:
- Spec: `specs/007-headlamp-web-ui/spec.md`
- Plan: `specs/007-headlamp-web-ui/plan.md`
- Research: `specs/007-headlamp-web-ui/research.md`
- Data Model: `specs/007-headlamp-web-ui/data-model.md`
