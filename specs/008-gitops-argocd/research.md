# Phase 0: Research - ArgoCD GitOps Implementation

**Feature**: 008-gitops-argocd
**Date**: 2025-11-12
**Status**: Complete

## Research Overview

This document captures research findings and architectural decisions for implementing ArgoCD-based GitOps continuous deployment in the chocolandia_kube K3s cluster. Focus areas: pull-based GitOps architecture, private repository authentication, ArgoCD Helm chart configuration, and integration with existing infrastructure (Traefik, cert-manager, Cloudflare Access).

---

## 1. ArgoCD Architecture for K3s Clusters

### Research Question
How should ArgoCD be architected for a homelab K3s cluster with 2 nodes (master1 + nodo1)?

### Decision: Single-Replica Deployment with Embedded Redis

**Rationale**:
- **Homelab scale**: K3s cluster has 2 nodes; ArgoCD HA (3+ replicas) is over-engineered
- **Learning focus**: GitOps workflow understanding, not ArgoCD high availability
- **Resource efficiency**: Single replicas reduce CPU/memory footprint on small cluster
- **Acceptable risk**: ArgoCD downtime affects sync operations only, not running workloads
- **State persistence**: ArgoCD application state stored in etcd (survives pod restarts)

**Configuration**:
- **argocd-server**: 1 replica (web UI + gRPC API)
- **argocd-repo-server**: 1 replica (Git repository operations)
- **argocd-application-controller**: 1 replica (sync controller, health assessment)
- **argocd-redis**: 1 replica embedded (caching layer)
- **argocd-dex**: 0 replicas (not needed for GitHub OAuth via Cloudflare Access)

**Alternatives Considered**:
- **HA ArgoCD** (3 replicas + Redis HA): Rejected - adds complexity without proportional learning value
- **ArgoCD Lite** (single binary): Rejected - Helm chart provides better maintainability and upgrade path
- **Flux CD**: Rejected - ArgoCD chosen for better UI/UX and industry adoption

---

## 2. Pull-Based GitOps vs Push-Based CI/CD

### Research Question
Should ArgoCD use pull-based (polling) or push-based (webhooks) architecture for GitHub repository synchronization?

### Decision: Pull-Based Architecture (Repository Polling)

**Rationale**:
- **Cloudflare tunnel constraint**: Cluster only accessible via Cloudflare Zero Trust tunnel (no direct inbound connectivity)
- **No webhook support**: GitHub cannot send webhook payloads to cluster (no public IP, no port forwarding)
- **ArgoCD default**: Pull-based polling is ArgoCD's native model (webhooks are optional enhancement)
- **Acceptable latency**: 3-minute polling interval provides reasonable sync latency for infrastructure changes
- **Security benefit**: No inbound firewall rules required (ArgoCD initiates all connections outbound to GitHub)

**Configuration**:
- **Polling interval**: 3 minutes (default: `timeout.reconciliation`)
- **Sync mode**: Automatic sync after change detection (enabled after manual validation)
- **Repository access**: HTTPS with GitHub Personal Access Token (stored as Kubernetes Secret)

**Alternatives Considered**:
- **GitHub Actions push**: Rejected - requires cluster API accessibility, violates pull-based GitOps principle
- **Webhook relay service**: Rejected - adds external dependency and complexity
- **Shorter polling interval (1 minute)**: Rejected - increases GitHub API rate limit usage without significant benefit

---

## 3. GitHub Private Repository Authentication

### Research Question
How should ArgoCD authenticate to the private chocolandia_kube GitHub repository?

### Decision: GitHub Personal Access Token (PAT) with Repository Scope

**Rationale**:
- **User decision**: Token already exists in `~/.env` and MCP GitHub configuration
- **Simplicity**: PAT stored as Kubernetes Secret, referenced by ArgoCD Application manifest
- **Scope control**: `repo` scope provides full repository access (read, write, webhooks if future)
- **Token rotation**: Can be rotated without ArgoCD redeployment (update Secret, restart ArgoCD pods)
- **Security**: Token never committed to Git, managed via OpenTofu `sensitive` variables

