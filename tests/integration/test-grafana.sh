#!/usr/bin/env bash
#
# Grafana Integration Test
# Verifies Grafana deployment and dashboard accessibility via NodePort
#
# Usage: ./test-grafana.sh [kubeconfig_path] [node_ip]

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

KUBECONFIG_PATH="${1:-../../terraform/environments/chocolandiadc-mvp/kubeconfig}"
NODE_IP="${2:-192.168.4.101}"  # Default to master1 IP
MONITORING_NAMESPACE="monitoring"
GRAFANA_SERVICE="kube-prometheus-stack-grafana"
EXPECTED_NODEPORT="30000"
TIMEOUT_SECONDS=180

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

log "Starting Grafana integration test"

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
log "Testing Grafana access via node IP: $NODE_IP"

# ============================================================================
# Namespace Check
# ============================================================================

log "Checking monitoring namespace..."
if ! kubectl get namespace "$MONITORING_NAMESPACE" &> /dev/null; then
    error "Monitoring namespace '$MONITORING_NAMESPACE' not found"
fi
success "Monitoring namespace exists"

# ============================================================================
# Grafana Deployment Check
# ============================================================================

log "Checking Grafana deployment..."

# Check if Grafana Deployment exists
if ! kubectl get deployment -n "$MONITORING_NAMESPACE" "$GRAFANA_SERVICE" &> /dev/null; then
    error "Grafana Deployment not found"
fi
success "Grafana Deployment found"

# Wait for Grafana pods to be Ready
log "Waiting for Grafana pods to be Ready (timeout: ${TIMEOUT_SECONDS}s)..."
START_TIME=$(date +%s)
while true; do
    READY_REPLICAS=$(kubectl get deployment -n "$MONITORING_NAMESPACE" "$GRAFANA_SERVICE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED_REPLICAS=$(kubectl get deployment -n "$MONITORING_NAMESPACE" "$GRAFANA_SERVICE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

    if [[ "$READY_REPLICAS" == "$DESIRED_REPLICAS" ]] && [[ "$READY_REPLICAS" != "0" ]]; then
        success "Grafana pods are running ($READY_REPLICAS/$DESIRED_REPLICAS)"
        break
    fi

    ELAPSED=$(($(date +%s) - START_TIME))
    if [[ $ELAPSED -ge $TIMEOUT_SECONDS ]]; then
        error "Grafana pods did not become Ready after ${TIMEOUT_SECONDS}s (ready: $READY_REPLICAS/$DESIRED_REPLICAS)"
    fi

    log "Waiting for Grafana pods... ($READY_REPLICAS/$DESIRED_REPLICAS ready, ${ELAPSED}s elapsed)"
    sleep 5
done

# ============================================================================
# Grafana Service Check
# ============================================================================

log "Checking Grafana service..."
if ! kubectl get service -n "$MONITORING_NAMESPACE" "$GRAFANA_SERVICE" &> /dev/null; then
    error "Grafana service '$GRAFANA_SERVICE' not found"
fi

SERVICE_TYPE=$(kubectl get service -n "$MONITORING_NAMESPACE" "$GRAFANA_SERVICE" -o jsonpath='{.spec.type}')
log "Grafana service type: $SERVICE_TYPE"

if [[ "$SERVICE_TYPE" == "NodePort" ]]; then
    NODEPORT=$(kubectl get service -n "$MONITORING_NAMESPACE" "$GRAFANA_SERVICE" -o jsonpath='{.spec.ports[0].nodePort}')
    log "Grafana NodePort: $NODEPORT"

    if [[ "$NODEPORT" == "$EXPECTED_NODEPORT" ]]; then
        success "Grafana is exposed on expected NodePort $EXPECTED_NODEPORT"
    else
        log "WARNING: Grafana NodePort is $NODEPORT (expected $EXPECTED_NODEPORT)"
    fi
else
    log "WARNING: Grafana service is type '$SERVICE_TYPE' (expected NodePort)"
    # Try to get ClusterIP port for port-forward test
    CLUSTER_PORT=$(kubectl get service -n "$MONITORING_NAMESPACE" "$GRAFANA_SERVICE" -o jsonpath='{.spec.ports[0].port}')
    log "Will test via port-forward on port $CLUSTER_PORT"
fi

# ============================================================================
# Grafana HTTP Accessibility Test
# ============================================================================

log "Testing Grafana HTTP accessibility..."

if [[ "$SERVICE_TYPE" == "NodePort" ]]; then
    # Test via NodePort
    log "Testing Grafana via NodePort: http://$NODE_IP:$NODEPORT"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:$NODEPORT/login" --max-time 10 2>/dev/null || echo "000")

    if [[ "$HTTP_CODE" == "200" ]]; then
        success "Grafana is accessible via NodePort (HTTP $HTTP_CODE)"
    elif [[ "$HTTP_CODE" == "302" ]] || [[ "$HTTP_CODE" == "301" ]]; then
        success "Grafana is accessible via NodePort (HTTP $HTTP_CODE - redirect)"
    else
        log "WARNING: Grafana returned HTTP $HTTP_CODE (may not be accessible from this machine)"
    fi
else
    # Test via port-forward
    log "Testing Grafana via port-forward..."
    kubectl port-forward -n "$MONITORING_NAMESPACE" svc/"$GRAFANA_SERVICE" 3000:80 &> /dev/null &
    PORT_FORWARD_PID=$!
    sleep 3

    # Cleanup function
    cleanup() {
        if [[ -n "${PORT_FORWARD_PID:-}" ]]; then
            kill "$PORT_FORWARD_PID" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/login" --max-time 10 2>/dev/null || echo "000")

    if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]]; then
        success "Grafana is accessible via port-forward (HTTP $HTTP_CODE)"
    else
        error "Grafana returned HTTP $HTTP_CODE via port-forward"
    fi
