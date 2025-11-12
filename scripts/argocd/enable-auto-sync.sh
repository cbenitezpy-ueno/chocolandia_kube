#!/usr/bin/env bash
# ==============================================================================
# ArgoCD Auto-Sync Enablement Script
# Feature 008: GitOps Continuous Deployment with ArgoCD
# ==============================================================================
#
# This script enables automated synchronization for an ArgoCD Application,
# allowing it to automatically detect and apply changes from Git.
#
# Usage:
#   ./scripts/argocd/enable-auto-sync.sh <application-name> [namespace]
#
# Example:
#   ./scripts/argocd/enable-auto-sync.sh chocolandia-kube argocd
#
# Configuration:
#   - prune: true (delete resources removed from Git)
#   - selfHeal: true (revert manual cluster changes)
#   - allowEmpty: false (prevent accidental deletion)
#
# Requirements:
#   - kubectl configured with cluster access
#   - ArgoCD Application exists in cluster
#   - KUBECONFIG environment variable set
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
APP_NAME="${1:-}"
NAMESPACE="${2:-argocd}"

# ==============================================================================
# Functions
# ==============================================================================

print_usage() {
    cat << EOF
Usage: $0 <application-name> [namespace]

Arguments:
  application-name    Name of the ArgoCD Application
  namespace          Kubernetes namespace (default: argocd)

Example:
  $0 chocolandia-kube argocd

EOF
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# ==============================================================================
# Validation
# ==============================================================================

if [[ -z "${APP_NAME}" ]]; then
    error "Application name is required"
    print_usage
    exit 1
fi

if [[ -z "${KUBECONFIG:-}" ]]; then
    error "KUBECONFIG environment variable not set"
    exit 1
fi

# Check kubectl access
if ! kubectl auth can-i get applications.argoproj.io -n "${NAMESPACE}" &>/dev/null; then
    error "Insufficient permissions to access ArgoCD Applications in namespace '${NAMESPACE}'"
    exit 1
fi

# Check if Application exists
if ! kubectl get application "${APP_NAME}" -n "${NAMESPACE}" &>/dev/null; then
    error "Application '${APP_NAME}' not found in namespace '${NAMESPACE}'"
    exit 1
fi

# ==============================================================================
# Pre-Flight Checks
# ==============================================================================

info "Checking current Application status..."

# Get current sync status
CURRENT_SYNC=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.sync.status}')
CURRENT_HEALTH=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.health.status}')

echo "  Current Status:"
echo "    Sync Status:   ${CURRENT_SYNC}"
echo "    Health Status: ${CURRENT_HEALTH}"

# Check if auto-sync already enabled
if kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o yaml | grep -q "automated:"; then
    CURRENT_PRUNE=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.syncPolicy.automated.prune}')
    CURRENT_SELFHEAL=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.syncPolicy.automated.selfHeal}')
    CURRENT_ALLOWEMPTY=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.syncPolicy.automated.allowEmpty}')

    echo "  Current Auto-Sync Configuration:"
    echo "    prune:      ${CURRENT_PRUNE}"
    echo "    selfHeal:   ${CURRENT_SELFHEAL}"
    echo "    allowEmpty: ${CURRENT_ALLOWEMPTY}"

    read -p "Auto-sync is already configured. Continue with update? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Operation cancelled"
        exit 0
    fi
fi

# ==============================================================================
# Enable Auto-Sync
# ==============================================================================

info "Enabling auto-sync for Application '${APP_NAME}'..."

# Patch Application with auto-sync configuration
kubectl patch application "${APP_NAME}" -n "${NAMESPACE}" --type merge -p '{
  "spec": {
    "syncPolicy": {
      "automated": {
        "prune": true,
        "selfHeal": true,
        "allowEmpty": false
      }
    }
  }
}'

success "Auto-sync configuration applied"

# Wait for ArgoCD to process the change
info "Waiting for ArgoCD to process configuration change..."
sleep 5

# ==============================================================================
# Verification
# ==============================================================================

info "Verifying auto-sync enablement..."

# Get updated configuration
NEW_PRUNE=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.syncPolicy.automated.prune}')
NEW_SELFHEAL=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.syncPolicy.automated.selfHeal}')
NEW_ALLOWEMPTY=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.syncPolicy.automated.allowEmpty}')

echo "  Verified Configuration:"
echo "    prune:      ${NEW_PRUNE}"
echo "    selfHeal:   ${NEW_SELFHEAL}"
echo "    allowEmpty: ${NEW_ALLOWEMPTY}"

# Verify all settings are correct
if [[ "${NEW_PRUNE}" == "true" && "${NEW_SELFHEAL}" == "true" && "${NEW_ALLOWEMPTY}" == "false" ]]; then
    success "Auto-sync enabled successfully!"
else
    error "Auto-sync configuration verification failed"
    exit 1
fi

# Get final status
FINAL_SYNC=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.sync.status}')
FINAL_HEALTH=$(kubectl get application "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.health.status}')

echo ""
echo "Final Application Status:"
echo "  Sync Status:   ${FINAL_SYNC}"
echo "  Health Status: ${FINAL_HEALTH}"

# ==============================================================================
# Next Steps
# ==============================================================================

cat << EOF

${GREEN}Auto-sync is now enabled!${NC}

How it works:
1. ArgoCD polls Git repository every 3 minutes
2. Detects changes to Kubernetes manifests
3. Automatically syncs changes to the cluster
4. Self-healing: Reverts manual cluster changes to match Git

To test auto-sync:
1. Make changes to Kubernetes manifests in Git
2. Commit and push to repository
3. Wait up to 3 minutes for ArgoCD to detect changes
4. Verify sync: kubectl get application ${APP_NAME} -n ${NAMESPACE}

To monitor sync operations:
  kubectl describe application ${APP_NAME} -n ${NAMESPACE}

To view ArgoCD UI:
  kubectl port-forward -n argocd svc/argocd-server 8080:443
  # Access: https://localhost:8080

EOF

exit 0