**Configuration**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: chocolandia-kube-repo
  namespace: argocd
type: Opaque
stringData:
  type: git
  url: https://github.com/cbenitez/chocolandia_kube
  password: <GITHUB_PAT>  # From terraform.tfvars (var.github_token)
  username: cbenitez       # GitHub username
```

**ArgoCD Application References**:
```yaml
spec:
  source:
    repoURL: https://github.com/cbenitez/chocolandia_kube
    targetRevision: main
    path: kubernetes/argocd/applications
```

**Alternatives Considered**:
- **SSH deploy key**: Rejected - requires SSH key generation, less flexible than PAT
- **GitHub App**: Rejected - over-engineered for single-user homelab
- **OAuth flow**: Rejected - requires external OAuth server, adds complexity

---

## 4. ArgoCD Application Manifest Structure

### Research Question
What should the ArgoCD Application manifest structure look like for chocolandia_kube infrastructure repository?

### Decision: Single Application for Infrastructure with Manual Sync Initially

**Application Manifest**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: chocolandia-kube
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # Cascade delete on Application removal
spec:
  project: default  # ArgoCD Project for RBAC scoping

  source:
    repoURL: https://github.com/cbenitez/chocolandia_kube
    targetRevision: main  # Branch to sync
    path: kubernetes/argocd/applications  # Path in repo with Kubernetes manifests

  destination:
    server: https://kubernetes.default.svc  # In-cluster API server
    namespace: argocd  # Default namespace (Applications can override)

  syncPolicy:
    automated: null  # Disable auto-sync initially (enable after manual validation)
    syncOptions:
      - CreateNamespace=true  # Auto-create namespaces if missing
      - PruneLast=true        # Delete resources last during sync
    retry:
      limit: 5  # Retry failed syncs up to 5 times
      backoff:
        duration: 5s    # Initial retry delay
        factor: 2       # Exponential backoff factor
        maxDuration: 3m # Maximum retry delay

  # Ignore differences in specific fields (prevent drift detection noise)
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore HPA-managed replica count changes
```

**Rationale**:
- **Manual sync first**: Conservative approach, validate first sync before enabling automation
- **Cascade delete**: Ensures Application removal cleans up created resources
- **Namespace creation**: Simplifies Application deployment (no pre-created namespace requirement)
- **Retry policy**: Handles transient failures (network issues, API server throttling)
- **Ignore differences**: Prevents false drift detection (e.g., HPA changing replicas)

**Alternatives Considered**:
- **Auto-sync from start**: Rejected - too risky without validation
- **Multiple Applications**: Rejected - single Application for infrastructure simplifies management

---

## 5. ArgoCD Helm Chart Configuration

### Research Question
What Helm chart values are required for ArgoCD deployment in K3s with Traefik, cert-manager, and Cloudflare Access?

### Decision: Minimal Helm Values with External Ingress Management

