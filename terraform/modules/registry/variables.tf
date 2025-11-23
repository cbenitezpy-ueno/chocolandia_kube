variable "namespace" {
  description = "Kubernetes namespace for registry deployment"
  type        = string
  default     = "registry"
}

variable "storage_size" {
  description = "PersistentVolumeClaim storage size for registry data"
  type        = string
  default     = "30Gi"
}

variable "hostname" {
  description = "Hostname for registry ingress (e.g., registry.homelab.local)"
  type        = string
}

variable "auth_secret" {
  description = "Name of the Kubernetes secret containing htpasswd file for basic auth"
  type        = string
}

variable "storage_class" {
  description = "Storage class for PVC"
  type        = string
  default     = "local-path"
}

variable "registry_image" {
  description = "Docker Registry image to deploy"
  type        = string
  default     = "registry:2"
}

variable "resource_limits_memory" {
  description = "Memory limit for registry container"
  type        = string
  default     = "512Mi"
}

variable "resource_limits_cpu" {
  description = "CPU limit for registry container"
  type        = string
  default     = "500m"
}

variable "resource_requests_memory" {
  description = "Memory request for registry container"
  type        = string
  default     = "256Mi"
}

variable "resource_requests_cpu" {
  description = "CPU request for registry container"
  type        = string
  default     = "100m"
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer name for TLS certificates"
  type        = string
  default     = "letsencrypt-prod"
}

variable "traefik_entrypoint" {
  description = "Traefik entrypoint for HTTPS traffic"
  type        = string
  default     = "websecure"
}

variable "enable_ui" {
  description = "Enable Registry UI deployment"
  type        = bool
  default     = true
}

variable "ui_hostname" {
  description = "Hostname for Registry UI (e.g., registry-ui.homelab.local)"
  type        = string
  default     = ""
}

variable "ui_image" {
  description = "Registry UI image to deploy"
  type        = string
  default     = "joxit/docker-registry-ui:latest"
}
