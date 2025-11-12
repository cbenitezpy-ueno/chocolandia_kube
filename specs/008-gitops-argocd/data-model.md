# Phase 1: Data Model - ArgoCD Entities and Relationships

**Feature**: 008-gitops-argocd
**Date**: 2025-11-12
**Status**: Complete

## Overview

This document defines the core entities, attributes, relationships, and state transitions for the ArgoCD GitOps implementation in chocolandia_kube. ArgoCD operates on declarative Kubernetes Custom Resources (CRDs) that define how Git repositories are synchronized to cluster resources.

---

## Core Entities

### 1. ArgoCD Application

**Description**: Kubernetes custom resource (CRD) that defines a Git repository source, target cluster destination, and sync policies for continuous deployment.

**Attributes**:
- `name` (string, required): Unique identifier for the Application (e.g., "chocolandia-kube", "portfolio-app")
- `namespace` (string, required): Kubernetes namespace where Application resource lives (typically "argocd")
- `project` (string, required): ArgoCD Project name for RBAC scoping (default: "default")
- `repoURL` (string, required): Git repository URL (e.g., "https://github.com/cbenitez/chocolandia_kube")
- `targetRevision` (string, required): Git branch, tag, or commit SHA to sync (e.g., "main", "v1.0.0")
- `path` (string, required): Directory path in repository containing Kubernetes manifests (e.g., "kubernetes/argocd/applications")
- `destination.server` (string, required): Kubernetes API server URL (e.g., "https://kubernetes.default.svc" for in-cluster)
- `destination.namespace` (string, optional): Target namespace for deployed resources (can be overridden per-resource)
- `syncPolicy.automated` (object, optional): Auto-sync configuration (null = manual sync)
  - `prune` (boolean): Auto-delete resources removed from Git
  - `selfHeal` (boolean): Auto-revert manual changes to match Git state
  - `allowEmpty` (boolean): Allow sync when no resources in Git (default: false)
- `syncPolicy.syncOptions` (array of strings): Sync behavior modifiers
  - `CreateNamespace=true`: Auto-create destination namespace
  - `PruneLast=true`: Delete resources last during sync
- `syncPolicy.retry` (object): Retry policy for failed syncs
  - `limit` (int): Maximum retry attempts (e.g., 5)
  - `backoff.duration` (string): Initial retry delay (e.g., "5s")
  - `backoff.factor` (int): Exponential backoff multiplier (e.g., 2)
  - `backoff.maxDuration` (string): Maximum retry delay (e.g., "3m")
- `ignoreDifferences` (array of objects): Fields to ignore during drift detection
- `finalizers` (array of strings): Cascade delete behavior (e.g., "resources-finalizer.argocd.argoproj.io")

**State**: Read from `status` field:
- `sync.status` (enum): Synced, OutOfSync, Unknown
- `health.status` (enum): Healthy, Progressing, Degraded, Suspended, Missing, Unknown
- `operationState.phase` (enum): Running, Succeeded, Failed, Error, Terminating
- `sync.revision` (string): Git commit SHA of last synced state

**Relationships**:
- **Belongs to**: ArgoCD Project (1:1, required)
- **References**: Git Repository (1:1, required)
- **Manages**: Kubernetes Resources (1:many, lifecycle managed)
- **Creates**: Sync Operations (1:many, historical record)

---

### 2. ArgoCD Project

**Description**: Logical grouping of Applications with RBAC policies and resource restrictions for multi-tenant isolation.

**Attributes**:
- `name` (string, required): Project name (e.g., "default", "web-apps", "infrastructure")
- `namespace` (string, required): Always "argocd"
- `description` (string, optional): Human-readable project description
- `sourceRepos` (array of strings): Allowed Git repository URLs (["*"] = all repos)
- `destinations` (array of objects): Allowed deployment targets
  - `server` (string): Kubernetes API server URL
  - `namespace` (string): Allowed namespace pattern (e.g., "web-*", "*")
- `clusterResourceWhitelist` (array of objects): Allowed cluster-scoped resources
  - `group` (string): API group (e.g., "", "rbac.authorization.k8s.io")
  - `kind` (string): Resource kind (e.g., "Namespace", "ClusterRole")
- `namespaceResourceBlacklist` (array of objects): Denied namespace-scoped resources
- `roles` (array of objects): RBAC roles for project access

**Relationships**:
- **Contains**: Applications (1:many)
- **Enforces**: RBAC Policies (1:many)

