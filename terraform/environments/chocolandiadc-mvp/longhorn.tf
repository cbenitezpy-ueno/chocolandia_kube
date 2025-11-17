# ============================================================================
# Longhorn Distributed Block Storage Instance
# ============================================================================
# Deploys Longhorn v1.5.x for distributed block storage with 2-replica volumes
# using USB disk on master1 for additional capacity
# ============================================================================

module "longhorn" {
  source = "../../modules/longhorn"

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
