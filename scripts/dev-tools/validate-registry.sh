#!/bin/bash
# Validation script for Docker Registry
# Tests: docker login, push, pull operations

set -e

# Configuration
REGISTRY_HOST="${REGISTRY_HOST:-registry.homelab.local}"
REGISTRY_USER="${REGISTRY_USER:-admin}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-K0tnob1+9F5ZbQtOS+1bPV2pctQTdZZk}"
TEST_IMAGE="alpine:latest"
TEST_TAG="validate-test-$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "Docker Registry Validation Script"
echo "================================================"
echo ""
echo "Registry: $REGISTRY_HOST"
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

# Test 1: Check registry health endpoint
echo "Test 1: Checking registry health endpoint..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u "$REGISTRY_USER:$REGISTRY_PASSWORD" "https://$REGISTRY_HOST/v2/" 2>/dev/null || echo "000")
if [ "$HEALTH_STATUS" == "200" ] || [ "$HEALTH_STATUS" == "401" ]; then
    print_result 0 "Registry endpoint is accessible (HTTP $HEALTH_STATUS)"
else
    echo -e "${YELLOW}Warning: Registry returned HTTP $HEALTH_STATUS${NC}"
    print_result 1 "Registry endpoint check"
fi

# Test 2: Docker login
echo ""
echo "Test 2: Testing docker login..."
echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY_HOST" -u "$REGISTRY_USER" --password-stdin > /dev/null 2>&1
print_result $? "Docker login to $REGISTRY_HOST"

# Test 3: Pull test image from Docker Hub
echo ""
echo "Test 3: Pulling test image from Docker Hub..."
docker pull "$TEST_IMAGE" > /dev/null 2>&1
print_result $? "Pull $TEST_IMAGE from Docker Hub"

# Test 4: Tag image for local registry
echo ""
echo "Test 4: Tagging image for local registry..."
docker tag "$TEST_IMAGE" "$REGISTRY_HOST/$TEST_TAG"
print_result $? "Tag image as $REGISTRY_HOST/$TEST_TAG"

# Test 5: Push image to local registry
echo ""
echo "Test 5: Pushing image to local registry..."
docker push "$REGISTRY_HOST/$TEST_TAG" > /dev/null 2>&1
print_result $? "Push image to local registry"

# Test 6: Remove local images
echo ""
echo "Test 6: Removing local images..."
docker rmi "$REGISTRY_HOST/$TEST_TAG" > /dev/null 2>&1
print_result $? "Remove local tagged image"

# Test 7: Pull image back from local registry
echo ""
echo "Test 7: Pulling image from local registry..."
docker pull "$REGISTRY_HOST/$TEST_TAG" > /dev/null 2>&1
print_result $? "Pull image from local registry"

# Test 8: List repositories via API
echo ""
echo "Test 8: Listing repositories via registry API..."
REPOS=$(curl -s -u "$REGISTRY_USER:$REGISTRY_PASSWORD" "https://$REGISTRY_HOST/v2/_catalog" 2>/dev/null)
if echo "$REPOS" | grep -q "repositories"; then
    print_result 0 "List repositories via API"
    echo "   Repositories: $REPOS"
else
    print_result 1 "List repositories via API"
fi

# Cleanup
echo ""
echo "Cleaning up test artifacts..."
docker rmi "$REGISTRY_HOST/$TEST_TAG" > /dev/null 2>&1 || true
docker logout "$REGISTRY_HOST" > /dev/null 2>&1 || true

echo ""
echo "================================================"
echo -e "${GREEN}All registry validation tests passed!${NC}"
echo "================================================"