**Helm Chart Values** (`terraform/modules/argocd/main.tf`):
```hcl
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.0"  # ArgoCD v2.9.x
  namespace  = "argocd"

  values = [
    yamlencode({
      # Global configuration
      global = {
        domain = var.argocd_domain  # argocd.chocolandiadc.com
      }

      # Server component (web UI + gRPC)
      server = {
        replicas = 1
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
        metrics = {
          enabled = true  # Expose Prometheus metrics
          serviceMonitor = {
            enabled = var.enable_prometheus_metrics
          }
        }
        ingress = {
          enabled = false  # Managed by Traefik IngressRoute (separate resource)
        }
      }

      # Repository server (Git operations)
      repoServer = {
        replicas = 1
        resources = {
          limits = {
            cpu    = "200m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "64Mi"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = var.enable_prometheus_metrics
          }
        }
      }

      # Application controller (sync operations)
      controller = {
        replicas = 1
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = var.enable_prometheus_metrics
          }
        }
      }

      # Redis (caching layer)
      redis = {
        enabled = true  # Embedded Redis (not HA)
        resources = {
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      }

      # Dex (OIDC provider - not needed)
      dex = {
        enabled = false  # Cloudflare Access handles authentication
      }

      # Configurations
      configs = {
        cm = {
          # Repository polling interval
          timeout.reconciliation = "180s"  # 3 minutes

          # Custom health checks for CRDs
          resource.customizations = {
            "traefik.containo.us/IngressRoute" = {
              health.lua = <<-LUA
                hs = {}
                hs.status = "Healthy"
                return hs
              LUA
            }
            "cert-manager.io/Certificate" = {
              health.lua = <<-LUA
                hs = {}
                if obj.status ~= nil then
                  if obj.status.conditions ~= nil then
                    for i, condition in ipairs(obj.status.conditions) do
                      if condition.type == "Ready" and condition.status == "False" then
                        hs.status = "Degraded"
                        hs.message = condition.message
                        return hs
                      end
                      if condition.type == "Ready" and condition.status == "True" then
                        hs.status = "Healthy"
                        hs.message = condition.message
                        return hs
                      end
                    end
                  end
                end
                hs.status = "Progressing"
                hs.message = "Waiting for certificate"
                return hs
              LUA
            }
          }
        }
      }
    })
  ]
}
```

**Rationale**:
- **Single replicas**: Homelab scale, focus on GitOps workflow learning
- **Resource limits**: Prevent resource exhaustion on 2-node cluster
- **Prometheus metrics**: Observability for sync operations, application health
- **Embedded Redis**: Simplifies deployment, HA not required
- **Dex disabled**: Cloudflare Access handles authentication (no OIDC provider needed)
- **Custom health checks**: ArgoCD understands Traefik IngressRoute and cert-manager Certificate CRDs
- **180s polling**: 3-minute repository sync interval (balance between latency and API rate limits)

**Alternatives Considered**:
- **ArgoCD Ingress enabled**: Rejected - Traefik IngressRoute provides better TLS and Cloudflare Access integration
- **Dex enabled**: Rejected - redundant with Cloudflare Access OAuth
- **60s polling**: Rejected - increases GitHub API rate limit usage without significant benefit

---

## 6. Auto-Sync and Self-Heal Configuration

### Research Question
When and how should ArgoCD auto-sync and self-heal be enabled?

### Decision: Manual Sync Initially, Enable Auto-Sync After Validation

**Initial Configuration** (Manual Sync):
```yaml
syncPolicy:
  automated: null  # Disable auto-sync
  syncOptions:
    - CreateNamespace=true
    - PruneLast=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

**Post-Validation Configuration** (Auto-Sync Enabled):
```yaml
syncPolicy:
  automated:
    prune: true      # Auto-delete resources removed from Git
    selfHeal: true   # Auto-revert manual changes (drift correction)
    allowEmpty: false  # Prevent accidental deletion of all resources
  syncOptions:
    - CreateNamespace=true
    - PruneLast=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

**Enablement Procedure**:
1. Deploy ArgoCD with manual sync
2. Manually trigger first sync via ArgoCD UI or CLI: `argocd app sync chocolandia-kube`
3. Verify sync completes successfully (Application status: Synced, Healthy)
4. Verify cluster resources match Git state
5. Update Application manifest to enable auto-sync
6. Apply updated manifest: `kubectl apply -f kubernetes/argocd/applications/chocolandia-kube.yaml`
7. Verify auto-sync behavior: Make test commit to Git, wait 3 minutes, verify auto-sync

**Rationale**:
- **Manual validation first**: Conservative approach prevents immediate automation failures
- **Self-heal enabled**: Enforces Git as source of truth, prevents manual drift
- **Prune enabled**: Auto-deletes resources removed from Git (prevents orphaned resources)
- **allowEmpty: false**: Safety guard against accidental repository emptying

**Alternatives Considered**:
- **Auto-sync from start**: Rejected - too risky without manual validation
- **Self-heal disabled**: Rejected - violates GitOps principle (Git as source of truth)

---

