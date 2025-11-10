# Data Model: Cloudflare Zero Trust VPN Access

**Feature**: 004-cloudflare-zerotrust
**Created**: 2025-11-09
**Status**: Design Phase

## Overview

This document defines the key entities, their attributes, relationships, and state transitions for the Cloudflare Zero Trust Tunnel deployment in K3s cluster.

## Entity Definitions

### 1. Cloudflare Tunnel

**Description**: Represents the secure outbound connection from K3s cluster to Cloudflare's edge network. Acts as the bridge between internal services and external access.

**Attributes**:
- `tunnel_id` (string, UUID): Unique identifier assigned by Cloudflare (e.g., `a7b3c4d5-e6f7-8a9b-0c1d-2e3f4a5b6c7d`)
- `tunnel_name` (string): Human-readable name (e.g., `chocolandia-k3s-tunnel`)
- `tunnel_token` (string, secret): Authentication credential for cloudflared connector (format: `eyJhIjoiXXX...`)
- `account_id` (string): Cloudflare account ID owning the tunnel
- `created_at` (timestamp): Tunnel creation timestamp
- `connection_status` (enum): Current connectivity state
  - `disconnected`: No active connections
  - `connecting`: Attempting to establish connection
  - `connected`: Active connection to Cloudflare edge
  - `degraded`: Connection issues (packet loss, high latency)
- `replica_count` (integer): Number of cloudflared pods running (default: 1, P3: 2+)
- `metrics_enabled` (boolean): Whether Prometheus metrics exposed (P3 feature)

**Relationships**:
- Has many `Ingress Rules` (1:N)
- Has one `Tunnel Connector Pod` per replica (1:N)
- Protected by one `Tunnel Token Secret` (1:1)

**Validation Rules**:
- `tunnel_name` must be unique per Cloudflare account
- `tunnel_token` must be base64-encoded JWT format
- `replica_count` must be >= 1

**State Transitions**:
```
disconnected → connecting → connected
connected → degraded (network issues detected)
degraded → connected (issues resolved)
connected → disconnected (pod failure, network loss)
disconnected → connecting (auto-reconnection)
```

---

### 2. Tunnel Token Secret

**Description**: Kubernetes Secret storing the Cloudflare Tunnel authentication token. Mounted to cloudflared pods as environment variable.

**Attributes**:
- `secret_name` (string): Kubernetes Secret name (e.g., `cloudflared-token`)
- `namespace` (string): Kubernetes namespace (e.g., `cloudflare-system`)
- `token_value` (string, sensitive): Base64-encoded tunnel token
- `created_at` (timestamp): Secret creation timestamp
- `last_rotated_at` (timestamp, nullable): Last token rotation timestamp (future feature)

**Relationships**:
- Belongs to one `Cloudflare Tunnel` (N:1)
- Mounted by one or more `Tunnel Connector Pods` (1:N)

**Validation Rules**:
- `secret_name` must match Kubernetes naming conventions (lowercase, alphanumeric, hyphens)
- `token_value` must not be committed to Git (enforced via .gitignore)
- Secret must exist before Deployment creation (dependency order)

**Security Requirements**:
- Kubernetes Secret encryption at rest (etcd)
- RBAC: Only cloudflared ServiceAccount can read
- No logging of token_value in any logs/events

---

### 3. Ingress Rule

**Description**: Mapping configuration defining how public hostnames route to internal Kubernetes services. Configured via Cloudflare Zero Trust dashboard (MVP) or Terraform API (future).

**Attributes**:
- `rule_id` (string, UUID): Unique identifier (Cloudflare-assigned)
- `tunnel_id` (string, UUID): Parent tunnel reference
- `public_hostname` (string): Public DNS hostname (e.g., `pihole.example.com`)
- `service_url` (string): Internal service address (e.g., `http://pihole-web.default.svc.cluster.local:80`)
- `protocol` (enum): Traffic protocol
  - `http`: HTTP traffic
  - `https`: HTTPS traffic (TLS termination at Cloudflare edge)
  - `ssh`: SSH traffic (future)
  - `rdp`: RDP traffic (future)
