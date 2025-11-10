# Research & Architectural Decisions: Cloudflare Zero Trust VPN Access

**Feature**: 004-cloudflare-zerotrust
**Date**: 2025-11-09
**Status**: Draft

## Context

This research document captures architectural decisions for deploying Cloudflare Zero Trust Tunnel (cloudflared) in the K3s cluster to provide secure remote access to internal services without exposing public ports. The deployment must integrate with Cloudflare Access for authentication, support multiple internal services through a single tunnel, and follow production-ready patterns suitable for a homelab/learning environment.

---

## Decision 1: Tunnel Creation Method - Terraform vs Dashboard

**Question**: Should Cloudflare Tunnels be created using Terraform (IaC) or Dashboard (manual) approach for automated deployment?

**Options Considered**:

1. **Terraform-Managed Tunnels**
   - **Pros**:
     - Full GitOps compliance - tunnel creation in version control
     - Infrastructure as code - no manual dashboard steps
     - Reproducible deployments - `tofu apply` recreates entire infrastructure
     - Automated secret generation - tunnel credentials managed by Terraform
     - Aligns with Constitution Principle II (GitOps Workflow)
     - Single source of truth for all infrastructure
   - **Cons**:
     - Requires Cloudflare API token configuration
     - More complex initial setup vs one-time dashboard click
     - Terraform state contains sensitive tunnel credentials (must be secured)
   - **Implementation**:
     - Use `cloudflare_tunnel` Terraform resource
     - Generate tunnel secret via `random_password` resource
     - Output tunnel token for Kubernetes Secret creation
     - All tunnel lifecycle managed via `tofu apply/destroy`

2. **Dashboard/Remotely-Managed Tunnels**
   - **Pros**:
     - Simpler initial setup - GUI-driven tunnel creation
     - Visual management and monitoring in Zero Trust dashboard
     - No Terraform provider configuration needed
   - **Cons**:
     - Violates GitOps principles - manual dashboard interaction required
     - Not reproducible - tunnel creation not in version control
     - Breaks Constitution Principle II (GitOps Workflow)
     - Manual secret copying from dashboard prone to errors
   - **Implementation**:
     - Create tunnel once in Cloudflare Zero Trust dashboard
     - Manually copy tunnel token to `.tfvars` file
     - Manual cleanup if infrastructure needs to be torn down

3. **CLI/Locally-Managed Tunnels**
   - **Pros**:
     - Full GitOps workflow - tunnel config file version-controlled
     - No dashboard interaction needed
   - **Cons**:
     - Requires cert.pem and credentials.json files
     - Deprecated approach - Cloudflare recommends remotely-managed tunnels
     - More complex Secret management
   - **Implementation**:
     - `cloudflared tunnel create my-tunnel` → generates credentials.json
     - Store credentials.json in Kubernetes Secret

**Decision**: **Terraform-Managed Tunnels (Option 1)**

**Rationale**:
- **Constitution compliance**: Full adherence to Principle II (GitOps Workflow) - zero manual dashboard configuration
- **Infrastructure as code**: Tunnel creation, configuration, and lifecycle entirely in Terraform
- **Reproducibility**: Complete environment can be recreated via `tofu apply` without manual steps
- **Automation**: Tunnel secret automatically generated and managed by Terraform
- **Single source of truth**: All Cloudflare resources (tunnel, DNS, Access policies) in version control
- **Security**: Tunnel credentials never manually copied - generated and stored by Terraform
- **Learning value**: Understanding Terraform provider patterns, API-driven infrastructure management

**Alternatives Considered and Rejected**:
- **Dashboard/manual approach**: Rejected because it violates Constitution Principle II (GitOps Workflow) and requires manual steps that cannot be version-controlled
- **CLI approach**: Rejected because it's the legacy method and requires file-based credential management

**Implementation Notes**:
1. **Tunnel Creation** (Terraform resource):
   ```hcl
   # Generate random tunnel secret
   resource "random_password" "tunnel_secret" {
     length  = 64
     special = false
   }

   # Create Cloudflare Tunnel
   resource "cloudflare_tunnel" "chocolandia_tunnel" {
     account_id = var.cloudflare_account_id
     name       = "chocolandia-k3s-tunnel"
     secret     = base64sha256(random_password.tunnel_secret.result)
   }

   # Output tunnel token for Kubernetes Secret
   output "tunnel_token" {
     value     = cloudflare_tunnel.chocolandia_tunnel.tunnel_token
     sensitive = true
   }

   output "tunnel_id" {
     value = cloudflare_tunnel.chocolandia_tunnel.id
   }
   ```

2. **Kubernetes Secret** (created by Terraform):
   ```hcl
   resource "kubernetes_secret" "cloudflared_token" {
     metadata {
       name      = "cloudflared-token"
       namespace = "cloudflare-system"
     }

     data = {
       token = cloudflare_tunnel.chocolandia_tunnel.tunnel_token
     }

     type = "Opaque"
   }
   ```

3. **Deployment Command**:
   ```yaml
   containers:
   - name: cloudflared
     image: cloudflare/cloudflared:latest
     args:
     - tunnel
     - --no-autoupdate
     - run
     - --token
     - $(TUNNEL_TOKEN)
     env:
     - name: TUNNEL_TOKEN
       valueFrom:
         secretKeyRef:
           name: cloudflared-token
           key: token
   ```

