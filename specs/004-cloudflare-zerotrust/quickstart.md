# Quickstart Guide: Cloudflare Zero Trust VPN Access

**Feature**: 004-cloudflare-zerotrust
**Target**: K3s cluster deployment with secure remote access
**Time**: ~30-45 minutes (first-time setup)

## Prerequisites

Before starting, ensure you have:

- ✅ **K3s cluster running** (3 control-plane + 1 worker node)
- ✅ **Cloudflare account** (free tier sufficient)
- ✅ **Domain name managed by Cloudflare DNS** (e.g., `chocolandiadc.com`)
- ✅ **Google Cloud Console access** (for OAuth client creation)
- ✅ **kubectl configured** to access your K3s cluster
- ✅ **OpenTofu 1.6+** installed locally
- ✅ **Internal service running** (e.g., Pi-hole at `pihole-web.default.svc.cluster.local:80`)
- ✅ **Cloudflare API Token** (with required permissions - see Step 1)
- ✅ **Cloudflare Account ID** (see Step 2)
- ✅ **Cloudflare Zone ID** (see Step 2)

**Verification Commands**:
```bash
# Check cluster access
kubectl get nodes

# Check OpenTofu version
tofu version  # Should show 1.6.x or higher

# Verify domain DNS managed by Cloudflare
dig NS chocolandiadc.com  # Should show Cloudflare nameservers
```

---

## Step 1: Create Cloudflare API Token

**Goal**: Generate API token with permissions to manage tunnels, Access policies, and DNS records via Terraform.

### 1.1: Navigate to API Tokens

1. Login to **Cloudflare Dashboard**: `https://dash.cloudflare.com/`
2. Navigate to **My Profile** → **API Tokens**:
   - URL: `https://dash.cloudflare.com/profile/api-tokens`
   - Click **Create Token**

### 1.2: Create Custom Token

1. Click **Get started** next to "Create Custom Token"
2. Configure token **permissions**:

   **Account Permissions**:
   - `Cloudflare Tunnel` → **Edit**
   - `Access: Apps and Policies` → **Edit**

   **Zone Permissions**:
   - `DNS` → **Edit**
   - `Zone` → **Read**

3. Configure **Account Resources**:
   - Include → Specific account → Select your Cloudflare account

4. Configure **Zone Resources**:
   - Include → Specific zone → Select `chocolandiadc.com` (or your domain)

5. Optional: Set **IP Address Filtering** (restrict to your home IP for security)

6. Optional: Set **TTL** (token expiration - leave empty for no expiration)

7. Click **Continue to summary**

### 1.3: Copy Token Securely

1. Review permissions summary
2. Click **Create Token**
3. **Copy the token immediately** (shown only once):
   ```
   abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
   ```
4. ⚠️ **CRITICAL**: Store token securely (password manager, encrypted vault)
5. You'll use this token in Step 4 (`terraform.tfvars`)

**Expected Result**: API token created with required permissions.

---

## Step 2: Get Cloudflare Account and Zone IDs

**Goal**: Retrieve Account ID and Zone ID required for Terraform configuration.

### 2.1: Get Account ID

1. Navigate to **Cloudflare Dashboard** home: `https://dash.cloudflare.com/`
2. Look at the **sidebar** (left navigation):
   - Under your account name, you'll see **Account ID**
   - Example: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`
3. Click to copy or note it down

**Alternative method**:
```bash
# Using curl with API token
curl -X GET "https://api.cloudflare.com/client/v4/accounts" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  | jq -r '.result[0].id'
```

### 2.2: Get Zone ID

1. Navigate to **Cloudflare Dashboard** → **Websites**
2. Click on your domain: `chocolandiadc.com`
3. Scroll to **API** section on right sidebar (Overview tab):
   - Look for **Zone ID**
   - Example: `z9y8x7w6v5u4t3s2r1q0p9o8n7m6l5k4`
4. Click to copy or note it down

**Alternative method**:
```bash
# Using curl with API token
curl -X GET "https://api.cloudflare.com/client/v4/zones?name=chocolandiadc.com" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  | jq -r '.result[0].id'
```

**Expected Result**: Both Account ID and Zone ID copied securely for Step 4.

---

## Step 3: Configure Google OAuth Client

**Goal**: Create OAuth client in Google Cloud Console for Cloudflare Access authentication.

⚠️ **Note**: This is the ONLY manual dashboard configuration required. OAuth client credentials will be referenced in Terraform, but the client itself must be created in Google Cloud Console.

### 3.1: Create Google Cloud Project

1. Navigate to **Google Cloud Console**:
   - URL: `https://console.cloud.google.com/`
   - Login with your Google account

2. Create new project:
   - Click project selector (top navigation bar)
   - Click **New Project**
   - Project name: `chocolandia-homelab-access`
   - Organization: None (or your organization)
   - Click **Create**

### 3.2: Configure OAuth Consent Screen

1. Navigate to **OAuth consent screen**:
   - URL: `https://console.cloud.google.com/apis/credentials/consent`
   - Select the project you just created