---

### 3. Git Repository Credentials

**Description**: Kubernetes Secret storing authentication credentials for private Git repository access.

**Attributes**:
- `name` (string, required): Secret name (e.g., "chocolandia-kube-repo")
- `namespace` (string, required): "argocd"
- `type` (string, required): "Opaque"
- `data.type` (string): "git"
- `data.url` (string): Git repository URL
- `data.username` (string): GitHub username (e.g., "cbenitez")
- `data.password` (string): GitHub Personal Access Token (base64 encoded)
- `labels` (map): Metadata labels (e.g., `argocd.argoproj.io/secret-type: repository`)

**Security**:
- Never committed to Git (managed via OpenTofu sensitive variables)
- Access restricted to ArgoCD ServiceAccount via RBAC
- Token rotation requires Secret update + ArgoCD pod restart

**Relationships**:
- **Used by**: ArgoCD Application (many:1, for private repo authentication)

---

### 4. Sync Operation

**Description**: Runtime record of a single synchronization attempt (Git → Cluster).

**Attributes**:
- `uid` (string): Unique operation ID
- `phase` (enum): Running, Succeeded, Failed, Error, Terminating
- `startedAt` (timestamp): When sync started (ISO 8601)
- `finishedAt` (timestamp): When sync completed or failed
- `message` (string): Human-readable status message
- `syncResult` (object): Detailed sync results
  - `resources` (array): Per-resource sync status
    - `group`, `kind`, `namespace`, `name`: Resource identifier
    - `status` (enum): Synced, OutOfSync, Pruned
    - `message`: Status details
    - `hookPhase` (enum): PreSync, Sync, PostSync, SyncFail (if resource is hook)
- `revision` (string): Git commit SHA that was synced
- `source` (object): Git repository source details

**Relationships**:
- **Created by**: ArgoCD Application (many:1)
- **Modifies**: Kubernetes Resources (1:many)

---

### 5. ArgoCD Deployment (Infrastructure)

**Description**: Kubernetes Deployments running ArgoCD platform components.

**Components**:

#### argocd-server
- **Replicas**: 1 (homelab scale)
- **Resources**: 256Mi memory limit, 200m CPU limit
- **Ports**: 8080 (HTTP), 8083 (gRPC), 8084 (metrics)
- **Purpose**: Web UI, API server, gRPC endpoint

#### argocd-repo-server
- **Replicas**: 1
- **Resources**: 128Mi memory limit, 200m CPU limit
- **Ports**: 8081 (gRPC), 8084 (metrics)
- **Purpose**: Git repository operations (clone, fetch), manifest generation

#### argocd-application-controller
- **Replicas**: 1
- **Resources**: 512Mi memory limit, 500m CPU limit
- **Ports**: 8082 (metrics)
- **Purpose**: Application reconciliation loop, health assessment, sync operations

#### argocd-redis
- **Replicas**: 1 (embedded, no HA)
- **Resources**: 128Mi memory limit, 100m CPU limit
- **Ports**: 6379 (Redis)
- **Purpose**: Caching layer for Git repository data, application state

**Relationships**:
- **Managed by**: Helm Release (1:1, OpenTofu-managed)
- **Exposes**: Kubernetes Services (1:many, for networking)
- **Scrapes**: Prometheus (many:1, via ServiceMonitor)

---

### 6. Traefik IngressRoute (ArgoCD Ingress)

**Description**: Traefik CRD defining HTTP/HTTPS routing to ArgoCD web UI.

**Attributes**:
- `name` (string): "argocd-server"
- `namespace` (string): "argocd"
- `entryPoints` (array): ["websecure"] (HTTPS only)
- `routes[0].match` (string): Host(`argocd.chocolandiadc.com`)
- `routes[0].services[0].name` (string): "argocd-server"
- `routes[0].services[0].port` (int): 443
- `tls.secretName` (string): "argocd-tls" (cert-manager Certificate)

**Relationships**:
- **Routes to**: ArgoCD Server Service (1:1)
- **Uses**: TLS Certificate (1:1, from cert-manager)
- **Protected by**: Cloudflare Access Application (1:1)

---

### 7. Certificate (TLS for ArgoCD)

**Description**: cert-manager CRD managing TLS certificate lifecycle for ArgoCD domain.

