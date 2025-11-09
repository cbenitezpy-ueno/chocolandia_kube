#!/usr/bin/env bash
#
# Setup SSH Passwordless Authentication for K3s Nodes
# Interactive script to generate SSH keys and configure passwordless access
#
# Usage: ./setup-ssh-passwordless.sh

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SSH_KEY_TYPE="ed25519"  # More secure and faster than RSA
SSH_KEY_PATH="$HOME/.ssh/id_ed25519_k3s"
SSH_CONFIG_FILE="$HOME/.ssh/config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"
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

prompt() {
    echo -e "${YELLOW}?${NC} $*"
}

# ============================================================================
# Introduction
# ============================================================================

clear
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║  SSH Passwordless Setup for K3s Cluster                      ║
║  ChocolandiaDC MVP                                            ║
╚═══════════════════════════════════════════════════════════════╝
EOF

echo ""
log "This script will:"
echo "  1. Generate a new SSH key pair (ed25519)"
echo "  2. Copy the public key to your K3s nodes"
echo "  3. Configure passwordless sudo on the nodes"
echo "  4. Test SSH connectivity"
echo ""

read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# ============================================================================
# Step 1: Generate SSH Key
# ============================================================================

log "Step 1: Generate SSH Key"
echo ""

if [[ -f "$SSH_KEY_PATH" ]]; then
    warning "SSH key already exists at $SSH_KEY_PATH"
    read -p "Do you want to use the existing key? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        prompt "Enter a new path for the SSH key (default: $SSH_KEY_PATH):"
        read -r NEW_KEY_PATH
        if [[ -n "$NEW_KEY_PATH" ]]; then
            SSH_KEY_PATH="$NEW_KEY_PATH"
        fi
        log "Generating new SSH key at $SSH_KEY_PATH..."
        ssh-keygen -t "$SSH_KEY_TYPE" -f "$SSH_KEY_PATH" -C "k3s-chocolandiadc-$(date +%Y%m%d)" -N ""
        success "SSH key generated"
    else
        success "Using existing SSH key"
    fi
else
    log "Generating new SSH key at $SSH_KEY_PATH..."
    ssh-keygen -t "$SSH_KEY_TYPE" -f "$SSH_KEY_PATH" -C "k3s-chocolandiadc-$(date +%Y%m%d)" -N ""
    success "SSH key generated"
fi

echo ""
log "Public key fingerprint:"
ssh-keygen -lf "$SSH_KEY_PATH"
echo ""

# ============================================================================
# Step 2: Collect Node Information
# ============================================================================

log "Step 2: Node Information"
echo ""

prompt "Enter the username for SSH access (e.g., cbenitez, ubuntu):"
read -r SSH_USER

prompt "Enter master1 IP address (e.g., 192.168.4.10):"
read -r MASTER1_IP

prompt "Enter nodo1 IP address (e.g., 192.168.4.11):"
read -r NODO1_IP

echo ""
log "Configuration:"
echo "  SSH User:   $SSH_USER"
echo "  SSH Key:    $SSH_KEY_PATH"
echo "  Master1 IP: $MASTER1_IP"
echo "  Nodo1 IP:   $NODO1_IP"
echo ""

read -p "Is this correct? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error "Configuration cancelled. Please run the script again."
fi

# ============================================================================
# Step 3: Copy SSH Key to Nodes
# ============================================================================

log "Step 3: Copy SSH Key to Nodes"
echo ""

warning "You will be prompted for the password for each node"
echo ""

# Copy to master1
log "Copying SSH key to master1 ($MASTER1_IP)..."
if ssh-copy-id -i "$SSH_KEY_PATH.pub" "$SSH_USER@$MASTER1_IP" 2>/dev/null; then
    success "SSH key copied to master1"
else
    error "Failed to copy SSH key to master1. Check the IP, username, and password."
fi

# Copy to nodo1
log "Copying SSH key to nodo1 ($NODO1_IP)..."
if ssh-copy-id -i "$SSH_KEY_PATH.pub" "$SSH_USER@$NODO1_IP" 2>/dev/null; then
    success "SSH key copied to nodo1"
else
    error "Failed to copy SSH key to nodo1. Check the IP, username, and password."
fi

echo ""

# ============================================================================
# Step 4: Configure Passwordless Sudo
# ============================================================================

log "Step 4: Configure Passwordless Sudo"
echo ""

warning "This step requires sudo password on each node (may be the last time!)"
echo ""

# Configure master1
log "Configuring passwordless sudo on master1..."
warning "Enter sudo password for master1 when prompted"
ssh -t -i "$SSH_KEY_PATH" "$SSH_USER@$MASTER1_IP" "echo '$SSH_USER ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$SSH_USER > /dev/null && sudo chmod 0440 /etc/sudoers.d/$SSH_USER && echo '✓ Passwordless sudo configured on master1'"

if [[ $? -eq 0 ]]; then
    success "Passwordless sudo configured on master1"
else
    warning "Failed to configure passwordless sudo on master1 (may already be configured)"
fi

# Configure nodo1
log "Configuring passwordless sudo on nodo1..."
warning "Enter sudo password for nodo1 when prompted"
ssh -t -i "$SSH_KEY_PATH" "$SSH_USER@$NODO1_IP" "echo '$SSH_USER ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$SSH_USER > /dev/null && sudo chmod 0440 /etc/sudoers.d/$SSH_USER && echo '✓ Passwordless sudo configured on nodo1'"

