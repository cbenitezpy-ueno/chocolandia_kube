#!/usr/bin/env bash
#
# Test: External Connectivity to PostgreSQL via MetalLB LoadBalancer
# Feature: 011-postgresql-cluster
# Phase: 4 - User Story 2 (Internal Network Database Access)
# Tasks: T040, T041
#
# Purpose: Validate that PostgreSQL cluster is accessible from internal network
#          via MetalLB LoadBalancer service
#
# Prerequisites:
#   - PostgreSQL cluster deployed with LoadBalancer service
#   - MetalLB configured with IP pool
#   - psql client available (or use nc/telnet for basic connectivity)
#   - KUBECONFIG set to cluster kubeconfig
#
# Usage:
#   ./test_external_connectivity.sh [external-ip]
#
# If external-ip is not provided, script will auto-detect from service

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${NAMESPACE:-postgresql}"
SERVICE_NAME="${SERVICE_NAME:-postgres-ha-postgresql-primary}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
TEST_DATABASE="${TEST_DATABASE:-app_db}"
TEST_USER="${TEST_USER:-postgres}"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

echo "================================================"
echo "PostgreSQL External Connectivity Test"
echo "Feature: 011-postgresql-cluster - Phase 4"
echo "================================================"
echo ""

# Function to print test result
print_result() {
    local test_name=$1
    local result=$2
    local message=$3

    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        [ -n "$message" ] && echo "  → $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        [ -n "$message" ] && echo "  → $message"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Test 1: Get LoadBalancer external IP
echo "Test 1: Retrieve LoadBalancer External IP"
echo "-------------------------------------------"

if [ -n "${1:-}" ]; then
    EXTERNAL_IP="$1"
    echo "Using provided external IP: $EXTERNAL_IP"
else
    echo "Auto-detecting external IP from service..."
    EXTERNAL_IP=$(kubectl get svc -n "$NAMESPACE" "$SERVICE_NAME" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
fi

if [ -z "$EXTERNAL_IP" ]; then
    print_result "Get LoadBalancer IP" 1 "Failed to retrieve external IP. Service may not have LoadBalancer type or IP not yet assigned."
    echo "Checking service status:"
    kubectl get svc -n "$NAMESPACE" "$SERVICE_NAME" 2>&1 || true
    exit 1
fi

print_result "Get LoadBalancer IP" 0 "External IP: $EXTERNAL_IP"

# Test 2: Verify LoadBalancer service exists
echo "Test 2: Verify LoadBalancer Service Configuration"
echo "--------------------------------------------------"

SERVICE_TYPE=$(kubectl get svc -n "$NAMESPACE" "$SERVICE_NAME" \
    -o jsonpath='{.spec.type}' 2>/dev/null || echo "")

if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
    print_result "Service Type Check" 0 "Service type is LoadBalancer"
else
    print_result "Service Type Check" 1 "Service type is $SERVICE_TYPE (expected LoadBalancer)"
fi

# Test 3: TCP connectivity test (port reachable)
echo "Test 3: TCP Connectivity to PostgreSQL Port"
echo "--------------------------------------------"

if command -v nc &> /dev/null; then
    echo "Testing TCP connectivity using netcat..."
    if timeout 5 nc -zv "$EXTERNAL_IP" "$POSTGRES_PORT" 2>&1 | grep -q "succeeded\|open"; then
        print_result "TCP Connectivity" 0 "Port $POSTGRES_PORT is reachable on $EXTERNAL_IP"
    else
        print_result "TCP Connectivity" 1 "Port $POSTGRES_PORT is NOT reachable on $EXTERNAL_IP"
        echo "Troubleshooting tips:"
        echo "  - Check MetalLB speaker pods: kubectl get pods -n metallb-system"
        echo "  - Verify IP pool: kubectl get ipaddresspool -n metallb-system"
        echo "  - Check service events: kubectl describe svc -n $NAMESPACE $SERVICE_NAME"
    fi
elif command -v telnet &> /dev/null; then
    echo "Testing TCP connectivity using telnet..."
    if timeout 5 bash -c "echo 'quit' | telnet $EXTERNAL_IP $POSTGRES_PORT" 2>&1 | grep -q "Connected\|Escape"; then
        print_result "TCP Connectivity" 0 "Port $POSTGRES_PORT is reachable on $EXTERNAL_IP"
    else
        print_result "TCP Connectivity" 1 "Port $POSTGRES_PORT is NOT reachable on $EXTERNAL_IP"
    fi
else
    echo -e "${YELLOW}⚠ SKIP${NC}: TCP Connectivity - Neither nc nor telnet available"
    echo ""
fi

# Test 4: Get PostgreSQL password from secret
echo "Test 4: Retrieve PostgreSQL Credentials"
echo "----------------------------------------"

PGPASSWORD=$(kubectl get secret -n "$NAMESPACE" postgres-ha-postgresql-credentials \
    -o jsonpath="{.data.postgres-password}" 2>/dev/null | base64 -d || echo "")

if [ -n "$PGPASSWORD" ]; then
    print_result "Retrieve Credentials" 0 "Successfully retrieved postgres password from secret"
else
    print_result "Retrieve Credentials" 1 "Failed to retrieve postgres password"
    echo "Cannot proceed with PostgreSQL connectivity tests without credentials"
    exit 1
fi

# Test 5: PostgreSQL connectivity test (requires psql client)
echo "Test 5: PostgreSQL Protocol Connectivity"
echo "-----------------------------------------"

if command -v psql &> /dev/null; then
    echo "Testing PostgreSQL connectivity using psql client..."

    # Test connection and get version
    export PGPASSWORD
    if POSTGRES_VERSION=$(psql -h "$EXTERNAL_IP" -p "$POSTGRES_PORT" -U "$TEST_USER" -d "$TEST_DATABASE" \
        -t -c "SELECT version();" 2>/dev/null); then
        print_result "PostgreSQL Connection" 0 "Successfully connected to PostgreSQL"
        echo "  PostgreSQL version: $(echo "$POSTGRES_VERSION" | head -n1 | xargs)"
    else
        print_result "PostgreSQL Connection" 1 "Failed to connect to PostgreSQL via external IP"
        echo "Troubleshooting tips:"
        echo "  - Verify credentials are correct"
        echo "  - Check PostgreSQL logs: kubectl logs -n $NAMESPACE $SERVICE_NAME-0 -c postgresql"
        echo "  - Verify pg_hba.conf allows connections from your IP"
    fi
else
    echo -e "${YELLOW}⚠ SKIP${NC}: PostgreSQL Connection - psql client not available"
    echo "  To run this test, install PostgreSQL client:"
    echo "  - macOS: brew install postgresql"
    echo "  - Ubuntu/Debian: apt-get install postgresql-client"
    echo "  - RHEL/CentOS: yum install postgresql"
    echo ""
fi

# Test 6: Query execution test
echo "Test 6: Query Execution via External IP"
echo "----------------------------------------"

if command -v psql &> /dev/null; then
    echo "Executing test query..."

    export PGPASSWORD
    if RESULT=$(psql -h "$EXTERNAL_IP" -p "$POSTGRES_PORT" -U "$TEST_USER" -d "$TEST_DATABASE" \
        -t -c "SELECT current_database(), current_user, inet_server_addr(), inet_server_port();" 2>/dev/null); then
        print_result "Query Execution" 0 "Successfully executed query"
        echo "  Database: $(echo "$RESULT" | awk '{print $1}')"
        echo "  User: $(echo "$RESULT" | awk '{print $2}')"
        echo "  Server: $(echo "$RESULT" | awk '{print $3}'):$(echo "$RESULT" | awk '{print $4}')"
    else
        print_result "Query Execution" 1 "Failed to execute query"
    fi
else
    echo -e "${YELLOW}⚠ SKIP${NC}: Query Execution - psql client not available"
    echo ""
fi

# Test 7: Connection latency test
echo "Test 7: Connection Latency Test"
echo "--------------------------------"

if command -v psql &> /dev/null; then
    echo "Measuring connection latency (5 attempts)..."

    LATENCY_TOTAL=0
    LATENCY_COUNT=0

    for i in {1..5}; do
        export PGPASSWORD
        START=$(date +%s%N)
        if psql -h "$EXTERNAL_IP" -p "$POSTGRES_PORT" -U "$TEST_USER" -d "$TEST_DATABASE" \
            -c "SELECT 1;" &>/dev/null; then
            END=$(date +%s%N)
            LATENCY=$((($END - $START) / 1000000)) # Convert to milliseconds
            echo "  Attempt $i: ${LATENCY}ms"
            LATENCY_TOTAL=$((LATENCY_TOTAL + LATENCY))
            ((LATENCY_COUNT++))
        fi
    done

    if [ $LATENCY_COUNT -gt 0 ]; then
        AVG_LATENCY=$((LATENCY_TOTAL / LATENCY_COUNT))
        if [ $AVG_LATENCY -lt 5000 ]; then
            print_result "Connection Latency" 0 "Average latency: ${AVG_LATENCY}ms (target: <5000ms)"
        else
            print_result "Connection Latency" 1 "Average latency: ${AVG_LATENCY}ms (exceeds 5000ms target)"
        fi
    else
        print_result "Connection Latency" 1 "Failed to measure latency"
    fi
else
    echo -e "${YELLOW}⚠ SKIP${NC}: Connection Latency - psql client not available"
    echo ""
fi

# Test 8: MetalLB speaker pod health
echo "Test 8: MetalLB Infrastructure Health"
echo "--------------------------------------"

SPEAKER_PODS=$(kubectl get pods -n metallb-system -l component=speaker \
    -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")

if echo "$SPEAKER_PODS" | grep -q "Running"; then
    RUNNING_COUNT=$(echo "$SPEAKER_PODS" | tr ' ' '\n' | grep -c "Running" || echo "0")
    print_result "MetalLB Speakers" 0 "MetalLB speaker pods running: $RUNNING_COUNT"
else
    print_result "MetalLB Speakers" 1 "MetalLB speaker pods not running properly"
fi

# Test 9: IP pool configuration
echo "Test 9: MetalLB IP Pool Configuration"
echo "--------------------------------------"

IP_POOLS=$(kubectl get ipaddresspool -n metallb-system -o name 2>/dev/null | wc -l)

if [ "$IP_POOLS" -gt 0 ]; then
    print_result "IP Pool Configuration" 0 "Found $IP_POOLS MetalLB IP pool(s)"
    kubectl get ipaddresspool -n metallb-system 2>/dev/null || true
    echo ""
else
    print_result "IP Pool Configuration" 1 "No MetalLB IP pools configured"
fi

# Summary
echo "================================================"
echo "Test Summary"
echo "================================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "External access to PostgreSQL is working correctly."
    echo "Connection string: postgresql://$TEST_USER:<password>@$EXTERNAL_IP:$POSTGRES_PORT/$TEST_DATABASE"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Please review the failed tests above and check:"
    echo "  1. MetalLB is properly installed and configured"
    echo "  2. LoadBalancer service has been created"
    echo "  3. External IP has been assigned"
    echo "  4. Network allows connectivity to port $POSTGRES_PORT"
    echo "  5. PostgreSQL is configured to accept external connections"
    exit 1
fi
