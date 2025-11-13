# Homepage RBAC Configuration

# ServiceAccount for Homepage pod
resource "kubernetes_service_account" "homepage" {
  metadata {
    name      = "homepage"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }
}

# Role for service discovery (created in each monitored namespace)
resource "kubernetes_role" "homepage_viewer" {
  for_each = toset(var.monitored_namespaces)

  metadata {
    name      = "homepage-viewer"
    namespace = each.value
  }

  # Read access to services
  rule {
    api_groups = [""]
    resources  = ["services", "pods"]
    verbs      = ["get", "list"]
  }

  # Read access to ingresses
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list"]
  }

  # Read access to cert-manager Certificates (CRD)
  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["certificates"]
    verbs      = ["get", "list"]
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
