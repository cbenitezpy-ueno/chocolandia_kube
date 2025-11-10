# Traefik Module Outputs
# Feature 005: Traefik Ingress Controller

output "release_name" {
  description = "Helm release name"
  value       = helm_release.traefik.name
}

output "namespace" {
  description = "Kubernetes namespace where Traefik is deployed"
  value       = helm_release.traefik.namespace
}

output "chart_version" {
  description = "Traefik Helm chart version deployed"
  value       = helm_release.traefik.version
}

output "status" {
  description = "Helm release status"
  value       = helm_release.traefik.status
}

output "loadbalancer_ip" {
  description = "LoadBalancer IP assigned by MetalLB"
  value       = var.loadbalancer_ip
}

output "replicas" {
  description = "Number of Traefik replicas configured"
  value       = var.replicas
}
