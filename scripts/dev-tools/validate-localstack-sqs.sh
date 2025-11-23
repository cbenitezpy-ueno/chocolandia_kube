#!/bin/bash
# Validation script for LocalStack SQS
# Tests: queue creation, send message, receive message, delete queue

set -e

# Configuration
LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-https://localstack.homelab.local}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

TEST_QUEUE="sqs-validation-test-$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "================================================"
echo "LocalStack SQS Validation Script"
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

# Test 1: Create SQS queue
echo "Test 1: Creating SQS queue..."
QUEUE_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sqs create-queue --queue-name "$TEST_QUEUE" 2>&1)
if echo "$QUEUE_RESULT" | grep -q "QueueUrl"; then
    print_result 0 "Create queue $TEST_QUEUE"
    QUEUE_URL=$(echo "$QUEUE_RESULT" | jq -r '.QueueUrl')
    echo "   Queue URL: $QUEUE_URL"
else
    print_result 1 "Create queue"
fi

# Test 2: List queues
echo ""
echo "Test 2: Listing SQS queues..."
QUEUES=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sqs list-queues 2>/dev/null)
if echo "$QUEUES" | grep -q "$TEST_QUEUE"; then
    print_result 0 "List queues shows $TEST_QUEUE"
else
    print_result 1 "List queues"
fi

# Test 3: Send message
echo ""
echo "Test 3: Sending message to queue..."
MESSAGE_BODY="Hello from SQS validation - $(date)"
SEND_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-body "$MESSAGE_BODY" 2>&1)
if echo "$SEND_RESULT" | grep -q "MessageId"; then
    print_result 0 "Send message to queue"
    MESSAGE_ID=$(echo "$SEND_RESULT" | jq -r '.MessageId')
    echo "   Message ID: $MESSAGE_ID"
else
    print_result 1 "Send message"
fi

# Test 4: Receive message
echo ""
echo "Test 4: Receiving message from queue..."
RECEIVE_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sqs receive-message \
    --queue-url "$QUEUE_URL" \
    --max-number-of-messages 1 2>&1)
if echo "$RECEIVE_RESULT" | grep -q "Body"; then
    print_result 0 "Receive message from queue"
    RECEIVED_BODY=$(echo "$RECEIVE_RESULT" | jq -r '.Messages[0].Body')
    echo "   Received: $RECEIVED_BODY"
    RECEIPT_HANDLE=$(echo "$RECEIVE_RESULT" | jq -r '.Messages[0].ReceiptHandle')
else
    print_result 1 "Receive message"
fi

# Test 5: Delete message
echo ""
echo "Test 5: Deleting message from queue..."
aws --endpoint-url="$LOCALSTACK_ENDPOINT" sqs delete-message \
    --queue-url "$QUEUE_URL" \
    --receipt-handle "$RECEIPT_HANDLE" > /dev/null 2>&1
print_result $? "Delete message from queue"

# Cleanup
echo ""
echo "Cleaning up test artifacts..."
aws --endpoint-url="$LOCALSTACK_ENDPOINT" sqs delete-queue --queue-url "$QUEUE_URL" > /dev/null 2>&1 || true

echo ""
echo "================================================"
echo -e "${GREEN}All LocalStack SQS validation tests passed!${NC}"
echo "================================================"
