# K3s Node Module - Input Variables
# Configures individual K3s server (control-plane) or agent (worker) nodes

# ============================================================================
# Node Identity
# ============================================================================

variable "hostname" {
  description = "Hostname for the K3s node (e.g., 'master1', 'nodo1')"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.hostname))
    error_message = "Hostname must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "node_ip" {
  description = "Static IP address of the node on the network (e.g., '192.168.4.10')"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.node_ip))
    error_message = "Node IP must be a valid IPv4 address."
  }
}

variable "node_role" {
  description = "Role of the node: 'server' for control-plane or 'agent' for worker"
  type        = string

  validation {
    condition     = contains(["server", "agent"], var.node_role)
    error_message = "Node role must be either 'server' or 'agent'."
  }
}

# ============================================================================
# SSH Access Configuration
# ============================================================================

variable "ssh_user" {
  description = "SSH username for connecting to the node (must have passwordless sudo)"
  type        = string
  default     = "cbenitez"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for authentication"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_port" {
  description = "SSH port for connecting to the node"
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

variable "k3s_version" {
  description = "K3s version to install (e.g., 'v1.28.3+k3s1'). Use 'latest' for most recent stable."
  type        = string
  default     = "v1.28.3+k3s1"
}

variable "k3s_channel" {
  description = "K3s release channel: 'stable', 'latest', or 'testing'"
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["stable", "latest", "testing"], var.k3s_channel)
    error_message = "K3s channel must be 'stable', 'latest', or 'testing'."
  }
}

variable "k3s_flags" {
  description = "Additional flags to pass to K3s server or agent (e.g., ['--disable=traefik', '--write-kubeconfig-mode=644'])"
  type        = list(string)
  default     = []
}

# ============================================================================
# Cluster Join Configuration (Agent nodes only)
# ============================================================================

variable "server_url" {
  description = "K3s server URL for agent nodes to join (e.g., 'https://192.168.4.10:6443'). Required for agent nodes."
  type        = string
  default     = ""

  validation {
    condition     = var.server_url == "" || can(regex("^https://", var.server_url))
    error_message = "Server URL must start with 'https://' when provided."
  }
}

variable "join_token" {
  description = "K3s cluster join token for agent nodes. Required for agent nodes. Obtain from server node output."
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================================
# Advanced Configuration
# ============================================================================

variable "datastore" {
  description = "Datastore type for K3s server: 'sqlite' (default, embedded) or 'etcd' (external HA)"
  type        = string
  default     = "sqlite"

  validation {
    condition     = contains(["sqlite", "etcd"], var.datastore)
    error_message = "Datastore must be 'sqlite' or 'etcd'."
  }
}

variable "disable_components" {
  description = "K3s components to disable (e.g., ['traefik', 'servicelb']). Useful for custom ingress/LB."
  type        = list(string)
  default     = ["traefik"] # Disable Traefik by default (will use Nginx Ingress)
}

variable "tls_san" {
  description = "Additional hostnames/IPs to add to TLS certificate Subject Alternative Names"
  type        = list(string)
  default     = []
}

variable "cluster_init" {
  description = "Initialize HA cluster with embedded etcd (only for first server node)"
  type        = bool
  default     = false
}

# ============================================================================
# OIDC Authentication Configuration (Server nodes only)
# ============================================================================

variable "enable_oidc" {
  description = "Enable OIDC authentication for Kubernetes API server (server nodes only)"
  type        = bool
  default     = false
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL (e.g., 'https://accounts.google.com')"
  type        = string
  default     = "https://accounts.google.com"
}

variable "oidc_client_id" {
  description = "OIDC client ID for Google OAuth"
  type        = string
  sensitive   = true
  default     = ""
}

variable "oidc_client_secret" {
  description = "OIDC client secret for Google OAuth"
  type        = string
  sensitive   = true
  default     = ""
}

variable "oidc_username_claim" {
  description = "JWT claim to use as the user name"
  type        = string
  default     = "email"
}

variable "oidc_groups_claim" {
  description = "JWT claim to use as the user's group"
  type        = string
  default     = "groups"
}

variable "oidc_username_prefix" {
  description = "Prefix prepended to username claims to prevent conflicts"
  type        = string
  default     = "-"
}