4. **Required Terraform Variables**:
   ```hcl
   variable "cloudflare_account_id" {
     description = "Cloudflare Account ID"
     type        = string
   }

   variable "cloudflare_api_token" {
     description = "Cloudflare API Token with Tunnel:Edit permissions"
     type        = string
     sensitive   = true
   }
   ```

5. **Cloudflare Provider Configuration**:
   ```hcl
   terraform {
     required_providers {
       cloudflare = {
         source  = "cloudflare/cloudflare"
         version = "~> 4.0"
       }
     }
   }

   provider "cloudflare" {
     api_token = var.cloudflare_api_token
   }
   ```

6. **Token Security**:
   - Store API token in `.tfvars` file (excluded from Git via `.gitignore`)
   - Example: `terraform.tfvars.example` → `terraform.tfvars` (local only)
   - Terraform manages tunnel token lifecycle automatically
   - Never manually copy credentials from dashboard

---

## Decision 2: Kubernetes Deployment Best Practices - Resource Limits and Health Probes

**Question**: What are the production-ready resource limits, health check configurations, and deployment patterns for cloudflared in Kubernetes?

**Options Considered**:

1. **Minimal Configuration** (no limits, no probes)
   - **Pros**: Simple, fast deployment, no tuning required
   - **Cons**: No resource protection, pods can consume unlimited CPU/memory, no automatic restart on failure
   - **Risk**: Pod eviction under memory pressure, no health visibility

2. **Basic Configuration** (limits only)
   - **Pros**: Prevents resource overconsumption, protects cluster from runaway processes
   - **Cons**: No automated health checks, manual intervention needed for failures
   - **Resources**: CPU: 100m-500m, Memory: 100Mi-200Mi

3. **Production Configuration** (limits + probes + metrics)
   - **Pros**: Full observability, automatic failure recovery, resource protection, Kubernetes-native health checks
   - **Cons**: More complex configuration, requires understanding of probe parameters
   - **Resources**: CPU: 100m request / 500m limit, Memory: 100Mi request / 200Mi limit
   - **Probes**: Liveness + readiness on `/ready` endpoint (port 2000 for metrics)

**Decision**: **Production Configuration (Option 3)**

**Rationale**:
- **Constitution Alignment**: Aligns with Principle III (Container-First Development) requiring health checks mandatory for container deployments
- **Operational Excellence**: Automatic pod restart on tunnel disconnection (liveness probe) prevents manual intervention
- **Resource Efficiency**: Cloudflared is lightweight (official example shows 100Mi memory), but limits prevent potential leaks
- **Learning Value**: Understanding Kubernetes resource management and probe configuration is essential for production deployments
- **P3 Story Support**: Metrics endpoint (port 2000) enables future Prometheus integration without deployment changes
- **Cloudflare Best Practice**: Official Cloudflare blog examples use liveness probes on `/ready` endpoint

**Alternatives Considered and Rejected**:
- **No resource limits**: Rejected because Kubernetes documentation states "it is almost always better to use resource requests/limits than to forego them"
- **Guaranteed QoS** (requests = limits): Rejected for MVP as cloudflared is not latency-sensitive; "Burstable" QoS (requests < limits) provides flexibility
- **TCP probes instead of HTTP**: Rejected because cloudflared exposes `/ready` HTTP endpoint specifically for health checks

**Implementation Notes**:

1. **Resource Limits** (based on Cloudflare blog example and community deployments):
   ```yaml
   resources:
     requests:
       cpu: 100m        # Baseline: cloudflared is CPU-light (tunnel encryption)
       memory: 100Mi    # Baseline: minimal memory footprint
     limits:
       cpu: 500m        # Burst capacity for high-traffic scenarios
       memory: 200Mi    # Prevents memory leaks from consuming node resources
   ```

2. **Liveness Probe** (detects tunnel disconnection):
   ```yaml
   livenessProbe:
     httpGet:
       path: /ready
       port: 2000       # Metrics port (also exposes /metrics)
     initialDelaySeconds: 10    # Allow cloudflared to establish tunnel
     periodSeconds: 10          # Check every 10 seconds
     timeoutSeconds: 5          # Probe timeout
     failureThreshold: 3        # Restart after 3 consecutive failures (30 seconds)
   ```
   - **Why `/ready` endpoint**: Cloudflared exposes this endpoint to signal tunnel connectivity to Cloudflare edge
   - **Why port 2000**: Official cloudflared metrics port (also used for Prometheus scraping)
   - **Failure recovery**: Pod restarts automatically if tunnel disconnects for >30 seconds

3. **Readiness Probe** (controls traffic routing):
   ```yaml
   readinessProbe:
     httpGet:
       path: /ready
       port: 2000
     initialDelaySeconds: 5     # Faster initial check than liveness
     periodSeconds: 5           # More frequent checks for traffic routing
     timeoutSeconds: 3
     failureThreshold: 2        # Remove from service endpoints faster
   ```
   - **Purpose**: Prevents routing traffic to pod before tunnel is connected
   - **Use case**: Important for multi-replica deployments (P3 HA story)

