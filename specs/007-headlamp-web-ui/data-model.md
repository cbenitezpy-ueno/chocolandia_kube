# Data Model: Headlamp Web UI

**Feature**: 007-headlamp-web-ui
**Date**: 2025-11-12
**Status**: Design Complete

## Overview

This document describes the Kubernetes resources and their relationships for deploying Headlamp web UI. All entities are Kubernetes-native resources (Deployment, Service, IngressRoute, Certificate, etc.) managed via OpenTofu.

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Cloudflare Access Layer                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Access Application (headlamp.chocolandiadc.com)                   │  │
│  │  - Google OAuth Identity Provider                                 │  │
│  │  - Access Policy (email: cbenitez@gmail.com)                      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           Traefik Ingress Layer                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ IngressRoute (HTTPS)                                              │  │
│  │  - Host: headlamp.chocolandiadc.com                               │  │
│  │  - TLS Secret: headlamp-tls ──────────────┐                       │  │
│  │  - Service: headlamp:80                   │                       │  │
│  └───────────────────────────────────────────┼───────────────────────┘  │
│                                              │                          │
│  ┌───────────────────────────────────────────┼───────────────────────┐  │
│  │ IngressRoute (HTTP) - Redirect            │                       │  │
│  │  - Middleware: https-redirect             │                       │  │
│  └───────────────────────────────────────────┼───────────────────────┘  │
└─────────────────────────────────────────────┼───────────────────────────┘
                                              │
                                              ▼
                        ┌────────────────────────────────────┐
                        │    Certificate (cert-manager)       │
                        │  - Name: headlamp-cert              │
                        │  - Issuer: letsencrypt-production   │
                        │  - Domain: headlamp.chocolandiadc.  │
                        │            com                      │
                        │  - Secret: headlamp-tls             │
                        │  - Renewal: 30 days before expiry   │
                        └────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Service Layer                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Service (headlamp)                                                │  │
│  │  - Type: ClusterIP                                                │  │
│  │  - Port: 80 → targetPort: 4466                                    │  │
│  │  - Selector: app.kubernetes.io/name=headlamp                      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Workload Layer (Pods)                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Deployment (headlamp)                                             │  │
│  │  - Replicas: 2                                                    │  │
│  │  - Image: ghcr.io/headlamp-k8s/headlamp:v0.38.0                  │  │
│  │  - Resources: 100m CPU / 128Mi RAM                                │  │
│  │  - Health: liveness + readiness probes                            │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │ Pod 1 (node1)          │ Pod 2 (node2)                      │  │  │
│  │  │  - Container: headlamp │  - Container: headlamp             │  │  │
│  │  │  - Port: 4466          │  - Port: 4466                      │  │  │
│  │  │  - Volume: config       │  - Volume: config                  │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ (accesses via ServiceAccount token)
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         RBAC Authorization Layer                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ ServiceAccount (headlamp-admin)                                   │  │
│  │  - Namespace: headlamp                                            │  │
│  │  - Secret: headlamp-admin-token (long-lived token)                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                  │                                       │
│                                  │ (bound via)                           │
│                                  ▼                                       │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ ClusterRoleBinding (headlamp-view-binding)                        │  │
│  │  - Subject: ServiceAccount headlamp-admin                         │  │
│  │  - Role: ClusterRole "view" (built-in read-only)                  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                  │                                       │
│                                  ▼                                       │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ ClusterRole "view" (Kubernetes built-in)                          │  │
│  │  - Verbs: get, list, watch (read-only)                            │  │
│  │  - Resources: Pods, Services, Deployments, etc.                   │  │
│  │  - Exclusions: Secrets (no access)                                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ (queries for metrics)
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Observability Layer (Optional)                     │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Prometheus (monitoring namespace)                                 │  │
│  │  - URL: http://prometheus-kube-prometheus-prometheus.             │  │
│  │         monitoring:9090                                           │  │
│  │  - Used by Headlamp UI to display workload metrics                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Core Entities

### 1. Deployment (Workload)

**Purpose**: Runs Headlamp web UI container(s)

