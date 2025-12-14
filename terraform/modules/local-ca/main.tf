# Local CA Module
# Creates a self-signed CA for .local domains that Let's Encrypt cannot issue

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# ==============================================================================
# Self-Signed ClusterIssuer (Bootstrap)
# ==============================================================================

resource "kubernetes_manifest" "selfsigned_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-issuer"
      labels = {
        "app.kubernetes.io/name"       = "local-ca"
        "app.kubernetes.io/component"  = "issuer"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      selfSigned = {}
    }
  }
}

# ==============================================================================
# CA Certificate (Root CA for .local domains)
# ==============================================================================

resource "kubernetes_manifest" "local_ca_certificate" {
  computed_fields = [
    "spec.duration",
    "spec.renewBefore"
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "local-ca"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"       = "local-ca"
        "app.kubernetes.io/component"  = "ca-certificate"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      isCA       = true
      commonName = var.ca_common_name
      secretName = "local-ca-secret"
      duration   = "87600h" # 10 years
      privateKey = {
        algorithm = "ECDSA"
        size      = 256
      }
      issuerRef = {
        name  = "selfsigned-issuer"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }

  depends_on = [kubernetes_manifest.selfsigned_issuer]
}

# ==============================================================================
# CA ClusterIssuer (Issues certificates for .local domains)
# ==============================================================================

resource "kubernetes_manifest" "local_ca_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.issuer_name
      labels = {
        "app.kubernetes.io/name"       = "local-ca"
        "app.kubernetes.io/component"  = "issuer"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }
    spec = {
      ca = {
        secretName = "local-ca-secret"
      }
    }
  }

  depends_on = [kubernetes_manifest.local_ca_certificate]
}
