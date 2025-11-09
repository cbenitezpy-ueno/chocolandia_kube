# Pi-hole Module - Outputs
# Provides information about deployed Pi-hole resources

# ============================================================================
# Service Access Information
# ============================================================================

output "web_admin_url" {
  description = "URL(s) to access Pi-hole web admin interface"
  value       = [for ip in var.node_ips : "http://${ip}:${var.web_nodeport}/admin"]
}

output "web_nodeport" {
  description = "NodePort number for web admin interface"
  value       = var.web_nodeport
}

output "dns_service_name" {
  description = "Kubernetes Service name for Pi-hole DNS"
  value       = "pihole-dns"
}

output "dns_service_type" {
  description = "Kubernetes Service type for DNS service"
  value       = "NodePort"
}

# ============================================================================
# Admin Credentials
# ============================================================================

output "admin_password_secret" {
  description = "Kubernetes Secret name containing admin password"
  value       = "pihole-admin-password"
}

output "admin_password_retrieval_command" {
  description = "Command to retrieve admin password from Kubernetes Secret"
  value       = "kubectl get secret pihole-admin-password -n ${var.namespace} -o jsonpath='{.data.password}' | base64 -d"
}

# ============================================================================
# Pod Information
# ============================================================================

output "deployment_name" {
  description = "Kubernetes Deployment name for Pi-hole"
  value       = "pihole"
}

output "namespace" {
  description = "Kubernetes namespace where Pi-hole is deployed"
  value       = var.namespace
}

output "pod_selector" {
  description = "Label selector for Pi-hole pods"
  value       = "app=pihole"
}

# ============================================================================
# Storage Information
# ============================================================================

output "pvc_name" {
  description = "PersistentVolumeClaim name for Pi-hole configuration"
  value       = "pihole-config"
}

output "storage_size" {
  description = "PersistentVolumeClaim storage size"
  value       = var.storage_size
}

output "storage_class" {
  description = "Storage class used for PersistentVolumeClaim"
  value       = var.storage_class
}

# ============================================================================
# Deployment Status Commands
# ============================================================================

output "check_pod_status_command" {
  description = "Command to check Pi-hole pod status"
  value       = "kubectl get pods -n ${var.namespace} -l app=pihole"
}

output "view_logs_command" {
  description = "Command to view Pi-hole logs"
  value       = "kubectl logs -n ${var.namespace} -l app=pihole --tail=50"
}

output "check_services_command" {
  description = "Command to check Pi-hole services"
  value       = "kubectl get svc -n ${var.namespace} | grep pihole"
}
