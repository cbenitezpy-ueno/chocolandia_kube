#!/usr/bin/env bash
#
# transform.sh - Markdown transformation functions for Wiki compatibility
#
# Usage: source this file in other scripts
#   source "$(dirname "$0")/lib/transform.sh"
#

set -euo pipefail

# Transform relative links to Wiki links
# Input: markdown content with relative links like ./other.md or ../001-k3s/spec.md
# Output: transformed content with Wiki links like #section or [[Feature-001-K3s]]
transform_relative_links() {
    local content="$1"
    local current_feature_dir="$2"  # e.g., specs/001-k3s-cluster-setup
    local repo_root="${3:-/Users/cbenitez/chocolandia_kube}"

    # Transform same-feature links: ./quickstart.md → #quick-start
    # Pattern: [text](./file.md) or [text](./file.md#section)
    content=$(echo "$content" | sed -E 's|\[([^]]+)\]\(\./([a-z-]+)\.md(#[a-z-]+)?\)|[\1](#\2\3)|g')

    # Transform cross-feature links: ../001-k3s/spec.md → [[Feature-001-K3s-Cluster-Setup#specification]]
    # This is more complex and would require parsing each link individually
    # For now, keep as-is (they won't work on Wiki but won't break either)

    echo "$content"
}

# Transform image paths to raw GitHub URLs
# Input: markdown content with relative image paths
# Output: transformed content with absolute GitHub raw URLs
transform_image_paths() {
    local content="$1"
    local current_feature_dir="$2"  # e.g., specs/001-k3s-cluster-setup
    local repo_owner="${3:-cbenitezpy-ueno}"
    local repo_name="${4:-chocolandia_kube}"
    local branch="${5:-main}"

    local feature_num
    local feature_name

    # Extract feature directory name for URL construction
    feature_num=$(basename "$current_feature_dir" | cut -d'-' -f1)
    feature_name=$(basename "$current_feature_dir" | cut -d'-' -f2-)

    # Transform relative image paths: ./images/diagram.png → https://raw.githubusercontent.com/.../diagram.png
    # Pattern: ![alt](./path/to/image.ext) or ![alt](images/file.ext)
    content=$(echo "$content" | sed -E \
        "s|!\[([^]]*)\]\(\.?/?images/([^)]+)\)|![\1](https://raw.githubusercontent.com/${repo_owner}/${repo_name}/${branch}/specs/${feature_num}-${feature_name}/images/\2)|g")

    # Transform parent directory images: ![alt](../shared/logo.png)
    content=$(echo "$content" | sed -E \
        "s|!\[([^]]*)\]\(\.\./([^)]+)\)|![\1](https://raw.githubusercontent.com/${repo_owner}/${repo_name}/${branch}/specs/\2)|g")

    echo "$content"
}

# Strip YAML frontmatter from markdown content
# Input: markdown content potentially with frontmatter (---...---)
# Output: content without frontmatter
strip_frontmatter() {
    local content="$1"
    local in_frontmatter=0
    local output=""

    while IFS= read -r line; do
        # Check if we're entering/exiting frontmatter
        if [[ "$line" =~ ^---$ ]]; then
            if [[ $in_frontmatter -eq 0 ]]; then
                in_frontmatter=1
                continue
            else
                in_frontmatter=0
                continue
            fi
        fi

        # Only include lines outside frontmatter
        if [[ $in_frontmatter -eq 0 ]]; then
            output="${output}${line}"$'\n'
        fi
    done <<< "$content"

    echo "$output"
}

# Transform markdown content for Wiki compatibility
# Input: file content, feature directory, repo details
# Output: transformed content ready for Wiki
transform_for_wiki() {
    local content="$1"
    local feature_dir="$2"
    local repo_owner="${3:-cbenitezpy-ueno}"
    local repo_name="${4:-chocolandia_kube}"
    local branch="${5:-main}"

    # Apply all transformations in sequence
    content=$(strip_frontmatter "$content")
    content=$(transform_image_paths "$content" "$feature_dir" "$repo_owner" "$repo_name" "$branch")
    content=$(transform_relative_links "$content" "$feature_dir")

    echo "$content"
}

# Convert markdown heading to anchor ID (GitHub style)
# Input: ## Quick Start Guide
# Output: quick-start-guide
heading_to_anchor() {
    local heading="$1"

    # Remove markdown heading syntax (##, ###, etc.)
    heading=$(echo "$heading" | sed -E 's/^#+\s*//')

    # Convert to lowercase, replace spaces with hyphens, remove special chars
    echo "$heading" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g'
}

# Generate Wiki section link from file name
# Input: quickstart.md
# Output: #quick-start
filename_to_section_anchor() {
    local filename="$1"

    # Remove .md extension
    local name="${filename%.md}"

    # Convert to anchor format
    echo "#${name//_/-}" | tr '[:upper:]' '[:lower:]'
}

# Check if content contains sensitive information (basic check)
# Input: content string
# Output: 0 if safe, 1 if potentially sensitive
check_for_secrets() {
    local content="$1"
    local warnings=()

    # Check for common secret patterns
    if echo "$content" | grep -qi "password\s*[:=]"; then
        warnings+=("Found 'password:' or 'password=' pattern")
    fi

    if echo "$content" | grep -qi "api[_-]key\s*[:=]"; then
        warnings+=("Found 'api_key:' or 'api-key=' pattern")
    fi

    if echo "$content" | grep -qi "secret\s*[:=]"; then
        warnings+=("Found 'secret:' or 'secret=' pattern")
    fi

    if echo "$content" | grep -qiE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"; then
        # Check if it's an internal IP (10.x, 192.168.x, 172.16-31.x)
        if echo "$content" | grep -qE "(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01]))"; then
            warnings+=("Found internal IP address")
        fi
    fi

    if [[ ${#warnings[@]} -gt 0 ]]; then
        for warning in "${warnings[@]}"; do
            log_warning "$warning"
        done
        return 1
    fi

    return 0
}

# Export functions for use in other scripts
export -f transform_relative_links transform_image_paths
export -f strip_frontmatter transform_for_wiki
export -f heading_to_anchor filename_to_section_anchor
export -f check_for_secrets
