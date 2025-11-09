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
