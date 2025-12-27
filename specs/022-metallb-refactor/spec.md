# Feature Specification: MetalLB Module Refactor - Declarative Resources

**Feature Branch**: `022-metallb-refactor`
**Created**: 2025-12-27
**Status**: Draft
**Input**: GitHub Issue #23 - refactor: MetalLB module - use declarative Kubernetes resources

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Predictable Infrastructure Plan (Priority: P1)

As a platform engineer, I want to see accurate changes in `tofu plan` output so that I can review and approve MetalLB configuration changes before applying them.

**Why this priority**: The core value of Infrastructure as Code is predictable, reviewable changes. Without accurate plan output, engineers cannot safely approve changes, leading to potential production incidents.

**Independent Test**: Can be fully tested by running `tofu plan` after modifying MetalLB variables and verifying that the planned changes accurately reflect what will happen to the IP pool and L2 advertisement resources.

**Acceptance Scenarios**:

1. **Given** an existing MetalLB deployment with IP pool 192.168.4.200-210, **When** I modify the IP range variable to 192.168.4.200-220 and run `tofu plan`, **Then** the plan shows the IPAddressPool will be updated with the new range.

2. **Given** an existing MetalLB deployment, **When** I change the pool name variable and run `tofu plan`, **Then** the plan shows the old pool being destroyed and a new one being created.

3. **Given** a fresh cluster without MetalLB, **When** I run `tofu plan`, **Then** the plan shows creation of helm_release, IPAddressPool, and L2Advertisement resources with accurate resource counts.

---

### User Story 2 - Clean Resource Destruction (Priority: P1)

As a platform engineer, I want `tofu destroy` to completely remove all MetalLB resources so that I can cleanly tear down environments without orphaned resources.

**Why this priority**: Orphaned resources cause confusion, potential IP conflicts, and make environment recreation unreliable. This is equally critical as P1 because incomplete cleanup blocks environment management workflows.

**Independent Test**: Can be fully tested by running `tofu destroy` on an existing MetalLB deployment and verifying all resources (Helm release, CRDs, IPAddressPool, L2Advertisement) are removed from the cluster.

**Acceptance Scenarios**:

1. **Given** a fully deployed MetalLB with IPAddressPool and L2Advertisement, **When** I run `tofu destroy`, **Then** all MetalLB resources are removed from the cluster without manual intervention.

2. **Given** a partially deployed MetalLB (e.g., Helm release succeeded but CRDs failed), **When** I run `tofu destroy`, **Then** the available resources are cleaned up and the state is cleared.

---

### User Story 3 - State Drift Detection (Priority: P2)

As a platform engineer, I want Terraform state to accurately reflect the actual cluster resources so that I can detect and reconcile configuration drift.

**Why this priority**: Drift detection enables GitOps workflows and prevents "works on my machine" scenarios. Important for operational stability but not blocking for basic functionality.

**Independent Test**: Can be fully tested by manually modifying an IPAddressPool in the cluster, then running `tofu plan` to verify it detects the drift.

**Acceptance Scenarios**:

1. **Given** a MetalLB deployment managed by Terraform, **When** someone manually edits the IPAddressPool via kubectl, **Then** the next `tofu plan` shows the drift and proposes to restore the expected state.

2. **Given** a MetalLB deployment where the L2Advertisement was manually deleted, **When** I run `tofu plan`, **Then** the plan shows the L2Advertisement will be recreated.

---

### User Story 4 - Reliable CRD Initialization (Priority: P2)

As a platform engineer, I want the module to reliably wait for MetalLB CRDs to be available before creating custom resources so that initial deployments succeed consistently.

**Why this priority**: Race conditions during initial deployment cause frustrating failures that require manual intervention. Important for operational reliability but can be worked around with retries.

**Independent Test**: Can be fully tested by deploying MetalLB to a fresh cluster and verifying IPAddressPool creation succeeds on the first `tofu apply` without timing errors.

**Acceptance Scenarios**:

