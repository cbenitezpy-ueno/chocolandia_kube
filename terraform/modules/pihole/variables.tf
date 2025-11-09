# Pi-hole Module - Input Variables
# Configures Pi-hole DNS ad blocker deployment on K3s cluster

# ============================================================================
# Admin Configuration
# ============================================================================

variable "admin_password" {
  description = "Pi-hole web admin password (stored in Kubernetes Secret)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "Admin password must be at least 8 characters."
  }
}

# ============================================================================
# DNS Configuration
# ============================================================================

variable "timezone" {
  description = "Timezone for Pi-hole logs (IANA format, e.g., 'America/New_York', 'UTC')"
  type        = string
  default     = "UTC"
}

variable "upstream_dns" {
  description = "Upstream DNS servers (semicolon-separated, e.g., '1.1.1.1;8.8.8.8')"
  type        = string
  default     = "1.1.1.1;8.8.8.8"

  validation {
    condition     = length(var.upstream_dns) > 0
    error_message = "Upstream DNS must contain at least one valid IP address."
  }
}

# ============================================================================
# Kubernetes Configuration
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Pi-hole deployment"
  type        = string
  default     = "default"
}

variable "image" {
  description = "Pi-hole Docker image"
  type        = string
  default     = "pihole/pihole:latest"
}

variable "replicas" {
  description = "Number of Pi-hole pod replicas (1 for MVP, 2+ for HA)"
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1
    error_message = "Replicas must be at least 1."
  }
}

# ============================================================================
# Storage Configuration
# ============================================================================

variable "storage_size" {
  description = "PersistentVolumeClaim size for Pi-hole configuration"
  type        = string
  default     = "2Gi"
}

variable "storage_class" {
  description = "Storage class for PersistentVolumeClaim (K3s default: local-path)"
  type        = string
  default     = "local-path"
}

# ============================================================================
# Resource Limits
# ============================================================================

variable "cpu_request" {
  description = "CPU resource request (e.g., '100m', '0.5')"
  type        = string
  default     = "100m"
}

variable "cpu_limit" {
  description = "CPU resource limit (e.g., '500m', '1')"
  type        = string
  default     = "500m"
}

variable "memory_request" {
  description = "Memory resource request (e.g., '256Mi', '1Gi')"
  type        = string
  default     = "256Mi"
}

variable "memory_limit" {
  description = "Memory resource limit (e.g., '512Mi', '1Gi')"
  type        = string
  default     = "512Mi"
}

# ============================================================================
# Service Configuration
# ============================================================================

variable "web_nodeport" {
  description = "NodePort for web admin interface (30000-32767)"
  type        = number
  default     = 30001

  validation {
    condition     = var.web_nodeport >= 30000 && var.web_nodeport <= 32767
    error_message = "NodePort must be in range 30000-32767."
  }
}

variable "node_ips" {
  description = "List of K3s node IPs for NodePort access (e.g., ['192.168.4.101', '192.168.4.102'])"
  type        = list(string)
  default     = ["192.168.4.101", "192.168.4.102"]
}
