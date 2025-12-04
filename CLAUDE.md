# chocolandia_kube Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-11-08

## Active Technologies
- HCL (OpenTofu) 1.6+, Bash scripting for validation + K3s v1.28+, OpenTofu 1.6+, kubectl, Helm (002-k3s-mvp-eero)
- SQLite datastore (embedded in K3s server), local OpenTofu state file, Kubernetes PersistentVolumes via local-path provisioner (002-k3s-mvp-eero)
- YAML (Kubernetes manifests) / HCL (OpenTofu) 1.6+ + Pi-hole Docker image (pihole/pihole:latest), K3s local-path-provisioner, kubectl, Helm (optional) (003-pihole)
- Kubernetes PersistentVolume (local-path-provisioner) for /etc/pihole and /etc/dnsmasq.d (003-pihole)
- HCL (OpenTofu) 1.6+, Cloudflare Zero Trust (cloudflared), Cloudflare Terraform Provider ~> 4.0, Bash validation scripts (004-cloudflare-zerotrust)
- Kubernetes Deployment (cloudflared pods), Secret (tunnel credentials), PodDisruptionBudget (HA), Google OAuth 2.0 (Cloudflare Access) (004-cloudflare-zerotrust)
- HCL (OpenTofu) 1.6+, YAML (Kubernetes manifests) + cert-manager v1.13.x (Helm chart), Let's Encrypt ACME CA, Traefik v3.1.0 (ingress controller) (006-cert-manager)
- Kubernetes Secrets (TLS certificates and private keys), etcd (cert-manager state via CRDs) (006-cert-manager)
- Kubernetes Secrets (ServiceAccount tokens, TLS certificates), Kubernetes etcd (state for CRDs) (007-headlamp-web-ui)
- HCL (OpenTofu) 1.6+, YAML (Kubernetes manifests), Bash scripting (008-gitops-argocd)
- PersistentVolume via local-path-provisioner (Homepage configuration YAML files) (009-homepage-dashboard)
- Bash scripting / Python 3.11+ (for sync automation) + GitHub CLI (`gh`), Git, GitHub Wiki API (via gh or git) (010-github-wiki-docs)
- GitHub Wiki git repository (separate from main repo), local specs/ directory as source (010-github-wiki-docs)
- Kubernetes PersistentVolumes via local-path-provisioner (existing in cluster) (011-postgresql-cluster)
- Containerized application (existing Dockerfile), Kubernetes manifests (YAML), OpenTofu 1.6+ for database provisioning (012-beersystem-deployment)
- PostgreSQL database "beersystem_stage" with persistent storage via local-path-provisioner (012-beersystem-deployment)
- PostgreSQL database "beersystem_stage" with persistent storage via CloudNativePG PersistentVolumes (012-beersystem-deployment)
- YAML (Homepage configuration), HCL (OpenTofu/Terraform 1.6+) + Homepage Docker image (ghcr.io/gethomepage/homepage), Kubernetes 1.28 (K3s), Helm, OpenTofu 1.6+ (001-homepage-update)
- Kubernetes ConfigMaps for configuration persistence (services.yaml, widgets.yaml, settings.yaml, kubernetes.yaml) (001-homepage-update)
- N/A (infrastructure deployment) + Redis 7.x (Docker image), Helm chart (bitnami/redis or equivalent), MetalLB LoadBalancer, Prometheus Redis Exporter (013-redis-deployment)
- N/A (infrastructure deployment) + Redis 7.x (Bitnami Helm chart), MetalLB LoadBalancer, Prometheus Redis Exporter (013-redis-deployment)
- HCL (OpenTofu 1.6+), YAML (Kubernetes manifests), Bash (scripts de validación) + Prometheus (kube-prometheus-stack Helm chart), Grafana, Alertmanager, Ntfy (014-monitoring-alerts)
- Kubernetes PersistentVolumes via local-path-provisioner (métricas 7-14 días retención) (014-monitoring-alerts)
- HCL (OpenTofu 1.6+), YAML (Kubernetes manifests), Bash (validation scripts) + Docker Registry v2, LocalStack (Community Edition), Traefik Ingress, cert-manager (015-dev-tools-local)
- PersistentVolumes via local-path-provisioner (30GB registry + 20GB LocalStack) (015-dev-tools-local)
- HCL (OpenTofu 1.6+), YAML (Kubernetes manifests) + Nexus Repository OSS 3.x, Kubernetes provider ~> 2.23, cert-manager, Traefik (016-nexus-repository)
- Kubernetes PersistentVolume via local-path-provisioner (50Gi recommended) (016-nexus-repository)
- HCL (OpenTofu 1.6+), YAML (Kubernetes manifests), Bash (validation scripts) + Actions Runner Controller (ARC) Helm chart, Kubernetes provider ~> 2.23, Helm provider ~> 2.12 (017-github-actions-runner)
- Kubernetes PersistentVolume via local-path-provisioner (runner work directory, configuration state) (017-github-actions-runner)
- YAML (Home Assistant configuration), HCL (OpenTofu 1.6+) + Home Assistant Core (container), Govee integration (HACS), Prometheus integration, Ntfy integration (018-home-assistant)
- Kubernetes PersistentVolume via local-path-provisioner (Home Assistant config directory) (018-home-assistant)
- YAML (Kubernetes manifests) / HCL (OpenTofu) 1.6+ + Home Assistant Core (ghcr.io/home-assistant/home-assistant:stable), HACS, ha-prometheus-sensor (018-home-assistant)
- Kubernetes PersistentVolume via local-path-provisioner (10Gi for /config) (018-home-assistant)
- YAML (Kubernetes manifests), HCL (OpenTofu 1.6+) + govee2mqtt (ghcr.io/wez/govee2mqtt), Eclipse Mosquitto (MQTT broker), Home Assistant MQTT integration (019-govee2mqtt)
- PersistentVolume para caché de govee2mqtt (opcional), PV para Mosquitto (persistencia de mensajes) (019-govee2mqtt)

