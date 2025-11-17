# ============================================================================
# Netdata Hardware Monitoring Module
# Real-time performance and hardware monitoring with web UI
# ============================================================================

# ============================================================================
# Namespace
# ============================================================================

resource "kubernetes_namespace" "netdata" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "netdata"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ============================================================================
# Netdata Helm Chart
# ============================================================================

resource "helm_release" "netdata" {
  name       = "netdata"
  repository = "https://netdata.github.io/helmchart/"
  chart      = "netdata"
  version    = var.chart_version
  namespace  = kubernetes_namespace.netdata.metadata[0].name

  # Parent node configuration
  set {
    name  = "parent.enabled"
    value = "true"
  }

  set {
    name  = "parent.port"
    value = "19999"
  }

  set {
    name  = "parent.resources.requests.cpu"
    value = var.parent_cpu_request
  }

  set {
    name  = "parent.resources.requests.memory"
    value = var.parent_memory_request
  }

  set {
    name  = "parent.resources.limits.cpu"
    value = var.parent_cpu_limit
  }

  set {
    name  = "parent.resources.limits.memory"
    value = var.parent_memory_limit
  }

  # Child nodes (DaemonSet on each node for hardware monitoring)
  set {
    name  = "child.enabled"
    value = "true"
  }

  set {
    name  = "child.port"
    value = "19999"
  }

  set {
    name  = "child.resources.requests.cpu"
    value = var.child_cpu_request
  }

  set {
    name  = "child.resources.requests.memory"
    value = var.child_memory_request
  }

  set {
    name  = "child.resources.limits.cpu"
    value = var.child_cpu_limit
  }

  set {
    name  = "child.resources.limits.memory"
    value = var.child_memory_limit
  }

  # Access host PID namespace for full hardware visibility
  set {
    name  = "child.hostPID"
    value = "true"
  }

  # Access host network for accurate network stats
  set {
    name  = "child.hostNetwork"
    value = "false" # Keep false for K3s compatibility
  }

  # Mount /proc, /sys for hardware sensors
  set {
    name  = "child.hostMounts.proc.enabled"
    value = "true"
  }

  set {
    name  = "child.hostMounts.sys.enabled"
    value = "true"
  }

  # Service configuration
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "service.port"
    value = "19999"
  }

  # Disable built-in ingress (we'll use Traefik IngressRoute)
  set {
    name  = "ingress.enabled"
    value = "false"
  }

  # Enable persistence for historical data
  set {
    name  = "parent.database.persistence"
    value = "true"
  }

  set {
    name  = "parent.database.storageclass"
    value = var.storage_class_name
  }

  set {
    name  = "parent.database.volumesize"
    value = var.storage_size
  }

  # Alarms configuration (optional)
  set {
    name  = "parent.alarms.enabled"
    value = "true"
  }

  # Prometheus export (integrates with existing monitoring)
  set {
    name  = "k8sState.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.netdata]
}

# ============================================================================
# Service (for Traefik IngressRoute)
# ============================================================================

# The Helm chart creates the service, but we reference it for the IngressRoute
data "kubernetes_service" "netdata_parent" {
  metadata {
    name      = "netdata"
    namespace = kubernetes_namespace.netdata.metadata[0].name
  }

  depends_on = [helm_release.netdata]
}
