# Research: BeerSystem Cluster Deployment

**Feature**: 012-beersystem-deployment
**Date**: 2025-11-15
**Purpose**: Document technical research and decisions for deploying beersystem application to K3s cluster

## Research Questions & Findings

### 1. PostgreSQL Database Provisioning Strategy

**Question**: How to create beersystem_stage database and user with DDL privileges in the existing PostgreSQL cluster from feature 011?

**Decision**: Use PostgreSQL provider for OpenTofu to create database and user programmatically

**Rationale**:
- PostgreSQL cluster from feature 011 already exists and is accessible
- OpenTofu PostgreSQL provider can connect to existing cluster and execute DDL statements
- Declarative approach aligns with Constitution Principle I (Infrastructure as Code)
- State management ensures idempotent operations (won't recreate if already exists)
- Credentials can be managed via OpenTofu variables/outputs for consumption by application

**Alternatives Considered**:
1. **Manual SQL scripts** - Rejected: Not version controlled, not idempotent, violates IaC principle
2. **Kubernetes Job with psql** - Rejected: More complex, requires managing container image with psql client, less declarative
3. **Helm chart with init container** - Rejected: Mixes application deployment with database provisioning, couples unrelated concerns

**Implementation Details**:
- OpenTofu module: `terraform/modules/postgresql-database/`
- Provider: `cyrilgdn/postgresql` (community PostgreSQL provider for Terraform/OpenTofu)
- Resources needed:
  - `postgresql_database` for beersystem_stage
  - `postgresql_role` for database user with DDL privileges (CREATE, ALTER, DROP)
  - `postgresql_grant` to assign privileges
- Connection to PostgreSQL cluster: via service endpoint from feature 011 (likely `postgres-rw.postgres.svc.cluster.local`)

**References**:
- PostgreSQL Terraform Provider: https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs
- Feature 011 spec for PostgreSQL cluster details

---

### 2. Container Image Registry Strategy

**Question**: Where should the beersystem Docker image be stored and how should it be pulled by Kubernetes?

**Decision**: Build and push to Docker Hub public registry, pull from Kubernetes using imagePullPolicy: Always for staging environment

**Rationale**:
- Simplest approach for homelab staging environment
- Docker Hub is free for public images
- No need to manage private registry infrastructure (Harbor, local registry)
- Image versioning via tags (e.g., `cbenitez/beersystem:v1.0.0`, `cbenitez/beersystem:latest`)
- `imagePullPolicy: Always` ensures latest image is pulled on deployment (appropriate for staging)

**Alternatives Considered**:
1. **Private Harbor registry in cluster** - Rejected: Overkill for single application, adds complexity and resource usage
2. **Local registry on Raspberry Pi** - Rejected: Single point of failure, no redundancy for learning environment
3. **GitHub Container Registry (GHCR)** - Viable alternative: If beersystem repo is on GitHub, GHCR could be used. Deferred decision: can switch later if needed.

**Implementation Details**:
- Build command: `docker build -t cbenitez/beersystem:latest /Users/cbenitez/beersystem`
- Tag versioning: `docker tag cbenitez/beersystem:latest cbenitez/beersystem:v1.0.0`
- Push command: `docker push cbenitez/beersystem:latest && docker push cbenitez/beersystem:v1.0.0`
- Kubernetes deployment spec: `image: cbenitez/beersystem:latest` with `imagePullPolicy: Always`

**Security Note**: For production, would use private registry with image scanning and signed images. For staging/learning, public registry acceptable.

---

### 3. Database Connection Configuration for Application

**Question**: How should the beersystem application receive database connection credentials securely?

**Decision**: Kubernetes Secret with connection string components, injected as environment variables into application pods

**Rationale**:
- Kubernetes Secrets are encrypted at rest in etcd (with encryption provider enabled in K3s)
- Environment variable injection is standard pattern for 12-factor apps
- OpenTofu can output connection details (host, port, database, user, password) for Secret creation
- No hardcoded credentials in manifests or images
- Allows credential rotation without rebuilding images

**Alternatives Considered**:
1. **ConfigMap for connection details** - Rejected: ConfigMaps are not encrypted, unsuitable for passwords
2. **External Secrets Operator** - Rejected: Overkill for single application, adds operational complexity
3. **Sealed Secrets** - Viable enhancement: Can encrypt secrets in Git. Deferred: manual Secret creation acceptable for MVP, can enhance later.

**Implementation Details**:
- Secret manifest: `k8s/secret.yaml` (not committed to Git)
- Secret template: `k8s/secret.yaml.template` (committed to Git, placeholder values)
- Environment variables exposed to application:
  - `DATABASE_URL`: Full connection string (e.g., `postgresql://user:pass@host:5432/beersystem_stage`)
  - Or individual vars: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- OpenTofu outputs connection details to be used for Secret creation (manual step or via sealed-secrets)

**Security Best Practice**: Use least privilege database user (no SUPERUSER, only necessary DDL/DML grants)

---

### 4. Health Check Endpoints for Kubernetes Probes

**Question**: What endpoints should be used for liveness and readiness probes in Kubernetes?

**Decision**:
- **Liveness probe**: HTTP GET `/health` or `/` (check if application process is alive)
- **Readiness probe**: HTTP GET `/health/ready` or `/health` (check if application can serve traffic, including database connectivity)

**Rationale**:
- Liveness: Restart pod if application crashes or deadlocks
- Readiness: Remove pod from service load balancer if database unavailable or initialization incomplete
- Separate probes allow graceful handling of database connection issues (don't restart pod immediately)
- Standard practice for web applications in Kubernetes

**Alternatives Considered**:
1. **TCP socket probe** - Rejected: Only checks if port is open, not if application is healthy
2. **Exec probe with custom script** - Rejected: More complex, requires maintaining health check script in image
3. **gRPC probe** - N/A: BeerSystem is HTTP-based web application

**Implementation Details**:
- Deployment manifest liveness probe:
  ```yaml
  livenessProbe:
    httpGet:
      path: /health
      port: 8000
    initialDelaySeconds: 30
    periodSeconds: 10
    failureThreshold: 3
  ```
- Deployment manifest readiness probe:
  ```yaml
  readinessProbe:
    httpGet:
      path: /health/ready
      port: 8000
    initialDelaySeconds: 10
    periodSeconds: 5
    failureThreshold: 2
  ```

**Assumption**: BeerSystem application exposes `/health` endpoint. If not, will use `/` as fallback.

---

### 5. TLS Certificate Management with Cloudflare

**Question**: How to provision TLS certificate for beer.chocolandiadc.com subdomain given access is via Cloudflare Tunnel?

**Decision**: Use Cloudflare-managed TLS certificates (Cloudflare handles TLS termination at edge), internal communication via HTTP to beersystem service

**Rationale**:
- Cloudflare Tunnel (feature 004) already provides TLS termination at Cloudflare's edge
- Cloudflare automatically provisions and renews certificates for all tunneled domains
- HTTP-01 ACME challenge doesn't work with Cloudflare Tunnel (no direct port 80 access)
- DNS-01 ACME challenge is complex and unnecessary when Cloudflare already provides certs
- Simpler architecture: Cloudflare Edge (HTTPS) → Tunnel → Cluster (HTTP)
- End-to-end encryption via Cloudflare Tunnel's encrypted connection

**Alternatives Considered**:
1. **Cert-manager with DNS-01 challenge** - Rejected: Complex (requires Cloudflare API token for DNS validation), unnecessary when Cloudflare already provides certs
2. **Cert-manager with HTTP-01 challenge** - Rejected: Doesn't work with Cloudflare Tunnel (no direct HTTP access)
3. **Self-signed certificates** - Rejected: Browser warnings, not production-ready
4. **End-to-end TLS (Cloudflare → Cluster)** - Deferred: More complex, requires Cloudflare Origin CA certs. MVP uses Cloudflare TLS termination.

**Implementation Details**:
- No Certificate resource needed (Cloudflare manages certs)
- No cert-manager configuration for this service
- Cloudflare Tunnel configuration will include:
  ```yaml
  ingress:
    - hostname: beer.chocolandiadc.com
      service: http://beersystem-service.beersystem.svc.cluster.local:80
  ```
- Cloudflare Dashboard shows auto-provisioned Universal SSL certificate
- Internal service remains HTTP (no TLS overhead in cluster)

**Security Note**: While internal communication is HTTP, it's within the cluster network (isolated) and the Cloudflare Tunnel connection itself is encrypted. For production with sensitive data, consider Cloudflare Origin CA certificates for end-to-end TLS.

**Traffic Flow**:
- Client → HTTPS (Cloudflare TLS) → Cloudflare Edge
- Cloudflare Edge → Encrypted Tunnel → cloudflared pod in cluster
- cloudflared pod → HTTP → beersystem-service (ClusterIP)
- beersystem-service → HTTP → beersystem pods

---

### 6. ArgoCD Application Configuration Strategy

**Question**: How should ArgoCD Application resource be configured to sync beersystem manifests from the k8s/ directory?

**Decision**: Create ArgoCD Application manifest in chocolandia_kube repo, pointing to beersystem repo k8s/ directory, with auto-sync enabled

**Rationale**:
- ArgoCD Application is cluster-scoped infrastructure configuration, belongs in chocolandia_kube repo
- Auto-sync enables GitOps workflow (changes to beersystem k8s/ directory trigger automatic deployment)
- Self-healing enabled to correct drift if manual changes made to cluster
- Prune enabled to remove resources deleted from Git

**Alternatives Considered**:
1. **ArgoCD App-of-Apps pattern** - Deferred: Single application, no need for app-of-apps hierarchy
2. **Manual sync only (no auto-sync)** - Rejected: Violates GitOps principle, requires manual intervention
3. **ApplicationSet for multiple environments** - Deferred: Single staging environment for now, can add dev/prod later

**Implementation Details**:
- ArgoCD Application manifest: `terraform/environments/chocolandiadc-mvp/argocd-apps/beersystem.yaml`
  ```yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: beersystem
    namespace: argocd
  spec:
    project: default
    source:
      repoURL: https://github.com/cbenitez/beersystem  # Assuming GitHub repo
      targetRevision: main  # Or staging branch
      path: k8s
    destination:
      server: https://kubernetes.default.svc
      namespace: beersystem
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
      syncOptions:
        - CreateNamespace=true
  ```

**Repository Access**: If beersystem repo is private, need to configure ArgoCD repository credentials (SSH key or HTTPS token).

---

### 7. Resource Requests and Limits Sizing

**Question**: What CPU and memory requests/limits should be set for beersystem application pods?

**Decision**:
- **Requests**: CPU 100m, Memory 256Mi (guaranteed resources)
- **Limits**: CPU 500m, Memory 512Mi (maximum burst)

**Rationale**:
- Conservative sizing for staging environment (can tune based on actual usage)
- Requests ensure pod scheduling (Kubernetes reserves resources)
- Limits prevent resource exhaustion on shared cluster nodes
- Aligns with Constitution Principle V (resource limits mandatory)
- Typical sizing for small to medium web applications

**Alternatives Considered**:
1. **No limits** - Rejected: Violates constitution, can cause node resource exhaustion
2. **Very large limits (multi-core CPU, 2Gi+ memory)** - Rejected: Wasteful for homelab with limited resources
3. **Vertical Pod Autoscaler (VPA)** - Deferred: Advanced feature, not needed for MVP

**Implementation Details**:
- Deployment manifest resources:
  ```yaml
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  ```

**Tuning Strategy**: Monitor actual resource usage via Prometheus/Grafana (future enhancement), adjust based on observed patterns.

---

### 8. Namespace Strategy

**Question**: Should beersystem application use dedicated namespace or deploy to default namespace?

**Decision**: Create dedicated `beersystem` namespace

**Rationale**:
- Logical isolation from other applications
- Easier RBAC management (namespace-scoped roles)
- Cleaner resource organization (all beersystem resources in one namespace)
- Follows Kubernetes best practice (avoid default namespace for applications)
- Easier to delete/cleanup entire application (delete namespace)

**Alternatives Considered**:
1. **Default namespace** - Rejected: Poor practice, mixes resources, harder to manage
2. **Shared "applications" namespace** - Rejected: Reduces isolation, complicates RBAC

**Implementation Details**:
- Namespace manifest: `k8s/namespace.yaml`
  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: beersystem
    labels:
      app: beersystem
      environment: staging
  ```

**ArgoCD Integration**: ArgoCD Application spec includes `CreateNamespace=true` sync option, will create namespace automatically.

---

## Summary of Key Decisions

| Decision Area | Choice | Rationale |
|---------------|--------|-----------|
| Database Provisioning | OpenTofu PostgreSQL provider | Declarative, IaC-compliant, idempotent |
| Container Registry | Docker Hub public | Simple, no infrastructure overhead |
| Database Credentials | Kubernetes Secret + env vars | Secure, standard 12-factor pattern |
| Health Checks | HTTP /health endpoints | Standard, supports liveness/readiness |
| TLS Certificates | Cert-manager Certificate CRD | Automated, renewable, declarative |
| ArgoCD Sync | Auto-sync with self-heal | Full GitOps automation |
| Resource Sizing | 100m/256Mi requests, 500m/512Mi limits | Conservative, tunable |
| Namespace | Dedicated `beersystem` namespace | Isolation, best practice |

All decisions align with Constitution principles (IaC, GitOps, Container-First, Security Hardening, Documentation-First).

## Next Steps

Phase 1 will produce:
1. **data-model.md**: Database schema for beersystem_stage
2. **contracts/ingress.yaml**: Ingress route specification
3. **quickstart.md**: Step-by-step deployment runbook
