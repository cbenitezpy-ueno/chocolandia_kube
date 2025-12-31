#!/bin/bash
# ============================================================================
# OpenTofu Backend Environment Variables
# ============================================================================
# Source this file before running tofu commands to configure the S3 backend:
#   source ./backend-env.sh
# ============================================================================

cd "$(dirname "${BASH_SOURCE[0]}")"

# Set dummy vars for tofu commands (required for validation)
export TF_VAR_github_token="dummy"
export TF_VAR_github_app_id="123456"
export TF_VAR_github_app_installation_id="789012"
export TF_VAR_github_app_private_key="-----BEGIN RSA PRIVATE KEY-----
MIIBOgIBAAJBALRZxGAuXV
-----END RSA PRIVATE KEY-----"
export TF_VAR_govee_api_key="dummy"

# MinIO S3 backend configuration
export AWS_ENDPOINT_URL_S3="http://192.168.4.101:30090"

# Try to get credentials from state
AWS_KEY=$(tofu output -raw minio_root_user 2>/dev/null || echo "")
AWS_SECRET=$(tofu output -raw minio_root_password 2>/dev/null || echo "")

if [ -n "$AWS_KEY" ]; then
    export AWS_ACCESS_KEY_ID="$AWS_KEY"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET"
    echo "MinIO backend environment configured"
    echo "  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:5}..."
    echo "  AWS_ENDPOINT_URL_S3: $AWS_ENDPOINT_URL_S3"
else
    echo "WARNING: Could not get MinIO credentials from state"
    echo "Make sure tofu state is accessible or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY manually"
fi
