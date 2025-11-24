# Local CA Module - Outputs

output "issuer_name" {
  description = "Name of the CA ClusterIssuer for .local domains"
  value       = var.issuer_name
}

output "ca_secret_name" {
  description = "Name of the secret containing the CA certificate"
  value       = "local-ca-secret"
}

output "ca_secret_namespace" {
  description = "Namespace where the CA secret is stored"
  value       = var.namespace
}
