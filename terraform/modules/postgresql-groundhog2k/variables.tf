# PostgreSQL Groundhog2k - Variables
# Configuration variables for PostgreSQL deployment using official images

# ==============================================================================
# Core Configuration
# ==============================================================================

variable "release_name" {
  description = "Helm release name for PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "namespace" {
  description = "Kubernetes namespace for PostgreSQL"
  type        = string
  default     = "postgresql"
}

# ==============================================================================
# Helm Chart Configuration
# ==============================================================================

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://groundhog2k.github.io/helm-charts/"
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "1.6.1"
}

variable "helm_timeout" {
  description = "Helm install/upgrade timeout in seconds"
  type        = number
  default     = 600
}

# ==============================================================================
# PostgreSQL Image Configuration
# ==============================================================================

variable "postgres_image_tag" {
  description = "PostgreSQL Docker image tag (official postgres image)"
  type        = string
  default     = "17-alpine"
}

# ==============================================================================
# Database Configuration
# ==============================================================================

variable "postgres_database" {
  description = "Default database to create"
  type        = string
  default     = "app_db"
}

variable "postgres_user" {
  description = "Default application user"
  type        = string
  default     = "app_user"
}

variable "additional_databases" {
  description = "Additional databases to create (via init script)"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Resource Configuration
# ==============================================================================

variable "cpu_request" {
  description = "CPU request for PostgreSQL pod"
  type        = string
  default     = "500m"
}

variable "cpu_limit" {
  description = "CPU limit for PostgreSQL pod"
  type        = string
  default     = "2"
}

variable "memory_request" {
  description = "Memory request for PostgreSQL pod"
  type        = string
  default     = "1Gi"
}

variable "memory_limit" {
  description = "Memory limit for PostgreSQL pod"
  type        = string
  default     = "4Gi"
}

# ==============================================================================
# Storage Configuration
# ==============================================================================

variable "storage_class" {
  description = "Kubernetes storage class for PostgreSQL persistence"
  type        = string
  default     = "local-path"
}

variable "storage_size" {
  description = "Storage size for PostgreSQL persistence"
  type        = string
  default     = "50Gi"
}

# ==============================================================================
# Network Configuration
# ==============================================================================

variable "loadbalancer_ip" {
  description = "LoadBalancer IP for external access (MetalLB)"
  type        = string
  default     = ""
}

variable "metallb_ip_pool" {
  description = "MetalLB IP pool name"
  type        = string
  default     = "eero-pool"
}

# ==============================================================================
# Monitoring Configuration
# ==============================================================================

variable "enable_metrics" {
  description = "Enable Prometheus metrics exporter"
  type        = bool
  default     = true
}

variable "enable_service_monitor" {
  description = "Enable ServiceMonitor for Prometheus Operator"
  type        = bool
  default     = true
}

variable "monitoring_namespace" {
  description = "Namespace where Prometheus is deployed"
  type        = string
  default     = "monitoring"
}

# ==============================================================================
# PostgreSQL Configuration
# ==============================================================================

variable "postgres_config" {
  description = "Additional PostgreSQL configuration parameters"
  type        = map(string)
  default = {
    max_connections        = "200"
    shared_buffers         = "256MB"
    effective_cache_size   = "1GB"
    maintenance_work_mem   = "128MB"
    checkpoint_completion_target = "0.9"
    wal_buffers            = "16MB"
    default_statistics_target = "100"
    random_page_cost       = "1.1"
    effective_io_concurrency = "200"
    work_mem               = "16MB"
    min_wal_size           = "1GB"
    max_wal_size           = "4GB"
    max_worker_processes   = "4"
    max_parallel_workers_per_gather = "2"
    max_parallel_workers   = "4"
    max_parallel_maintenance_workers = "2"
  }
}
