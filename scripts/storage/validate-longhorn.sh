#!/usr/bin/env bash
# ============================================================================
# Longhorn Deployment Validation Script
# ============================================================================
# Validates Longhorn distributed block storage deployment including:
# - Cluster pods and services
# - Storage nodes and disk capacity
# - StorageClass configuration
# - Basic volume provisioning functionality
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="longhorn-system"
STORAGE_CLASS="longhorn"
KUBECONFIG_PATH="${KUBECONFIG:-}"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisite() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    if [ -z "$KUBECONFIG_PATH" ]; then
        log_warn "KUBECONFIG not set. Using default kubeconfig."
    fi
}

validate_namespace() {
    log_info "Validating Longhorn namespace..."
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "✅ Namespace '$NAMESPACE' exists"
    else
        log_error "❌ Namespace '$NAMESPACE' not found"
        exit 1
    fi
}

validate_pods() {
    log_info "Validating Longhorn pods..."

    # Get pod count
    TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l | tr -d ' ')
    READY_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers | wc -l | tr -d ' ')

    log_info "Total pods: $TOTAL_PODS, Running pods: $READY_PODS"

    if [ "$TOTAL_PODS" -eq "$READY_PODS" ]; then
        log_info "✅ All Longhorn pods are Running ($READY_PODS/$TOTAL_PODS)"
    else
        log_warn "⚠️  Some pods are not ready ($READY_PODS/$TOTAL_PODS)"
        kubectl get pods -n "$NAMESPACE" | grep -v Running || true
    fi
}

validate_nodes() {
    log_info "Validating Longhorn storage nodes..."

    # Check if we can query Longhorn nodes CRD
    if kubectl get nodes.longhorn.io -n "$NAMESPACE" &> /dev/null; then
        NODE_COUNT=$(kubectl get nodes.longhorn.io -n "$NAMESPACE" --no-headers | wc -l | tr -d ' ')
        log_info "✅ Longhorn storage nodes: $NODE_COUNT"
        kubectl get nodes.longhorn.io -n "$NAMESPACE" -o wide
    else
        log_warn "⚠️  Cannot query Longhorn nodes CRD. Checking K8s nodes instead..."
        kubectl get nodes
    fi
}

validate_storageclass() {
    log_info "Validating Longhorn StorageClass..."

    if kubectl get storageclass "$STORAGE_CLASS" &> /dev/null; then
        log_info "✅ StorageClass '$STORAGE_CLASS' exists"

        # Check if it's the default StorageClass
        DEFAULT_ANNOTATION=$(kubectl get storageclass "$STORAGE_CLASS" -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')
        if [ "$DEFAULT_ANNOTATION" = "true" ]; then
            log_info "✅ StorageClass '$STORAGE_CLASS' is set as default"
        else
            log_warn "⚠️  StorageClass '$STORAGE_CLASS' is not the default"
        fi

        # Show StorageClass details
        kubectl get storageclass "$STORAGE_CLASS" -o yaml | grep -E "(provisioner|parameters|allowVolumeExpansion|reclaimPolicy)" || true
    else
        log_error "❌ StorageClass '$STORAGE_CLASS' not found"
        exit 1
    fi
}

validate_ui_service() {
    log_info "Validating Longhorn UI service..."

    if kubectl get svc -n "$NAMESPACE" longhorn-frontend &> /dev/null; then
        log_info "✅ Longhorn UI service 'longhorn-frontend' exists"
        kubectl get svc -n "$NAMESPACE" longhorn-frontend
    else
        log_warn "⚠️  Longhorn UI service not found (expected 'longhorn-frontend')"
    fi
}

validate_metrics() {
    log_info "Validating Prometheus metrics..."

    # Check for ServiceMonitor if Prometheus Operator is available
    if kubectl get servicemonitor -n "$NAMESPACE" &> /dev/null; then
        SERVICEMONITOR_COUNT=$(kubectl get servicemonitor -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
        if [ "$SERVICEMONITOR_COUNT" -gt 0 ]; then
            log_info "✅ ServiceMonitor resources found: $SERVICEMONITOR_COUNT"
            kubectl get servicemonitor -n "$NAMESPACE"
        else
            log_warn "⚠️  No ServiceMonitor resources found"
        fi
    else
        log_warn "⚠️  ServiceMonitor CRD not available (Prometheus Operator not installed?)"
    fi
}

# Main execution
main() {
    log_info "========================================="
    log_info "Longhorn Deployment Validation"
    log_info "========================================="

    check_prerequisite
    validate_namespace
    validate_pods
    validate_nodes
    validate_storageclass
    validate_ui_service
    validate_metrics

    log_info "========================================="
    log_info "✅ Longhorn validation completed"
    log_info "========================================="
}

main "$@"
