#!/bin/bash
# PostgreSQL Replication Test
# Feature 011: PostgreSQL Cluster Database Service
# User Story 1: Application Database Connectivity
#
# Tests that replication is working correctly between primary and replica

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

NAMESPACE="${NAMESPACE:-postgresql}"
SECRET_NAME="${SECRET_NAME:-postgres-ha-postgresql-credentials}"
PRIMARY_POD="${PRIMARY_POD:-postgres-ha-postgresql-0}"
REPLICA_POD="${REPLICA_POD:-postgres-ha-postgresql-1}"
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

    if ! kubectl get pod -n "$NAMESPACE" "$REPLICA_POD" &> /dev/null; then
        log_error "Replica pod $REPLICA_POD not found in namespace $NAMESPACE"
        exit 1
    fi

    log_info "Prerequisites OK"
}

get_postgres_password() {
    kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" \
        -o jsonpath="{.data.postgres-password}" 2>/dev/null | base64 -d || echo ""
}

# ==============================================================================
# Test 1: Verify Replication Connection
# ==============================================================================

test_replication_connection() {
    log_info "Test 1: Verify Replication Connection"
    log_info "Checking if replica is connected to primary..."

    # Query pg_stat_replication on primary
    local replication_info
    replication_info=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -t -c "SELECT application_name, state, sync_state FROM pg_stat_replication;" 2>/dev/null || echo "")

    if [ -z "$replication_info" ]; then
        log_error "✗ No replication connections found"
        log_error "  This indicates the replica is not connected to the primary"
        return 1
    fi

    log_info "  Replication connections:"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        log_info "    $line"
    done <<< "$replication_info"

    # Check if at least one connection is streaming
    if echo "$replication_info" | grep -q "streaming"; then
        log_info "✓ Replication connection active (streaming)"
        return 0
    else
        log_error "✗ No active streaming replication found"
        return 1
    fi
}

# ==============================================================================
# Test 2: Check Replication Lag
# ==============================================================================

test_replication_lag() {
    log_info "Test 2: Check Replication Lag"
    log_info "Measuring replication lag..."

    # Get replication lag from primary
    local lag_info
    lag_info=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -t -c "SELECT application_name, replay_lag, write_lag, flush_lag FROM pg_stat_replication;" 2>/dev/null || echo "")

    if [ -z "$lag_info" ]; then
        log_error "✗ Could not retrieve replication lag information"
        return 1
    fi

    log_info "  Replication lag:"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        log_info "    $line"
    done <<< "$lag_info"

    # For asynchronous replication, some lag is acceptable
    # We just warn if lag appears high, but don't fail the test
    if echo "$lag_info" | grep -q "00:00:00"; then
        log_info "✓ Replication lag is minimal (< 1 second)"
    else
        log_warn "⚠ Replication lag detected (this is normal for asynchronous replication)"
    fi

    return 0
}

# ==============================================================================
# Test 3: Test Data Replication
# ==============================================================================