## 7. Integration with Existing Infrastructure

### Research Question
How should ArgoCD integrate with existing chocolandia_kube infrastructure (Traefik, cert-manager, Cloudflare Access)?

### Decision: Leverage Existing Patterns from Feature 007 (Headlamp)

**Traefik IngressRoute** (`terraform/modules/argocd/ingress.tf`):
```hcl
resource "kubernetes_manifest" "argocd_ingressroute" {
  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "argocd-server"
      namespace = "argocd"
    }
    spec = {
      entryPoints = ["websecure"]  # HTTPS only
      routes = [
        {
          match = "Host(`${var.argocd_domain}`)"  # argocd.chocolandiadc.com
          kind  = "Rule"
          services = [
            {
              name = "argocd-server"
              port = 443  # ArgoCD server HTTPS port
            }
          ]
        }
      ]
      tls = {
        secretName = "argocd-tls"  # cert-manager Certificate
      }
    }
  }
}
```

**cert-manager Certificate** (`terraform/modules/argocd/ingress.tf`):
```hcl
resource "kubernetes_manifest" "argocd_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "argocd-tls"
      namespace = "argocd"
    }
    spec = {
      secretName = "argocd-tls"
      issuerRef = {
        name = var.cluster_issuer  # letsencrypt-production
        kind = "ClusterIssuer"
      }
      dnsNames = [
        var.argocd_domain  # argocd.chocolandiadc.com
      ]
      duration    = var.certificate_duration      # 2160h (90 days)
      renewBefore = var.certificate_renew_before  # 720h (30 days)
    }
  }
}
```

**Cloudflare Access Application** (`terraform/modules/argocd/cloudflare-access.tf`):
```hcl
resource "cloudflare_access_application" "argocd" {
  account_id = var.cloudflare_account_id
  name       = "ArgoCD GitOps Dashboard"
  domain     = var.argocd_domain  # argocd.chocolandiadc.com
  type       = "self_hosted"

  session_duration = var.access_session_duration  # 24h
  auto_redirect_to_identity = var.access_auto_redirect  # true
  app_launcher_visible      = var.access_app_launcher_visible  # true
}

resource "cloudflare_access_policy" "argocd_auth" {
  application_id = cloudflare_access_application.argocd.id
  account_id     = var.cloudflare_account_id
  name           = "ArgoCD Authorized Users"
  precedence     = 1
  decision       = "allow"

  include {
    email = var.authorized_emails  # [cbenitez@gmail.com, ...]
  }

  require {
    login_method = [var.google_oauth_idp_id]  # Google OAuth identity provider
  }
}
```

**Rationale**:
- **Reuse existing patterns**: ArgoCD ingress/TLS follows same pattern as Headlamp (Feature 007)
- **Cloudflare Access**: Two-layer authentication (Cloudflare identity + ArgoCD RBAC)
- **Automatic TLS**: cert-manager handles certificate lifecycle (issuance, renewal)
- **HTTPS only**: Traefik `websecure` entryPoint enforces TLS
- **DNS-01 challenge**: Cloudflare DNS provider for wildcard certificate capability

**Alternatives Considered**:
- **ArgoCD built-in Ingress**: Rejected - Traefik IngressRoute provides better integration
- **Let's Encrypt HTTP-01**: Rejected - DNS-01 already configured, more flexible
- **No Cloudflare Access**: Rejected - violates security principle (public ArgoCD UI)

---

## 8. ArgoCD Application Template for Web Projects

### Research Question
How should the reusable ArgoCD Application template be structured for future web development projects?

### Decision: Parameterized YAML Template with 4 Required Variables

