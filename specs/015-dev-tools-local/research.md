# Research: LocalStack and Container Registry

**Feature**: 015-dev-tools-local
**Date**: 2025-11-23

## 1. Docker Registry Implementation

### Decision: Docker Registry v2 (Official)

**Rationale**: The official Docker Registry v2 is the standard, lightweight solution for private container registries. It's battle-tested, supports all Docker/OCI image formats, and has minimal resource requirements.

**Alternatives Considered**:

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| Docker Registry v2 | Lightweight, standard API, simple | No UI built-in | SELECTED |
| Harbor | Full UI, vulnerability scanning, RBAC | Heavy (3GB+ RAM), overkill for homelab | Rejected |
| Gitea Container Registry | Integrated with Gitea | Requires Gitea installation | Rejected |
| Distribution (CNCF) | Same as Docker Registry v2 | Same codebase | N/A |

### Authentication Implementation

**Decision**: htpasswd file with bcrypt encryption

**Rationale**: Native Docker Registry v2 support, simple to manage, compatible with `docker login` workflow.

```yaml
# Registry config.yml snippet
auth:
  htpasswd:
    realm: "Registry Realm"
    path: /auth/htpasswd
```

**Commands for htpasswd generation**:
```bash
htpasswd -Bbn username password > htpasswd
kubectl create secret generic registry-auth --from-file=htpasswd=./htpasswd
```

### TLS Configuration

**Decision**: Use Traefik IngressRoute with cert-manager

**Rationale**: Existing infrastructure already handles TLS termination. Registry runs HTTP internally, Traefik handles HTTPS.

```yaml
# Traefik annotation approach
annotations:
  traefik.ingress.kubernetes.io/router.tls: "true"
  traefik.ingress.kubernetes.io/router.tls.certresolver: "letsencrypt"
```

### Storage Configuration

**Decision**: PersistentVolumeClaim with local-path-provisioner (30GB)

**Rationale**: Uses existing cluster storage infrastructure. 30GB sufficient for development images.

```yaml
storage:
  filesystem:
    rootdirectory: /var/lib/registry
```

### Registry UI

**Decision**: Joxit/docker-registry-ui

**Rationale**: Lightweight, read-only UI that connects to Registry v2 API. No additional dependencies.

**Alternatives Considered**:
- Portus: Heavy, deprecated
- Quay: Enterprise-grade, overkill
- crane: CLI-only, not UI

---

## 2. LocalStack Implementation

### Decision: LocalStack Community Edition (Free Tier)

**Rationale**: Community edition supports all required services (S3, SQS, SNS, DynamoDB, Lambda) for free. Pro features not needed for homelab development.

**Services Enabled** (based on spec FR-002):
- S3 (object storage)
- SQS (message queues)
- SNS (notifications)
- DynamoDB (NoSQL)
- Lambda (serverless functions)

### LocalStack Version

**Decision**: Use `localstack/localstack:latest` (currently 3.x)

**Rationale**: Latest stable version with best AWS API compatibility.

### Persistence Configuration

**Decision**: Enable persistence with DATA_DIR environment variable

**Rationale**: Required by FR-004 to persist data across restarts.

```yaml
env:
  - name: PERSISTENCE
    value: "1"
  - name: DATA_DIR
    value: "/var/lib/localstack"
```

### Lambda Execution Mode

**Decision**: Docker-in-Docker (DinD) for Lambda execution

**Rationale**: LocalStack requires Docker access to run Lambda functions in containers. K3s nodes have Docker/containerd available.

**Configuration**:
```yaml
env:
  - name: LAMBDA_EXECUTOR
    value: "docker"
  - name: DOCKER_HOST
    value: "unix:///var/run/docker.sock"
volumeMounts:
  - name: docker-sock
    mountPath: /var/run/docker.sock
```

**Security Note**: Docker socket access required but acceptable for dev-only service.

### Network Exposure

**Decision**: Single ingress endpoint for all LocalStack services

**Rationale**: LocalStack exposes all services on port 4566 with path-based routing internally.

```
https://localstack.homelab.local → port 4566
AWS CLI endpoint-url: https://localstack.homelab.local
```

---

## 3. DNS Configuration

### Decision: Pi-hole Custom DNS entries

**Rationale**: Existing Pi-hole handles homelab DNS. Add CNAME records pointing to Traefik LoadBalancer IP.

**Required DNS Entries**:
```
registry.homelab.local    → 192.168.4.202 (Traefik LB)
localstack.homelab.local  → 192.168.4.202 (Traefik LB)
registry-ui.homelab.local → 192.168.4.202 (Traefik LB)
```

---

## 4. Kubernetes Node Configuration

### Decision: Configure containerd to trust local registry

**Rationale**: K3s nodes need to pull images from the local registry. Without trust configuration, TLS verification fails or authentication issues occur.

**Implementation Options**:

| Option | Complexity | Notes |
|--------|------------|-------|
| registries.yaml (K3s native) | Low | Preferred - K3s built-in config |
| containerd config.toml | Medium | Manual per-node |
| ImagePullSecrets per deployment | High | Repetitive |

**Decision**: K3s registries.yaml (Option 1)

**Configuration** (`/etc/rancher/k3s/registries.yaml` on each node):
```yaml
mirrors:
  "registry.homelab.local":
    endpoint:
      - "https://registry.homelab.local"
configs:
  "registry.homelab.local":
    auth:
      username: admin
      password: <from-secret>
```

---

## 5. Resource Limits

### Registry Resources

**Decision**: Conservative limits for homelab

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### LocalStack Resources

**Decision**: Higher limits due to Lambda execution

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

---

## 6. Garbage Collection (Registry)

### Decision: Manual garbage collection via registry CLI

**Rationale**: Per clarification, no automatic deletion. Document procedure for manual cleanup.

**Procedure**:
```bash
# 1. Enter registry pod
kubectl exec -it registry-pod -- sh

# 2. Run garbage collection (dry-run first)
registry garbage-collect /etc/docker/registry/config.yml --dry-run

# 3. Run actual garbage collection
registry garbage-collect /etc/docker/registry/config.yml
```

---

## 7. Monitoring Integration

### Registry Metrics

**Decision**: Enable Prometheus metrics endpoint

```yaml
# Registry config.yml
http:
  debug:
    addr: :5001
    prometheus:
      enabled: true
      path: /metrics
```

### LocalStack Metrics

**Decision**: Use LocalStack's built-in health endpoint + custom ServiceMonitor

```yaml
# Health check
GET http://localstack:4566/_localstack/health
```

---

## Summary of Technical Decisions

| Component | Decision | Rationale |
|-----------|----------|-----------|
| Registry Image | registry:2 | Official, lightweight |
| Registry Auth | htpasswd (bcrypt) | Native support, simple |
| Registry TLS | Traefik + cert-manager | Existing infrastructure |
| Registry UI | joxit/docker-registry-ui | Lightweight, read-only |
| LocalStack Version | localstack/localstack:latest | Best AWS compatibility |
| LocalStack Lambda | Docker executor (DinD) | Full Lambda support |
| Storage | local-path-provisioner PVCs | Existing cluster storage |
| DNS | Pi-hole CNAME records | Existing DNS infrastructure |
| Node Config | K3s registries.yaml | Native, simple |
| Garbage Collection | Manual CLI | Per spec requirement |
