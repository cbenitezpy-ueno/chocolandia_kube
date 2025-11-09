# Research & Architectural Decisions: Cloudflare Zero Trust VPN Access

**Feature**: 004-cloudflare-zerotrust
**Date**: 2025-11-09
**Status**: Draft

## Context

This research document captures architectural decisions for deploying Cloudflare Zero Trust Tunnel (cloudflared) in the K3s cluster to provide secure remote access to internal services without exposing public ports. The deployment must integrate with Cloudflare Access for authentication, support multiple internal services through a single tunnel, and follow production-ready patterns suitable for a homelab/learning environment.

---

## Decision 1: Tunnel Creation Method - CLI vs Dashboard

**Question**: Should Cloudflare Tunnels be created using CLI (locally-managed) or Dashboard (remotely-managed) approach for IaC/automated deployment?

**Options Considered**:

1. **Dashboard/Remotely-Managed Tunnels**
   - **Pros**:
     - Stateless deployment - no local credential files needed beyond token
     - Ingress rules configured via web UI or API (no config file in pod)
     - Simpler Kubernetes deployment - only tunnel token required in Secret
     - Easier management and visibility through Zero Trust dashboard
     - Recommended by Cloudflare for Kubernetes deployments (2024 docs)
     - Multiple replicas can use same tunnel token without coordination
   - **Cons**:
     - Initial tunnel creation requires manual dashboard interaction
     - Ingress rule changes require dashboard/API access (not in Git)
     - Less "infrastructure as code" for routing rules
   - **Implementation**:
     - Create tunnel once in Cloudflare Zero Trust dashboard → Networks → Tunnels
     - Copy tunnel token from dashboard
     - Store token in Kubernetes Secret
     - Deploy cloudflared with token only (no config file needed)
     - Manage ingress routes via dashboard or Cloudflare API

2. **CLI/Locally-Managed Tunnels**
   - **Pros**:
     - Full GitOps workflow - tunnel config file version-controlled
     - Ingress rules defined in YAML ConfigMap (infrastructure as code)
     - No dashboard interaction needed after initial tunnel creation
     - Configuration changes via Git commits
   - **Cons**:
     - Requires cert.pem and credentials.json files
     - More complex Secret management (multiple files vs single token)
     - Deprecated approach - Cloudflare recommends remotely-managed tunnels
     - Config file must be mounted to cloudflared pod
     - More difficult to manage multiple replicas (config file sync)
   - **Implementation**:
     - `cloudflared tunnel create my-tunnel` → generates credentials.json
     - Store credentials.json in Kubernetes Secret
     - Create ConfigMap with tunnel config.yaml (ingress rules)
     - Mount both Secret and ConfigMap to cloudflared pod

**Decision**: **Dashboard/Remotely-Managed Tunnels (Option 1)**

**Rationale**:
- **Cloudflare recommendation**: Official 2024 Kubernetes documentation explicitly recommends remotely-managed tunnels as the modern approach
- **Stateless deployment**: Aligns with Kubernetes best practices (single token Secret vs multiple credential files)
- **Simpler operations**: Tunnel token is the only credential needed; no cert.pem or config file management
- **HA-friendly**: Multiple cloudflared replicas can use identical tunnel token without configuration sync issues
- **Visibility**: Zero Trust dashboard provides real-time tunnel health, connection metrics, and traffic analytics
- **Hybrid IaC approach**: While ingress routes are managed via dashboard/API (not pure GitOps), the cloudflared Deployment/Secret/ConfigMap are still version-controlled in OpenTofu
- **Learning value**: Understanding cloud-native tunnel management (API-driven config) vs legacy file-based config

**Alternatives Considered and Rejected**:
- **Pure CLI approach**: Rejected because it's the legacy method. Cloudflare docs state: "The legacy method is dependent on files on your disk to be present/set in the right way/permissions to function, while the new method is entirely stateless and can be re-setup & configured remotely"
- **Terraform-managed ingress routes**: Rejected for MVP simplicity. Could be added later via `cloudflare_tunnel_config` Terraform resource for full IaC compliance

