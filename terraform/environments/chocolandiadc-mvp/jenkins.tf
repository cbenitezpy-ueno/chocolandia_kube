# Jenkins CI Server
# Feature 029: Jenkins CI Deployment
# Replaces GitHub Actions with self-hosted CI/CD

module "jenkins" {
  source = "../../modules/jenkins"

  namespace = "jenkins"
  hostname  = "jenkins.chocolandiadc.local"

  # Jenkins version
  jenkins_image = "jenkins/jenkins"
  jenkins_tag   = "lts-jdk17"

  # Admin credentials
  admin_user     = "admin"
  admin_password = var.jenkins_admin_password

  # Storage
  storage_class = "local-path"
  storage_size  = "20Gi"

  # Controller resources
  controller_cpu_request    = "500m"
  controller_cpu_limit      = "2000m"
  controller_memory_request = "1Gi"
  controller_memory_limit   = "2Gi"

  # DinD sidecar resources
  dind_cpu_request    = "200m"
  dind_cpu_limit      = "1000m"
  dind_memory_request = "512Mi"
  dind_memory_limit   = "1Gi"

  # TLS and ingress
  cluster_issuer     = "local-ca" # Using self-signed CA for .local domains
  traefik_entrypoint = "websecure"

  # Nexus Docker registry integration
  nexus_docker_registry = "docker.nexus.chocolandiadc.local"
  nexus_username        = "admin"
  nexus_password        = var.nexus_admin_password

  # Monitoring
  enable_metrics = true

  # Notifications
  ntfy_server = "http://ntfy.ntfy.svc.cluster.local"
  ntfy_topic  = "homelab-alerts"
}

# ==============================================================================
# Outputs
# ==============================================================================

output "jenkins_url" {
  description = "Jenkins Web UI URL (LAN)"
  value       = module.jenkins.jenkins_url
}

output "jenkins_admin_user" {
  description = "Jenkins admin username"
  value       = module.jenkins.admin_user
}

output "jenkins_admin_password" {
  description = "Jenkins admin password"
  value       = module.jenkins.admin_password
  sensitive   = true
}