2. Configure consent screen:
   - **User Type**: `External`
   - Click **Create**

3. Fill in application information:
   - **App name**: `Chocolandia Homelab Access`
   - **User support email**: Your Gmail address (`cbenitez@gmail.com`)
   - **App logo**: Optional (skip for MVP)
   - **Application home page**: Optional (can use `https://chocolandiadc.com`)
   - **Authorized domains**: Add `cloudflareaccess.com`
   - **Developer contact email**: `cbenitez@gmail.com`
   - Click **Save and Continue**

4. Configure scopes:
   - Click **Add or Remove Scopes**
   - Default scopes are sufficient (`openid`, `email`, `profile`)
   - Click **Update** → **Save and Continue**

5. Add test users (if keeping app in "Testing" status):
   - Click **Add Users**
   - Add your email: `cbenitez@gmail.com`
   - Add family/authorized emails: `family@gmail.com`
   - Click **Add** → **Save and Continue**

6. Review and confirm:
   - Publishing status: **Testing** (for limited access)
   - Click **Back to Dashboard**

### 3.3: Create OAuth 2.0 Client ID

1. Navigate to **Credentials**:
   - URL: `https://console.cloud.google.com/apis/credentials`
   - Click **Create Credentials** → **OAuth client ID**

2. Configure client:
   - **Application type**: `Web application`
   - **Name**: `Cloudflare Access OAuth Client`

3. Add **Authorized JavaScript origins**:
   - Click **Add URI**
   - Format: `https://<your-team-name>.cloudflareaccess.com`
   - ⚠️ **Find your team name**: Cloudflare Dashboard → Zero Trust → Settings → Custom Pages → Team domain
   - Example: `https://chocolandia.cloudflareaccess.com`

4. Add **Authorized redirect URIs**:
   - Click **Add URI**
   - Format: `https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/callback`
   - Example: `https://chocolandia.cloudflareaccess.com/cdn-cgi/access/callback`

5. Click **Create**

### 3.4: Copy OAuth Credentials

1. Copy the credentials shown:
   - **Client ID**: `123456789012-abc123def456ghi789jkl.apps.googleusercontent.com`
   - **Client Secret**: `GOCSPX-ABC123DEF456GHI789JKL012MNO`

2. ⚠️ **Store securely**: You'll use these in Step 4 (`terraform.tfvars`)

**Expected Result**: OAuth client created with Client ID and Secret ready for Terraform configuration.

---

## Step 4: Deploy ALL Infrastructure via Terraform

**Goal**: Deploy tunnel, Kubernetes resources, Access policies, DNS records, and ingress routes with a single `tofu apply` command.

✅ **Key Message**: Zero manual dashboard configuration - everything declared in code.

### 4.1: Navigate to Terraform Environment

```bash
# Navigate to OpenTofu environment directory
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/
```

### 4.2: Create terraform.tfvars (NOT Committed)

⚠️ **CRITICAL**: This file contains secrets and MUST NOT be committed to Git.

```bash
# Create terraform.tfvars file
cat > terraform.tfvars <<'EOF'
# ============================================================================
# Cloudflare Configuration
# ============================================================================

# API Token (from Step 1)
cloudflare_api_token = "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"

# Account and Zone IDs (from Step 2)
cloudflare_account_id = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
cloudflare_zone_id    = "z9y8x7w6v5u4t3s2r1q0p9o8n7m6l5k4"

# Domain Configuration
domain_name = "chocolandiadc.com"

# ============================================================================
# Google OAuth Configuration (from Step 3)
# ============================================================================

google_oauth_client_id     = "123456789012-abc123def456ghi789jkl.apps.googleusercontent.com"
google_oauth_client_secret = "GOCSPX-ABC123DEF456GHI789JKL012MNO"

# ============================================================================
# Access Control Configuration
# ============================================================================

# Authorized email addresses for Cloudflare Access
authorized_emails = [
  "cbenitez@gmail.com",
  "family@gmail.com"
]

# ============================================================================
# Service Configuration
# ============================================================================

# Services to expose via Cloudflare Tunnel
services = {
  pihole = {
    hostname = "pihole.chocolandiadc.com"
    service  = "http://pihole-web.default.svc.cluster.local:80"
    enabled  = true
  }
  grafana = {
    hostname = "grafana.chocolandiadc.com"
    service  = "http://grafana.monitoring.svc.cluster.local:3000"
    enabled  = false  # Enable after Grafana deployment
  }
}

# ============================================================================
# Kubernetes Configuration
# ============================================================================

kubeconfig_path = "./kubeconfig"

# ============================================================================
# Git Configuration
# ============================================================================

commit_email = "cbenitez@gmail.com"
EOF
```

