# Jenkins Module Variables
# Feature 029: Jenkins CI Deployment

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# ==============================================================================
# Namespace Configuration
# ==============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Jenkins"
  type        = string
  default     = "jenkins"
}

# ==============================================================================
# Jenkins Controller Configuration
# ==============================================================================

variable "jenkins_image" {
  description = "Jenkins Docker image"
  type        = string
  default     = "jenkins/jenkins"
}

variable "jenkins_tag" {
  description = "Jenkins Docker image tag"
  type        = string
  default     = "lts-jdk17"
}

variable "admin_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Jenkins admin password (generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

# ==============================================================================
# Resource Configuration
# ==============================================================================

variable "controller_cpu_request" {
  description = "CPU request for Jenkins controller"
  type        = string
  default     = "500m"
}

variable "controller_cpu_limit" {
  description = "CPU limit for Jenkins controller"
  type        = string
  default     = "2000m"
}

variable "controller_memory_request" {
  description = "Memory request for Jenkins controller"
  type        = string
  default     = "1Gi"
}

variable "controller_memory_limit" {
  description = "Memory limit for Jenkins controller"
  type        = string
  default     = "2Gi"
}

variable "dind_cpu_request" {
  description = "CPU request for DinD sidecar"
  type        = string
  default     = "200m"
}

variable "dind_cpu_limit" {
  description = "CPU limit for DinD sidecar"
  type        = string
  default     = "1000m"
}

variable "dind_memory_request" {
  description = "Memory request for DinD sidecar"
  type        = string
  default     = "512Mi"
}

variable "dind_memory_limit" {
  description = "Memory limit for DinD sidecar"
  type        = string
  default     = "1Gi"
}

# ==============================================================================
# Storage Configuration
# ==============================================================================

variable "storage_class" {
  description = "Storage class for Jenkins PVC"
  type        = string
  default     = "local-path"
}

variable "storage_size" {
  description = "Storage size for Jenkins home"
  type        = string
  default     = "20Gi"
}

# ==============================================================================
# Ingress Configuration
# ==============================================================================

variable "hostname" {
  description = "Hostname for Jenkins web UI (LAN)"
  type        = string
  default     = "jenkins.chocolandiadc.local"
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer for TLS certificate"
  type        = string
  default     = "local-ca"
}

variable "traefik_entrypoint" {
  description = "Traefik entrypoint for HTTPS"
  type        = string
  default     = "websecure"
}

# ==============================================================================
# Nexus Integration
# ==============================================================================

variable "nexus_docker_registry" {
  description = "Nexus Docker registry hostname"
  type        = string
  default     = "docker.nexus.chocolandiadc.local"
}

variable "nexus_username" {
  description = "Nexus registry username"
  type        = string
  default     = "admin"
}

variable "nexus_password" {
  description = "Nexus registry password"
  type        = string
  sensitive   = true
}

# ==============================================================================
# Monitoring Configuration
# ==============================================================================

variable "enable_metrics" {
  description = "Enable Prometheus metrics endpoint"
  type        = bool
  default     = true
}

variable "metrics_port" {
  description = "Port for Prometheus metrics"
  type        = number
  default     = 8080
}

# ==============================================================================
# Notification Configuration
# ==============================================================================

variable "ntfy_server" {
  description = "ntfy server URL"
  type        = string
  default     = "http://ntfy.ntfy.svc.cluster.local"
}

variable "ntfy_topic" {
  description = "ntfy topic for build notifications"
  type        = string
  default     = "homelab-alerts"
}

# ==============================================================================
# Helm Chart Configuration
# ==============================================================================

variable "chart_version" {
  description = "Jenkins Helm chart version"
  type        = string
  default     = "5.8.3"
}

variable "chart_repository" {
  description = "Jenkins Helm chart repository"
  type        = string
  default     = "https://charts.jenkins.io"
}
