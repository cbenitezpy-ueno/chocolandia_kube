# Research: Nexus Repository Manager

**Feature**: 016-nexus-repository
**Date**: 2025-11-24

## Technology Decisions

### 1. Nexus Repository OSS vs Alternatives

**Decision**: Sonatype Nexus Repository OSS 3.x

**Rationale**:
- Supports all 5 required formats in single deployment (Docker, Helm, NPM, Maven, APT)
- Free and open-source (OSS version)
- Mature, well-documented, production-ready
- Built-in web UI for administration
- Prometheus metrics endpoint available
- Active community and regular updates

**Alternatives Considered**:

| Option | Pros | Cons | Rejected Because |
|--------|------|------|------------------|
| JFrog Artifactory OSS | Industry standard | Limited formats in OSS, complex setup | APT not in free tier |
| Harbor | Excellent for Docker/Helm | No NPM/Maven/APT support | Missing 3 of 5 required formats |
| Docker Registry + separate repos | Simple Docker registry | Would need 5 separate systems | Too complex to manage |
| Verdaccio (NPM) + others | Specialized per format | Multiple deployments | Increases operational burden |

### 2. Container Image Selection

**Decision**: `sonatype/nexus3:latest` (official image)

**Rationale**:
- Official Sonatype image with security updates
- Multi-architecture support (amd64, arm64)
- Well-documented configuration options
- ~800MB image size (acceptable for homelab)

**Configuration Requirements**:
- Java heap: 1200MB minimum recommended
- Data volume: /nexus-data (persistent storage)
- Ports: 8081 (web UI/API), additional ports for repository-specific connectors

### 3. Repository Configuration Strategy

**Decision**: Hosted repositories only (Phase 1), Proxy repositories optional (Phase 2)

**Rationale**:
- Hosted repositories provide immediate value for private artifacts
- Proxy repositories (caching Docker Hub, npmjs, Maven Central) add complexity
- Can be enabled post-deployment via Nexus UI without infrastructure changes

**Repository Structure**:

| Format | Repository Name | Type | Purpose |
|--------|----------------|------|---------|
| Docker | docker-hosted | hosted | Private Docker images |
| Helm | helm-hosted | hosted | Private Helm charts |
| NPM | npm-hosted | hosted | Private NPM packages |
| Maven | maven-releases | hosted | Release artifacts |
| Maven | maven-snapshots | hosted | Snapshot artifacts |
| APT | apt-hosted | hosted | Debian packages |

### 4. Authentication Strategy

**Decision**: Nexus built-in authentication with admin-configured users

**Rationale**:
- Nexus has built-in user/role management
- Simpler than integrating external auth (LDAP) for homelab
- Initial admin password set via environment variable or first-login
- Per-repository permissions configurable via UI

**Security Model**:
- Anonymous read: Configurable per repository (default: disabled)
- Authenticated write: Required for all push operations
- Admin access: Web UI for repository management

### 5. Ingress and TLS Strategy

**Decision**: Traefik IngressRoute with cert-manager certificates

**Rationale**:
- Consistent with existing cluster services (localstack, registry, etc.)
- HTTPS required for Docker registry API
- Wildcard or per-service certificates via Let's Encrypt

**URL Structure**:
- Web UI: https://nexus.chocolandiadc.local
- Docker API: https://nexus.chocolandiadc.local (same host, different port internally)

**Note**: Docker registry in Nexus requires special handling:
- Docker client expects registry at root path
- Nexus serves Docker API at `/repository/docker-hosted/`
- Solution: Traefik path rewrite or dedicated Docker connector port

### 6. Prometheus Metrics Integration

**Decision**: Enable Nexus metrics endpoint + ServiceMonitor for Prometheus

**Rationale**:
- Nexus exposes metrics at `/service/metrics/prometheus`
- Requires anonymous access to metrics endpoint (or basic auth)
- ServiceMonitor CRD for automatic Prometheus discovery

**Key Metrics**:
- `nexus_repository_*` - Repository statistics
- `jvm_*` - JVM metrics (heap, GC, threads)
- `http_*` - Request latency and counts

### 7. Storage Sizing

**Decision**: 50Gi PersistentVolumeClaim

**Rationale**:
- Current Docker Registry uses 30Gi
- Nexus stores additional formats (Helm, NPM, Maven, APT)
- 50Gi provides growth headroom
- local-path-provisioner for K3s compatibility

### 8. Migration Strategy

**Decision**: Clean deployment, rebuild images as needed

**Rationale**:
- Per spec assumptions: "existing Docker Registry has minimal critical images"
- Nexus uses different storage format than Docker Registry v2
- Simpler to push images to new Nexus than attempt data migration
- Old registry.tf removed after Nexus validated

**Migration Steps**:
1. Deploy Nexus alongside existing Registry
2. Validate Nexus functionality
3. Re-push critical images to Nexus
4. Update cluster imagePullSecrets
5. Remove old Registry module

## Best Practices Applied

### Kubernetes Deployment

- Single replica with PVC (no StatefulSet needed for single instance)
- Resource limits: 2Gi memory, 1 CPU (Java application)
- Liveness/readiness probes on /service/rest/v1/status
- Security context: non-root user (UID 200 - nexus user)

### OpenTofu Module

- Variables for all configurable values (hostname, storage, resources)
- Outputs for service endpoints and credentials
- Depends_on for proper resource ordering
- Consistent labeling scheme with existing modules

### Observability

- Prometheus ServiceMonitor for metrics scraping
- Grafana dashboard panel for Nexus health
- Log output to stdout for cluster logging

## Unresolved Items

None - all technical decisions made. Ready for Phase 1 design artifacts.
