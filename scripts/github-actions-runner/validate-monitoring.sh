#!/usr/bin/env bash
# T024: Validate GitHub Actions Runner monitoring integration
# Feature 017: GitHub Actions Self-Hosted Runner
#
# This script validates that Prometheus monitoring is properly configured
# for the GitHub Actions runner.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="${NAMESPACE:-github-actions}"
PROMETHEUS_NAMESPACE="${PROMETHEUS_NAMESPACE:-monitoring}"

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
# Check ServiceMonitor
# ==============================================================================

print_header "Checking ServiceMonitor"

if kubectl get servicemonitor -n "$NAMESPACE" github-actions-runner &> /dev/null 2>&1; then
    check_pass "ServiceMonitor 'github-actions-runner' exists"

    # Check labels for Prometheus discovery
    LABELS=$(kubectl get servicemonitor -n "$NAMESPACE" github-actions-runner -o jsonpath='{.metadata.labels}' 2>/dev/null || echo "{}")
    if echo "$LABELS" | grep -q "release"; then
        check_pass "ServiceMonitor has 'release' label for Prometheus discovery"
    else
        check_warn "ServiceMonitor missing 'release' label - Prometheus may not discover it"
    fi
else
    check_fail "ServiceMonitor 'github-actions-runner' not found"
fi

# ==============================================================================
# Check PrometheusRule
# ==============================================================================

print_header "Checking PrometheusRule"

if kubectl get prometheusrule -n "$NAMESPACE" github-actions-runner &> /dev/null 2>&1; then
    check_pass "PrometheusRule 'github-actions-runner' exists"

    # Check for specific alerts
    RULES=$(kubectl get prometheusrule -n "$NAMESPACE" github-actions-runner -o jsonpath='{.spec.groups[*].rules[*].alert}' 2>/dev/null || echo "")

    if echo "$RULES" | grep -q "GitHubRunnerOffline"; then
        check_pass "Alert 'GitHubRunnerOffline' is defined"
    else
        check_warn "Alert 'GitHubRunnerOffline' not found"
    fi

    if echo "$RULES" | grep -q "GitHubRunnerHighUtilization"; then
        check_pass "Alert 'GitHubRunnerHighUtilization' is defined"
    else
        check_info "Alert 'GitHubRunnerHighUtilization' not found (optional)"
    fi
else
    check_fail "PrometheusRule 'github-actions-runner' not found"
fi

# ==============================================================================
# Check Prometheus Discovery
# ==============================================================================

print_header "Checking Prometheus Discovery"

# Check if Prometheus is available
PROMETHEUS_POD=$(kubectl get pods -n "$PROMETHEUS_NAMESPACE" -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$PROMETHEUS_POD" ]]; then
    check_pass "Prometheus pod found: $PROMETHEUS_POD"

    # Check if prometheus is scraping our targets (via port-forward would be needed for full check)
    check_info "To verify Prometheus scraping, port-forward to Prometheus:"
    echo "  kubectl port-forward -n $PROMETHEUS_NAMESPACE svc/prometheus-operated 9090:9090"
    echo "  Then visit: http://localhost:9090/targets"
else
    check_warn "Prometheus pod not found in namespace '$PROMETHEUS_NAMESPACE'"
fi

# ==============================================================================
# Check Grafana Dashboard
# ==============================================================================

print_header "Checking Grafana Dashboard"

DASHBOARD_PATH="terraform/dashboards/github-actions-runner.json"

if [[ -f "$DASHBOARD_PATH" ]]; then
    check_pass "Grafana dashboard JSON exists at $DASHBOARD_PATH"

    # Check if dashboard ConfigMap exists
    if kubectl get configmap -n "$PROMETHEUS_NAMESPACE" -l grafana_dashboard=1 2>/dev/null | grep -q "github-actions"; then
        check_pass "Dashboard ConfigMap found in Grafana namespace"
    else
        check_info "Dashboard ConfigMap not found - may need to import manually"
    fi
else
    check_warn "Grafana dashboard not found at $DASHBOARD_PATH"
fi

# ==============================================================================
# Check Metrics Endpoint
# ==============================================================================

print_header "Checking Metrics Endpoint"

# Check if ARC controller service has metrics port
ARC_SERVICE=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=gha-runner-scale-set-controller -o name 2>/dev/null || echo "")

if [[ -n "$ARC_SERVICE" ]]; then
    check_pass "ARC controller service found"

    PORTS=$(kubectl get "$ARC_SERVICE" -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].name}' 2>/dev/null || echo "")
    if echo "$PORTS" | grep -qi "metrics"; then
        check_pass "Metrics port exposed on ARC controller service"
    else
        check_info "Metrics port name not found (may be exposed under different name)"
    fi
else
    check_warn "ARC controller service not found"
fi

# ==============================================================================
# Summary
# ==============================================================================

print_header "Monitoring Validation Summary"

echo -e "Total checks: $((PASSED + FAILED + WARNINGS))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"

if [[ $FAILED -gt 0 ]]; then
    echo -e "\n${RED}Monitoring validation FAILED${NC}"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo -e "\n${YELLOW}Monitoring validation completed with warnings${NC}"
    exit 0
else
    echo -e "\n${GREEN}Monitoring validation PASSED${NC}"
    exit 0
fi
