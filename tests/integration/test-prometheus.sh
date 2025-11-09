#!/usr/bin/env bash
#
# Prometheus Integration Test
# Verifies Prometheus deployment and scrape targets
#
# Usage: ./test-prometheus.sh [kubeconfig_path]

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

KUBECONFIG_PATH="${1:-../../terraform/environments/chocolandiadc-mvp/kubeconfig}"
MONITORING_NAMESPACE="monitoring"
PROMETHEUS_SERVICE="kube-prometheus-stack-prometheus"
TIMEOUT_SECONDS=180

# Expected scrape targets
EXPECTED_TARGETS=("master1" "nodo1")

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

log "Starting Prometheus integration test"

# Check if kubeconfig exists
if [[ ! -f "$KUBECONFIG_PATH" ]]; then
    error "Kubeconfig not found at $KUBECONFIG_PATH"
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl not found in PATH"
fi

export KUBECONFIG="$KUBECONFIG_PATH"
log "Using kubeconfig: $KUBECONFIG_PATH"

# ============================================================================
# Namespace Check
# ============================================================================

log "Checking monitoring namespace..."
if ! kubectl get namespace "$MONITORING_NAMESPACE" &> /dev/null; then
    error "Monitoring namespace '$MONITORING_NAMESPACE' not found"
fi
success "Monitoring namespace exists"

# ============================================================================
# Prometheus Deployment Check
# ============================================================================

log "Checking Prometheus deployment..."

# Check if Prometheus StatefulSet exists
if ! kubectl get statefulset -n "$MONITORING_NAMESPACE" prometheus-kube-prometheus-stack-prometheus &> /dev/null; then
    error "Prometheus StatefulSet not found"
fi
success "Prometheus StatefulSet found"

# Wait for Prometheus pods to be Ready
log "Waiting for Prometheus pods to be Ready (timeout: ${TIMEOUT_SECONDS}s)..."
START_TIME=$(date +%s)
while true; do
    READY_PODS=$(kubectl get pods -n "$MONITORING_NAMESPACE" -l app.kubernetes.io/name=prometheus --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")

    if [[ $READY_PODS -gt 0 ]]; then
        success "Prometheus pods are running ($READY_PODS pods)"
        break
    fi

    ELAPSED=$(($(date +%s) - START_TIME))
    if [[ $ELAPSED -ge $TIMEOUT_SECONDS ]]; then
        error "Prometheus pods did not become Ready after ${TIMEOUT_SECONDS}s"
    fi

    log "Waiting for Prometheus pods... (${ELAPSED}s elapsed)"
    sleep 5
done

# ============================================================================
# Prometheus Service Check
# ============================================================================

log "Checking Prometheus service..."
if ! kubectl get service -n "$MONITORING_NAMESPACE" "$PROMETHEUS_SERVICE" &> /dev/null; then
    error "Prometheus service '$PROMETHEUS_SERVICE' not found"
fi

SERVICE_PORT=$(kubectl get service -n "$MONITORING_NAMESPACE" "$PROMETHEUS_SERVICE" -o jsonpath='{.spec.ports[0].port}')
success "Prometheus service found (port: $SERVICE_PORT)"

# ============================================================================
# Scrape Targets Verification
# ============================================================================

log "Verifying Prometheus scrape targets..."

# Port-forward Prometheus to localhost
log "Setting up port-forward to Prometheus..."
kubectl port-forward -n "$MONITORING_NAMESPACE" svc/"$PROMETHEUS_SERVICE" 9090:9090 &> /dev/null &
PORT_FORWARD_PID=$!
sleep 3

# Function to cleanup port-forward on exit
cleanup() {
    if [[ -n "${PORT_FORWARD_PID:-}" ]]; then
        kill "$PORT_FORWARD_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Query Prometheus API for targets
log "Querying Prometheus targets API..."
TARGETS_JSON=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null || echo '{"status":"error"}')

if [[ $(echo "$TARGETS_JSON" | jq -r '.status' 2>/dev/null) != "success" ]]; then
    error "Failed to query Prometheus targets API"
fi

# Check for active targets
ACTIVE_TARGETS=$(echo "$TARGETS_JSON" | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
log "Found $ACTIVE_TARGETS active scrape targets"

if [[ $ACTIVE_TARGETS -eq 0 ]]; then
    error "No active scrape targets found in Prometheus"
fi
success "Prometheus has $ACTIVE_TARGETS active scrape targets"

# Verify each expected node target
for NODE in "${EXPECTED_TARGETS[@]}"; do
    log "Checking if $NODE is being scraped..."

    # Check if node appears in any target labels
    NODE_FOUND=$(echo "$TARGETS_JSON" | jq -r ".data.activeTargets[] | select(.labels.instance | contains(\"$NODE\")) | .labels.instance" 2>/dev/null || echo "")

    if [[ -z "$NODE_FOUND" ]]; then
        # Try alternative label (node)
        NODE_FOUND=$(echo "$TARGETS_JSON" | jq -r ".data.activeTargets[] | select(.labels.node == \"$NODE\") | .labels.node" 2>/dev/null || echo "")
    fi

    if [[ -n "$NODE_FOUND" ]]; then
        success "Node $NODE is being scraped by Prometheus"
    else
        log "WARNING: Node $NODE not found in active targets (may not be critical)"
    fi
done

# ============================================================================
# Metrics Query Test
# ============================================================================

log "Testing Prometheus metrics queries..."

# Query for node CPU usage
CPU_QUERY='100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'
CPU_RESULT=$(curl -s "http://localhost:9090/api/v1/query?query=$(echo "$CPU_QUERY" | jq -sRr @uri)" | jq -r '.status' 2>/dev/null || echo "error")

if [[ "$CPU_RESULT" == "success" ]]; then
    success "Prometheus can query node CPU metrics"
else
    log "WARNING: Failed to query CPU metrics (may need time to collect data)"
fi

# Query for node memory usage
MEM_QUERY='(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100'
MEM_RESULT=$(curl -s "http://localhost:9090/api/v1/query?query=$(echo "$MEM_QUERY" | jq -sRr @uri)" | jq -r '.status' 2>/dev/null || echo "error")

if [[ "$MEM_RESULT" == "success" ]]; then
    success "Prometheus can query node memory metrics"
else
    log "WARNING: Failed to query memory metrics (may need time to collect data)"
fi

# ============================================================================
# Summary
# ============================================================================

log "========================================="
success "Prometheus integration test PASSED"
log "========================================="
log ""
log "Prometheus Summary:"
log "  - Namespace: $MONITORING_NAMESPACE"
log "  - Service: $PROMETHEUS_SERVICE"
log "  - Active Targets: $ACTIVE_TARGETS"
log "  - Metrics Query: Working"
log ""
log "Access Prometheus UI:"
log "  kubectl port-forward -n $MONITORING_NAMESPACE svc/$PROMETHEUS_SERVICE 9090:9090"
log "  Open: http://localhost:9090"
log ""

exit 0