**Update the following values**:
- `cloudflare_api_token`: Paste token from Step 1
- `cloudflare_account_id`: Paste Account ID from Step 2
- `cloudflare_zone_id`: Paste Zone ID from Step 2
- `google_oauth_client_id`: Paste Client ID from Step 3
- `google_oauth_client_secret`: Paste Client Secret from Step 3
- `authorized_emails`: Update with your authorized email addresses
- `services`: Enable/disable services as needed

### 4.3: Verify .gitignore Excludes Secrets

```bash
# Verify terraform.tfvars is excluded
grep -q "terraform.tfvars" ../../.gitignore && echo "✅ Secrets excluded" || echo "⚠️  WARNING: Add terraform.tfvars to .gitignore"

# If not excluded, add it
if ! grep -q "terraform.tfvars" ../../.gitignore; then
  echo "terraform.tfvars" >> ../../.gitignore
  echo "✅ Added terraform.tfvars to .gitignore"
fi
```

### 4.4: Initialize and Validate Terraform

```bash
# Initialize OpenTofu (download providers)
tofu init

# Expected output:
# Initializing the backend...
# Initializing provider plugins...
# - Finding hashicorp/kubernetes latest version...
# - Finding cloudflare/cloudflare latest version...
# Terraform has been successfully initialized!

# Validate configuration
tofu validate

# Expected output:
# Success! The configuration is valid.

# Format code (ensure consistent style)
tofu fmt -recursive
```

### 4.5: Preview Changes

```bash
# Generate execution plan
tofu plan

# Review the plan carefully:
# Expected resources to CREATE:
# - cloudflare_tunnel.main
# - cloudflare_tunnel_config.main
# - cloudflare_access_identity_provider.google_oauth
# - cloudflare_access_application.pihole
# - cloudflare_access_policy.pihole_allow
# - cloudflare_record.pihole_cname
# - kubernetes_namespace.cloudflare_system
# - kubernetes_secret.cloudflared_token
# - kubernetes_deployment.cloudflared
# - kubernetes_config_map.cloudflared_config (if using config file method)

# Total: ~10-12 resources
```

**Review checklist**:
- ✅ Sensitive values shown as `<sensitive>` (not plaintext)
- ✅ No resources being destroyed (unless this is a redeployment)
- ✅ DNS records point to correct services
- ✅ Access policies reference correct email addresses
- ✅ Tunnel configuration includes all enabled services

### 4.6: Deploy Infrastructure

```bash
# Apply configuration
tofu apply

# Review plan one more time
# Type 'yes' when prompted to confirm

# Expected output:
# Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
#
# Outputs:
# tunnel_id = "abc123de-f456-gh78-ij90-klmno1234567"
# tunnel_cname = "abc123de-f456-gh78-ij90-klmno1234567.cfargotunnel.com"
# dns_records = {
#   pihole = "pihole.chocolandiadc.com"
# }
# access_applications = {
#   pihole = "https://pihole.chocolandiadc.com"
# }
# cloudflared_namespace = "cloudflare-system"
# cloudflared_deployment = "cloudflared"
```

**Deployment time**: Typically 30-60 seconds.

✅ **Success**: Single command deployed tunnel, Kubernetes resources, Access policies, DNS records, and ingress routes!

---

## Step 5: Verify Deployment

**Goal**: Confirm all infrastructure components deployed successfully.

### 5.1: Check Terraform Outputs

```bash
# View all outputs
tofu output

# Expected outputs:
# tunnel_id               = "abc123de-f456-gh78-ij90-klmno1234567"
# tunnel_cname            = "abc123de-f456-gh78-ij90-klmno1234567.cfargotunnel.com"
# dns_records             = {
#   pihole = "pihole.chocolandiadc.com"
# }
# access_applications     = {
#   pihole = "https://pihole.chocolandiadc.com"
# }
# cloudflared_namespace   = "cloudflare-system"
# cloudflared_deployment  = "cloudflared"

# Get specific output
tofu output tunnel_id
```

### 5.2: Check Kubernetes Resources

```bash
# Set kubeconfig (if not already set)
export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig

# Check namespace
kubectl get namespace cloudflare-system

# Check deployment
kubectl get deployment -n cloudflare-system

# Expected output:
# NAME          READY   UP-TO-DATE   AVAILABLE   AGE
# cloudflared   1/1     1            1           2m

# Check pods
kubectl get pods -n cloudflare-system

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# cloudflared-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

**Success indicators**:
- ✅ Namespace exists: `cloudflare-system`
- ✅ Deployment shows `READY 1/1`
- ✅ Pod status: `Running`
- ✅ Pod ready: `1/1`

### 5.3: Check Cloudflared Logs

```bash
# View cloudflared logs
kubectl logs -n cloudflare-system deployment/cloudflared --tail=50

# Look for success messages:
# "Registered tunnel connection"
# "Connection ... registered connIndex=0"
# "Serving tunnel..."
# "INF Registered tunnel connection connIndex=0"
```

**Success indicators**:
- ✅ `"Registered tunnel connection"` appears in logs
- ✅ No error messages about authentication or connectivity
- ✅ Connection state shows as registered

### 5.4: Verify in Cloudflare Dashboard (Read-Only)

⚠️ **Note**: Dashboard is for verification only - all configuration managed by Terraform.

1. **Navigate to Cloudflare Zero Trust** → **Networks** → **Tunnels**:
   - URL: `https://one.dash.cloudflare.com/`
   - Look for tunnel with ID from `tofu output tunnel_id`

