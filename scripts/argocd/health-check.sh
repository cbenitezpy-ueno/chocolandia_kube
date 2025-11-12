#!/usr/bin/env bash
# ArgoCD Health Check Script
# Feature 008: GitOps Continuous Deployment with ArgoCD
#
# Verifies ArgoCD components health (pods Running, services accessible)
#
# Usage:
#   ./scripts/argocd/health-check.sh
#
# Exit codes:
#   0 - All health checks passed
#   1 - One or more health checks failed

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
TIMEOUT=300  # 5 minutes

# Exit flag
EXIT_CODE=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ArgoCD Health Check${NC}"
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

# Check 1: Namespace exists
echo -e "${BLUE}[1/7] Checking namespace...${NC}"
if kubectl --kubeconfig="$KUBECONFIG" get namespace "$ARGOCD_NAMESPACE" &>/dev/null; then
    print_status "OK" "Namespace '$ARGOCD_NAMESPACE' exists"
else
    print_status "FAIL" "Namespace '$ARGOCD_NAMESPACE' not found"
    exit 1
fi
echo ""

# Check 2: ArgoCD Server Pod
echo -e "${BLUE}[2/7] Checking ArgoCD Server pod...${NC}"
SERVER_POD=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$SERVER_POD" ]; then
    SERVER_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get pod -n "$ARGOCD_NAMESPACE" "$SERVER_POD" -o jsonpath='{.status.phase}')
    if [ "$SERVER_STATUS" = "Running" ]; then
        print_status "OK" "ArgoCD Server pod: $SERVER_POD ($SERVER_STATUS)"
    else
        print_status "FAIL" "ArgoCD Server pod: $SERVER_POD ($SERVER_STATUS)"
    fi
else
    print_status "FAIL" "ArgoCD Server pod not found"
fi
echo ""

# Check 3: ArgoCD Repo Server Pod
echo -e "${BLUE}[3/7] Checking ArgoCD Repo Server pod...${NC}"
REPO_POD=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$REPO_POD" ]; then
    REPO_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get pod -n "$ARGOCD_NAMESPACE" "$REPO_POD" -o jsonpath='{.status.phase}')
    if [ "$REPO_STATUS" = "Running" ]; then
        print_status "OK" "ArgoCD Repo Server pod: $REPO_POD ($REPO_STATUS)"
    else
        print_status "FAIL" "ArgoCD Repo Server pod: $REPO_POD ($REPO_STATUS)"
    fi
else
    print_status "FAIL" "ArgoCD Repo Server pod not found"
fi
echo ""

# Check 4: ArgoCD Application Controller Pod
echo -e "${BLUE}[4/7] Checking ArgoCD Application Controller pod...${NC}"
CONTROLLER_POD=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=argocd-application-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$CONTROLLER_POD" ]; then
    CONTROLLER_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get pod -n "$ARGOCD_NAMESPACE" "$CONTROLLER_POD" -o jsonpath='{.status.phase}')
    if [ "$CONTROLLER_STATUS" = "Running" ]; then
        print_status "OK" "ArgoCD Application Controller pod: $CONTROLLER_POD ($CONTROLLER_STATUS)"
    else
        print_status "FAIL" "ArgoCD Application Controller pod: $CONTROLLER_POD ($CONTROLLER_STATUS)"
    fi
else
    print_status "FAIL" "ArgoCD Application Controller pod not found"
fi
echo ""

# Check 5: ArgoCD Redis Pod
echo -e "${BLUE}[5/7] Checking ArgoCD Redis pod...${NC}"
REDIS_POD=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=argocd-redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$REDIS_POD" ]; then
    REDIS_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get pod -n "$ARGOCD_NAMESPACE" "$REDIS_POD" -o jsonpath='{.status.phase}')
    if [ "$REDIS_STATUS" = "Running" ]; then
        print_status "OK" "ArgoCD Redis pod: $REDIS_POD ($REDIS_STATUS)"
    else
        print_status "FAIL" "ArgoCD Redis pod: $REDIS_POD ($REDIS_STATUS)"
    fi
else
    print_status "FAIL" "ArgoCD Redis pod not found"
fi
echo ""

# Check 6: ArgoCD Server Service
echo -e "${BLUE}[6/7] Checking ArgoCD Server service...${NC}"
if kubectl --kubeconfig="$KUBECONFIG" get svc -n "$ARGOCD_NAMESPACE" argocd-server &>/dev/null; then
    SERVICE_TYPE=$(kubectl --kubeconfig="$KUBECONFIG" get svc -n "$ARGOCD_NAMESPACE" argocd-server -o jsonpath='{.spec.type}')
    SERVICE_PORT=$(kubectl --kubeconfig="$KUBECONFIG" get svc -n "$ARGOCD_NAMESPACE" argocd-server -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
    print_status "OK" "ArgoCD Server service exists (Type: $SERVICE_TYPE, Port: $SERVICE_PORT)"
else
    print_status "FAIL" "ArgoCD Server service not found"
fi
echo ""

# Check 7: ArgoCD IngressRoute (if exists)
echo -e "${BLUE}[7/7] Checking ArgoCD IngressRoute...${NC}"
if kubectl --kubeconfig="$KUBECONFIG" get ingressroute -n "$ARGOCD_NAMESPACE" argocd-server &>/dev/null; then
    INGRESS_HOST=$(kubectl --kubeconfig="$KUBECONFIG" get ingressroute -n "$ARGOCD_NAMESPACE" argocd-server -o jsonpath='{.spec.routes[0].match}' | sed -n 's/.*Host(`\([^`]*\)`).*/\1/p')
    print_status "OK" "ArgoCD IngressRoute exists (Host: $INGRESS_HOST)"
else
    print_status "WARN" "ArgoCD IngressRoute not found (optional)"
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All health checks passed${NC}"
else
    echo -e "${RED}✗ Some health checks failed${NC}"
fi
echo -e "${BLUE}========================================${NC}"

exit $EXIT_CODE
