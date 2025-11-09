#!/usr/bin/env bash
#
# Validate Single Node (master1) K3s Cluster
# Verifies that the control-plane node is Ready and API is accessible
#
# Usage: ./validate-single-node.sh [kubeconfig_path]

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

KUBECONFIG_PATH="${1:-./kubeconfig}"
MASTER_HOSTNAME="master1"
TIMEOUT_SECONDS=60

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

log "Starting single-node validation for $MASTER_HOSTNAME"

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
# Node Status Check
# ============================================================================

log "Checking $MASTER_HOSTNAME node status..."

# Wait for node to be Ready
START_TIME=$(date +%s)
while true; do
    NODE_STATUS=$(kubectl get nodes "$MASTER_HOSTNAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")

    if [[ "$NODE_STATUS" == "True" ]]; then
        success "Node $MASTER_HOSTNAME is Ready"
        break
    fi

    ELAPSED=$(($(date +%s) - START_TIME))
    if [[ $ELAPSED -ge $TIMEOUT_SECONDS ]]; then
        error "Node $MASTER_HOSTNAME did not become Ready after ${TIMEOUT_SECONDS}s (status: $NODE_STATUS)"
    fi

    log "Waiting for node to be Ready... (${ELAPSED}s elapsed)"
    sleep 5
done

# ============================================================================
# Node Details
# ============================================================================

log "Retrieving node details..."
kubectl get nodes "$MASTER_HOSTNAME" -o wide

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

# Display pod status
log "Kube-system pod status:"
kubectl get pods -n kube-system

# ============================================================================
# API Resources Check
# ============================================================================

log "Verifying API resources are available..."
if ! kubectl api-resources &> /dev/null; then
    error "Failed to retrieve API resources"
fi
success "API resources are available"

# ============================================================================
# Summary
# ============================================================================

log "========================================="
success "Single-node validation PASSED"
log "========================================="
log ""
log "Cluster Summary:"
kubectl cluster-info
log ""
log "Node Status:"
kubectl get nodes
log ""
log "System Pods:"
kubectl get pods -n kube-system -o wide

exit 0