4. **Security Context** (principle of least privilege):
   ```yaml
   securityContext:
     runAsNonRoot: true
     runAsUser: 65532         # cloudflared default non-root user
     allowPrivilegeEscalation: false
     capabilities:
       drop:
       - ALL
     readOnlyRootFilesystem: true
   ```

5. **Deployment Strategy**:
   ```yaml
   replicas: 1                  # MVP: single replica (P3 adds HA)
   strategy:
     type: RollingUpdate
     rollingUpdate:
       maxUnavailable: 0        # Zero-downtime updates
       maxSurge: 1              # New pod before terminating old
   ```

6. **Pod Disruption Budget** (for P3 HA):
   ```yaml
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: cloudflared-pdb
   spec:
     minAvailable: 1            # At least 1 replica must remain available
     selector:
       matchLabels:
         app: cloudflared
   ```

**Performance Expectations** (based on research):
- **Tunnel connection time**: <10 seconds after pod start
- **Probe overhead**: Negligible (<1% CPU, ~1MB memory)
- **Restart time**: <30 seconds (failure threshold + pod startup)
- **HTTP latency overhead**: <200ms added vs local access

---

## Decision 3: Cloudflare Access Integration - Google OAuth Configuration

**Question**: How should Google OAuth be configured for Cloudflare Access to provide email-based authentication for accessing protected services?

**Options Considered**:

1. **Google (Personal Gmail Accounts)**
   - **Pros**: Simple setup, works with any Gmail account, no Google Workspace requirement, free
   - **Cons**: No organizational control, anyone with Gmail can attempt authentication (rely on email whitelist), no directory integration
   - **Use case**: Homelab with family/friends access, 1-10 users
   - **Setup**: Google Cloud Console → Create OAuth Client ID → Audience Type: External

2. **Google Workspace (Organizational Accounts)**
   - **Pros**: Organizational control, can restrict to specific domain (e.g., @company.com), directory integration, group-based policies
   - **Cons**: Requires Google Workspace subscription ($6-18/user/month), overkill for homelab, additional admin overhead
   - **Use case**: Business/enterprise deployments, large teams
   - **Setup**: Google Cloud Console → Create OAuth Client ID → Audience Type: Internal

3. **One-Time PIN (OTP)**
   - **Pros**: No OAuth provider needed, works for any email address, simple user experience
   - **Cons**: Less secure (email compromise = access), no MFA, limited audit trail, not recommended for sensitive services
   - **Use case**: Temporary access, non-critical services

**Decision**: **Google (Personal Gmail Accounts) (Option 1)**

**Rationale**:
- **Cost**: Free tier sufficient for homelab learning environment (no Google Workspace subscription needed)
- **Simplicity**: Minimal setup - only requires Google Cloud Console OAuth client creation
- **Flexibility**: Can grant access to any Gmail user via email whitelist in Cloudflare Access policies
- **Homelab scope**: Typical use case is 1-10 users (family, friends, personal devices), not organizational scale
- **Security sufficient**: Email-based policies + Google OAuth provide adequate protection for homelab services (Pi-hole, future services)
- **Learning value**: Understanding OAuth 2.0 flow, identity providers, and email-based authorization policies

**Alternatives Considered and Rejected**:
- **Google Workspace**: Rejected due to unnecessary cost ($6+/user/month) for personal homelab
- **One-Time PIN**: Rejected because it's less secure (no MFA, email-only verification) and doesn't align with Constitution Principle V (Security Hardening)
- **Other OAuth providers** (GitHub, Azure AD): Considered but rejected for homelab simplicity (most family/friends have Gmail accounts)

**Implementation Notes**:

1. **Google Cloud Console Configuration**:
   - Navigate to: https://console.cloud.google.com/apis/credentials
   - Create Project: `chocolandia-homelab-access` (or use existing)
   - Create OAuth 2.0 Client ID:
     - Application type: **Web application**
     - Name: `Cloudflare Access - Homelab`
     - Authorized JavaScript origins: `https://<your-team-name>.cloudflareaccess.com`
     - Authorized redirect URIs: `https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/callback`
   - Copy **Client ID** and **Client Secret** (store securely)

2. **OAuth Consent Screen**:
   - User Type: **External** (allows any Gmail account)
   - App name: `Chocolandia Homelab Services`
   - User support email: `<your-email>@gmail.com`
   - Scopes: Default (email, profile, openid)
   - Test users: Add your Gmail addresses initially (required before publishing)
   - Publishing status: **In Production** (allows any Gmail user after approval) or **Testing** (limits to test users only)

3. **Cloudflare Zero Trust Configuration**:
   - Navigate to: Zero Trust → Settings → Authentication → Login methods
   - Add new → Select **Google**
   - Enter:
     - Name: `Google (Personal Accounts)`
     - App ID (Client ID): `<from Google Cloud Console>`
     - Client Secret: `<from Google Cloud Console>`
   - Save

