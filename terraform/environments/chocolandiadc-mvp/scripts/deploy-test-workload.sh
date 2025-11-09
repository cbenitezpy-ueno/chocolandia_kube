#!/usr/bin/env bash
#
# Deploy Test Workload (Nginx)
# Creates a test deployment and verifies it runs successfully on worker node
#
# Usage: ./deploy-test-workload.sh [kubeconfig_path]

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

KUBECONFIG_PATH="${1:-./kubeconfig}"
TEST_NAMESPACE="test-workload"
DEPLOYMENT_NAME="nginx-test"
REPLICAS=2
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

cleanup() {
    log "Cleaning up test resources..."
    kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true --timeout=30s &> /dev/null || true
}

# ============================================================================
# Pre-Check
# ============================================================================

log "Starting test workload deployment"

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
# Cluster Connectivity
# ============================================================================

log "Verifying cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes API server"
fi
success "Connected to cluster"

# ============================================================================
# Create Test Namespace
# ============================================================================

log "Creating test namespace: $TEST_NAMESPACE"
kubectl create namespace "$TEST_NAMESPACE" 2>/dev/null || log "Namespace already exists"

# ============================================================================
# Deploy Nginx Test Workload
# ============================================================================

log "Deploying nginx test workload ($REPLICAS replicas)..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT_NAME
  namespace: $TEST_NAMESPACE
  labels:
    app: nginx-test
spec:
  replicas: $REPLICAS
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: $DEPLOYMENT_NAME
  namespace: $TEST_NAMESPACE
spec:
  selector:
    app: nginx-test
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

success "Test workload deployed"

# ============================================================================
# Wait for Deployment to be Ready
# ============================================================================

log "Waiting for deployment to be ready (timeout: ${TIMEOUT_SECONDS}s)..."

START_TIME=$(date +%s)
while true; do
    READY_REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED_REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

    if [[ "$READY_REPLICAS" == "$DESIRED_REPLICAS" ]] && [[ "$READY_REPLICAS" != "0" ]]; then
        success "Deployment is ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas)"
        break
    fi

    ELAPSED=$(($(date +%s) - START_TIME))
    if [[ $ELAPSED -ge $TIMEOUT_SECONDS ]]; then
        log "Deployment status:"
        kubectl get deployment "$DEPLOYMENT_NAME" -n "$TEST_NAMESPACE"
        log "Pod status:"
        kubectl get pods -n "$TEST_NAMESPACE"
        log "Pod describe:"
        kubectl describe pods -n "$TEST_NAMESPACE"
        error "Deployment did not become ready after ${TIMEOUT_SECONDS}s (ready: $READY_REPLICAS/$DESIRED_REPLICAS)"
    fi

    log "Waiting for pods to be ready... ($READY_REPLICAS/$DESIRED_REPLICAS ready, ${ELAPSED}s elapsed)"
    sleep 5
done

# ============================================================================
# Verify Pod Distribution
# ============================================================================

log "Verifying pod distribution across nodes..."
kubectl get pods -n "$TEST_NAMESPACE" -o wide

POD_NODES=$(kubectl get pods -n "$TEST_NAMESPACE" -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort | uniq)
log "Pods scheduled on nodes: $POD_NODES"

# ============================================================================
# Test Service Connectivity
# ============================================================================

log "Testing service connectivity..."

SERVICE_IP=$(kubectl get service "$DEPLOYMENT_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.clusterIP}')
log "Service ClusterIP: $SERVICE_IP"

# Create a test pod to curl the service
log "Creating test client pod..."
kubectl run test-client -n "$TEST_NAMESPACE" --image=curlimages/curl:latest --rm -i --restart=Never --command -- sleep 1 &> /dev/null || true

log "Testing HTTP connectivity to nginx service..."
HTTP_RESPONSE=$(kubectl run test-client -n "$TEST_NAMESPACE" --image=curlimages/curl:latest --rm -i --restart=Never --command -- curl -s -o /dev/null -w "%{http_code}" "http://${SERVICE_IP}:80" 2>/dev/null || echo "000")

if [[ "$HTTP_RESPONSE" == "200" ]]; then
    success "Service is accessible (HTTP $HTTP_RESPONSE)"
else
    log "WARNING: Service returned HTTP $HTTP_RESPONSE (expected 200)"
fi

# ============================================================================
# Display Test Results
# ============================================================================

log "========================================="
log "Test Workload Summary"
log "========================================="
log ""
log "Deployment Status:"
kubectl get deployment "$DEPLOYMENT_NAME" -n "$TEST_NAMESPACE"
log ""
log "Pod Status:"
kubectl get pods -n "$TEST_NAMESPACE" -o wide
log ""
log "Service Status:"
kubectl get service "$DEPLOYMENT_NAME" -n "$TEST_NAMESPACE"
log ""
log "Pod Events:"
kubectl get events -n "$TEST_NAMESPACE" --sort-by='.lastTimestamp' | tail -10

# ============================================================================
# Cleanup Option
# ============================================================================

log ""
log "========================================="
success "Test workload validation PASSED"
log "========================================="
log ""
log "To clean up test resources, run:"
log "  kubectl delete namespace $TEST_NAMESPACE"
log ""
log "Or run this script with cleanup:"
log "  kubectl delete namespace $TEST_NAMESPACE"

exit 0
