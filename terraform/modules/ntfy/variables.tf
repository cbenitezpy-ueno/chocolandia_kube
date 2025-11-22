# Ntfy Module - Variables
# Feature: 014-monitoring-alerts

variable "namespace" {
  description = "Kubernetes namespace for Ntfy"
  type        = string
  default     = "ntfy"
}

variable "image_tag" {
  description = "Ntfy container image tag"
  type        = string
  default     = "latest"
}

variable "ingress_host" {
  description = "Hostname for Ntfy ingress"
  type        = string
  default     = "ntfy.chocolandia.com"
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer name for TLS"
  type        = string
  default     = "letsencrypt-prod"
}

variable "storage_class" {
  description = "Storage class for PVC"
  type        = string
  default     = "local-path"
}

variable "storage_size" {
  description = "PVC storage size"
  type        = string
  default     = "1Gi"
}

variable "default_topic" {
  description = "Default topic name for alerts"
  type        = string
  default     = "homelab-alerts"
}

variable "enable_auth" {
  description = "Enable authentication for Ntfy"
  type        = bool
  default     = true
}

variable "auth_default_access" {
  description = "Default access for unauthenticated users (deny-all, read-only, write-only, read-write)"
  type        = string
  default     = "read-only"
}

variable "admin_password" {
  description = "Admin user password (will be hashed)"
  type        = string
  sensitive   = true
  default     = ""
}