test_data_replication() {
    log_info "Test 3: Test Data Replication"
    log_info "Writing data to primary and verifying it appears on replica..."

    local test_db="replication_test_db"
    local test_table="replication_test_table"

    # Create test database on primary
    log_info "  Creating test database on primary..."
    kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -c "DROP DATABASE IF EXISTS $test_db;" || true

    if ! kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -c "CREATE DATABASE $test_db;"; then
        log_error "✗ Failed to create database on primary"
        return 1
    fi

    # Create table and insert data on primary
    log_info "  Creating table and inserting data on primary..."
    if ! kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -d "$test_db" -c "CREATE TABLE $test_table (id SERIAL PRIMARY KEY, data TEXT, written_at TIMESTAMP DEFAULT NOW());"; then
        log_error "✗ Failed to create table on primary"
        return 1
    fi

    # Insert test data
    local test_value="replication_test_$(date +%s)"
    if ! kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -d "$test_db" -c "INSERT INTO $test_table (data) VALUES ('$test_value');"; then
        log_error "✗ Failed to insert data on primary"
        return 1
    fi

    log_info "  Data written to primary: $test_value"

    # Wait for replication to catch up (give it a few seconds)
    log_info "  Waiting for replication to sync (5 seconds)..."
    sleep 5

    # Verify database exists on replica
    log_info "  Verifying database exists on replica..."
    local db_exists
    db_exists=$(kubectl exec -n "$NAMESPACE" "$REPLICA_POD" -c postgresql -- \
        psql -U postgres -t -c "SELECT 1 FROM pg_database WHERE datname='$test_db';" 2>/dev/null | tr -d '[:space:]' || echo "")

    if [ "$db_exists" != "1" ]; then
        log_error "✗ Database does not exist on replica"
        return 1
    fi

    log_info "  Database exists on replica ✓"

    # Verify data exists on replica
    log_info "  Verifying data on replica..."
    local replica_data
    replica_data=$(kubectl exec -n "$NAMESPACE" "$REPLICA_POD" -c postgresql -- \
        psql -U postgres -d "$test_db" -t -c "SELECT data FROM $test_table WHERE data='$test_value';" 2>/dev/null | tr -d '[:space:]' || echo "")

    if [ "$replica_data" != "$test_value" ]; then
        log_error "✗ Data not found on replica. Expected: $test_value, Found: $replica_data"
        return 1
    fi

    log_info "  Data verified on replica ✓"
    log_info "✓ Data replication working correctly!"

    # Cleanup
    log_info "  Cleaning up test database..."
    kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -c "DROP DATABASE IF EXISTS $test_db;" &>/dev/null || true

    return 0
}

# ==============================================================================
# Test 4: Verify Replica is Read-Only
# ==============================================================================

test_replica_readonly() {
    log_info "Test 4: Verify Replica is Read-Only"
    log_info "Attempting to write to replica (should fail)..."

    # Try to create a database on the replica (should fail)
    if kubectl exec -n "$NAMESPACE" "$REPLICA_POD" -c postgresql -- \
        psql -U postgres -c "CREATE DATABASE readonly_test_db;" &>/dev/null; then
        log_error "✗ Replica accepted write operation (should be read-only!)"
        # Cleanup if it somehow succeeded
        kubectl exec -n "$NAMESPACE" "$REPLICA_POD" -c postgresql -- \
            psql -U postgres -c "DROP DATABASE readonly_test_db;" &>/dev/null || true
        return 1
    else
        log_info "✓ Replica correctly rejected write operation (read-only)"
        return 0
    fi
}

# ==============================================================================
# Test 5: Replication Slot Status
# ==============================================================================

test_replication_slots() {
    log_info "Test 5: Replication Slot Status"
    log_info "Checking replication slot status..."

    local slot_info
    slot_info=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgresql -- \
        psql -U postgres -t -c "SELECT slot_name, slot_type, active, restart_lsn FROM pg_replication_slots;" 2>/dev/null || echo "")

    if [ -z "$slot_info" ]; then
        log_warn "⚠ No replication slots found (this may be expected for streaming replication)"
        return 0
    fi

    log_info "  Replication slots:"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        log_info "    $line"
    done <<< "$slot_info"

    log_info "✓ Replication slot information retrieved"
    return 0
}

# ==============================================================================
# Main Test Execution
# ==============================================================================

main() {
    log_info "=========================================="
    log_info "PostgreSQL Replication Test"
    log_info "=========================================="
    log_info "Namespace: $NAMESPACE"
    log_info "Primary Pod: $PRIMARY_POD"
    log_info "Replica Pod: $REPLICA_POD"
    log_info "=========================================="
    echo

    check_prerequisites
    echo

    local failed=0

    test_replication_connection || ((failed++))
    echo

    test_replication_lag || ((failed++))
    echo

    test_data_replication || ((failed++))
    echo

    test_replica_readonly || ((failed++))
    echo

    test_replication_slots || ((failed++))
    echo

    log_info "=========================================="
    if [ $failed -eq 0 ]; then
        log_info "✓ All replication tests passed!"
        log_info "  Primary-replica replication is working correctly"
        log_info "=========================================="
        exit 0
    else
        log_error "✗ $failed test(s) failed"
        log_info "=========================================="
        exit 1
    fi
}

main "$@"
