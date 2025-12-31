#!/bin/bash
# ============================================================================
# Migrate OpenTofu State to MinIO Remote Backend
# ============================================================================
# This script migrates the local terraform state to MinIO S3-compatible storage
#
# Prerequisites:
# - MinIO must be running and accessible
# - The opentofu-state bucket must exist
# - Current tofu state must have minio outputs available
# ============================================================================

set -e

cd "$(dirname "$0")"

echo "=== OpenTofu State Migration to MinIO ==="
echo ""

# Get MinIO credentials from current state
echo "1. Getting MinIO credentials from current state..."
export AWS_ACCESS_KEY_ID=$(TF_VAR_github_token=dummy TF_VAR_github_app_id=dummy TF_VAR_github_app_installation_id=dummy TF_VAR_github_app_private_key=dummy TF_VAR_govee_api_key=dummy tofu output -raw minio_root_user)
export AWS_SECRET_ACCESS_KEY=$(TF_VAR_github_token=dummy TF_VAR_github_app_id=dummy TF_VAR_github_app_installation_id=dummy TF_VAR_github_app_private_key=dummy TF_VAR_govee_api_key=dummy tofu output -raw minio_root_password)
export AWS_ENDPOINT_URL_S3="http://192.168.4.101:30090"

echo "   AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:5}..."
echo "   AWS_ENDPOINT_URL_S3: $AWS_ENDPOINT_URL_S3"
echo ""

# Verify MinIO is accessible
echo "2. Verifying MinIO connectivity..."
if curl -s --connect-timeout 5 "$AWS_ENDPOINT_URL_S3/minio/health/live" > /dev/null 2>&1; then
    echo "   MinIO is accessible"
else
    echo "   WARNING: MinIO health check failed, but continuing..."
fi
echo ""

# Backup current state
echo "3. Creating backup of local state..."
BACKUP_FILE="$HOME/terraform-state-backup-$(date +%Y%m%d-%H%M%S).tfstate"
cp terraform.tfstate "$BACKUP_FILE"
echo "   Backup saved to: $BACKUP_FILE"
echo ""

# Migrate state
echo "4. Migrating state to MinIO..."
echo "   This will prompt for confirmation."
echo ""

TF_VAR_github_token=dummy \
TF_VAR_github_app_id=dummy \
TF_VAR_github_app_installation_id=dummy \
TF_VAR_github_app_private_key=dummy \
TF_VAR_govee_api_key=dummy \
tofu init -migrate-state

echo ""
echo "=== Migration Complete ==="
echo ""
echo "The state is now stored in MinIO at:"
echo "  Bucket: opentofu-state"
echo "  Key: chocolandiadc-mvp/terraform.tfstate"
echo ""
echo "To use OpenTofu with the remote backend, always set these env vars:"
echo "  export AWS_ACCESS_KEY_ID=\"\$(tofu output -raw minio_root_user)\""
echo "  export AWS_SECRET_ACCESS_KEY=\"\$(tofu output -raw minio_root_password)\""
echo "  export AWS_ENDPOINT_URL_S3=\"http://192.168.4.101:30090\""
echo ""
echo "Or source the generated env file:"
echo "  source ./backend-env.sh"