- `path` (string, optional): URL path for path-based routing (e.g., `/admin`, future feature)
- `tls_verify` (boolean): Whether to verify internal service TLS certificate (default: false for MVP)
- `priority` (integer): Rule evaluation order (lower = higher priority)
- `created_at` (timestamp): Rule creation timestamp
- `last_modified_at` (timestamp): Last modification timestamp

**Relationships**:
- Belongs to one `Cloudflare Tunnel` (N:1)
- Protected by one or more `Cloudflare Access Policies` (N:M)
- Routes to one Kubernetes Service (N:1, external to this model)

**Validation Rules**:
- `public_hostname` must be valid DNS hostname (RFC 1123)
- `public_hostname` must use domain managed by Cloudflare account
- `service_url` must use `http://` or `https://` scheme
- `service_url` must resolve via Kubernetes DNS (*.svc.cluster.local)
- Duplicate `public_hostname` not allowed within same tunnel

**Routing Logic**:
1. User request to `pihole.example.com` hits Cloudflare edge
2. Cloudflare Access policy evaluated (authentication check)
3. If authorized, request forwarded to tunnel connector pod
4. cloudflared routes to matching `service_url` via Kubernetes DNS
5. Response flows back through tunnel to Cloudflare to user

---

### 4. Cloudflare Access Policy

**Description**: Authorization rules defining which users/groups can access specific public hostnames. Managed via Cloudflare Zero Trust dashboard.

**Attributes**:
- `policy_id` (string, UUID): Unique identifier (Cloudflare-assigned)
- `policy_name` (string): Human-readable name (e.g., `Homelab Admin Access`)
- `application_domain` (string): Protected hostname (e.g., `pihole.example.com`)
- `action` (enum): Policy action
  - `allow`: Grant access if rules match
  - `deny`: Block access if rules match
  - `bypass`: Skip authentication (not recommended)
- `selector_type` (enum): Authorization criteria
  - `emails`: Whitelist of email addresses
  - `email_domains`: Whitelist of email domains (e.g., `@example.com`)
  - `groups`: Cloudflare Access Groups
  - `everyone`: Allow all authenticated users (not recommended for production)
- `selector_values` (array of strings): List of allowed emails/domains/groups
  - Example: `["admin@gmail.com", "family@gmail.com"]`
- `auth_method` (enum): Authentication provider
  - `google_oauth`: Google OAuth (selected for this feature)
  - `github_oauth`: GitHub OAuth
  - `email_otp`: One-Time PIN via email
  - `azure_ad`: Microsoft Azure AD
- `session_duration` (string): Token validity period (e.g., `24h`, `12h`, `7d`)
- `require_mfa` (boolean): Whether multi-factor authentication required (Google OAuth inherits Google MFA)
- `created_at` (timestamp): Policy creation timestamp
- `last_modified_at` (timestamp): Last modification timestamp

**Relationships**:
- Protects one or more `Ingress Rules` (M:N)
- Uses one Authentication Provider configuration (N:1, external to this model)

**Validation Rules**:
- `application_domain` must match existing `Ingress Rule.public_hostname`
- `selector_values` array must not be empty for `emails`/`email_domains` selectors
- `session_duration` must be between 15 minutes and 30 days (Cloudflare limits)
- At least one `allow` policy must exist per application (otherwise no access possible)

**Authorization Flow**:
```
1. User navigates to pihole.example.com
2. Cloudflare Access intercepts request
3. Check if user has valid session token (cookie)
   - If valid and not expired → Allow access (step 7)
   - If expired or missing → Continue to step 4
4. Redirect to authentication provider (Google OAuth)
5. User authenticates with Google account
6. Cloudflare Access evaluates policies:
   - Match user email against selector_values
   - If match found in `allow` policy → Issue session token (24h)
   - If no match or `deny` policy → Show access denied error
7. User redirected to original URL with session token
8. Request forwarded to tunnel connector pod
```

---

### 5. Tunnel Connector Pod

**Description**: Kubernetes Deployment running cloudflared container. Maintains persistent outbound connection to Cloudflare edge and routes traffic to internal services.

