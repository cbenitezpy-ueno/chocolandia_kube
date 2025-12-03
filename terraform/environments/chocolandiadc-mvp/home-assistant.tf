# Home Assistant Deployment
# Feature: 018-home-assistant
# Scope: Phase 1 - Base Installation + Prometheus Integration

module "home_assistant" {
  source = "../../modules/home-assistant"

  # Use defaults from module for Phase 1
  # All values can be overridden if needed:
  # namespace               = "home-assistant"
  # app_name                = "home-assistant"
  # image                   = "ghcr.io/home-assistant/home-assistant:stable"
  # timezone                = "America/Chicago"
  # storage_size            = "10Gi"
  # storage_class           = "local-path"
  # local_domain            = "homeassistant.chocolandiadc.local"
  # external_domain         = "homeassistant.chocolandiadc.com"
  # local_cluster_issuer    = "local-ca"
  # external_cluster_issuer = "letsencrypt-production"
  # ingress_class           = "traefik"
  # service_port            = 8123
}