4. **Cloudflare Access Policy Configuration** (email-based):
   - Navigate to: Access → Applications → Add an application
   - Application type: **Self-hosted**
   - Application name: `Pi-hole Admin Dashboard`
   - Session Duration: **24 hours** (default)
   - Application domain:
     - Subdomain: `pihole`
     - Domain: `example.com` (your Cloudflare-managed domain)
   - Add a policy:
     - Policy name: `Allow specific Gmail accounts`
     - Action: **Allow**
     - Session duration: **24 hours**
     - Selector: **Emails** → Add allowed email addresses:
       - `your-email@gmail.com`
       - `family-member@gmail.com`
       - (up to 10 emails for homelab scope)
   - Enable **Instant Auth** (skip login page if only one auth method)

5. **Session Management Configuration**:
   - **Application Token Expiration**: 24 hours (default)
     - Users re-authenticate daily
     - Balances security (frequent re-auth) with usability (not too frequent)
   - **Global Token Expiration**: 24 hours (same as application token)
     - Users logged out after 24 hours of inactivity
     - Cloudflare auto-refreshes application token if global token is valid
   - **Idle Timeout**: Not configured (users stay logged in for full 24 hours)
     - Could be added for sensitive services (e.g., 1-hour idle timeout)
   - **Manual Token Refresh**: Users can manually refresh at:
     - `https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/refresh-identity`

6. **Email Whitelist Management** (scaling to multiple services):
   - **Approach 1**: Per-application policies (granular control)
     - Pi-hole: Allow `admin@gmail.com`, `family@gmail.com`
     - Future Service X: Allow `admin@gmail.com` only
     - Use case: Different access levels per service
   - **Approach 2**: Reusable Access Groups (recommended)
     - Create Access Group: `Homelab Admins` (emails: `admin@gmail.com`)
     - Create Access Group: `Homelab Users` (emails: `admin@gmail.com`, `family@gmail.com`, ...)
     - Assign groups to application policies
     - Use case: Consistent access control across services, easier management

7. **Security Best Practices**:
   - **Principle of least privilege**: Only add emails that require access
   - **Regular audits**: Review Access Logs (Zero Trust → Logs → Access) monthly
   - **Revocation**: Remove email from policy immediately upon access termination
   - **MFA enforcement**: Google OAuth includes MFA if enabled on user's Google account (no additional config)
   - **Session monitoring**: Monitor `https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/audit-log` for suspicious activity

**Token Refresh Behavior**:
- **Automatic refresh**: When application token expires (24 hours), Cloudflare checks if global token is still valid
  - If global token valid: New application token issued automatically (seamless user experience)
  - If global token expired: User redirected to Google OAuth login
- **Logout behavior**: User can manually logout at any time (invalidates tokens immediately)
- **Policy changes**: If email is removed from policy, user's existing tokens are invalidated within 1 minute (Cloudflare edge cache TTL)

---

## Decision 4: Ingress Rules Configuration - Multiple Services via Single Tunnel

**Question**: How should ingress rules be configured to route multiple internal services (Pi-hole, future services) through a single Cloudflare Tunnel?

**Options Considered**:

1. **Terraform-Only Configuration** (cloudflare_tunnel_config resource)
   - **Pros**: Full GitOps compliance, version-controlled ingress rules, infrastructure as code, automated updates via `tofu apply`
   - **Cons**: More complex than dashboard GUI, requires Cloudflare API knowledge, catch-all rule mandatory
   - **Approach**: Use `cloudflare_tunnel_config` Terraform resource to manage ingress rules as code
   - **Example**: All routing rules defined in `.tf` files, applied via Terraform

2. **Dashboard-Only Configuration** (no config file)
   - **Pros**: Simple, GUI-driven, real-time updates, no ConfigMap needed
   - **Cons**: Not version-controlled (not GitOps), manual changes only, no IaC, violates Constitution Principle II
   - **Approach**: Configure "Public Hostnames" in Zero Trust dashboard → Tunnels → `chocolandia-k3s-tunnel` → Configure
   - **Example**: `pihole.example.com` → `http://pihole-web.default.svc.cluster.local:80`

3. **ConfigMap-Based Configuration** (locally-managed tunnel)
   - **Pros**: Version-controlled ingress rules, GitOps-friendly
   - **Cons**: Requires locally-managed tunnel (rejected in Decision 1), deprecated approach, config file must be mounted to pod
   - **Approach**: Create ConfigMap with `config.yaml` containing ingress rules, mount to cloudflared pod

**Decision**: **Terraform-Only Configuration (Option 1)**

**Rationale**:
- **Constitution compliance**: Full adherence to Principle II (GitOps Workflow) - all ingress routes in version control
- **Infrastructure as code**: Ingress rules defined in `.tf` files alongside tunnel creation
- **Reproducibility**: Complete routing configuration recreated via `tofu apply`
- **Automation**: Route changes via Git commits and Terraform apply (no manual dashboard clicks)
- **Single source of truth**: All Cloudflare configuration (tunnel, routes, DNS, Access) managed together
- **Alignment with Decision 1**: Terraform manages tunnel creation, so routes should also be Terraform-managed
- **Learning value**: Understanding Terraform for complex resource configurations, API-driven infrastructure

