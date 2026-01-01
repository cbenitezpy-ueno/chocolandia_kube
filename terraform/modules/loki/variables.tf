# ============================================================================
# Loki Module Variables
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Loki"
  type        = string
  default     = "loki"
}

variable "grafana_namespace" {
  description = "Namespace where Grafana is deployed (for datasource config)"
  type        = string
  default     = "monitoring"
}

variable "loki_chart_version" {
  description = "Loki Helm chart version (grafana/loki chart for Loki 3.x)"
  type        = string
  default     = "6.23.0"  # Loki 3.3.2
}

variable "promtail_chart_version" {
  description = "Promtail Helm chart version"
  type        = string
  default     = "6.16.6"
}

# Storage Configuration
variable "persistence_enabled" {
  description = "Enable persistence for Loki"
  type        = bool
  default     = true
}

variable "persistence_size" {
  description = "Size of the persistent volume for Loki"
  type        = string
  default     = "10Gi"
}

variable "storage_class_name" {
  description = "Storage class for Loki PVC"
  type        = string
  default     = "longhorn"
}

variable "retention_period" {
  description = "Log retention period"
  type        = string
  default     = "168h" # 7 days
}

# Loki Resources
variable "loki_resources_requests_cpu" {
  description = "CPU requests for Loki"
  type        = string
  default     = "100m"
}

variable "loki_resources_requests_memory" {
  description = "Memory requests for Loki"
  type        = string
  default     = "256Mi"
}

variable "loki_resources_limits_cpu" {
  description = "CPU limits for Loki"
  type        = string
  default     = "500m"
}

variable "loki_resources_limits_memory" {
  description = "Memory limits for Loki"
  type        = string
  default     = "512Mi"
}

# Promtail Resources
variable "promtail_resources_requests_cpu" {
  description = "CPU requests for Promtail"
  type        = string
  default     = "50m"
}

variable "promtail_resources_requests_memory" {
  description = "Memory requests for Promtail"
  type        = string
  default     = "64Mi"
}

variable "promtail_resources_limits_cpu" {
  description = "CPU limits for Promtail"
  type        = string
  default     = "200m"
}

variable "promtail_resources_limits_memory" {
  description = "Memory limits for Promtail"
  type        = string
  default     = "128Mi"
}

# Monitoring
variable "enable_service_monitor" {
  description = "Enable Prometheus ServiceMonitor for Loki and Promtail"
  type        = bool
  default     = true
}
