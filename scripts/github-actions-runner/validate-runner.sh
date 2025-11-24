#!/usr/bin/env bash
# T016: Validate GitHub Actions Runner deployment
# Feature 017: GitHub Actions Self-Hosted Runner
#
# This script validates that the ARC controller and runner scale set are
# properly deployed and running in the Kubernetes cluster.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="${NAMESPACE:-github-actions}"
RUNNER_NAME="${RUNNER_NAME:-homelab-runner}"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

check_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# ==============================================================================
# Check Prerequisites
# ==============================================================================

print_header "Checking Prerequisites"

if command -v kubectl &> /dev/null; then
    check_pass "kubectl is installed"
else
    check_fail "kubectl is not installed"
    exit 1
fi

if kubectl cluster-info &> /dev/null; then
    check_pass "kubectl can connect to cluster"
else
    check_fail "kubectl cannot connect to cluster"
    exit 1
fi

# ==============================================================================
# Check Namespace
# ==============================================================================

print_header "Checking Namespace"

if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    check_pass "Namespace '$NAMESPACE' exists"
else
    check_fail "Namespace '$NAMESPACE' does not exist"
fi

# ==============================================================================
# Check ARC Controller
# ==============================================================================

print_header "Checking ARC Controller"

# Check if controller deployment exists
if kubectl get deployment -n "$NAMESPACE" -l app.kubernetes.io/name=gha-runner-scale-set-controller &> /dev/null 2>&1 || \
   kubectl get deployment -n "$NAMESPACE" arc-controller-gha-runner-scale-set-controller &> /dev/null 2>&1; then
    check_pass "ARC controller deployment found"

    # Check if controller pods are running
    CONTROLLER_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=gha-runner-scale-set-controller -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    if [[ -z "$CONTROLLER_PODS" ]]; then
        CONTROLLER_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance=arc-controller -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    fi

    if [[ "$CONTROLLER_PODS" == *"Running"* ]]; then
        check_pass "ARC controller pod is running"
    else
        check_fail "ARC controller pod is not running (status: $CONTROLLER_PODS)"
    fi
else
    check_fail "ARC controller deployment not found"
fi

# ==============================================================================
# Check Runner Scale Set
# ==============================================================================

print_header "Checking Runner Scale Set"

# Check if runner scale set exists (via AutoscalingRunnerSet CRD)
if kubectl get autoscalingrunnersets.actions.github.com -n "$NAMESPACE" &> /dev/null 2>&1; then
    RUNNER_COUNT=$(kubectl get autoscalingrunnersets.actions.github.com -n "$NAMESPACE" -o name 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$RUNNER_COUNT" -gt 0 ]]; then
        check_pass "Runner scale set found ($RUNNER_COUNT)"

        # Get runner scale set details
        kubectl get autoscalingrunnersets.actions.github.com -n "$NAMESPACE" -o wide 2>/dev/null || true
    else
        check_warn "No runner scale sets found (may be pending)"
    fi
else
    check_warn "AutoscalingRunnerSet CRD not found (ARC may not be fully installed)"
fi

# Check runner pods
RUNNER_PODS=$(kubectl get pods -n "$NAMESPACE" -l actions.github.com/scale-set-name="$RUNNER_NAME" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$RUNNER_PODS" ]]; then
    check_pass "Runner pods found: $RUNNER_PODS"

    # Check runner pod status
    kubectl get pods -n "$NAMESPACE" -l actions.github.com/scale-set-name="$RUNNER_NAME" -o wide 2>/dev/null || true
else
    check_info "No runner pods currently running (scale to zero when idle is expected)"
fi

# ==============================================================================
# Check GitHub App Secret
# ==============================================================================

print_header "Checking GitHub App Secret"

if kubectl get secret -n "$NAMESPACE" github-app-secret &> /dev/null; then
    check_pass "GitHub App secret exists"

    # Verify secret has expected keys
    SECRET_KEYS=$(kubectl get secret -n "$NAMESPACE" github-app-secret -o jsonpath='{.data}' | grep -o '"[^"]*"' | tr -d '"' || echo "")

    if echo "$SECRET_KEYS" | grep -q "github_app_id"; then
        check_pass "Secret contains github_app_id"
    else
        check_fail "Secret missing github_app_id"
    fi

    if echo "$SECRET_KEYS" | grep -q "github_app_installation_id"; then
        check_pass "Secret contains github_app_installation_id"
    else
        check_fail "Secret missing github_app_installation_id"
    fi

    if echo "$SECRET_KEYS" | grep -q "github_app_private_key"; then
        check_pass "Secret contains github_app_private_key"
    else
        check_fail "Secret missing github_app_private_key"
    fi
else
    check_fail "GitHub App secret not found"
fi

# ==============================================================================
# Check RBAC
# ==============================================================================

print_header "Checking RBAC"

if kubectl get serviceaccount -n "$NAMESPACE" arc-controller-sa &> /dev/null 2>&1; then
    check_pass "ARC controller service account exists"
else
    check_warn "ARC controller service account not found (may have different name)"
fi

# ==============================================================================
# Check Helm Releases
# ==============================================================================

print_header "Checking Helm Releases"

if command -v helm &> /dev/null; then
    HELM_RELEASES=$(helm list -n "$NAMESPACE" --output json 2>/dev/null || echo "[]")

    if echo "$HELM_RELEASES" | grep -q "arc-controller"; then
        check_pass "arc-controller Helm release found"
    else
        check_warn "arc-controller Helm release not found in namespace"
    fi

    if echo "$HELM_RELEASES" | grep -q "$RUNNER_NAME"; then
        check_pass "$RUNNER_NAME Helm release found"
    else
        check_warn "$RUNNER_NAME Helm release not found in namespace"
    fi
else
    check_info "helm CLI not available, skipping Helm release check"
fi

# ==============================================================================
# Summary
# ==============================================================================

print_header "Validation Summary"

echo -e "Total checks: $((PASSED + FAILED + WARNINGS))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"

if [[ $FAILED -gt 0 ]]; then
    echo -e "\n${RED}Validation FAILED${NC}"
    echo "Please review the failed checks above and ensure:"
    echo "  1. GitHub App is created and credentials are configured"
    echo "  2. OpenTofu/Terraform has been applied successfully"
    echo "  3. ARC controller and runner scale set are deployed"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo -e "\n${YELLOW}Validation completed with warnings${NC}"
    exit 0
else
    echo -e "\n${GREEN}Validation PASSED${NC}"
    exit 0
fi
