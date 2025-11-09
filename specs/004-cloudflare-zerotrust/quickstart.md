# Quickstart Guide: Cloudflare Zero Trust VPN Access

**Feature**: 004-cloudflare-zerotrust
**Target**: K3s cluster deployment with secure remote access
**Time**: ~45-60 minutes (first-time setup)

## Prerequisites

Before starting, ensure you have:

- ✅ **K3s cluster running** (3 control-plane + 1 worker node)
- ✅ **Cloudflare account** (free tier sufficient)
- ✅ **Domain name managed by Cloudflare DNS** (e.g., `example.com`)
- ✅ **Google Cloud Console access** (for OAuth client creation)
- ✅ **kubectl configured** to access your K3s cluster
- ✅ **OpenTofu 1.6+** installed locally
- ✅ **Internal service running** (e.g., Pi-hole at `pihole-web.default.svc.cluster.local:80`)

**Verification Commands**:
```bash
# Check cluster access
kubectl get nodes

# Check OpenTofu version
tofu version  # Should show 1.6.x or higher

# Verify domain DNS managed by Cloudflare
dig NS example.com  # Should show Cloudflare nameservers
```

---

## Step 1: Create Cloudflare Tunnel (Dashboard)

**Goal**: Create a remotely-managed tunnel and obtain the tunnel token.

1. Navigate to **Cloudflare Zero Trust Dashboard**:
   - URL: `https://one.dash.cloudflare.com/`
   - Login with your Cloudflare account

2. Go to **Networks** → **Tunnels**:
   - Click **Create a tunnel**
   - Select connector type: **Cloudflared**

3. Configure tunnel:
   - Tunnel name: `chocolandia-k3s-tunnel`
   - Click **Save tunnel**

4. **Copy tunnel token**:
   - You'll see a command like:
     ```bash
     cloudflared tunnel run --token eyJhIjoiXXXXXXXXXXXXXXXXXXX...
     ```
   - Copy the token value (starts with `eyJhIjo...`)
   - ⚠️ **IMPORTANT**: Store this securely, you'll need it in Step 3

