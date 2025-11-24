# ChocolandiaDC MVP Environment Variables
# Configuration for 2-node K3s cluster on Eero mesh network

# ============================================================================
# Cluster Configuration
# ============================================================================

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "chocolandiadc-mvp"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "k3s_version" {
  description = "K3s version to install across all nodes (e.g., 'v1.28.3+k3s1')"
  type        = string
  default     = "v1.28.3+k3s1"
}

# ============================================================================
# Master Node Configuration
# ============================================================================

variable "master1_hostname" {
  description = "Hostname for the K3s control-plane node"
  type        = string
  default     = "master1"
}

variable "master1_ip" {
  description = "Static IP address of master1 on Eero network"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.master1_ip))
    error_message = "Master1 IP must be a valid IPv4 address."
  }
}

# ============================================================================
# Worker Node Configuration
# ============================================================================

variable "nodo1_hostname" {
  description = "Hostname for the K3s worker node"
  type        = string
  default     = "nodo1"
}

variable "nodo1_ip" {
  description = "Static IP address of nodo1 on Eero network"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.nodo1_ip))
    error_message = "Nodo1 IP must be a valid IPv4 address."
  }
}

# ============================================================================
# Additional Control Plane Node Configuration (nodo03)
# ============================================================================

variable "nodo03_hostname" {
  description = "Hostname for the second K3s control-plane node"
  type        = string
  default     = "nodo03"
}

variable "nodo03_ip" {
  description = "Static IP address of nodo03 on Eero network"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.nodo03_ip))
    error_message = "Nodo03 IP must be a valid IPv4 address."
  }
}

# ============================================================================
# Additional Worker Node Configuration (nodo04)
# ============================================================================

variable "nodo04_hostname" {
  description = "Hostname for the second K3s worker node"
  type        = string
  default     = "nodo04"
}

variable "nodo04_ip" {
  description = "Static IP address of nodo04 on Eero network"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.nodo04_ip))
    error_message = "Nodo04 IP must be a valid IPv4 address."
  }
}

# ============================================================================
# SSH Configuration
# ============================================================================

variable "ssh_user" {
  description = "SSH username for connecting to all nodes (must have passwordless sudo)"
  type        = string
  default     = "cbenitez"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for authentication"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_port" {
  description = "SSH port for all nodes"
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port > 0 && var.ssh_port <= 65535
    error_message = "SSH port must be between 1 and 65535."
  }
}

# ============================================================================
# K3s Configuration
# ============================================================================

variable "disable_components" {
  description = "K3s components to disable (e.g., traefik, servicelb)"
  type        = list(string)
  default     = ["traefik"] # Disable Traefik (will use Nginx Ingress later)
}

variable "k3s_additional_flags" {
  description = "Additional flags to pass to K3s server"
  type        = list(string)
  default     = []
}

# ============================================================================
# Cloudflare Zero Trust Configuration (Feature 004)
# ============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Tunnel, Access, and DNS permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for chocolandiadc.com"
  type        = string
}

variable "cloudflare_email" {
  description = "Cloudflare account email (used for cert-manager DNS-01 challenge)"
  type        = string
}

variable "domain_name" {
  description = "Cloudflare-managed domain name"
  type        = string
  default     = "chocolandiadc.com"
}

variable "google_oauth_client_id" {
  description = "Google OAuth 2.0 Client ID"
  type        = string
}

variable "google_oauth_client_secret" {
  description = "Google OAuth 2.0 Client Secret"
  type        = string
  sensitive   = true
}

variable "authorized_emails" {
  description = "List of email addresses authorized to access protected services"
  type        = list(string)
}

variable "tunnel_name" {
  description = "Cloudflare Tunnel name"
  type        = string
  default     = "chocolandiadc-tunnel"
}

variable "tunnel_namespace" {
  description = "Kubernetes namespace for Cloudflare Tunnel deployment"
  type        = string
  default     = "cloudflare-tunnel"
}

variable "replica_count" {
  description = "Number of cloudflared replicas (1 for MVP, 2+ for HA)"
  type        = number
  default     = 1

  validation {
    condition     = var.replica_count >= 1
    error_message = "Replica count must be at least 1."
  }
}

variable "ingress_rules" {
  description = "List of ingress rules mapping public hostnames to internal services"
  type = list(object({
    hostname = string
    service  = string
  }))
}

# ============================================================================
# cert-manager Configuration (Feature 006)
# ============================================================================

variable "cert_manager_acme_email" {
  description = "Email address for Let's Encrypt ACME account notifications"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.cert_manager_acme_email))
    error_message = "cert_manager_acme_email must be a valid email address format"
  }
}

variable "cert_manager_enable_staging" {
  description = "Create staging ClusterIssuer for Let's Encrypt (recommended for testing)"
  type        = bool
  default     = true
}

variable "cert_manager_enable_production" {
  description = "Create production ClusterIssuer for Let's Encrypt (trusted certificates)"
  type        = bool
  default     = true
}

variable "cert_manager_enable_metrics" {
  description = "Enable Prometheus metrics endpoints for cert-manager components"
  type        = bool
  default     = true
}

