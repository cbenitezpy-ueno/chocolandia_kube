# ==============================================================================
# OIDC RBAC Configuration
# Grants read-only cluster access to OIDC-authenticated users
# ==============================================================================

# ClusterRoleBinding for OIDC users with read-only access
# Binds each authorized email to the built-in "view" ClusterRole
resource "kubernetes_cluster_role_binding" "oidc_users_view" {
  for_each = toset(var.authorized_emails)

  metadata {
    name = "oidc-${replace(each.value, "@", "-at-")}-view"
    labels = {
      "app.kubernetes.io/name"       = "headlamp"
      "app.kubernetes.io/component"  = "oidc-rbac"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view" # Built-in Kubernetes read-only role
  }

  subject {
    kind = "User"
    name = each.value # Email from OIDC token (username claim)
  }
}

# ==============================================================================
# Notes on OIDC RBAC Configuration
# ==============================================================================
#
# How OIDC Authentication Works:
# 1. User authenticates via Google OAuth in Headlamp UI
# 2. Google returns ID token with email claim
# 3. Headlamp sends ID token to K3s API server
# 4. K3s validates token with Google (issuer URL)
# 5. K3s extracts email from token (username-claim)
# 6. K3s checks RBAC for user with that email
# 7. This ClusterRoleBinding grants "view" role to the email
#
# ClusterRole "view":
# - Read-only access to most resources (pods, services, deployments, etc.)
# - Cannot create, update, or delete resources
# - Cannot access secrets (for security)
# - Cannot view or modify RBAC resources
#
# Why separate binding for each email?
# - Kubernetes doesn't support list of users in a single Subject
# - Using for_each creates one binding per authorized email
# - Each binding is named: oidc-<email-sanitized>-view
#
# Example:
# - User: cbenitez@gmail.com
# - Binding name: oidc-cbenitez-at-gmail.com-view
# - Grants: ClusterRole "view"
# - Result: Read-only access to cluster resources
#
