# LocalStack Module Instantiation
# Deploys LocalStack for AWS service emulation

module "localstack" {
  source = "../../modules/localstack"

  namespace     = "localstack"
  storage_size  = "20Gi"
  hostname      = "localstack.homelab.local"
  services_list = "s3,sqs,sns,dynamodb,lambda"

  # Enable persistence for data across restarts
  enable_persistence = true

  # Use Docker executor for Lambda functions
  lambda_executor = "docker"

  # Use existing cert-manager cluster issuer
  cluster_issuer = "letsencrypt-prod"

  # Resource configuration for homelab (Lambda needs more resources)
  resource_limits_memory   = "2Gi"
  resource_limits_cpu      = "1000m"
  resource_requests_memory = "512Mi"
  resource_requests_cpu    = "200m"
}

# Outputs for LocalStack
output "localstack_endpoint_url" {
  description = "LocalStack endpoint URL for AWS CLI/SDK"
  value       = module.localstack.endpoint_url
}

output "localstack_services_enabled" {
  description = "List of enabled AWS services"
  value       = module.localstack.services_enabled
}

output "localstack_health_endpoint" {
  description = "LocalStack health check URL"
  value       = module.localstack.health_endpoint
}
