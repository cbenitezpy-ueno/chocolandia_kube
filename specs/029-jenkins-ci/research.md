# Research: Jenkins CI Deployment

**Feature**: 029-jenkins-ci
**Date**: 2026-01-07

## 1. Jenkins Helm Chart Selection

**Decision**: Use official Jenkins Helm chart from `https://charts.jenkins.io`

**Rationale**:
- Official chart maintained by Jenkins project
- Supports Configuration as Code (JCasC) for declarative plugin/config management
- Built-in support for Kubernetes pod templates
- Active community and regular updates
- Well-documented and widely used in production

**Alternatives Considered**:
- Bitnami Jenkins chart: Less flexible JCasC support, additional abstraction layer
- Raw Kubernetes manifests: More maintenance overhead, no JCasC out of box
- Docker-compose: Not suitable for K3s cluster deployment

## 2. Plugin Configuration Strategy

**Decision**: Pre-install plugins via Helm values using JCasC (Jenkins Configuration as Code)

**Required Plugins**:

| Plugin | Purpose | Version Strategy |
|--------|---------|------------------|
| `kubernetes` | Pod-based builds, Kubernetes integration | Latest stable |
| `docker-workflow` | Docker build/push in pipelines | Latest stable |
| `docker-commons` | Docker credentials management | Latest stable |
| `pipeline-stage-view` | Pipeline visualization | Latest stable |
| `workflow-aggregator` | Pipeline support | Latest stable |
| `git` | Git SCM integration | Latest stable |
| `maven-plugin` | Maven builds | Latest stable |
| `nodejs` | Node.js tool installations | Latest stable |
| `pyenv-pipeline` | Python virtual environments | Latest stable |
| `golang` | Go tool installations | Latest stable |
| `prometheus` | Prometheus metrics endpoint | Latest stable |
| `configuration-as-code` | JCasC support | Latest stable |
| `credentials-binding` | Secrets in pipelines | Latest stable |

**Rationale**:
- JCasC ensures reproducible configuration
- Plugins installed at container startup, no manual intervention
- Version pinning optional (latest stable recommended for homelab)

## 3. Docker Build Strategy in Kubernetes

**Decision**: Use Docker-in-Docker (DinD) sidecar pattern with privileged container

**Rationale**:
- Jenkins controller pod will include DinD sidecar
- Allows building Docker images inside Kubernetes pods
- Required for `docker build` and `docker push` commands in pipelines

**Alternative Considered**:
- Kaniko (rootless builds): More secure but complex setup, limited compatibility
- Buildah: Requires specific configuration, less mature Jenkins integration
- Host Docker socket mount: Security risk, not recommended

**Implementation**:
```yaml
# DinD sidecar in Jenkins controller pod
- name: dind
  image: docker:24-dind
  securityContext:
    privileged: true
  env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
  volumeMounts:
    - name: docker-graph-storage
      mountPath: /var/lib/docker
```

## 4. Nexus Docker Registry Authentication

**Decision**: Store Nexus credentials as Kubernetes Secret, inject via JCasC

**Implementation**:
1. Create K8s Secret with Nexus username/password
2. Reference in JCasC credentials configuration
3. Use credential ID in Jenkinsfile for `docker login`

**Credential Configuration** (JCasC):
```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: GLOBAL
              id: nexus-docker
              username: ${NEXUS_USERNAME}
              password: ${NEXUS_PASSWORD}
              description: "Nexus Docker Registry"
```

## 5. Tool Installations (Java, Node, Python, Go)

**Decision**: Use Jenkins tool installers configured via JCasC

**Tool Configuration**:

| Tool | Installation Method | Versions |
|------|---------------------|----------|
| JDK | Adoptium (Temurin) installer | 17, 21 |
| Maven | Apache Maven installer | 3.9.x |
| Node.js | NodeJS plugin installer | 18 LTS, 20 LTS |
| Python | pyenv-pipeline (in Jenkinsfile) | 3.11, 3.12 |
| Go | Go plugin installer | 1.21, 1.22 |

**Rationale**:
- Managed installations ensure consistency
- Multiple versions available for different projects
- Automatic download and caching

## 6. Persistent Storage

**Decision**: 20Gi PVC via local-path-provisioner

**Rationale**:
- Jenkins home contains: job configs, build history, plugins, workspace cache
- 20Gi sufficient for homelab scale (5-10 projects)
- local-path-provisioner already deployed in cluster

**Backup Strategy** (future enhancement):
- Velero backup of PVC
- JCasC configuration in Git (recoverable)

## 7. Ingress and TLS Configuration

**Decision**: Follow existing patterns (nexus, argocd) with Traefik IngressRoute

**URLs**:
- LAN: `https://jenkins.chocolandiadc.local` (local-ca certificate)
- Public: `https://jenkins.chocolandiadc.com` (Cloudflare Zero Trust)

**Implementation**:
- cert-manager Certificate with `local-ca` ClusterIssuer
- Traefik IngressRoute for HTTPS routing
- Cloudflare tunnel ingress rule for public access

## 8. Monitoring Integration

**Decision**: Prometheus metrics plugin + ServiceMonitor + ntfy notifications

**Metrics Endpoint**: `/prometheus` on Jenkins controller
**ServiceMonitor**: Scrape every 30s
**Grafana Dashboard**: Jenkins dashboard from Grafana.com (ID: 9964)

**Alerts** (PrometheusRule):
- `JenkinsDown`: Jenkins not responding for 5 minutes
- `JenkinsBuildFailed`: Build failure detected
- `JenkinsQueueStuck`: Jobs stuck in queue > 10 minutes

**Notifications**:
- ntfy plugin for build success/failure notifications
- Target topic: `homelab-alerts`

## 9. Resource Requirements

**Decision**: Conservative resource limits suitable for homelab

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| Jenkins Controller | 500m | 2000m | 1Gi | 2Gi |
| DinD Sidecar | 200m | 1000m | 512Mi | 1Gi |

**Rationale**:
- Builds may spike CPU/memory temporarily
- DinD needs resources for Docker daemon and build processes
- Limits prevent resource exhaustion on homelab nodes

## 10. Security Considerations

**Decision**: Follow constitution security principles

| Aspect | Implementation |
|--------|----------------|
| Secrets | K8s Secrets, never in Git |
| Network | ClusterIP service, Traefik ingress only |
| Authentication | Jenkins native auth (admin user) |
| Authorization | Matrix-based security (admin full access) |
| Container Security | Non-root Jenkins user, DinD privileged (required) |

**Note**: DinD requires privileged mode which is a security trade-off. For homelab, this is acceptable. Production environments should consider Kaniko or Buildah.

## Summary

Jenkins will be deployed using:
- Official Helm chart with JCasC for reproducible configuration
- DinD sidecar for Docker builds inside Kubernetes
- Pre-installed plugins for Maven, Node.js, Python, Go
- Nexus credentials as K8s Secret
- Traefik ingress with local-ca TLS
- Prometheus metrics and ntfy notifications
- 20Gi persistent storage