**Attributes**:
- `name` (string): "argocd-tls"
- `namespace` (string): "argocd"
- `secretName` (string): "argocd-tls" (where certificate is stored)
- `issuerRef.name` (string): "letsencrypt-production" (ClusterIssuer)
- `issuerRef.kind` (string): "ClusterIssuer"
- `dnsNames` (array): ["argocd.chocolandiadc.com"]
- `duration` (string): "2160h" (90 days)
- `renewBefore` (string): "720h" (30 days before expiry)

**State**:
- `status.conditions[type=Ready]`: Certificate issuance status
- `status.notAfter`: Certificate expiration timestamp

**Relationships**:
- **Issued by**: ClusterIssuer (many:1, letsencrypt-production)
- **Stores**: TLS Secret (1:1, argocd-tls)
- **Used by**: IngressRoute (1:1)

---

### 8. Cloudflare Access Application (ArgoCD Protection)

**Description**: Cloudflare Zero Trust application protecting ArgoCD web UI with Google OAuth authentication.

**Attributes**:
- `name` (string): "ArgoCD GitOps Dashboard"
- `account_id` (string): Cloudflare account ID
- `domain` (string): "argocd.chocolandiadc.com"
- `type` (string): "self_hosted"
- `session_duration` (string): "24h"
- `auto_redirect_to_identity` (boolean): true
- `app_launcher_visible` (boolean): true

**Relationships**:
- **Enforces**: Access Policy (1:1, required)
- **Protects**: IngressRoute (1:1, argocd-server)

---

### 9. Cloudflare Access Policy

**Description**: Access control policy defining who can authenticate to ArgoCD.

**Attributes**:
- `application_id` (string): Reference to Access Application
- `name` (string): "ArgoCD Authorized Users"
- `precedence` (int): 1 (evaluation order)
- `decision` (enum): allow, deny, non_identity, bypass
- `include.email` (array of strings): Allowed email addresses
- `require.login_method` (array of strings): Required identity provider IDs

**Relationships**:
- **Belongs to**: Access Application (1:1, required)
- **Enforces**: Google OAuth Identity Provider (many:1)

---

### 10. ServiceMonitor (Prometheus Scraping)

**Description**: Prometheus Operator CRD defining metrics scraping targets for ArgoCD components.

**Attributes**:
- `name` (string): "argocd-metrics"
- `namespace` (string): "argocd"
- `selector.matchLabels` (map): Labels to select ArgoCD services
- `endpoints` (array): Scrape configuration per component
  - `port` (string): Service port name (e.g., "metrics")
  - `interval` (string): Scrape interval (e.g., "30s")
  - `path` (string): Metrics endpoint path (e.g., "/metrics")

**Metrics Exposed**:
- `argocd_app_sync_total`: Total sync operations per Application
- `argocd_app_health_status`: Application health status (0-4 scale)
- `argocd_app_sync_status`: Application sync status (0-2 scale)
- `argocd_git_request_total`: Git repository requests
- `argocd_git_request_duration_seconds`: Git operation latency

**Relationships**:
- **Scrapes**: ArgoCD Services (1:many, argocd-server, argocd-repo-server, argocd-application-controller)
- **Collected by**: Prometheus (many:1)

---

## Entity Relationships Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            ArgoCD GitOps System                              │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌──────────────────────┐
                    │   GitHub Repository  │
                    │  chocolandia_kube    │
                    │  (Git source)        │
                    └──────────┬───────────┘
                               │ polls (3min)
                               ▼
         ┌─────────────────────────────────────────┐
         │        ArgoCD Application CRD            │
         │  - name: chocolandia-kube               │
         │  - repoURL: github.com/cbenitez/...    │
         │  - targetRevision: main                 │
         │  - path: kubernetes/argocd/applications │
         │  - syncPolicy: manual → automated       │
         └──────┬──────────────────────────────────┘
                │ belongs to
                ▼
         ┌──────────────────┐        manages        ┌───────────────────┐
         │  ArgoCD Project  │ ◄──────────────────── │  Sync Operation   │
         │  (default)       │                       │  - phase: Running │
         └──────────────────┘                       │  - revision: abc   │
                                                    └──────────┬────────┘
                                                               │ modifies
                                                               ▼
                                          ┌────────────────────────────────────┐
                                          │    Kubernetes Resources            │
                                          │  (Deployments, Services, Secrets)  │
                                          └────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                          ArgoCD Infrastructure                               │