**Attributes**:
- `pod_name` (string): Kubernetes pod name (e.g., `cloudflared-deployment-abc123`)
- `namespace` (string): Kubernetes namespace (e.g., `cloudflare-system`)
- `replica_index` (integer): Replica number (0-indexed, e.g., `0` for first pod)
- `image` (string): Container image (e.g., `cloudflare/cloudflared:latest`)
- `status` (enum): Pod lifecycle status
  - `pending`: Pod scheduled, waiting for container start
  - `running`: Container running, tunnel connecting/connected
  - `succeeded`: Container exited successfully (N/A for tunnel, should never happen)
  - `failed`: Container crashed, awaiting restart
  - `unknown`: Kubelet communication lost
- `connection_status` (enum): Tunnel connection state (from cloudflared logs)
  - `initializing`: cloudflared starting up
  - `registering`: Registering with Cloudflare edge
  - `connected`: Active tunnel connection established
  - `reconnecting`: Connection lost, attempting reconnection
  - `failed`: Connection failed after retries
- `restart_count` (integer): Number of pod restarts (indicates stability)
- `cpu_usage` (string): Current CPU usage (e.g., `50m` = 0.05 cores)
- `memory_usage` (string): Current memory usage (e.g., `150Mi`)
- `health_check_status` (enum): Liveness/readiness probe status
  - `healthy`: Probes passing
  - `unhealthy`: Probes failing
- `created_at` (timestamp): Pod creation timestamp
- `last_restart_at` (timestamp, nullable): Last restart timestamp

**Relationships**:
- Belongs to one `Cloudflare Tunnel` (N:1)
- Uses one `Tunnel Token Secret` (N:1)
- Managed by one Kubernetes Deployment (N:1, external to this model)

**Validation Rules**:
- `cpu_usage` must not exceed limits (500m)
- `memory_usage` must not exceed limits (200Mi)
- `health_check_status` must be `healthy` for readiness probe to pass
- `restart_count` threshold: > 5 restarts/hour indicates issue requiring investigation

**State Transitions**:
```
pending → running (container started)
running → failed (container crash, OOM, health check failure)
failed → pending (Kubernetes restarts pod)
running → running (normal operation, connection_status may change)
```

**Health Check Logic**:
- **Liveness Probe**: `GET /ready` on port 2000 every 10 seconds
  - Success: HTTP 200, tunnel connected to Cloudflare
  - Failure (3 consecutive): Kubernetes kills and restarts pod
- **Readiness Probe**: `GET /ready` on port 2000 every 5 seconds
  - Success: HTTP 200, pod added to service endpoints (if metrics service exists)
  - Failure (2 consecutive): Pod removed from service endpoints

**Resource Limits Enforcement**:
- CPU throttling: If usage > 500m, Kubernetes throttles CPU allocation
- Memory limit: If usage > 200Mi, pod OOMKilled and restarted
- Request guarantees: 100m CPU, 100Mi memory reserved on node

---

## Entity Relationship Diagram (ERD)

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Cloudflare Tunnel                          │
│  - tunnel_id (UUID)                                                 │
│  - tunnel_name (string)                                             │
│  - connection_status (enum)                                         │
│  - replica_count (integer)                                          │
└──────────────┬──────────────────────────────────────┬───────────────┘
               │ 1                                    │ 1
               │                                      │
               │ N                                    │ 1
┌──────────────▼───────────────┐       ┌─────────────▼──────────────┐
│      Ingress Rule            │       │   Tunnel Token Secret      │
│  - rule_id (UUID)            │       │  - secret_name (string)    │
│  - public_hostname (string)  │       │  - token_value (secret)    │
│  - service_url (string)      │       └────────────┬───────────────┘
│  - protocol (enum)           │                    │ 1
└──────────────┬───────────────┘                    │
               │ N                                  │ N
               │                                    │
               │ M                      ┌───────────▼────────────────┐
               │                        │  Tunnel Connector Pod      │