**Implementation Notes**:
1. **Tunnel Creation** (one-time manual step):
   - Navigate to Cloudflare Zero Trust → Networks → Tunnels → Create a tunnel
   - Choose "Cloudflared" connector type
   - Name tunnel: `chocolandia-k3s-tunnel`
   - Copy tunnel token from dashboard (format: `eyJhIjoiXXX...`)
   - Document tunnel ID for reference

2. **Kubernetes Secret**:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: cloudflared-token
     namespace: cloudflare-system
   type: Opaque
   stringData:
     token: <TUNNEL_TOKEN_FROM_DASHBOARD>
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

4. **Ingress Route Configuration** (via dashboard):
   - After cloudflared pod is running, configure Public Hostnames in dashboard
   - Example: `pihole.example.com` → `http://pihole-web.default.svc.cluster.local:80`
   - Alternative: Use Cloudflare API (`POST /accounts/:account_id/tunnels/:tunnel_id/configurations`) for automation

5. **Token Security**:
   - Store token in `.tfvars` file (excluded from Git via `.gitignore`)
   - Example: `terraform.tfvars.example` → `terraform.tfvars` (local only)
   - OpenTofu creates Secret from variable: `sensitive = true`

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

1. **Dashboard-Only Configuration** (no config file)
   - **Pros**: Simple, GUI-driven, real-time updates, no ConfigMap needed
   - **Cons**: Not version-controlled (not GitOps), manual changes only, no IaC
   - **Approach**: Configure "Public Hostnames" in Zero Trust dashboard → Tunnels → `chocolandia-k3s-tunnel` → Configure
   - **Example**: `pihole.example.com` → `http://pihole-web.default.svc.cluster.local:80`

2. **ConfigMap-Based Configuration** (locally-managed tunnel)
   - **Pros**: Version-controlled ingress rules, GitOps-friendly, infrastructure as code
   - **Cons**: Requires locally-managed tunnel (rejected in Decision 1), config file must be mounted to pod
   - **Approach**: Create ConfigMap with `config.yaml` containing ingress rules, mount to cloudflared pod
   - **Example**:
     ```yaml
     ingress:
       - hostname: pihole.example.com
         service: http://pihole-web.default.svc.cluster.local:80
       - hostname: grafana.example.com
         service: http://grafana.monitoring.svc.cluster.local:3000
       - service: http_status:404  # Catch-all rule (required)
     ```

3. **Hybrid Approach** (remotely-managed tunnel + API automation)
   - **Pros**: Best of both worlds - remotely-managed simplicity + API-driven IaC, config changes via Terraform/scripts
   - **Cons**: More complex (requires Cloudflare API knowledge), not pure GitOps (API mutations), learning curve
   - **Approach**: Use Cloudflare API `POST /accounts/:account_id/tunnels/:tunnel_id/configurations` to update ingress rules programmatically
   - **Terraform resource**: `cloudflare_tunnel_config` (manages ingress routes as code)

**Decision**: **Dashboard-Only Configuration (Option 1) for MVP, with migration path to Hybrid Approach (Option 3)**

**Rationale**:
- **Alignment with Decision 1**: Remotely-managed tunnels use dashboard/API for ingress config (not config files)
- **MVP simplicity**: Dashboard GUI is fastest path to working tunnel (learning priority)
- **Low service count**: 2-5 services initially (Pi-hole + future services), manual management acceptable
- **Migration path**: When service count grows (>5), introduce Terraform `cloudflare_tunnel_config` resource for IaC compliance
- **Constitution trade-off**: Principle II (GitOps Workflow) partially violated but documented with clear upgrade path
- **Learning progression**: Phase 1 (dashboard) teaches tunnel mechanics, Phase 2 (API/Terraform) teaches automation

**Alternatives Considered and Rejected**:
- **ConfigMap approach**: Rejected because it requires locally-managed tunnel (Decision 1 chose remotely-managed)
- **Immediate API automation**: Rejected for MVP to reduce initial complexity (Cloudflare API learning curve)
- **Multiple tunnels (one per service)**: Rejected because single tunnel supports multiple ingress rules, reducing overhead

**Implementation Notes**:

