#!/bin/bash
# PostgreSQL Data Persistence Test
# Feature 011: PostgreSQL Cluster Database Service
# User Story 1: Application Database Connectivity
#
# Tests that data persists after pod restarts (validates PersistentVolume functionality)

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

NAMESPACE="${NAMESPACE:-postgresql}"
SERVICE_NAME="${SERVICE_NAME:-postgres-ha-postgresql}"
SECRET_NAME="${SECRET_NAME:-postgres-ha-postgresql-credentials}"
PRIMARY_POD="${PRIMARY_POD:-postgres-ha-postgresql-0}"
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

    if ! kubectl get pod -n "$NAMESPACE" "$PRIMARY_POD" &> /dev/null; then
        log_error "Primary pod $PRIMARY_POD not found in namespace $NAMESPACE"
        exit 1
    fi

    log_info "Prerequisites OK"
}

get_postgres_password() {
    kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" \
        -o jsonpath="{.data.postgres-password}" 2>/dev/null | base64 -d || echo ""
}

wait_for_pod_ready() {
    local pod_name=$1
    local max_wait=180 # 3 minutes
    local elapsed=0

    log_info "Waiting for pod $pod_name to be ready..."

    while [ $elapsed -lt $max_wait ]; do
        if kubectl get pod -n "$NAMESPACE" "$pod_name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
            log_info "Pod $pod_name is ready"
            return 0
        fi

        sleep 5
        ((elapsed+=5))
        log_info "  Waiting... ($elapsed/$max_wait seconds)"
    done

    log_error "Pod $pod_name did not become ready within $max_wait seconds"
    return 1
}

# ==============================================================================
# Test 1: Create Test Data
# ==============================================================================

test_create_data() {
    log_info "Test 1: Create Test Data"
    log_info "Creating test database and inserting data..."

    local postgres_password
    postgres_password=$(get_postgres_password)

    if [ -z "$postgres_password" ]; then
        log_error "✗ Could not retrieve postgres password"
        return 1
    fi

    local test_db="persistence_test_db"
    local test_table="persistence_test_table"

    # Create test database
    log_info "  Creating database: $test_db"
    kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -c "DROP DATABASE IF EXISTS $test_db;" || true

    if ! kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -c "CREATE DATABASE $test_db;"; then
        log_error "✗ Failed to create database"
        return 1
    fi

    # Create table and insert test data
    log_info "  Creating table and inserting test data..."
    if ! kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -d "$test_db" -c "CREATE TABLE $test_table (id SERIAL PRIMARY KEY, data TEXT, created_at TIMESTAMP DEFAULT NOW());"; then
        log_error "✗ Failed to create table"
        return 1
    fi

    # Insert multiple rows
    for i in {1..10}; do
        kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
            psql -U postgres -d "$test_db" -c "INSERT INTO $test_table (data) VALUES ('test_data_$i');" || true
    done

    # Verify data was inserted
    local row_count
    row_count=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -d "$test_db" -t -c "SELECT COUNT(*) FROM $test_table;" | tr -d '[:space:]')

    if [ "$row_count" -ne 10 ]; then
        log_error "✗ Expected 10 rows, found $row_count"
        return 1
    fi

    log_info "✓ Test data created successfully (10 rows inserted)"
    return 0
}

# ==============================================================================
# Test 2: Delete Pod (Trigger Restart)
# ==============================================================================

test_delete_pod() {
    log_info "Test 2: Delete Pod (Trigger Restart)"
    log_info "Deleting primary pod to test persistence..."

    # Delete the pod
    if kubectl delete pod -n "$NAMESPACE" "$PRIMARY_POD" --wait=false; then
        log_info "✓ Pod deletion initiated"
    else
        log_error "✗ Failed to delete pod"
        return 1
    fi

    # Wait a moment for deletion to start
    sleep 5

    # Wait for pod to be recreated and ready
    if wait_for_pod_ready "$PRIMARY_POD"; then
        log_info "✓ Pod has been recreated and is ready"
        return 0
    else
        log_error "✗ Pod did not become ready after restart"
        return 1
    fi
}

# ==============================================================================
# Test 3: Verify Data Persisted
# ==============================================================================

test_verify_data() {
    log_info "Test 3: Verify Data Persisted"
    log_info "Verifying test data still exists after pod restart..."

    local test_db="persistence_test_db"
    local test_table="persistence_test_table"

    # Wait a bit for PostgreSQL to be fully ready
    sleep 10

    # Check if database still exists
    local db_exists
    db_exists=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -t -c "SELECT 1 FROM pg_database WHERE datname='$test_db';" 2>/dev/null | tr -d '[:space:]' || echo "")

    if [ "$db_exists" != "1" ]; then
        log_error "✗ Database $test_db does not exist after restart"
        return 1
    fi

    log_info "  Database $test_db exists ✓"

    # Verify row count
    local row_count
    row_count=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -d "$test_db" -t -c "SELECT COUNT(*) FROM $test_table;" 2>/dev/null | tr -d '[:space:]' || echo "0")

    if [ "$row_count" -ne 10 ]; then
        log_error "✗ Expected 10 rows, found $row_count after restart"
        return 1
    fi

    log_info "  Row count: $row_count ✓"

    # Verify actual data
    local sample_data
    sample_data=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -d "$test_db" -t -c "SELECT data FROM $test_table WHERE id=5;" 2>/dev/null | tr -d '[:space:]' || echo "")

    if [ "$sample_data" != "test_data_5" ]; then
        log_error "✗ Data integrity check failed. Expected 'test_data_5', found '$sample_data'"
        return 1
    fi

    log_info "  Data integrity verified ✓"
    log_info "✓ All data persisted successfully after pod restart!"
    return 0
}

# ==============================================================================
# Test 4: Cleanup
# ==============================================================================

test_cleanup() {
    log_info "Test 4: Cleanup"
    log_info "Cleaning up test database..."

    local test_db="persistence_test_db"

    # Drop test database
    if kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -c "DROP DATABASE IF EXISTS $test_db;"; then
        log_info "✓ Test database cleaned up"
        return 0
    else
        log_warn "⚠ Failed to cleanup test database (may need manual cleanup)"
        return 0 # Don't fail the test due to cleanup issues
    fi
}

# ==============================================================================
# Main Test Execution
# ==============================================================================

main() {
    log_info "=========================================="
    log_info "PostgreSQL Data Persistence Test"
    log_info "=========================================="
    log_info "Namespace: $NAMESPACE"
    log_info "Primary Pod: $PRIMARY_POD"
    log_info "=========================================="
    echo

    check_prerequisites
    echo

    local failed=0

    test_create_data || ((failed++))
    echo

    # Only proceed with restart test if data creation succeeded
    if [ $failed -eq 0 ]; then
        test_delete_pod || ((failed++))
        echo

        test_verify_data || ((failed++))
        echo

        test_cleanup
        echo
    else
        log_error "Skipping restart test due to data creation failure"
    fi

    log_info "=========================================="
    if [ $failed -eq 0 ]; then
        log_info "✓ All persistence tests passed!"
        log_info "  Data survived pod restart successfully"
        log_info "=========================================="
        exit 0
    else
        log_error "✗ $failed test(s) failed"
        log_info "=========================================="
        exit 1
    fi
}

main "$@"
