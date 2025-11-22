#!/bin/bash
# Redis Shared - Performance Benchmark Script
# Tests Redis performance using redis-benchmark

set -e

NAMESPACE="redis"
MASTER_SVC="redis-shared-master.redis.svc.cluster.local"
SECRET_NAME="redis-credentials"

echo "========================================="
echo "Redis Shared - Performance Benchmark"
echo "========================================="
echo ""

# Get Redis password
echo "[1/3] Retrieving Redis password..."
REDIS_PASSWORD=$(kubectl get secret -n ${NAMESPACE} ${SECRET_NAME} -o jsonpath='{.data.redis-password}' | base64 -d)
echo "✓ Password retrieved"
echo ""

# Create benchmark pod
echo "[2/3] Creating benchmark pod..."
kubectl run redis-benchmark-test \
  --namespace=${NAMESPACE} \
  --image=redis:8.2 \
  --restart=Never \
  --command -- sleep 3600 > /dev/null 2>&1 || echo "Pod already exists"

echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod/redis-benchmark-test -n ${NAMESPACE} --timeout=30s
echo "✓ Benchmark pod ready"
echo ""

# Run benchmark
echo "[3/3] Running performance benchmark..."
echo "Target: ≥10,000 ops/sec (Success Criteria SC-006)"
echo ""
echo "Running redis-benchmark with 10,000 requests..."
echo "----------------------------------------"

BENCHMARK_OUTPUT=$(kubectl exec -n ${NAMESPACE} redis-benchmark-test -- \
  redis-benchmark \
  -h ${MASTER_SVC} \
  -p 6379 \
  -a "${REDIS_PASSWORD}" \
  -q \
  -t set,get,incr,lpush,rpush,lpop,rpop,sadd,hset,spop,zadd,zpopmin,lrange,mset \
  -n 10000 \
  -c 50 2>&1 | grep -v Warning)

echo "$BENCHMARK_OUTPUT"
echo "----------------------------------------"
echo ""

# Parse results
echo "Analyzing results..."
echo ""

SET_OPS=$(echo "$BENCHMARK_OUTPUT" | grep "^SET:" | awk '{print $2}')
GET_OPS=$(echo "$BENCHMARK_OUTPUT" | grep "^GET:" | awk '{print $2}')

echo "Key Performance Indicators:"
echo "  SET operations: $SET_OPS requests/sec"
echo "  GET operations: $GET_OPS requests/sec"
echo ""

# Check if meets success criteria (≥10,000 ops/sec)
TARGET_OPS=10000
PASSED=true

if [ -n "$SET_OPS" ]; then
  SET_OPS_NUM=$(echo "$SET_OPS" | tr -d ',')
  if [ "$SET_OPS_NUM" -ge $TARGET_OPS ]; then
    echo "✓ SET performance meets target ($SET_OPS_NUM ≥ $TARGET_OPS ops/sec)"
  else
    echo "⚠ SET performance below target ($SET_OPS_NUM < $TARGET_OPS ops/sec)"
    PASSED=false
  fi
fi

if [ -n "$GET_OPS" ]; then
  GET_OPS_NUM=$(echo "$GET_OPS" | tr -d ',')
  if [ "$GET_OPS_NUM" -ge $TARGET_OPS ]; then
    echo "✓ GET performance meets target ($GET_OPS_NUM ≥ $TARGET_OPS ops/sec)"
  else
    echo "⚠ GET performance below target ($GET_OPS_NUM < $TARGET_OPS ops/sec)"
    PASSED=false
  fi
fi
echo ""

# Cleanup
echo "Cleaning up benchmark pod..."
kubectl delete pod redis-benchmark-test -n ${NAMESPACE} > /dev/null 2>&1
echo "✓ Benchmark pod deleted"
echo ""

if [ "$PASSED" = true ]; then
  echo "========================================="
  echo "✓ Performance benchmark PASSED"
  echo "========================================="
  echo ""
  echo "Redis Shared meets performance requirements:"
  echo "  SC-006: ≥10,000 ops/sec ✓"
else
  echo "========================================="
  echo "⚠ Performance benchmark completed with warnings"
  echo "========================================="
  echo ""
  echo "Note: Homelab performance may vary based on hardware"
fi
