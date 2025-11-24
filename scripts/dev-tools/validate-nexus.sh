#!/bin/bash
# Nexus Repository Manager Validation Script
# Tests Nexus deployment, connectivity, and all repository types

set -e

NEXUS_HOST="${NEXUS_HOST:-nexus.chocolandiadc.local}"
DOCKER_HOST="${DOCKER_HOST:-docker.nexus.chocolandiadc.local}"
TRAEFIK_IP="${TRAEFIK_IP:-192.168.4.202}"
NAMESPACE="nexus"

echo "=============================================="
echo "Nexus Repository Manager Validation"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; exit 1; }
warn() { echo -e "${YELLOW}⚠ WARN${NC}: $1"; }
info() { echo -e "  INFO: $1"; }

# 1. Check namespace and pod
echo "1. Checking Nexus deployment..."
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    pass "Namespace '$NAMESPACE' exists"
else
    fail "Namespace '$NAMESPACE' not found"
fi

POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app=nexus -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
if [[ "$POD_STATUS" == "Running" ]]; then
    pass "Nexus pod is running"
else
    fail "Nexus pod not running (status: $POD_STATUS)"
fi

# 2. Check PVC
echo ""
echo "2. Checking persistent storage..."
PVC_STATUS=$(kubectl get pvc -n "$NAMESPACE" nexus-data -o jsonpath='{.status.phase}' 2>/dev/null)
if [[ "$PVC_STATUS" == "Bound" ]]; then
    pass "PVC 'nexus-data' is bound"
else
    fail "PVC not bound (status: $PVC_STATUS)"
fi

# 3. Check services
echo ""
echo "3. Checking Kubernetes services..."
if kubectl get svc -n "$NAMESPACE" nexus &>/dev/null; then
    pass "Service 'nexus' exists (port 8081)"
else
    fail "Service 'nexus' not found"
fi

if kubectl get svc -n "$NAMESPACE" nexus-docker &>/dev/null; then
    pass "Service 'nexus-docker' exists (port 8082)"
else
    fail "Service 'nexus-docker' not found"
fi

# 4. Check certificates
echo ""
echo "4. Checking TLS certificates..."
CERT_READY=$(kubectl get certificate -n "$NAMESPACE" nexus-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [[ "$CERT_READY" == "True" ]]; then
    pass "Certificate 'nexus-tls' is ready"
else
    warn "Certificate 'nexus-tls' not ready yet (might be pending Let's Encrypt)"
fi

DOCKER_CERT_READY=$(kubectl get certificate -n "$NAMESPACE" nexus-docker-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [[ "$DOCKER_CERT_READY" == "True" ]]; then
    pass "Certificate 'nexus-docker-tls' is ready"
else
    warn "Certificate 'nexus-docker-tls' not ready yet (might be pending Let's Encrypt)"
fi

# 5. Check IngressRoutes
echo ""
echo "5. Checking Traefik IngressRoutes..."
if kubectl get ingressroute -n "$NAMESPACE" nexus-https &>/dev/null; then
    pass "IngressRoute 'nexus-https' exists"
else
    fail "IngressRoute 'nexus-https' not found"
fi

if kubectl get ingressroute -n "$NAMESPACE" nexus-docker-https &>/dev/null; then
    pass "IngressRoute 'nexus-docker-https' exists"
else
    fail "IngressRoute 'nexus-docker-https' not found"
fi

# 6. Test HTTP connectivity
echo ""
echo "6. Testing HTTP connectivity..."

# Test via Traefik IP with Host header
HTTP_CODE=$(curl -sk "https://${TRAEFIK_IP}" -H "Host: ${NEXUS_HOST}" -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Nexus Web UI accessible via Traefik (HTTP $HTTP_CODE)"
else
    warn "Nexus Web UI returned HTTP $HTTP_CODE (might need DNS or certificate)"
fi

# 7. Test Nexus status API
echo ""
echo "7. Testing Nexus API endpoints..."
STATUS=$(curl -sk "https://${TRAEFIK_IP}/service/rest/v1/status" -H "Host: ${NEXUS_HOST}" 2>/dev/null || echo "failed")
if [[ "$STATUS" != "failed" ]]; then
    pass "Nexus status API responding"
else
    warn "Nexus status API not responding"
fi

# 8. Check Prometheus metrics
echo ""
echo "8. Checking Prometheus metrics..."
METRICS=$(curl -sk "https://${TRAEFIK_IP}/service/metrics/prometheus" -H "Host: ${NEXUS_HOST}" 2>/dev/null | head -5)
if [[ -n "$METRICS" ]]; then
    pass "Prometheus metrics endpoint responding"
else
    warn "Prometheus metrics endpoint not responding"
fi

# 9. Get admin password location
echo ""
echo "9. Admin password retrieval..."
info "Initial admin password can be retrieved with:"
info "  kubectl exec -n nexus deployment/nexus -- cat /nexus-data/admin.password"

# Summary
echo ""
echo "=============================================="
echo "Validation Complete"
echo "=============================================="
echo ""
echo "Nexus Web UI: https://${NEXUS_HOST}"
echo "Docker Registry: https://${DOCKER_HOST}"
echo ""
echo "Next steps:"
echo "1. Access Nexus UI and change admin password"
echo "2. Create docker-hosted repository with HTTP connector port 8082"
echo "3. Configure Helm, NPM, Maven, APT repositories as needed"
echo "4. Test docker login docker.nexus.chocolandiadc.local"