5. **Skip connector installation** (we'll deploy via Kubernetes):
   - Click **Next** to proceed to routing configuration
   - Leave routing empty for now (we'll configure in Step 6)

**Expected Result**: Tunnel created but showing "Inactive" status (will become active after K8s deployment).

---

## Step 2: Configure Google OAuth for Cloudflare Access

**Goal**: Set up Google as authentication provider for Cloudflare Access.

### 2.1: Create Google OAuth Client

1. Navigate to **Google Cloud Console**:
   - URL: `https://console.cloud.google.com/apis/credentials`
   - Create new project: `chocolandia-homelab-access`

2. Configure OAuth Consent Screen:
   - Go to **OAuth consent screen**
   - User Type: **External**
   - App name: `Chocolandia Homelab`
   - User support email: Your Gmail address
   - Developer contact: Your Gmail address
   - Scopes: Default (email, profile, openid)
   - Test users: Add your Gmail address and any authorized users
   - Publishing status: **Testing** (for limited access) or **Production** (after verification)

3. Create OAuth 2.0 Client ID:
   - Go to **Credentials** → **Create Credentials** → **OAuth client ID**
   - Application type: **Web application**
   - Name: `Cloudflare Access OAuth Client`
   - Authorized JavaScript origins:
     ```
     https://<your-team-name>.cloudflareaccess.com
     ```
     *(Replace `<your-team-name>` with your Cloudflare Zero Trust team name, found in Zero Trust → Settings → Custom Pages)*
   - Authorized redirect URIs:
     ```
     https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/callback
     ```
   - Click **Create**

4. **Copy credentials**:
   - Client ID: `1234567890-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com`
   - Client Secret: `GOCSPX-XXXXXXXXXXXXXXXXXXXXXXXX`
   - ⚠️ **Store securely**, you'll need these in Step 2.2

### 2.2: Add Google OAuth to Cloudflare Access

1. Navigate to **Cloudflare Zero Trust** → **Settings** → **Authentication**:
   - Click **Login methods** tab
   - Click **Add new**

2. Select **Google**:
   - Provider name: `Google OAuth (Personal Gmail)`
   - App ID (Client ID): Paste from Step 2.1
   - Client secret: Paste from Step 2.1
   - Click **Save**

3. **Test login method**:
   - Click **Test** next to the newly added Google OAuth provider
   - You should be redirected to Google login
   - After successful login, return to Cloudflare dashboard

**Expected Result**: Google OAuth appears in login methods list with "Active" status.

---

## Step 3: Deploy Cloudflare Tunnel to K3s Cluster

**Goal**: Deploy cloudflared connector as Kubernetes Deployment using OpenTofu.

### 3.1: Prepare OpenTofu Configuration

1. **Navigate to OpenTofu environment**:
   ```bash
   cd terraform/environments/chocolandiadc-mvp/
   ```

2. **Create terraform.tfvars file** (NOT committed to Git):
   ```bash
   cat > terraform.tfvars <<'EOF'
   # Cloudflare Tunnel Configuration
   cloudflare_tunnel_token = "eyJhIjoiXXXXXXXXXXXXXXXXXXX..."  # From Step 1
   cloudflare_tunnel_name  = "chocolandia-k3s-tunnel"

   # Kubernetes Configuration
   kubeconfig_path = "./kubeconfig"  # Path to your K3s kubeconfig

   # Email for cbenitez
   commit_email = "cbenitez@gmail.com"
   EOF
   ```
   - Replace `eyJhIjoiXXX...` with your actual tunnel token from Step 1
   - Adjust `kubeconfig_path` if your kubeconfig is elsewhere

3. **Verify `.gitignore` excludes secrets**:
   ```bash
   grep -q "terraform.tfvars" ../../.gitignore || echo "terraform.tfvars" >> ../../.gitignore
   ```

### 3.2: Create OpenTofu Module (if not exists)

⚠️ **Skip this step if module already exists** (check `terraform/modules/cloudflare-tunnel/`).

```bash
# Create module directory structure
mkdir -p ../../modules/cloudflare-tunnel/manifests

# Navigate to module directory
cd ../../modules/cloudflare-tunnel/
```

**Create `variables.tf`**:
```hcl
variable "tunnel_token" {
  description = "Cloudflare Tunnel token (from dashboard)"
  type        = string
  sensitive   = true
}

variable "tunnel_name" {
  description = "Human-readable tunnel name"
  type        = string
  default     = "k3s-tunnel"
}

variable "namespace" {
  description = "Kubernetes namespace for tunnel deployment"
  type        = string
  default     = "cloudflare-system"
}

variable "replica_count" {
  description = "Number of cloudflared pod replicas"
  type        = number
  default     = 1
}

variable "image" {
  description = "cloudflared container image"
  type        = string
  default     = "cloudflare/cloudflared:latest"
}

variable "cpu_request" {
  description = "CPU resource request"
  type        = string
  default     = "100m"
}

variable "cpu_limit" {
  description = "CPU resource limit"
  type        = string
  default     = "500m"
}

variable "memory_request" {
  description = "Memory resource request"
  type        = string
  default     = "100Mi"
}

variable "memory_limit" {
  description = "Memory resource limit"
  type        = string
  default     = "200Mi"
}
```

**Create `main.tf`**:
```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Create namespace
resource "kubernetes_namespace" "cloudflare_system" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "cloudflare-tunnel"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }
}

# Store tunnel token as Secret
resource "kubernetes_secret" "cloudflared_token" {
  metadata {
    name      = "cloudflared-token"
    namespace = kubernetes_namespace.cloudflare_system.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "cloudflare-tunnel"
    }
  }

  data = {
    token = var.tunnel_token
  }

  type = "Opaque"
}

# Deploy cloudflared connector
resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.cloudflare_system.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "cloudflare-tunnel"
      "app.kubernetes.io/version" = "latest"
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "cloudflare-tunnel"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "cloudflare-tunnel"
        }
      }

      spec {
        container {
          name  = "cloudflared"
          image = var.image

          args = [
            "tunnel",
            "--no-autoupdate",
            "run",
            "--token",
            "$(TUNNEL_TOKEN)"
          ]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.cloudflared_token.metadata[0].name
                key  = "token"
              }
            }
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 2
          }
        }

        restart_policy = "Always"
      }
    }
  }
}
```

**Create `outputs.tf`**:
```hcl
output "namespace" {
  description = "Kubernetes namespace where tunnel is deployed"
  value       = kubernetes_namespace.cloudflare_system.metadata[0].name
}

output "deployment_name" {
  description = "Kubernetes deployment name"
  value       = kubernetes_deployment.cloudflared.metadata[0].name
}

output "tunnel_name" {
  description = "Cloudflare Tunnel name"
  value       = var.tunnel_name
}
```

### 3.3: Reference Module in Environment Config

```bash
# Navigate back to environment directory
cd ../../environments/chocolandiadc-mvp/
```

**Create `cloudflare-tunnel.tf`**:
```hcl
module "cloudflare_tunnel" {
  source = "../../modules/cloudflare-tunnel"

  tunnel_token  = var.cloudflare_tunnel_token
  tunnel_name   = var.cloudflare_tunnel_name
  namespace     = "cloudflare-system"
  replica_count = 1  # MVP: single replica, P3: increase to 2-3

  # Resource limits from research
  cpu_request    = "100m"
  cpu_limit      = "500m"
  memory_request = "100Mi"
  memory_limit   = "200Mi"
}

output "tunnel_namespace" {
  description = "Cloudflare Tunnel namespace"
  value       = module.cloudflare_tunnel.namespace
}

output "tunnel_deployment" {
  description = "Cloudflare Tunnel deployment name"
  value       = module.cloudflare_tunnel.deployment_name
}
```

**Update `variables.tf`** (add tunnel variables):
```hcl
variable "cloudflare_tunnel_token" {
  description = "Cloudflare Tunnel token from dashboard"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_name" {
  description = "Cloudflare Tunnel name"
  type        = string
  default     = "chocolandia-k3s-tunnel"
}
```

### 3.4: Deploy with OpenTofu

```bash
# Initialize OpenTofu (download providers)
tofu init

# Validate configuration
tofu validate

# Format code
tofu fmt -recursive

# Preview changes
tofu plan

# Review plan output carefully:
# - Should show: Create namespace, Secret, Deployment
# - Secret data should show <sensitive>
# - No resources being destroyed

# Apply changes
tofu apply

# Type 'yes' when prompted
```

**Expected Output**:
```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:
tunnel_deployment = "cloudflared"
tunnel_namespace = "cloudflare-system"
```

---

## Step 4: Verify Tunnel Connection

**Goal**: Confirm cloudflared pod is running and connected to Cloudflare.

### 4.1: Check Pod Status

```bash
# Set kubeconfig (if not already)
export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig

# Check pod status
kubectl get pods -n cloudflare-system

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# cloudflared-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

**Troubleshooting**:
- If `STATUS` is `Pending`: Check node resources (`kubectl describe nodes`)
- If `STATUS` is `CrashLoopBackOff`: Check logs (`kubectl logs -n cloudflare-system deployment/cloudflared`)
- If `READY` is `0/1`: Health check may be failing, check logs

### 4.2: Check Tunnel Connection Logs

```bash
# View cloudflared logs
kubectl logs -n cloudflare-system deployment/cloudflared --tail=50

# Look for success messages:
# "Connection ... registered connIndex=0"
# "Registered tunnel connection"
# "Tunnel is now connected"
```

**Success Indicators**:
- ✅ `"Registered tunnel connection"` appears in logs
- ✅ `"Tunnel is now connected"` or `"Serving tunnel..."` message
- ✅ No error messages about authentication or connectivity

### 4.3: Verify in Cloudflare Dashboard

1. Navigate to **Cloudflare Zero Trust** → **Networks** → **Tunnels**
2. Find `chocolandia-k3s-tunnel` in the list
3. Status should show: **Healthy** (green indicator)
4. Connectors: Should show **1 active** (or N if multiple replicas)

**Expected Result**: Tunnel status "Healthy" with 1 active connector.

---

## Step 5: Configure Ingress Routes (Dashboard)

**Goal**: Route public hostnames to internal Kubernetes services.

### 5.1: Add Pi-hole Public Hostname

1. In Cloudflare Zero Trust → Networks → Tunnels:
   - Click on `chocolandia-k3s-tunnel`
   - Go to **Public Hostname** tab
   - Click **Add a public hostname**

2. Configure Pi-hole route:
   - **Subdomain**: `pihole`
   - **Domain**: `example.com` (select your domain)
   - **Path**: Leave empty (full domain routing)
   - **Type**: `HTTP`
   - **URL**: `pihole-web.default.svc.cluster.local:80`
   - **TLS Verification**: Disabled (unchecked)
   - Click **Save hostname**

3. **Verify DNS automatic creation**:
   - Cloudflare automatically creates CNAME record: `pihole.example.com` → `<tunnel-id>.cfargotunnel.com`
   - Check: Cloudflare Dashboard → DNS → Records → Look for `pihole` CNAME

### 5.2: (Optional) Add Additional Services

Repeat Step 5.1 for other services:

**Example: Grafana Dashboard**
- Subdomain: `grafana`
- Domain: `example.com`
- URL: `grafana.monitoring.svc.cluster.local:3000`

**Example: Homepage**
- Subdomain: `home`
- Domain: `example.com`
- URL: `homepage.default.svc.cluster.local:8080`

**Expected Result**: 2-5 public hostnames configured, all showing green "Active" status.

---

## Step 6: Create Cloudflare Access Policy

**Goal**: Protect Pi-hole with Google OAuth authentication.

### 6.1: Create Application

1. Navigate to **Cloudflare Zero Trust** → **Access** → **Applications**:
   - Click **Add an application**
   - Select **Self-hosted**

2. Configure application:
   - **Application name**: `Pi-hole Admin Dashboard`
   - **Session Duration**: `24 hours`
   - **Application domain**:
     - Subdomain: `pihole`
     - Domain: `example.com`
   - **App Launcher visibility**: Hidden (for homelab, not needed in launcher)
   - Click **Next**

### 6.2: Create Access Policy

3. Configure policy (Policy 1 - Allow):
   - **Policy name**: `Allow Homelab Admins`
   - **Action**: `Allow`
   - **Session duration**: `24 hours` (inherits from application default)
   - **Configure rules**:
     - **Selector**: `Emails`
     - **Value**: Enter your Gmail address (e.g., `admin@gmail.com`)
     - Click **+ Add another** to add more authorized emails:
       - `family-member@gmail.com`
       - `friend@gmail.com`
   - Click **Next**

4. **Additional settings** (optional):
   - CORS settings: Default (leave empty for MVP)
   - Cookie settings: Default
   - Click **Add application**

### 6.3: (Optional) Create Access Group for Easier Management

**Recommended for 3+ users**:

1. Navigate to **Access** → **Access Groups**:
   - Click **Add a Group**
   - Group name: `Homelab Admins`
   - Criteria: `Emails`
   - Values: List all authorized emails
   - Click **Save**

2. Update Access Policy to use group:
   - Edit policy created in Step 6.2
   - Change selector from `Emails` to `Access Groups`
   - Select `Homelab Admins`
   - Save changes

**Benefit**: Easier to add/remove users (edit group once, applies to all applications).

---

## Step 7: Test Remote Access

**Goal**: Verify end-to-end connectivity and authentication from external network.

### 7.1: Test from External Network

⚠️ **IMPORTANT**: Test from device NOT on your home network (use mobile data, coffee shop WiFi, or VPN to simulate external access).

1. **Open browser** (Incognito/Private mode recommended):
   - Navigate to: `https://pihole.example.com`

2. **Expected flow**:
   - You're redirected to Cloudflare Access login page
   - Click **Google** (or it may redirect automatically if only one method)
   - Authenticate with your Google account
   - After successful login, redirected back to Pi-hole admin dashboard

3. **Verify Pi-hole loads**:
   - Pi-hole admin interface should appear
   - Dashboard should show statistics (blocked queries, etc.)
   - ✅ **SUCCESS**: You're accessing internal service without exposing public ports!

### 7.2: Test Unauthorized Access

**Security validation**:

1. Open **different browser** (or logout from Google in Incognito mode)
2. Navigate to `https://pihole.example.com`
3. Attempt login with **unauthorized email** (not in Access policy)
4. **Expected result**: Access denied error page
   - Message: "You don't have access to this application"
   - ✅ **SUCCESS**: Unauthorized users are blocked

### 7.3: Test Session Persistence

1. After successful login (Step 7.1), close browser
2. Reopen browser, navigate to `https://pihole.example.com`
3. **Expected result**: No login prompt (session token still valid for 24 hours)
4. Pi-hole dashboard loads immediately

### 7.4: Test Tunnel Reconnection (P3 Story)

**Advanced test** (validates automatic recovery):

```bash
# Delete cloudflared pod
kubectl delete pod -n cloudflare-system -l app.kubernetes.io/name=cloudflare-tunnel

# Watch pod restart
kubectl get pods -n cloudflare-system --watch

# Expected: New pod created within 10 seconds, Running status within 30 seconds

# Test access again
# Open browser: https://pihole.example.com
# Should load successfully after ~30 seconds
```

**Expected Result**: Pod restarts automatically, tunnel reconnects, user access restored within 30 seconds (meets SC-003 success criteria).

---

## Step 8: Verify Success Criteria

Validate all measurable outcomes from specification:

### SC-001: Access Time < 5 Seconds
```bash
# Test from external network with curl
time curl -I https://pihole.example.com

# Expected: HTTP redirect to Cloudflare Access (3xx status)
# Time: < 5 seconds (usually < 2 seconds)
```

### SC-002: Unauthorized Access Blocked < 2 Seconds
- Attempt access with unauthorized email
- Access denied page should appear within 2 seconds

### SC-003: Recovery Time < 30 Seconds
- Perform Step 7.4 (pod deletion test)
- Measure time from deletion to successful access
- Should be < 30 seconds

### SC-004: Zero Public Ports Exposed
```bash
# From external network, scan your public IP (use nmap or online port scanner)
# Example: nmap -p 1-10000 <your-public-ip>

# Expected result: No open ports (except maybe 80/443 if you have other services)
# Cloudflare Tunnel uses outbound connection only (no inbound ports)
```

### SC-005: Multiple Services Accessible
- If you added additional services in Step 5.2, test each:
  - `https://grafana.example.com`
  - `https://home.example.com`
- All should be accessible through authentication

✅ **All success criteria met**: Feature is fully functional!

---

## Step 9: Commit Infrastructure Code

**Goal**: Version control the infrastructure configuration.

```bash
# Navigate to repo root
cd /Users/cbenitez/chocolandia_kube

# Check git status
git status

# Add new files
git add terraform/modules/cloudflare-tunnel/
git add terraform/environments/chocolandiadc-mvp/cloudflare-tunnel.tf
git add specs/004-cloudflare-zerotrust/

# Verify terraform.tfvars is NOT staged (should be ignored)
git status | grep terraform.tfvars
# Expected: No output (file excluded by .gitignore)

# Commit with detailed message
git commit -m "feat: Add Cloudflare Zero Trust Tunnel deployment

Deploy cloudflared connector to K3s cluster for secure remote access:

Components:
- OpenTofu module: terraform/modules/cloudflare-tunnel/
- Kubernetes resources: Namespace, Secret, Deployment
- Health checks: liveness/readiness probes on /ready:2000
- Resource limits: 100m-500m CPU, 100Mi-200Mi memory
- Authentication: Google OAuth via Cloudflare Access

Ingress routes configured:
- pihole.example.com -> pihole-web.default.svc.cluster.local:80

Access policies:
- Email-based whitelist for homelab admins
- 24-hour session duration

Success criteria validated:
✅ SC-001: Access time < 5 seconds
✅ SC-002: Unauthorized blocking < 2 seconds
✅ SC-003: Recovery time < 30 seconds
✅ SC-004: Zero public ports exposed
✅ SC-005: Multiple services routable

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Troubleshooting

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
# - "Insufficient cpu" -> Node resources exhausted
# - "Insufficient memory" -> Node resources exhausted
# - "No nodes available" -> Scheduling constraints not met
```

**Solutions**:
- Free up node resources (delete unused pods)
- Reduce resource requests in module variables
- Add node affinity/tolerations if needed

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
# - "Invalid tunnel token" -> Token format incorrect or expired
# - "Unable to reach origin service" -> Kubernetes DNS issue
# - "OOMKilled" -> Memory limit too low (check with kubectl describe pod)
```

**Solutions**:

1. **Invalid token**: Recreate tunnel in dashboard, update terraform.tfvars, reapply
2. **DNS issues**: Verify CoreDNS running (`kubectl get pods -n kube-system -l k8s-app=kube-dns`)
3. **OOMKilled**: Increase memory limit in module (`memory_limit = "256Mi"`)

---

### Issue: Tunnel shows "Inactive" in dashboard

**Symptoms**:
- Cloudflare dashboard shows tunnel as "Inactive" or "Down"
- Pod is running (`kubectl get pods` shows `Running`)

**Diagnosis**:
```bash
kubectl logs -n cloudflare-system deployment/cloudflared --tail=50

# Look for:
# - "Connection refused" -> Network connectivity issue
# - "Authentication failed" -> Token mismatch or expired
# - "dial tcp: lookup api.cloudflare.com: no such host" -> DNS resolution failure
```

**Solutions**:

1. **Network connectivity**: Verify nodes can reach internet
   ```bash
   kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- https://api.cloudflare.com
   ```
2. **Token mismatch**: Regenerate tunnel token in dashboard, update Secret
3. **DNS resolution**: Check CoreDNS configuration

---

### Issue: Access denied even with correct email

**Symptoms**:
- Login with Google succeeds
- Cloudflare Access shows "You don't have access to this application"

**Diagnosis**:
1. Check Access policy in dashboard:
   - Navigate to Access → Applications → Pi-hole Admin Dashboard → Policies
   - Verify email address matches exactly (case-sensitive)
   - Check policy is `Allow` action (not `Deny`)

2. Check Google OAuth consent screen:
   - If status is "Testing", verify your email is in "Test users" list
   - If status is "Production", no restrictions apply

**Solutions**:
- Add email to Access policy selector values
- Add email to Google OAuth test users (if in Testing mode)
- Check for typos in email address

---

### Issue: "502 Bad Gateway" when accessing service

**Symptoms**:
- Cloudflare Access authentication succeeds
- After redirect, see "502 Bad Gateway" error

**Diagnosis**:
```bash
# Check if internal service is running
kubectl get svc -n default pihole-web
kubectl get pods -n default -l app=pihole

# Check ingress rule configuration
# In Cloudflare dashboard: Networks → Tunnels → chocolandia-k3s-tunnel → Public Hostnames
# Verify URL matches service DNS name exactly
```

**Solutions**:

1. **Service not running**: Start internal service
2. **DNS name mismatch**: Update ingress rule URL to match Kubernetes service
   - Format: `<service-name>.<namespace>.svc.cluster.local:<port>`
   - Example: `pihole-web.default.svc.cluster.local:80`
3. **Service port wrong**: Verify service port (`kubectl describe svc pihole-web`)

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
```

**Solutions**:

1. **Tunnel not connecting**: Check logs for connection errors (see "Tunnel Inactive" troubleshooting)
2. **Health check too aggressive**: Increase `initial_delay_seconds` or `period_seconds` in module
3. **Port 2000 blocked**: Verify no network policies blocking traffic to port 2000

---

## Next Steps

### Immediate (MVP Complete):
- ✅ Tunnel deployed and connected
- ✅ Authentication working with Google OAuth
- ✅ Pi-hole accessible remotely

### Short-Term Enhancements (P2 Story):
- Add more services to ingress routes (Grafana, Homepage, etc.)
- Create Access Groups for easier user management
- Document additional troubleshooting scenarios

### Long-Term Enhancements (P3 Story):
- Increase replica count to 2-3 for high availability testing
- Add Prometheus metrics integration (scrape cloudflared `/metrics`)
- Create Grafana dashboard for tunnel status
- Migrate ingress rules to Terraform automation (GitOps compliance)

### Future Enhancements (Out of Scope):
- End-to-end TLS (cert-manager integration)
- Path-based routing (nginx-ingress controller)
- Custom domains (multiple Cloudflare accounts)
- Audit log export (SIEM integration)

---

## Reference Links

- **Cloudflare Tunnel Docs**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- **Cloudflare Access Docs**: https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/
- **cloudflared Releases**: https://github.com/cloudflare/cloudflared/releases
- **OpenTofu Kubernetes Provider**: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
- **Google OAuth Setup**: https://developers.google.com/identity/protocols/oauth2

---

## Summary

You've successfully deployed Cloudflare Zero Trust Tunnel to your K3s cluster! 🎉

**What you built**:
- Secure remote access to internal services (no exposed public ports)
- Google OAuth authentication via Cloudflare Access
- Automatic tunnel reconnection on pod failure
- Production-ready resource limits and health checks
- Infrastructure as Code using OpenTofu

**Key metrics achieved**:
- Access time: < 5 seconds
- Unauthorized blocking: < 2 seconds
- Recovery time: < 30 seconds
- Public ports exposed: 0
- Services accessible: 2+ (Pi-hole + future)

**Learning outcomes**:
- Zero Trust Network Access (ZTNA) principles
- Cloudflare Tunnel architecture (outbound-only connections)
- Kubernetes Secret management for sensitive data
- Health check configuration for automatic recovery
- OpenTofu module development and deployment

You can now access your homelab services securely from anywhere in the world! 🌍🔒
