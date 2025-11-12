# ==============================================================================
# ServiceAccount for Headlamp Admin Access
# ==============================================================================

resource "kubernetes_service_account" "headlamp_admin" {
  metadata {
    name      = "headlamp-admin"
    namespace = kubernetes_namespace.headlamp.metadata[0].name

    labels = {
      "app.kubernetes.io/name"       = "headlamp"
      "app.kubernetes.io/component"  = "admin"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # Auto-mount token disabled (we'll use explicit Secret for long-lived token)
  automount_service_account_token = false
}

# ==============================================================================
# Long-Lived ServiceAccount Token Secret
# ==============================================================================

resource "kubernetes_secret" "headlamp_admin_token" {
  metadata {
    name      = "headlamp-admin-token"
    namespace = kubernetes_namespace.headlamp.metadata[0].name

    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.headlamp_admin.metadata[0].name
    }

    labels = {
      "app.kubernetes.io/name"       = "headlamp"
      "app.kubernetes.io/component"  = "admin"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [
    kubernetes_service_account.headlamp_admin
  ]
}

# ==============================================================================
# ClusterRoleBinding - Read-Only Access
# ==============================================================================

resource "kubernetes_cluster_role_binding" "headlamp_view" {
  metadata {
    name = "headlamp-view-binding"

    labels = {
      "app.kubernetes.io/name"       = "headlamp"
      "app.kubernetes.io/component"  = "rbac"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # Bind to built-in ClusterRole "view" (read-only permissions)
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  # Grant permissions to headlamp-admin ServiceAccount
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.headlamp_admin.metadata[0].name
    namespace = kubernetes_namespace.headlamp.metadata[0].name
  }

  depends_on = [
    kubernetes_service_account.headlamp_admin
  ]
}

# ==============================================================================
# Notes on ClusterRole "view"
# ==============================================================================

# The built-in ClusterRole "view" provides read-only access to most resources:
#
# ALLOWED:
# - View pods, services, deployments, replicasets, daemonsets, statefulsets
# - View configmaps (but NOT secrets)
# - View persistent volumes and claims
# - View ingresses, network policies
# - View custom resources (IngressRoutes, Certificates, ServiceMonitors, etc.)
# - View events, logs
# - View resource metrics (via metrics-server)
#
# BLOCKED:
# - View secrets (security: prevents exposure of sensitive data)
# - Create, update, delete any resources
# - Exec into pods
# - Port-forward to pods
# - Proxy to services
#
# This ensures safe cluster exploration without risk of destructive operations.