2. **Check tunnel status**:
   - Status: **Healthy** (green indicator)
   - Connectors: **1 active**

3. **Verify public hostnames** (click tunnel → **Public Hostname** tab):
   - `pihole.chocolandiadc.com` → `http://pihole-web.default.svc.cluster.local:80`
   - Service status: **Active**

4. **Verify Access applications** (Navigate to **Access** → **Applications**):
   - Application name: `Pi-hole Admin Dashboard`
   - Domain: `pihole.chocolandiadc.com`
   - Status: **Active**

5. **Verify Access identity provider** (Navigate to **Settings** → **Authentication**):
   - Provider: `Google OAuth`
   - Status: **Active**

6. **Verify DNS records** (Navigate to **DNS** → **Records**):
   - Type: `CNAME`
   - Name: `pihole`
   - Target: `<tunnel-id>.cfargotunnel.com`
   - Proxy status: **Proxied** (orange cloud)

**Expected Result**: All components show as active/healthy in dashboard (managed entirely by Terraform).

### 5.5: Verify DNS Resolution

```bash
# Query DNS records
dig pihole.chocolandiadc.com

# Expected output:
# ;; ANSWER SECTION:
# pihole.chocolandiadc.com. 300 IN CNAME abc123de-f456-gh78-ij90-klmno1234567.cfargotunnel.com.
# abc123de-f456-gh78-ij90-klmno1234567.cfargotunnel.com. 300 IN A 104.21.x.x
# abc123de-f456-gh78-ij90-klmno1234567.cfargotunnel.com. 300 IN A 172.67.x.x

# Verify CNAME points to tunnel
dig pihole.chocolandiadc.com CNAME +short

# Expected output:
# abc123de-f456-gh78-ij90-klmno1234567.cfargotunnel.com.
```

**Success indicators**:
- ✅ CNAME record resolves to `<tunnel-id>.cfargotunnel.com`
- ✅ A records point to Cloudflare IPs (104.21.x.x, 172.67.x.x ranges)
- ✅ No DNS resolution errors

---

## Step 6: Test Remote Access

**Goal**: Verify end-to-end connectivity and authentication from external network.

### 6.1: Test from External Network

⚠️ **IMPORTANT**: Test from device NOT on your home network (use mobile data, coffee shop WiFi, or VPN to simulate external access).

1. **Open browser** (Incognito/Private mode recommended):
   - Navigate to: `https://pihole.chocolandiadc.com`

2. **Expected authentication flow**:
   - Step 1: Redirected to Cloudflare Access login page
   - Step 2: Click **Google** (or auto-redirect if only one provider)
   - Step 3: Authenticate with authorized Google account (`cbenitez@gmail.com`)
   - Step 4: Grant consent (if first time)
   - Step 5: Redirected back to Pi-hole admin dashboard

3. **Verify Pi-hole loads**:
   - Pi-hole admin interface should appear
   - Dashboard shows statistics (blocked queries, DNS queries, etc.)
   - URL remains: `https://pihole.chocolandiadc.com`

**Success indicators**:
- ✅ Access time: < 5 seconds (SC-001)
- ✅ Authentication succeeds with authorized email
- ✅ Pi-hole dashboard fully functional
- ✅ HTTPS connection (green padlock in browser)

### 6.2: Test Unauthorized Access

**Security validation**:

1. Open **different browser** (or logout from Google in Incognito mode)
2. Navigate to `https://pihole.chocolandiadc.com`
3. Attempt login with **unauthorized email** (not in `authorized_emails` list)
4. **Expected result**:
   - Access denied error page
   - Message: "You don't have access to this application"
   - Blocked within 2 seconds (SC-002)

**Success indicators**:
- ✅ Unauthorized users blocked immediately
- ✅ Clear error message displayed
- ✅ No access to internal service

### 6.3: Test Session Persistence

1. After successful login (Step 6.1), close browser
2. Reopen browser, navigate to `https://pihole.chocolandiadc.com`
3. **Expected result**:
   - No login prompt (session cookie still valid)
   - Pi-hole dashboard loads immediately
   - Session persists for duration configured in Terraform (default: 24 hours)

### 6.4: Test Tunnel Reconnection (Automatic Recovery)

**Advanced test** (validates SC-003 recovery time):

```bash
# Delete cloudflared pod to simulate failure
kubectl delete pod -n cloudflare-system -l app.kubernetes.io/name=cloudflare-tunnel

# Watch pod restart
kubectl get pods -n cloudflare-system --watch

# Expected sequence:
# 1. Pod terminates (0-5 seconds)
# 2. New pod created by Deployment (5-10 seconds)
# 3. Pod Running status (10-20 seconds)
# 4. Pod Ready (20-30 seconds)

# Press Ctrl+C to stop watching

# Test access again
# Open browser: https://pihole.chocolandiadc.com
# Should load successfully within 30 seconds
```

