#!/usr/bin/env bash
#
# generate-sidebar.sh - Generate GitHub Wiki sidebar navigation (_Sidebar.md)
#
# Usage: ./generate-sidebar.sh [specs-directory]
# Output: Sidebar markdown content to stdout
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/extract-metadata.sh"

# Configuration
SPECS_DIR="${1:-specs}"

# Show usage
show_usage() {
    cat <<EOF
Usage: $(basename "$0") [specs-directory]

Generate GitHub Wiki sidebar navigation (_Sidebar.md).

Arguments:
  specs-directory   Path to specs directory (default: specs)

Example:
  ./$(basename "$0") specs > _Sidebar.md

EOF
}

# Handle help flag
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
fi

# Generate sidebar header
generate_header() {
    cat <<'EOF'
### 📚 Documentation

- [🏠 Home](Home)

---

### 🚀 Features

EOF
}

# Group features by category
# For now, simple grouping by number ranges
generate_features_by_category() {
    local specs_dir="$1"

    # Infrastructure (001-002)
    echo "#### Infrastructure"
    echo ""
    while IFS= read -r feature_dir; do
        local number
        number=$(extract_feature_number "$feature_dir")

        if [[ "$number" =~ ^00[12]$ ]]; then
            local name
            local title_name
            local wiki_filename

            name=$(extract_feature_name "$feature_dir")
            title_name=$(kebab_to_title_case "$name")
            wiki_filename=$(generate_wiki_page_filename "$feature_dir")

            echo "- [${number}: ${title_name}](${wiki_filename})"
        fi
    done < <(find_feature_directories "$specs_dir")
    echo ""

    # Core Services (003-006)
    echo "#### Core Services"
    echo ""
    while IFS= read -r feature_dir; do
        local number
        number=$(extract_feature_number "$feature_dir")

        if [[ "$number" =~ ^00[3-6]$ ]]; then
            local name
            local title_name
            local wiki_filename

            name=$(extract_feature_name "$feature_dir")
            title_name=$(kebab_to_title_case "$name")
            wiki_filename=$(generate_wiki_page_filename "$feature_dir")

            echo "- [${number}: ${title_name}](${wiki_filename})"
        fi
    done < <(find_feature_directories "$specs_dir")
    echo ""

    # Management & Operations (007-009)
    echo "#### Management & Operations"
    echo ""
    while IFS= read -r feature_dir; do
        local number
        number=$(extract_feature_number "$feature_dir")

        if [[ "$number" =~ ^00[7-9]$ ]]; then
            local name
            local title_name
            local wiki_filename

            name=$(extract_feature_name "$feature_dir")
            title_name=$(kebab_to_title_case "$name")
            wiki_filename=$(generate_wiki_page_filename "$feature_dir")

            echo "- [${number}: ${title_name}](${wiki_filename})"
        fi
    done < <(find_feature_directories "$specs_dir")
    echo ""

    # Documentation & Tools (010+)
    echo "#### Documentation & Tools"
    echo ""
    while IFS= read -r feature_dir; do
        local number
        number=$(extract_feature_number "$feature_dir")

        if [[ "$number" =~ ^0[1-9][0-9]$ ]] || [[ $((10#$number)) -ge 100 ]]; then
            local name
            local title_name
            local wiki_filename

            name=$(extract_feature_name "$feature_dir")
            title_name=$(kebab_to_title_case "$name")
            wiki_filename=$(generate_wiki_page_filename "$feature_dir")

            echo "- [${number}: ${title_name}](${wiki_filename})"
        fi
    done < <(find_feature_directories "$specs_dir")
}

# Main generation function
main() {
    if [[ ! -d "$SPECS_DIR" ]]; then
        log_error "Specs directory not found: $SPECS_DIR"
        exit 1
    fi

    # Generate all sections
    generate_header
    generate_features_by_category "$SPECS_DIR"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
