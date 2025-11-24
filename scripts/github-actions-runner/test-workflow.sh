#!/usr/bin/env bash
# T018: Script to trigger and verify test workflow execution
# Feature 017: GitHub Actions Self-Hosted Runner
#
# This script triggers the test-self-hosted-runner workflow and monitors its execution.
# Requires: gh CLI authenticated to the repository

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO="${REPO:-cbenitezpy-ueno/chocolandia_kube}"
WORKFLOW="${WORKFLOW:-test-self-hosted-runner.yaml}"
TIMEOUT="${TIMEOUT:-300}" # 5 minutes default

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

check_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# ==============================================================================
# Prerequisites Check
# ==============================================================================

print_header "Checking Prerequisites"

if ! command -v gh &> /dev/null; then
    check_fail "GitHub CLI (gh) is not installed"
    echo "Install with: brew install gh"
    exit 1
fi
check_pass "GitHub CLI installed"

if ! gh auth status &> /dev/null; then
    check_fail "GitHub CLI not authenticated"
    echo "Authenticate with: gh auth login"
    exit 1
fi
check_pass "GitHub CLI authenticated"

# ==============================================================================
# Trigger Workflow
# ==============================================================================

print_header "Triggering Test Workflow"

check_info "Repository: $REPO"
check_info "Workflow: $WORKFLOW"

echo ""
echo "Dispatching workflow..."

if ! gh workflow run "$WORKFLOW" --repo "$REPO"; then
    check_fail "Failed to trigger workflow"
    exit 1
fi

check_pass "Workflow dispatched successfully"

# Wait a moment for the workflow to register
echo "Waiting for workflow to start..."
sleep 5

# ==============================================================================
# Get Run ID
# ==============================================================================

print_header "Getting Workflow Run"

RUN_ID=""
for i in {1..10}; do
    RUN_ID=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
    if [[ -n "$RUN_ID" ]]; then
        break
    fi
    echo "Waiting for run to appear... (attempt $i/10)"
    sleep 3
done

if [[ -z "$RUN_ID" ]]; then
    check_fail "Could not find workflow run"
    exit 1
fi

check_pass "Found workflow run: $RUN_ID"
echo "View at: https://github.com/$REPO/actions/runs/$RUN_ID"

# ==============================================================================
# Monitor Workflow
# ==============================================================================

print_header "Monitoring Workflow Execution"

START_TIME=$(date +%s)
STATUS=""

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [[ $ELAPSED -gt $TIMEOUT ]]; then
        check_fail "Workflow timed out after ${TIMEOUT}s"
        exit 1
    fi

    RUN_INFO=$(gh run view "$RUN_ID" --repo "$REPO" --json status,conclusion 2>/dev/null || echo "{}")
    STATUS=$(echo "$RUN_INFO" | jq -r '.status // "unknown"')
    CONCLUSION=$(echo "$RUN_INFO" | jq -r '.conclusion // "null"')

    echo -ne "\rStatus: $STATUS | Elapsed: ${ELAPSED}s    "

    if [[ "$STATUS" == "completed" ]]; then
        echo ""
        break
    fi

    sleep 5
done

# ==============================================================================
# Check Results
# ==============================================================================

print_header "Workflow Results"

echo ""
gh run view "$RUN_ID" --repo "$REPO" 2>/dev/null || true

echo ""

if [[ "$CONCLUSION" == "success" ]]; then
    check_pass "Workflow completed successfully!"
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Self-hosted runner is working correctly!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "Your homelab runner can now execute GitHub Actions workflows."
    echo "Use 'runs-on: [self-hosted, linux, x64, homelab]' in your workflows."
    exit 0
elif [[ "$CONCLUSION" == "failure" ]]; then
    check_fail "Workflow failed"
    echo ""
    echo "Check the workflow logs for details:"
    echo "  gh run view $RUN_ID --repo $REPO --log"
    exit 1
elif [[ "$CONCLUSION" == "cancelled" ]]; then
    check_fail "Workflow was cancelled"
    exit 1
else
    check_fail "Workflow ended with unexpected conclusion: $CONCLUSION"
    exit 1
fi
