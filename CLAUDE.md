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
- Bash (scripts de validación), HCL/OpenTofu 1.6+ (manifiestos existentes) + kubectl, helm, k3s installer, apt package manager (020-cluster-version-audit)
- etcd (K3s), Longhorn (persistent volumes), PostgreSQL, Redis (020-cluster-version-audit)
- HCL (OpenTofu 1.6+), Bash scripting for validation + OpenTofu, Helm provider (~> 2.12), Kubernetes provider (~> 2.23), kubectl (020-cluster-version-audit)
- N/A (infrastructure operations only) (020-cluster-version-audit)
- HCL (OpenTofu 1.6+), YAML (Helm values) (021-monitoring-stack-upgrade)
- PersistentVolume 10Gi (Prometheus), 5Gi (Grafana) via local-path-provisioner (021-monitoring-stack-upgrade)
- HCL (OpenTofu 1.6+) + hashicorp/kubernetes ~> 2.23, hashicorp/helm ~> 2.11, hashicorp/time ~> 0.11 (022-metallb-refactor)
- Kubernetes CRDs (metallb.io/v1beta1), Terraform state file (local) (022-metallb-refactor)
- Bash scripting (wiki sync scripts), Markdown (documentation) + Git, gh CLI, kubectl, existing wiki scripts in scripts/wiki/ (024-docs-wiki-sync)
- N/A (documentation only) (024-docs-wiki-sync)
- YAML (Homepage configuration format), HCL (OpenTofu 1.6+) + Homepage v1.4.6 (ghcr.io/gethomepage/homepage:v1.4.6), Kubernetes provider ~> 2.23 (025-homepage-redesign)
- HCL (OpenTofu 1.6+), YAML (Kubernetes manifests) + kube-prometheus-stack Helm chart, ntfy, Homepage (026-ntfy-homepage-alerts)
- Kubernetes Secrets (ntfy credentials), ConfigMaps (Homepage config) (026-ntfy-homepage-alerts)
- HCL (OpenTofu 1.6+), Bash scripting para scripts de backup + rclone/rclone:latest, curl (para ntfy), kubectl (028-paperless-gdrive-backup)
- PVCs existentes (paperless-ngx-data 5Gi, paperless-ngx-media 40Gi), Google Drive como destino (028-paperless-gdrive-backup)

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
- 028-paperless-gdrive-backup: Added HCL (OpenTofu 1.6+), Bash scripting para scripts de backup + rclone/rclone:latest, curl (para ntfy), kubectl
- 027-paperless-ngx: Added HCL (OpenTofu 1.6+), YAML (Kubernetes manifests)
- 026-ntfy-homepage-alerts: Added HCL (OpenTofu 1.6+), YAML (Kubernetes manifests) + kube-prometheus-stack Helm chart, ntfy, Homepage


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
| pihole-dns | default | 192.168.4.200 | 53/TCP, 53/UDP | Pi-hole DNS - Network-wide ad blocking and DNS |
| samba-smb | paperless | 192.168.4.201 | 445/TCP | Paperless-ngx Samba - Scanner document intake |
| traefik | traefik | 192.168.4.202 | 80/TCP, 443/TCP, 9100/TCP | Traefik Ingress Controller - Entry point for all HTTPS traffic + Prometheus metrics |
| redis-shared-external | redis | 192.168.4.203 | 6379/TCP | Redis Shared - Cluster-wide caching service (groundhog2k/redis with official images) |
| postgres-ha-external | postgresql | 192.168.4.204 | 5432/TCP | PostgreSQL - Main database endpoint (groundhog2k/postgres with official images) |

### Available IPs
- 192.168.4.205 - 192.168.4.210 (6 IPs available)

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

## Paperless-ngx Document Management

**Feature**: 027-paperless-ngx
**Status**: Deployed (2026-01-01)

Document management system with OCR processing and scanner integration.

### URLs
| Service | URL | Description |
|---------|-----|-------------|
| Web UI (Public) | https://paperless.chocolandiadc.com | Cloudflare Zero Trust |
| Web UI (LAN) | https://paperless.chocolandiadc.local | Direct LAN access |
| SMB Share | smb://192.168.4.201/consume | Scanner document intake |

