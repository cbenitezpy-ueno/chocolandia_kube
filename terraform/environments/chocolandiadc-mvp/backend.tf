# ============================================================================
# OpenTofu Remote Backend Configuration
# ============================================================================
# Uses MinIO as S3-compatible storage for the terraform state
#
# Required environment variables:
#   AWS_ACCESS_KEY_ID     - MinIO root user
#   AWS_SECRET_ACCESS_KEY - MinIO root password
#   AWS_ENDPOINT_URL_S3   - MinIO API endpoint (http://192.168.4.101:30090)
#
# To initialize:
#   export AWS_ACCESS_KEY_ID="$(tofu output -raw minio_root_user)"
#   export AWS_SECRET_ACCESS_KEY="$(tofu output -raw minio_root_password)"
#   export AWS_ENDPOINT_URL_S3="http://192.168.4.101:30090"
#   tofu init -migrate-state
# ============================================================================

terraform {
  backend "s3" {
    bucket = "opentofu-state"
    key    = "chocolandiadc-mvp/terraform.tfstate"
    region = "us-east-1"

    # MinIO-specific settings
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true

    # Enable state locking (MinIO supports S3 object locking)
    # Note: If locking causes issues, can disable with: skip_s3_checksum = true
  }
}