**Key Attributes**:
- **Name**: `headlamp`
- **Namespace**: `headlamp`
- **Replicas**: 2 (HA across 2-node cluster)
- **Image**: `ghcr.io/headlamp-k8s/headlamp:v0.38.0`
- **Container Port**: 4466 (Headlamp default)
- **Resources**:
  - Requests: 100m CPU, 128Mi RAM
  - Limits: 200m CPU, 256Mi RAM
- **Health Checks**:
  - Liveness probe: HTTP GET / (port 4466)
  - Readiness probe: HTTP GET / (port 4466)
- **Pod Anti-Affinity**: Preferentially distribute pods across different nodes

**Relationships**:
- **Creates**: Pod replicas (2)
- **Selected by**: Service (via label selector)
- **Authenticated as**: ServiceAccount `headlamp-admin`

**State Transitions**:
- Initial: 0 pods → Scaling: Creating 2 pods → Running: 2/2 pods ready
- On update: Rolling update (maxUnavailable: 1, maxSurge: 1)
- On failure: Pod restarts automatically (Kubernetes restart policy)

**Validation Rules**:
- Replicas must be ≥1 for availability
- Resource limits must be ≥ requests
- Health probes must succeed within timeout

---

### 2. Service (Networking)

**Purpose**: Exposes Headlamp deployment within cluster (ClusterIP)

**Key Attributes**:
- **Name**: `headlamp`
- **Namespace**: `headlamp`
- **Type**: ClusterIP (internal only)
- **Port**: 80 (exposed to IngressRoute)
- **TargetPort**: 4466 (container port)
- **Selector**: `app.kubernetes.io/name: headlamp`

**Relationships**:
- **Targets**: Deployment pods (via label selector)
- **Referenced by**: IngressRoute (as backend service)
- **DNS Name**: `headlamp.headlamp.svc.cluster.local`

**State Transitions**:
- Created → Endpoints populated (when pods ready) → Traffic routing active
- Pod changes → Endpoints updated automatically

**Validation Rules**:
- Port must match IngressRoute service reference
- Selector must match Deployment pod labels
- Type must be ClusterIP (Traefik handles external access)

---

### 3. IngressRoute (HTTP - Redirect)

**Purpose**: Redirect all HTTP traffic to HTTPS

**Key Attributes**:
- **Name**: `headlamp-http`
- **Namespace**: `headlamp`
- **EntryPoint**: `web` (port 80)
- **Host**: `headlamp.chocolandiadc.com`
- **Middleware**: `https-redirect`
- **Backend**: `noop@internal` (Traefik special service)

**Relationships**:
- **Uses**: Middleware `https-redirect`
- **Terminates**: HTTP requests (returns 301 redirect)

**State Transitions**:
- Created → Traefik syncs → HTTP requests redirected to HTTPS

**Validation Rules**:
- Host must match certificate domain
- Middleware must exist in same namespace
- EntryPoint must be Traefik's `web`

---

### 4. IngressRoute (HTTPS - Service)

**Purpose**: Route HTTPS traffic to Headlamp service

**Key Attributes**:
- **Name**: `headlamp-https`
- **Namespace**: `headlamp`
- **EntryPoint**: `websecure` (port 443)
- **Host**: `headlamp.chocolandiadc.com`
- **TLS Secret**: `headlamp-tls` (cert-manager generated)
- **Backend**: Service `headlamp` port 80

**Relationships**:
- **Routes to**: Service `headlamp`
- **Uses**: TLS Secret `headlamp-tls` (from Certificate)
- **Protected by**: Cloudflare Access (upstream)

**State Transitions**:
- Created → Traefik syncs → HTTPS traffic routed to service
- Certificate renewal → TLS Secret updated → Traefik picks up new cert

**Validation Rules**:
- TLS secretName must match Certificate secretName
- Service must exist and be reachable
- Host must be resolvable via DNS

---

### 5. Certificate (cert-manager)

**Purpose**: Manage TLS certificate lifecycle for Headlamp domain

