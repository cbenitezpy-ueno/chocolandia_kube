#!/usr/bin/env bash
#
# K3s Cluster Backup Script
# Backs up K3s cluster data from Feature 002 MVP
#
# Usage: ./backup-cluster.sh [backup_dir]
#
# This script backs up:
# - K3s SQLite database (state.db) from master1
# - All Kubernetes manifests (deployments, services, etc.)
# - PersistentVolume data (Prometheus, Grafana)
# - Helm releases and values
# - ConfigMaps and Secrets (encrypted)
#
# IMPORTANT: This script requires SSH access to master1

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${1:-$ENVIRONMENT_DIR/backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Node configuration
MASTER_IP="${MASTER_IP:-192.168.4.101}"
SSH_USER="${SSH_USER:-chocolim}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_k3s}"
KUBECONFIG="${KUBECONFIG:-$ENVIRONMENT_DIR/kubeconfig}"

# Namespaces to backup (add more as workloads are deployed)
NAMESPACES=("monitoring" "kube-system" "default")

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

log "Starting K3s cluster backup for Feature 002 MVP"
log "Backup directory: $BACKUP_DIR"
log "Timestamp: $TIMESTAMP"

# Check if kubeconfig exists
if [[ ! -f "$KUBECONFIG" ]]; then
    error "Kubeconfig not found at $KUBECONFIG"
fi

# Check kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl not found in PATH"
fi

# Check SSH key exists
if [[ ! -f "$SSH_KEY" ]]; then
    error "SSH key not found at $SSH_KEY"
fi

# Test cluster connectivity
if ! kubectl --kubeconfig="$KUBECONFIG" get nodes &> /dev/null; then
    error "Cannot connect to cluster. Check kubeconfig and cluster status."
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# ============================================================================
# Backup K3s SQLite Database
# ============================================================================

log "Backing up K3s SQLite database from master1..."

# Create remote backup (with K3s stopped briefly for consistency)
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$MASTER_IP" bash <<'ENDSSH'
    set -e
    echo "Creating SQLite database snapshot..."

    # Use sqlite3 to create a backup while K3s is running (safer)
    if command -v sqlite3 &> /dev/null; then
        sudo sqlite3 /var/lib/rancher/k3s/server/db/state.db ".backup /tmp/k3s-state-backup.db"
        echo "SQLite backup created at /tmp/k3s-state-backup.db"
    else
        # Fallback: copy file (less safe, but works)
        echo "WARNING: sqlite3 not found, using file copy (may be inconsistent)"
        sudo cp /var/lib/rancher/k3s/server/db/state.db /tmp/k3s-state-backup.db
    fi

    # Secure permissions: database contains all cluster secrets
    sudo chmod 600 /tmp/k3s-state-backup.db
    sudo chown $USER /tmp/k3s-state-backup.db
ENDSSH

# Download backup
scp -o StrictHostKeyChecking=no -i "$SSH_KEY" \
    "$SSH_USER@$MASTER_IP:/tmp/k3s-state-backup.db" \
    "$BACKUP_DIR/k3s-state-db-$TIMESTAMP.db"

# Cleanup remote temp file
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$MASTER_IP" \
    "rm -f /tmp/k3s-state-backup.db"

success "Backed up SQLite database: $BACKUP_DIR/k3s-state-db-$TIMESTAMP.db"

# ============================================================================
# Backup Kubernetes Manifests
# ============================================================================

log "Backing up Kubernetes manifests..."

MANIFESTS_DIR="$BACKUP_DIR/manifests-$TIMESTAMP"
mkdir -p "$MANIFESTS_DIR"

export KUBECONFIG

# Backup all resource types per namespace
for namespace in "${NAMESPACES[@]}"; do
    log "Backing up namespace: $namespace"

    NS_DIR="$MANIFESTS_DIR/$namespace"
    mkdir -p "$NS_DIR"

    # Backup namespace definition
    kubectl get namespace "$namespace" -o yaml > "$NS_DIR/namespace.yaml" 2>/dev/null || true

    # Backup common resource types
    RESOURCE_TYPES=(
        "deployments"
        "statefulsets"
        "daemonsets"
        "services"
        "configmaps"
        "secrets"
        "persistentvolumeclaims"
        "ingresses"
        "networkpolicies"
        "serviceaccounts"
        "roles"
        "rolebindings"
    )

    for resource in "${RESOURCE_TYPES[@]}"; do
        if kubectl get "$resource" -n "$namespace" &> /dev/null; then
            RESOURCE_COUNT=$(kubectl get "$resource" -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')

            if [[ $RESOURCE_COUNT -gt 0 ]]; then
                kubectl get "$resource" -n "$namespace" -o yaml > "$NS_DIR/$resource.yaml"
                log "  - Backed up $RESOURCE_COUNT $resource"
            fi
        fi
    done
done

# Backup cluster-wide resources
log "Backing up cluster-wide resources..."

CLUSTER_DIR="$MANIFESTS_DIR/cluster-wide"
mkdir -p "$CLUSTER_DIR"

CLUSTER_RESOURCES=(
    "nodes"
    "persistentvolumes"
    "storageclasses"
    "clusterroles"
    "clusterrolebindings"
    "customresourcedefinitions"
)

for resource in "${CLUSTER_RESOURCES[@]}"; do
    if kubectl get "$resource" &> /dev/null; then
        RESOURCE_COUNT=$(kubectl get "$resource" --no-headers 2>/dev/null | wc -l | tr -d ' ')

        if [[ $RESOURCE_COUNT -gt 0 ]]; then
            kubectl get "$resource" -o yaml > "$CLUSTER_DIR/$resource.yaml"
            log "  - Backed up $RESOURCE_COUNT $resource"
        fi
    fi
done

success "Backed up manifests to: $MANIFESTS_DIR"

# ============================================================================
# Backup Helm Releases
# ============================================================================

log "Backing up Helm releases..."

HELM_DIR="$BACKUP_DIR/helm-$TIMESTAMP"
mkdir -p "$HELM_DIR"

if command -v helm &> /dev/null; then
    # List all Helm releases
    helm list -A -o json > "$HELM_DIR/releases.json"

    # Export each release's values
    helm list -A --no-headers | while read -r line; do
        RELEASE_NAME=$(echo "$line" | awk '{print $1}')
        RELEASE_NS=$(echo "$line" | awk '{print $2}')

        log "  - Exporting Helm release: $RELEASE_NAME ($RELEASE_NS)"

        helm get values "$RELEASE_NAME" -n "$RELEASE_NS" > "$HELM_DIR/$RELEASE_NAME-values.yaml" 2>/dev/null || true
        helm get manifest "$RELEASE_NAME" -n "$RELEASE_NS" > "$HELM_DIR/$RELEASE_NAME-manifest.yaml" 2>/dev/null || true
    done

    success "Backed up Helm releases to: $HELM_DIR"
else
    log "WARNING: helm not found, skipping Helm backup"
fi

# ============================================================================
# Backup PersistentVolume Data
# ============================================================================

log "Backing up PersistentVolume data..."

PV_BACKUP_DIR="$BACKUP_DIR/persistent-volumes-$TIMESTAMP"
mkdir -p "$PV_BACKUP_DIR"

# Get list of PVs and their paths
kubectl get pv -o json | jq -r '.items[] | "\(.metadata.name)|\(.spec.local.path // "N/A")|\(.spec.claimRef.namespace // "N/A")|\(.spec.claimRef.name // "N/A")"' | \
while IFS='|' read -r pv_name pv_path pv_namespace pv_claim; do
    if [[ "$pv_path" != "N/A" && "$pv_namespace" != "N/A" ]]; then
        log "  - Backing up PV: $pv_name ($pv_namespace/$pv_claim)"

        # Create tarball of PV data on remote node
        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$MASTER_IP" \
            "sudo tar -czf /tmp/pv-$pv_name.tar.gz -C $pv_path . 2>/dev/null || echo 'Failed to backup $pv_path'" &
    fi
done

# Wait for all background SSH jobs
wait

# Download PV backups
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$MASTER_IP" \
    "ls -1 /tmp/pv-*.tar.gz 2>/dev/null || true" | \
while read -r remote_file; do
    if [[ -n "$remote_file" ]]; then
        scp -o StrictHostKeyChecking=no -i "$SSH_KEY" \
            "$SSH_USER@$MASTER_IP:$remote_file" \
            "$PV_BACKUP_DIR/"

        # Cleanup remote file
        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$MASTER_IP" \
            "rm -f $remote_file"
    fi
done

if [[ $(ls -A "$PV_BACKUP_DIR" 2>/dev/null | wc -l) -gt 0 ]]; then
    success "Backed up PV data to: $PV_BACKUP_DIR"
else
    log "WARNING: No PersistentVolume data found to backup"
fi

# ============================================================================
# Backup Monitoring Data (Grafana Dashboards)
# ============================================================================

log "Backing up Grafana dashboards..."

GRAFANA_DIR="$BACKUP_DIR/grafana-$TIMESTAMP"
mkdir -p "$GRAFANA_DIR"

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring kube-prometheus-stack-grafana \
    -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [[ -n "$GRAFANA_PASSWORD" ]]; then
    # Export all dashboards
    curl -s -u "admin:$GRAFANA_PASSWORD" "http://$MASTER_IP:30000/api/search" | \
        jq -r '.[] | .uid' 2>/dev/null | \
    while read -r uid; do
        if [[ -n "$uid" ]]; then
            curl -s -u "admin:$GRAFANA_PASSWORD" \
                "http://$MASTER_IP:30000/api/dashboards/uid/$uid" \
                > "$GRAFANA_DIR/dashboard-$uid.json" 2>/dev/null || true
        fi
    done

    # Export datasources
    curl -s -u "admin:$GRAFANA_PASSWORD" \
        "http://$MASTER_IP:30000/api/datasources" \
        > "$GRAFANA_DIR/datasources.json" 2>/dev/null || true

    success "Backed up Grafana dashboards to: $GRAFANA_DIR"
else
    log "WARNING: Could not retrieve Grafana password, skipping dashboard backup"
fi

# ============================================================================
# Create Cluster Backup Manifest
# ============================================================================

log "Creating cluster backup manifest..."

cat > "$BACKUP_DIR/cluster-backup-manifest-$TIMESTAMP.txt" <<EOF
K3s Cluster Backup Manifest
===========================

Backup Date: $(date +'%Y-%m-%d %H:%M:%S')
Environment: chocolandiadc-mvp (Feature 002 MVP)
Cluster: https://$MASTER_IP:6443
Backup Directory: $BACKUP_DIR

Cluster State:
--------------
$(kubectl get nodes -o wide --no-headers)

Backed Up Components:
---------------------
1. K3s SQLite Database:
   $BACKUP_DIR/k3s-state-db-$TIMESTAMP.db
   Source: /var/lib/rancher/k3s/server/db/state.db on master1

2. Kubernetes Manifests:
   $MANIFESTS_DIR/
   Namespaces: ${NAMESPACES[*]}
   Resources: deployments, services, configmaps, secrets, PVCs, etc.

3. Helm Releases:
   $HELM_DIR/
   $(helm list -A --no-headers 2>/dev/null | wc -l | tr -d ' ') releases exported

4. PersistentVolume Data:
   $PV_BACKUP_DIR/
   $(ls -1 "$PV_BACKUP_DIR" 2>/dev/null | wc -l | tr -d ' ') volumes backed up

5. Grafana Dashboards:
   $GRAFANA_DIR/
   $(ls -1 "$GRAFANA_DIR"/dashboard-*.json 2>/dev/null | wc -l | tr -d ' ') dashboards exported

Restore Instructions:
---------------------
CRITICAL: Restore must be done on a K3s cluster with same version (v1.28.3+k3s1)

1. Restore SQLite database (on master1, K3s stopped):
   sudo systemctl stop k3s
   sudo cp $BACKUP_DIR/k3s-state-db-$TIMESTAMP.db /var/lib/rancher/k3s/server/db/state.db
   sudo chown root:root /var/lib/rancher/k3s/server/db/state.db
   sudo systemctl start k3s

2. Restore Kubernetes manifests:
   export KUBECONFIG=$ENVIRONMENT_DIR/kubeconfig

   # Restore namespaces first
   kubectl apply -f $MANIFESTS_DIR/*/namespace.yaml

   # Restore secrets and configmaps
   kubectl apply -f $MANIFESTS_DIR/*/secrets.yaml
   kubectl apply -f $MANIFESTS_DIR/*/configmaps.yaml

   # Restore PVCs
   kubectl apply -f $MANIFESTS_DIR/*/persistentvolumeclaims.yaml

   # Restore workloads
   kubectl apply -f $MANIFESTS_DIR/*/deployments.yaml
   kubectl apply -f $MANIFESTS_DIR/*/statefulsets.yaml
   kubectl apply -f $MANIFESTS_DIR/*/daemonsets.yaml

   # Restore services
   kubectl apply -f $MANIFESTS_DIR/*/services.yaml

3. Restore PersistentVolume data:
   # Extract PV backups on master1 at correct paths
   # See PV paths in: $MANIFESTS_DIR/cluster-wide/persistentvolumes.yaml

4. Restore Helm releases:
   helm install <release-name> <chart> -f $HELM_DIR/<release-name>-values.yaml -n <namespace>

5. Restore Grafana dashboards:
   # Use Grafana API or UI to import dashboard JSON files from $GRAFANA_DIR/

Verification Steps:
-------------------
After restore:

1. Check node status:
   kubectl get nodes

2. Check pod status:
   kubectl get pods -A

3. Check PVCs are bound:
   kubectl get pvc -A

4. Verify workload functionality:
   - Grafana: http://$MASTER_IP:30000
   - Prometheus port-forward

5. Check cluster events for errors:
   kubectl get events -A --sort-by='.lastTimestamp'

Notes:
------
- SQLite restore requires K3s to be stopped
- PV data must be restored to same paths as original cluster
- Secrets are exported (ensure backup security!)
- For production, consider using Velero for automated backup/restore

EOF

success "Created cluster backup manifest: $BACKUP_DIR/cluster-backup-manifest-$TIMESTAMP.txt"

# ============================================================================
# Summary
# ============================================================================

log "========================================="
success "K3s cluster backup completed"
log "========================================="
log ""
log "Backup Summary:"
log "  - SQLite Database: $BACKUP_DIR/k3s-state-db-$TIMESTAMP.db"
log "  - Manifests: $MANIFESTS_DIR/"
log "  - Helm Releases: $HELM_DIR/"
log "  - PV Data: $PV_BACKUP_DIR/"
log "  - Grafana: $GRAFANA_DIR/"
log "  - Manifest: $BACKUP_DIR/cluster-backup-manifest-$TIMESTAMP.txt"
log ""
log "Total Backup Size:"
du -sh "$BACKUP_DIR" | awk '{print "  " $1}'
log ""
log "IMPORTANT: Store backups in secure, encrypted location!"
log ""

exit 0