**Template** (`kubernetes/argocd/applications/web-app-template.yaml`):
```yaml
# ArgoCD Application Template for Web Projects
#
# Usage:
# 1. Copy this file: cp web-app-template.yaml my-app.yaml
# 2. Replace placeholders:
#    - APP_NAME: Application name (e.g., "portfolio-app")
#    - REPO_URL: GitHub repository URL (e.g., "https://github.com/cbenitez/portfolio")
#    - TARGET_PATH: Path in repo with K8s manifests (e.g., "kubernetes/")
#    - NAMESPACE: Target namespace (e.g., "web-apps")
# 3. Apply: kubectl apply -f my-app.yaml
# 4. Verify sync: argocd app get my-app

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: APP_NAME  # REPLACE: Your application name
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: REPO_URL         # REPLACE: Your GitHub repository URL
    targetRevision: main      # Change if different branch
    path: TARGET_PATH         # REPLACE: Path to Kubernetes manifests in repo

  destination:
    server: https://kubernetes.default.svc
    namespace: NAMESPACE      # REPLACE: Target namespace for deployment

  syncPolicy:
    automated: null           # Start with manual sync, enable auto-sync after validation
    syncOptions:
      - CreateNamespace=true  # Auto-create namespace if missing
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore HPA-managed replica changes
```

**Documentation** (`kubernetes/argocd/applications/README.md`):
```markdown
# ArgoCD Application Templates

## Web App Template

Deploy web applications to the K3s cluster using GitOps.

### Prerequisites
- Web project repository with Kubernetes manifests (Deployment, Service, Ingress)
- Manifests in a dedicated directory (e.g., `kubernetes/`, `k8s/`, `.k8s/`)
- GitHub repository accessible by ArgoCD (public or private with credentials)

### Quick Start

1. Copy template:
   ```bash
   cp web-app-template.yaml my-app.yaml
   ```

2. Replace placeholders (4 required):
   - `APP_NAME`: Your application name (e.g., "portfolio-app")
   - `REPO_URL`: Your GitHub repository URL
   - `TARGET_PATH`: Path to Kubernetes manifests in repo
   - `NAMESPACE`: Target namespace (will be created if missing)

3. Apply Application:
   ```bash
   kubectl apply -f my-app.yaml
   ```

4. Verify sync status:
   ```bash
   argocd app get my-app
   argocd app sync my-app  # Manual sync
   ```

5. Enable auto-sync (after validation):
   - Edit `my-app.yaml`
   - Set `syncPolicy.automated.prune: true` and `syncPolicy.automated.selfHeal: true`
   - Apply changes: `kubectl apply -f my-app.yaml`

### Example: Portfolio Web App

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portfolio-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/cbenitez/portfolio
    targetRevision: main
    path: kubernetes/
  destination:
    server: https://kubernetes.default.svc
    namespace: web-apps
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
```

**Rationale**:
- **4 required parameters**: Minimal configuration (app name, repo URL, path, namespace)
- **Sensible defaults**: Manual sync, namespace creation, retry policy pre-configured
- **Copy-paste workflow**: Template designed for quick adaptation (< 10 minutes to running app)
- **Documentation included**: README with prerequisites, quick start, and example

**Alternatives Considered**:
- **ArgoCD ApplicationSet**: Rejected - over-engineered for small number of web apps
- **Helm-based template**: Rejected - YAML template simpler for learning
- **More parameters**: Rejected - keeps template simple, advanced users can customize

---

## Research Summary

### Key Decisions Made

1. **Architecture**: Single-replica ArgoCD with embedded Redis (homelab scale)
2. **GitOps Model**: Pull-based polling (3-minute interval) due to Cloudflare tunnel constraint
3. **Authentication**: GitHub PAT stored as Kubernetes Secret
4. **Sync Policy**: Manual sync initially, enable auto-sync after validation
5. **Integration**: Leverage existing Traefik, cert-manager, and Cloudflare Access patterns
6. **Web App Template**: Parameterized YAML with 4 required variables

### Next Steps

- **Phase 1**: Create data-model.md (ArgoCD entities, relationships, state transitions)
- **Phase 1**: Generate quickstart.md (deployment procedure, validation steps)
- **Phase 1**: Update agent context with new technologies (ArgoCD, GitOps)
- **Phase 2**: Generate tasks.md from this plan (/speckit.tasks command)

### Unresolved Questions

None - all technical unknowns resolved through research.
