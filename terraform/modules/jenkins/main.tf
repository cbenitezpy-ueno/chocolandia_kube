# Jenkins Module - Main Configuration
# Feature 029: Jenkins CI Deployment
#
# Deploys Jenkins CI server using Helm chart with JCasC configuration.
# Includes DinD sidecar for Docker builds inside Kubernetes.

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  # Generate admin password if not provided
  admin_password = var.admin_password != "" ? var.admin_password : random_password.admin_password[0].result

  # Common labels
  labels = {
    app                            = "jenkins"
    "app.kubernetes.io/name"       = "jenkins"
    "app.kubernetes.io/component"  = "ci-server"
    "app.kubernetes.io/managed-by" = "opentofu"
  }
}

# ==============================================================================
# Random Password (if not provided)
# ==============================================================================

resource "random_password" "admin_password" {
  count   = var.admin_password == "" ? 1 : 0
  length  = 24
  special = true
}

# ==============================================================================
# Namespace
# ==============================================================================

resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace
    labels = merge(local.labels, {
      name = var.namespace
    })
  }
}

# ==============================================================================
# PersistentVolumeClaim for Jenkins Home
# ==============================================================================

resource "kubernetes_persistent_volume_claim" "jenkins_home" {
  metadata {
    name      = "jenkins-home"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }

  wait_until_bound = false
}

# ==============================================================================
# PersistentVolumeClaim for DinD Docker Cache
# NOTE: Disabled for now - using emptyDir until DinD stability improves
# ==============================================================================

# resource "kubernetes_persistent_volume_claim" "dind_storage" {
#   metadata {
#     name      = "jenkins-dind-storage"
#     namespace = kubernetes_namespace.jenkins.metadata[0].name
#     labels = merge(local.labels, {
#       "app.kubernetes.io/component" = "dind-cache"
#     })
#   }
#
#   spec {
#     access_modes       = ["ReadWriteOnce"]
#     storage_class_name = var.storage_class
#
#     resources {
#       requests = {
#         storage = var.dind_storage_size
#       }
#     }
#   }
#
#   wait_until_bound = false
# }

# ==============================================================================
# Kubernetes Secret - Jenkins Admin Password
# ==============================================================================

resource "kubernetes_secret" "jenkins_admin" {
  metadata {
    name      = "jenkins-admin"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
    labels    = local.labels
  }

  data = {
    jenkins-admin-user     = var.admin_user
    jenkins-admin-password = local.admin_password
  }

  type = "Opaque"
}

# ==============================================================================
# Kubernetes Secret - Nexus Docker Credentials
# ==============================================================================

resource "kubernetes_secret" "nexus_credentials" {
  metadata {
    name      = "nexus-docker-credentials"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
    labels    = local.labels
  }

  data = {
    username = var.nexus_username
    password = var.nexus_password
  }

  type = "Opaque"
}

# ==============================================================================
# Jenkins Helm Release
# ==============================================================================

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = var.chart_repository
  chart      = "jenkins"
  version    = var.chart_version
  namespace  = kubernetes_namespace.jenkins.metadata[0].name

  wait    = true
  timeout = 900 # 15 minutes - Jenkins startup can be slow

  values = [
    templatefile("${path.module}/values/jenkins.yaml", {
      admin_user              = var.admin_user
      controller_image        = var.jenkins_image
      controller_tag          = var.jenkins_tag
      controller_cpu_request  = var.controller_cpu_request
      controller_cpu_limit    = var.controller_cpu_limit
      controller_memory_request = var.controller_memory_request
      controller_memory_limit = var.controller_memory_limit
      dind_cpu_request        = var.dind_cpu_request
      dind_cpu_limit          = var.dind_cpu_limit
      dind_memory_request     = var.dind_memory_request
      dind_memory_limit       = var.dind_memory_limit
      storage_class           = var.storage_class
      storage_size            = var.storage_size
      hostname                = var.hostname
      nexus_docker_registry   = var.nexus_docker_registry
      enable_metrics          = var.enable_metrics
    })
  ]

  # Note: admin password is provided via existingSecret in values.yaml
  # The set_sensitive block is not needed when using existingSecret

  depends_on = [
    kubernetes_namespace.jenkins,
    kubernetes_persistent_volume_claim.jenkins_home,
    kubernetes_secret.jenkins_admin,
    kubernetes_secret.nexus_credentials
  ]
}
