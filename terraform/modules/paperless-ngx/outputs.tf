# Paperless-ngx Module Outputs
# Feature: 027-paperless-ngx

output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.paperless.metadata[0].name
}

output "service_name" {
  description = "Kubernetes service name"
  value       = kubernetes_service.paperless.metadata[0].name
}

output "service_port" {
  description = "Service port"
  value       = var.service_port
}

output "internal_url" {
  description = "Internal cluster URL"
  value       = "http://${kubernetes_service.paperless.metadata[0].name}.${kubernetes_namespace.paperless.metadata[0].name}.svc.cluster.local:${var.service_port}"
}

output "public_url" {
  description = "Public URL (Cloudflare)"
  value       = "https://${var.public_host}"
}

output "local_url" {
  description = "Local LAN URL"
  value       = var.enable_local_ingress ? "https://${var.local_host}" : null
}

output "samba_service_name" {
  description = "Samba LoadBalancer service name"
  value       = kubernetes_service.samba.metadata[0].name
}

output "consume_pvc_name" {
  description = "Consume folder PVC name"
  value       = kubernetes_persistent_volume_claim.consume.metadata[0].name
}

output "samba_endpoint" {
  description = "Samba SMB endpoint for scanner configuration (smb://IP/consume)"
  value       = "smb://${kubernetes_service.samba.status[0].load_balancer[0].ingress[0].ip}/${var.samba_share_name}"
}