variable "cert_manager_enable_servicemonitor" {
  description = "Enable ServiceMonitor for Prometheus Operator (requires Prometheus Operator)"
  type        = bool
  default     = true
}

# ============================================================================
# Headlamp Web UI Configuration (Feature 007)
# ============================================================================

variable "headlamp_domain" {
  description = "Domain name for Headlamp web interface (e.g., headlamp.chocolandiadc.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.headlamp_domain))
    error_message = "headlamp_domain must be a valid DNS name"
  }
}

variable "headlamp_authorized_emails" {
  description = "List of authorized email addresses for Headlamp Cloudflare Access"
  type        = list(string)

  validation {
    condition     = length(var.headlamp_authorized_emails) > 0
    error_message = "At least one authorized email is required for Headlamp access"
  }
}

variable "google_oauth_idp_id" {
  description = "Google OAuth Identity Provider ID from Cloudflare Zero Trust (UUID format) - Phase 6 (US4)"
  type        = string
  sensitive   = true
  default     = "" # Optional until Phase 6
}

# ============================================================================
# ArgoCD GitOps Configuration (Feature 008)
# ============================================================================

variable "argocd_domain" {
  description = "Domain name for ArgoCD web interface (e.g., argocd.chocolandiadc.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.argocd_domain))
    error_message = "argocd_domain must be a valid DNS name"
  }
}

variable "github_token" {
  description = "GitHub Personal Access Token for private repository authentication (repo scope)"
  type        = string
  sensitive   = true
}

variable "github_username" {
  description = "GitHub username for repository access"
  type        = string
  default     = "cbenitezpy-ueno"
}

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

# ============================================================================
# Homepage Dashboard Configuration (Feature 009)
# ============================================================================

variable "homepage_image" {
  description = "Docker image for Homepage dashboard"
  type        = string
  default     = "ghcr.io/gethomepage/homepage:latest"
}

variable "homepage_namespace" {
  description = "Kubernetes namespace for Homepage deployment"
  type        = string
  default     = "homepage"
}

variable "homepage_service_port" {
  description = "Internal service port for Homepage"
  type        = number
  default     = 3000
}

variable "argocd_token" {
  description = "ArgoCD API token for Homepage widget"
  type        = string
  sensitive   = true
}

variable "homepage_resource_requests_cpu" {
  description = "CPU request for Homepage container"
  type        = string
  default     = "100m"
}

variable "homepage_resource_requests_memory" {
  description = "Memory request for Homepage container"
  type        = string
  default     = "128Mi"
}

variable "homepage_resource_limits_cpu" {
  description = "CPU limit for Homepage container"
  type        = string
  default     = "500m"
}

variable "homepage_resource_limits_memory" {
  description = "Memory limit for Homepage container"
  type        = string
  default     = "512Mi"
}

variable "homepage_monitored_namespaces" {
  description = "List of Kubernetes namespaces to monitor for service discovery"
  type        = list(string)
  default     = ["traefik", "cert-manager", "argocd", "headlamp", "homepage", "monitoring"]
}

# ============================================================================
# Feature 001: Longhorn and MinIO Storage Infrastructure
# ============================================================================

variable "longhorn_domain" {
  description = "Domain for Longhorn web UI"
  type        = string
  default     = "longhorn.chocolandiadc.com"
}

variable "minio_console_domain" {
  description = "Domain for MinIO web console"
  type        = string
  default     = "minio.chocolandiadc.com"
}

variable "minio_s3_domain" {
  description = "Domain for MinIO S3 API endpoint"
  type        = string
  default     = "s3.chocolandiadc.com"
}

variable "longhorn_replica_count" {
  description = "Number of replicas for Longhorn volumes"
  type        = number
  default     = 2
}

variable "minio_storage_size" {
  description = "Storage size for MinIO PersistentVolume"
  type        = string
  default     = "50Gi"
}

# ============================================================================
# Netdata Hardware Monitoring Configuration
# ============================================================================

variable "netdata_domain" {
  description = "Domain for Netdata hardware monitoring dashboard"
  type        = string
  default     = "netdata.chocolandiadc.com"
}

variable "netdata_storage_size" {
  description = "Storage size for Netdata historical metrics database"
  type        = string
  default     = "10Gi"
}

# ============================================================================
# GitHub Actions Runner Configuration (Feature 017)
# ============================================================================

variable "github_actions_config_url" {
  description = "GitHub repository or organization URL for runner registration (e.g., https://github.com/owner/repo)"
  type        = string
  default     = "https://github.com/cbenitezpy-ueno/chocolandia_kube"

  validation {
    condition     = can(regex("^https://github.com/", var.github_actions_config_url))
    error_message = "GitHub config URL must start with https://github.com/"
  }
}

variable "github_app_id" {
  description = "GitHub App ID for runner authentication"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9]+$", var.github_app_id))
    error_message = "GitHub App ID must be a numeric string"
  }
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9]+$", var.github_app_installation_id))
    error_message = "GitHub App Installation ID must be a numeric string"
  }
}

variable "github_app_private_key" {
  description = "GitHub App private key in PEM format"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^-----BEGIN", var.github_app_private_key))
    error_message = "GitHub App private key must be in PEM format (starting with -----BEGIN)"
  }
}
