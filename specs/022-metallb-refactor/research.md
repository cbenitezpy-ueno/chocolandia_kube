# Research: MetalLB Module Refactor

**Feature**: 022-metallb-refactor
**Date**: 2025-12-27
**Status**: Complete

## Executive Summary

This research evaluates approaches for refactoring the MetalLB module from `null_resource` with provisioners to declarative Kubernetes resources. The goal is achieving proper `tofu plan` visibility, automatic state tracking, and clean `tofu destroy` behavior.

---

## Decision 1: Resource Type for CRD Management

### Decision
Use `kubernetes_manifest` from the hashicorp/kubernetes provider (~> 2.23) for IPAddressPool and L2Advertisement resources.

### Rationale
1. **Native Terraform state management**: Full resource definition tracked in state
2. **Accurate `tofu plan`**: Shows exact changes to manifests (addresses, names, etc.)
3. **Automatic cleanup**: `tofu destroy` deletes resources via Kubernetes API
4. **No external dependencies**: Doesn't require kubectl binary at runtime
5. **Drift detection**: Detects manual changes via `tofu plan`
6. **Existing pattern**: Already used in local-ca and alerting-rules modules

### Alternatives Considered

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **kubernetes_manifest** | Native state, full plan visibility, auto-cleanup | Requires CRDs to exist at plan-time | **SELECTED** |
| **kubectl_manifest (gavinbunney)** | YAML syntax, ignores computed fields | Third-party provider, less ecosystem support | Rejected |
| **null_resource + provisioners** | Works before CRDs exist | No state tracking, no plan visibility, manual cleanup | Current (to replace) |
| **terraform_data** | Modern replacement for null_resource | Same limitations as null_resource | Rejected |

---

## Decision 2: CRD Wait Mechanism

### Decision
Use `time_sleep` resource from hashicorp/time provider with configurable duration, combined with `depends_on` chain.

### Rationale
1. **Simplicity**: No shell scripts or external commands needed
2. **Declarative**: Pure Terraform resource (no provisioners)
3. **Configurable**: Duration exposed as variable for different environments
4. **Sufficient for MetalLB**: CRDs typically available 2-5 seconds after Helm completes
5. **Predictable**: Always waits same duration (good for CI/CD)

### Alternatives Considered

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **time_sleep** | Simple, declarative, no kubectl | Fixed wait (may over-wait) | **SELECTED** |
| **kubectl wait loop** | Exits immediately when ready | Requires kubectl, shell complexity | Rejected |
| **CRD bootstrap manifest** | Verifies CRD exists | Complex, may conflict with Helm ownership | Rejected |
| **Exponential backoff script** | Optimal timing | Complex script, external dependency | Rejected |

### Configuration
```hcl
variable "crd_wait_duration" {
  description = "Duration to wait for CRDs after Helm release (e.g., '30s', '1m')"
  type        = string
  default     = "30s"
}
```

---

## Decision 3: Field Manager Configuration

### Decision
Use `server_side_apply = true` with `field_manager = "opentofu"` for all kubernetes_manifest resources.

### Rationale
1. **Conflict prevention**: Server-side apply prevents client-side merge conflicts
2. **Clear ownership**: Field manager identifies OpenTofu as the owner
3. **No force_conflicts**: Not needed since we're the primary manager
4. **Future-proof**: Standard practice for Terraform + Kubernetes

### Configuration
```hcl
resource "kubernetes_manifest" "example" {
  manifest = { ... }

  field_manager {
    name            = "opentofu"
    force_conflicts = false
  }
}
```

---

## Decision 4: Handling Computed Fields

### Decision
Not needed for MetalLB IPAddressPool and L2Advertisement - these CRDs don't have status fields that would cause drift.

### Rationale
1. MetalLB controller doesn't modify spec fields
2. No annotations are added by webhooks
3. Status subresource is separate and not tracked by Terraform
4. If drift occurs in future, can add `computed_fields` parameter

---

## Decision 5: Backward Compatibility

### Decision
Maintain existing variable interface exactly:
- `chart_version`
- `namespace`
- `pool_name`
- `ip_range`

### Rationale
1. No changes required to environment configuration (`metallb.tf`)
2. Outputs remain unchanged
3. Migration is transparent to module consumers
4. State migration not required (Terraform will create new resources)

---

## Decision 6: State Migration Strategy

### Decision
Use `tofu state rm` + fresh `tofu apply` rather than `tofu import`.

### Rationale
1. **null_resource has no corresponding Kubernetes state**: Cannot import
2. **Clean slate**: Fresh resources ensure consistency
3. **Existing resources preserved**: Kubernetes IPAddressPool/L2Advertisement persist
4. **Quick migration**: ~30 seconds downtime acceptable for homelab

### Migration Steps
1. `tofu state rm module.metallb.null_resource.wait_for_crds`
2. `tofu state rm module.metallb.null_resource.ip_address_pool`
3. Apply new module code
4. Verify LoadBalancer services retain IPs

---

## Technical Specifications

### MetalLB CRD Manifest Structure

**IPAddressPool (metallb.io/v1beta1)**:
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: eero-pool
  namespace: metallb-system
  labels:
    app.kubernetes.io/name: metallb
    app.kubernetes.io/managed-by: opentofu
spec:
  addresses:
    - "192.168.4.200-192.168.4.210"  # Range format
  autoAssign: true
```

**L2Advertisement (metallb.io/v1beta1)**:
```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: eero-pool-l2
  namespace: metallb-system
  labels:
    app.kubernetes.io/name: metallb
    app.kubernetes.io/managed-by: opentofu
spec:
  ipAddressPools:
    - eero-pool
```

### Provider Requirements

```hcl
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}
```

### Timing Expectations

| Scenario | Helm Release | CRD Available | Wait Time |
|----------|--------------|---------------|-----------|
| Fast (low load) | ~15s | ~17-20s | 2-5s |
| Normal | ~20s | ~25-30s | 5-10s |
| Slow (high load) | ~30s | ~40-45s | 10-15s |

**Recommendation**: 30-second default wait is safe for all scenarios.

---

## Known Issues and Mitigations

### Issue 1: Plan-Time CRD Validation
**Problem**: `kubernetes_manifest` validates CRD schema at plan-time. If CRDs don't exist, plan fails.

**Mitigation**:
- Helm release with `wait = true` ensures CRDs exist before plan
- For fresh clusters: `tofu apply -target=module.metallb.helm_release.metallb` first

### Issue 2: Webhook Validation Timeout
**Problem**: MetalLB admission webhook may timeout if not ready.

**Mitigation**:
- `time_sleep` provides sufficient delay for webhook readiness
- Helm `wait = true` ensures webhook pod is ready

### Issue 3: Terraform State Drift
**Problem**: Manual kubectl changes cause state drift.

**Mitigation**:
- Labels identify OpenTofu-managed resources
- `tofu plan` detects drift and shows reconciliation

---

## References

1. [Terraform kubernetes_manifest Documentation](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest)
2. [MetalLB Configuration Reference](https://metallb.universe.tf/configuration/)
3. [HashiCorp Blog: CRD Support in Kubernetes Provider](https://www.hashicorp.com/blog/beta-support-for-crds-in-the-terraform-provider-for-kubernetes)
4. [time_sleep Resource Documentation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep)
5. [Server-Side Apply in Kubernetes](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
