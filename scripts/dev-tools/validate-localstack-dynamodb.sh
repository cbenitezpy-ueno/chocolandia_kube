#!/bin/bash
# Validation script for LocalStack DynamoDB
# Tests: table creation, put item, get item, scan, delete table

set -e

# Configuration
LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-https://localstack.chocolandiadc.local}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

TEST_TABLE="dynamodb-validation-test-$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "================================================"
echo "LocalStack DynamoDB Validation Script"
echo "================================================"
echo ""
echo "Endpoint: $LOCALSTACK_ENDPOINT"
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

# Test 1: Create DynamoDB table
echo "Test 1: Creating DynamoDB table..."
CREATE_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" dynamodb create-table \
    --table-name "$TEST_TABLE" \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST 2>&1)
if echo "$CREATE_RESULT" | grep -q "TableDescription"; then
    print_result 0 "Create table $TEST_TABLE"
else
    print_result 1 "Create table"
fi

# Wait for table to be active
echo "   Waiting for table to become active..."
aws --endpoint-url="$LOCALSTACK_ENDPOINT" dynamodb wait table-exists --table-name "$TEST_TABLE" 2>/dev/null || true
sleep 2

# Test 2: List tables
echo ""
echo "Test 2: Listing DynamoDB tables..."
TABLES=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" dynamodb list-tables 2>/dev/null)
if echo "$TABLES" | grep -q "$TEST_TABLE"; then
    print_result 0 "List tables shows $TEST_TABLE"
else
    print_result 1 "List tables"
fi

# Test 3: Put item
echo ""
echo "Test 3: Putting item into table..."
PUT_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" dynamodb put-item \
    --table-name "$TEST_TABLE" \
    --item '{"id": {"S": "test-item-1"}, "name": {"S": "Validation Test"}, "timestamp": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}}' 2>&1)
print_result $? "Put item into table"

# Test 4: Get item
echo ""
echo "Test 4: Getting item from table..."
GET_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" dynamodb get-item \
    --table-name "$TEST_TABLE" \
    --key '{"id": {"S": "test-item-1"}}' 2>&1)
if echo "$GET_RESULT" | grep -q "Validation Test"; then
    print_result 0 "Get item from table"
    echo "   Retrieved: $(echo "$GET_RESULT" | jq -r '.Item.name.S')"
else
    print_result 1 "Get item"
fi

# Test 5: Scan table
echo ""
echo "Test 5: Scanning table..."
SCAN_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" dynamodb scan \
    --table-name "$TEST_TABLE" 2>&1)
if echo "$SCAN_RESULT" | grep -q '"Count":'; then
    COUNT=$(echo "$SCAN_RESULT" | jq -r '.Count')
    print_result 0 "Scan table (found $COUNT items)"
else
    print_result 1 "Scan table"
fi

# Test 6: Update item
echo ""
echo "Test 6: Updating item in table..."
UPDATE_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" dynamodb update-item \
    --table-name "$TEST_TABLE" \
    --key '{"id": {"S": "test-item-1"}}' \
    --update-expression "SET #n = :newname" \
    --expression-attribute-names '{"#n": "name"}' \
    --expression-attribute-values '{":newname": {"S": "Updated Validation Test"}}' \
    --return-values UPDATED_NEW 2>&1)
if echo "$UPDATE_RESULT" | grep -q "Updated"; then
    print_result 0 "Update item in table"
else
    print_result 1 "Update item"
fi

# Test 7: Delete item
echo ""
echo "Test 7: Deleting item from table..."
aws --endpoint-url="$LOCALSTACK_ENDPOINT" dynamodb delete-item \
    --table-name "$TEST_TABLE" \
    --key '{"id": {"S": "test-item-1"}}' > /dev/null 2>&1
print_result $? "Delete item from table"

# Cleanup
echo ""
echo "Cleaning up test artifacts..."
aws --endpoint-url="$LOCALSTACK_ENDPOINT" dynamodb delete-table --table-name "$TEST_TABLE" > /dev/null 2>&1 || true

echo ""
echo "================================================"
echo -e "${GREEN}All LocalStack DynamoDB validation tests passed!${NC}"
echo "================================================"
