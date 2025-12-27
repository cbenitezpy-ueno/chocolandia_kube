# ============================================================================
# MetalLB Load Balancer Module
# ============================================================================
# This module deploys MetalLB via Helm chart for bare-metal LoadBalancer
# services in K3s cluster.
#
# Refactored to use declarative kubernetes_manifest resources instead of
# null_resource provisioners for accurate plan visibility and state tracking.
# ============================================================================

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

# MetalLB Helm Release
resource "helm_release" "metallb" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = true
  wait             = true
  timeout          = 300

  # Disable speaker if using L2 only mode (our case)
  set {
    name  = "speaker.frr.enabled"
    value = "false"
  }
}

# Wait for MetalLB CRDs to be registered after Helm release
resource "time_sleep" "wait_for_crds" {
  depends_on = [helm_release.metallb]

  create_duration = var.crd_wait_duration
}

# IPAddressPool for LoadBalancer IPs
resource "kubernetes_manifest" "ip_address_pool" {
  depends_on = [time_sleep.wait_for_crds]

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = var.pool_name
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"       = "metallb"
        "app.kubernetes.io/component"  = "ip-pool"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      addresses  = [var.ip_range]
      autoAssign = true
    }
  }

  field_manager {
    name            = "opentofu"
    force_conflicts = false
  }
}

# L2Advertisement for Layer 2 mode IP announcement
resource "kubernetes_manifest" "l2_advertisement" {
  depends_on = [kubernetes_manifest.ip_address_pool]

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "${var.pool_name}-l2"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"       = "metallb"
        "app.kubernetes.io/component"  = "l2-advertisement"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      ipAddressPools = [var.pool_name]
    }
  }

  field_manager {
    name            = "opentofu"
    force_conflicts = false
  }
}