**Success indicators**:
- ✅ Pod restarts automatically (Kubernetes Deployment controller)
- ✅ Tunnel reconnects to Cloudflare
- ✅ User access restored within 30 seconds (SC-003)
- ✅ No manual intervention required

---

## Step 7: Verify Success Criteria

**Goal**: Validate all measurable outcomes from specification.

### SC-001: Access Time < 5 Seconds

```bash
# Test from external network with curl
time curl -I https://pihole.chocolandiadc.com

# Expected output:
# HTTP/2 302
# location: https://chocolandia.cloudflareaccess.com/cdn-cgi/access/login/...
# ...
# real    0m1.234s  # < 5 seconds

# Measure full page load time
time curl -sL https://pihole.chocolandiadc.com -o /dev/null

# Expected: < 5 seconds for complete redirect and auth flow
```

✅ **Pass**: Response time < 5 seconds

### SC-002: Unauthorized Access Blocked < 2 Seconds

1. Attempt access with unauthorized email
2. Measure time from login to "Access Denied" page
3. **Expected**: Error page appears within 2 seconds

✅ **Pass**: Blocking time < 2 seconds

### SC-003: Recovery Time < 30 Seconds

```bash
# Perform pod deletion test (Step 6.4)
# Measure time from deletion to successful access:

# Start timer
date +%s > /tmp/tunnel_delete_start

# Delete pod
kubectl delete pod -n cloudflare-system -l app.kubernetes.io/name=cloudflare-tunnel

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -n cloudflare-system -l app.kubernetes.io/name=cloudflare-tunnel --timeout=60s

# End timer
date +%s > /tmp/tunnel_delete_end

# Calculate recovery time
echo "Recovery time: $(( $(cat /tmp/tunnel_delete_end) - $(cat /tmp/tunnel_delete_start) )) seconds"

# Expected: < 30 seconds
```

✅ **Pass**: Recovery time < 30 seconds

### SC-004: Zero Public Ports Exposed

```bash
# From external network, scan your public IP
# Option 1: Use nmap (if installed)
nmap -p 1-10000 <your-public-ip>

# Option 2: Use online port scanner
# Navigate to: https://www.yougetsignal.com/tools/open-ports/
# Enter your public IP

# Expected result: No open ports (except maybe 80/443 if you have other services)
# Cloudflare Tunnel uses outbound connection only (no inbound ports)
```

✅ **Pass**: No public ports exposed

### SC-005: Multiple Services Accessible

```bash
# If you enabled additional services in terraform.tfvars, test each:

# Test Grafana (if enabled)
curl -I https://grafana.chocolandiadc.com

# Test Homepage (if enabled)
curl -I https://home.chocolandiadc.com

# Expected: All services accessible through Cloudflare Access
```

✅ **Pass**: All enabled services accessible

### SC-006: Infrastructure Reproducibility (NEW)

**Critical test**: Verify infrastructure can be torn down and recreated identically.

```bash
# Destroy all infrastructure
tofu destroy

# Review plan (should show all resources being destroyed)
# Type 'yes' to confirm

# Expected output:
# Destroy complete! Resources: 12 destroyed.

# Verify cleanup
kubectl get namespace cloudflare-system
# Expected: Error: namespaces "cloudflare-system" not found

# Recreate infrastructure
tofu apply

# Type 'yes' to confirm

# Expected output:
# Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

# Test access again
curl -I https://pihole.chocolandiadc.com
# Expected: HTTP 302 redirect to Cloudflare Access (same as before)
```

✅ **Pass**: Infrastructure can be destroyed and recreated identically

**Summary**:
- ✅ SC-001: Access time < 5 seconds
- ✅ SC-002: Unauthorized blocking < 2 seconds
- ✅ SC-003: Recovery time < 30 seconds
- ✅ SC-004: Zero public ports exposed
- ✅ SC-005: Multiple services routable
- ✅ SC-006: Infrastructure reproducible via `tofu destroy && tofu apply`

✅ **All success criteria met**: Feature is fully functional!

---

## Step 8: Commit Infrastructure Code

**Goal**: Version control the infrastructure configuration.

⚠️ **CRITICAL**: Ensure `terraform.tfvars` is NOT committed (contains secrets).

