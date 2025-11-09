#!/usr/bin/env bash
#
# K3s Agent (Worker Node) Installation Script
# Installs K3s in agent mode and joins existing cluster
#
# Usage: ./install-k3s-agent.sh <k3s_version> <server_url> <join_token> <node_ip> <k3s_flags>
#
# Arguments:
#   $1 - K3s version (e.g., "v1.28.3+k3s1" or "latest")
#   $2 - K3s server URL (e.g., "https://192.168.4.10:6443")
#   $3 - Cluster join token (from server node)
#   $4 - Node IP address (e.g., "192.168.4.11")
#   $5 - K3s agent flags (space-separated, optional)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

K3S_VERSION="${1:-v1.28.3+k3s1}"
K3S_URL="${2:?Server URL is required}"
K3S_TOKEN="${3:?Join token is required}"
NODE_IP="${4:-}"
K3S_FLAGS="${5:-}"

# K3s installation URL
INSTALL_K3S_URL="https://get.k3s.io"

# Installation log
LOG_FILE="/var/log/k3s-install.log"

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
    fi
}

check_dependencies() {
    local deps=("curl" "systemctl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Required dependency '$dep' not found"
        fi
    done
}

# ============================================================================
# Pre-Installation Checks
# ============================================================================

log "Starting K3s agent installation (version: $K3S_VERSION)"
check_root
check_dependencies

# Validate server URL
if [[ ! "$K3S_URL" =~ ^https:// ]]; then
    error "Server URL must start with https://"
fi

# Check if K3s is already installed
if systemctl is-active --quiet k3s-agent; then
    log "K3s agent is already running. Skipping installation."
    exit 0
fi

# ============================================================================
# System Preparation
# ============================================================================

log "Preparing system for K3s installation..."

# Disable swap (required for Kubernetes)
if swapon --show | grep -q '^/'; then
    log "Disabling swap..."
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
fi

# Enable IP forwarding
log "Enabling IP forwarding..."
cat > /etc/sysctl.d/99-k3s.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl --system > /dev/null 2>&1

# ============================================================================
# K3s Agent Installation
# ============================================================================

log "Installing K3s agent..."
log "Connecting to server: $K3S_URL"

# Build K3s installation command with environment variables
export K3S_URL="$K3S_URL"
export K3S_TOKEN="$K3S_TOKEN"
export INSTALL_K3S_VERSION="$K3S_VERSION"

# Build exec arguments
EXEC_ARGS=""
if [[ -n "$NODE_IP" ]]; then
    EXEC_ARGS="$EXEC_ARGS --node-ip=$NODE_IP"
fi

if [[ -n "$K3S_FLAGS" ]]; then
    EXEC_ARGS="$EXEC_ARGS $K3S_FLAGS"
fi

# Install K3s agent
if [[ -n "$EXEC_ARGS" ]]; then
    export INSTALL_K3S_EXEC="$EXEC_ARGS"
    log "Running: curl -sfL $INSTALL_K3S_URL | sh -s - agent (with exec args: $EXEC_ARGS)"
    curl -sfL "$INSTALL_K3S_URL" | sh -s - agent >> "$LOG_FILE" 2>&1 || error "K3s agent installation failed"
else
    log "Running: curl -sfL $INSTALL_K3S_URL | sh -s - agent"
    curl -sfL "$INSTALL_K3S_URL" | sh -s - agent >> "$LOG_FILE" 2>&1 || error "K3s agent installation failed"
fi

# ============================================================================
# Post-Installation Configuration
# ============================================================================

log "Configuring K3s agent..."

# Wait for K3s agent to be ready
log "Waiting for K3s agent to be ready..."
for i in {1..30}; do
    if systemctl is-active --quiet k3s-agent; then
        log "K3s agent is active"
        break
    fi
    if [[ $i -eq 30 ]]; then
        error "K3s agent failed to start after 30 seconds"
    fi
    sleep 1
done

# ============================================================================
# Verification
# ============================================================================

log "Verifying K3s agent installation..."

# Check K3s agent service status
if ! systemctl is-active --quiet k3s-agent; then
    error "K3s agent service is not running"
fi

# Display service status
log "K3s agent installation complete!"
systemctl status k3s-agent --no-pager | tee -a "$LOG_FILE"

log "Agent successfully joined cluster at $K3S_URL"
log "Verify node status on server: kubectl get nodes"

exit 0