**Alternatives Considered and Rejected**:
- **Dashboard-only approach**: Rejected because it violates Constitution Principle II (GitOps Workflow) and creates configuration drift between IaC and reality
- **ConfigMap approach**: Rejected because it requires locally-managed tunnel (Decision 1 chose Terraform-managed)
- **Multiple tunnels (one per service)**: Rejected because single tunnel supports multiple ingress rules, reducing overhead

**Implementation Notes**:

1. **Terraform Configuration** (cloudflare_tunnel_config resource):
   ```hcl
   resource "cloudflare_tunnel_config" "chocolandia_config" {
     account_id = var.cloudflare_account_id
     tunnel_id  = cloudflare_tunnel.chocolandia_tunnel.id

     config {
       # Pi-hole admin interface
       ingress_rule {
         hostname = "pihole.${var.cloudflare_zone_name}"
         service  = "http://pihole-web.default.svc.cluster.local:80"
       }

       # Future service examples
       ingress_rule {
         hostname = "grafana.${var.cloudflare_zone_name}"
         service  = "http://grafana.monitoring.svc.cluster.local:3000"
       }

       ingress_rule {
         hostname = "home.${var.cloudflare_zone_name}"
         service  = "http://homepage.default.svc.cluster.local:8080"
       }

       # Required catch-all rule (must be last)
       ingress_rule {
         service = "http_status:404"
       }
     }
   }
   ```

2. **Catch-All Rule Requirement**:
   - **MANDATORY**: Terraform `cloudflare_tunnel_config` requires final catch-all rule
   - **Purpose**: Handles requests that don't match any hostname
   - **Options**:
     - `http_status:404` - Return 404 for unmatched requests (recommended)
     - `http_status:503` - Return 503 service unavailable
     - `http://fallback-service:80` - Route to default service
   - **Error if missing**: Terraform apply will fail without catch-all rule

3. **Ingress Rule Structure** (multiple services):

   | Public Hostname | Internal Service | Protocol | TLS Verification |
   |----------------|------------------|----------|------------------|
   | `pihole.chocolandiadc.com` | `pihole-web.default.svc.cluster.local:80` | HTTP | No |
   | `grafana.chocolandiadc.com` | `grafana.monitoring.svc.cluster.local:3000` | HTTP | No |
   | `home.chocolandiadc.com` | `homepage.default.svc.cluster.local:8080` | HTTP | No |

4. **Service Discovery Patterns** (Kubernetes DNS):
   - **Same namespace**: `http://service-name:port` (e.g., `http://pihole-web:80`)
   - **Cross-namespace**: `http://service-name.namespace.svc.cluster.local:port` (e.g., `http://grafana.monitoring.svc.cluster.local:3000`)
   - **External service**: `http://external-ip:port` (e.g., `http://192.168.4.100:8080` for non-Kubernetes service)

5. **TLS Termination Options**:
   - **Cloudflare edge** (default, recommended):
     - User → Cloudflare edge (TLS) → Tunnel (encrypted) → Internal service (HTTP)
     - Public traffic encrypted, internal cluster traffic unencrypted (acceptable for homelab)
   - **End-to-end TLS** (optional, for sensitive services):
     - User → Cloudflare edge (TLS) → Tunnel (encrypted) → Internal service (HTTPS)
     - Requires TLS cert on internal service (cert-manager, self-signed, etc.)
     - Configure in Terraform: `origin_server_name = "service.namespace.svc.cluster.local"`

6. **Traffic Routing Behavior**:
   - **Top-to-bottom matching**: Cloudflare matches hostname against ingress rules in order configured
   - **Wildcard support**: `*.chocolandiadc.com` routes all subdomains to same service
   - **Path-based routing**: Supported via `path` parameter in `ingress_rule` block

7. **Testing Ingress Rules**:
   - **Manual test**: `curl -H "Host: pihole.chocolandiadc.com" http://localhost:8080` (from cloudflared pod)
   - **External test**: Browse to `https://pihole.chocolandiadc.com` (should prompt for Cloudflare Access login)
   - **Troubleshooting**: Check tunnel logs: `kubectl logs -n cloudflare-system deployment/cloudflared`
   - **Terraform validation**: `tofu plan` will validate ingress rule syntax before apply

8. **Advanced Configuration** (for specific services):
   - **WebSocket Support**:
     - Automatically enabled for all HTTP/HTTPS services
     - No additional configuration needed
   - **HTTP/2 Support**:
     - Enabled by default for HTTPS services
   - **Connection Timeout**:
     - Configure via `connect_timeout` and `tls_timeout` in config block
     - Default: 30 seconds

---

## Decision 5: Cloudflare Access Policies Management - Terraform vs Dashboard

**Question**: How should Cloudflare Access applications and policies be configured to protect services with authentication?

**Options Considered**:

1. **Terraform-Managed Access Policies**
   - **Pros**: Full GitOps compliance, version-controlled policies, infrastructure as code, automated policy updates
   - **Cons**: More complex than dashboard GUI, requires understanding of Access policy structure
   - **Approach**: Use `cloudflare_access_application`, `cloudflare_access_policy`, `cloudflare_access_identity_provider` Terraform resources
   - **Example**: All Access configuration in `.tf` files