```bash
# Navigate to repo root
cd /Users/cbenitez/chocolandia_kube

# Verify terraform.tfvars is excluded
git status | grep terraform.tfvars
# Expected: No output (file excluded by .gitignore)

# If it appears in git status, DO NOT COMMIT
# Add to .gitignore immediately:
echo "terraform.tfvars" >> .gitignore

# Check for uncommitted changes (as per CLAUDE.md guidelines)
git status

# Expected files to commit:
# - terraform/modules/cloudflare-tunnel/ (new module)
# - terraform/modules/cloudflare-access/ (new module)
# - terraform/environments/chocolandiadc-mvp/*.tf (environment config)
# - terraform/environments/chocolandiadc-mvp/terraform.tfvars.example (example vars, NO secrets)
# - specs/004-cloudflare-zerotrust/ (documentation)

# Add new files
git add terraform/modules/cloudflare-tunnel/
git add terraform/modules/cloudflare-access/
git add terraform/environments/chocolandiadc-mvp/*.tf
git add terraform/environments/chocolandiadc-mvp/terraform.tfvars.example
git add specs/004-cloudflare-zerotrust/

# Commit with detailed message
git commit -m "feat: Add Cloudflare Zero Trust Tunnel via Terraform

Deploy complete Cloudflare Zero Trust infrastructure as code:

Infrastructure Components:
- Cloudflare Tunnel (remotely-managed connector)
- Cloudflare Access (Zero Trust authentication)
- Google OAuth identity provider integration
- DNS records (CNAME to tunnel endpoint)
- Kubernetes resources (Namespace, Secret, Deployment)

Terraform Modules:
- terraform/modules/cloudflare-tunnel/
  - Tunnel creation and configuration
  - Kubernetes deployment (cloudflared)
  - Health checks and resource limits
- terraform/modules/cloudflare-access/
  - Identity provider (Google OAuth)
  - Access applications (per-service policies)
  - Email-based authorization rules

Environment Configuration:
- terraform/environments/chocolandiadc-mvp/
  - Variables: API token, Account/Zone IDs, OAuth credentials
  - Services: Pi-hole, Grafana (future)
  - Authorized emails: cbenitez@gmail.com

Deployed Services:
- pihole.chocolandiadc.com → pihole-web.default.svc.cluster.local:80

Security Features:
- Zero public ports exposed (outbound tunnel only)
- Google OAuth authentication required
- Email-based access control
- 24-hour session duration
- TLS encryption end-to-end

Success Criteria Validated:
✅ SC-001: Access time < 5 seconds
✅ SC-002: Unauthorized blocking < 2 seconds
✅ SC-003: Recovery time < 30 seconds
✅ SC-004: Zero public ports exposed
✅ SC-005: Multiple services routable
✅ SC-006: Infrastructure reproducible (tofu destroy && apply)

Key Benefits:
- Single command deployment (tofu apply)
- Zero manual dashboard configuration
- Full infrastructure versioning in Git
- Reproducible via tofu destroy && tofu apply
- All changes tracked in commit history

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to remote (after verifying no uncommitted secrets)
git push origin main
```

**Expected Result**: Infrastructure code committed to Git, secrets excluded, all changes tracked.

---

## Troubleshooting

### Issue: Terraform apply fails with authentication error

**Symptoms**:
```bash
tofu apply

# Error output:
# Error: failed to verify Cloudflare API token
# Authentication error: Invalid request headers (6003)
```

**Diagnosis**:
```bash
# Verify API token format
cat terraform.tfvars | grep cloudflare_api_token
# Should be 40-character alphanumeric string (no quotes inside the value)

# Test API token manually
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Expected response:
# {"result":{"id":"...","status":"active"},"success":true}
```

**Solutions**:
1. **Invalid token format**: Regenerate token in Cloudflare Dashboard (Step 1)
2. **Expired token**: Create new token with no TTL or longer expiration
3. **Insufficient permissions**: Verify token has all required permissions (Step 1.2)
4. **Copy-paste error**: Ensure no extra spaces or quotes in `terraform.tfvars`

---

### Issue: DNS records not created

**Symptoms**:
```bash
dig pihole.chocolandiadc.com

# Output:
# ;; ANSWER SECTION:
# (empty - no records found)
```

**Diagnosis**:
```bash
# Check Terraform output for DNS record creation
tofu output dns_records

# Check Zone ID matches your domain
tofu output | grep zone_id

# Verify Zone ID in Cloudflare Dashboard
# Dashboard → Domain → Overview → Zone ID (API section)
```

**Solutions**:
1. **Zone ID mismatch**: Update `cloudflare_zone_id` in `terraform.tfvars` with correct value from Step 2
2. **Domain not managed by Cloudflare**: Transfer domain nameservers to Cloudflare
3. **Terraform apply failed**: Check `tofu apply` output for DNS resource creation errors
4. **DNS propagation delay**: Wait 2-5 minutes and retry `dig` command

---

### Issue: Access policies not working

**Symptoms**:
- Can access `https://pihole.chocolandiadc.com` but not prompted for authentication
- OR: Authentication succeeds but still get "Access Denied"

**Diagnosis**:
```bash
# Check if Access application was created
tofu output access_applications

# Verify OAuth client ID in terraform.tfvars
cat terraform.tfvars | grep google_oauth_client_id

# Check Cloudflare dashboard:
# Access → Applications → Should show "Pi-hole Admin Dashboard"
# Settings → Authentication → Should show "Google OAuth"
```

