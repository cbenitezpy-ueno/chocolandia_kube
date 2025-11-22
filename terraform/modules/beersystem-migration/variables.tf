# Beersystem Migration - Variables
# Input variables for beersystem-backend Redis migration

variable "replicas" {
  description = "Number of replicas for beersystem-backend deployment. Set to 0 for migration downtime."
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 0 && var.replicas <= 3
    error_message = "Replicas must be between 0 and 3."
  }
}

variable "backend_image" {
  description = "Docker image for beersystem-backend container"
  type        = string
  default     = "992382722562.dkr.ecr.us-east-1.amazonaws.com/beer-awards-backend:staging"
}

variable "redis_host" {
  description = "Redis master hostname (DNS name for cluster-internal access)"
  type        = string
  default     = "redis-shared-master.redis.svc.cluster.local"
}

variable "redis_port" {
  description = "Redis port"
  type        = string
  default     = "6379"
}

variable "redis_secret_name" {
  description = "Name of the Kubernetes secret containing redis-password"
  type        = string
  default     = "redis-credentials"
}
