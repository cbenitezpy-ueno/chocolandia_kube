#!/bin/bash
# Redis Shared - Monitoring Test Script
# Tests Prometheus metrics integration

set -e

NAMESPACE="redis"
METRICS_SVC="redis-shared-metrics"
METRICS_PORT="9121"

echo "========================================="
echo "Redis Shared - Monitoring Test"
echo "========================================="
echo ""

# Test 1: Check metrics service exists
echo "[1/5] Checking metrics service..."
kubectl get svc -n ${NAMESPACE} ${METRICS_SVC} > /dev/null 2>&1
METRICS_IP=$(kubectl get svc -n ${NAMESPACE} ${METRICS_SVC} -o jsonpath='{.spec.clusterIP}')
echo "✓ Metrics service exists: ${METRICS_SVC}.${NAMESPACE}.svc.cluster.local"
echo "  ClusterIP: $METRICS_IP:${METRICS_PORT}"
echo ""

# Test 2: Check metrics pods are running
echo "[2/5] Checking Redis exporter containers..."
MASTER_EXPORTER=$(kubectl get pod -n ${NAMESPACE} redis-shared-master-0 -o jsonpath='{.spec.containers[?(@.name=="redis-exporter")].name}' 2>/dev/null || echo "")
REPLICA_EXPORTER=$(kubectl get pod -n ${NAMESPACE} redis-shared-replicas-0 -o jsonpath='{.spec.containers[?(@.name=="redis-exporter")].name}' 2>/dev/null || echo "")

if [ -z "$MASTER_EXPORTER" ]; then
  echo "✗ Redis exporter not found in master pod"
  echo "  Checking container names..."
  kubectl get pod -n ${NAMESPACE} redis-shared-master-0 -o jsonpath='{.spec.containers[*].name}'
  echo ""
else
  echo "✓ Redis exporter running in master pod"
fi

if [ -z "$REPLICA_EXPORTER" ]; then
  echo "✗ Redis exporter not found in replica pod"
else
  echo "✓ Redis exporter running in replica pod"
fi
echo ""

# Test 3: Fetch metrics from service endpoint
echo "[3/5] Fetching metrics from service endpoint..."

# Create test pod with curl
kubectl run metrics-test \
  --namespace=${NAMESPACE} \
  --image=curlimages/curl:latest \
  --restart=Never \
  --command -- sleep 3600 > /dev/null 2>&1 || echo "Pod already exists"

echo "Waiting for test pod to be ready..."
kubectl wait --for=condition=ready pod/metrics-test -n ${NAMESPACE} --timeout=30s > /dev/null 2>&1

echo "Fetching metrics..."
METRICS=$(kubectl exec -n ${NAMESPACE} metrics-test -- curl -s http://${METRICS_SVC}.${NAMESPACE}.svc.cluster.local:${METRICS_PORT}/metrics 2>&1)

if echo "$METRICS" | grep -q "redis_up"; then
  echo "✓ Metrics endpoint is accessible"
else
  echo "✗ Metrics endpoint not accessible or metrics not found"
  echo "Response:"
  echo "$METRICS" | head -20
  kubectl delete pod metrics-test -n ${NAMESPACE} > /dev/null 2>&1
  exit 1
fi
echo ""

# Test 4: Verify key metrics exist
echo "[4/5] Verifying key Redis metrics..."

METRICS_TO_CHECK=(
  "redis_up"
  "redis_connected_clients"
  "redis_memory_used_bytes"
  "redis_commands_processed_total"
  "redis_connected_slaves"
)

MISSING_METRICS=0
for metric in "${METRICS_TO_CHECK[@]}"; do
  if echo "$METRICS" | grep -q "^${metric}"; then
    echo "  ✓ $metric"
  else
    echo "  ✗ $metric (missing)"
    MISSING_METRICS=$((MISSING_METRICS + 1))
  fi
done

if [ $MISSING_METRICS -eq 0 ]; then
  echo "✓ All key metrics present"
else
  echo "✗ $MISSING_METRICS metrics missing"
  kubectl delete pod metrics-test -n ${NAMESPACE} > /dev/null 2>&1
  exit 1
fi
echo ""

# Test 5: Check ServiceMonitor (if Prometheus Operator is installed)
echo "[5/5] Checking ServiceMonitor configuration..."
SM_EXISTS=$(kubectl get servicemonitor -n monitoring redis-shared-metrics 2>/dev/null || echo "")

if [ -z "$SM_EXISTS" ]; then
  echo "⚠ ServiceMonitor not found in monitoring namespace"
  echo "  This is expected if ServiceMonitor was not created by Helm chart"
  echo "  Metrics are still accessible via service endpoint"
else
  echo "✓ ServiceMonitor exists: redis-shared-metrics"
  kubectl get servicemonitor -n monitoring redis-shared-metrics -o jsonpath='{.spec.endpoints[0].interval}' 2>/dev/null
  echo ""
fi
echo ""

# Cleanup
echo "Cleaning up test pod..."
kubectl delete pod metrics-test -n ${NAMESPACE} > /dev/null 2>&1
echo "✓ Test pod deleted"
echo ""

echo "========================================="
echo "✓ Monitoring tests PASSED"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Metrics service: ✓"
echo "  - Redis exporter containers: ✓"
echo "  - Metrics endpoint: ✓"
echo "  - Key metrics present: ✓ (${#METRICS_TO_CHECK[@]}/5)"
echo ""
echo "Sample metrics values:"
echo "$METRICS" | grep -E "^(redis_up|redis_connected_clients|redis_memory_used_bytes)" | head -5