┌──────────────▼───────────────┐       │  - pod_name (string)       │
│  Cloudflare Access Policy    │       │  - status (enum)           │
│  - policy_id (UUID)          │       │  - connection_status       │
│  - application_domain        │       │  - health_check_status     │
│  - selector_type (enum)      │       │  - cpu_usage (string)      │
│  - selector_values (array)   │       │  - memory_usage (string)   │
│  - auth_method (enum)        │       └────────────────────────────┘
│  - session_duration (string) │
└──────────────────────────────┘
```

**Relationship Cardinalities**:
- Cloudflare Tunnel → Ingress Rules: 1:N (one tunnel, multiple routes)
- Cloudflare Tunnel → Tunnel Token Secret: 1:1 (one tunnel, one token)
- Cloudflare Tunnel → Tunnel Connector Pods: 1:N (one tunnel, N replicas)
- Ingress Rule → Cloudflare Access Policies: N:M (one route can have multiple policies, one policy can protect multiple routes)
- Tunnel Token Secret → Tunnel Connector Pods: 1:N (one token, mounted by N pods)

---

## Data Flow Diagrams

### User Access Flow (with Authentication)

```
┌─────────────┐                  ┌──────────────────┐
│   User      │ 1. HTTPS Request │  Cloudflare Edge │
│  Browser    ├─────────────────►│   (DNS: CNAME)   │
└─────────────┘  pihole.example  └────────┬─────────┘
                                           │
                                           │ 2. Check Session Token
                                           │
                                  ┌────────▼─────────┐
                                  │ Cloudflare Access│
                                  │  (Policy Check)  │
                                  └────────┬─────────┘
                                           │
                   ┌───────────────────────┼────────────────────┐
                   │ No Token/Expired      │ Valid Token        │
                   ▼                       ▼                    │
          ┌────────────────┐      ┌───────────────┐            │
          │ Google OAuth   │      │ Forward to    │            │
          │ Authentication │      │ Tunnel        │            │
          └────────┬───────┘      └───────┬───────┘            │
                   │                      │                    │
                   │ 3. Auth Success      │ 4. HTTP Request    │
                   ▼                      ▼                    │
          ┌────────────────┐      ┌───────────────────┐       │
          │ Issue Session  │      │ Tunnel Connector  │       │
          │ Token (24h)    │      │ Pod (cloudflared) │       │
          └────────┬───────┘      └───────┬───────────┘       │
                   │                      │                    │
                   │ Redirect with Token  │ 5. K8s DNS Lookup  │
                   └──────────────────────┼────────────────────┘
                                          │
                                  ┌───────▼──────────┐
                                  │ Kubernetes       │
                                  │ Service          │
                                  │ (pihole-web:80)  │
                                  └───────┬──────────┘
                                          │
                                          │ 6. HTTP Response
                                          ▼
                                  ┌───────────────────┐
                                  │ Pi-hole Container │
                                  │ (Admin Dashboard) │
                                  └───────────────────┘
```

### Pod Failure Recovery Flow

```
┌─────────────────┐
│ Tunnel Pod      │ Status: Running, connection_status: connected
│ (cloudflared)   │
└────────┬────────┘
         │
         │ Liveness Probe: GET /ready
         ▼
┌─────────────────┐
│ Health Check    │ Failure (3x) → /ready returns 500 or timeout
│ Endpoint :2000  │
└────────┬────────┘
         │
         │ health_check_status: unhealthy
         ▼
┌─────────────────┐
│ Kubernetes      │ Action: Kill pod (SIGTERM → SIGKILL)
│ Kubelet         │
└────────┬────────┘
         │
         │ status: failed → pending
         ▼
┌─────────────────┐
│ Kubernetes      │ Action: Schedule new pod on node
│ Scheduler       │
└────────┬────────┘
         │
         │ Pull image, create container
         ▼
┌─────────────────┐
│ New Tunnel Pod  │ Status: Running, connection_status: registering
│ (cloudflared)   │
└────────┬────────┘
         │
         │ cloudflared: tunnel run --token $TOKEN
         ▼
┌─────────────────┐
│ Cloudflare Edge │ Tunnel registered, connection established
│ Network         │
└────────┬────────┘
         │
         │ connection_status: connected (< 30 seconds)
         ▼
