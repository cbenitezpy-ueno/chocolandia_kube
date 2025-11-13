# Homepage RBAC Configuration

# ServiceAccount for Homepage pod
resource "kubernetes_service_account" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
}

# Role for service discovery and management (created in each monitored namespace)
resource "kubernetes_role" "homepage_viewer" {
  for_each = toset(var.monitored_namespaces)

  metadata {
    name      = "homepage-viewer"
    namespace = each.value
  }

  # Full access to pods, services, and deployments
  rule {
    api_groups = [""]
    resources  = ["services", "pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  # Access to deployments, replicasets, statefulsets, daemonsets
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch"]
  }

  # Access to ingresses
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  # Access to cert-manager Certificates (CRD)
  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["certificates"]
    verbs      = ["get", "list", "watch"]
  }

  # Access to ArgoCD Applications (CRD)
  rule {
    api_groups = ["argoproj.io"]
    resources  = ["applications"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRole for cluster-wide resources
resource "kubernetes_cluster_role" "homepage_cluster_viewer" {
  metadata {
    name = "homepage-cluster-viewer"
  }

  # Read access to nodes
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }

  # Read access to namespaces
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  # Read access to persistent volumes
  rule {
    api_groups = [""]
    resources  = ["persistentvolumes"]
    verbs      = ["get", "list", "watch"]
  }

  # Read access to metrics from metrics-server
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list"]
  }
}

# ClusterRoleBinding for cluster-wide access
resource "kubernetes_cluster_role_binding" "homepage_cluster_viewer" {
  metadata {
    name = "homepage-cluster-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.homepage_cluster_viewer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.homepage.metadata[0].name
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
}

# RoleBinding to connect ServiceAccount to Roles (one per monitored namespace)
resource "kubernetes_role_binding" "homepage_viewer" {
  for_each = toset(var.monitored_namespaces)

  metadata {
    name      = "homepage-viewer"
    namespace = each.value
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.homepage_viewer[each.key].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.homepage.metadata[0].name
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
}
