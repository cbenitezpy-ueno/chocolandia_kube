#!/bin/bash
# Redis Shared - Connectivity Test Script
# Tests Redis connectivity from within the cluster

set -e

NAMESPACE="redis"
MASTER_SVC="redis-shared-master.redis.svc.cluster.local"
REPLICA_SVC="redis-shared-replicas.redis.svc.cluster.local"
SECRET_NAME="redis-credentials"

echo "========================================="
echo "Redis Shared - Connectivity Test"
echo "========================================="
echo ""

# Get Redis password
echo "[1/5] Retrieving Redis password from Secret..."
REDIS_PASSWORD=$(kubectl get secret -n ${NAMESPACE} ${SECRET_NAME} -o jsonpath='{.data.redis-password}' | base64 -d)
echo "✓ Password retrieved (${#REDIS_PASSWORD} characters)"
echo ""

# Create test pod
echo "[2/5] Creating test pod..."
kubectl run redis-connectivity-test \
  --namespace=${NAMESPACE} \
  --image=redis:8.2 \
  --restart=Never \
  --command -- sleep 3600 > /dev/null 2>&1 || echo "Pod already exists"

echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod/redis-connectivity-test -n ${NAMESPACE} --timeout=30s
echo "✓ Test pod ready"
echo ""

# Test 1: PING master
echo "[3/5] Testing PING to master..."
PING_RESULT=$(kubectl exec -n ${NAMESPACE} redis-connectivity-test -- sh -c "export REDISCLI_AUTH='${REDIS_PASSWORD}' && redis-cli -h ${MASTER_SVC} -p 6379 PING 2>&1" | grep -v Warning)
if [ "$PING_RESULT" = "PONG" ]; then
  echo "✓ Master PING successful: $PING_RESULT"
else
  echo "✗ Master PING failed: $PING_RESULT"
  exit 1
fi
echo ""

# Test 2: SET/GET operations on master
echo "[4/5] Testing SET/GET operations on master..."
SET_RESULT=$(kubectl exec -n ${NAMESPACE} redis-connectivity-test -- sh -c "export REDISCLI_AUTH='${REDIS_PASSWORD}' && redis-cli -h ${MASTER_SVC} -p 6379 SET test-connectivity 'validation-$(date +%s)' 2>&1" | grep -v Warning)
if [ "$SET_RESULT" = "OK" ]; then
  echo "✓ SET operation successful"
else
  echo "✗ SET operation failed: $SET_RESULT"
  exit 1
fi

GET_RESULT=$(kubectl exec -n ${NAMESPACE} redis-connectivity-test -- sh -c "export REDISCLI_AUTH='${REDIS_PASSWORD}' && redis-cli -h ${MASTER_SVC} -p 6379 GET test-connectivity 2>&1" | grep -v Warning)
echo "✓ GET operation successful: $GET_RESULT"
echo ""

# Test 3: Read from replica
echo "[5/5] Testing read from replica..."
REPLICA_READ=$(kubectl exec -n ${NAMESPACE} redis-connectivity-test -- sh -c "export REDISCLI_AUTH='${REDIS_PASSWORD}' && redis-cli -h ${REPLICA_SVC} -p 6379 GET test-connectivity 2>&1" | grep -v Warning)
if [ "$REPLICA_READ" = "$GET_RESULT" ]; then
  echo "✓ Replica read successful: $REPLICA_READ"
  echo "✓ Data replicated correctly from master to replica"
else
  echo "✗ Replica read mismatch"
  echo "  Master value: $GET_RESULT"
  echo "  Replica value: $REPLICA_READ"
  exit 1
fi
echo ""

# Cleanup
echo "Cleaning up test pod..."
kubectl delete pod redis-connectivity-test -n ${NAMESPACE} > /dev/null 2>&1
echo "✓ Test pod deleted"
echo ""

echo "========================================="
echo "✓ All connectivity tests PASSED"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Master PING: ✓"
echo "  - Master SET/GET: ✓"
echo "  - Replica read: ✓"
echo "  - Data replication: ✓"
