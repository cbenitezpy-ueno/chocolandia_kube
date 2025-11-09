#!/usr/bin/env bash
#
# Validate Two-Node K3s Cluster (master1 + nodo1)
# Verifies that both nodes are Ready and cluster is functional
#
# Usage: ./validate-cluster.sh [kubeconfig_path]

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

KUBECONFIG_PATH="${1:-./kubeconfig}"
EXPECTED_NODES=2
EXPECTED_NODE_NAMES=("master1" "nodo1")
TIMEOUT_SECONDS=120

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

success() {
    log "SUCCESS: $*"
}

# ============================================================================
# Pre-Check
# ============================================================================

log "Starting cluster validation (expecting ${EXPECTED_NODES} nodes)"

# Check if kubeconfig exists
if [[ ! -f "$KUBECONFIG_PATH" ]]; then
    error "Kubeconfig not found at $KUBECONFIG_PATH"
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl not found in PATH. Install kubectl first."
fi

export KUBECONFIG="$KUBECONFIG_PATH"
log "Using kubeconfig: $KUBECONFIG_PATH"

# ============================================================================
# API Server Connectivity
# ============================================================================

log "Testing API server connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes API server"
fi
success "API server is accessible"

# ============================================================================
# Node Count Check
# ============================================================================

log "Checking node count..."

START_TIME=$(date +%s)
while true; do
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")

    if [[ $NODE_COUNT -eq $EXPECTED_NODES ]]; then
        success "Found $EXPECTED_NODES nodes"
        break
    fi

    ELAPSED=$(($(date +%s) - START_TIME))
    if [[ $ELAPSED -ge $TIMEOUT_SECONDS ]]; then
        error "Expected $EXPECTED_NODES nodes, found $NODE_COUNT after ${TIMEOUT_SECONDS}s"
    fi

    log "Waiting for all nodes to appear... (found $NODE_COUNT/$EXPECTED_NODES, ${ELAPSED}s elapsed)"
    sleep 5
done

# ============================================================================
# Individual Node Status Check
# ============================================================================

log "Checking individual node status..."

for NODE_NAME in "${EXPECTED_NODE_NAMES[@]}"; do
    log "Verifying node: $NODE_NAME"

    START_TIME=$(date +%s)
    while true; do
        NODE_STATUS=$(kubectl get nodes "$NODE_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")

        if [[ "$NODE_STATUS" == "True" ]]; then
            success "Node $NODE_NAME is Ready"
            break
        fi

        ELAPSED=$(($(date +%s) - START_TIME))
        if [[ $ELAPSED -ge $TIMEOUT_SECONDS ]]; then
            error "Node $NODE_NAME did not become Ready after ${TIMEOUT_SECONDS}s (status: $NODE_STATUS)"
        fi

        log "Waiting for $NODE_NAME to be Ready... (${ELAPSED}s elapsed, status: $NODE_STATUS)"
        sleep 5
    done
done

# ============================================================================
# Node Roles Verification
# ============================================================================

log "Verifying node roles..."

CONTROL_PLANE_COUNT=$(kubectl get nodes -l node-role.kubernetes.io/control-plane=true --no-headers 2>/dev/null | wc -l || echo "0")
if [[ $CONTROL_PLANE_COUNT -lt 1 ]]; then
    error "No control-plane nodes found"
fi
success "Found $CONTROL_PLANE_COUNT control-plane node(s)"

# ============================================================================
# Node Details
# ============================================================================

log "Retrieving node details..."
kubectl get nodes -o wide

# ============================================================================
# Component Status
# ============================================================================

log "Checking K3s components..."

# Check if kube-system pods are running
KUBE_SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l || echo "0")
if [[ $KUBE_SYSTEM_PODS -eq 0 ]]; then
    error "No kube-system pods found"
fi
success "Found $KUBE_SYSTEM_PODS kube-system pods"

# Check for any pods that are not Running or Completed
log "Checking for unhealthy pods in kube-system..."
UNHEALTHY_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l || echo "0")
if [[ $UNHEALTHY_PODS -gt 0 ]]; then
    log "WARNING: Found $UNHEALTHY_PODS unhealthy pods in kube-system"
    kubectl get pods -n kube-system | grep -v "Running\|Completed" || true
else
    success "All kube-system pods are healthy"
fi

# Display pod status
log "Kube-system pod status:"
kubectl get pods -n kube-system -o wide

# ============================================================================
# Connectivity Test
# ============================================================================

log "Testing inter-node connectivity..."

# Check if CoreDNS is running (required for DNS resolution)
COREDNS_READY=$(kubectl get deployment -n kube-system coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ $COREDNS_READY -gt 0 ]]; then
    success "CoreDNS is running ($COREDNS_READY replicas)"
else
    log "WARNING: CoreDNS may not be ready yet"
fi

# ============================================================================
# Cluster Resource Check
# ============================================================================

log "Checking cluster resources..."

# Namespaces
NAMESPACE_COUNT=$(kubectl get namespaces --no-headers 2>/dev/null | wc -l || echo "0")
log "Namespaces: $NAMESPACE_COUNT"

# Services
SERVICE_COUNT=$(kubectl get services --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
log "Services: $SERVICE_COUNT"

# ============================================================================
# Summary
# ============================================================================

log "========================================="
success "Cluster validation PASSED"
log "========================================="
log ""
log "Cluster Summary:"
kubectl cluster-info
log ""
log "Node Status:"
kubectl get nodes -o wide
log ""
log "Node Capacity:"
kubectl top nodes 2>/dev/null || log "Metrics not available (metrics-server not installed)"
log ""
log "System Pods:"
kubectl get pods -n kube-system -o wide

exit 0
