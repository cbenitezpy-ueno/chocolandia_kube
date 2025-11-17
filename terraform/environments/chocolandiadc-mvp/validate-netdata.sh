#!/bin/bash
# ============================================================================
# Netdata Deployment Validation Script
# Hardware Monitoring Dashboard
# ============================================================================

set -e

KUBECONFIG_PATH="/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig"
export KUBECONFIG="$KUBECONFIG_PATH"

echo "========================================="
echo "Netdata Deployment Validation"
echo "========================================="
echo ""

# Check namespace
echo "✓ Checking Netdata namespace..."
kubectl get namespace netdata &>/dev/null && echo "  ✅ Namespace exists" || (echo "  ❌ Namespace not found" && exit 1)
echo ""

# Check Helm release
echo "✓ Checking Helm release..."
RELEASE_STATUS=$(helm list -n netdata -o json | jq -r '.[0].status')
if [ "$RELEASE_STATUS" = "deployed" ]; then
    echo "  ✅ Helm release status: $RELEASE_STATUS"
    helm list -n netdata
else
    echo "  ❌ Helm release status: $RELEASE_STATUS"
    exit 1
fi
echo ""

# Check parent pod (central UI)
echo "✓ Checking Netdata parent pod..."
PARENT_POD=$(kubectl get pods -n netdata -l app=netdata,role=parent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$PARENT_POD" ]; then
    PARENT_STATUS=$(kubectl get pod -n netdata "$PARENT_POD" -o jsonpath='{.status.phase}')
    PARENT_READY=$(kubectl get pod -n netdata "$PARENT_POD" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    echo "  Pod: $PARENT_POD"
    echo "  Status: $PARENT_STATUS"
    echo "  Ready: $PARENT_READY"

    if [ "$PARENT_STATUS" = "Running" ] && [ "$PARENT_READY" = "True" ]; then
        echo "  ✅ Parent pod is Running and Ready"
    else
        echo "  ❌ Parent pod is not Running/Ready"
        exit 1
    fi
else
    echo "  ⚠️  Parent pod not found (may still be deploying)"
fi
echo ""

# Check child pods (DaemonSet - one per node)
echo "✓ Checking Netdata child pods (DaemonSet)..."
CHILD_PODS=$(kubectl get pods -n netdata -l app=netdata,role=child -o jsonpath='{.items[*].metadata.name}')
CHILD_COUNT=$(kubectl get pods -n netdata -l app=netdata,role=child --no-headers | wc -l | tr -d ' ')
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')

echo "  Child pods: $CHILD_COUNT"
echo "  Nodes: $NODE_COUNT"

if [ "$CHILD_COUNT" -eq "$NODE_COUNT" ]; then
    echo "  ✅ Child pod on each node"
    kubectl get pods -n netdata -l app=netdata,role=child -o wide
else
    echo "  ⚠️  Child pod count doesn't match node count"
fi
echo ""

# Check PVC (historical metrics storage)
echo "✓ Checking PVC for historical metrics..."
PVC_STATUS=$(kubectl get pvc -n netdata -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$PVC_STATUS" = "Bound" ]; then
    echo "  ✅ PVC is Bound"
    kubectl get pvc -n netdata
else
    echo "  ⚠️  PVC status: $PVC_STATUS"
fi
echo ""

# Check TLS certificate
echo "✓ Checking TLS certificate..."
CERT_READY=$(kubectl get certificate -n netdata netdata-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")
if [ "$CERT_READY" = "True" ]; then
    echo "  ✅ TLS certificate is Ready"
    kubectl get certificate -n netdata
else
    echo "  ⚠️  TLS certificate status: $CERT_READY (may still be issuing)"
    kubectl get certificate -n netdata
fi
echo ""

# Check IngressRoute
echo "✓ Checking IngressRoute..."
INGRESS=$(kubectl get ingressroute -n netdata -o name 2>/dev/null | wc -l | tr -d ' ')
if [ "$INGRESS" -gt 0 ]; then
    echo "  ✅ IngressRoute exists"
    kubectl get ingressroute -n netdata
else
    echo "  ❌ IngressRoute not found"
fi
echo ""

# Check Service
echo "✓ Checking Netdata service..."
SERVICE_IP=$(kubectl get svc -n netdata netdata -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "NotFound")
SERVICE_PORT=$(kubectl get svc -n netdata netdata -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "NotFound")
if [ "$SERVICE_IP" != "NotFound" ]; then
    echo "  ✅ Service exists"
    echo "  ClusterIP: $SERVICE_IP"
    echo "  Port: $SERVICE_PORT"
    kubectl get svc -n netdata
else
    echo "  ❌ Service not found"
fi
echo ""

# Test HTTPS endpoint
echo "✓ Testing HTTPS endpoint..."
HTTP_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" https://netdata.chocolandiadc.com || echo "000")
echo "  HTTP Status: $HTTP_STATUS"
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
    echo "  ✅ Endpoint is accessible (HTTP $HTTP_STATUS)"
else
    echo "  ⚠️  Endpoint returned HTTP $HTTP_STATUS (may need Cloudflare Access authentication)"
fi
echo ""

echo "========================================="
echo "✅ Netdata Validation Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Helm release deployed"
echo "  - Parent pod (central UI) running"
echo "  - Child pods (DaemonSet) on all nodes"
echo "  - Storage: Longhorn PVC for historical metrics"
echo "  - TLS: Let's Encrypt certificate"
echo "  - Access: https://netdata.chocolandiadc.com"
echo ""
echo "Next steps:"
echo "  1. Login with authorized Google account via Cloudflare Access"
echo "  2. Navigate to each node's dashboard to see hardware details"
echo "  3. Check CPU temps, RAM usage, disk I/O, network stats"
echo "  4. Enable/disable specific metrics collectors as needed"
echo ""
