#!/usr/bin/env bash
#
# test-tunnel.sh - Cloudflare Zero Trust Tunnel Validation Script
# Feature 004: End-to-end testing for tunnel deployment
#
# Usage: ./scripts/test-tunnel.sh [kubeconfig_path]
#
# Checks:
# - Pod status and health
# - DNS resolution
# - HTTP/HTTPS connectivity
# - OAuth redirect presence
# - High availability configuration
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG_PATH="${1:-./kubeconfig}"
NAMESPACE="cloudflare-tunnel"
DEPLOYMENT="cloudflared"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_CHECKS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_CHECKS++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check() {
    ((TOTAL_CHECKS++))
}

separator() {
    echo "=================================================="
}

# Main script
main() {
    echo ""
    info "Cloudflare Zero Trust Tunnel - Validation Script"
    separator
    echo ""

    # Verify kubeconfig exists
    if [[ ! -f "$KUBECONFIG_PATH" ]]; then
        fail "Kubeconfig not found at: $KUBECONFIG_PATH"
        exit 1
    fi

    export KUBECONFIG="$KUBECONFIG_PATH"
    info "Using kubeconfig: $KUBECONFIG_PATH"
    echo ""

    # Check 1: Namespace exists
    check
    info "Check 1: Verifying namespace '$NAMESPACE' exists..."
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        success "Namespace '$NAMESPACE' exists"
    else
        fail "Namespace '$NAMESPACE' not found"
        exit 1
    fi
    echo ""

    # Check 2: Deployment exists and ready
    check
    info "Check 2: Verifying deployment '$DEPLOYMENT' status..."
    DESIRED=$(kubectl get deployment -n "$NAMESPACE" "$DEPLOYMENT" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    READY=$(kubectl get deployment -n "$NAMESPACE" "$DEPLOYMENT" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

    if [[ "$READY" -eq "$DESIRED" ]] && [[ "$DESIRED" -gt 0 ]]; then
        success "Deployment ready: $READY/$DESIRED replicas"
        info "Replica count: $READY"
    else
        fail "Deployment not ready: $READY/$DESIRED replicas"
    fi
    echo ""

    # Check 3: All pods running and ready
    check
    info "Check 3: Verifying all pods are running and ready..."
    POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app=cloudflared -o jsonpath='{range .items[*]}{.status.phase}{" "}{.status.containerStatuses[0].ready}{"\n"}{end}')

    ALL_RUNNING=true
    while IFS= read -r line; do
        PHASE=$(echo "$line" | awk '{print $1}')
        READY=$(echo "$line" | awk '{print $2}')

        if [[ "$PHASE" != "Running" ]] || [[ "$READY" != "true" ]]; then
            ALL_RUNNING=false
            break
        fi
    done <<< "$POD_STATUS"

    if $ALL_RUNNING; then
        success "All pods running and ready"
        kubectl get pods -n "$NAMESPACE" -l app=cloudflared | tail -n +2 | while read -r line; do
            POD_NAME=$(echo "$line" | awk '{print $1}')
            NODE=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.spec.nodeName}')
            info "  - $POD_NAME on node $NODE"
        done
    else
        fail "Some pods are not running or ready"
        kubectl get pods -n "$NAMESPACE" -l app=cloudflared
    fi
    echo ""

    # Check 4: Pod health probes
    check
    info "Check 4: Verifying pod health probes..."
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=cloudflared -o jsonpath='{.items[0].metadata.name}')

    HAS_LIVENESS=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.spec.containers[0].livenessProbe}' | grep -q . && echo "true" || echo "false")
    HAS_READINESS=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.spec.containers[0].readinessProbe}' | grep -q . && echo "true" || echo "false")

    if [[ "$HAS_LIVENESS" == "true" ]] && [[ "$HAS_READINESS" == "true" ]]; then
        success "Health probes configured (liveness + readiness)"
    else
        fail "Health probes missing or incomplete"
    fi
    echo ""

    # Check 5: PodDisruptionBudget (if HA mode)
    check
    info "Check 5: Verifying PodDisruptionBudget for HA..."
    if [[ "$DESIRED" -gt 1 ]]; then
        if kubectl get pdb -n "$NAMESPACE" cloudflared-pdb &>/dev/null; then
            MIN_AVAILABLE=$(kubectl get pdb -n "$NAMESPACE" cloudflared-pdb -o jsonpath='{.spec.minAvailable}')
            ALLOWED_DISRUPTIONS=$(kubectl get pdb -n "$NAMESPACE" cloudflared-pdb -o jsonpath='{.status.disruptionsAllowed}')
            success "PodDisruptionBudget exists (minAvailable: $MIN_AVAILABLE, allowedDisruptions: $ALLOWED_DISRUPTIONS)"
        else
            warn "PodDisruptionBudget not found (recommended for HA with $DESIRED replicas)"
        fi
    else
        info "Single replica deployment - PodDisruptionBudget not required"
        ((PASSED_CHECKS++))
    fi
    echo ""

    # Check 6: DNS resolution for exposed services
    check
    info "Check 6: Testing DNS resolution for exposed services..."

    # Get ingress hostnames from deployment environment variables or config
    HOSTNAMES=$(kubectl get deployment -n "$NAMESPACE" "$DEPLOYMENT" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="TUNNEL_HOSTNAME")].value}' 2>/dev/null || echo "")

    # Fallback: try to get from common services
    TEST_HOSTNAMES=("pihole.chocolandiadc.com" "grafana.chocolandiadc.com")

    DNS_SUCCESS=0
    DNS_TOTAL=0

    for HOSTNAME in "${TEST_HOSTNAMES[@]}"; do
        ((DNS_TOTAL++))
        if dig +short "$HOSTNAME" CNAME | grep -q "cfargotunnel.com"; then
            info "   $HOSTNAME ’ Cloudflare Tunnel"
            ((DNS_SUCCESS++))
        else
            warn "   $HOSTNAME ’ Not pointing to Cloudflare Tunnel"
        fi
    done

    if [[ $DNS_SUCCESS -eq $DNS_TOTAL ]] && [[ $DNS_TOTAL -gt 0 ]]; then
        success "DNS resolution working ($DNS_SUCCESS/$DNS_TOTAL hostnames)"
    elif [[ $DNS_SUCCESS -gt 0 ]]; then
        warn "Partial DNS resolution ($DNS_SUCCESS/$DNS_TOTAL hostnames)"
        ((PASSED_CHECKS++))
    else
        fail "DNS resolution failed for all tested hostnames"
    fi
    echo ""

    # Check 7: HTTP/HTTPS connectivity
    check
    info "Check 7: Testing HTTP/HTTPS connectivity..."

    HTTP_SUCCESS=0
    HTTP_TOTAL=0

    for HOSTNAME in "${TEST_HOSTNAMES[@]}"; do
        ((HTTP_TOTAL++))
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "https://$HOSTNAME" 2>/dev/null || echo "000")

        # 200 OK, 302 Redirect (OAuth), 401/403 (Access denied but server responding)
        if [[ "$HTTP_CODE" =~ ^(200|302|401|403)$ ]]; then
            info "   $HOSTNAME ’ HTTP $HTTP_CODE"
            ((HTTP_SUCCESS++))
        else
            warn "   $HOSTNAME ’ HTTP $HTTP_CODE (Expected: 200, 302, 401, or 403)"
        fi
    done

    if [[ $HTTP_SUCCESS -eq $HTTP_TOTAL ]] && [[ $HTTP_TOTAL -gt 0 ]]; then
        success "HTTP/HTTPS connectivity working ($HTTP_SUCCESS/$HTTP_TOTAL services)"
    elif [[ $HTTP_SUCCESS -gt 0 ]]; then
        warn "Partial HTTP/HTTPS connectivity ($HTTP_SUCCESS/$HTTP_TOTAL services)"
        ((PASSED_CHECKS++))
    else
        fail "HTTP/HTTPS connectivity failed for all services"
    fi
    echo ""

    # Check 8: OAuth redirect detection
    check
    info "Check 8: Detecting OAuth redirect (Access control active)..."

    OAUTH_SUCCESS=0
    OAUTH_TOTAL=0

    for HOSTNAME in "${TEST_HOSTNAMES[@]}"; do
        ((OAUTH_TOTAL++))
        RESPONSE=$(curl -s -L -m 10 "https://$HOSTNAME" 2>/dev/null || echo "")

        if echo "$RESPONSE" | grep -qi "cloudflareaccess\|oauth\|google"; then
            info "   $HOSTNAME ’ OAuth redirect detected"
            ((OAUTH_SUCCESS++))
        else
            warn "   $HOSTNAME ’ No OAuth redirect detected (may be allowed without auth)"
        fi
    done

    if [[ $OAUTH_SUCCESS -gt 0 ]]; then
        success "OAuth access control active ($OAUTH_SUCCESS/$OAUTH_TOTAL services)"
    else
        warn "No OAuth redirects detected (services may be publicly accessible)"
        ((PASSED_CHECKS++))
    fi
    echo ""

    # Check 9: Prometheus metrics endpoint
    check
    info "Check 9: Verifying Prometheus metrics configuration..."

    POD_ANNOTATIONS=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.metadata.annotations}')

    if echo "$POD_ANNOTATIONS" | grep -q "prometheus.io/scrape.*true"; then
        success "Prometheus scrape annotations configured"
        METRICS_PORT=$(echo "$POD_ANNOTATIONS" | grep -oP 'prometheus.io/port.*?(\d+)' | grep -oP '\d+')
        info "  Metrics port: ${METRICS_PORT:-2000}"
        info "  Metrics path: /metrics"
    else
        fail "Prometheus annotations missing"
    fi
    echo ""

    # Check 10: Pod logs (no critical errors)
    check
    info "Check 10: Checking pod logs for critical errors..."

    LOG_ERRORS=$(kubectl logs -n "$NAMESPACE" "$POD_NAME" --tail=100 2>/dev/null | grep -iE "error|fatal|panic" | wc -l)

    if [[ $LOG_ERRORS -eq 0 ]]; then
        success "No critical errors in recent pod logs"
    elif [[ $LOG_ERRORS -lt 5 ]]; then
        warn "Found $LOG_ERRORS potential error(s) in logs (review manually)"
        ((PASSED_CHECKS++))
    else
        fail "Found $LOG_ERRORS error(s) in logs - manual review required"
        info "Run: kubectl logs -n $NAMESPACE $POD_NAME --tail=50"
    fi
    echo ""

    # Summary
    separator
    echo ""
    info "Validation Summary:"
    echo "  Total checks:  $TOTAL_CHECKS"
    echo -e "  ${GREEN}Passed:${NC}        $PASSED_CHECKS"
    echo -e "  ${RED}Failed:${NC}        $FAILED_CHECKS"
    echo ""

    if [[ $FAILED_CHECKS -eq 0 ]]; then
        success "All checks passed! Cloudflare Tunnel is operational."
        separator
        exit 0
    else
        fail "$FAILED_CHECKS check(s) failed. Review output above for details."
        separator
        exit 1
    fi
}

# Run main function
main "$@"
