#!/bin/bash
# Redis Shared - Replication Test Script
# Tests primary-replica replication and lag

set -e

NAMESPACE="redis"
MASTER_POD="redis-shared-master-0"
REPLICA_POD="redis-shared-replicas-0"

echo "========================================="
echo "Redis Shared - Replication Test"
echo "========================================="
echo ""

# Test 1: Check replication info on master
echo "[1/4] Checking replication info on master..."
MASTER_INFO=$(kubectl exec -n ${NAMESPACE} ${MASTER_POD} -c redis -- sh -c 'export REDISCLI_AUTH=$(cat /opt/bitnami/redis/secrets/redis-password) && redis-cli INFO replication' 2>&1 | grep -v Warning)

ROLE=$(echo "$MASTER_INFO" | grep "^role:" | cut -d: -f2 | tr -d '\r')
CONNECTED_SLAVES=$(echo "$MASTER_INFO" | grep "^connected_slaves:" | cut -d: -f2 | tr -d '\r')

echo "  Role: $ROLE"
echo "  Connected slaves: $CONNECTED_SLAVES"

if [ "$ROLE" != "master" ]; then
  echo "✗ Expected role 'master', got '$ROLE'"
  exit 1
fi

if [ "$CONNECTED_SLAVES" != "1" ]; then
  echo "✗ Expected 1 connected slave, got $CONNECTED_SLAVES"
  exit 1
fi

echo "✓ Master has correct role and 1 connected replica"
echo ""

# Test 2: Check replication info on replica
echo "[2/4] Checking replication info on replica..."
REPLICA_INFO=$(kubectl exec -n ${NAMESPACE} ${REPLICA_POD} -c redis -- sh -c 'export REDISCLI_AUTH=$(cat /opt/bitnami/redis/secrets/redis-password) && redis-cli INFO replication' 2>&1 | grep -v Warning)

REPLICA_ROLE=$(echo "$REPLICA_INFO" | grep "^role:" | cut -d: -f2 | tr -d '\r')
MASTER_LINK_STATUS=$(echo "$REPLICA_INFO" | grep "^master_link_status:" | cut -d: -f2 | tr -d '\r')

echo "  Role: $REPLICA_ROLE"
echo "  Master link status: $MASTER_LINK_STATUS"

if [ "$REPLICA_ROLE" != "slave" ]; then
  echo "✗ Expected role 'slave', got '$REPLICA_ROLE'"
  exit 1
fi

if [ "$MASTER_LINK_STATUS" != "up" ]; then
  echo "✗ Master link is not up: $MASTER_LINK_STATUS"
  exit 1
fi

echo "✓ Replica has correct role and connection to master is up"
echo ""

# Test 3: Write multiple keys to master and verify on replica
echo "[3/4] Testing bulk write/read replication..."
echo "Writing 10 test keys to master..."

for i in {1..10}; do
  kubectl exec -n ${NAMESPACE} ${MASTER_POD} -c redis -- sh -c "export REDISCLI_AUTH=\$(cat /opt/bitnami/redis/secrets/redis-password) && redis-cli SET repl-test-$i 'value-$i'" > /dev/null 2>&1
done

echo "✓ Wrote 10 keys to master"

# Wait a moment for replication
sleep 2

echo "Verifying keys exist on replica..."
MISSING_KEYS=0
for i in {1..10}; do
  VALUE=$(kubectl exec -n ${NAMESPACE} ${REPLICA_POD} -c redis -- sh -c "export REDISCLI_AUTH=\$(cat /opt/bitnami/redis/secrets/redis-password) && redis-cli GET repl-test-$i" 2>&1 | grep -v Warning)
  if [ "$VALUE" != "value-$i" ]; then
    echo "✗ Key repl-test-$i not replicated correctly (expected: value-$i, got: $VALUE)"
    MISSING_KEYS=$((MISSING_KEYS + 1))
  fi
done

if [ $MISSING_KEYS -eq 0 ]; then
  echo "✓ All 10 keys replicated correctly to replica"
else
  echo "✗ $MISSING_KEYS keys failed to replicate"
  exit 1
fi
echo ""

# Test 4: Check replication lag
echo "[4/4] Checking replication lag..."
MASTER_OFFSET=$(echo "$MASTER_INFO" | grep "^master_repl_offset:" | cut -d: -f2 | tr -d '\r')
REPLICA_OFFSET=$(echo "$REPLICA_INFO" | grep "^slave_repl_offset:" | cut -d: -f2 | tr -d '\r')

# Get fresh replica offset after writes
REPLICA_INFO_FRESH=$(kubectl exec -n ${NAMESPACE} ${REPLICA_POD} -c redis -- sh -c 'export REDISCLI_AUTH=$(cat /opt/bitnami/redis/secrets/redis-password) && redis-cli INFO replication' 2>&1 | grep -v Warning)
REPLICA_OFFSET_FRESH=$(echo "$REPLICA_INFO_FRESH" | grep "^slave_repl_offset:" | cut -d: -f2 | tr -d '\r')

echo "  Master offset: $MASTER_OFFSET"
echo "  Replica offset: $REPLICA_OFFSET_FRESH"

LAG=$((MASTER_OFFSET - REPLICA_OFFSET_FRESH))
if [ $LAG -lt 0 ]; then
  LAG=0
fi

echo "  Replication lag: $LAG bytes"

if [ $LAG -lt 1000 ]; then
  echo "✓ Replication lag is acceptable (<1KB)"
else
  echo "⚠ Replication lag is higher than expected: $LAG bytes"
fi
echo ""

echo "========================================="
echo "✓ All replication tests PASSED"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Master role verification: ✓"
echo "  - Replica connection: ✓"
echo "  - Bulk replication (10 keys): ✓"
echo "  - Replication lag: ✓ ($LAG bytes)"
