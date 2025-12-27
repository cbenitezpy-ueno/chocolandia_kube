# ArgoCD Module Variables
# Feature 008: GitOps Continuous Deployment with ArgoCD

# ==============================================================================
# Core Configuration
# ==============================================================================

variable "argocd_domain" {
  description = "Domain for ArgoCD web UI (e.g., argocd.chocolandiadc.com)"
  type        = string
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD deployment"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.9.0" # Upgraded from 5.51.0 (ArgoCD v2.9.x → v3.2.x)
}

# ==============================================================================
# GitHub Repository Authentication
# ==============================================================================

variable "github_token" {
  description = "GitHub Personal Access Token for private repository authentication"
  type        = string
  sensitive   = true
}

variable "github_username" {
  description = "GitHub username for repository access"
  type        = string
  default     = "cbenitez"
}

variable "github_repo_url" {
  description = "GitHub repository URL for chocolandia_kube"
  type        = string
  default     = "https://github.com/cbenitez/chocolandia_kube"
}

# ==============================================================================
# TLS Certificate Configuration
# ==============================================================================

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer name for TLS certificate issuance"
  type        = string
  default     = "letsencrypt-production"
}

variable "certificate_duration" {
  description = "TLS certificate duration (90 days)"
  type        = string
  default     = "2160h"
}

variable "certificate_renew_before" {
  description = "Renew certificate before expiration (30 days)"
  type        = string
  default     = "720h"
}

# ==============================================================================
# Cloudflare Access Configuration
# ==============================================================================

variable "cloudflare_account_id" {
  description = "Cloudflare account ID for Access application"
  type        = string
}

variable "authorized_emails" {
  description = "List of email addresses authorized to access ArgoCD UI"
  type        = list(string)
}

variable "google_oauth_idp_id" {
  description = "Google OAuth identity provider ID for Cloudflare Access"
  type        = string
}

variable "access_session_duration" {
  description = "Cloudflare Access session duration"
  type        = string
  default     = "24h"
}

variable "access_auto_redirect" {
  description = "Automatically redirect to identity provider"
  type        = bool
  default     = true
}

variable "access_app_launcher_visible" {
  description = "Show application in Cloudflare Access app launcher"
  type        = bool
  default     = true
}

# ==============================================================================
# Prometheus Metrics Configuration
# ==============================================================================

variable "enable_prometheus_metrics" {
  description = "Enable Prometheus ServiceMonitor for ArgoCD metrics"
  type        = bool
  default     = true
}

# ==============================================================================
# ArgoCD Component Resources
# ==============================================================================

variable "server_replicas" {
  description = "Number of argocd-server replicas (homelab: 1)"
  type        = number
  default     = 1
}

variable "server_cpu_limit" {
  description = "CPU limit for argocd-server"
  type        = string
  default     = "200m"
}

variable "server_memory_limit" {
  description = "Memory limit for argocd-server"
  type        = string
  default     = "256Mi"
}

variable "repo_server_replicas" {
  description = "Number of argocd-repo-server replicas (homelab: 1)"
  type        = number
  default     = 1
}

variable "repo_server_cpu_limit" {
  description = "CPU limit for argocd-repo-server"
  type        = string
  default     = "200m"
}

variable "repo_server_memory_limit" {
  description = "Memory limit for argocd-repo-server"
  type        = string
  default     = "128Mi"
}

variable "controller_replicas" {
  description = "Number of argocd-application-controller replicas (homelab: 1)"
  type        = number
  default     = 1
}

variable "controller_cpu_limit" {
  description = "CPU limit for argocd-application-controller"
  type        = string
  default     = "500m"
}

variable "controller_memory_limit" {
  description = "Memory limit for argocd-application-controller"
  type        = string
  default     = "512Mi"
}

# ==============================================================================
# ArgoCD Polling Configuration
# ==============================================================================

variable "repository_polling_interval" {
  description = "Git repository polling interval (reconciliation timeout)"
  type        = string
  default     = "180s" # 3 minutes
}

# ==============================================================================
# Network Access Configuration
# ==============================================================================

variable "enable_nodeport" {
  description = "Enable NodePort access for ArgoCD CLI from private network"
  type        = bool
  default     = true
}

variable "nodeport_http" {
  description = "NodePort for HTTP access (CLI and Web UI) on private network"
  type        = number
  default     = 30080
}
