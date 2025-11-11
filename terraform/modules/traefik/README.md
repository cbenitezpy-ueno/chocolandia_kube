# Traefik Ingress Controller Module

Terraform module for deploying Traefik v3.x ingress controller to K3s cluster using Helm chart.

## Features

- **HA Configuration**: 2 replicas with PodDisruptionBudget
- **MetalLB Integration**: LoadBalancer service with static IP (192.168.4.201)
- **Prometheus Metrics**: /metrics endpoint enabled for observability
- **Dashboard**: Built-in dashboard for operational visibility
- **Health Checks**: Liveness and readiness probes configured
- **Resource Limits**: CPU/memory requests and limits enforced
- **Security**: Non-root user, read-only root filesystem, capability dropping

## Prerequisites

- K3s cluster running (Feature 002)
- MetalLB deployed with IP pool configured (Feature 002)
- kubectl access to cluster
- Helm v3 installed
- OpenTofu 1.6+

## Usage

```hcl
module "traefik" {
  source = "../../modules/traefik"

  release_name   = "traefik"
  chart_version  = "30.0.2"  # Traefik v3.2.0
  namespace      = "traefik"
  replicas       = 2
  loadbalancer_ip = "192.168.4.201"

  resources_requests_cpu    = "100m"
  resources_requests_memory = "128Mi"
  resources_limits_cpu      = "500m"
  resources_limits_memory   = "256Mi"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| release_name | Helm release name | string | "traefik" | no |
| chart_version | Traefik Helm chart version | string | "30.0.2" | no |
| namespace | Kubernetes namespace | string | "traefik" | no |
| replicas | Number of replicas for HA | number | 2 | no |
| loadbalancer_ip | Static LoadBalancer IP | string | "192.168.4.201" | no |
| resources_requests_cpu | CPU request | string | "100m" | no |
| resources_requests_memory | Memory request | string | "128Mi" | no |
| resources_limits_cpu | CPU limit | string | "500m" | no |
| resources_limits_memory | Memory limit | string | "256Mi" | no |

## Outputs

| Name | Description |
|------|-------------|
| release_name | Helm release name |
| namespace | Kubernetes namespace |
| chart_version | Deployed chart version |
| status | Helm release status |
| loadbalancer_ip | LoadBalancer IP |
| replicas | Number of replicas |

## Validation

After deployment, verify Traefik is running:

```bash
# Check pods
kubectl get pods -n traefik

# Check service and LoadBalancer IP
kubectl get svc -n traefik traefik

# Check CRDs installed
kubectl get crd | grep traefik

# Test HTTP connectivity
curl http://192.168.4.201  # Should return 404 (no routes configured yet)
```

## Dashboard Access

Dashboard is accessible via port-forward:

```bash
kubectl port-forward -n traefik svc/traefik 9000:9000
# Open http://localhost:9000/dashboard/
```

Or via IngressRoute (see manifests/traefik/dashboard-ingressroute.yaml).

## Next Steps

1. Create IngressRoute resources for services (US2)
2. Configure TLS with certificates (US4)
3. Enable Prometheus monitoring (US5)

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Helm Chart](https://github.com/traefik/traefik-helm-chart)
- [IngressRoute CRD](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