┌─────────────────┐
│ User Requests   │ Resume normal traffic flow
│ Resume          │
└─────────────────┘
```

---

## State Management

### Tunnel Connection States

| State | Description | Triggers | Next States |
|-------|-------------|----------|-------------|
| `disconnected` | No active connection to Cloudflare | Initial state, network failure, pod restart | `connecting` |
| `connecting` | Attempting to establish connection | Pod started, auto-reconnect | `connected`, `disconnected` (timeout) |
| `connected` | Active connection, routing traffic | Successful registration | `degraded`, `disconnected` |
| `degraded` | Connection issues (packet loss, high latency) | Network instability detected | `connected`, `disconnected` |

### Pod Lifecycle States

| State | Description | Triggers | Next States |
|-------|-------------|----------|-------------|
| `pending` | Pod scheduled, waiting for container start | Deployment created, pod restart | `running`, `failed` |
| `running` | Container running, may be connecting/connected | Container started successfully | `failed`, `running` (normal) |
| `failed` | Container crashed or health check failed | OOMKilled, panic, liveness probe failure | `pending` (restart) |
| `unknown` | Kubelet lost connection to control plane | Network partition | `running`, `failed` |

### Access Policy Evaluation States

| State | Description | Triggers | Next States |
|-------|-------------|----------|-------------|
| `unauthenticated` | No session token present | Initial request, token expired | `authenticating` |
| `authenticating` | OAuth flow in progress | Redirect to Google OAuth | `authorized`, `denied` |
| `authorized` | Policy matched, session token issued | Email in selector_values | `unauthenticated` (after 24h) |
| `denied` | Policy not matched or explicit deny | Email not in selector_values | N/A (terminal state, user must re-attempt) |

---

## Data Persistence

### Persistent Data (survives pod restart):
- **Tunnel Token Secret**: Stored in etcd (Kubernetes Secret), encrypted at rest
- **Ingress Rules**: Stored in Cloudflare Zero Trust dashboard/API (external to cluster)
- **Access Policies**: Stored in Cloudflare Zero Trust dashboard/API (external to cluster)

### Ephemeral Data (lost on pod restart):
- **Pod metrics** (CPU/memory usage): Available only while pod running
- **Connection logs**: cloudflared stdout/stderr (captured by Kubernetes logging if configured)
- **Session tokens**: Stored in user browser cookies (24h TTL)

### Backup Requirements:
- **Tunnel Token**: Backup terraform.tfvars file (excluded from Git, stored securely)
- **Ingress Rules**: Export via Cloudflare API or Terraform state (future)
- **Access Policies**: Export via Cloudflare API or Terraform state (future)

---

## Validation & Constraints Summary

### At Deployment Time:
- ✅ Tunnel token must be valid base64 JWT format
- ✅ Kubernetes Secret must exist before Deployment creation
- ✅ Resource limits must be defined (CPU/memory)
- ✅ Health check endpoints must be configured
- ✅ Service URLs must use valid Kubernetes DNS names

### At Runtime:
- ✅ Pod must connect to Cloudflare within 30 seconds (liveness probe threshold)
- ✅ Memory usage must stay below 200Mi (OOMKill threshold)
- ✅ Restart count should remain low (< 5/hour indicates stability)
- ✅ User session tokens expire after 24 hours (re-authentication required)

### At Access Policy Evaluation:
- ✅ User email must match at least one `selector_values` entry
- ✅ Session token must not be expired
- ✅ Application domain must match requested hostname

---

## Future Enhancements (Out of Scope for MVP)

- **Terraform API Automation**: Manage ingress rules via `cloudflare_tunnel_config` resource
- **Multiple Replicas (HA)**: Increase replica_count to 2-3 for high availability
- **Prometheus Metrics**: Scrape cloudflared `/metrics` endpoint for observability
- **Custom Domains**: Add multiple domains beyond primary Cloudflare account domain
- **Path-Based Routing**: Support `path` attribute for routing by URL path
- **End-to-End TLS**: Enable `tls_verify` for internal service certificate validation
- **Audit Logging**: Export Cloudflare Access logs to SIEM or syslog server
- **Token Rotation**: Implement automated tunnel token rotation (security enhancement)
