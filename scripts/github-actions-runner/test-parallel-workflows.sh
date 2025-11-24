#!/usr/bin/env bash
# T027: Test parallel workflow execution on multiple runners
# Feature 017: GitHub Actions Self-Hosted Runner
#
# This script triggers multiple workflow runs simultaneously to test
# that runners can scale and handle concurrent jobs.
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
PARALLEL_COUNT="${PARALLEL_COUNT:-3}"
TIMEOUT="${TIMEOUT:-600}" # 10 minutes for parallel runs

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
    exit 1
fi
check_pass "GitHub CLI installed"

if ! gh auth status &> /dev/null; then
    check_fail "GitHub CLI not authenticated"
    exit 1
fi
check_pass "GitHub CLI authenticated"

# ==============================================================================
# Trigger Multiple Workflows
# ==============================================================================

print_header "Triggering $PARALLEL_COUNT Parallel Workflows"

check_info "Repository: $REPO"
check_info "Workflow: $WORKFLOW"
check_info "Parallel runs: $PARALLEL_COUNT"

declare -a RUN_IDS

for i in $(seq 1 "$PARALLEL_COUNT"); do
    echo "Dispatching workflow $i of $PARALLEL_COUNT..."
    if gh workflow run "$WORKFLOW" --repo "$REPO"; then
        check_pass "Workflow $i dispatched"
    else
        check_fail "Failed to dispatch workflow $i"
    fi
    # Small delay to ensure unique runs
    sleep 2
done

# Wait for workflows to register
echo "Waiting for workflows to start..."
sleep 10

# ==============================================================================
# Get Run IDs
# ==============================================================================

print_header "Getting Workflow Runs"

# Get the most recent runs
RUNS=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit "$PARALLEL_COUNT" --json databaseId,status,createdAt 2>/dev/null || echo "[]")

RUN_COUNT=$(echo "$RUNS" | jq 'length')
if [[ "$RUN_COUNT" -lt "$PARALLEL_COUNT" ]]; then
    check_fail "Expected $PARALLEL_COUNT runs but found $RUN_COUNT"
else
    check_pass "Found $RUN_COUNT workflow runs"
fi

echo "$RUNS" | jq -r '.[] | "Run \(.databaseId): \(.status)"'

# ==============================================================================
# Monitor Parallel Execution
# ==============================================================================

print_header "Monitoring Parallel Execution"

START_TIME=$(date +%s)
COMPLETED=0
FAILED_RUNS=0

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [[ $ELAPSED -gt $TIMEOUT ]]; then
        check_fail "Workflows timed out after ${TIMEOUT}s"
        break
    fi

    # Get status of all runs
    RUNS=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit "$PARALLEL_COUNT" --json databaseId,status,conclusion 2>/dev/null || echo "[]")

    IN_PROGRESS=$(echo "$RUNS" | jq '[.[] | select(.status == "in_progress" or .status == "queued")] | length')
    COMPLETED=$(echo "$RUNS" | jq '[.[] | select(.status == "completed")] | length')
    SUCCESSFUL=$(echo "$RUNS" | jq '[.[] | select(.conclusion == "success")] | length')
    FAILED_RUNS=$(echo "$RUNS" | jq '[.[] | select(.conclusion == "failure")] | length')

    echo -ne "\rIn progress: $IN_PROGRESS | Completed: $COMPLETED/$PARALLEL_COUNT | Success: $SUCCESSFUL | Failed: $FAILED_RUNS | Elapsed: ${ELAPSED}s    "

    if [[ "$COMPLETED" -ge "$PARALLEL_COUNT" ]]; then
        echo ""
        break
    fi

    sleep 5
done

# ==============================================================================
# Check Concurrent Execution
# ==============================================================================

print_header "Analyzing Concurrent Execution"

# Get run details
RUNS_DETAIL=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit "$PARALLEL_COUNT" --json databaseId,status,conclusion,startedAt,updatedAt 2>/dev/null || echo "[]")

echo "Run Details:"
echo "$RUNS_DETAIL" | jq -r '.[] | "  Run \(.databaseId): \(.status) - \(.conclusion // "pending") (started: \(.startedAt))"'

# Check for overlapping execution times
echo ""
check_info "Checking for concurrent execution..."

# Simple check: if runs have similar start times, they ran in parallel
STARTED_TIMES=$(echo "$RUNS_DETAIL" | jq -r '.[].startedAt' | sort)
FIRST_START=$(echo "$STARTED_TIMES" | head -1)
LAST_START=$(echo "$STARTED_TIMES" | tail -1)

if [[ -n "$FIRST_START" && -n "$LAST_START" ]]; then
    FIRST_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$FIRST_START" +%s 2>/dev/null || date -d "$FIRST_START" +%s 2>/dev/null || echo "0")
    LAST_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_START" +%s 2>/dev/null || date -d "$LAST_START" +%s 2>/dev/null || echo "0")

    if [[ "$FIRST_TS" != "0" && "$LAST_TS" != "0" ]]; then
        START_DIFF=$((LAST_TS - FIRST_TS))
        if [[ $START_DIFF -lt 60 ]]; then
            check_pass "Runs started within 60 seconds of each other (concurrent execution likely)"
        else
            check_info "Runs had ${START_DIFF}s between start times (may indicate queuing)"
        fi
    fi
fi

# ==============================================================================
# Summary
# ==============================================================================

print_header "Parallel Execution Summary"

SUCCESSFUL=$(echo "$RUNS_DETAIL" | jq '[.[] | select(.conclusion == "success")] | length')
FAILED_RUNS=$(echo "$RUNS_DETAIL" | jq '[.[] | select(.conclusion == "failure")] | length')

echo -e "Total runs: $PARALLEL_COUNT"
echo -e "${GREEN}Successful: $SUCCESSFUL${NC}"
echo -e "${RED}Failed: $FAILED_RUNS${NC}"

if [[ "$SUCCESSFUL" -eq "$PARALLEL_COUNT" ]]; then
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  All parallel workflows completed successfully!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "Your homelab runners can handle concurrent workflow execution."
    exit 0
elif [[ "$FAILED_RUNS" -gt 0 ]]; then
    check_fail "$FAILED_RUNS workflow(s) failed"
    echo "Check logs with: gh run view <run_id> --repo $REPO --log"
    exit 1
else
    check_info "Some workflows may still be running or were cancelled"
    exit 1
fi
