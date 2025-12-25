# ============================================================================
# Longhorn Distributed Block Storage Instance
# ============================================================================
# Deploys Longhorn v1.5.x for distributed block storage with 2-replica volumes
# using USB disk on master1 for additional capacity
# ============================================================================

module "longhorn" {
  source = "../../modules/longhorn"

  # Longhorn chart version - upgrade path: 1.5.5 → 1.6.3 → 1.7.3 → 1.8.2 → 1.9.2 → 1.10.1
  chart_version = "1.10.1"

  # Replica configuration (2 replicas for balance between capacity and HA)
  replica_count = var.longhorn_replica_count

  # USB disk path on master1 for Longhorn storage
  # Note: Longhorn will auto-discover this path on nodes
  usb_disk_path = "/media/usb/longhorn-storage"

  # StorageClass name (will be set as default)
  storage_class_name = "longhorn"

  # Storage reservation (10% reserved for system)
  storage_reserved_percentage = 10

  # Enable Prometheus metrics for monitoring
  enable_metrics = true

  # Cloudflare and Ingress configuration (User Story 2)
  longhorn_domain          = var.longhorn_domain
  cloudflare_zone_id       = var.cloudflare_zone_id
  cloudflare_account_id    = var.cloudflare_account_id
  traefik_loadbalancer_ip  = "192.168.4.201" # MetalLB assigned IP
  authorized_emails        = var.authorized_emails
  cluster_issuer           = var.cluster_issuer
  certificate_duration     = var.certificate_duration
  certificate_renew_before = var.certificate_renew_before

  # Cloudflare Access Authentication
  google_oauth_idp_id  = module.cloudflare_tunnel.access_identity_provider_id
  access_auto_redirect = true
}

# ============================================================================
# Outputs
# ============================================================================

output "longhorn_storageclass_name" {
  description = "Name of the Longhorn StorageClass for PVC provisioning"
  value       = module.longhorn.storageclass_name
}

output "longhorn_namespace" {
  description = "Kubernetes namespace where Longhorn is deployed"
  value       = module.longhorn.namespace
}

output "longhorn_ui_service" {
  description = "Longhorn UI service details for IngressRoute configuration"
  value = {
    name = module.longhorn.ui_service_name
    port = module.longhorn.ui_service_port
  }
}

output "longhorn_replica_count" {
  description = "Configured replica count for Longhorn volumes"
  value       = module.longhorn.replica_count
}
