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
- 009-homepage-dashboard: Added PersistentVolume via local-path-provisioner (Homepage configuration YAML files)
- 008-gitops-argocd: Added HCL (OpenTofu) 1.6+, YAML (Kubernetes manifests), Bash scripting
- 007-headlamp-web-ui: Added HCL (OpenTofu) 1.6+, YAML (Kubernetes manifests)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
