#!/bin/bash
# Restore script for Paperless-ngx from Google Drive backup
# Feature: 028-paperless-gdrive-backup
#
# This script restores Paperless data from Google Drive backup
# Run from a machine with kubectl access to the cluster

set -e

NAMESPACE="paperless"
RCLONE_SECRET="rclone-gdrive-config"
DATA_PVC="paperless-ngx-data"
MEDIA_PVC="paperless-ngx-media"
GDRIVE_REMOTE="gdrive:/Paperless-Backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================="
echo "Paperless Restore from Google Drive"
echo -e "==========================================${NC}"
echo ""

# Check kubectl access
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}ERROR: Cannot access namespace $NAMESPACE${NC}"
    echo "Make sure kubectl is configured correctly"
    exit 1
fi

# Check if rclone secret exists
if ! kubectl get secret $RCLONE_SECRET -n $NAMESPACE &> /dev/null; then
    echo -e "${RED}ERROR: rclone secret '$RCLONE_SECRET' not found in namespace $NAMESPACE${NC}"
    echo "Run setup-rclone.sh first and create the secret"
    exit 1
fi

# Prompt for confirmation
echo -e "${YELLOW}WARNING: This will restore data from Google Drive backup${NC}"
echo ""
echo "This script will:"
echo "  1. Scale Paperless deployment to 0 replicas"
echo "  2. Create a temporary restore pod"
echo "  3. Sync data from Google Drive to PVCs"
echo "  4. Clean up restore pod"
echo "  5. Scale Paperless back to 1 replica"
echo ""
echo -e "${YELLOW}Paperless will be UNAVAILABLE during the restore process${NC}"
echo ""
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

# Check for optional arguments
RESTORE_TYPE="full"
RESTORE_PATH=""
RESTORE_DATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --partial)
            RESTORE_TYPE="partial"
            RESTORE_PATH="$2"
            shift 2
            ;;
        --from-deleted)
            RESTORE_DATE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo ""
echo "Starting restore process..."
echo ""

# Step 1: Scale down Paperless
echo "Step 1/5: Scaling down Paperless deployment..."
kubectl scale deployment paperless-ngx -n $NAMESPACE --replicas=0

echo "Waiting for pods to terminate..."
kubectl wait --for=delete pod -l app.kubernetes.io/name=paperless-ngx -n $NAMESPACE --timeout=120s 2>/dev/null || true

# Step 2: Create restore pod
echo ""
echo "Step 2/5: Creating restore pod..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: paperless-restore
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: paperless-restore
spec:
  containers:
  - name: restore
    image: rclone/rclone:latest
    command: ["sleep", "infinity"]
    volumeMounts:
    - name: data
      mountPath: /data
    - name: media
      mountPath: /media
    - name: rclone-config
      mountPath: /config/rclone
      readOnly: true
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: $DATA_PVC
  - name: media
    persistentVolumeClaim:
      claimName: $MEDIA_PVC
  - name: rclone-config
    secret:
      secretName: $RCLONE_SECRET
  restartPolicy: Never
EOF

echo "Waiting for restore pod to be ready..."
kubectl wait --for=condition=Ready pod/paperless-restore -n $NAMESPACE --timeout=120s

# Step 3: Execute restore
echo ""
echo "Step 3/5: Restoring data from Google Drive..."

# Determine source path
if [ -n "$RESTORE_DATE" ]; then
    DATA_SOURCE="$GDRIVE_REMOTE/.deleted/data-$RESTORE_DATE"
    MEDIA_SOURCE="$GDRIVE_REMOTE/.deleted/media-$RESTORE_DATE"
    echo "Restoring from deleted backup: $RESTORE_DATE"
else
    DATA_SOURCE="$GDRIVE_REMOTE/data"
    MEDIA_SOURCE="$GDRIVE_REMOTE/media"
    echo "Restoring from latest backup"
fi

if [ "$RESTORE_TYPE" = "partial" ]; then
    echo "Partial restore: $RESTORE_PATH"
    kubectl exec paperless-restore -n $NAMESPACE -- sh -c "
        cp /config/rclone/rclone.conf /tmp/rclone.conf
        export RCLONE_CONFIG=/tmp/rclone.conf
        rclone copy '$RESTORE_PATH' /media/ --verbose
    "
else
    echo "Full restore in progress..."

    # Restore data
    echo "Restoring data directory..."
    kubectl exec paperless-restore -n $NAMESPACE -- sh -c "
        cp /config/rclone/rclone.conf /tmp/rclone.conf
        export RCLONE_CONFIG=/tmp/rclone.conf
        rclone sync '$DATA_SOURCE' /data --verbose
    "

    # Restore media
    echo ""
    echo "Restoring media directory..."
    kubectl exec paperless-restore -n $NAMESPACE -- sh -c "
        export RCLONE_CONFIG=/tmp/rclone.conf
        rclone sync '$MEDIA_SOURCE' /media --verbose
    "
fi

# Step 4: Cleanup
echo ""
echo "Step 4/5: Cleaning up restore pod..."
kubectl delete pod paperless-restore -n $NAMESPACE

# Step 5: Scale up Paperless
echo ""
echo "Step 5/5: Scaling up Paperless deployment..."
kubectl scale deployment paperless-ngx -n $NAMESPACE --replicas=1

echo "Waiting for Paperless to be ready..."
kubectl wait --for=condition=Available deployment/paperless-ngx -n $NAMESPACE --timeout=300s

echo ""
echo -e "${GREEN}=========================================="
echo "Restore completed successfully!"
echo -e "==========================================${NC}"
echo ""
echo "Paperless is back online."
echo "Check the application at your configured URL."
echo ""
echo "If you see issues, check the logs:"
echo "  kubectl logs -f deployment/paperless-ngx -n $NAMESPACE"
