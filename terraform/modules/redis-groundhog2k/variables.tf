# Redis Groundhog2k - Variables
# Configuration variables for Redis deployment using official images

# ==============================================================================
# Core Configuration
# ==============================================================================

variable "release_name" {
  description = "Helm release name for Redis"
  type        = string
  default     = "redis"
}

variable "namespace" {
  description = "Kubernetes namespace for Redis"
  type        = string
  default     = "redis"
}

variable "replica_namespaces" {
  description = "List of namespaces to replicate Redis credentials to"
  type        = list(string)
  default     = []
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
  default     = "2.2.1"
}

variable "helm_timeout" {
  description = "Helm install/upgrade timeout in seconds"
  type        = number
  default     = 600
}

# ==============================================================================
# Redis Image Configuration
# ==============================================================================

variable "redis_image_tag" {
  description = "Redis Docker image tag (official redis image)"
  type        = string
  default     = "8.4.0-alpine"
}

# ==============================================================================
# High Availability Configuration
# ==============================================================================

variable "ha_enabled" {
  description = "Enable HA mode with master-replica + Sentinel"
  type        = bool
  default     = false
}

variable "replica_count" {
  description = "Number of Redis replicas (minimum 3 for HA mode)"
  type        = number
  default     = 3

  validation {
    condition     = var.replica_count >= 1
    error_message = "Replica count must be at least 1"
  }
}

# ==============================================================================
# Resource Configuration
# ==============================================================================

variable "cpu_request" {
  description = "CPU request for Redis pods"
  type        = string
  default     = "250m"
}

variable "cpu_limit" {
  description = "CPU limit for Redis pods"
  type        = string
  default     = "1000m"
}

variable "memory_request" {
  description = "Memory request for Redis pods"
  type        = string
  default     = "512Mi"
}

variable "memory_limit" {
  description = "Memory limit for Redis pods"
  type        = string
  default     = "2Gi"
}

# ==============================================================================
# Storage Configuration
# ==============================================================================

variable "storage_class" {
  description = "Kubernetes storage class for Redis persistence"
  type        = string
  default     = "local-path"
}

variable "storage_size" {
  description = "Storage size for Redis persistence"
  type        = string
  default     = "10Gi"
}

# ==============================================================================
# Network Configuration
# ==============================================================================

variable "service_type" {
  description = "Kubernetes service type (ClusterIP, LoadBalancer, NodePort)"
  type        = string
  default     = "ClusterIP"
}

variable "service_annotations" {
  description = "Additional annotations for the Redis service"
  type        = map(string)
  default     = {}
}

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
# Redis Configuration
# ==============================================================================

variable "redis_config" {
  description = "Additional Redis configuration (appended to redis.conf)"
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
