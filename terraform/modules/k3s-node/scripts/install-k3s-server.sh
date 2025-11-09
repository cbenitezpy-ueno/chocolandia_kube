#!/usr/bin/env bash
#
# K3s Server (Control-Plane) Installation Script
# Installs K3s in server mode with SQLite datastore (single-server, non-HA)
#
# Usage: ./install-k3s-server.sh <k3s_version> <k3s_flags> <node_ip> <tls_san>
#
# Arguments:
#   $1 - K3s version (e.g., "v1.28.3+k3s1" or "latest")
#   $2 - K3s server flags (space-separated, e.g., "--disable=traefik --write-kubeconfig-mode=644")
#   $3 - Node IP address (e.g., "192.168.4.10")
#   $4 - TLS SAN (comma-separated hostnames/IPs for TLS cert)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

K3S_VERSION="${1:-v1.28.3+k3s1}"
K3S_FLAGS="${2:-}"
NODE_IP="${3:-}"
TLS_SAN="${4:-}"

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

log "Starting K3s server installation (version: $K3S_VERSION)"
check_root
check_dependencies

# Check if K3s is already installed
if systemctl is-active --quiet k3s; then
    log "K3s server is already running. Skipping installation."
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
# K3s Server Installation
# ============================================================================

log "Installing K3s server..."

# Build K3s installation command
INSTALL_CMD="curl -sfL $INSTALL_K3S_URL | INSTALL_K3S_VERSION='$K3S_VERSION' sh -s - server"

# Add flags
if [[ -n "$K3S_FLAGS" ]]; then
    INSTALL_CMD="$INSTALL_CMD $K3S_FLAGS"
fi

# Add node IP if provided
if [[ -n "$NODE_IP" ]]; then
    INSTALL_CMD="INSTALL_K3S_EXEC='--node-ip=$NODE_IP' $INSTALL_CMD"
fi

# Add TLS SAN if provided
if [[ -n "$TLS_SAN" ]]; then
    INSTALL_CMD="INSTALL_K3S_EXEC='--tls-san=$TLS_SAN' $INSTALL_CMD"
fi

# Execute installation
log "Running: $INSTALL_CMD"
eval "$INSTALL_CMD" >> "$LOG_FILE" 2>&1 || error "K3s installation failed"

# ============================================================================
# Post-Installation Configuration
# ============================================================================

log "Configuring K3s server..."

# Wait for K3s to be ready
log "Waiting for K3s server to be ready..."
for i in {1..30}; do
    if systemctl is-active --quiet k3s; then
        log "K3s server is active"
        break
    fi
    if [[ $i -eq 30 ]]; then
        error "K3s server failed to start after 30 seconds"
    fi
    sleep 1
done

# Wait for kubeconfig to be generated
log "Waiting for kubeconfig..."
for i in {1..30}; do
    if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
        log "Kubeconfig generated successfully"
        break
    fi
    if [[ $i -eq 30 ]]; then
        error "Kubeconfig not found after 30 seconds"
    fi
    sleep 1
done

# Set proper permissions on kubeconfig (secure: only root can read)
chmod 600 /etc/rancher/k3s/k3s.yaml
chown root:root /etc/rancher/k3s/k3s.yaml

# Wait for cluster to be ready
log "Waiting for cluster to be ready..."
for i in {1..60}; do
    if k3s kubectl get nodes &> /dev/null; then
        log "Cluster is ready"
        break
    fi
    if [[ $i -eq 60 ]]; then
        error "Cluster not ready after 60 seconds"
    fi
    sleep 2
done

# ============================================================================
# Verification
# ============================================================================

log "Verifying K3s installation..."

# Check K3s service status
if ! systemctl is-active --quiet k3s; then
    error "K3s service is not running"
fi

# Check node status
if ! k3s kubectl get nodes | grep -q "Ready"; then
    error "K3s node is not in Ready state"
fi

# Display cluster info
log "K3s server installation complete!"
log "Cluster information:"
k3s kubectl get nodes -o wide | tee -a "$LOG_FILE"

# Display join token location
log "Cluster join token is available at: /var/lib/rancher/k3s/server/node-token"

exit 0