### Configuration
| Setting | Value |
|---------|-------|
| Namespace | paperless |
| OCR Languages | Spanish + English (spa+eng) |
| Database | PostgreSQL (192.168.4.204) |
| Cache | Redis (192.168.4.203) |
| Storage | 5Gi data, 40Gi media, 5Gi consume |

### Scanner Setup
Configure your scanner to save to SMB:
```
Server: 192.168.4.201
Share: consume
User: scanner
Password: (run: tofu output -raw paperless_samba_password)
```

### Credentials
```bash
# Get admin password
tofu output -raw paperless_admin_password

# Get Samba password for scanner
tofu output -raw paperless_samba_password
```

### Monitoring
- ServiceMonitor: `paperless-ngx` in `paperless` namespace
- PrometheusRule: `paperless-ngx-alerts` (PaperlessDown, PaperlessHighMemory)
- Metrics endpoint: `/metrics` on port 8000

### Google Drive Backup (028-paperless-gdrive-backup)

**Status**: Deployed (2026-01-04)

Automated daily backup of Paperless documents to Google Drive using rclone.

| Setting | Value |
|---------|-------|
| Schedule | 3:00 AM daily |
| Remote | `gdrive:/Paperless-Backup/` |
| Retention | Deleted files moved to `.deleted/` folder |
| Timeout | 2 hours |
| Notifications | ntfy (homelab-alerts topic) |

**Resources in `paperless` namespace:**
- `cronjob/paperless-backup` - Daily backup job
- `configmap/paperless-backup-script` - Backup script
- `secret/rclone-gdrive-config` - Google Drive OAuth credentials
- `prometheusrule/paperless-backup-alerts` - Missing/failed backup alerts

**Manual backup:**
```bash
kubectl create job --from=cronjob/paperless-backup manual-backup -n paperless
kubectl logs -f job/manual-backup -n paperless
```

**Restore from backup:**
```bash
# Full restore (stops Paperless during restore)
scripts/paperless-backup/restore.sh

# Partial restore (single file)
kubectl run restore --rm -it --image=rclone/rclone \
  --overrides='{"spec":{"containers":[{"name":"restore","image":"rclone/rclone","command":["sh","-c","sleep 3600"],"volumeMounts":[{"name":"cfg","mountPath":"/config/rclone"}]}],"volumes":[{"name":"cfg","secret":{"secretName":"rclone-gdrive-config"}}]}}' \
  -n paperless -- rclone copy gdrive:/Paperless-Backup/media/documents/originals/0000001.pdf /tmp/
```

**Verify backup in Google Drive:**
```bash
rclone tree gdrive:/Paperless-Backup --max-depth 2
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

## Monitoring Stack (kube-prometheus-stack)

**Current Version**: 68.4.0 (Upgraded 2025-12-27 from 55.5.0)

### Components
| Component | Version | Description |
|-----------|---------|-------------|
| Prometheus Operator | v0.79.2 | CRD-based monitoring configuration |
| Prometheus | v2.55.x | Metrics collection and storage |
| Grafana | v11.4.0 | Visualization and dashboards |
| Alertmanager | v0.27.x | Alert routing and notifications |
| kube-state-metrics | v2.14.x | Kubernetes object metrics |
| prometheus-node-exporter | v1.8.x | Node-level metrics |

### Key Configuration
- **Retention**: 15 days
- **Grafana Access**: NodePort 30000 (http://<node-ip>:30000)
- **Grafana Credentials**: admin user - password in `monitoring.tf` (grafana.adminPassword)
- **Alert Notifications**: Ntfy (homelab-alerts topic)
- **Storage**: 10Gi Prometheus, 5Gi Grafana (local-path-provisioner)

### Important Notes
1. **hostNetwork disabled** for node-exporter due to K3s scheduler port conflict
2. **ServiceMonitor discovery** enabled across ALL namespaces
3. **Alertmanager v2 API** - v1 API removed in 0.27.0
4. **Rollback available**: `helm rollback kube-prometheus-stack 15 -n monitoring`

### Custom Dashboards (6)
- K3s cluster overview
- Node Exporter Full
- Traefik Official
- Redis Dashboard
- PostgreSQL Database
- Longhorn

### Alert Receivers
| Receiver | Destination | Use Case |
|----------|-------------|----------|
| ntfy-homelab | http://ntfy.ntfy.svc.cluster.local/homelab-alerts?template=alertmanager | Default alerts |
| ntfy-critical | http://ntfy.ntfy.svc.cluster.local/homelab-alerts?template=alertmanager | Critical severity |
| null | (discarded) | Watchdog alerts |

### Ntfy Authentication (026-ntfy-homepage-alerts)

**Status**: Configured (2025-12-31)
**Root Cause Fixed**: ntfy's `auth-default-access: "read-only"` requires authentication for publishing

| Component | Configuration |
|-----------|--------------|
| ntfy User | `alertmanager` (dedicated user with write-only access to homelab-alerts) |
| Password Secret | `ntfy-alertmanager-password` in `monitoring` namespace |
| Auth Method | HTTP Basic Auth via `password_file` |
| Secret Mount | `/etc/alertmanager/secrets/ntfy-alertmanager-password/password` |

**Testing Notifications**:
```bash
# Get password from secret
PASSWORD=$(kubectl get secret ntfy-alertmanager-password -n monitoring -o jsonpath='{.data.password}' | base64 -d)

