# Alerting Rules Module - Variables
# Feature: 014-monitoring-alerts

variable "namespace" {
  description = "Namespace where PrometheusRules will be created"
  type        = string
  default     = "monitoring"
}

variable "grafana_url" {
  description = "Grafana URL for dashboard links in alerts"
  type        = string
  default     = "http://192.168.4.101:30000"
}

variable "node_down_threshold_minutes" {
  description = "Minutes before a node is considered down"
  type        = number
  default     = 5
}

variable "disk_usage_warning_percent" {
  description = "Disk usage percentage for warning alerts"
  type        = number
  default     = 80
}

variable "disk_usage_critical_percent" {
  description = "Disk usage percentage for critical alerts"
  type        = number
  default     = 90
}

variable "memory_usage_warning_percent" {
  description = "Memory usage percentage for warning alerts"
  type        = number
  default     = 80
}

variable "memory_usage_critical_percent" {
  description = "Memory usage percentage for critical alerts"
  type        = number
  default     = 90
}

variable "cpu_usage_warning_percent" {
  description = "CPU usage percentage for warning alerts"
  type        = number
  default     = 80
}

variable "cpu_usage_critical_percent" {
  description = "CPU usage percentage for critical alerts"
  type        = number
  default     = 90
}
