# cert-manager Module Configuration
# Feature 006: SSL/TLS Certificate Management with Let's Encrypt
# Manages automated certificate issuance and renewal via ACME protocol

module "cert_manager" {
  source = "../../modules/cert-manager"

  # Namespace configuration
  namespace = "cert-manager"

  # Helm chart version
  chart_version = "v1.13.3"

  # ACME account configuration
  acme_email = var.cert_manager_acme_email

  # ClusterIssuer configuration
  enable_staging    = var.cert_manager_enable_staging
  enable_production = var.cert_manager_enable_production

  # Monitoring configuration
  enable_metrics        = var.cert_manager_enable_metrics
  enable_servicemonitor = var.cert_manager_enable_servicemonitor

  # High availability configuration (homelab: single replica)
  controller_replicas = 1
  webhook_replicas    = 1
  cainjector_replicas = 1
}

# Outputs for use by other modules
output "cert_manager_namespace" {
  description = "cert-manager namespace"
  value       = module.cert_manager.namespace
}

output "cert_manager_staging_issuer" {
  description = "Staging ClusterIssuer name for testing"
  value       = module.cert_manager.staging_issuer_name
}

output "cert_manager_production_issuer" {
  description = "Production ClusterIssuer name for trusted certificates"
  value       = module.cert_manager.production_issuer_name
}

output "cert_manager_metrics_port" {
  description = "Prometheus metrics port"
  value       = module.cert_manager.metrics_port
}
