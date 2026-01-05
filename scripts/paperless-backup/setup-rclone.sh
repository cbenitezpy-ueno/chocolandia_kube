#!/bin/bash
# Setup script for rclone Google Drive OAuth
# Feature: 028-paperless-gdrive-backup
#
# Run this script on your LOCAL machine (with browser access)
# NOT on the K3s cluster

set -e

echo "=========================================="
echo "Paperless Backup - rclone Setup"
echo "=========================================="
echo ""

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo "rclone is not installed."
    echo ""
    echo "Install rclone first:"
    echo "  macOS:   brew install rclone"
    echo "  Linux:   curl https://rclone.org/install.sh | sudo bash"
    echo "  Windows: winget install Rclone.Rclone"
    echo ""
    exit 1
fi

echo "rclone version: $(rclone version | head -1)"
echo ""

# Check if gdrive remote already exists
if rclone listremotes | grep -q "^gdrive:$"; then
    echo "WARNING: 'gdrive' remote already exists!"
    echo ""
    read -p "Do you want to reconfigure it? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Using existing configuration."
        echo ""
    else
        echo "Reconfiguring gdrive remote..."
        rclone config delete gdrive
    fi
fi

# Configure if not exists
if ! rclone listremotes | grep -q "^gdrive:$"; then
    echo "Creating 'gdrive' remote..."
    echo ""
    echo "Follow these steps in the rclone wizard:"
    echo "  1. When asked for 'name', enter: gdrive"
    echo "  2. For 'Storage', enter: drive"
    echo "  3. Leave 'client_id' and 'client_secret' blank"
    echo "  4. For 'scope', select: 1 (Full access)"
    echo "  5. Leave 'root_folder_id' blank"
    echo "  6. Leave 'service_account_file' blank"
    echo "  7. Edit advanced config: n"
    echo "  8. Use auto config: y"
    echo "  9. Configure as Shared Drive: n"
    echo ""
    echo "Press Enter to start the configuration..."
    read

    rclone config
fi

# Verify configuration
echo ""
echo "Verifying configuration..."
if rclone lsd gdrive:/ --max-depth 0 &> /dev/null; then
    echo "SUCCESS: Google Drive access verified!"
else
    echo "ERROR: Cannot access Google Drive. Please reconfigure."
    exit 1
fi

# Create backup folder
echo ""
echo "Creating Paperless-Backup folder in Google Drive..."
rclone mkdir gdrive:/Paperless-Backup || true
rclone mkdir gdrive:/Paperless-Backup/data || true
rclone mkdir gdrive:/Paperless-Backup/media || true
rclone mkdir gdrive:/Paperless-Backup/.deleted || true

echo ""
echo "Folder structure created:"
rclone lsd gdrive:/Paperless-Backup/

# Show config file location
CONFIG_FILE=$(rclone config file | tail -1)
echo ""
echo "=========================================="
echo "Configuration complete!"
echo "=========================================="
echo ""
echo "Config file location: $CONFIG_FILE"
echo ""
echo "Next step: Create Kubernetes secret with this command:"
echo ""
echo "  kubectl create secret generic rclone-gdrive-config \\"
echo "    -n paperless \\"
echo "    --from-file=rclone.conf=$CONFIG_FILE"
echo ""
echo "After creating the secret, verify with:"
echo ""
echo "  kubectl get secret rclone-gdrive-config -n paperless"
echo ""
