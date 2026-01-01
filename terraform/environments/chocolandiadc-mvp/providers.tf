# Provider configuration for ChocolandiaDC MVP
# This environment uses null provider for SSH-based provisioning

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.21"
    }
  }
}

# No cloud provider configuration needed for this MVP
# K3s installation will be performed via SSH using null_resource provisioners

# ============================================================================
# Helm Provider Configuration
# ============================================================================

provider "helm" {
  kubernetes {
    config_path = "${path.root}/kubeconfig"
  }
}

# ============================================================================
# Kubernetes Provider Configuration
# ============================================================================

provider "kubernetes" {
  config_path = "${path.root}/kubeconfig"
}

# ============================================================================
# Cloudflare Provider Configuration (Feature 004)
# ============================================================================

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# ============================================================================
# Random Provider Configuration (Feature 004)
# ============================================================================

provider "random" {}

# ============================================================================
# PostgreSQL Provider Configuration (Feature 027)
# ============================================================================

provider "postgresql" {
  host            = "192.168.4.204"
  port            = 5432
  username        = "postgres"
  password        = var.postgresql_admin_password
  sslmode         = "disable"
  connect_timeout = 15
  superuser       = true
}
