# Homepage Module Variables

variable "homepage_image" {
  description = "Docker image for Homepage"
  type        = string
  default     = "ghcr.io/gethomepage/homepage:v1.4.6"  # Pinned from :latest
}

variable "namespace" {
  description = "Kubernetes namespace for Homepage deployment"
  type        = string
  default     = "homepage"
}

variable "service_port" {
  description = "Internal service port for Homepage"
  type        = number
  default     = 3000
}

variable "argocd_token" {
  description = "ArgoCD API token for Homepage widget"
  type        = string
  sensitive   = true
}

variable "resource_requests_cpu" {
  description = "CPU request for Homepage container"
  type        = string
  default     = "100m"
}

variable "resource_requests_memory" {
  description = "Memory request for Homepage container"
  type        = string
  default     = "128Mi"
}

variable "resource_limits_cpu" {
  description = "CPU limit for Homepage container"
  type        = string
  default     = "500m"
}

variable "resource_limits_memory" {
  description = "Memory limit for Homepage container"
  type        = string
  default     = "512Mi"
}

variable "monitored_namespaces" {
  description = "List of Kubernetes namespaces to monitor for service discovery"
  type        = list(string)
  default     = ["default", "pihole", "traefik", "cert-manager", "argocd", "headlamp", "homepage", "monitoring", "beersystem", "minio", "postgresql", "longhorn-system"]
}

variable "domain_name" {
  description = "Domain name for Homepage external access"
  type        = string
  default     = "chocolandiadc.com"
}
