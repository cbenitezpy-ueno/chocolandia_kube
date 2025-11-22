# Redis Shared - Services Configuration
# Creates LoadBalancer service for private network (192.168.4.0/24) access

# ==============================================================================
# LoadBalancer Service - Private Network Access
# ==============================================================================
# This service exposes Redis on the private network via MetalLB.
# The Helm chart automatically creates ClusterIP services for internal access:
#   - redis-shared-master.redis.svc.cluster.local (write operations)
#   - redis-shared-replicas.redis.svc.cluster.local (read operations)

resource "kubernetes_service" "redis_external" {
  metadata {
    name      = "${var.release_name}-external"
    namespace = kubernetes_namespace.redis.metadata[0].name

    labels = merge(
      local.common_labels,
      {
        "app.kubernetes.io/component" = "external-access"
      }
    )

    annotations = {
      "metallb.universe.tf/address-pool"     = var.metallb_ip_pool
      "metallb.universe.tf/allow-shared-ip"  = var.release_name
      "svccontroller.k3s.cattle.io/enablelb" = "false" # Disable K3s ServiceLB
      "description"                          = "Redis LoadBalancer for private network (192.168.4.0/24) access"
    }
  }

  spec {
    type                    = "LoadBalancer"
    load_balancer_ip        = var.loadbalancer_ip
    external_traffic_policy = "Cluster"
    session_affinity        = "None"

    # Port Configuration
    port {
      name        = "tcp-redis"
      port        = 6379
      target_port = "redis"
      protocol    = "TCP"
    }

    # Selector targets Redis master pod
    # Helm chart applies these labels to master pods
    selector = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/instance"  = var.release_name
      "app.kubernetes.io/component" = "master"
    }
  }

  depends_on = [
    helm_release.redis
  ]
}