2. **Dashboard-Only Configuration**
   - **Pros**: Simple GUI-driven setup, visual policy builder
   - **Cons**: Not version-controlled, manual changes only, no IaC, violates Constitution Principle II
   - **Approach**: Configure applications and policies via Zero Trust dashboard
   - **Example**: Manual creation of applications and email-based policies

**Decision**: **Terraform-Managed Access Policies (Option 1)**

**Rationale**:
- **Constitution compliance**: Full adherence to Principle II (GitOps Workflow) - all Access policies in version control
- **Infrastructure as code**: Access applications, policies, and identity providers defined in `.tf` files
- **Reproducibility**: Complete Access configuration recreated via `tofu apply`
- **Security audit trail**: Policy changes tracked in Git history
- **Alignment with Decisions 1 & 4**: All Cloudflare configuration managed via Terraform
- **Policy consistency**: Reusable policy definitions across multiple applications
- **Learning value**: Understanding identity-based access control, OAuth integration via IaC

**Alternatives Considered and Rejected**:
- **Dashboard-only approach**: Rejected because it violates Constitution Principle II and creates security policy drift

**Implementation Notes**:

1. **Google OAuth Identity Provider** (Terraform resource):
   ```hcl
   resource "cloudflare_access_identity_provider" "google_oauth" {
     account_id = var.cloudflare_account_id
     name       = "Google OAuth (Personal Accounts)"
     type       = "google"

     config {
       client_id     = var.google_oauth_client_id
       client_secret = var.google_oauth_client_secret
     }
   }
   ```

2. **Access Application** (protecting services):
   ```hcl
   resource "cloudflare_access_application" "homelab_services" {
     zone_id                   = var.cloudflare_zone_id
     name                      = "Homelab Services"
     domain                    = "*.chocolandiadc.com"
     type                      = "self_hosted"
     session_duration          = "24h"
     auto_redirect_to_identity = true  # Skip login page if only one auth method

     # Optional: CORS headers for API services
     cors_headers {
       allowed_origins = ["https://*.chocolandiadc.com"]
       allow_all_methods = true
       allow_all_headers = true
       allow_credentials = true
       max_age           = 86400
     }
   }
   ```

3. **Access Policy - Email Whitelist** (allow specific users):
   ```hcl
   resource "cloudflare_access_policy" "allow_admins" {
     application_id = cloudflare_access_application.homelab_services.id
     zone_id        = var.cloudflare_zone_id
     name           = "Allow Homelab Admins"
     precedence     = 1
     decision       = "allow"

     include {
       email = [
         "cbenitez@gmail.com",
         # Add additional allowed emails here
       ]
     }
   }
   ```

4. **Access Policy - Multiple Users** (using email list variable):
   ```hcl
   variable "allowed_admin_emails" {
     description = "List of admin email addresses allowed to access homelab services"
     type        = list(string)
     default     = ["cbenitez@gmail.com"]
   }

   resource "cloudflare_access_policy" "allow_admins" {
     application_id = cloudflare_access_application.homelab_services.id
     zone_id        = var.cloudflare_zone_id
     name           = "Allow Homelab Admins"
     precedence     = 1
     decision       = "allow"

     include {
       email = var.allowed_admin_emails
     }
   }
   ```

5. **Per-Service Access Application** (granular control):
   ```hcl
   # Pi-hole specific access
   resource "cloudflare_access_application" "pihole" {
     zone_id          = var.cloudflare_zone_id
     name             = "Pi-hole Admin Dashboard"
     domain           = "pihole.chocolandiadc.com"
     type             = "self_hosted"
     session_duration = "24h"
   }

   resource "cloudflare_access_policy" "pihole_admins_only" {
     application_id = cloudflare_access_application.pihole.id
     zone_id        = var.cloudflare_zone_id
     name           = "Pi-hole Admins Only"
     precedence     = 1
     decision       = "allow"

     include {
       email = ["cbenitez@gmail.com"]  # Restricted access
     }
   }
   ```

6. **Access Groups** (reusable policy building blocks):
   ```hcl
   # Define reusable access groups
   resource "cloudflare_access_group" "homelab_admins" {
     account_id = var.cloudflare_account_id
     name       = "Homelab Admins"

     include {
       email = ["cbenitez@gmail.com"]
     }
   }

   resource "cloudflare_access_group" "homelab_users" {
     account_id = var.cloudflare_account_id
     name       = "Homelab Users"

     include {
       email = [
         "cbenitez@gmail.com",
         "family@gmail.com",
         "friend@gmail.com"
       ]
     }
   }

   # Use groups in policies
   resource "cloudflare_access_policy" "use_groups" {
     application_id = cloudflare_access_application.homelab_services.id
     zone_id        = var.cloudflare_zone_id
     name           = "Allow via Groups"
     precedence     = 1
     decision       = "allow"

     include {
       group = [cloudflare_access_group.homelab_admins.id]
     }
   }
   ```

7. **Required Variables**:
   ```hcl
   variable "cloudflare_zone_id" {
     description = "Cloudflare Zone ID for chocolandiadc.com domain"
     type        = string
   }

   variable "google_oauth_client_id" {
     description = "Google OAuth Client ID from Google Cloud Console"
     type        = string
   }

   variable "google_oauth_client_secret" {
     description = "Google OAuth Client Secret"
     type        = string
     sensitive   = true
   }
   ```

