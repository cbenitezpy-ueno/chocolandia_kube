# ============================================================================
# Longhorn Module Variables
# ============================================================================

variable "replica_count" {
  description = "Number of replicas for Longhorn volumes (balance capacity vs HA)"
  type        = number
  default     = 2

  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 3
    error_message = "replica_count must be between 1 and 3 for 4-node cluster"
  }
}

variable "usb_disk_path" {
  description = "Path to USB disk mount point on master1 for Longhorn storage"
  type        = string
  default     = "/media/usb/longhorn-storage"
}

variable "storage_class_name" {
  description = "Name of the Longhorn StorageClass"
  type        = string
  default     = "longhorn"
}

variable "storage_reserved_percentage" {
  description = "Percentage of disk to reserve for system (10% recommended)"
  type        = number
  default     = 10

  validation {
    condition     = var.storage_reserved_percentage >= 0 && var.storage_reserved_percentage <= 50
    error_message = "storage_reserved_percentage must be between 0 and 50"
  }
}

variable "enable_metrics" {
  description = "Enable Prometheus metrics for Longhorn components"
  type        = bool
  default     = true
}
