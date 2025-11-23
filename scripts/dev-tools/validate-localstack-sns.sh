#!/bin/bash
# Validation script for LocalStack SNS
# Tests: topic creation, subscription, publish message

set -e

# Configuration
LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-https://localstack.homelab.local}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

TEST_TOPIC="sns-validation-test-$(date +%s)"
TEST_QUEUE="sns-target-queue-$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "================================================"
echo "LocalStack SNS Validation Script"
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

# Test 1: Create SNS topic
echo "Test 1: Creating SNS topic..."
TOPIC_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sns create-topic --name "$TEST_TOPIC" 2>&1)
if echo "$TOPIC_RESULT" | grep -q "TopicArn"; then
    print_result 0 "Create topic $TEST_TOPIC"
    TOPIC_ARN=$(echo "$TOPIC_RESULT" | jq -r '.TopicArn')
    echo "   Topic ARN: $TOPIC_ARN"
else
    print_result 1 "Create topic"
fi

# Test 2: List topics
echo ""
echo "Test 2: Listing SNS topics..."
TOPICS=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sns list-topics 2>/dev/null)
if echo "$TOPICS" | grep -q "$TEST_TOPIC"; then
    print_result 0 "List topics shows $TEST_TOPIC"
else
    print_result 1 "List topics"
fi

# Test 3: Create SQS queue for subscription
echo ""
echo "Test 3: Creating SQS queue for SNS subscription..."
QUEUE_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sqs create-queue --queue-name "$TEST_QUEUE" 2>&1)
if echo "$QUEUE_RESULT" | grep -q "QueueUrl"; then
    print_result 0 "Create target queue $TEST_QUEUE"
    QUEUE_URL=$(echo "$QUEUE_RESULT" | jq -r '.QueueUrl')
else
    print_result 1 "Create target queue"
fi

# Get queue ARN
QUEUE_ARN="arn:aws:sqs:${AWS_DEFAULT_REGION}:000000000000:${TEST_QUEUE}"

# Test 4: Subscribe SQS queue to SNS topic
echo ""
echo "Test 4: Subscribing SQS queue to SNS topic..."
SUB_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol sqs \
    --notification-endpoint "$QUEUE_ARN" 2>&1)
if echo "$SUB_RESULT" | grep -q "SubscriptionArn"; then
    print_result 0 "Subscribe queue to topic"
    SUB_ARN=$(echo "$SUB_RESULT" | jq -r '.SubscriptionArn')
    echo "   Subscription ARN: $SUB_ARN"
else
    print_result 1 "Subscribe to topic"
fi

# Test 5: Publish message to topic
echo ""
echo "Test 5: Publishing message to SNS topic..."
MESSAGE="Hello from SNS validation - $(date)"
PUB_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sns publish \
    --topic-arn "$TOPIC_ARN" \
    --message "$MESSAGE" 2>&1)
if echo "$PUB_RESULT" | grep -q "MessageId"; then
    print_result 0 "Publish message to topic"
    echo "   Message ID: $(echo "$PUB_RESULT" | jq -r '.MessageId')"
else
    print_result 1 "Publish message"
fi

# Test 6: Verify message delivered to SQS
echo ""
echo "Test 6: Verifying message delivery to SQS queue..."
sleep 2  # Give time for message propagation
RECEIVE_RESULT=$(aws --endpoint-url="$LOCALSTACK_ENDPOINT" sqs receive-message \
    --queue-url "$QUEUE_URL" \
    --max-number-of-messages 1 2>&1)
if echo "$RECEIVE_RESULT" | grep -q "Body"; then
    print_result 0 "Message delivered to SQS queue"
    echo "   Received SNS notification in SQS"
else
    print_result 1 "Message delivery to SQS"
fi

# Cleanup
echo ""
echo "Cleaning up test artifacts..."
aws --endpoint-url="$LOCALSTACK_ENDPOINT" sns unsubscribe --subscription-arn "$SUB_ARN" > /dev/null 2>&1 || true
aws --endpoint-url="$LOCALSTACK_ENDPOINT" sns delete-topic --topic-arn "$TOPIC_ARN" > /dev/null 2>&1 || true
aws --endpoint-url="$LOCALSTACK_ENDPOINT" sqs delete-queue --queue-url "$QUEUE_URL" > /dev/null 2>&1 || true

echo ""
echo "================================================"
echo -e "${GREEN}All LocalStack SNS validation tests passed!${NC}"
echo "================================================"