1. **Dashboard Configuration** (MVP - Phase 1):
   - Navigate to: Zero Trust → Networks → Tunnels → `chocolandia-k3s-tunnel` → Configure
   - Click **Add a public hostname**:
     - **Subdomain**: `pihole`
     - **Domain**: `example.com` (select from Cloudflare-managed domains)
     - **Type**: HTTP
     - **URL**: `pihole-web.default.svc.cluster.local:80`
     - **TLS Verification**: Disabled (internal cluster service, no TLS cert)
   - Repeat for additional services:
     - `grafana.example.com` → `grafana.monitoring.svc.cluster.local:3000`
     - `home.example.com` → `homepage.default.svc.cluster.local:8080`
   - **Important**: No catch-all rule needed for dashboard-managed tunnels (Cloudflare handles 404 automatically)

2. **Ingress Rule Structure** (multiple services):

   | Public Hostname | Internal Service | Protocol | TLS Verification |
   |----------------|------------------|----------|------------------|
   | `pihole.example.com` | `pihole-web.default.svc.cluster.local:80` | HTTP | No |
   | `grafana.example.com` | `grafana.monitoring.svc.cluster.local:3000` | HTTP | No |
   | `home.example.com` | `homepage.default.svc.cluster.local:8080` | HTTP | No |

3. **DNS Automatic Configuration**:
   - Cloudflare automatically creates CNAME records when public hostname is added:
     - `pihole.example.com` → `<tunnel-id>.cfargotunnel.com`
     - `grafana.example.com` → `<tunnel-id>.cfargotunnel.com`
   - No manual DNS configuration needed (zero-touch DNS management)

4. **Path-Based Routing** (alternative to hostname-based):
   - **Not supported** in dashboard-managed tunnels directly
   - **Workaround**: Use Kubernetes Ingress controller (e.g., nginx-ingress) inside cluster:
     - Cloudflare Tunnel → nginx-ingress (single entry point)
     - nginx-ingress routes by path: `/pihole` → pihole service, `/grafana` → grafana service
   - **Use case**: Reduces number of public hostnames (e.g., `services.example.com/pihole`, `services.example.com/grafana`)
   - **Trade-off**: Adds nginx-ingress complexity, deferred to future enhancement

5. **Service Discovery Patterns** (Kubernetes DNS):
   - **Same namespace**: `http://service-name:port` (e.g., `http://pihole-web:80`)
   - **Cross-namespace**: `http://service-name.namespace.svc.cluster.local:port` (e.g., `http://grafana.monitoring.svc.cluster.local:3000`)
   - **External service**: `http://external-ip:port` (e.g., `http://192.168.4.100:8080` for non-Kubernetes service)

6. **TLS Termination Options**:
   - **Cloudflare edge** (default, recommended):
     - User → Cloudflare edge (TLS) → Tunnel (encrypted) → Internal service (HTTP)
     - Public traffic encrypted, internal cluster traffic unencrypted (acceptable for homelab)
   - **End-to-end TLS** (optional, for sensitive services):
     - User → Cloudflare edge (TLS) → Tunnel (encrypted) → Internal service (HTTPS)
     - Requires TLS cert on internal service (cert-manager, self-signed, etc.)
     - Enable "TLS Verification" in dashboard (must trust internal CA)

7. **Traffic Routing Behavior**:
   - **Top-to-bottom matching**: Cloudflare matches hostname against ingress rules in order configured
   - **Wildcard support**: `*.example.com` routes all subdomains to same service (e.g., `alpha.example.com`, `beta.example.com`)
   - **Path regex** (dashboard limitation): Not supported in dashboard; requires config file (hybrid approach)

8. **Migration to Terraform Automation** (Phase 2 - future enhancement):
   - **Terraform resource**:
     ```hcl
     resource "cloudflare_tunnel_config" "chocolandia_tunnel" {
       account_id = var.cloudflare_account_id
       tunnel_id  = cloudflare_tunnel.chocolandia_tunnel.id

       config {
         ingress_rule {
           hostname = "pihole.example.com"
           service  = "http://pihole-web.default.svc.cluster.local:80"
         }
         ingress_rule {
           hostname = "grafana.example.com"
           service  = "http://grafana.monitoring.svc.cluster.local:3000"
         }
         ingress_rule {
           service = "http_status:404"  # Catch-all required
         }
       }
     }
     ```
   - **Advantages**: GitOps-compliant, version-controlled ingress rules, automated updates via `tofu apply`
   - **When to migrate**: When service count exceeds 5, or when team collaboration requires review/approval workflow for routing changes