**Solutions**:
1. **OAuth client ID mismatch**: Verify Client ID in `terraform.tfvars` matches Google Cloud Console (Step 3.4)
2. **Authorized redirect URIs incorrect**: Update Google OAuth client with correct Cloudflare team domain
3. **Email not in authorized list**: Add email to `authorized_emails` in `terraform.tfvars`, reapply
4. **Google OAuth consent screen in Testing mode**: Add user to "Test users" list (Step 3.2)
5. **Terraform apply partially failed**: Run `tofu apply` again to create missing resources

---

### Issue: Pod stays in `Pending` status

**Symptoms**:
```bash
kubectl get pods -n cloudflare-system
# NAME                          READY   STATUS    RESTARTS   AGE
# cloudflared-xxxxxxxxxx-xxxxx   0/1     Pending   0          5m
```

**Diagnosis**:
```bash
kubectl describe pod -n cloudflare-system <pod-name>

# Look for Events section, common causes:
# - "Insufficient cpu" → Node resources exhausted
# - "Insufficient memory" → Node resources exhausted
# - "No nodes available" → Scheduling constraints not met
```

**Solutions**:
1. **Node resources exhausted**: Free up resources (delete unused pods) or add nodes
2. **Resource requests too high**: Reduce `cpu_request` / `memory_request` in Terraform module variables
3. **Node affinity/taints**: Remove node selectors or add tolerations in Terraform configuration

---

### Issue: Pod restarts frequently (`CrashLoopBackOff`)

**Symptoms**:
```bash
kubectl get pods -n cloudflare-system
# NAME                          READY   STATUS             RESTARTS   AGE
# cloudflared-xxxxxxxxxx-xxxxx   0/1     CrashLoopBackOff   5          10m
```

**Diagnosis**:
```bash
kubectl logs -n cloudflare-system deployment/cloudflared --tail=100

# Common error messages:
# - "Invalid tunnel token" → Token format incorrect or expired
# - "Unable to reach origin service" → Kubernetes DNS issue
# - "Failed to register tunnel" → Cloudflare API connectivity issue
```

**Solutions**:
1. **Invalid tunnel token**:
   - Check Terraform output: `tofu output tunnel_id`
   - Verify tunnel exists in Cloudflare Dashboard
   - Recreate tunnel via Terraform: `tofu destroy -target=cloudflare_tunnel.main && tofu apply`

2. **Kubernetes DNS issues**:
   - Verify CoreDNS running: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
   - Restart CoreDNS: `kubectl rollout restart deployment/coredns -n kube-system`

3. **OOMKilled (memory limit too low)**:
   - Check pod events: `kubectl describe pod -n cloudflare-system <pod-name>`
   - Increase memory limit in Terraform: `memory_limit = "256Mi"`
   - Reapply: `tofu apply`

---

### Issue: 502 Bad Gateway when accessing service

**Symptoms**:
- Cloudflare Access authentication succeeds
- After redirect, see "502 Bad Gateway" error

**Diagnosis**:
```bash
# Check if internal service is running
kubectl get svc -n default pihole-web
kubectl get pods -n default -l app=pihole

# Check service endpoint
kubectl get endpoints -n default pihole-web

# Verify ingress rule configuration in Terraform
cat terraform/environments/chocolandiadc-mvp/terraform.tfvars | grep -A 5 "services ="
```

**Solutions**:
1. **Internal service not running**:
   - Start Pi-hole: Deploy Pi-hole via Terraform or Helm
   - Verify service exists: `kubectl get svc pihole-web`

2. **Service DNS name mismatch**:
   - Update `services` map in `terraform.tfvars`
   - Format: `http://<service-name>.<namespace>.svc.cluster.local:<port>`
   - Example: `http://pihole-web.default.svc.cluster.local:80`
   - Reapply: `tofu apply`

3. **Service port incorrect**:
   - Check service port: `kubectl describe svc pihole-web -n default`
   - Update port in `terraform.tfvars` → `services.pihole.service`
   - Reapply: `tofu apply`

4. **Tunnel not routing correctly**:
   - Check cloudflared logs: `kubectl logs -n cloudflare-system deployment/cloudflared`
   - Verify tunnel configuration: `tofu output tunnel_config`

---

### Issue: Health check failing (liveness probe)

**Symptoms**:
```bash
kubectl describe pod -n cloudflare-system <pod-name>

# Events:
# Warning  Unhealthy  2m (x3 over 3m)  kubelet  Liveness probe failed: HTTP probe failed with statuscode: 503
```

**Diagnosis**:
```bash
# Check /ready endpoint manually
kubectl port-forward -n cloudflare-system deployment/cloudflared 2000:2000

# In another terminal:
curl http://localhost:2000/ready

# Should return HTTP 200 if tunnel connected
# HTTP 503 if tunnel not connected
```