└──────────────────────────────────────────────────────────────────────────────┘

     ┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
     │  argocd-server   │        │ argocd-repo      │        │ argocd-controller│
     │  (Web UI/API)    │ ◄─────►│  -server         │ ◄─────►│ (Sync engine)    │
     │  Replicas: 1     │        │  (Git ops)       │        │ Replicas: 1      │
     └────────┬─────────┘        └──────────────────┘        └──────────────────┘
              │                            │
              │ caches                     │
              ▼                            ▼
     ┌──────────────────┐        ┌──────────────────────────────────────┐
     │  argocd-redis    │        │  Git Repository Credentials Secret   │
     │  (Cache layer)   │        │  - type: git                         │
     │  Replicas: 1     │        │  - password: <GITHUB_PAT>            │
     └──────────────────┘        └──────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                        External Access & Security                            │
└──────────────────────────────────────────────────────────────────────────────┘

   Internet                Cloudflare Tunnel              K3s Cluster
      │                           │                            │
      ▼                           ▼                            ▼
┌────────────────┐       ┌─────────────────┐        ┌──────────────────┐
│ User Browser   │ ────► │ Cloudflare      │ ─────► │ Traefik          │
│ (OAuth login)  │       │ Access Policy   │        │ IngressRoute     │
└────────────────┘       │ (email check)   │        │ argocd.domain    │
                         └─────────────────┘        └────────┬─────────┘
                                                              │ routes to
                                                              ▼
                                                    ┌──────────────────┐
                                                    │ argocd-server    │
                                                    │ Service (443)    │
                                                    └──────────────────┘
                                                              │ uses
                                                              ▼
                         ┌──────────────────────────────────────────────┐
                         │  Certificate (cert-manager CRD)              │
                         │  - issuer: letsencrypt-production            │
                         │  - dnsNames: [argocd.chocolandiadc.com]     │
                         │  - secret: argocd-tls                        │
                         └──────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                               Observability                                  │
└──────────────────────────────────────────────────────────────────────────────┘

         ┌──────────────────┐        scrapes       ┌──────────────────┐
         │  ServiceMonitor  │ ◄────────────────── │   Prometheus     │
         │  argocd-metrics  │                      │  (kube-prom)     │
         └────────┬─────────┘                      └────────┬─────────┘
                  │ targets                                 │ queries
                  ▼                                         ▼
    ┌──────────────────────────────────┐         ┌──────────────────┐
    │  ArgoCD Components /metrics      │         │    Grafana       │
    │  - argocd-server:8084           │         │  (dashboards)    │
    │  - argocd-repo-server:8084      │         └──────────────────┘
    │  - argocd-controller:8082       │
    └──────────────────────────────────┘
```

---

## State Transitions

### Application Sync State Machine

```
                    ┌──────────────┐
                    │   Unknown    │ (Initial state)
                    └──────┬───────┘
                           │ first sync
                           ▼
                    ┌──────────────┐
             ┌─────►│   Synced     │◄─────┐
             │      └──────┬───────┘      │
             │             │              │ self-heal
             │             │ Git change   │
             │             ▼              │
             │      ┌──────────────┐      │
             │      │  OutOfSync   │──────┘
             │      └──────┬───────┘
             │             │ manual/auto sync
             │             ▼
             │      ┌──────────────┐
             │      │  Syncing     │
             │      └──────┬───────┘
             │             │
             │        ┌────┴────┐
             │        │         │
             │    Success    Failure
             │        │         │
             └────────┘         ▼
                         ┌──────────────┐
                         │   Failed     │
                         └──────┬───────┘
                                │ retry / manual intervention
                                └─────► (back to OutOfSync)
```

### Application Health State Machine

```
    ┌──────────────┐
    │   Unknown    │ (No resources deployed)
    └──────┬───────┘
           │ resources created
           ▼
    ┌──────────────┐
    │ Progressing  │ (Pods creating, Rolling update)
    └──────┬───────┘
           │
      ┌────┴────┐
      │         │
   Success   Degraded
      │         │
      ▼         ▼
┌──────────┐  ┌──────────────┐
│ Healthy  │  │  Degraded    │ (Some pods failing)
└────┬─────┘  └──────┬───────┘
     │               │
     │               │ self-heal / manual fix
     │               └────────────────┐
     │                                ▼
     │                         ┌──────────────┐
     └────────────────────────►│ Progressing  │
                               └──────────────┘

