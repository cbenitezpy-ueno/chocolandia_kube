#!/usr/bin/env bash
#
# utils.sh - Common utility functions for Wiki sync scripts
#
# Usage: source this file in other scripts
#   source "$(dirname "$0")/lib/utils.sh"
#

set -euo pipefail

# Colors for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*" >&2
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# Extract feature number from directory name
# Input: specs/001-k3s-cluster-setup or 001-k3s-cluster-setup
# Output: 001
extract_feature_number() {
    local dir_path="$1"
    local dir_name

    # Get just the directory name if full path provided
    dir_name=$(basename "$dir_path")

    # Extract first 3 digits
    if [[ "$dir_name" =~ ^([0-9]{3})- ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    else
        log_error "Invalid feature directory name: $dir_name (expected format: XXX-name)"
        return 1
    fi
}

# Extract feature name from directory name (kebab-case)
# Input: specs/001-k3s-cluster-setup or 001-k3s-cluster-setup
# Output: k3s-cluster-setup
extract_feature_name() {
    local dir_path="$1"
    local dir_name

    # Get just the directory name if full path provided
    dir_name=$(basename "$dir_path")

    # Extract everything after first 4 characters (XXX-)
    if [[ "$dir_name" =~ ^[0-9]{3}-(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    else
        log_error "Invalid feature directory name: $dir_name"
        return 1
    fi
}

# Convert kebab-case to Title Case
# Input: k3s-cluster-setup
# Output: K3s Cluster Setup
kebab_to_title_case() {
    local kebab_string="$1"
    local result=""

    # Split by hyphens and capitalize each word
    IFS='-' read -ra words <<< "$kebab_string"
    for word in "${words[@]}"; do
        # Capitalize first letter, keep rest as-is (preserves K3s, Pi-hole, etc.)
        if [[ -n "$word" ]]; then
            capitalized="$(tr '[:lower:]' '[:upper:]' <<< "${word:0:1}")${word:1}"
            result="${result}${result:+ }${capitalized}"
        fi
    done

    echo "$result"
}

# Convert kebab-case to Wiki page filename format
# Input: k3s-cluster-setup
# Output: K3s-Cluster-Setup
kebab_to_wiki_filename() {
    local kebab_string="$1"
    local result=""

    # Split by hyphens and capitalize each word
    IFS='-' read -ra words <<< "$kebab_string"
    for i in "${!words[@]}"; do
        word="${words[$i]}"
        if [[ -n "$word" ]]; then
            # Capitalize first letter
            capitalized="$(tr '[:lower:]' '[:upper:]' <<< "${word:0:1}")${word:1}"
            if [[ $i -eq 0 ]]; then
                result="$capitalized"
            else
                result="${result}-${capitalized}"
            fi
        fi
    done

    echo "$result"
}

# Generate Wiki page filename for a feature
# Input: specs/001-k3s-cluster-setup
# Output: Feature-001-K3s-Cluster-Setup
generate_wiki_page_filename() {
    local feature_dir="$1"
    local number
    local name
    local wiki_name

    number=$(extract_feature_number "$feature_dir") || return 1
    name=$(extract_feature_name "$feature_dir") || return 1
    wiki_name=$(kebab_to_wiki_filename "$name")

    echo "Feature-${number}-${wiki_name}"
}

# Generate Wiki page title for a feature
# Input: specs/001-k3s-cluster-setup
# Output: Feature 001: K3s Cluster Setup
generate_wiki_page_title() {
    local feature_dir="$1"
    local number
    local name
    local title_name

    number=$(extract_feature_number "$feature_dir") || return 1
    name=$(extract_feature_name "$feature_dir") || return 1
    title_name=$(kebab_to_title_case "$name")

    echo "Feature ${number}: ${title_name}"
}

# Check if file exists and is non-empty
# Input: file path
# Output: 0 if exists and non-empty, 1 otherwise
file_exists_and_nonempty() {
    local file_path="$1"

    [[ -f "$file_path" && -s "$file_path" ]]
}

# Get current timestamp in ISO 8601 format
# Output: 2025-11-13T10:30:00Z
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Find all feature directories in specs/
# Output: List of directory paths (one per line)
find_feature_directories() {
    local specs_dir="${1:-specs}"

    # Find directories matching pattern XXX-*
    find "$specs_dir" -maxdepth 1 -type d -name '[0-9][0-9][0-9]-*' | sort -V
}

# Count lines in a file
# Input: file path
# Output: number of lines
count_lines() {
    local file_path="$1"

    if [[ -f "$file_path" ]]; then
        wc -l < "$file_path" | tr -d ' '
    else
        echo "0"
    fi
}

# Escape special characters for markdown
# Input: string with special chars
# Output: escaped string
escape_markdown() {
    local input="$1"

    # Escape backslashes, backticks, asterisks, underscores, pipes
    echo "$input" | sed -e 's/\\/\\\\/g' \
                        -e 's/`/\\`/g' \
                        -e 's/\*/\\*/g' \
                        -e 's/_/\\_/g' \
                        -e 's/|/\\|/g'
}

# Generate markdown table separator
# Input: number of columns
# Output: |---|---|---| (with correct number of columns)
generate_table_separator() {
    local num_columns="$1"
    local separator="|"

    for ((i=0; i<num_columns; i++)); do
        separator="${separator}---|"
    done

    echo "$separator"
}

# Test if command exists
# Input: command name
# Output: 0 if exists, 1 otherwise
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verify required commands are available
# Input: list of command names
# Output: 0 if all exist, 1 if any missing
verify_commands() {
    local missing=()

    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi

    return 0
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error
export -f extract_feature_number extract_feature_name
export -f kebab_to_title_case kebab_to_wiki_filename
export -f generate_wiki_page_filename generate_wiki_page_title
export -f file_exists_and_nonempty get_timestamp
export -f find_feature_directories count_lines
export -f escape_markdown generate_table_separator
export -f command_exists verify_commands
