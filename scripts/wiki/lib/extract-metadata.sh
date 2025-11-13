#!/usr/bin/env bash
#
# extract-metadata.sh - Extract metadata from feature specification files
#
# Usage: source this file in other scripts
#   source "$(dirname "$0")/lib/extract-metadata.sh"
#

set -euo pipefail

# Extract feature description from spec.md
# Looks for first substantial paragraph after the title
# Input: path to spec.md
# Output: brief description (max 100 chars)
extract_feature_description() {
    local spec_file="$1"
    local description=""

    if [[ ! -f "$spec_file" ]]; then
        echo "Documentation for this feature"
        return 0
    fi

    # Try to extract from "User description:" input field
    if grep -q "^**Input**:" "$spec_file"; then
        description=$(grep -A 1 "^**Input**:" "$spec_file" | \
                     grep "User description:" | \
                     sed 's/.*User description: "\(.*\)".*/\1/' | \
                     head -c 100)
    fi

    # If not found, try first User Story summary
    if [[ -z "$description" ]]; then
        description=$(grep -A 2 "### User Story 1" "$spec_file" | \
                     tail -1 | \
                     sed 's/^As .* I want to //' | \
                     sed 's/ so that.*//' | \
                     head -c 100)
    fi

    # If still not found, try first paragraph after title
    if [[ -z "$description" ]]; then
        description=$(awk '/^## / {found=1; next} found && /^[A-Z]/ {print; exit}' "$spec_file" | \
                     head -c 100)
    fi

    # Fallback
    if [[ -z "$description" ]]; then
        description="Documentation for this feature"
    fi

    # Clean up and trim
    description=$(echo "$description" | tr -d '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    echo "$description"
}

# Determine feature status based on available files
# Input: feature directory path
# Output: status string (✅ Complete, 🚧 In Progress, 📝 Planning)
get_feature_status() {
    local feature_dir="$1"

    # Complete: has tasks.md (means implementation tasks are defined)
    if [[ -f "${feature_dir}/tasks.md" ]]; then
        echo "✅ Complete"
        return 0
    fi

    # In Progress: has plan.md but not tasks.md
    if [[ -f "${feature_dir}/plan.md" ]]; then
        echo "🚧 In Progress"
        return 0
    fi

    # Planning: only has spec.md
    if [[ -f "${feature_dir}/spec.md" ]]; then
        echo "📝 Planning"
        return 0
    fi

    # Unknown state
    echo "❓ Unknown"
}

# Check if feature has quickstart guide
# Input: feature directory path
# Output: "true" or "false"
has_quickstart() {
    local feature_dir="$1"
    local quickstart_file="${feature_dir}/quickstart.md"

    if [[ -f "$quickstart_file" && -s "$quickstart_file" ]]; then
        # Check if file has substantial content (more than just headers)
        local line_count
        line_count=$(grep -c '^[^#]' "$quickstart_file" 2>/dev/null || echo "0")
        if [[ $line_count -gt 5 ]]; then
            echo "true"
            return 0
        fi
    fi

    echo "false"
}

# Extract feature metadata as JSON
# Input: feature directory path
# Output: JSON object with metadata
extract_feature_metadata_json() {
    local feature_dir="$1"
    local number
    local name
    local title
    local wiki_filename
    local status
    local description
    local has_qs

    # Extract basic info using utils.sh functions
    number=$(extract_feature_number "$feature_dir")
    name=$(extract_feature_name "$feature_dir")
    title=$(generate_wiki_page_title "$feature_dir")
    wiki_filename=$(generate_wiki_page_filename "$feature_dir")

    # Extract metadata
    status=$(get_feature_status "$feature_dir")
    description=$(extract_feature_description "${feature_dir}/spec.md")
    has_qs=$(has_quickstart "$feature_dir")

    # Generate JSON
    cat <<EOF
{
  "number": "$number",
  "name": "$name",
  "title": "$title",
  "wiki_filename": "$wiki_filename",
  "status": "$status",
  "description": "$description",
  "has_quickstart": $has_qs,
  "dir_path": "$feature_dir"
}
EOF
}

# Extract all available documentation files for a feature
# Input: feature directory path
# Output: space-separated list of available doc types
get_available_docs() {
    local feature_dir="$1"
    local docs=()

    [[ -f "${feature_dir}/spec.md" ]] && docs+=("spec")
    [[ -f "${feature_dir}/quickstart.md" ]] && docs+=("quickstart")
    [[ -f "${feature_dir}/plan.md" ]] && docs+=("plan")
    [[ -f "${feature_dir}/data-model.md" ]] && docs+=("data-model")
    [[ -f "${feature_dir}/research.md" ]] && docs+=("research")
    [[ -f "${feature_dir}/tasks.md" ]] && docs+=("tasks")

    echo "${docs[@]}"
}

# Get full title from spec.md (first # heading)
# Input: spec.md file path
# Output: title without # prefix
extract_spec_title() {
    local spec_file="$1"

    if [[ ! -f "$spec_file" ]]; then
        echo "Feature Specification"
        return 0
    fi

    # Extract first # heading
    local title
    title=$(grep -m 1 "^# " "$spec_file" | sed 's/^# //')

    if [[ -z "$title" ]]; then
        title="Feature Specification"
    fi

    echo "$title"
}

# Export functions for use in other scripts
export -f extract_feature_description get_feature_status
export -f has_quickstart extract_feature_metadata_json
export -f get_available_docs extract_spec_title
