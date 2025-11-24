# Data Model: Nexus Repository Manager

**Feature**: 016-nexus-repository
**Date**: 2025-11-24

## Overview

This document describes the Kubernetes resources and OpenTofu configuration entities for deploying Nexus Repository Manager.

## Kubernetes Resources

### Namespace

```yaml
kind: Namespace
metadata:
  name: nexus
  labels:
    name: nexus
    managed-by: opentofu
    app: nexus
```

### PersistentVolumeClaim

| Field | Value | Notes |
|-------|-------|-------|
| name | nexus-data | Stores all repository data |
| storage | 50Gi | Configurable via variable |
| storageClassName | local-path | K3s default |
| accessModes | ReadWriteOnce | Single replica |

### Deployment

| Field | Value | Notes |
|-------|-------|-------|
| replicas | 1 | Single instance |
| image | sonatype/nexus3:latest | Official image |
| ports | 8081 (web), 8082 (docker) | Web UI + Docker connector |
| volumeMounts | /nexus-data | Persistent storage |

**Environment Variables**:

| Variable | Purpose |
|----------|---------|
| INSTALL4J_ADD_VM_PARAMS | JVM heap settings (-Xms1200m -Xmx1200m) |
| NEXUS_SECURITY_RANDOMPASSWORD | Set to false for initial admin password |

**Resource Limits**:

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 500m | 1000m |
| Memory | 1536Mi | 2048Mi |

**Probes**:

| Probe | Path | Port | Initial Delay |
|-------|------|------|---------------|
| Liveness | /service/rest/v1/status | 8081 | 120s |
| Readiness | /service/rest/v1/status | 8081 | 60s |

### Services

**ClusterIP Service (Web UI/API)**:

| Field | Value |
|-------|-------|
| name | nexus |
| type | ClusterIP |
| port | 8081 |
| targetPort | 8081 |

**ClusterIP Service (Docker Registry)**:

| Field | Value |
|-------|-------|
| name | nexus-docker |
| type | ClusterIP |
| port | 8082 |
| targetPort | 8082 |

### Traefik IngressRoute

**HTTPS Route (Web UI)**:

| Field | Value |
|-------|-------|
| entryPoints | websecure |
| host | nexus.chocolandiadc.local |
| service | nexus:8081 |
| tls.secretName | nexus-tls |

**HTTPS Route (Docker API)**:

| Field | Value |
|-------|-------|
| entryPoints | websecure |
| host | docker.nexus.chocolandiadc.local |
| service | nexus-docker:8082 |
| tls.secretName | nexus-docker-tls |

### Certificate (cert-manager)

| Field | Value |
|-------|-------|
| secretName | nexus-tls |
| issuerRef | letsencrypt-prod (ClusterIssuer) |
| dnsNames | nexus.chocolandiadc.local, docker.nexus.chocolandiadc.local |

### ServiceMonitor (Prometheus)

| Field | Value |
|-------|-------|
| name | nexus-metrics |
| endpoint.path | /service/metrics/prometheus |
| endpoint.port | 8081 |
| interval | 30s |

## OpenTofu Module Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| namespace | string | "nexus" | Kubernetes namespace |
| hostname | string | required | Web UI hostname |
| docker_hostname | string | required | Docker registry hostname |
| storage_size | string | "50Gi" | PVC size |
| storage_class | string | "local-path" | Storage class |
| nexus_image | string | "sonatype/nexus3:latest" | Container image |
| resource_limits_memory | string | "2Gi" | Memory limit |
| resource_limits_cpu | string | "1000m" | CPU limit |
| resource_requests_memory | string | "1536Mi" | Memory request |
| resource_requests_cpu | string | "500m" | CPU request |
| cluster_issuer | string | "letsencrypt-prod" | cert-manager issuer |
| traefik_entrypoint | string | "websecure" | Traefik entrypoint |
| enable_metrics | bool | true | Enable Prometheus metrics |

## OpenTofu Module Outputs

| Output | Type | Description |
|--------|------|-------------|
| web_url | string | Nexus Web UI URL |
| docker_url | string | Docker registry URL |
| namespace | string | Deployed namespace |
| service_name | string | ClusterIP service name |
| internal_endpoint | string | Internal cluster endpoint |

## Repository Configuration (Post-Deployment)

Nexus repositories are configured via the web UI after initial deployment. The following repositories should be created:

### Docker Repository

| Setting | Value |
|---------|-------|
| Name | docker-hosted |
| Format | docker |
| Type | hosted |
| HTTP Connector | 8082 |
| Allow anonymous pull | false |

### Helm Repository

| Setting | Value |
|---------|-------|
| Name | helm-hosted |
| Format | helm |
| Type | hosted |

### NPM Repository

| Setting | Value |
|---------|-------|
| Name | npm-hosted |
| Format | npm |
| Type | hosted |

### Maven Repositories

| Setting | Value (releases) | Value (snapshots) |
|---------|------------------|-------------------|
| Name | maven-releases | maven-snapshots |
| Format | maven2 | maven2 |
| Type | hosted | hosted |
| Version Policy | Release | Snapshot |

### APT Repository

| Setting | Value |
|---------|-------|
| Name | apt-hosted |
| Format | apt |
| Type | hosted |
| Distribution | focal (or as needed) |

## State Transitions

### Deployment Lifecycle

```
[Not Deployed] → tofu apply → [Initializing]
                                    ↓
                              [Starting] (JVM boot, ~60s)
                                    ↓
                              [Running] (Ready for requests)
                                    ↓
                    tofu destroy → [Terminating] → [Not Deployed]
```

### Repository States

```
[Empty] → artifact push → [Has Artifacts]
                              ↓
              artifact delete → [Empty] (if all deleted)
```

## Relationships

```
Namespace (nexus)
    ├── PersistentVolumeClaim (nexus-data)
    ├── Deployment (nexus)
    │       └── uses PVC
    ├── Service (nexus) → port 8081
    ├── Service (nexus-docker) → port 8082
    ├── Certificate (nexus-tls)
    ├── IngressRoute (nexus-https) → Service (nexus)
    ├── IngressRoute (nexus-docker-https) → Service (nexus-docker)
    └── ServiceMonitor (nexus-metrics) → Service (nexus)
```