8. **Session Management**:
   - **Application Token Expiration**: 24 hours (configurable via `session_duration`)
   - **Automatic Token Refresh**: Handled by Cloudflare when global token is valid
   - **Policy Changes**: Take effect immediately (existing tokens invalidated within 1 minute)

9. **Security Best Practices**:
   - **Principle of least privilege**: Define separate applications/policies for sensitive services
   - **Email validation**: Only add verified email addresses to policies
   - **Regular audits**: Review Access Logs via Terraform or dashboard
   - **MFA enforcement**: Enabled automatically if user's Google account has MFA configured

---

## Decision 6: DNS Records Management - Terraform vs Dashboard

**Question**: How should DNS CNAME records for tunnel endpoints be configured?

**Options Considered**:

1. **Terraform-Managed DNS Records**
   - **Pros**: Full GitOps compliance, version-controlled DNS, infrastructure as code, automated DNS updates
   - **Cons**: Requires understanding of Cloudflare DNS resource syntax
   - **Approach**: Use `cloudflare_record` Terraform resource to create CNAME records
   - **Example**: All DNS records defined in `.tf` files

2. **Dashboard Auto-Configuration**
   - **Pros**: Automatic CNAME creation when adding public hostnames, zero configuration
   - **Cons**: Not version-controlled, manual cleanup needed when routes removed, violates Constitution Principle II
   - **Approach**: Cloudflare automatically creates CNAMEs when public hostnames added to tunnel
   - **Example**: Dashboard manages DNS records implicitly

3. **Manual Dashboard Configuration**
   - **Pros**: Simple GUI-driven DNS management
   - **Cons**: Not version-controlled, manual changes only, error-prone, violates Constitution Principle II
   - **Approach**: Manually create CNAME records in Cloudflare DNS dashboard
   - **Example**: Point pihole.chocolandiadc.com to tunnel CNAME

**Decision**: **Terraform-Managed DNS Records (Option 1)**

**Rationale**:
- **Constitution compliance**: Full adherence to Principle II (GitOps Workflow) - all DNS records in version control
- **Infrastructure as code**: DNS records defined in `.tf` files alongside tunnel and routing configuration
- **Reproducibility**: Complete DNS configuration recreated via `tofu apply`
- **Consistency**: DNS records and tunnel routes defined together (single source of truth)
- **Alignment with Decisions 1, 4, 5**: All Cloudflare configuration managed via Terraform
- **Cleanup automation**: `tofu destroy` removes DNS records automatically
- **Learning value**: Understanding DNS-as-code, Terraform resource dependencies

**Alternatives Considered and Rejected**:
- **Auto-configuration approach**: Rejected because it creates DNS records outside of version control and requires manual cleanup
- **Manual dashboard approach**: Rejected because it violates Constitution Principle II and is error-prone

**Implementation Notes**:

1. **CNAME Record for Tunnel** (Terraform resource):
   ```hcl
   resource "cloudflare_record" "pihole_cname" {
     zone_id = var.cloudflare_zone_id
     name    = "pihole"
     value   = "${cloudflare_tunnel.chocolandia_tunnel.id}.cfargotunnel.com"
     type    = "CNAME"
     proxied = true  # Enable Cloudflare proxy (orange cloud)
     comment = "Managed by Terraform - Pi-hole admin interface via Cloudflare Tunnel"
   }
   ```

2. **Multiple Service CNAMEs** (DRY approach using for_each):
   ```hcl
   locals {
     tunnel_services = {
       "pihole"  = "Pi-hole admin interface"
       "grafana" = "Grafana monitoring dashboard"
       "home"    = "Homepage application"
     }
   }

   resource "cloudflare_record" "tunnel_services" {
     for_each = local.tunnel_services

     zone_id = var.cloudflare_zone_id
     name    = each.key
     value   = "${cloudflare_tunnel.chocolandia_tunnel.id}.cfargotunnel.com"
     type    = "CNAME"
     proxied = true
     comment = "Managed by Terraform - ${each.value} via Cloudflare Tunnel"
   }
   ```

3. **Wildcard CNAME** (for dynamic services):
   ```hcl
   resource "cloudflare_record" "wildcard_services" {
     zone_id = var.cloudflare_zone_id
     name    = "*"  # Matches *.chocolandiadc.com
     value   = "${cloudflare_tunnel.chocolandia_tunnel.id}.cfargotunnel.com"
     type    = "CNAME"
     proxied = true
     comment = "Managed by Terraform - All services via Cloudflare Tunnel"
   }
   ```

4. **Proxied vs DNS-Only**:
   - **Proxied (recommended)**: `proxied = true`
     - Enables Cloudflare CDN, DDoS protection, WAF, Access policies
     - Hides origin IP address
     - Required for Cloudflare Access to work
   - **DNS-Only**: `proxied = false`
     - Bypasses Cloudflare features
     - Not recommended for tunnel endpoints

