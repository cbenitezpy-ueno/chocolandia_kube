# Data Model: MetalLB Module Refactor

**Feature**: 022-metallb-refactor
**Date**: 2025-12-27

## Overview

This feature involves Kubernetes Custom Resource Definitions (CRDs) managed by MetalLB. The data model describes the Kubernetes resources that OpenTofu will manage declaratively.

---

## Entities

### 1. IPAddressPool

**Purpose**: Defines a pool of IP addresses available for LoadBalancer services.

**API Version**: `metallb.io/v1beta1`

**Kind**: `IPAddressPool`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `metadata.name` | string | Yes | Unique name for the pool (e.g., "eero-pool") |
| `metadata.namespace` | string | Yes | Must be MetalLB namespace (metallb-system) |
| `metadata.labels` | map[string]string | No | Labels for resource identification |
| `spec.addresses` | []string | Yes | List of IP ranges or CIDRs |
| `spec.autoAssign` | bool | No | Auto-assign IPs to services (default: true) |
| `spec.avoidBuggyIPs` | bool | No | Avoid .0 and .255 addresses (default: false) |

**Validation Rules**:
- `spec.addresses` must be valid IP ranges (e.g., "192.168.4.200-192.168.4.210") or CIDRs
- IP ranges must not overlap with other IPAddressPools
- Namespace must match MetalLB deployment namespace

**Example**:
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
    - "192.168.4.200-192.168.4.210"
  autoAssign: true
```

---

### 2. L2Advertisement

**Purpose**: Configures Layer 2 mode advertisement for IP addresses from specified pools.

**API Version**: `metallb.io/v1beta1`

**Kind**: `L2Advertisement`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `metadata.name` | string | Yes | Unique name (e.g., "eero-pool-l2") |
| `metadata.namespace` | string | Yes | Must be MetalLB namespace |
| `metadata.labels` | map[string]string | No | Labels for resource identification |
| `spec.ipAddressPools` | []string | No | Pools to advertise (empty = all pools) |
| `spec.nodeSelectors` | []LabelSelector | No | Limit to specific nodes |
| `spec.interfaces` | []string | No | Limit to specific network interfaces |

**Validation Rules**:
- Referenced `ipAddressPools` must exist
- Namespace must match MetalLB deployment namespace
- If `ipAddressPools` is empty, advertises ALL pools (usually undesired)

**Example**:
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

---

### 3. Helm Release (Terraform Resource)

**Purpose**: Manages MetalLB controller and speaker deployment.

**Terraform Resource**: `helm_release`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Release name ("metallb") |
| `repository` | string | Yes | Helm chart repository URL |
| `chart` | string | Yes | Chart name ("metallb") |
| `version` | string | Yes | Chart version (e.g., "0.15.3") |
| `namespace` | string | Yes | Target namespace |
| `create_namespace` | bool | No | Create namespace if missing |
| `wait` | bool | No | Wait for resources to be ready |
| `timeout` | number | No | Timeout in seconds |

---

### 4. Time Sleep (Terraform Resource)

**Purpose**: Declarative wait for CRD availability after Helm release.

**Terraform Resource**: `time_sleep`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `create_duration` | string | Yes | Wait duration (e.g., "30s") |
| `depends_on` | list | No | Dependencies (helm_release) |
| `triggers` | map | No | Values that trigger recreation |

---

## Relationships

```
┌─────────────────┐
│  helm_release   │
│    (metallb)    │
└────────┬────────┘
         │ creates CRDs
         ▼
┌─────────────────┐
│   time_sleep    │
│ (wait for CRDs) │
└────────┬────────┘
         │ depends_on
         ▼
┌─────────────────┐      references      ┌─────────────────┐
│  IPAddressPool  │◄─────────────────────│ L2Advertisement │
│   (eero-pool)   │                      │  (eero-pool-l2) │
└────────┬────────┘                      └─────────────────┘
         │ allocates IPs
         ▼
┌─────────────────┐
│    Services     │
│ (LoadBalancer)  │
└─────────────────┘
```

---

## State Transitions

### IPAddressPool Lifecycle

```
[Not Exists] ──tofu apply──► [Created] ──tofu apply (changed)──► [Updated]
                                │                                    │
                                │                                    │
                                ▼                                    ▼
                         [kubectl edit]                        [Drift Detected]
                                │                                    │
                                ▼                                    │
                         [Drift Detected] ◄──────────────────────────┘
                                │
                                ▼
                         tofu apply ──► [Reconciled]
                                │
                                ▼
                         tofu destroy ──► [Deleted]
```

### Service IP Assignment

```
[Service Created] ──type: LoadBalancer──► [Pending External IP]
                                                    │
                                                    ▼
                                          [MetalLB Controller]
                                                    │
                                                    ▼
                                      [IP Assigned from Pool]
                                                    │
                                                    ▼
                                          [L2 Advertisement]
                                                    │
                                                    ▼
                                          [ARP Announcement]
                                                    │
                                                    ▼
                                          [Traffic Routable]
```

---

## Terraform State Structure

```
module.metallb
├── helm_release.metallb
│   ├── name = "metallb"
│   ├── version = "0.15.3"
│   └── namespace = "metallb-system"
│
├── time_sleep.wait_for_crds
│   └── create_duration = "30s"
│
├── kubernetes_manifest.ip_address_pool
│   └── manifest
│       ├── apiVersion = "metallb.io/v1beta1"
│       ├── kind = "IPAddressPool"
│       └── spec.addresses = ["192.168.4.200-192.168.4.210"]
│
└── kubernetes_manifest.l2_advertisement
    └── manifest
        ├── apiVersion = "metallb.io/v1beta1"
        ├── kind = "L2Advertisement"
        └── spec.ipAddressPools = ["eero-pool"]
```

---

## Variables Interface

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `chart_version` | string | "0.15.3" | MetalLB Helm chart version |
| `namespace` | string | "metallb-system" | Kubernetes namespace |
| `pool_name` | string | "eero-pool" | Name of IP address pool |
| `ip_range` | string | (required) | IP range (e.g., "192.168.4.200-192.168.4.210") |
| `crd_wait_duration` | string | "30s" | Time to wait for CRDs after Helm |

---

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `namespace` | string | Deployed namespace |
| `chart_version` | string | Deployed chart version |
| `ip_range` | string | Configured IP range |
| `pool_name` | string | IP pool name |
