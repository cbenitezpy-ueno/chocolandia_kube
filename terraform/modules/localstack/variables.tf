variable "namespace" {
  description = "Kubernetes namespace for LocalStack deployment"
  type        = string
  default     = "localstack"
}

variable "services_list" {
  description = "Comma-separated list of AWS services to enable"
  type        = string
  default     = "s3,sqs,sns,dynamodb,lambda"
}

variable "storage_size" {
  description = "PersistentVolumeClaim storage size for LocalStack data"
  type        = string
  default     = "20Gi"
}

variable "hostname" {
  description = "Hostname for LocalStack ingress (e.g., localstack.homelab.local)"
  type        = string
}

variable "storage_class" {
  description = "Storage class for PVC"
  type        = string
  default     = "local-path"
}

variable "localstack_image" {
  description = "LocalStack image to deploy"
  type        = string
  default     = "localstack/localstack:latest"
}

variable "resource_limits_memory" {
  description = "Memory limit for LocalStack container"
  type        = string
  default     = "2Gi"
}

variable "resource_limits_cpu" {
  description = "CPU limit for LocalStack container"
  type        = string
  default     = "1000m"
}

variable "resource_requests_memory" {
  description = "Memory request for LocalStack container"
  type        = string
  default     = "512Mi"
}

variable "resource_requests_cpu" {
  description = "CPU request for LocalStack container"
  type        = string
  default     = "200m"
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

variable "enable_persistence" {
  description = "Enable data persistence across restarts"
  type        = bool
  default     = true
}

variable "lambda_executor" {
  description = "Lambda execution mode (docker or local)"
  type        = string
  default     = "docker"
}
