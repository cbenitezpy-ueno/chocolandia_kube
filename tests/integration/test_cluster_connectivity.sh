#!/bin/bash
# PostgreSQL Cluster Connectivity Test
# Feature 011: PostgreSQL Cluster Database Service
# User Story 1: Application Database Connectivity
#
# Tests that applications running in Kubernetes cluster can connect to PostgreSQL

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

NAMESPACE="${NAMESPACE:-postgresql}"
SERVICE_NAME="${SERVICE_NAME:-postgres-ha-postgresql}"
SECRET_NAME="${SECRET_NAME:-postgres-ha-postgresql-credentials}"
KUBECONFIG="${KUBECONFIG:-terraform/environments/chocolandiadc-mvp/kubeconfig}"

export KUBECONFIG

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check KUBECONFIG."
        exit 1
    fi

    log_info "Prerequisites OK"
}

# ==============================================================================
# Test 1: DNS Resolution
# ==============================================================================

test_dns_resolution() {
    log_info "Test 1: DNS Resolution"
    log_info "Testing DNS resolution for PostgreSQL service..."

    local service_fqdn="${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"

    if kubectl run dns-test-$RANDOM --image=nicolaka/netshoot --rm -i --restart=Never -- \
        nslookup "$service_fqdn" &> /dev/null; then
        log_info "✓ DNS resolution successful: $service_fqdn"
        return 0
    else
        log_error "✗ DNS resolution failed for: $service_fqdn"
        return 1
    fi
}

# ==============================================================================
# Test 2: TCP Connectivity
# ==============================================================================

test_tcp_connectivity() {
    log_info "Test 2: TCP Connectivity"
    log_info "Testing TCP connectivity to PostgreSQL port 5432..."

    local service_fqdn="${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"

    if kubectl run tcp-test-$RANDOM --image=nicolaka/netshoot --rm -i --restart=Never -- \
        nc -zv "$service_fqdn" 5432 2>&1 | grep -q "succeeded"; then
        log_info "✓ TCP connectivity successful: $service_fqdn:5432"
        return 0
    else
        log_error "✗ TCP connectivity failed: $service_fqdn:5432"
        return 1
    fi
}

# ==============================================================================
# Test 3: PostgreSQL Authentication
# ==============================================================================

test_postgresql_auth() {
    log_info "Test 3: PostgreSQL Authentication"
    log_info "Testing PostgreSQL authentication with credentials..."

    # Get postgres password from secret
    local postgres_password
    postgres_password=$(kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" \
        -o jsonpath="{.data.postgres-password}" 2>/dev/null | base64 -d || echo "")

    if [ -z "$postgres_password" ]; then
        log_error "✗ Could not retrieve postgres password from secret"
        return 1
    fi

    local service_fqdn="${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"

    # Test connection using psql
    if kubectl run psql-test-$RANDOM --image=postgres:16 --rm -i --restart=Never --env="PGPASSWORD=$postgres_password" -- \
        psql -h "$service_fqdn" -U postgres -d postgres -c "SELECT 1;" &> /dev/null; then
        log_info "✓ PostgreSQL authentication successful"
        return 0
    else
        log_error "✗ PostgreSQL authentication failed"
        return 1
    fi
}

# ==============================================================================
# Test 4: Database Operations (Read/Write)
# ==============================================================================

test_database_operations() {
    log_info "Test 4: Database Operations (Read/Write)"
    log_info "Testing basic database operations..."

    # Get postgres password
    local postgres_password
    postgres_password=$(kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" \
        -o jsonpath="{.data.postgres-password}" | base64 -d)

    local service_fqdn="${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"
    local test_table="connectivity_test_$(date +%s)"

    # Create table
    log_info "  Creating test table: $test_table"
    if ! kubectl run psql-ops-test-$RANDOM --image=postgres:16 --rm -i --restart=Never --env="PGPASSWORD=$postgres_password" -- \
        psql -h "$service_fqdn" -U postgres -d postgres -c "CREATE TABLE $test_table (id SERIAL PRIMARY KEY, test_data TEXT);" &> /dev/null; then
        log_error "✗ Failed to create table"
        return 1
    fi

    # Insert data
    log_info "  Inserting test data..."
    if ! kubectl run psql-ops-test-$RANDOM --image=postgres:16 --rm -i --restart=Never --env="PGPASSWORD=$postgres_password" -- \
        psql -h "$service_fqdn" -U postgres -d postgres -c "INSERT INTO $test_table (test_data) VALUES ('connectivity_test');" &> /dev/null; then
        log_error "✗ Failed to insert data"
        return 1
    fi

    # Read data
    log_info "  Reading test data..."
    if ! kubectl run psql-ops-test-$RANDOM --image=postgres:16 --rm -i --restart=Never --env="PGPASSWORD=$postgres_password" -- \
        psql -h "$service_fqdn" -U postgres -d postgres -c "SELECT * FROM $test_table;" 2>&1 | grep -q "connectivity_test"; then
        log_error "✗ Failed to read data"
        return 1
    fi

    # Cleanup
    log_info "  Cleaning up test table..."
    kubectl run psql-ops-test-$RANDOM --image=postgres:16 --rm -i --restart=Never --env="PGPASSWORD=$postgres_password" -- \
        psql -h "$service_fqdn" -U postgres -d postgres -c "DROP TABLE $test_table;" &> /dev/null || true

    log_info "✓ Database operations successful"
    return 0
}

# ==============================================================================
# Main Test Execution
# ==============================================================================

main() {
    log_info "=========================================="
    log_info "PostgreSQL Cluster Connectivity Test"
    log_info "=========================================="
    log_info "Namespace: $NAMESPACE"
    log_info "Service: $SERVICE_NAME"
    log_info "=========================================="
    echo

    check_prerequisites
    echo

    local failed=0

    test_dns_resolution || ((failed++))
    echo

    test_tcp_connectivity || ((failed++))
    echo

    test_postgresql_auth || ((failed++))
    echo

    test_database_operations || ((failed++))
    echo

    log_info "=========================================="
    if [ $failed -eq 0 ]; then
        log_info "✓ All connectivity tests passed!"
        log_info "=========================================="
        exit 0
    else
        log_error "✗ $failed test(s) failed"
        log_info "=========================================="
        exit 1
    fi
}

main "$@"
