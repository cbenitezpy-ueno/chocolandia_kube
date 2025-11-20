# Redis Shared - Namespace Configuration
# Creates dedicated "redis" namespace for shared Redis service

resource "kubernetes_namespace" "redis" {
  metadata {
    name = var.namespace

    labels = merge(
      local.common_labels,
      {
        "name" = var.namespace
      }
    )

    annotations = {
      "description" = "Shared Redis caching service for cluster applications"
    }
  }
}
