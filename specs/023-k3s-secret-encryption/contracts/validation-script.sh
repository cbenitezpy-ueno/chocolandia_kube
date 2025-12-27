#!/bin/bash
# K3s Secret Encryption Validation Script
#
# This script validates that secret encryption is properly configured
# Run on a K3s server node (master1 or nodo03)
#
# Usage: ./validation-script.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "K3s Secret Encryption Validation"
echo "=========================================="
echo ""

FAILED=0

# Test 1: Check if running as root
echo -n "[Test 1] Running as root... "
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${YELLOW}WARN${NC} - Some checks require root"
fi

# Test 2: K3s is running
echo -n "[Test 2] K3s service is running... "
if systemctl is-active --quiet k3s 2>/dev/null || systemctl is-active --quiet k3s-server 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} - K3s is not running"
    FAILED=1
fi

# Test 3: Encryption config file exists
echo -n "[Test 3] Encryption config file exists... "
ENCRYPTION_CONFIG="/var/lib/rancher/k3s/server/cred/encryption-config.json"
if [ -f "$ENCRYPTION_CONFIG" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} - $ENCRYPTION_CONFIG not found"
    echo "       Encryption may not be enabled"
    FAILED=1
fi

# Test 4: Encryption config permissions
echo -n "[Test 4] Encryption config has correct permissions... "
if [ -f "$ENCRYPTION_CONFIG" ]; then
    PERMS=$(stat -c "%a" "$ENCRYPTION_CONFIG" 2>/dev/null || stat -f "%Lp" "$ENCRYPTION_CONFIG" 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        echo -e "${GREEN}PASS${NC} (mode 600)"
    else
        echo -e "${YELLOW}WARN${NC} - Expected 600, got $PERMS"
    fi
else
    echo -e "${YELLOW}SKIP${NC} - File not found"
fi

# Test 5: Check encryption status via CLI
echo -n "[Test 5] k3s secrets-encrypt status... "
if k3s secrets-encrypt status 2>/dev/null | grep -q "Enabled"; then
    echo -e "${GREEN}PASS${NC} - Encryption is enabled"
else
    STATUS=$(k3s secrets-encrypt status 2>/dev/null | head -1 || echo "Command failed")
    echo -e "${RED}FAIL${NC} - $STATUS"
    FAILED=1
fi

# Test 6: Check rotation stage
echo -n "[Test 6] Encryption rotation stage... "
STAGE=$(k3s secrets-encrypt status 2>/dev/null | grep "Current Rotation Stage" | awk '{print $NF}' || echo "unknown")
if [ "$STAGE" = "reencrypt_finished" ] || [ "$STAGE" = "start" ]; then
    echo -e "${GREEN}PASS${NC} - Stage: $STAGE"
else
    echo -e "${YELLOW}WARN${NC} - Stage: $STAGE (may need re-encryption)"
fi

# Test 7: Create and verify test secret
echo -n "[Test 7] Create and verify test secret... "
TEST_SECRET_NAME="encryption-test-$(date +%s)"
if kubectl create secret generic "$TEST_SECRET_NAME" \
    --from-literal=test=encrypted-value \
    -n default 2>/dev/null; then

    # Verify we can read it back
    VALUE=$(kubectl get secret "$TEST_SECRET_NAME" -n default \
        -o jsonpath='{.data.test}' 2>/dev/null | base64 -d 2>/dev/null)

    if [ "$VALUE" = "encrypted-value" ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC} - Retrieved value doesn't match"
        FAILED=1
    fi

    # Cleanup
    kubectl delete secret "$TEST_SECRET_NAME" -n default 2>/dev/null || true
else
    echo -e "${RED}FAIL${NC} - Could not create test secret"
    FAILED=1
fi

# Test 8: Verify encryption at rest (requires root)
echo -n "[Test 8] Secrets encrypted in database... "
if [ "$(id -u)" -eq 0 ]; then
    DB_PATH="/var/lib/rancher/k3s/server/db/state.db"
    if [ -f "$DB_PATH" ]; then
        # Create a unique test secret
        TEST_VALUE="test-encryption-verification-$(date +%s)"
        kubectl create secret generic encryption-db-test \
            --from-literal=dbtest="$TEST_VALUE" \
            -n default 2>/dev/null || true

        sleep 2  # Wait for write

        # Check if plaintext value appears in database
        if sqlite3 "$DB_PATH" "SELECT value FROM kine WHERE name LIKE '%encryption-db-test%'" 2>/dev/null | strings | grep -q "$TEST_VALUE"; then
            echo -e "${RED}FAIL${NC} - Plaintext found in database!"
            FAILED=1
        else
            echo -e "${GREEN}PASS${NC} - No plaintext in database"
        fi

        # Cleanup
        kubectl delete secret encryption-db-test -n default 2>/dev/null || true
    else
        echo -e "${YELLOW}SKIP${NC} - Database not found at $DB_PATH"
    fi
else
    echo -e "${YELLOW}SKIP${NC} - Requires root access"
fi

# Summary
echo ""
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "Overall: ${GREEN}ALL CRITICAL TESTS PASSED${NC}"
    exit 0
else
    echo -e "Overall: ${RED}SOME TESTS FAILED${NC}"
    exit 1
fi
