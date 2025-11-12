# ==============================================================================
# Kubernetes Outputs - Phase 3 (US1)
# ==============================================================================

output "namespace" {
  description = "Kubernetes namespace where Headlamp is deployed"
  value       = kubernetes_namespace.headlamp.metadata[0].name
}

output "service_name" {
  description = "Headlamp Kubernetes service name"
  value       = helm_release.headlamp.name
}

# ==============================================================================
# Configuration Outputs - Phase 3 (US1)
# ==============================================================================

output "replicas" {
  description = "Number of Headlamp pod replicas deployed"
  value       = var.replicas
}

output "chart_version" {
  description = "Headlamp Helm chart version deployed"
  value       = helm_release.headlamp.version
}

# ==============================================================================
# Ingress & Certificate Outputs - Phase 5 (US3)
# ==============================================================================

output "ingress_hostname" {
  description = "Headlamp ingress hostname (HTTPS URL)"
  value       = "https://${var.domain}"
}

output "certificate_secret" {
  description = "TLS certificate secret name"
  value       = kubernetes_manifest.certificate.manifest.spec.secretName
}

# ==============================================================================
# RBAC Outputs - Phase 4 (US2)
# ==============================================================================

output "serviceaccount_name" {
  description = "ServiceAccount name for Headlamp admin access"
  value       = kubernetes_service_account.headlamp_admin.metadata[0].name
}

output "serviceaccount_token_secret" {
  description = "ServiceAccount token secret name (for UI authentication)"
  value       = kubernetes_secret.headlamp_admin_token.metadata[0].name
}

output "clusterrolebinding_name" {
  description = "ClusterRoleBinding name for read-only access"
  value       = kubernetes_cluster_role_binding.headlamp_view.metadata[0].name
}

# ==============================================================================
# Cloudflare Access Outputs - Phase 6 (US4) - UNCOMMENT AFTER IMPLEMENTATION
# ==============================================================================

# output "cloudflare_access_application_id" {
#   description = "Cloudflare Zero Trust Access application ID"
#   value       = cloudflare_zero_trust_access_application.headlamp.id
# }

# output "cloudflare_access_policy_id" {
#   description = "Cloudflare Zero Trust Access policy ID"
#   value       = cloudflare_zero_trust_access_policy.headlamp_allow.id
# }