9. **Testing Ingress Rules**:
   - **Manual test**: `curl -H "Host: pihole.example.com" http://localhost:8080` (from cloudflared pod)
   - **External test**: Browse to `https://pihole.example.com` (should prompt for Cloudflare Access login)
   - **Troubleshooting**: Check tunnel logs: `kubectl logs -n cloudflare-system deployment/cloudflared`

10. **Advanced Configuration** (for specific services):
    - **HTTP Headers** (add/modify/remove):
      - Use case: Add `X-Forwarded-For` for client IP logging
      - Limitation: Dashboard doesn't support header manipulation; requires config file (hybrid approach)
    - **WebSocket Support**:
      - Automatically enabled for all HTTP/HTTPS services
      - No additional configuration needed
    - **SSH/RDP Tunneling** (TCP services):
      - Requires `cloudflared access` on client side
      - Use case: SSH to cluster nodes via tunnel (security risk, not recommended for homelab)
    - **Load Balancing** (across multiple services):
      - Use case: Blue/green deployments, A/B testing
      - Limitation: Not supported in single tunnel; requires multiple tunnels or external LB

---

## Summary of Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Tunnel Creation Method** | Dashboard/Remotely-Managed | Cloudflare recommendation, stateless deployment, HA-friendly, simpler Secret management |
| **Resource Limits** | 100Mi-200Mi memory, 100m-500m CPU | Cloudflare best practice, prevents resource overconsumption, sufficient for homelab traffic |
| **Health Probes** | Liveness + Readiness on `/ready` port 2000 | Automatic failure recovery, aligns with K8s best practices, enables P3 HA monitoring |
| **OAuth Provider** | Google (Personal Gmail Accounts) | Free, simple setup, sufficient security for homelab, no Workspace subscription needed |
| **Access Policies** | Email-based whitelist | Granular control, easy management for 1-10 users, supports future Access Groups |
| **Session Duration** | 24 hours (application + global tokens) | Balances security (daily re-auth) with usability (not too frequent) |
| **Ingress Configuration** | Dashboard-Only (MVP) → Terraform API (future) | Fast MVP delivery, migration path to GitOps when service count grows |
| **Routing Pattern** | Hostname-based (separate subdomain per service) | DNS simplicity, no path-rewriting complexity, Cloudflare auto-manages DNS CNAMEs |
| **TLS Termination** | Cloudflare edge only (HTTP to internal services) | Adequate security for homelab, avoids cert-manager complexity in MVP |

**Constitution Alignment**:
- ✅ **Principle I (IaC/OpenTofu)**: Cloudflared Deployment/Secret/ConfigMap managed via OpenTofu; ingress routes deferred to future Terraform automation
- ✅ **Principle II (GitOps)**: Partial compliance - Deployment config in Git, ingress routes in dashboard (upgrade path documented)
- ✅ **Principle III (Container-First)**: cloudflared container with health probes and resource limits
- ⚠️ **Principle IV (Observability)**: Metrics endpoint configured (port 2000), Prometheus integration deferred to P3 story
- ✅ **Principle V (Security Hardening)**: Google OAuth + email policies, tunnel token in Secret, no public ports exposed
- ⚠️ **Principle VI (High Availability)**: Single replica in MVP (P1/P2), HA addressed in P3 story
- ⚠️ **Principle IX (Network-First Security)**: Cloudflare Zero Trust replaces traditional network perimeter (identity-based vs network-based security)

**Trade-offs Accepted**:
1. **Ingress routes not in Git** (MVP): Deferred to maintain dashboard simplicity for learning; Terraform automation planned for Phase 2
2. **Single replica** (P1/P2): Acceptable for homelab learning; multi-replica HA tested in P3 story
3. **No Prometheus integration** (MVP): Metrics endpoint ready but integration deferred to P3; focus on core connectivity first

**Next Phase**: Proceed to Phase 1 (Design) to generate `data-model.md`, `contracts/`, and `quickstart.md` based on these architectural decisions.
