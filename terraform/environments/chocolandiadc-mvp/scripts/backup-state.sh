#!/usr/bin/env bash
#
# OpenTofu State Backup Script
# Backs up OpenTofu state files and cluster token for Feature 002 MVP
#
# Usage: ./backup-state.sh [backup_dir]
#
# This script backs up:
# - OpenTofu state files (.terraform/, terraform.tfstate*)
# - Cluster join token from master1
# - Kubeconfig file
#
# Backups are timestamped and compressed for archival

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${1:-$ENVIRONMENT_DIR/backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="terraform-state-$TIMESTAMP"

# Node configuration (read from terraform.tfvars if possible)
MASTER_IP="${MASTER_IP:-192.168.4.101}"
SSH_USER="${SSH_USER:-chocolim}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_k3s}"

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

success() {
    log "SUCCESS: $*"
}

# ============================================================================
# Pre-Flight Checks
# ============================================================================

log "Starting OpenTofu state backup for Feature 002 MVP"
log "Backup directory: $BACKUP_DIR"
log "Timestamp: $TIMESTAMP"

# Check if we're in the right directory
if [[ ! -f "$ENVIRONMENT_DIR/providers.tf" ]]; then
    error "Not in chocolandiadc-mvp environment directory. Expected: $ENVIRONMENT_DIR/providers.tf"
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
cd "$ENVIRONMENT_DIR"

# ============================================================================
# Backup OpenTofu State Files
# ============================================================================

log "Backing up OpenTofu state files..."

# Create temporary directory for backup
TEMP_BACKUP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_BACKUP_DIR" EXIT

mkdir -p "$TEMP_BACKUP_DIR/terraform-state"

# Copy state files
if [[ -f "terraform.tfstate" ]]; then
    cp terraform.tfstate "$TEMP_BACKUP_DIR/terraform-state/"
    log "Copied terraform.tfstate"
else
    log "WARNING: terraform.tfstate not found (may be using remote state)"
fi

if [[ -f "terraform.tfstate.backup" ]]; then
    cp terraform.tfstate.backup "$TEMP_BACKUP_DIR/terraform-state/"
    log "Copied terraform.tfstate.backup"
fi

# Copy .terraform directory (provider binaries and lock file)
if [[ -d ".terraform" ]]; then
    cp -r .terraform "$TEMP_BACKUP_DIR/terraform-state/"
    log "Copied .terraform directory"
fi

if [[ -f ".terraform.lock.hcl" ]]; then
    cp .terraform.lock.hcl "$TEMP_BACKUP_DIR/terraform-state/"
    log "Copied .terraform.lock.hcl"
fi

# Copy configuration files for reference
cp *.tf "$TEMP_BACKUP_DIR/terraform-state/" 2>/dev/null || true
if [[ -f "terraform.tfvars" ]]; then
    cp terraform.tfvars "$TEMP_BACKUP_DIR/terraform-state/"
    log "Copied terraform.tfvars"
fi

# Create compressed archive
cd "$TEMP_BACKUP_DIR"
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" terraform-state/
success "Created state backup: $BACKUP_DIR/$BACKUP_NAME.tar.gz"

# ============================================================================
# Backup Cluster Token
# ============================================================================

log "Backing up cluster join token from master1..."

if [[ ! -f "$SSH_KEY" ]]; then
    log "WARNING: SSH key not found at $SSH_KEY, skipping token backup"
else
    if ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$MASTER_IP" "sudo test -f /var/lib/rancher/k3s/server/node-token" 2>/dev/null; then
        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$MASTER_IP" \
            "sudo cat /var/lib/rancher/k3s/server/node-token" > \
            "$BACKUP_DIR/cluster-token-$TIMESTAMP.txt"

        chmod 600 "$BACKUP_DIR/cluster-token-$TIMESTAMP.txt"
        success "Backed up cluster token: $BACKUP_DIR/cluster-token-$TIMESTAMP.txt"
    else
        log "WARNING: Could not access cluster token on master1"
    fi
fi

# ============================================================================
# Backup Kubeconfig
# ============================================================================

log "Backing up kubeconfig..."

cd "$ENVIRONMENT_DIR"

if [[ -f "kubeconfig" ]]; then
    cp kubeconfig "$BACKUP_DIR/kubeconfig-$TIMESTAMP.yaml"
    chmod 600 "$BACKUP_DIR/kubeconfig-$TIMESTAMP.yaml"
    success "Backed up kubeconfig: $BACKUP_DIR/kubeconfig-$TIMESTAMP.yaml"
else
    log "WARNING: kubeconfig not found at $ENVIRONMENT_DIR/kubeconfig"
fi

# ============================================================================
# Create Backup Manifest
# ============================================================================

log "Creating backup manifest..."

cat > "$BACKUP_DIR/backup-manifest-$TIMESTAMP.txt" <<EOF
OpenTofu State Backup Manifest
================================

Backup Date: $(date +'%Y-%m-%d %H:%M:%S')
Environment: chocolandiadc-mvp (Feature 002 MVP)
Backup Directory: $BACKUP_DIR

Files Included:
---------------
1. OpenTofu State Archive:
   $BACKUP_DIR/$BACKUP_NAME.tar.gz

   Contents:
   - terraform.tfstate (current state)
   - terraform.tfstate.backup (previous state)
   - .terraform/ (provider binaries and modules)
   - .terraform.lock.hcl (provider version locks)
   - *.tf (configuration files)
   - terraform.tfvars (variable values)

2. Cluster Join Token:
   $BACKUP_DIR/cluster-token-$TIMESTAMP.txt

   Purpose: Used for joining new worker nodes to cluster
   Location on master1: /var/lib/rancher/k3s/server/node-token

3. Kubeconfig:
   $BACKUP_DIR/kubeconfig-$TIMESTAMP.yaml

   Purpose: Kubernetes cluster access credentials
   API Endpoint: https://$MASTER_IP:6443

Restore Instructions:
---------------------
To restore OpenTofu state:

1. Extract state archive:
   cd $ENVIRONMENT_DIR
   tar -xzf $BACKUP_DIR/$BACKUP_NAME.tar.gz --strip-components=1

2. Verify state:
   tofu show

3. If needed, restore cluster token:
   scp $BACKUP_DIR/cluster-token-$TIMESTAMP.txt $SSH_USER@$MASTER_IP:/tmp/node-token
   ssh $SSH_USER@$MASTER_IP "sudo mv /tmp/node-token /var/lib/rancher/k3s/server/node-token"
   ssh $SSH_USER@$MASTER_IP "sudo systemctl restart k3s"

4. Verify kubeconfig:
   export KUBECONFIG=$BACKUP_DIR/kubeconfig-$TIMESTAMP.yaml
   kubectl get nodes

Notes:
------
- This backup does NOT include:
  - K3s SQLite database (/var/lib/rancher/k3s/server/db/state.db)
  - PersistentVolume data
  - Application data

- For complete cluster backup, also run: backup-cluster.sh

- Store backups in secure location with encryption at rest

EOF

success "Created backup manifest: $BACKUP_DIR/backup-manifest-$TIMESTAMP.txt"

# ============================================================================
# Summary
# ============================================================================

log "========================================="
success "OpenTofu state backup completed"
log "========================================="
log ""
log "Backup Summary:"
log "  - State Archive: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
log "  - Cluster Token: $BACKUP_DIR/cluster-token-$TIMESTAMP.txt"
log "  - Kubeconfig: $BACKUP_DIR/kubeconfig-$TIMESTAMP.yaml"
log "  - Manifest: $BACKUP_DIR/backup-manifest-$TIMESTAMP.txt"
log ""
log "Total Backup Size:"
du -sh "$BACKUP_DIR" | awk '{print "  " $1}'
log ""
log "Latest Backups:"
ls -lht "$BACKUP_DIR" | head -10
log ""

exit 0
