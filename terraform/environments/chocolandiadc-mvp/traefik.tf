# Traefik Ingress Controller
# Feature 005: Traefik Ingress Controller
# Deploys Traefik v3.x with HA configuration

module "traefik" {
  source = "../../modules/traefik"

  release_name    = "traefik"
  chart_version   = "30.0.2" # Traefik v3.2.0
  namespace       = "traefik"
  replicas        = 2
  loadbalancer_ip = "192.168.4.201"

  resources_requests_cpu    = "100m"
  resources_requests_memory = "128Mi"
  resources_limits_cpu      = "500m"
  resources_limits_memory   = "256Mi"
}

# Outputs
output "traefik_loadbalancer_ip" {
  description = "Traefik LoadBalancer IP address"
  value       = module.traefik.loadbalancer_ip
}

output "traefik_status" {
  description = "Traefik Helm release status"
  value       = module.traefik.status
}

output "traefik_namespace" {
  description = "Traefik namespace"
  value       = module.traefik.namespace
}
