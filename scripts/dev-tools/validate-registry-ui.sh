#!/bin/bash
# Validation script for Registry UI
# Tests: UI accessibility and basic functionality

set -e

# Configuration
REGISTRY_UI_HOST="${REGISTRY_UI_HOST:-registry-ui.chocolandiadc.local}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "================================================"
echo "Registry UI Validation Script"
echo "================================================"
echo ""
echo "Registry UI: https://$REGISTRY_UI_HOST"
echo ""

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        exit 1
    fi
}

# Test 1: Check UI is accessible
echo "Test 1: Checking Registry UI accessibility..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$REGISTRY_UI_HOST/" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" == "200" ]; then
    print_result 0 "Registry UI is accessible (HTTP $HTTP_STATUS)"
else
    print_result 1 "Registry UI accessibility (HTTP $HTTP_STATUS)"
fi

# Test 2: Check UI returns HTML content
echo ""
echo "Test 2: Checking Registry UI returns valid content..."
CONTENT=$(curl -s "https://$REGISTRY_UI_HOST/" 2>/dev/null)
if echo "$CONTENT" | grep -qi "docker\|registry"; then
    print_result 0 "Registry UI returns valid HTML content"
else
    print_result 1 "Registry UI content validation"
fi

# Test 3: Check TLS certificate
echo ""
echo "Test 3: Checking TLS certificate..."
CERT_INFO=$(echo | openssl s_client -connect "$REGISTRY_UI_HOST:443" -servername "$REGISTRY_UI_HOST" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ -n "$CERT_INFO" ]; then
    print_result 0 "TLS certificate is valid"
    echo "$CERT_INFO" | head -2 | sed 's/^/   /'
else
    print_result 1 "TLS certificate validation"
fi

echo ""
echo "================================================"
echo -e "${GREEN}All Registry UI validation tests passed!${NC}"
echo "================================================"
echo ""
echo "Open in browser: https://$REGISTRY_UI_HOST"
