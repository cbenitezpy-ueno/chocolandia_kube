# Pi-hole DNS Ad Blocker Deployment
# Deploys Pi-hole on K3s cluster for network-wide ad blocking

module "pihole" {
  source = "../../modules/pihole"

  # Admin Configuration
  admin_password = var.pihole_admin_password

  # DNS Configuration
  timezone     = "America/New_York" # Adjust to your timezone
  upstream_dns = "1.1.1.1;8.8.8.8"  # Cloudflare + Google DNS

  # Custom DNS hosts for local services (Pi-hole v6 format: "IP HOSTNAME")
  # All services point to Traefik LoadBalancer IP: 192.168.4.202
  custom_dns_hosts = [
    # Production Services (.chocolandiadc.com)
    "192.168.4.202 s3.chocolandiadc.com",

    # Local Network Services (.chocolandiadc.local) - Core Infrastructure
    "192.168.4.202 argocd.chocolandiadc.local",
    "192.168.4.202 grafana.chocolandiadc.local",
    "192.168.4.202 headlamp.chocolandiadc.local",
    "192.168.4.202 homepage.chocolandiadc.local",
    "192.168.4.202 longhorn.chocolandiadc.local",
    "192.168.4.202 pihole.chocolandiadc.local",
    "192.168.4.202 ntfy.chocolandiadc.local",

    # Storage Services
    "192.168.4.202 minio.chocolandiadc.local",

    # Applications
    "192.168.4.202 beer.chocolandiadc.local",

    # Dev Tools - Container Registry
    "192.168.4.202 registry.chocolandiadc.local",
    "192.168.4.202 registry-ui.chocolandiadc.local",

    # Dev Tools - LocalStack (AWS emulation)
    "192.168.4.202 localstack.chocolandiadc.local",

    # Dev Tools - Nexus Repository Manager
    "192.168.4.202 nexus.chocolandiadc.local",
    "192.168.4.202 docker.nexus.chocolandiadc.local",

    # Home Automation
    "192.168.4.202 homeassistant.chocolandiadc.local",

    # Document Management
    "192.168.4.202 paperless.chocolandiadc.local",
  ]

  # Kubernetes Configuration
  namespace = "default"
  image     = "pihole/pihole:latest"
  replicas  = 1 # MVP: Single pod

  # Storage Configuration
  storage_size  = "2Gi"
  storage_class = "local-path" # K3s default

  # Resource Limits
  cpu_request    = "100m"
  cpu_limit      = "500m"
  memory_request = "256Mi"
  memory_limit   = "512Mi"

  # Service Configuration
  web_nodeport = 30001
  node_ips     = ["192.168.4.101", "192.168.4.102"] # master1, nodo1
}

# ============================================================================
# Variable Declaration
# ============================================================================

variable "pihole_admin_password" {
  description = "Pi-hole web admin password"
  type        = string
  sensitive   = true
}

# ============================================================================
# Outputs
# ============================================================================

output "pihole_web_admin_url" {
  description = "URL(s) to access Pi-hole web admin interface"
  value       = module.pihole.web_admin_url
}

output "pihole_admin_password_retrieval" {
  description = "Command to retrieve Pi-hole admin password"
  value       = module.pihole.admin_password_retrieval_command
}

output "pihole_pod_status_command" {
  description = "Command to check Pi-hole pod status"
  value       = module.pihole.check_pod_status_command
}

output "pihole_dns_service" {
  description = "Pi-hole DNS service name"
  value       = module.pihole.dns_service_name
}
