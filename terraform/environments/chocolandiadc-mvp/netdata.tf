# ============================================================================
# Netdata Hardware Monitoring Deployment
# Real-time performance and hardware monitoring dashboard
# ============================================================================

module "netdata" {
  source = "../../modules/netdata"

  # Namespace
  namespace = "netdata"

  # Helm chart version
  chart_version = "3.7.151"

  # Parent node (central UI + aggregation)
  parent_cpu_request    = "200m"
  parent_memory_request = "256Mi"
  parent_cpu_limit      = "1000m"
  parent_memory_limit   = "1Gi"

  # Child nodes (DaemonSet - one per node for hardware monitoring)
  child_cpu_request    = "100m"
  child_memory_request = "128Mi"
  child_cpu_limit      = "500m"
  child_memory_limit   = "512Mi"

  # Storage (Longhorn for historical metrics)
  storage_class_name = "longhorn"
  storage_size       = var.netdata_storage_size

  # Ingress
  domain         = var.netdata_domain
  cluster_issuer = var.cluster_issuer

  # Cloudflare
  cloudflare_zone_id      = var.cloudflare_zone_id
  cloudflare_account_id   = var.cloudflare_account_id
  traefik_loadbalancer_ip = module.traefik.loadbalancer_ip
  authorized_emails       = var.authorized_emails
  google_oauth_idp_id     = var.google_oauth_idp_id

  depends_on = [
    module.longhorn,    # Storage backend required
    module.traefik,     # Ingress controller required
    module.cert_manager # TLS certificates required
  ]
}

# ============================================================================
# Outputs
# ============================================================================

output "netdata_url" {
  description = "Netdata hardware monitoring dashboard URL"
  value       = module.netdata.web_ui_url
}

output "netdata_namespace" {
  description = "Netdata deployment namespace"
  value       = module.netdata.namespace
}