Special states:
- Suspended: Resources exist but paused (e.g., CronJob with suspend: true)
- Missing: Resources expected but not found (deleted manually)
```

### Sync Operation Lifecycle

```
┌──────────────┐
│    Queued    │ (Sync requested, waiting for controller)
└──────┬───────┘
       │ controller picks up
       ▼
┌──────────────┐
│   Running    │ (Apply manifests to cluster)
└──────┬───────┘
       │
  ┌────┴────┐
  │         │
Success  Failure
  │         │
  ▼         ▼
┌──────────┐  ┌──────────────┐
│Succeeded │  │    Failed    │
└──────────┘  └──────┬───────┘
                     │
                     │ retry (exponential backoff)
                     └──► (back to Queued, up to retry limit)
```

---

## Validation Rules

### Application Validation

1. **repoURL must be valid Git URL** (HTTPS or SSH format)
2. **targetRevision must exist in repository** (branch, tag, or commit SHA)
3. **path must exist in repository** (directory with Kubernetes manifests)
4. **destination.server must be reachable** Kubernetes API server
5. **syncPolicy.retry.limit must be > 0** (at least one retry attempt)
6. **If syncPolicy.automated is set, prune and selfHeal must be boolean**

### Sync Operation Validation

1. **Git repository must be accessible** (credentials valid, network reachable)
2. **Manifests must be valid YAML** (parseable, no syntax errors)
3. **Kubernetes resources must pass API validation** (schema validation, required fields)
4. **Target namespace must exist or CreateNamespace=true** (if resources are namespaced)
5. **ArgoCD ServiceAccount must have RBAC permissions** (for target resources and namespace)

---

## Data Flow

### Continuous Sync Workflow

```
1. Repository Polling (every 3 minutes):
   ┌─────────────────────────────────────────────────────────────────┐
   │ argocd-application-controller                                    │
   │  ├─► Poll GitHub repository (GET /repos/cbenitez/chocolandia_kube)│
   │  ├─► Compare HEAD SHA with last synced revision                 │
   │  └─► If different: Set Application status to OutOfSync          │
   └─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ (if auto-sync enabled)
   ┌─────────────────────────────────────────────────────────────────┐
   │ Sync Operation Initiated                                         │
   │  ├─► argocd-repo-server: Clone repository, checkout revision    │
   │  ├─► Parse Kubernetes manifests from target path                │
   │  ├─► Generate resource list with desired state                  │
   │  └─► argocd-application-controller: Apply manifests to cluster  │
   └─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ Health Assessment (continuous)                                   │
   │  ├─► Query Kubernetes API for resource status                   │
   │  ├─► Evaluate health checks (readiness probes, custom health)   │
   │  ├─► Update Application health status (Healthy/Degraded/etc)    │
   │  └─► If Degraded: Log error details for troubleshooting         │
   └─────────────────────────────────────────────────────────────────┘
```

### Self-Heal Workflow

```
1. Drift Detection:
   argocd-application-controller compares Git state vs Cluster state
   │
   ▼ (if difference detected)
   ┌─────────────────────────────────────────────────────────────────┐
   │ Set Application status to OutOfSync                              │
   │  - Identify drifted resources (manual kubectl edit, etc)         │
   │  - Log drift details in Application status                       │
   └─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ (if selfHeal: true)
   ┌─────────────────────────────────────────────────────────────────┐
   │ Auto-Sync to Git State                                           │
   │  - Re-apply manifests from Git (overwrite cluster changes)       │
   │  - Delete resources not in Git (if prune: true)                  │
   │  - Update Application status to Synced                           │
   └─────────────────────────────────────────────────────────────────┘
```

---

## Summary

**Total Entities**: 10 core entities
- 3 ArgoCD CRDs (Application, Project, Sync Operation)
- 4 Infrastructure components (Server, Repo Server, Controller, Redis)
- 3 Integration entities (IngressRoute, Certificate, Access Application/Policy)

**Key Relationships**:
- Application → Git Repository (1:1, required)
- Application → Kubernetes Resources (1:many, managed lifecycle)
- Application → Sync Operations (1:many, historical)
- ArgoCD Components → ServiceMonitor → Prometheus (observability chain)

**State Machines**:
- Sync State: Unknown → OutOfSync → Syncing → Synced (loop)
- Health State: Unknown → Progressing → Healthy/Degraded (loop)
- Operation State: Queued → Running → Succeeded/Failed

This data model enables understanding of ArgoCD's declarative GitOps architecture and prepares for implementation planning (tasks generation).
