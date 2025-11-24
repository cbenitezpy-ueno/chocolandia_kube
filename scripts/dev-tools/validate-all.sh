#!/bin/bash
# Comprehensive validation script for all dev-tools services
# Runs all individual validation scripts in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================================"
echo -e "${BLUE}Dev Tools Comprehensive Validation${NC}"
echo "========================================================"
echo ""
echo "This script validates all dev-tools services:"
echo "  - Docker Registry (registry.chocolandiadc.local)"
echo "  - Registry UI (registry-ui.chocolandiadc.local)"
echo "  - LocalStack S3 (localstack.chocolandiadc.local)"
echo "  - LocalStack SQS"
echo "  - LocalStack SNS"
echo "  - LocalStack DynamoDB"
echo ""

# Track results
PASSED=0
FAILED=0
SKIPPED=0

run_validation() {
    local name="$1"
    local script="$2"

    echo ""
    echo "========================================================"
    echo -e "${BLUE}Running: $name${NC}"
    echo "========================================================"

    if [ -x "$script" ]; then
        if "$script"; then
            echo -e "${GREEN}✓ $name: PASSED${NC}"
            ((PASSED++))
        else
            echo -e "${RED}✗ $name: FAILED${NC}"
            ((FAILED++))
            return 1
        fi
    else
        echo -e "${YELLOW}⊘ $name: SKIPPED (script not found or not executable)${NC}"
        ((SKIPPED++))
    fi
}

# Run all validation scripts
echo ""
echo "Starting validation..."

run_validation "Docker Registry" "$SCRIPT_DIR/validate-registry.sh" || true
run_validation "Registry UI" "$SCRIPT_DIR/validate-registry-ui.sh" || true
run_validation "LocalStack S3" "$SCRIPT_DIR/validate-localstack-s3.sh" || true
run_validation "LocalStack SQS" "$SCRIPT_DIR/validate-localstack-sqs.sh" || true
run_validation "LocalStack SNS" "$SCRIPT_DIR/validate-localstack-sns.sh" || true
run_validation "LocalStack DynamoDB" "$SCRIPT_DIR/validate-localstack-dynamodb.sh" || true

# Summary
echo ""
echo "========================================================"
echo -e "${BLUE}Validation Summary${NC}"
echo "========================================================"
echo ""
echo -e "  ${GREEN}Passed${NC}:  $PASSED"
echo -e "  ${RED}Failed${NC}:  $FAILED"
echo -e "  ${YELLOW}Skipped${NC}: $SKIPPED"
echo ""

if [ $FAILED -eq 0 ] && [ $PASSED -gt 0 ]; then
    echo -e "${GREEN}========================================================"
    echo "All validations passed successfully!"
    echo "========================================================${NC}"
    exit 0
else
    echo -e "${RED}========================================================"
    echo "Some validations failed. Please check the logs above."
    echo "========================================================${NC}"
    exit 1
fi