- HCL (OpenTofu) 1.6+, Bash scripting for validation (001-k3s-cluster-setup)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for HCL (Terraform) 1.6+, Bash scripting for validation

## Code Style

HCL (Terraform) 1.6+, Bash scripting for validation: Follow standard conventions

## Recent Changes
- 019-govee2mqtt: Added YAML (Kubernetes manifests), HCL (OpenTofu 1.6+) + govee2mqtt (ghcr.io/wez/govee2mqtt), Eclipse Mosquitto (MQTT broker), Home Assistant MQTT integration
- 018-home-assistant: Added YAML (Kubernetes manifests) / HCL (OpenTofu) 1.6+ + Home Assistant Core (ghcr.io/home-assistant/home-assistant:stable), HACS, ha-prometheus-sensor
- 018-home-assistant: Added YAML (Home Assistant configuration), HCL (OpenTofu 1.6+) + Home Assistant Core (container), Govee integration (HACS), Prometheus integration, Ntfy integration


<!-- MANUAL ADDITIONS START -->

## MetalLB LoadBalancer IP Assignments

**CRITICAL: All services exposed externally MUST use LoadBalancer type, NOT NodePort**

MetalLB Pool Configuration:
- Pool Name: `eero-pool`
- IP Range: `192.168.4.200-192.168.4.210`
- Namespace: `metallb-system`
- Advertisement: L2 (Layer 2)

### Active IP Assignments

| Service | Namespace | External IP | Ports | Description |
|---------|-----------|-------------|-------|-------------|
| postgres-ha-postgresql-primary | postgresql | 192.168.4.200 | 5432/TCP | PostgreSQL HA Primary - Main database endpoint |
| pihole-dns | default | 192.168.4.201 | 53/TCP, 53/UDP | Pi-hole DNS - Network-wide ad blocking and DNS |
| traefik | traefik | 192.168.4.202 | 80/TCP, 443/TCP, 9100/TCP | Traefik Ingress Controller - Entry point for all HTTPS traffic + Prometheus metrics |
| redis-shared-external | redis | 192.168.4.203 | 6379/TCP | Redis Shared - Cluster-wide caching service (primary + replica) |

### Available IPs
- 192.168.4.204 - 192.168.4.210 (7 IPs available)