**Key Attributes**:
- **Name**: `headlamp-cert`
- **Namespace**: `headlamp`
- **Secret Name**: `headlamp-tls` (where certificate is stored)
- **Issuer**: ClusterIssuer `letsencrypt-production`
- **Domain**: `headlamp.chocolandiadc.com`
- **Duration**: 90 days (Let's Encrypt max)
- **Renew Before**: 30 days before expiration

**Relationships**:
- **Uses**: ClusterIssuer `letsencrypt-production` (cluster-wide resource)
- **Creates**: Secret `headlamp-tls` (TLS certificate + private key)
- **Referenced by**: IngressRoute HTTPS (TLS configuration)

**State Transitions**:
1. Created → CertificateRequest created → ACME challenge initiated
2. DNS-01 challenge (Cloudflare) → Validation succeeds → Certificate issued
3. Secret `headlamp-tls` created/updated with cert + key
4. 60 days → Renewal check → CertificateRequest created → New cert issued

**Validation Rules**:
- Domain must be controlled (Cloudflare DNS)
- ClusterIssuer must exist and be ready
- Secret must not be manually modified (cert-manager owns it)

---

### 6. ServiceAccount (RBAC)

**Purpose**: Identity for Headlamp to authenticate to Kubernetes API

**Key Attributes**:
- **Name**: `headlamp-admin`
- **Namespace**: `headlamp`
- **Token Secret**: `headlamp-admin-token` (long-lived)

**Relationships**:
- **Bound to**: ClusterRoleBinding `headlamp-view-binding`
- **Used by**: Headlamp users (via UI login)
- **Creates**: Secret `headlamp-admin-token` (bearer token)

**State Transitions**:
- Created → Token secret auto-generated → Token extracted for UI login

**Validation Rules**:
- Must exist in same namespace as Deployment
- Token must be base64 decodable
- Token must not expire (long-lived)

---

### 7. ClusterRoleBinding (RBAC)

**Purpose**: Grant ServiceAccount read-only access to cluster resources

**Key Attributes**:
- **Name**: `headlamp-view-binding`
- **Subject**: ServiceAccount `headlamp-admin` (namespace: headlamp)
- **RoleRef**: ClusterRole `view` (Kubernetes built-in)
- **Scope**: Cluster-wide (all namespaces)

**Relationships**:
- **Grants**: ServiceAccount → ClusterRole permissions
- **Enforces**: Read-only access (get, list, watch)
- **Protects**: Secrets (not included in "view" role)

**State Transitions**:
- Created → RBAC enforced immediately → ServiceAccount can access cluster resources

**Validation Rules**:
- RoleRef must point to existing ClusterRole "view"
- Subject must reference existing ServiceAccount
- Cannot be modified after creation (delete + recreate)

---

### 8. Cloudflare Access Application

**Purpose**: Protect Headlamp with Google OAuth authentication

**Key Attributes**:
- **Name**: "Headlamp Kubernetes Dashboard"
- **Domain**: `headlamp.chocolandiadc.com`
- **Type**: `self_hosted`
- **Session Duration**: 24h
- **Identity Provider**: Google OAuth

**Relationships**:
- **Protects**: IngressRoute (HTTPS endpoint)
- **Uses**: Access Policy (email-based rules)
- **Integrates**: Google OAuth IdP

**State Transitions**:
1. User accesses URL → Cloudflare Access intercepts
2. Redirect to Google OAuth → User authenticates
3. Email validated against policy → Access granted/denied
4. JWT cookie issued → User redirected to Headlamp

**Validation Rules**:
- Domain must match IngressRoute host
- Policy must exist with allow decision
- Google OAuth must be configured

---

### 9. Cloudflare Access Policy

**Purpose**: Define who can access Headlamp

**Key Attributes**:
- **Name**: "Allow Homelab Admins"
- **Decision**: `allow`
- **Include**: Email list (cbenitez@gmail.com, etc.)
- **Require**: Google OAuth login method
- **Session**: 24h

**Relationships**:
- **Attached to**: Access Application
- **Enforces**: Email whitelist
- **Requires**: Google OAuth authentication

**State Transitions**:
- User matches include rule → Access granted → JWT issued
- User not in include list → Access denied → 403 Forbidden

**Validation Rules**:
- At least one include rule required
- Email format must be valid
- Login method must reference existing IdP

---

## Entity Lifecycle Flows

### Deployment Flow
```
OpenTofu apply
    ↓
Namespace created (headlamp)
    ↓
ServiceAccount + Secret created
    ↓
ClusterRoleBinding created
    ↓
Deployment created
    ↓
Pods scheduled → Images pulled → Containers started
    ↓
Health checks pass → Pods Ready
    ↓
Service endpoints updated
    ↓
Certificate CRD created
    ↓
cert-manager issues certificate → Secret created
    ↓
IngressRoute created (HTTP + HTTPS)
    ↓
Traefik syncs routes
    ↓
Cloudflare Access configured
    ↓
User can access https://headlamp.chocolandiadc.com
```

### Authentication Flow
```
User accesses https://headlamp.chocolandiadc.com
    ↓
Cloudflare Access intercepts → Redirect to Google OAuth
    ↓
User authenticates with Google
    ↓
Cloudflare validates email against policy
    ↓
[PASS] JWT cookie issued → Redirect to Headlamp
    ↓
Traefik routes HTTPS → Service → Pod
    ↓
Headlamp UI loads → Shows token login form
    ↓
User pastes ServiceAccount token
    ↓
Headlamp validates token against Kubernetes API
    ↓
[PASS] Token stored in localStorage → Dashboard loads
    ↓
Headlamp queries cluster resources (via ServiceAccount permissions)
    ↓
RBAC enforces read-only access (ClusterRole "view")
```

### Certificate Renewal Flow
```
60 days after issuance
    ↓
cert-manager checks renewBefore (30 days)
    ↓
CertificateRequest created
    ↓
ACME challenge initiated (DNS-01)
    ↓
Cloudflare DNS updated with challenge record
    ↓
Let's Encrypt validates → New certificate issued
    ↓
Secret headlamp-tls updated (atomic)
    ↓
Traefik detects Secret change → Reloads certificate
    ↓
Zero-downtime renewal complete
```

---

## Data Validation Matrix

| Entity | Validation Point | Check | Failure Action |
|--------|------------------|-------|----------------|
| Deployment | Pod creation | Image pull succeeds | Retry with backoff |
| Deployment | Health checks | Liveness/readiness pass | Restart pod |
| Service | Endpoint sync | Pods match selector | Update endpoints |
| Certificate | ACME challenge | DNS-01 validation | Retry, log error |
| IngressRoute | TLS Secret | Secret exists | Wait for cert-manager |
| ServiceAccount | Token generation | Secret created | Manual investigation |
| Access Policy | User auth | Email in include list | Deny access (403) |

---

## Dependency Graph

```
OpenTofu Module (headlamp)
    ├── Depends on: K3s cluster (Feature 001)
    ├── Depends on: Traefik (Feature 005)
    ├── Depends on: cert-manager (Feature 006)
    ├── Depends on: Cloudflare Zero Trust (Feature 004)
    ├── Depends on: Prometheus (existing)
    └── Outputs:
        ├── Service endpoint (internal)
        ├── IngressRoute hostname
        └── ServiceAccount token (for UI login)
```

---

## Resource Ownership

| Resource | Owner | Lifecycle |
|----------|-------|-----------|
| Namespace `headlamp` | OpenTofu | Created/deleted with module |
| Deployment | OpenTofu (Helm) | Managed by Helm release |
| Service | OpenTofu (Helm) | Managed by Helm release |
| IngressRoute | OpenTofu | Created/deleted with module |
| Certificate | OpenTofu | Created/deleted with module |
| Secret `headlamp-tls` | cert-manager | Auto-created/renewed |
| ServiceAccount | OpenTofu | Created/deleted with module |
| Secret `headlamp-admin-token` | Kubernetes | Auto-created with ServiceAccount |
| ClusterRoleBinding | OpenTofu | Created/deleted with module |
| Access Application | OpenTofu | Created/deleted with module |
| Access Policy | OpenTofu | Created/deleted with module |

---

## State Management

**OpenTofu State**:
- Tracks all created resources
- Detects drift (manual changes)
- Enables destroy operation

**Kubernetes etcd State**:
- Stores all Kubernetes resources
- Manages resource versions (optimistic concurrency)
- Survives node failures (HA etcd)

**cert-manager State**:
- Tracks certificate issuance/renewal
- Stores private keys in Secrets
- Maintains CertificateRequest history

**Cloudflare State**:
- Access Application configuration
- Policy rules
- Session tokens (JWT in cookies)

---

## Next Steps

Data model complete. Ready to:
1. Generate quickstart.md (deployment procedure)
2. Update agent context (CLAUDE.md)
3. Proceed to Phase 2 (/speckit.tasks)
