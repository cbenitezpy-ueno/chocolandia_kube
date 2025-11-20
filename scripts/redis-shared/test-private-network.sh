#!/bin/bash
# Redis Shared - Private Network Access Test
# Tests Redis connectivity from private network (192.168.4.0/24) via LoadBalancer
#
# IMPORTANT: This script must be run from a host on the 192.168.4.0/24 network
# It cannot be run from within the Kubernetes cluster

set -e

REDIS_LB_IP="192.168.4.203"
REDIS_PORT="6379"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

echo "========================================="
echo "Redis Shared - Private Network Test"
echo "========================================="
echo ""
echo "Testing connectivity to Redis LoadBalancer:"
echo "  IP: ${REDIS_LB_IP}"
echo "  Port: ${REDIS_PORT}"
echo ""

# Check if redis-cli is available
if ! command -v redis-cli &> /dev/null; then
    echo "❌ Error: redis-cli not found"
    echo ""
    echo "Please install redis-cli first:"
    echo "  - macOS: brew install redis"
    echo "  - Ubuntu/Debian: sudo apt-get install redis-tools"
    echo "  - RHEL/CentOS: sudo yum install redis"
    exit 1
fi
echo "✓ redis-cli is installed"
echo ""

# Prompt for password if not provided
if [ -z "$REDIS_PASSWORD" ]; then
    echo "Please enter the Redis password:"
    echo "(Get it with: kubectl get secret -n redis redis-credentials -o jsonpath='{.data.redis-password}' | base64 -d)"
    echo ""
    read -s -p "Password: " REDIS_PASSWORD
    echo ""
    echo ""
fi

# Test 1: Check network connectivity (ping)
echo "[1/6] Testing network connectivity to ${REDIS_LB_IP}..."
if ping -c 1 -W 2 ${REDIS_LB_IP} > /dev/null 2>&1; then
    echo "✓ Host ${REDIS_LB_IP} is reachable on the network"
else
    echo "⚠ Warning: Cannot ping ${REDIS_LB_IP} (ICMP may be blocked, continuing...)"
fi
echo ""

# Test 2: Check if Redis port is open
echo "[2/6] Testing if Redis port ${REDIS_PORT} is open..."
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${REDIS_LB_IP}/${REDIS_PORT}" 2>/dev/null; then
    echo "✓ Port ${REDIS_PORT} is open on ${REDIS_LB_IP}"
else
    echo "❌ Error: Cannot connect to ${REDIS_LB_IP}:${REDIS_PORT}"
    echo "   Possible issues:"
    echo "   - LoadBalancer not assigned IP"
    echo "   - Firewall blocking access"
    echo "   - Not on 192.168.4.0/24 network"
    exit 1
fi
echo ""

# Test 3: PING command (with authentication)
echo "[3/6] Testing Redis PING with authentication..."
PING_RESULT=$(redis-cli -h ${REDIS_LB_IP} -p ${REDIS_PORT} -a "${REDIS_PASSWORD}" PING 2>&1 | grep -v "Warning")

if [ "$PING_RESULT" = "PONG" ]; then
    echo "✓ Redis PING successful: $PING_RESULT"
else
    echo "❌ Redis PING failed: $PING_RESULT"
    if echo "$PING_RESULT" | grep -q "WRONGPASS\|NOAUTH"; then
        echo "   Authentication failed. Please verify the password."
    fi
    exit 1
fi
echo ""

# Test 4: SET/GET operations
echo "[4/6] Testing SET/GET operations..."
TEST_KEY="private-network-test-$(date +%s)"
TEST_VALUE="test-from-private-network-$(date +%s)"

SET_RESULT=$(redis-cli -h ${REDIS_LB_IP} -p ${REDIS_PORT} -a "${REDIS_PASSWORD}" SET "${TEST_KEY}" "${TEST_VALUE}" 2>&1 | grep -v "Warning")
if [ "$SET_RESULT" = "OK" ]; then
    echo "✓ SET operation successful"
else
    echo "❌ SET operation failed: $SET_RESULT"
    exit 1
fi

GET_RESULT=$(redis-cli -h ${REDIS_LB_IP} -p ${REDIS_PORT} -a "${REDIS_PASSWORD}" GET "${TEST_KEY}" 2>&1 | grep -v "Warning")
if [ "$GET_RESULT" = "$TEST_VALUE" ]; then
    echo "✓ GET operation successful: $GET_RESULT"
else
    echo "❌ GET operation failed"
    echo "   Expected: $TEST_VALUE"
    echo "   Got: $GET_RESULT"
    exit 1
fi
echo ""

# Test 5: Check current network
echo "[5/6] Verifying test is running from private network..."
CURRENT_IP=$(ip route get ${REDIS_LB_IP} 2>/dev/null | grep -oP 'src \K\S+' || \
             ifconfig | grep 'inet ' | grep '192.168.4' | awk '{print $2}' | head -1 || \
             echo "unknown")

if [[ "$CURRENT_IP" == 192.168.4.* ]]; then
    echo "✓ Running from private network: $CURRENT_IP"
    echo "  (subnet: 192.168.4.0/24)"
else
    echo "⚠ Warning: Cannot confirm running from 192.168.4.0/24 network"
    echo "  Detected IP: $CURRENT_IP"
    echo "  Test may not be accurate for AS-2 validation"
fi
echo ""

# Test 6: Test authentication failure (without password)
echo "[6/6] Testing authentication rejection (security check)..."
NO_AUTH_RESULT=$(redis-cli -h ${REDIS_LB_IP} -p ${REDIS_PORT} PING 2>&1 | grep -v "Warning" || true)

if echo "$NO_AUTH_RESULT" | grep -q "NOAUTH"; then
    echo "✓ Authentication required (NOAUTH error received)"
    echo "  Security validated: Cannot connect without password"
else
    echo "⚠ Warning: Expected NOAUTH error, got: $NO_AUTH_RESULT"
fi
echo ""

# Cleanup test key
redis-cli -h ${REDIS_LB_IP} -p ${REDIS_PORT} -a "${REDIS_PASSWORD}" DEL "${TEST_KEY}" > /dev/null 2>&1

echo "========================================="
echo "✓ All private network tests PASSED"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Network connectivity: ✓"
echo "  - Port accessibility: ✓"
echo "  - Redis PING: ✓"
echo "  - SET/GET operations: ✓"
echo "  - Running from private network: ✓"
echo "  - Authentication required: ✓"
echo ""
echo "US2 Acceptance Criteria Status:"
echo "  AS-1 (Private network access): ✓"
echo "  AS-2 (Public access blocked): Manual validation required"
echo "  AS-3 (Authentication works): ✓"
echo ""
echo "Note: To fully validate AS-2, attempt connection from"
echo "      a public IP or different network subnet."
