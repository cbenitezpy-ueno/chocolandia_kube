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
- 001-homepage-update: Added YAML (Homepage configuration), HCL (OpenTofu/Terraform 1.6+) + Homepage Docker image (ghcr.io/gethomepage/homepage), Kubernetes 1.28 (K3s), Helm, OpenTofu 1.6+
- 012-beersystem-deployment: Added Containerized application (existing Dockerfile), Kubernetes manifests (YAML), OpenTofu 1.6+ for database provisioning
- 012-beersystem-deployment: Added Containerized application (existing Dockerfile), Kubernetes manifests (YAML), OpenTofu 1.6+ for database provisioning


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

### Available IPs
- 192.168.4.203 - 192.168.4.210 (8 IPs available)

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

<!-- MANUAL ADDITIONS END -->