if [[ $? -eq 0 ]]; then
    success "Passwordless sudo configured on nodo1"
else
    warning "Failed to configure passwordless sudo on nodo1 (may already be configured)"
fi

echo ""

# ============================================================================
# Step 5: Test SSH Connectivity
# ============================================================================

log "Step 5: Test SSH Connectivity"
echo ""

# Test master1
log "Testing SSH to master1..."
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USER@$MASTER1_IP" "hostname && sudo whoami" &>/dev/null; then
    success "SSH and sudo working on master1"
else
    error "SSH or sudo test failed on master1"
fi

# Test nodo1
log "Testing SSH to nodo1..."
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USER@$NODO1_IP" "hostname && sudo whoami" &>/dev/null; then
    success "SSH and sudo working on nodo1"
else
    error "SSH or sudo test failed on nodo1"
fi

echo ""

# ============================================================================
# Step 6: Update SSH Config (Optional)
# ============================================================================

log "Step 6: SSH Config (Optional)"
echo ""

prompt "Do you want to add SSH aliases to $SSH_CONFIG_FILE? (y/n):"
read -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Adding SSH config entries..."

    # Backup existing config
    if [[ -f "$SSH_CONFIG_FILE" ]]; then
        cp "$SSH_CONFIG_FILE" "$SSH_CONFIG_FILE.backup.$(date +%Y%m%d%H%M%S)"
        log "Backup created: $SSH_CONFIG_FILE.backup.*"
    fi

    # Add entries
    cat >> "$SSH_CONFIG_FILE" << EOF

# K3s ChocolandiaDC MVP Cluster
Host master1
    HostName $MASTER1_IP
    User $SSH_USER
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host nodo1
    HostName $NODO1_IP
    User $SSH_USER
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

    success "SSH config updated"
    echo ""
    log "You can now connect with:"
    echo "  ssh master1"
    echo "  ssh nodo1"
else
    log "Skipping SSH config update"
fi

echo ""

# ============================================================================
# Step 7: Create terraform.tfvars
# ============================================================================

log "Step 7: Create terraform.tfvars"
echo ""

TFVARS_PATH="/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars"

if [[ -f "$TFVARS_PATH" ]]; then
    warning "terraform.tfvars already exists"
    prompt "Do you want to overwrite it? (y/n):"
    read -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Skipping terraform.tfvars creation"
    else
        log "Creating terraform.tfvars..."
        cat > "$TFVARS_PATH" << EOF
# ChocolandiaDC MVP Environment Configuration
# Generated by setup-ssh-passwordless.sh on $(date)

cluster_name = "chocolandiadc-mvp"
k3s_version  = "v1.28.3+k3s1"

# Node IP Addresses
master1_hostname = "master1"
master1_ip       = "$MASTER1_IP"

nodo1_hostname = "nodo1"
nodo1_ip       = "$NODO1_IP"

# SSH Configuration
ssh_user             = "$SSH_USER"
ssh_private_key_path = "$SSH_KEY_PATH"
ssh_port             = 22

# K3s Configuration
disable_components = ["traefik"]
EOF
        success "terraform.tfvars created at $TFVARS_PATH"
    fi
else
    log "Creating terraform.tfvars..."
    cat > "$TFVARS_PATH" << EOF
# ChocolandiaDC MVP Environment Configuration
# Generated by setup-ssh-passwordless.sh on $(date)

cluster_name = "chocolandiadc-mvp"
k3s_version  = "v1.28.3+k3s1"

# Node IP Addresses
master1_hostname = "master1"
master1_ip       = "$MASTER1_IP"

nodo1_hostname = "nodo1"
nodo1_ip       = "$NODO1_IP"

# SSH Configuration
ssh_user             = "$SSH_USER"
ssh_private_key_path = "$SSH_KEY_PATH"
ssh_port             = 22

# K3s Configuration
disable_components = ["traefik"]
EOF
    success "terraform.tfvars created at $TFVARS_PATH"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║  Setup Complete!                                              ║
╚═══════════════════════════════════════════════════════════════╝
EOF

echo ""
success "SSH passwordless authentication is configured"
echo ""

log "Summary:"
echo "  ✓ SSH key generated: $SSH_KEY_PATH"
echo "  ✓ Public key copied to master1 and nodo1"
echo "  ✓ Passwordless sudo configured on both nodes"
echo "  ✓ SSH connectivity tested successfully"
if [[ -f "$TFVARS_PATH" ]]; then
    echo "  ✓ terraform.tfvars created"
fi
echo ""

log "Next Steps:"
echo ""
echo "  1. Verify SSH access:"
echo "     ssh -i $SSH_KEY_PATH $SSH_USER@$MASTER1_IP"
echo "     ssh -i $SSH_KEY_PATH $SSH_USER@$NODO1_IP"
echo ""
echo "  2. Deploy the K3s cluster:"
echo "     cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp"
echo "     tofu plan"
echo "     tofu apply"
echo ""
echo "  3. Access the cluster:"
echo "     export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig"
echo "     kubectl get nodes"
echo ""

log "Happy clustering! 🚀"
echo ""