1. **Given** a fresh cluster without MetalLB, **When** I run `tofu apply`, **Then** the module waits for CRDs to be registered before attempting to create IPAddressPool and L2Advertisement.

2. **Given** a slow cluster where CRD registration takes 45 seconds, **When** I run `tofu apply`, **Then** the deployment succeeds without timing out (within configurable timeout).

---

### Edge Cases

- What happens when MetalLB Helm chart is deleted externally while IPAddressPool still exists?
- How does the system handle CRD registration timeout (cluster overloaded)?
- What happens when attempting to create duplicate IPAddressPool names?
- How does destroy behave if the Kubernetes cluster is unreachable?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Module MUST use native Terraform/OpenTofu resources (`kubernetes_manifest`) instead of `null_resource` with provisioners for IPAddressPool and L2Advertisement.

- **FR-002**: Module MUST implement a declarative wait mechanism (e.g., `time_sleep` or equivalent) for CRD availability instead of shell script loops.

- **FR-003**: `tofu plan` MUST accurately show planned changes to IPAddressPool and L2Advertisement resources.

- **FR-004**: `tofu destroy` MUST cleanly remove IPAddressPool and L2Advertisement resources without requiring manual kubectl commands.

- **FR-005**: Terraform state MUST track the actual state of IPAddressPool and L2Advertisement resources for drift detection.

- **FR-006**: Module MUST maintain backward compatibility with existing variable interface (pool_name, ip_range, namespace, chart_version).

- **FR-007**: Module MUST continue to support L2 advertisement mode for bare-metal LoadBalancer services.

- **FR-008**: Module MUST use `field_manager` configuration to handle potential conflicts with other controllers.

### Key Entities

- **IPAddressPool**: MetalLB custom resource defining the IP address range available for LoadBalancer services. Key attributes: name, namespace, addresses (list of CIDR or range).

- **L2Advertisement**: MetalLB custom resource enabling Layer 2 mode for IP announcement. Key attributes: name, namespace, ipAddressPools (reference to pool names).

- **Helm Release**: Terraform-managed deployment of MetalLB controller and speaker components.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Platform engineers can review and approve MetalLB changes via `tofu plan` output with 100% accuracy (no hidden changes via provisioners).

- **SC-002**: Fresh MetalLB deployments succeed on first `tofu apply` attempt without CRD timing errors (transient cluster issues like network timeouts are excluded from this criterion).

- **SC-003**: `tofu destroy` removes all MetalLB resources (Helm release + CRs) without manual intervention in 100% of cases when cluster is reachable.

- **SC-004**: Configuration drift is detected within one `tofu plan` execution after manual cluster modifications.

- **SC-005**: Existing services using MetalLB LoadBalancer IPs continue functioning without interruption during the module refactor (zero downtime migration).

- **SC-006**: Module maintains current functionality: LoadBalancer services receive IPs from the configured range within 30 seconds of creation.

## Assumptions

- The Kubernetes cluster is accessible from where OpenTofu runs (same kubeconfig as current implementation).
- MetalLB Helm chart version supports the `metallb.io/v1beta1` API version for IPAddressPool and L2Advertisement.
- The `time_sleep` resource (hashicorp/time provider) is acceptable for CRD wait mechanism; 30 seconds default wait time is sufficient for typical clusters.
- The refactor will be applied during a maintenance window where brief MetalLB unavailability is acceptable (for destroy/apply scenarios).
- Existing LoadBalancer services will retain their IPs if the IPAddressPool configuration remains unchanged.

## Constraints

- Must not require changes to services currently using MetalLB LoadBalancer IPs.
- Must work with OpenTofu 1.6+ (current project standard).
- Must not introduce new external dependencies (kubectl, shell scripts) for core functionality.

## Dependencies

- hashicorp/kubernetes provider ~> 2.23 (already in project)
- hashicorp/helm provider ~> 2.11 (already in project)
- hashicorp/time provider (may need to be added for `time_sleep` resource)
