#!/usr/bin/env bash
#
# validate-markdown.sh - Validate markdown files before Wiki sync
#
# Usage: ./validate-markdown.sh <file-or-directory>
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "${SCRIPT_DIR}/lib/utils.sh"

# Validate markdown syntax (basic checks)
validate_markdown_syntax() {
    local file_path="$1"
    local errors=0

    if [[ ! -f "$file_path" ]]; then
        log_error "File not found: $file_path"
        return 1
    fi

    # Check for unclosed code blocks
    local code_block_count
    code_block_count=$(grep -c '^```' "$file_path" || echo "0")
    if [[ $((code_block_count % 2)) -ne 0 ]]; then
        log_error "$file_path: Unclosed code block (odd number of \`\`\` markers)"
        ((errors++))
    fi

    # Check for broken image syntax
    if grep -q '!\[.*\]([^)]*)$' "$file_path"; then
        log_warning "$file_path: Potentially malformed image syntax"
    fi

    # Check for broken link syntax
    if grep -q '\[.*\]([^)]*)$' "$file_path"; then
        log_warning "$file_path: Potentially malformed link syntax"
    fi

    # Check for very long lines (>10000 chars - could cause rendering issues)
    local max_line_length
    max_line_length=$(awk '{print length}' "$file_path" | sort -n | tail -1)
    if [[ $max_line_length -gt 10000 ]]; then
        log_warning "$file_path: Very long line detected (${max_line_length} chars)"
    fi

    return $errors
}

# Validate feature directory structure
validate_feature_directory() {
    local feature_dir="$1"
    local errors=0

    if [[ ! -d "$feature_dir" ]]; then
        log_error "Directory not found: $feature_dir"
        return 1
    fi

    # Check for required spec.md
    if [[ ! -f "${feature_dir}/spec.md" ]]; then
        log_error "$feature_dir: Missing required spec.md file"
        ((errors++))
    fi

    # Validate existing markdown files
    for md_file in "$feature_dir"/*.md; do
        if [[ -f "$md_file" ]]; then
            validate_markdown_syntax "$md_file" || ((errors++))
        fi
    done

    return $errors
}

# Main validation function
main() {
    local target="${1:-.}"
    local exit_code=0

    log_info "Starting markdown validation..."

    if [[ -f "$target" ]]; then
        # Validate single file
        validate_markdown_syntax "$target" || exit_code=1
    elif [[ -d "$target" ]]; then
        # Check if it's a feature directory
        if [[ $(basename "$target") =~ ^[0-9]{3}-.*$ ]]; then
            validate_feature_directory "$target" || exit_code=1
        else
            # Validate all markdown files in directory
            local file_count=0
            local error_count=0

            while IFS= read -r -d '' md_file; do
                ((file_count++))
                if ! validate_markdown_syntax "$md_file"; then
                    ((error_count++))
                fi
            done < <(find "$target" -type f -name "*.md" -print0)

            log_info "Validated $file_count markdown files"
            if [[ $error_count -gt 0 ]]; then
                log_error "Found errors in $error_count files"
                exit_code=1
            else
                log_success "All files passed validation"
            fi
        fi
    else
        log_error "Invalid target: $target (must be file or directory)"
        exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_success "Validation complete - no critical errors"
    else
        log_error "Validation failed - please fix errors above"
    fi

    return $exit_code
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
