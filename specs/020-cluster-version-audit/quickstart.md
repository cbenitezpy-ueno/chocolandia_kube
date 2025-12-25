# Quickstart: Cluster Version Audit & Update

**Branch**: `020-cluster-version-audit` | **Date**: 2025-12-23

## Quick Reference

Referencia rápida para ejecutar las actualizaciones del cluster.

---

## Pre-flight Checks

```bash
# Set kubeconfig
export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig

# Verify cluster access
kubectl get nodes

# Check all pods running
kubectl get pods -A --field-selector=status.phase!=Running

# Verify Longhorn volumes healthy
kubectl -n longhorn-system get volumes.longhorn.io

# Check etcd health
kubectl -n kube-system exec -it $(kubectl -n kube-system get pods -l component=etcd -o name | head -1) -- etcdctl endpoint health
```

---

## Phase 0: Backups

### etcd Snapshot
```bash
# SSH to control-plane node
ssh -i ~/.ssh/id_ed25519_k3s ubuntu@192.168.4.101

# Create etcd snapshot
sudo k3s etcd-snapshot save --name pre-upgrade-$(date +%Y%m%d)

# List snapshots
sudo k3s etcd-snapshot ls
```

### Kubernetes Resources Export
```bash
# Export all resources (except secrets)
kubectl get all -A -o yaml > cluster-backup-$(date +%Y%m%d).yaml
```

---

## Phase 0.5: Ubuntu Security Patches

**Order**: Workers first, then control-plane

### Worker 1 (nodo1)
```bash
ssh -i ~/.ssh/id_ed25519_k3s ubuntu@192.168.4.102
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### Worker 2 (nodo04)
```bash
ssh -i ~/.ssh/id_ed25519_k3s ubuntu@192.168.4.104
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### Control-plane 2 (nodo03)
```bash
# Verify etcd before
kubectl -n kube-system exec -it $(kubectl -n kube-system get pods -l component=etcd -o name | head -1) -- etcdctl member list

ssh -i ~/.ssh/id_ed25519_k3s ubuntu@192.168.4.103
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### Control-plane 1 (master1)
```bash
# Last node - verify etcd quorum first
ssh -i ~/.ssh/id_ed25519_k3s ubuntu@192.168.4.101
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### Validation After Each Node
```bash
kubectl get nodes  # Wait for Ready
kubectl get pods -A | grep -v Running  # Should be empty
```

---

## Phase 1: K3s Upgrade

### Step 1: v1.28.3 → v1.30.x
```bash
# On each node (control-plane first, then workers)
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.30.10+k3s1" sh -

# Validate
kubectl get nodes  # All should show v1.30.10+k3s1
```

### Step 2: v1.30.x → v1.32.x
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.32.11+k3s1" sh -
```

### Step 3: v1.32.x → v1.33.7
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.33.7+k3s1" sh -
```

---

## Phase 2: Longhorn Upgrade (via OpenTofu)

**CRITICAL**: Must upgrade through each minor version!

### Upgrade Path: v1.5 → v1.6 → v1.7 → v1.8 → v1.9 → v1.10

```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# For each version - update chart_version in module call
# terraform/environments/chocolandiadc-mvp/storage.tf:
#   module "longhorn" {
#     chart_version = "1.X.Y"  # Update this
#   }

# Plan and apply
tofu plan -target=module.longhorn
tofu apply -target=module.longhorn

# Validate after each upgrade
kubectl -n longhorn-system get pods
kubectl -n longhorn-system get volumes.longhorn.io
```

### Pre v1.10 Migration
```bash
# Verify no v1beta1 resources
kubectl get --raw="/apis/longhorn.io/v1beta1" 2>&1 | grep -q "not found" && echo "OK: No v1beta1"
```

---

## Phase 3: Observability (via OpenTofu)

### cert-manager
```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Update CRDs first (manual step)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.crds.yaml

# Update chart_version in module call then:
tofu plan -target=module.cert_manager
tofu apply -target=module.cert_manager
```

### kube-prometheus-stack
```bash
# Backup Grafana dashboards first!
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80 &
# Export dashboards via Grafana UI

# Update local.prometheus_stack_version in monitoring.tf then:
tofu plan -target=helm_release.kube_prometheus_stack
tofu apply -target=helm_release.kube_prometheus_stack
```

---

## Phase 4: Ingress & GitOps (via OpenTofu)

### Traefik
```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Update chart_version in module call then:
tofu plan -target=module.traefik
tofu apply -target=module.traefik
```

### ArgoCD (v2 → v3)
```bash
# Update argocd_chart_version in module call then:
tofu plan -target=module.argocd
tofu apply -target=module.argocd

# Note: Large CRDs may require manual server-side apply:
# kubectl apply -n argocd --server-side --force-conflicts \
#   -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.2/manifests/install.yaml
```

### MetalLB
```bash
# Update chart_version in metallb.tf then:
tofu plan -target=module.metallb
tofu apply -target=module.metallb
```

---

## Phase 5: Applications

### Pin "latest" Tags in OpenTofu

Update modules to use specific versions:

| Component | File | Change |
|-----------|------|--------|
| pihole | `terraform/modules/pihole/main.tf` | `image = "pihole/pihole:2025.11.1"` |
| homepage | `terraform/modules/homepage/main.tf` | `image = "ghcr.io/gethomepage/homepage:v1.8.0"` |
| nexus | - | `image = "sonatype/nexus3:3.87.1"` |

```bash
# Apply changes
cd terraform/environments/chocolandiadc-mvp
tofu plan
tofu apply
```

---

## Rollback Procedures

### OpenTofu Rollback (PREFERRED)
```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Revert chart_version in the module to previous value
# Then apply:
tofu plan -target=module.<module_name>
tofu apply -target=module.<module_name>
```

### K3s Rollback
```bash
# Reinstall previous version
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.28.3+k3s1" sh -
```

### Helm Rollback (if OpenTofu not possible)
```bash
# List revisions
helm history <release-name> -n <namespace>

# Rollback to previous
helm rollback <release-name> <revision> -n <namespace>

# WARNING: Helm rollback may cause state drift with OpenTofu!
# Run 'tofu refresh' after manual helm rollback
```

### Ubuntu Kernel Rollback
```bash
# On boot, select "Advanced options for Ubuntu" in GRUB
# Choose previous kernel version
```

---

## Validation Commands

```bash
# Cluster health
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running

# Component versions
kubectl version
helm list -A

# Longhorn health
kubectl -n longhorn-system get volumes.longhorn.io

# ArgoCD health
kubectl -n argocd get apps

# Prometheus health
kubectl -n monitoring get prometheuses
kubectl -n monitoring get pods
```
