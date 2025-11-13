#!/usr/bin/env bash
# ArgoCD Application Sync Validation Script
# Feature 008: GitOps Continuous Deployment with ArgoCD
#
# Checks ArgoCD Application sync status and health
#
# Usage:
#   ./scripts/argocd/validate-sync.sh [application-name]
#
#   If application-name is not provided, checks all applications
#
# Exit codes:
#   0 - All applications Synced and Healthy
#   1 - One or more applications OutOfSync or Degraded

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
KUBECONFIG="${KUBECONFIG:-terraform/environments/chocolandiadc-mvp/kubeconfig}"
APP_NAME="${1:-}"

# Exit flag
EXIT_CODE=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ArgoCD Application Sync Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2

    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
        EXIT_CODE=1
    fi
}

# Function to check single application
check_application() {
    local app=$1

    echo -e "${BLUE}Checking Application: $app${NC}"

    # Get application status
    if ! kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" &>/dev/null; then
        print_status "FAIL" "Application '$app' not found"
        echo ""
        return
    fi

    # Get sync status
    SYNC_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")

    # Get health status
    HEALTH_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

    # Get repository URL
    REPO_URL=$(kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o jsonpath='{.spec.source.repoURL}' 2>/dev/null || echo "Unknown")

    # Get target revision
    TARGET_REVISION=$(kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || echo "Unknown")

    # Get destination namespace
    DEST_NAMESPACE=$(kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o jsonpath='{.spec.destination.namespace}' 2>/dev/null || echo "Unknown")

    # Print application details
    echo "  Repository:   $REPO_URL"
    echo "  Branch:       $TARGET_REVISION"
    echo "  Namespace:    $DEST_NAMESPACE"
    echo ""

    # Check sync status
    if [ "$SYNC_STATUS" = "Synced" ]; then
        print_status "OK" "Sync Status: $SYNC_STATUS"
    elif [ "$SYNC_STATUS" = "OutOfSync" ]; then
        print_status "FAIL" "Sync Status: $SYNC_STATUS"

        # Show what's out of sync
        echo -e "${YELLOW}  Out of sync resources:${NC}"
        kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o json | \
            jq -r '.status.conditions[]? | select(.type == "OutOfSync") | "  - \(.message)"' 2>/dev/null || echo "  (details unavailable)"
    else
        print_status "WARN" "Sync Status: $SYNC_STATUS"
    fi

    # Check health status
    if [ "$HEALTH_STATUS" = "Healthy" ]; then
        print_status "OK" "Health Status: $HEALTH_STATUS"
    elif [ "$HEALTH_STATUS" = "Progressing" ]; then
        print_status "WARN" "Health Status: $HEALTH_STATUS (deployment in progress)"
    elif [ "$HEALTH_STATUS" = "Degraded" ]; then
        print_status "FAIL" "Health Status: $HEALTH_STATUS"

        # Show degraded resources
        echo -e "${RED}  Degraded resources:${NC}"
        kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o json | \
            jq -r '.status.resources[]? | select(.health.status == "Degraded") | "  - \(.kind)/\(.name): \(.health.message)"' 2>/dev/null || echo "  (details unavailable)"
    elif [ "$HEALTH_STATUS" = "Missing" ]; then
        print_status "FAIL" "Health Status: $HEALTH_STATUS (resources not found)"
    else
        print_status "WARN" "Health Status: $HEALTH_STATUS"
    fi

    # Check auto-sync status
    AUTO_SYNC=$(kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o jsonpath='{.spec.syncPolicy.automated}' 2>/dev/null)
    if [ -n "$AUTO_SYNC" ] && [ "$AUTO_SYNC" != "null" ]; then
        PRUNE=$(kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o jsonpath='{.spec.syncPolicy.automated.prune}' 2>/dev/null)
        SELF_HEAL=$(kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o jsonpath='{.spec.syncPolicy.automated.selfHeal}' 2>/dev/null)
        echo -e "  Auto-Sync: ${GREEN}Enabled${NC} (Prune: $PRUNE, SelfHeal: $SELF_HEAL)"
    else
        echo -e "  Auto-Sync: ${YELLOW}Disabled${NC} (manual sync required)"
    fi

    # Get last sync time
    LAST_SYNC=$(kubectl --kubeconfig="$KUBECONFIG" get application -n "$ARGOCD_NAMESPACE" "$app" -o jsonpath='{.status.operationState.finishedAt}' 2>/dev/null || echo "Never")
    if [ "$LAST_SYNC" != "Never" ]; then
        echo "  Last Sync: $LAST_SYNC"
    else
        echo -e "  Last Sync: ${YELLOW}$LAST_SYNC${NC}"
    fi

    echo ""
}

# Check if specific application or all applications
if [ -n "$APP_NAME" ]; then
    # Check single application
    check_application "$APP_NAME"
else
    # Get all applications
    APPLICATIONS=$(kubectl --kubeconfig="$KUBECONFIG" get applications -n "$ARGOCD_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

    if [ -z "$APPLICATIONS" ]; then
        echo -e "${YELLOW}No ArgoCD Applications found in namespace '$ARGOCD_NAMESPACE'${NC}"
        echo ""
        exit 0
    fi

    # Check each application
    for app in $APPLICATIONS; do
        check_application "$app"
    done
fi

# Summary
echo -e "${BLUE}========================================${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All applications Synced and Healthy${NC}"
else
    echo -e "${RED}✗ Some applications OutOfSync or Degraded${NC}"
    echo ""
    echo "To manually sync an application:"
    echo "  kubectl apply -f kubernetes/argocd/applications/<app-name>.yaml"
    echo "  argocd app sync <app-name>"
fi
echo -e "${BLUE}========================================${NC}"

exit $EXIT_CODE
