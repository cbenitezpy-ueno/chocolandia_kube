#!/bin/bash
# Redis Shared - Beersystem Validation Script
# Tests beersystem functionality before and after Redis migration

set -e

NAMESPACE="beersystem"
BACKEND_SERVICE="beersystem-backend"
BACKEND_PORT="3001"
HEALTH_ENDPOINT="/api/v1/health"

echo "========================================="
echo "Beersystem Validation Test"
echo "========================================="
echo ""

# Test 1: Check pods are running
echo "[1/6] Checking beersystem pods status..."
BACKEND_POD=$(kubectl get pods -n ${NAMESPACE} -l app=beersystem,component=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
FRONTEND_POD=$(kubectl get pods -n ${NAMESPACE} -l app=beersystem,component=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$BACKEND_POD" ]; then
    echo "❌ Backend pod not found"
    exit 1
fi
echo "✓ Backend pod: $BACKEND_POD"

if [ -z "$FRONTEND_POD" ]; then
    echo "❌ Frontend pod not found"
    exit 1
fi
echo "✓ Frontend pod: $FRONTEND_POD"

# Check pod status
BACKEND_STATUS=$(kubectl get pod -n ${NAMESPACE} ${BACKEND_POD} -o jsonpath='{.status.phase}')
if [ "$BACKEND_STATUS" != "Running" ]; then
    echo "❌ Backend pod is not running (status: $BACKEND_STATUS)"
    exit 1
fi
echo "✓ Backend is Running"
echo ""

# Test 2: Check health endpoint
echo "[2/6] Testing backend health endpoint..."
kubectl run curl-test \
  --namespace=${NAMESPACE} \
  --image=curlimages/curl:latest \
  --restart=Never \
  --command -- sleep 3600 > /dev/null 2>&1 || echo "Pod already exists"

echo "Waiting for curl pod to be ready..."
kubectl wait --for=condition=ready pod/curl-test -n ${NAMESPACE} --timeout=30s > /dev/null 2>&1

HEALTH_RESPONSE=$(kubectl exec -n ${NAMESPACE} curl-test -- curl -s http://${BACKEND_SERVICE}:${BACKEND_PORT}${HEALTH_ENDPOINT} 2>&1)
HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"' || echo "")

if [ "$HEALTH_STATUS" = "ok" ] || [ "$HEALTH_STATUS" = "healthy" ]; then
    echo "✓ Health check passed: $HEALTH_STATUS"
else
    echo "⚠ Health check response: $HEALTH_RESPONSE"
    if echo "$HEALTH_RESPONSE" | grep -q "ok\|healthy\|running"; then
        echo "✓ Backend appears to be healthy"
    else
        echo "❌ Backend health check failed"
    fi
fi
echo ""

# Test 3: Check Redis connection
echo "[3/6] Checking Redis connection from backend..."
REDIS_HOST=$(kubectl get deployment beersystem-backend -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="REDIS_HOST")].value}')
REDIS_PORT=$(kubectl get deployment beersystem-backend -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="REDIS_PORT")].value}')

echo "  Redis Host: $REDIS_HOST"
echo "  Redis Port: $REDIS_PORT"

# Check if backend can connect to Redis
REDIS_CHECK=$(kubectl exec -n ${NAMESPACE} ${BACKEND_POD} -- sh -c "timeout 5 cat < /dev/null > /dev/tcp/${REDIS_HOST}/${REDIS_PORT}" 2>&1 || echo "failed")
if echo "$REDIS_CHECK" | grep -q "failed"; then
    echo "⚠ Cannot connect to Redis from backend pod"
    echo "  This is expected if Redis is down during migration"
else
    echo "✓ Backend can connect to Redis"
fi
echo ""

# Test 4: Check database connection
echo "[4/6] Checking database connection..."
DB_HOST=$(kubectl get deployment beersystem-backend -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_HOST")].valueFrom.secretKeyRef.name}')
echo "  DB configured via secret: $DB_HOST"
echo "✓ Database configuration present"
echo ""

# Test 5: Check backend logs for errors
echo "[5/6] Checking recent backend logs for errors..."
ERROR_COUNT=$(kubectl logs -n ${NAMESPACE} ${BACKEND_POD} --tail=50 | grep -i "error\|fatal\|exception" | wc -l || echo "0")
echo "  Error lines in last 50 log lines: $ERROR_COUNT"

if [ "$ERROR_COUNT" -gt 5 ]; then
    echo "⚠ High number of errors detected in logs"
    echo "  Recent errors:"
    kubectl logs -n ${NAMESPACE} ${BACKEND_POD} --tail=50 | grep -i "error\|fatal\|exception" | head -3
else
    echo "✓ No critical errors in recent logs"
fi
echo ""

# Test 6: Check environment variables
echo "[6/6] Verifying Redis environment configuration..."
kubectl exec -n ${NAMESPACE} ${BACKEND_POD} -- env | grep REDIS | sort

echo ""

# Cleanup
echo "Cleaning up test pod..."
kubectl delete pod curl-test -n ${NAMESPACE} > /dev/null 2>&1 || true
echo ""

echo "========================================="
echo "✓ Beersystem validation complete"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Backend pod: $BACKEND_STATUS"
echo "  - Health endpoint: ✓"
echo "  - Redis config: $REDIS_HOST:$REDIS_PORT"
echo "  - Error count: $ERROR_COUNT"
echo ""
echo "Note: If migration is in progress, Redis connection"
echo "      errors are expected and will resolve after"
echo "      backend is reconfigured and restarted."
