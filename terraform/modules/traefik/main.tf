# Traefik Ingress Controller Module
# Feature 005: Traefik Ingress Controller
# Deploys Traefik v3.x via Helm chart with HA configuration

resource "helm_release" "traefik" {
  name       = var.release_name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.chart_version
  namespace  = var.namespace

  values = [
    file("${path.module}/values.yaml")
  ]

  # Override values with variables
  set {
    name  = "deployment.replicas"
    value = var.replicas
  }

  set {
    name  = "service.annotations.metallb\\.universe\\.tf/loadBalancerIPs"
    value = var.loadbalancer_ip
  }

  set {
    name  = "resources.requests.cpu"
    value = var.resources_requests_cpu
  }

  set {
    name  = "resources.requests.memory"
    value = var.resources_requests_memory
  }

  set {
    name  = "resources.limits.cpu"
    value = var.resources_limits_cpu
  }

  set {
    name  = "resources.limits.memory"
    value = var.resources_limits_memory
  }

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 300 # 5 minutes

  # Create namespace if it doesn't exist
  create_namespace = true

  # Enable atomic to rollback on failure
  atomic = true

  # Enable cleanup on failure
  cleanup_on_fail = true
}
