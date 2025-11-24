# Nexus Repository Manager
# Multi-format artifact repository (Docker, Helm, NPM, Maven, APT)

module "nexus" {
  source = "../../modules/nexus"

  namespace       = "nexus"
  hostname        = "nexus.chocolandiadc.local"
  docker_hostname = "docker.nexus.chocolandiadc.local"

  storage_size  = "50Gi"
  storage_class = "local-path"

  # Resource allocation for Nexus (Java application)
  resource_requests_memory = "1536Mi"
  resource_requests_cpu    = "500m"
  resource_limits_memory   = "2Gi"
  resource_limits_cpu      = "1000m"
  jvm_heap_size            = "1200m"

  # TLS and ingress
  cluster_issuer     = "local-ca"  # Using self-signed CA for .local domains
  traefik_entrypoint = "websecure"

  # Enable Prometheus metrics
  enable_metrics = true
}

output "nexus_web_url" {
  description = "Nexus Web UI URL"
  value       = module.nexus.web_url
}

output "nexus_docker_url" {
  description = "Nexus Docker Registry URL"
  value       = module.nexus.docker_url
}