### Important Notes
1. **Always use LoadBalancer type** for services that need to be accessible on standard ports (53, 80, 443, 5432, etc.)
2. **NodePort is only for internal/non-standard port access** (e.g., web admin interfaces on high ports)
3. **K3s ServiceLB (Klipper) must be disabled** for services managed by MetalLB using the annotation: `svccontroller.k3s.cattle.io/enablelb: "false"`
4. When applying Terraform, verify that LoadBalancer services maintain their type and annotations
5. MetalLB creates the LoadBalancer externally (not via svclb-* pods like K3s ServiceLB)
6. Services are accessible on:
   - The assigned LoadBalancer IP (e.g., 192.168.4.200)
   - All node IPs (192.168.4.101, 192.168.4.102, etc.) on the service port

### Terraform Module Requirements
- Pi-hole DNS service: `type = "LoadBalancer"` in `terraform/modules/pihole/main.tf`
- PostgreSQL service: Managed by Helm chart (already configured as LoadBalancer)
- Traefik service: Managed by Helm chart (already configured as LoadBalancer)

## Local CA for .local Domains

Since Let's Encrypt cannot issue certificates for `.local` TLD, we use a self-signed CA managed by cert-manager.

### ClusterIssuers Available
| Issuer Name | Type | Use Case |
|-------------|------|----------|
| `letsencrypt-production` | ACME | Public domains (*.chocolandiadc.com) via Cloudflare DNS |
| `local-ca` | Self-signed CA | Private domains (*.chocolandiadc.local) |

### CA Certificate Location
- **Kubernetes Secret**: `local-ca-secret` in `cert-manager` namespace
- **Local file**: `terraform/environments/chocolandiadc-mvp/chocolandia-local-ca.crt`

### Trusting the CA on Client Machines

**macOS (for curl, browsers):**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain chocolandia-local-ca.crt
```

**Docker Desktop:**
```bash
mkdir -p ~/.docker/certs.d/docker.nexus.chocolandiadc.local
cp chocolandia-local-ca.crt ~/.docker/certs.d/docker.nexus.chocolandiadc.local/ca.crt
# Then restart Docker Desktop
# Note: Repeat this for each Docker registry hostname using this CA
```

**Export CA from cluster (if needed):**
```bash
kubectl get secret -n cert-manager local-ca-secret -o jsonpath='{.data.ca\.crt}' | base64 -d > chocolandia-local-ca.crt
```

## Nexus Repository Manager

Multi-format artifact repository for Docker, Helm, NPM, Maven, and APT packages.

### URLs
| Service | URL | Description |
|---------|-----|-------------|
| Web UI | https://nexus.chocolandiadc.local | Admin interface |
| Docker Registry | https://docker.nexus.chocolandiadc.local | Docker push/pull |

### Configured Repositories
| Repository | Type | Format | Description |
|------------|------|--------|-------------|
| `docker-hosted` | hosted | Docker | Private Docker images (port 8082) |
| `helm-hosted` | hosted | Helm | Private Helm charts |
| `npm-proxy` | proxy | NPM | Cache for npmjs.org |
| `apt-ubuntu` | proxy | APT | Cache for Ubuntu packages |
| `maven-central` | proxy | Maven | Cache for Maven Central (pre-configured) |
| `maven-releases` | hosted | Maven | Release artifacts (pre-configured) |
| `maven-snapshots` | hosted | Maven | Snapshot artifacts (pre-configured) |
| `maven-public` | group | Maven | Aggregated Maven repos (pre-configured) |

### Docker Usage
```bash
# Login
docker login docker.nexus.chocolandiadc.local -u admin

# Tag and push
docker tag myimage:latest docker.nexus.chocolandiadc.local/myimage:latest
docker push docker.nexus.chocolandiadc.local/myimage:latest

# Pull
docker pull docker.nexus.chocolandiadc.local/myimage:latest
```

### Helm Usage
```bash
# Add repo (requires helm-nexus-push plugin)
helm repo add nexus https://nexus.chocolandiadc.local/repository/helm-hosted/ --username admin --password <password>

# Push chart
helm push mychart-0.1.0.tgz nexus
```

### NPM Usage
```bash
# Configure npm to use Nexus proxy
npm config set registry https://nexus.chocolandiadc.local/repository/npm-proxy/

# Or per-project in .npmrc
registry=https://nexus.chocolandiadc.local/repository/npm-proxy/
```

<!-- MANUAL ADDITIONS END -->
- ~/.ssh/id_ed25519_k3s  es el key para entrar a los nodos
