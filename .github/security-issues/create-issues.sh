#!/usr/bin/env bash
#
# Script para crear GitHub Issues automáticamente
# Requiere: gh CLI (GitHub CLI) instalado y autenticado
#
# Instalación de gh:
#   macOS:   brew install gh
#   Linux:   https://github.com/cli/cli/blob/trunk/docs/install_linux.md
#   Windows: https://github.com/cli/cli#windows
#
# Uso:
#   1. Autenticarse: gh auth login
#   2. Ejecutar: ./create-issues.sh

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="cbenitezpy-ueno/chocolandia_kube"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error() {
    echo -e "${RED}✗ ERROR:${NC} $*" >&2
    exit 1
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

log "Checking prerequisites..."

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    error "gh CLI is not installed. Install it from: https://github.com/cli/cli"
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    error "Not authenticated with GitHub. Run: gh auth login"
fi

success "Prerequisites OK"
echo ""

# ============================================================================
# Confirmation
# ============================================================================

cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║  GitHub Security Issues Creator                                   ║
║  ChocolandiaDC K3s Infrastructure                                 ║
╚═══════════════════════════════════════════════════════════════════╝

This script will create 6 security issues on GitHub:

🔴 CRITICAL:
  1. K3s cluster token exposed in environment variables
  2. SQLite database without encryption at rest

⚠️  HIGH:
  3. Grafana exposed without TLS on NodePort
  4. Flat network without segmentation
  5. SSH StrictHostKeyChecking disabled
  6. K3s cluster without audit logging enabled

EOF

read -p "Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Cancelled by user"
    exit 0
fi

# ============================================================================
# Create Issues
# ============================================================================

log "Creating issues on GitHub..."
echo ""

CREATED=0
FAILED=0

for file in "$SCRIPT_DIR"/0*.md; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    filename=$(basename "$file")
    log "Processing: $filename"

    # Extract title (first line without #)
    title=$(head -n 1 "$file" | sed 's/^# //')

    # Extract labels from line 3
    labels=$(sed -n '3p' "$file" | sed 's/\*\*Labels:\*\* //; s/`//g; s/, /,/g')

    # Body content (from line 5 onwards)
    body=$(tail -n +5 "$file")

    # Create issue
    if gh issue create \
        --repo "$REPO" \
        --title "$title" \
        --body "$body" \
        --label "$labels" &> /dev/null; then

        success "Created: $title"
        ((CREATED++))
    else
        warning "Failed to create: $title"
        ((FAILED++))
    fi

    # Rate limiting (be nice to GitHub)
    sleep 2
done

echo ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================================================
# Summary
# ============================================================================

echo ""
log "Summary:"
success "Issues created: $CREATED"
if [[ $FAILED -gt 0 ]]; then
    warning "Issues failed: $FAILED"
fi

echo ""
log "View issues at:"
echo "  https://github.com/$REPO/issues"

echo ""
success "Done! 🎉"