# Test from cluster (requires temp curl pod)
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -u "alertmanager:${PASSWORD}" -d "Test notification" \
  http://ntfy.ntfy.svc.cluster.local/homelab-alerts
```

**Verify notifications working**:
```bash
# Check ntfy message count increasing
kubectl logs -n ntfy deployment/ntfy --tail=5 | grep messages_published
```

## K3s Secret Encryption at Rest

**Status**: Enabled (2025-12-27)
**Encryption Provider**: AES-CBC
**Active Key**: aescbckey-2025-12-27T23:36:11Z

### Encryption Key Location
- **Primary**: `/var/lib/rancher/k3s/server/cred/encryption-config.json` (on master1)
- **Backup**: `~/k3s-encryption-backup-YYYYMMDD/encryption-config-backup.json` (local machine)

### Important Notes
1. Encryption is managed from master1 (192.168.4.101)
2. Secondary server (nodo03) syncs automatically via etcd
3. Agent nodes (nodo1, nodo04) do not require encryption config

### Recovery Procedures

**If K3s fails to start after encryption change:**
```bash
# Check K3s logs
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 "sudo journalctl -u k3s -n 100 --no-pager"

# Restore encryption config from backup
scp ~/k3s-encryption-backup-YYYYMMDD/encryption-config-backup.json chocolim@192.168.4.101:/tmp/
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 "sudo cp /tmp/encryption-config-backup.json /var/lib/rancher/k3s/server/cred/encryption-config.json && sudo systemctl restart k3s"
```

**If encryption key is lost:**
- Secrets CANNOT be decrypted without the key
- **WARNING: This procedure restores secrets from a backup taken *before* encryption was enabled. Any secrets created or updated since that backup will be PERMANENTLY LOST.**
- Restore from secrets backup: `~/k3s-encryption-backup-YYYYMMDD/all-secrets-backup.yaml`
- May require cluster rebuild if no backup exists

### Rollback (Disable Encryption)
```bash
# On master1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101
sudo k3s secrets-encrypt disable
sudo k3s secrets-encrypt rotate-keys
sudo systemctl restart k3s
# Then restart nodo03
```

### Verify Encryption Status
```bash
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 "sudo k3s secrets-encrypt status"
# Expected: Encryption Status: Enabled, Current Rotation Stage: reencrypt_finished
```

## OpenTofu Remote Backend (MinIO)

**Status**: Enabled (2025-12-31)
**Backend**: S3-compatible (MinIO)
**Bucket**: `opentofu-state`
**Key**: `chocolandiadc-mvp/terraform.tfstate`

### Configuration
The OpenTofu state is stored in MinIO.

| Setting | Value |
|---------|-------|
| Endpoint | http://192.168.4.101:30090 |
| Bucket | opentofu-state |
| Region | us-east-1 (dummy, required by S3 provider) |
| Versioning | Manual (use `mc version enable` to enable) |

### Security Considerations
**HTTP without TLS**: The MinIO endpoint uses HTTP (not HTTPS). This is acceptable for homelab
environments where traffic stays within trusted LAN. Trade-offs:
- Credentials and state are transmitted unencrypted
- Only run `tofu` commands from trusted networks
- Consider enabling TLS on MinIO for sensitive environments

**NodePort Exposure**: MinIO S3 API is exposed on port 30090 on all cluster nodes.
- Protected by MinIO credentials (not anonymous)
- Ensure NodePort is not exposed to public internet
- Use firewall rules to restrict access if needed

### Usage
Before running any `tofu` command, source the environment file:
```bash
cd terraform/environments/chocolandiadc-mvp
source ./backend-env.sh
tofu plan
```

Or manually set the environment variables:
```bash
export AWS_ACCESS_KEY_ID="$(tofu output -raw minio_root_user)"
export AWS_SECRET_ACCESS_KEY="$(tofu output -raw minio_root_password)"
export AWS_ENDPOINT_URL_S3="http://192.168.4.101:30090"
```

### State Backup Location
- **Remote (Primary)**: MinIO bucket `opentofu-state` with versioning
- **Local Backup**: `~/terraform-state-backup-YYYYMMDD-HHMMSS.tfstate`

### Recovery Procedures

**If MinIO is unavailable:**
```bash
# Restore from local backup
cp ~/terraform-state-backup-YYYYMMDD-HHMMSS.tfstate terraform/environments/chocolandiadc-mvp/terraform.tfstate
# Temporarily rename backend.tf to use local state
mv backend.tf backend.tf.bak
tofu init
# After fixing MinIO, restore backend.tf and migrate state back
```

**If state is corrupted:**
```bash
# Download previous version from MinIO (versioning enabled)
# First, get credentials from K8s secret:
ACCESS_KEY=$(kubectl get secret -n minio minio-credentials -o jsonpath='{.data.rootUser}' | base64 -d)
SECRET_KEY=$(kubectl get secret -n minio minio-credentials -o jsonpath='{.data.rootPassword}' | base64 -d)
mc alias set minio http://192.168.4.101:30090 "$ACCESS_KEY" "$SECRET_KEY"
mc ls --versions minio/opentofu-state/chocolandiadc-mvp/
mc cp --version-id VERSION_ID minio/opentofu-state/chocolandiadc-mvp/terraform.tfstate ./restored.tfstate
```

## NVIDIA GPU (nodo05)

**Status**: Configured (2026-01-03)
**Node**: nodo05 (192.168.4.105)

### Hardware
| Spec | Value |
|------|-------|
| GPU | NVIDIA GeForce GTX 760 |
| VRAM | 2GB |
| Architecture | Kepler (GK104) |
| Driver | 470.256.02 |
| CUDA | 11.4 |

### Kubernetes Integration
| Component | Version/Status |
|-----------|----------------|
| NVIDIA Driver | 470.256.02 |
| NVIDIA Container Toolkit | 1.18.1 |
| NVIDIA Device Plugin | v0.14.5 (DaemonSet) |
| RuntimeClass | `nvidia` |
| Resource | `nvidia.com/gpu: 1` |

### Using the GPU in Pods

Pods that need GPU access must:
1. Use `runtimeClassName: nvidia`
2. Request the GPU resource

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  runtimeClassName: nvidia
  containers:
  - name: gpu-container
    image: nvidia/cuda:11.4-base
    resources:
      limits:
        nvidia.com/gpu: 1
    command: ["nvidia-smi"]
```

### Verification Commands
```bash
# Check GPU on node
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.105 "nvidia-smi"

# Check GPU available in Kubernetes
kubectl describe node nodo05 | grep nvidia.com/gpu

# Check device plugin logs
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds --field-selector spec.nodeName=nodo05
```

### Recommended Use Cases
| Use Case | Viability | Notes |
|----------|-----------|-------|
| Jellyfin/Plex transcoding | Good | NVDEC for hardware decode |
| Frigate NVR | Good | Hardware decode for camera streams |
| Ollama/LLMs | Limited | Only small models (~2GB VRAM) |
| Stable Diffusion | Not viable | Needs minimum 4GB VRAM |

### Important Notes
1. Only nodo05 has a GPU - use nodeSelector or nodeAffinity for GPU workloads
2. The NVIDIA device plugin runs on all nodes but only detects GPUs on nodo05
3. RuntimeClass `nvidia` is required for GPU access in containers

<!-- MANUAL ADDITIONS END -->
- ~/.ssh/id_ed25519_k3s  es el key para entrar a los nodos (usuario: chocolim)
