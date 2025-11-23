#!/bin/bash
# Validation script for LocalStack S3
# Tests: bucket creation, file upload, file download, bucket listing

set -e

# Configuration
LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-https://localstack.homelab.local}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

TEST_BUCKET="s3-validation-test-$(date +%s)"
TEST_FILE="/tmp/localstack-test-file.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "LocalStack S3 Validation Script"
echo "================================================"
echo ""
echo "Endpoint: $LOCALSTACK_ENDPOINT"
echo "Region: $AWS_DEFAULT_REGION"
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

# Test 0: Check LocalStack health
echo "Test 0: Checking LocalStack health endpoint..."
HEALTH=$(curl -s "${LOCALSTACK_ENDPOINT}/_localstack/health" 2>/dev/null || echo "failed")
if echo "$HEALTH" | grep -q "running"; then
    print_result 0 "LocalStack is running"
    echo "   Services: $(echo $HEALTH | jq -r '.services | keys | join(", ")' 2>/dev/null || echo 'N/A')"
else
    echo -e "${YELLOW}Warning: Could not parse health response${NC}"
    echo "   Response: $HEALTH"
fi

# Test 1: Create S3 bucket
echo ""
echo "Test 1: Creating S3 bucket..."
aws --endpoint-url="$LOCALSTACK_ENDPOINT" s3 mb "s3://$TEST_BUCKET" > /dev/null 2>&1
print_result $? "Create bucket $TEST_BUCKET"

# Test 2: List buckets
echo ""
echo "Test 2: Listing S3 buckets..."
BUCKETS=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" s3 ls 2>/dev/null)
if echo "$BUCKETS" | grep -q "$TEST_BUCKET"; then
    print_result 0 "List buckets shows $TEST_BUCKET"
else
    print_result 1 "List buckets"
fi

# Test 3: Upload file
echo ""
echo "Test 3: Uploading test file..."
echo "Hello from LocalStack S3 validation - $(date)" > "$TEST_FILE"
aws --endpoint-url="$LOCALSTACK_ENDPOINT" s3 cp "$TEST_FILE" "s3://$TEST_BUCKET/test.txt" > /dev/null 2>&1
print_result $? "Upload file to S3"

# Test 4: List objects in bucket
echo ""
echo "Test 4: Listing objects in bucket..."
OBJECTS=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" s3 ls "s3://$TEST_BUCKET/" 2>/dev/null)
if echo "$OBJECTS" | grep -q "test.txt"; then
    print_result 0 "List objects shows test.txt"
else
    print_result 1 "List objects"
fi

# Test 5: Download file
echo ""
echo "Test 5: Downloading file from S3..."
DOWNLOADED_FILE="/tmp/localstack-downloaded.txt"
rm -f "$DOWNLOADED_FILE"
aws --endpoint-url="$LOCALSTACK_ENDPOINT" s3 cp "s3://$TEST_BUCKET/test.txt" "$DOWNLOADED_FILE" > /dev/null 2>&1
print_result $? "Download file from S3"

# Test 6: Verify file contents
echo ""
echo "Test 6: Verifying file contents..."
if [ -f "$DOWNLOADED_FILE" ] && grep -q "Hello from LocalStack" "$DOWNLOADED_FILE"; then
    print_result 0 "File contents match"
else
    print_result 1 "File contents verification"
fi

# Cleanup
echo ""
echo "Cleaning up test artifacts..."
aws --endpoint-url="$LOCALSTACK_ENDPOINT" s3 rm "s3://$TEST_BUCKET/test.txt" > /dev/null 2>&1 || true
aws --endpoint-url="$LOCALSTACK_ENDPOINT" s3 rb "s3://$TEST_BUCKET" > /dev/null 2>&1 || true
rm -f "$TEST_FILE" "$DOWNLOADED_FILE"

echo ""
echo "================================================"
echo -e "${GREEN}All LocalStack S3 validation tests passed!${NC}"
echo "================================================"
