# Homepage Dashboard Update - Quickstart Guide

**Feature**: 001-homepage-update
**Date**: 2025-11-18
**Estimated Time**: 30-45 minutes

## Overview

This quickstart guide walks through the complete process of updating the Homepage dashboard configuration to add new services, fix ArgoCD widget authentication, and verify all integrations are working correctly.

## Prerequisites

- [x] K3s cluster is running (nodes: eero-1, eero-2, eero-3, eero-4)
- [x] Homepage is deployed in the `homepage` namespace
- [x] ArgoCD is deployed and managing Homepage application
- [x] OpenTofu 1.6+ installed locally
- [x] kubectl configured with cluster access
- [x] ArgoCD CLI installed (for token generation)

## Table of Contents

1. [Generate ArgoCD API Token](#1-generate-argocd-api-token)
2. [Update OpenTofu Configuration](#2-update-opentofu-configuration)
3. [Apply Changes with OpenTofu](#3-apply-changes-with-opentofu)
4. [Verify ConfigMap Updates](#4-verify-configmap-updates)
5. [Restart Homepage Pod](#5-restart-homepage-pod)
6. [Test Service Links and Widgets](#6-test-service-links-and-widgets)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Generate ArgoCD API Token

### Step 1.1: Create ArgoCD Local User Account

Edit the ArgoCD ConfigMap to add a local user with API key capability:

```bash
kubectl edit configmap argocd-cm -n argocd
```

Add the following under the `data` section:

```yaml
data:
  accounts.homepage: apiKey
```

Save and exit.

### Step 1.2: Configure RBAC Permissions

Edit the ArgoCD RBAC ConfigMap to grant read-only permissions:

```bash
kubectl edit configmap argocd-rbac-cm -n argocd
```

Add the following under the `data` section:

```yaml
data:
  policy.csv: |
    g, homepage, role:readonly
```

Save and exit.

### Step 1.3: Restart ArgoCD Pods

Apply the configuration changes by restarting ArgoCD server:

```bash
kubectl rollout restart deployment argocd-server -n argocd
```

Wait for pods to be ready:

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=120s
```

### Step 1.4: Generate API Token

Login to ArgoCD:

```bash
argocd login argocd.chocolandiadc.com
```

When prompted:
- Username: `admin`
- Password: Get from secret:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
  ```

Generate token for homepage account:

```bash
argocd account generate-token --account homepage
```

**Important**: Copy the token output - you'll need it in the next step.

Example output:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhcmd...
```

---

## 2. Update OpenTofu Configuration

### Step 2.1: Update Terraform Variables

Open the terraform variables file:

```bash
cd /Users/cbenitez/chocolandia_kube
```

Edit `terraform/environments/prod/terraform.tfvars` and update the ArgoCD token:

```hcl
# Homepage Configuration
homepage_argocd_token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhcmd..."
```

**Security Note**: This file is gitignored and should never be committed to version control.

### Step 2.2: Review Configuration Files

The following configuration files have been updated:

```bash
# Check updated configurations
ls -la terraform/modules/homepage/configs/
```

Expected files:
- `services.yaml` - Service links and widgets
- `widgets.yaml` - Global dashboard widgets (Kubernetes, resources)
- `kubernetes.yaml` - Kubernetes integration settings
- `settings.yaml` - Global settings (unchanged)

Preview the changes:

```bash
# View services configuration
cat terraform/modules/homepage/configs/services.yaml

# View widgets configuration
cat terraform/modules/homepage/configs/widgets.yaml

# View Kubernetes integration settings
cat terraform/modules/homepage/configs/kubernetes.yaml
```

---

## 3. Apply Changes with OpenTofu

### Step 3.1: Initialize OpenTofu

```bash
cd terraform/environments/prod
tofu init
```

### Step 3.2: Plan Changes

Review what will be changed:

```bash
tofu plan
```

Expected changes:
- ConfigMap `homepage-services` will be updated
- ConfigMap `homepage-widgets` will be updated
- ConfigMap `homepage-kubernetes` may be updated
- Secret `homepage-secrets` will be updated (ArgoCD token)

**Review carefully**: Ensure only Homepage-related resources are being modified.

### Step 3.3: Apply Changes

Apply the configuration:

```bash
tofu apply
```

When prompted, type `yes` to confirm.

Expected output:
```
Apply complete! Resources: 0 added, 3 changed, 0 destroyed.
```

---

## 4. Verify ConfigMap Updates

### Step 4.1: Check ConfigMaps

Verify the ConfigMaps were updated:

```bash
# Check services ConfigMap
kubectl get configmap homepage-services -n homepage -o yaml | grep -A 10 "data:"

# Check widgets ConfigMap
kubectl get configmap homepage-widgets -n homepage -o yaml | grep -A 10 "data:"

# Check kubernetes ConfigMap
kubectl get configmap homepage-kubernetes -n homepage -o yaml | grep -A 5 "data:"
```

### Step 4.2: Verify Secret

Check that the ArgoCD token secret was created/updated:

```bash
kubectl get secret homepage-secrets -n homepage -o jsonpath='{.data.argocd-token}' | base64 -d
```

This should output the token you generated in Step 1.4 (truncated for security).

---

## 5. Restart Homepage Pod

### Important Note: ArgoCD Auto-Sync

Homepage is managed by ArgoCD with automatic sync enabled. After updating ConfigMaps, ArgoCD may detect drift and automatically restart the pod. Check ArgoCD first:

```bash
# Check ArgoCD application status
argocd app get homepage
```

If sync status shows "OutOfSync", ArgoCD will auto-sync within 3 minutes (default interval).

### Step 5.1: Manual Restart (if needed)

If ArgoCD hasn't synced yet, or you want to force immediate restart:

```bash
kubectl rollout restart deployment homepage -n homepage
```

### Step 5.2: Wait for Pod Ready

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=homepage -n homepage --timeout=120s
```

### Step 5.3: Check Pod Logs

Verify no errors during startup:

```bash
kubectl logs -n homepage -l app.kubernetes.io/name=homepage --tail=50
```

Expected output should show:
- Configuration files loaded successfully
- No authentication errors
- Widgets initialized

Look for any ERROR or WARN messages related to ArgoCD or Kubernetes integration.

---

## 6. Test Service Links and Widgets

### Step 6.1: Access Homepage Dashboard

Open Homepage in your browser:

```
https://homepage.chocolandiadc.com
```

You should be prompted to authenticate via Cloudflare Zero Trust (Google OAuth).

### Step 6.2: Verify Service Categories

Confirm all service categories are visible and alphabetically organized:

**Expected Categories and Services**:

1. **Applications**
   - [ ] Beersystem (icon: beer.svg)
     - Public URL: https://beer.chocolandiadc.com
     - Private URL shown in description
     - Kubernetes widget displaying pod metrics

2. **GitOps**
   - [ ] ArgoCD (icon: argocd.svg)
     - Public URL: https://argocd.chocolandiadc.com
     - **ArgoCD widget showing application sync status** ⚠️ **PRIMARY TEST**
     - Should display: Total apps, Synced, Out of Sync, Healthy, etc.

3. **Infrastructure**
   - [ ] cert-manager (existing)
   - [ ] Headlamp (existing)
   - [ ] Pi-hole (icon: pihole.svg)
     - Public URL: https://pihole.chocolandiadc.com
     - Private URLs in description
   - [ ] Traefik (existing)

4. **Monitoring**
   - [ ] Grafana (icon: grafana.svg)
     - Public URL: https://grafana.chocolandiadc.com
     - Private NodePort in description
     - Kubernetes widget showing pod metrics
   - [ ] Homepage (self - existing)
   - [ ] Netdata (icon: netdata.svg) - if deployed
     - Private URL only
   - [ ] Prometheus (icon: prometheus.svg)
     - Internal only (port-forward)

5. **Storage**
   - [ ] Longhorn (icon: longhorn.svg)
     - Public URL: https://longhorn.chocolandiadc.com
   - [ ] MinIO API (icon: minio.svg)
     - Public URL: https://s3.chocolandiadc.com
     - Private URL in description
   - [ ] MinIO Console (icon: minio.svg)
     - Public URL: https://minio.chocolandiadc.com
   - [ ] PostgreSQL HA (icon: postgresql.svg)
     - Private LoadBalancer IP: 192.168.4.200:5432

### Step 6.3: Test ArgoCD Widget

**This is the critical test** - verify ArgoCD widget authentication is working:

1. Locate the ArgoCD service card in the "GitOps" category
2. Confirm the widget displays metrics:
   - Total applications count
   - Synced / Out of Sync counts
   - Healthy / Progressing / Degraded statuses
3. Widget should **NOT** show authentication errors

**If widget shows error**: See [Troubleshooting](#7-troubleshooting) section below.

### Step 6.4: Test Kubernetes Widgets

Verify Kubernetes integration is working:

1. **Global Kubernetes Widget** (sidebar or top):
   - [ ] Cluster CPU usage displayed
   - [ ] Cluster memory usage displayed
   - [ ] Node count shown (4 nodes: eero-1, eero-2, eero-3, eero-4)
   - [ ] Per-node metrics visible

2. **Service-Level Kubernetes Widgets**:
   - [ ] Beersystem shows pod metrics
   - [ ] Grafana shows pod metrics
   - [ ] Homepage (self) shows pod metrics

### Step 6.5: Test Service Links

Click through to verify all public URLs are accessible:

- [ ] ArgoCD: https://argocd.chocolandiadc.com
- [ ] Beersystem: https://beer.chocolandiadc.com
- [ ] Grafana: https://grafana.chocolandiadc.com
- [ ] Headlamp: https://headlamp.chocolandiadc.com
- [ ] Longhorn: https://longhorn.chocolandiadc.com
- [ ] MinIO Console: https://minio.chocolandiadc.com
- [ ] MinIO S3 API: https://s3.chocolandiadc.com
- [ ] Pi-hole: https://pihole.chocolandiadc.com

All should:
1. Authenticate via Cloudflare Zero Trust (Google OAuth)
2. Load the service interface successfully
3. Match the service described in the card

### Step 6.6: Test Private Network Access (Optional)

From a device on the 192.168.4.0/24 network, test private URLs:

```bash
# Grafana NodePort
curl -I http://192.168.4.101:30000

# Pi-hole Web
curl -I http://192.168.4.101:30001

# PostgreSQL (requires psql client)
psql -h 192.168.4.200 -p 5432 -U postgres -l

# Pi-hole DNS
dig @192.168.4.201 google.com
```

---

## 7. Troubleshooting

### Issue: ArgoCD Widget Shows "Unauthorized" or "401"

**Cause**: Invalid or expired API token

**Solution**:

1. Verify token in secret:
   ```bash
   kubectl get secret homepage-secrets -n homepage -o jsonpath='{.data.argocd-token}' | base64 -d
   ```

2. Test token manually:
   ```bash
   TOKEN=$(kubectl get secret homepage-secrets -n homepage -o jsonpath='{.data.argocd-token}' | base64 -d)
   curl -k -H "Authorization: Bearer $TOKEN" https://argocd.chocolandiadc.com/api/v1/applications
   ```

3. If token is invalid, regenerate:
   ```bash
   # Revoke old token
   argocd account delete-token --account homepage

   # Generate new token
   argocd account generate-token --account homepage

   # Update terraform.tfvars and re-apply
   tofu apply
   ```

4. Restart Homepage pod:
   ```bash
   kubectl rollout restart deployment homepage -n homepage
   ```

### Issue: ArgoCD Widget Shows "Connection Refused"

**Cause**: Widget using wrong URL (external vs internal)

**Solution**:

1. Check services.yaml ArgoCD widget URL:
   ```bash
   kubectl get configmap homepage-services -n homepage -o yaml | grep -A 5 "argocd"
   ```

2. Should use in-cluster service URL:
   ```yaml
   url: http://argocd-server.argocd.svc.cluster.local:80
   ```

3. If using external URL, update to in-cluster URL and re-apply configuration

### Issue: Kubernetes Widget Shows "Permission Denied"

**Cause**: Insufficient RBAC permissions

**Solution**:

1. Verify ServiceAccount exists:
   ```bash
   kubectl get serviceaccount homepage -n homepage
   ```

2. Check ClusterRoleBinding:
   ```bash
   kubectl get clusterrolebinding homepage -o yaml
   ```

3. Verify ServiceAccount is mounted in pod:
   ```bash
   kubectl describe pod -n homepage -l app.kubernetes.io/name=homepage | grep "Service Account"
   ```

4. Check pod logs for permission errors:
   ```bash
   kubectl logs -n homepage -l app.kubernetes.io/name=homepage | grep -i "permission\|denied\|forbidden"
   ```

### Issue: Node/Pod Metrics Not Displayed

**Cause**: metrics-server not available

**Solution**:

1. Check metrics-server deployment:
   ```bash
   kubectl get deployment metrics-server -n kube-system
   ```

2. Verify metrics API is working:
   ```bash
   kubectl top nodes
   kubectl top pods -n homepage
   ```

3. If metrics-server is missing, K3s should include it by default. Restart K3s if needed:
   ```bash
   # On each node
   sudo systemctl restart k3s
   ```

### Issue: Services Not Auto-Discovered

**Cause**: Auto-discovery disabled or missing annotations

**Solution**:

1. Check kubernetes.yaml configuration:
   ```bash
   kubectl get configmap homepage-kubernetes -n homepage -o yaml
   ```

2. Ensure `showAnnotations: true` if you want auto-discovery

3. For manual configuration (recommended), ensure services.yaml is properly formatted

### Issue: ArgoCD Shows "Out of Sync" for Homepage

**Cause**: ConfigMap changes detected by ArgoCD

**Behavior**: This is expected after OpenTofu updates ConfigMaps

**Solution**:

ArgoCD will auto-sync within 3 minutes (default sync interval). You can:

1. Wait for auto-sync:
   ```bash
   argocd app get homepage --watch
   ```

2. Or manually sync:
   ```bash
   argocd app sync homepage
   ```

3. Check sync status:
   ```bash
   argocd app list | grep homepage
   ```

### Issue: Icons Not Displaying

**Cause**: Icon file not found or incorrect name

**Solution**:

1. Homepage includes many built-in icons. Check available icons at:
   https://github.com/walkxcode/dashboard-icons

2. Common icon names (use exact filename):
   - `argocd.svg`
   - `grafana.svg`
   - `postgresql.svg`
   - `minio.svg`
   - `pihole.svg`
   - `longhorn.svg`
   - `prometheus.svg`

3. If icon is missing, either:
   - Use a similar icon name
   - Add custom icon to Homepage static assets
   - Leave `icon` field blank (shows default icon)

---

## Success Criteria

Your Homepage update is complete when:

- [x] ArgoCD widget displays application sync status (no auth errors)
- [x] Kubernetes cluster widget shows node metrics
- [x] All service links are clickable and load correctly
- [x] Service categories are properly organized
- [x] Icons display correctly for all services
- [x] Private network access URLs are documented in descriptions
- [x] ArgoCD shows Homepage application as "Synced" and "Healthy"
- [x] No errors in Homepage pod logs

---

## Next Steps

After successful deployment:

1. **Monitor ArgoCD Sync**:
   - Homepage will auto-sync any drift detected
   - Review ArgoCD logs if sync fails
   - Ensure changes are intentional before committing

2. **Update Documentation**:
   - Document any custom widgets added
   - Update CLAUDE.md with new services
   - Add to project wiki if needed

3. **Consider Enhancements**:
   - Add Netdata if hardware monitoring is needed
   - Configure additional widgets (Grafana, Pi-hole)
   - Set up IngressRoute annotations for auto-discovery
   - Add Prometheus/Alertmanager public ingress if needed

4. **Token Rotation**:
   - Schedule periodic ArgoCD token rotation (recommended: quarterly)
   - Document token rotation procedure
   - Set calendar reminder

---

## Reference URLs

**Documentation**:
- Homepage Official Docs: https://gethomepage.dev/
- ArgoCD Widget: https://gethomepage.dev/widgets/services/argocd/
- Kubernetes Integration: https://gethomepage.dev/configs/kubernetes/

**Your Services**:
- Homepage Dashboard: https://homepage.chocolandiadc.com
- ArgoCD Console: https://argocd.chocolandiadc.com
- Grafana Dashboards: https://grafana.chocolandiadc.com

**Local Network Access**:
- PostgreSQL: 192.168.4.200:5432
- Pi-hole DNS: 192.168.4.201:53
- Grafana: http://192.168.4.101:30000
- Pi-hole Web: http://192.168.4.101:30001

---

**Document Version**: 1.0
**Last Updated**: 2025-11-18
**Estimated Completion Time**: 30-45 minutes
**Difficulty**: Intermediate
