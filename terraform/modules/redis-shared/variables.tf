# Redis Shared - Input Variables

# ==============================================================================
# Basic Configuration
# ==============================================================================

variable "release_name" {
  description = "Helm release name for Redis deployment"
  type        = string
  default     = "redis-shared"
}

variable "namespace" {
  description = "Kubernetes namespace for Redis deployment"
  type        = string
  default     = "redis"
}

variable "replica_namespaces" {
  description = "List of additional namespaces where Redis credentials Secret should be replicated"
  type        = list(string)
  default     = ["beersystem"]
}

# ==============================================================================
# Helm Chart Configuration
# ==============================================================================

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://charts.bitnami.com/bitnami"
}

variable "chart_version" {
  description = "Redis Helm chart version"
  type        = string
  default     = "23.2.12"
}

variable "helm_timeout" {
  description = "Helm release timeout in seconds"
  type        = number
  default     = 600
}

# ==============================================================================
# Storage Configuration
# ==============================================================================

variable "storage_class" {
  description = "Storage class for PersistentVolumes"
  type        = string
  default     = "local-path"
}

variable "storage_size" {
  description = "Storage size per Redis instance"
  type        = string
  default     = "10Gi"
}

# ==============================================================================
# Redis Architecture
# ==============================================================================

variable "replica_count" {
  description = "Number of Redis replicas (not including primary)"
  type        = number
  default     = 1

  validation {
    condition     = var.replica_count >= 1
    error_message = "Replica count must be at least 1 for high availability."
  }
}

# ==============================================================================
# Master Resources
# ==============================================================================

variable "master_cpu_request" {
  description = "Master instance CPU request"
  type        = string
  default     = "500m"
}

variable "master_cpu_limit" {
  description = "Master instance CPU limit"
  type        = string
  default     = "1000m"
}

variable "master_memory_request" {
  description = "Master instance memory request"
  type        = string
  default     = "1Gi"
}

variable "master_memory_limit" {
  description = "Master instance memory limit"
  type        = string
  default     = "2Gi"
}

# ==============================================================================
# Replica Resources
# ==============================================================================

variable "replica_cpu_request" {
  description = "Replica instance CPU request"
  type        = string
  default     = "250m"
}

variable "replica_cpu_limit" {
  description = "Replica instance CPU limit"
  type        = string
  default     = "1000m"
}

variable "replica_memory_request" {
  description = "Replica instance memory request"
  type        = string
  default     = "1Gi"
}

variable "replica_memory_limit" {
  description = "Replica instance memory limit"
  type        = string
  default     = "2Gi"
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
  description = "Namespace where Prometheus Operator is deployed"
  type        = string
  default     = "monitoring"
}

# ==============================================================================
# LoadBalancer Configuration
# ==============================================================================

variable "loadbalancer_ip" {
  description = "MetalLB LoadBalancer IP for private network access"
  type        = string
  default     = "192.168.4.203"

  validation {
    condition     = can(regex("^192\\.168\\.4\\.(20[0-9]|210)$", var.loadbalancer_ip))
    error_message = "LoadBalancer IP must be within MetalLB pool range (192.168.4.200-210)."
  }
}

variable "metallb_ip_pool" {
  description = "MetalLB IP pool annotation value"
  type        = string
  default     = "eero-pool"
}

# ==============================================================================
# Redis Configuration
# ==============================================================================

variable "redis_config" {
  description = "Redis configuration overrides (redis.conf format)"
  type        = string
  default     = <<-EOT
    maxmemory 1536mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly no
    loglevel notice
    slowlog-log-slower-than 10000
    slowlog-max-len 128
  EOT
}

variable "disable_commands" {
  description = "List of dangerous Redis commands to disable"
  type        = list(string)
  default     = ["FLUSHDB", "FLUSHALL", "CONFIG", "SHUTDOWN"]
}