5. **TTL Configuration**:
   ```hcl
   resource "cloudflare_record" "pihole_cname" {
     zone_id = var.cloudflare_zone_id
     name    = "pihole"
     value   = "${cloudflare_tunnel.chocolandia_tunnel.id}.cfargotunnel.com"
     type    = "CNAME"
     proxied = true
     ttl     = 1  # Auto (proxied records always use TTL=1)
   }
   ```
   - **Proxied records**: TTL automatically set to 1 (automatic)
   - **DNS-only records**: Can configure custom TTL (300-86400 seconds)

6. **Resource Dependencies**:
   ```hcl
   resource "cloudflare_record" "pihole_cname" {
     zone_id = var.cloudflare_zone_id
     name    = "pihole"
     value   = "${cloudflare_tunnel.chocolandia_tunnel.id}.cfargotunnel.com"
     type    = "CNAME"
     proxied = true

     # Explicit dependency ensures tunnel exists before DNS record
     depends_on = [cloudflare_tunnel.chocolandia_tunnel]
   }
   ```

7. **DNS Verification**:
   - **Terraform output**: `tofu apply` shows created DNS records
   - **Manual verification**: `dig pihole.chocolandiadc.com CNAME`
   - **Expected result**: `pihole.chocolandiadc.com. 300 IN CNAME <tunnel-id>.cfargotunnel.com.`

8. **DNS Record Cleanup**:
   - **Automatic**: `tofu destroy` removes all DNS records
   - **Manual removal**: Never delete DNS records manually in dashboard (causes Terraform state drift)

---

## Summary of Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Tunnel Creation Method** | Terraform-Managed (cloudflare_tunnel) | Full GitOps compliance, reproducible deployments, zero manual dashboard steps |
| **Resource Limits** | 100Mi-200Mi memory, 100m-500m CPU | Cloudflare best practice, prevents resource overconsumption, sufficient for homelab traffic |
| **Health Probes** | Liveness + Readiness on `/ready` port 2000 | Automatic failure recovery, aligns with K8s best practices, enables P3 HA monitoring |
| **OAuth Provider** | Google (Personal Gmail Accounts) via Terraform | Free, simple setup, sufficient security for homelab, no Workspace subscription needed |
| **Access Policies** | Terraform-Managed (cloudflare_access_policy) | Version-controlled policies, security audit trail, GitOps compliance |
| **Session Duration** | 24 hours (application + global tokens) | Balances security (daily re-auth) with usability (not too frequent) |
| **Ingress Configuration** | Terraform-Only (cloudflare_tunnel_config) | Full GitOps compliance, version-controlled routing, automated updates |
| **Routing Pattern** | Hostname-based (separate subdomain per service) | DNS simplicity, no path-rewriting complexity |
| **DNS Records** | Terraform-Managed (cloudflare_record) | Version-controlled DNS, automated cleanup, single source of truth |
| **TLS Termination** | Cloudflare edge only (HTTP to internal services) | Adequate security for homelab, avoids cert-manager complexity in MVP |

**Prerequisites**:
- **Cloudflare Account**: Active Cloudflare account with chocolandiadc.com domain configured
- **Cloudflare Account ID**: Found in Cloudflare Dashboard → Account Home
- **Cloudflare Zone ID**: Found in Cloudflare Dashboard → Domain Overview → API section
- **Cloudflare API Token**: Created with following permissions:
  - Account:Cloudflare Tunnel:Edit
  - Zone:DNS:Edit
  - Account:Access:Apps and Policies:Edit
  - Account:Access:Organizations, Identity Providers, and Groups:Edit
- **Google OAuth Credentials**: OAuth 2.0 Client ID and Client Secret from Google Cloud Console
- **Domain**: chocolandiadc.com domain active in Cloudflare (DNS managed by Cloudflare)

**Constitution Alignment**:
- ✅ **Principle I (IaC/OpenTofu)**: All infrastructure (Cloudflared Deployment, Secrets, Cloudflare resources) managed via OpenTofu/Terraform
- ✅ **Principle II (GitOps)**: FULL compliance - All Cloudflare configuration (tunnel, routes, DNS, Access policies) in version control, zero manual dashboard configuration
- ✅ **Principle III (Container-First)**: cloudflared container with health probes and resource limits
- ⚠️ **Principle IV (Observability)**: Metrics endpoint configured (port 2000), Prometheus integration deferred to P3 story
- ✅ **Principle V (Security Hardening)**: Google OAuth + Terraform-managed policies, tunnel token in Secret, no public ports exposed, all credentials in version-controlled .tfvars
- ⚠️ **Principle VI (High Availability)**: Single replica in MVP (P1/P2), HA addressed in P3 story
- ✅ **Principle IX (Network-First Security)**: Cloudflare Zero Trust replaces traditional network perimeter (identity-based vs network-based security)

**Trade-offs Accepted**:
1. **Single replica** (P1/P2): Acceptable for homelab learning; multi-replica HA tested in P3 story
2. **No Prometheus integration** (MVP): Metrics endpoint ready but integration deferred to P3; focus on core connectivity first
3. **Terraform state security**: State file contains sensitive credentials (tunnel token, API token); must be stored securely (future: migrate to remote backend with encryption)

**Next Phase**: Proceed to Phase 1 (Design) to generate `data-model.md`, `contracts/`, and `quickstart.md` based on these architectural decisions.
