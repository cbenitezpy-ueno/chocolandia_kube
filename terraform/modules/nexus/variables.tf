# Nexus Repository Manager - Module Variables

variable "namespace" {
  description = "Kubernetes namespace for Nexus deployment"
  type        = string
  default     = "nexus"
}

variable "hostname" {
  description = "Hostname for Nexus web UI (e.g., nexus.chocolandiadc.local)"
  type        = string
}

variable "docker_hostname" {
  description = "Hostname for Docker registry API (e.g., docker.nexus.chocolandiadc.local)"
  type        = string
}

variable "storage_size" {
  description = "PersistentVolumeClaim storage size for Nexus data"
  type        = string
  default     = "50Gi"
}

variable "storage_class" {
  description = "Storage class for PVC"
  type        = string
  default     = "local-path"
}

variable "nexus_image" {
  description = "Nexus Repository Manager container image"
  type        = string
  default     = "sonatype/nexus3:latest"
}

variable "resource_limits_memory" {
  description = "Memory limit for Nexus container"
  type        = string
  default     = "2Gi"
}

variable "resource_limits_cpu" {
  description = "CPU limit for Nexus container"
  type        = string
  default     = "1000m"
}

variable "resource_requests_memory" {
  description = "Memory request for Nexus container"
  type        = string
  default     = "1536Mi"
}

variable "resource_requests_cpu" {
  description = "CPU request for Nexus container"
  type        = string
  default     = "500m"
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

variable "enable_metrics" {
  description = "Enable Prometheus metrics endpoint and ServiceMonitor"
  type        = bool
  default     = true
}

variable "jvm_heap_size" {
  description = "JVM heap size for Nexus (e.g., 1200m)"
  type        = string
  default     = "1200m"
}
