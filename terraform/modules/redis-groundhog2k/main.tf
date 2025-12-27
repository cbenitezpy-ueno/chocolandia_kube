# Redis Groundhog2k - Main Helm Release Configuration
# Deploys Redis using official Docker images (not Bitnami)
# Chart: https://github.com/groundhog2k/helm-charts/tree/master/charts/redis

# ==============================================================================
# Namespace
# ==============================================================================

resource "kubernetes_namespace" "redis" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "redis"
      "app.kubernetes.io/managed-by" = "opentofu"
      "feature"                      = "013-redis-deployment"
    }
  }
}

# ==============================================================================
# Redis Password Secret
# ==============================================================================

resource "random_password" "redis_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "redis_credentials" {
  metadata {
    name      = "redis-credentials"
    namespace = kubernetes_namespace.redis.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "redis"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "redis-password" = random_password.redis_password.result
  }
}

# Replicate credentials to other namespaces
resource "kubernetes_secret" "redis_credentials_replica" {
  for_each = toset(var.replica_namespaces)

  metadata {
    name      = "redis-credentials"
    namespace = each.value
    labels = {
      "app.kubernetes.io/name"       = "redis"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
    annotations = {
      "source-secret"    = "redis-credentials"
      "description"      = "Replicated Redis credentials from ${var.namespace} namespace"
      "managed-by"       = "opentofu"
      "replication-date" = timestamp()
    }
  }

  data = {
    "redis-password" = random_password.redis_password.result
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["replication-date"]
    ]
  }
}

# ==============================================================================
# Redis Helm Release (Groundhog2k)
# ==============================================================================

resource "helm_release" "redis" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = "redis"
  version    = var.chart_version
  namespace  = kubernetes_namespace.redis.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = var.helm_timeout
  atomic        = true

  values = [
    yamlencode({
      # Image configuration - Official Redis image
      image = {
        registry   = "docker.io"
        repository = "redis"
        tag        = var.redis_image_tag
      }

      # HA Mode with master-replica + Sentinel
      haMode = {
        enabled              = var.ha_enabled
        useDnsNames          = true
        masterGroupName      = var.release_name
        replicas             = var.ha_enabled ? var.replica_count : 1
        quorum               = var.ha_enabled ? max(1, floor(var.replica_count / 2)) : 1
        downAfterMilliseconds = 30000
        failoverTimeout      = 180000
      }

      # Use StatefulSet even in non-HA mode for data persistence
      useDeploymentWhenNonHA = false

      # Service configuration
      service = {
        type         = var.ha_enabled ? "ClusterIP" : var.service_type
        serverPort   = 6379
        sentinelPort = 26379
        annotations  = var.service_annotations
      }

      # Resource limits
      resources = {
        requests = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      # Storage configuration
      storage = {
        requestedSize = var.storage_size
        className     = var.storage_class
        accessModes   = ["ReadWriteOnce"]
        keepPvc       = true
      }

      # Redis configuration with authentication
      redisConfig = <<-EOT
        requirepass ${random_password.redis_password.result}
        masterauth ${random_password.redis_password.result}
        ${var.redis_config}
      EOT

      # Prometheus metrics
      metrics = {
        enabled = var.enable_metrics
        exporter = {
          image = {
            registry   = "docker.io"
            repository = "oliver006/redis_exporter"
            tag        = "v1.80.0"
          }
          securityContext = {
            allowPrivilegeEscalation = false
            privileged               = false
            readOnlyRootFilesystem   = true
            runAsNonRoot             = true
            runAsUser                = 999
            runAsGroup               = 999
          }
          env = [
            {
              name  = "REDIS_PASSWORD"
              value = random_password.redis_password.result
            }
          ]
        }
        serviceMonitor = {
          enabled          = var.enable_service_monitor
          additionalLabels = {
            release = "kube-prometheus-stack"
          }
        }
      }

      # Security context
      podSecurityContext = {
        fsGroup = 999
        supplementalGroups = [999]
      }

      securityContext = {
        allowPrivilegeEscalation = false
        privileged               = false
        readOnlyRootFilesystem   = true
        runAsNonRoot             = true
        runAsUser                = 999
        runAsGroup               = 999
      }

      # Pod labels
      podLabels = {
        "app.kubernetes.io/name"       = "redis"
        "app.kubernetes.io/instance"   = var.release_name
        "app.kubernetes.io/managed-by" = "opentofu"
        "feature"                      = "013-redis-deployment"
      }

      # Pod annotations for Prometheus scraping
      podAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = "9121"
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.redis,
    kubernetes_secret.redis_credentials
  ]
}

# ==============================================================================
# External LoadBalancer Service (MetalLB)
# ==============================================================================

resource "kubernetes_service" "redis_external" {
  count = var.loadbalancer_ip != "" ? 1 : 0

  metadata {
    name      = "${var.release_name}-external"
    namespace = kubernetes_namespace.redis.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "redis"
      "app.kubernetes.io/instance"   = var.release_name
      "app.kubernetes.io/managed-by" = "opentofu"
    }
    annotations = {
      # MetalLB 0.13+ uses metallb.io namespace (not metallb.universe.tf)
      "metallb.io/address-pool"     = var.metallb_ip_pool
      "metallb.io/loadBalancerIPs"  = var.loadbalancer_ip
      # Disable K3s ServiceLB for MetalLB-managed service
      "svccontroller.k3s.cattle.io/enablelb" = "false"
    }
  }

  spec {
    type                    = "LoadBalancer"
    # Note: Do NOT use load_balancer_ip here - MetalLB 0.15+ conflicts with annotation
    # IP is specified via metallb.universe.tf/loadBalancerIPs annotation only
    external_traffic_policy = "Local"

    selector = {
      "app.kubernetes.io/name"     = "redis"
      "app.kubernetes.io/instance" = var.release_name
    }

    port {
      name        = "redis"
      port        = 6379
      target_port = 6379
      protocol    = "TCP"
    }
  }

  depends_on = [helm_release.redis]
}
