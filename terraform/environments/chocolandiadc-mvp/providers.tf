# Provider configuration for ChocolandiaDC MVP
# This environment uses null provider for SSH-based provisioning

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# No cloud provider configuration needed for this MVP
# K3s installation will be performed via SSH using null_resource provisioners
