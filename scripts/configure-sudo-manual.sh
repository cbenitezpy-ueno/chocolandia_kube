#!/usr/bin/env bash
#
# Manual Passwordless Sudo Configuration
# Simpler approach - run this on EACH node directly
#
# Usage:
#   1. Copy this script to each node
#   2. Run it on each node: ./configure-sudo-manual.sh

set -euo pipefail

USER=$(whoami)

echo "Configuring passwordless sudo for user: $USER"
echo ""

# Create sudoers file
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER > /dev/null

# Set correct permissions
sudo chmod 0440 /etc/sudoers.d/$USER

# Verify
if sudo -n true 2>/dev/null; then
    echo "✓ SUCCESS: Passwordless sudo is now configured"
    echo ""
    echo "Test it:"
    echo "  sudo whoami"
    echo ""
else
    echo "✗ FAILED: Passwordless sudo configuration failed"
    exit 1
fi