**Solutions**:
1. **Tunnel not connecting**: Check logs for connection errors (see "CrashLoopBackOff" troubleshooting)
2. **Health check too aggressive**: Increase probe timings in Terraform module:
   ```hcl
   liveness_probe {
     initial_delay_seconds = 30  # Increase from 10
     period_seconds        = 30  # Increase from 10
   }
   ```
   - Reapply: `tofu apply`

3. **Port 2000 blocked**: Verify no network policies blocking metrics port

---

## Next Steps

### Immediate (MVP Complete):
- ✅ Tunnel deployed and connected
- ✅ Authentication working with Google OAuth
- ✅ Pi-hole accessible remotely
- ✅ **Zero manual dashboard configuration**
- ✅ **All infrastructure in Terraform**

### Short-Term Enhancements:
1. **Add more services** (edit `terraform.tfvars` → `services` map):
   ```hcl
   services = {
     pihole = { ... }
     grafana = {
       hostname = "grafana.chocolandiadc.com"
       service  = "http://grafana.monitoring.svc.cluster.local:3000"
       enabled  = true
     }
     homepage = {
       hostname = "home.chocolandiadc.com"
       service  = "http://homepage.default.svc.cluster.local:8080"
       enabled  = true
     }
   }
   ```
   - Run: `tofu apply`

2. **Create Access Groups for easier user management**:
   - Add `cloudflare_access_group` resource in Terraform
   - Reference group in Access policies instead of individual emails

3. **Increase replica count for high availability**:
   - Update `replica_count = 2` in Terraform configuration
   - Run: `tofu apply`

### Long-Term Enhancements:
1. **Prometheus metrics integration**:
   - Scrape cloudflared `/metrics` endpoint (port 2000)
   - Create Grafana dashboard for tunnel status

2. **Automated testing**:
   - Add `terraform test` for validation
   - CI/CD pipeline for `tofu plan` on pull requests

3. **Remote state backend**:
   - Migrate from local `terraform.tfstate` to S3/Cloudflare R2
   - Enable state locking for team collaboration

4. **Secrets management**:
   - Integrate with Vault or AWS Secrets Manager
   - Auto-rotate API tokens and OAuth credentials

### Future Enhancements (Out of Scope):
- End-to-end TLS (cert-manager integration)
- Custom domains (multiple Cloudflare accounts)
- Audit log export (SIEM integration)
- Path-based routing (nginx-ingress controller)

---

## Key Advantages of Terraform Approach

✅ **Zero manual dashboard configuration** - everything in code
✅ **Single `tofu apply` command** deploys entire infrastructure
✅ **Infrastructure can be torn down and recreated identically** via `tofu destroy && tofu apply`
✅ **All changes tracked in Git history** (except sensitive variables)
✅ **Faster deployment** - 30-45 minutes vs 45-60 minutes (fewer manual steps)
✅ **Version control** - infrastructure changes are reviewable in pull requests
✅ **Reproducible** - same configuration produces identical infrastructure every time
✅ **Testable** - can validate configuration before deployment with `tofu plan`

---

## Reference Links

- **Cloudflare Terraform Provider**: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs
- **Cloudflare Tunnel Terraform Resource**: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/tunnel
- **Cloudflare Access Terraform Resources**: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/access_application
- **OpenTofu Kubernetes Provider**: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
- **Cloudflare API Documentation**: https://developers.cloudflare.com/api/
- **Google OAuth Setup**: https://developers.google.com/identity/protocols/oauth2

---

## Summary

You've successfully deployed Cloudflare Zero Trust Tunnel to your K3s cluster using 100% Terraform-managed infrastructure!

**What you built**:
- Secure remote access to internal services (no exposed public ports)
- Google OAuth authentication via Cloudflare Access
- Automatic tunnel reconnection on pod failure
- Production-ready resource limits and health checks
- **Fully automated Infrastructure as Code** using OpenTofu/Terraform

**Key metrics achieved**:
- Access time: < 5 seconds (SC-001)
- Unauthorized blocking: < 2 seconds (SC-002)
- Recovery time: < 30 seconds (SC-003)
- Public ports exposed: 0 (SC-004)
- Services accessible: 2+ (SC-005)
- **Infrastructure reproducibility: 100%** (SC-006)

**Infrastructure as Code benefits**:
- ✅ **Zero manual configuration** - everything declared in `.tf` files
- ✅ **Single command deployment** - `tofu apply` creates all resources
- ✅ **Version controlled** - all changes tracked in Git
- ✅ **Reproducible** - `tofu destroy && tofu apply` recreates identical infrastructure
- ✅ **Testable** - `tofu plan` validates before deployment
- ✅ **Auditable** - commit history shows all infrastructure changes

**Learning outcomes**:
- Zero Trust Network Access (ZTNA) principles
- Cloudflare Tunnel architecture (outbound-only connections)
- Terraform provider usage (Cloudflare + Kubernetes)
- Infrastructure as Code best practices
- Secrets management in Terraform (sensitive variables)
- Kubernetes Secret management for tunnel tokens
- Health check configuration for automatic recovery

You can now access your homelab services securely from anywhere in the world - all managed by code!
