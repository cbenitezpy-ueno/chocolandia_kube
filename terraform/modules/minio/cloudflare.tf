# ============================================================================
# Cloudflare Configuration for MinIO S3 API and Console
# ============================================================================
# DNS records and Cloudflare Access are now managed by the cloudflare-tunnel module
# The tunnel module creates CNAME records and Access applications for all services
# ============================================================================

# DNS and Access resources removed - managed by cloudflare-tunnel module
# MinIO Console (minio.chocolandiadc.com) and S3 API (s3.chocolandiadc.com)
# are exposed via Cloudflare Tunnel ingress rules in terraform.tfvars
#
# Note: The tunnel module creates Access for both console and S3 API.
# For programmatic S3 access without browser authentication, use:
# - Direct access via private network (192.168.4.x)
# - Or configure S3 client to handle Cloudflare Access authentication
