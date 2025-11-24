# Nexus Repository Manager Module

OpenTofu module for deploying Sonatype Nexus Repository Manager OSS on Kubernetes.

## Features

- Nexus Repository Manager OSS 3.x
- Support for multiple repository formats:
  - Docker (private registry)
  - Helm (chart repository)
  - NPM (package registry)
  - Maven (artifact repository)
  - APT (Debian packages)
- TLS certificates via cert-manager
- Traefik ingress for web UI and Docker API
- Prometheus metrics integration
- Persistent storage via PVC

## Usage

```hcl
module "nexus" {
  source = "../../modules/nexus"

  hostname        = "nexus.chocolandiadc.local"
  docker_hostname = "docker.nexus.chocolandiadc.local"
  storage_size    = "50Gi"
  enable_metrics  = true
}
```

## Requirements

| Name | Version |
|------|---------|
| opentofu | >= 1.6.0 |
| kubernetes | ~> 2.23 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| namespace | Kubernetes namespace | string | "nexus" |
| hostname | Nexus web UI hostname | string | required |
| docker_hostname | Docker registry hostname | string | required |
| storage_size | PVC storage size | string | "50Gi" |
| storage_class | Storage class name | string | "local-path" |
| nexus_image | Container image | string | "sonatype/nexus3:latest" |
| resource_limits_memory | Memory limit | string | "2Gi" |
| resource_limits_cpu | CPU limit | string | "1000m" |
| resource_requests_memory | Memory request | string | "1536Mi" |
| resource_requests_cpu | CPU request | string | "500m" |
| cluster_issuer | cert-manager ClusterIssuer | string | "letsencrypt-prod" |
| traefik_entrypoint | Traefik HTTPS entrypoint | string | "websecure" |
| enable_metrics | Enable Prometheus metrics | bool | true |
| jvm_heap_size | JVM heap size | string | "1200m" |

## Outputs

| Name | Description |
|------|-------------|
| web_url | Nexus Web UI URL |
| docker_url | Docker registry URL |
| namespace | Deployed namespace |
| service_name | ClusterIP service name |
| internal_endpoint | Internal cluster endpoint |
| docker_service_name | Docker connector service name |

## Post-Deployment Setup

1. Get initial admin password:
   ```bash
   kubectl exec -n nexus deployment/nexus -- cat /nexus-data/admin.password
   ```

2. Access Nexus UI at https://nexus.chocolandiadc.local

3. Complete setup wizard and change admin password

4. Create repositories via UI (Settings > Repository > Repositories):
   - Docker: `docker-hosted` (HTTP connector port 8082)
   - Helm: `helm-hosted`
   - NPM: `npm-hosted`
   - Maven: `maven-releases`, `maven-snapshots`
   - APT: `apt-hosted`

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │           Traefik Ingress           │
                    └───────────┬───────────┬─────────────┘
                                │           │
                    ┌───────────▼───┐   ┌───▼───────────┐
                    │ nexus:8081    │   │ docker:8082   │
                    │ (Web UI/API)  │   │ (Docker API)  │
                    └───────────┬───┘   └───┬───────────┘
                                │           │
                    ┌───────────▼───────────▼─────────────┐
                    │         Nexus Deployment            │
                    │     sonatype/nexus3:latest          │
                    │                                     │
                    │  Ports:                             │
                    │   - 8081: Web UI, REST API, Helm,   │
                    │           NPM, Maven, APT           │
                    │   - 8082: Docker Registry API       │
                    └───────────────┬─────────────────────┘
                                    │
                    ┌───────────────▼─────────────────────┐
                    │      PersistentVolumeClaim          │
                    │           nexus-data                │
                    │             50Gi                    │
                    └─────────────────────────────────────┘
```
