#!/usr/bin/env bash
#
# generate-feature-page.sh - Generate consolidated Wiki page for a feature
#
# Usage: ./generate-feature-page.sh <feature-directory>
# Output: Feature page markdown content to stdout
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/extract-metadata.sh"
source "${SCRIPT_DIR}/lib/transform.sh"

# Configuration
REPO_OWNER="${REPO_OWNER:-cbenitezpy-ueno}"
REPO_NAME="${REPO_NAME:-chocolandia_kube}"
REPO_BRANCH="${REPO_BRANCH:-main}"

# Show usage
show_usage() {
    cat <<EOF
Usage: $(basename "$0") <feature-directory>

Generate consolidated Wiki page for a single feature.

Arguments:
  feature-directory   Path to feature directory (e.g., specs/001-k3s-cluster-setup)

Environment Variables:
  REPO_OWNER          GitHub repository owner (default: cbenitezpy-ueno)
  REPO_NAME           GitHub repository name (default: chocolandia_kube)
  REPO_BRANCH         Repository branch (default: main)

Example:
  ./$(basename "$0") specs/001-k3s-cluster-setup > Feature-001-K3s-Cluster-Setup.md

EOF
}

# Handle help flag
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    log_error "Missing required argument: feature-directory"
    show_usage
    exit 1
fi

FEATURE_DIR="$1"

if [[ ! -d "$FEATURE_DIR" ]]; then
    log_error "Feature directory not found: $FEATURE_DIR"
    exit 1
fi

# Generate page header with navigation
generate_header() {
    local feature_dir="$1"
    local title

    title=$(generate_wiki_page_title "$feature_dir")

    cat <<EOF
# ${title}

[🏠 Back to Documentation Index](Home)

---

EOF
}

# Extract and output a documentation section
# Args: section_title, file_path, heading_level
output_section() {
    local section_title="$1"
    local file_path="$2"
    local heading_level="${3:-2}"  # Default to ##

    if [[ ! -f "$file_path" ]]; then
        return 0  # Skip if file doesn't exist
    fi

    if [[ ! -s "$file_path" ]]; then
        return 0  # Skip if file is empty
    fi

    # Generate heading
    local heading_prefix
    heading_prefix=$(printf '%*s' "$heading_level" | tr ' ' '#')
    echo "${heading_prefix} ${section_title}"
    echo ""

    # Read and transform content
    local content
    content=$(cat "$file_path")

    # Apply transformations
    content=$(transform_for_wiki "$content" "$FEATURE_DIR" "$REPO_OWNER" "$REPO_NAME" "$REPO_BRANCH")

    # Output content
    echo "$content"
    echo ""
    echo "---"
    echo ""
}

# Output tasks section (may summarize if too long)
output_tasks_section() {
    local tasks_file="$1"
    local max_lines=500

    if [[ ! -f "$tasks_file" ]] || [[ ! -s "$tasks_file" ]]; then
        return 0
    fi

    local line_count
    line_count=$(count_lines "$tasks_file")

    echo "## Tasks"
    echo ""

    if [[ $line_count -gt $max_lines ]]; then
        # Summarize large task files
        local number
        local name
        number=$(extract_feature_number "$FEATURE_DIR")
        name=$(extract_feature_name "$FEATURE_DIR")

        cat <<EOF
This feature has ${line_count} lines of implementation tasks. [View full task list](https://github.com/${REPO_OWNER}/${REPO_NAME}/blob/${REPO_BRANCH}/specs/${number}-${name}/tasks.md).

### Task Summary

EOF
        # Extract phase headers
        grep "^## Phase" "$tasks_file" | head -10
        echo ""
    else
        # Include full tasks file
        cat "$tasks_file"
        echo ""
    fi

    echo "---"
    echo ""
}

# Generate page footer
generate_footer() {
    local feature_dir="$1"
    local number
    local name
    local timestamp

    number=$(extract_feature_number "$feature_dir")
    name=$(extract_feature_name "$feature_dir")
    timestamp=$(get_timestamp)

    cat <<EOF
**Source**: This documentation is auto-generated from the [${REPO_NAME} repository](https://github.com/${REPO_OWNER}/${REPO_NAME}/tree/${REPO_BRANCH}/specs/${number}-${name}).

**Last Synced**: ${timestamp}

**Edit**: Changes should be made in the repository and synced to Wiki.
EOF
}

# Main generation function
main() {
    # Generate header
    generate_header "$FEATURE_DIR"

    # Generate sections in order (only if files exist)
    output_section "Quick Start" "${FEATURE_DIR}/quickstart.md" 2
    output_section "Specification" "${FEATURE_DIR}/spec.md" 2
    output_section "Implementation Plan" "${FEATURE_DIR}/plan.md" 2
    output_section "Data Model" "${FEATURE_DIR}/data-model.md" 2
    output_section "Research & Decisions" "${FEATURE_DIR}/research.md" 2
    output_tasks_section "${FEATURE_DIR}/tasks.md"

    # Generate footer
    generate_footer "$FEATURE_DIR"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
