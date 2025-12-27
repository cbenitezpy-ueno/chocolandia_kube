# Quickstart: MetalLB Module Refactor

**Feature**: 022-metallb-refactor
**Date**: 2025-12-27

## Overview

This guide covers how to migrate the MetalLB module from `null_resource` with provisioners to declarative `kubernetes_manifest` resources.

---

## Prerequisites

1. OpenTofu 1.6+ installed
2. kubectl configured with cluster access
3. Existing MetalLB deployment (Helm chart 0.15.3)
4. Current services using LoadBalancer IPs

---

## Migration Steps

### Step 1: Verify Current State

```bash
# Check current LoadBalancer services
kubectl get svc -A -o wide | grep LoadBalancer

# Verify MetalLB resources exist
kubectl get ipaddresspools,l2advertisements -n metallb-system

# Check Terraform state
cd terraform/environments/chocolandiadc-mvp
tofu state list | grep metallb
```

**Expected output**:
```
module.metallb.helm_release.metallb
module.metallb.null_resource.wait_for_crds
module.metallb.null_resource.ip_address_pool
```

### Step 2: Remove Old State Entries

```bash
# Remove null_resource entries (keeps Kubernetes resources)
tofu state rm module.metallb.null_resource.wait_for_crds
tofu state rm module.metallb.null_resource.ip_address_pool
```

### Step 3: Apply New Module

```bash
# Plan to see new resources
tofu plan

# Expected:
# + kubernetes_manifest.ip_address_pool
# + kubernetes_manifest.l2_advertisement
# + time_sleep.wait_for_crds

# Apply changes
tofu apply
```

### Step 4: Verify Migration

```bash
# Verify state now has kubernetes_manifest
tofu state list | grep metallb

# Expected:
# module.metallb.helm_release.metallb
# module.metallb.time_sleep.wait_for_crds
# module.metallb.kubernetes_manifest.ip_address_pool
# module.metallb.kubernetes_manifest.l2_advertisement

# Verify Kubernetes resources unchanged
kubectl get ipaddresspools,l2advertisements -n metallb-system

# Verify services still have IPs
kubectl get svc -A | grep LoadBalancer
```

---

## Testing Refactored Module

### Test 1: Plan Visibility

```bash
# Modify IP range temporarily in metallb.tf
# ip_range = "192.168.4.200-192.168.4.215"

tofu plan

# Should show:
# ~ kubernetes_manifest.ip_address_pool
#   ~ manifest.spec.addresses = ["192.168.4.200-192.168.4.210"] -> ["192.168.4.200-192.168.4.215"]
```

### Test 2: Drift Detection

```bash
# Manually edit IPAddressPool
kubectl patch ipaddresspool eero-pool -n metallb-system \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/addresses/0", "value": "192.168.4.200-192.168.4.220"}]'

# Run plan - should detect drift
tofu plan

# Should show:
# ~ kubernetes_manifest.ip_address_pool
#   ~ manifest.spec.addresses = ["192.168.4.200-192.168.4.220"] -> ["192.168.4.200-192.168.4.210"]

# Restore correct state
tofu apply
```

### Test 3: Clean Destroy (Use with caution!)

```bash
# Only in test environment!
# This will remove MetalLB and break LoadBalancer services

tofu destroy -target=module.metallb

# Verify cleanup
kubectl get ipaddresspools,l2advertisements -n metallb-system
# Should show: No resources found

# Re-apply
tofu apply
```

---

## Rollback Procedure

If migration fails:

### Option 1: Restore from Git

```bash
# Checkout previous module version
git checkout HEAD~1 -- terraform/modules/metallb/

# Re-apply old version
tofu apply
```

### Option 2: Manual kubectl Restore

```bash
# If Terraform state is corrupted, restore manually
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: eero-pool
  namespace: metallb-system
spec:
  addresses:
    - "192.168.4.200-192.168.4.210"
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: eero-pool-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - eero-pool
EOF
```

---

## Common Issues

### Issue: "no matches for kind IPAddressPool"

**Cause**: CRDs not registered yet at plan-time.

**Solution**:
```bash
# Apply Helm release first
tofu apply -target=module.metallb.helm_release.metallb

# Then full apply
tofu apply
```

### Issue: "field is immutable"

**Cause**: Trying to change immutable field (e.g., metadata.name).

**Solution**: Destroy and recreate the resource:
```bash
tofu apply -replace=module.metallb.kubernetes_manifest.ip_address_pool
```

### Issue: Services lose LoadBalancer IPs

**Cause**: IPAddressPool was deleted.

**Solution**:
```bash
# Immediately re-apply
tofu apply

# Services should re-acquire IPs (may get different IPs if not using annotations)
```

---

## Validation Commands

```bash
# Full health check
echo "=== Terraform State ==="
tofu state list | grep metallb

echo "=== Kubernetes Resources ==="
kubectl get ipaddresspools,l2advertisements -n metallb-system

echo "=== LoadBalancer Services ==="
kubectl get svc -A -o wide | grep LoadBalancer

echo "=== MetalLB Pods ==="
kubectl get pods -n metallb-system

echo "=== IP Assignments ==="
kubectl get svc -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}/{.metadata.name}: {.status.loadBalancer.ingress[0].ip}{"\n"}{end}'
```

---

## Expected Final State

After successful migration:

| Resource | Type | Status |
|----------|------|--------|
| `helm_release.metallb` | Helm | Unchanged |
| `time_sleep.wait_for_crds` | Time | New |
| `kubernetes_manifest.ip_address_pool` | K8s | New (manages existing) |
| `kubernetes_manifest.l2_advertisement` | K8s | New (manages existing) |
| `null_resource.wait_for_crds` | Null | Removed |
| `null_resource.ip_address_pool` | Null | Removed |

**Service Impact**: Zero - LoadBalancer services retain their IPs throughout migration.