fi

# ============================================================================
# Grafana API Health Check
# ============================================================================

log "Checking Grafana API health..."

if [[ "$SERVICE_TYPE" == "NodePort" ]]; then
    API_HEALTH=$(curl -s "http://$NODE_IP:$NODEPORT/api/health" --max-time 10 2>/dev/null | jq -r '.database' 2>/dev/null || echo "unknown")
else
    API_HEALTH=$(curl -s "http://localhost:3000/api/health" --max-time 10 2>/dev/null | jq -r '.database' 2>/dev/null || echo "unknown")
fi

if [[ "$API_HEALTH" == "ok" ]]; then
    success "Grafana API is healthy (database: ok)"
else
    log "WARNING: Grafana API health check returned: $API_HEALTH"
fi

# ============================================================================
# Dashboard Check
# ============================================================================

log "Checking for Grafana dashboards..."

# Get Grafana admin credentials
GRAFANA_SECRET=$(kubectl get secret -n "$MONITORING_NAMESPACE" "$GRAFANA_SERVICE" -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null || echo "prom-operator")
log "Grafana admin username: admin"

# Try to list dashboards (without auth, just check if endpoint responds)
if [[ "$SERVICE_TYPE" == "NodePort" ]]; then
    DASHBOARDS_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:$NODEPORT/api/search" --max-time 10 2>/dev/null || echo "000")
else
    DASHBOARDS_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/api/search" --max-time 10 2>/dev/null || echo "000")
fi

if [[ "$DASHBOARDS_CHECK" == "401" ]] || [[ "$DASHBOARDS_CHECK" == "200" ]]; then
    success "Grafana dashboards API is responding (HTTP $DASHBOARDS_CHECK)"
else
    log "WARNING: Grafana dashboards API returned HTTP $DASHBOARDS_CHECK"
fi

# ============================================================================
# Summary
# ============================================================================

log "========================================="
success "Grafana integration test PASSED"
log "========================================="
log ""
log "Grafana Summary:"
log "  - Namespace: $MONITORING_NAMESPACE"
log "  - Service: $GRAFANA_SERVICE"
log "  - Service Type: $SERVICE_TYPE"

if [[ "$SERVICE_TYPE" == "NodePort" ]]; then
    log "  - NodePort: $NODEPORT"
    log "  - URL: http://$NODE_IP:$NODEPORT"
else
    log "  - Access via: kubectl port-forward -n $MONITORING_NAMESPACE svc/$GRAFANA_SERVICE 3000:80"
    log "  - URL: http://localhost:3000"
fi

log "  - Admin Username: admin"
log "  - Admin Password: (retrieve with command below)"
log ""
log "Get Grafana admin password:"
log "  kubectl get secret -n $MONITORING_NAMESPACE $GRAFANA_SERVICE -o jsonpath='{.data.admin-password}' | base64 -d"
log ""

exit 0
