# Redis Shared - Secrets Management
# Generates Redis password and replicates credentials to multiple namespaces

# ==============================================================================
# Password Generation
# ==============================================================================

resource "random_password" "redis_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?" # Avoid backticks, quotes, and shell-sensitive chars
}

# ==============================================================================
# Secret - Primary Namespace (redis)
# ==============================================================================

resource "kubernetes_secret" "redis_credentials" {
  metadata {
    name      = "redis-credentials"
    namespace = kubernetes_namespace.redis.metadata[0].name

    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/component" = "authentication"
      }
    )

    annotations = {
      "description" = "Redis authentication credentials for shared caching service"
    }
  }

  data = {
    redis-password = random_password.redis_password.result
  }

  type = "Opaque"
}

# ==============================================================================
# Secret Replication - Additional Namespaces
# ==============================================================================
# Replicates the same Redis password to other namespaces for cross-namespace access
# This enables applications in different namespaces to connect to redis-shared
# without complex RBAC configurations or External Secrets Operator

resource "kubernetes_secret" "redis_credentials_replica" {
  for_each = toset(var.replica_namespaces)

  metadata {
    name      = "redis-credentials"
    namespace = each.value

    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/component" = "authentication"
        "replica-of"                  = kubernetes_secret.redis_credentials.metadata[0].name
        "source-namespace"            = kubernetes_namespace.redis.metadata[0].name
      }
    )

    annotations = {
      "description"      = "Replicated Redis credentials from ${kubernetes_namespace.redis.metadata[0].name} namespace"
      "source-secret"    = kubernetes_secret.redis_credentials.metadata[0].name
      "managed-by"       = "opentofu"
      "replication-date" = timestamp()
    }
  }

  data = {
    redis-password = random_password.redis_password.result
  }

  type = "Opaque"
}
