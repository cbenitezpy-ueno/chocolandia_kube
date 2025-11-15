# PostgreSQL Cluster Module - Input Variables
# Feature 011: PostgreSQL Cluster Database Service
#
# Configuration variables for PostgreSQL HA deployment

# ==============================================================================
# Basic Configuration
# ==============================================================================

variable "namespace" {
  description = "Kubernetes namespace for PostgreSQL deployment"
  type        = string
  default     = "postgresql"
}

variable "release_name" {
  description = "Helm release name for PostgreSQL cluster"
  type        = string
  default     = "postgres-ha"
}

variable "postgresql_version" {
  description = "PostgreSQL major version (e.g., '16' for PostgreSQL 16.x)"
  type        = string
  default     = "16"
}

# ==============================================================================
# High Availability Configuration
# ==============================================================================

variable "replica_count" {
  description = "Total number of PostgreSQL instances (1 primary + N replicas). Must be >= 2 for HA."
  type        = number
  default     = 2

  validation {
    condition     = var.replica_count >= 2
    error_message = "Replica count must be at least 2 (1 primary + 1 replica) for high availability."
  }
}

variable "replication_mode" {
  description = "Replication mode: 'async' for asynchronous or 'sync' for synchronous"
  type        = string
  default     = "async"

  validation {
    condition     = contains(["async", "sync"], var.replication_mode)
    error_message = "Replication mode must be either 'async' or 'sync'."
  }
}

# ==============================================================================
# Storage Configuration
# ==============================================================================

variable "storage_size" {
  description = "PersistentVolume size per PostgreSQL instance (e.g., '50Gi')"
  type        = string
  default     = "50Gi"
}

variable "storage_class" {
  description = "StorageClass for PersistentVolumes (use 'local-path' for K3s local-path-provisioner)"
  type        = string
  default     = "local-path"
}

# ==============================================================================
# Resource Limits
# ==============================================================================

variable "resources_limits_cpu" {
  description = "CPU limit per PostgreSQL pod (e.g., '2' for 2 cores)"
  type        = string
  default     = "2"
}

variable "resources_limits_memory" {
  description = "Memory limit per PostgreSQL pod (e.g., '4Gi')"
  type        = string
  default     = "4Gi"
}

variable "resources_requests_cpu" {
  description = "CPU request per PostgreSQL pod"
  type        = string
  default     = "500m"
}

variable "resources_requests_memory" {
  description = "Memory request per PostgreSQL pod"
  type        = string
  default     = "1Gi"
}

# ==============================================================================
# Network Configuration
# ==============================================================================

variable "enable_external_access" {
  description = "Enable LoadBalancer service for external network access"
  type        = bool
  default     = true
}

variable "metallb_ip_pool" {
  description = "MetalLB IP address pool name for LoadBalancer service"
  type        = string
  default     = "eero-pool"
}

# ==============================================================================
# Monitoring Configuration
# ==============================================================================

variable "enable_metrics" {
  description = "Enable PostgreSQL Exporter sidecar for Prometheus metrics"
  type        = bool
  default     = true
}

variable "enable_service_monitor" {
  description = "Create ServiceMonitor resource for Prometheus Operator"
  type        = bool
  default     = true
}

# ==============================================================================
# Helm Chart Configuration
# ==============================================================================

variable "chart_version" {
  description = "Bitnami PostgreSQL Helm chart version (standard chart, not HA)"
  type        = string
  default     = "18.1.9" # Latest stable chart version with working container images
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://charts.bitnami.com/bitnami"
}

variable "helm_timeout" {
  description = "Timeout in seconds for Helm operations"
  type        = number
  default     = 600 # 10 minutes
}

# ==============================================================================
# Security Configuration
# ==============================================================================

variable "create_random_passwords" {
  description = "Generate random passwords for PostgreSQL users (recommended for production)"
  type        = bool
  default     = true
}

variable "postgres_password" {
  description = "PostgreSQL superuser password (only used if create_random_passwords = false)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "replication_password" {
  description = "PostgreSQL replication user password (only used if create_random_passwords = false)"
  type        = string
  default     = ""
  sensitive   = true
}
