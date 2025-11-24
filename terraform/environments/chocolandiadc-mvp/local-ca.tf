# Local CA for .local domains
# Self-signed CA for services that cannot use Let's Encrypt (*.local TLD)

module "local_ca" {
  source = "../../modules/local-ca"

  namespace      = "cert-manager"
  issuer_name    = "local-ca"
  ca_common_name = "Chocolandia Homelab CA"
}

output "local_ca_issuer_name" {
  description = "ClusterIssuer name for .local domains"
  value       = module.local_ca.issuer_name
}
