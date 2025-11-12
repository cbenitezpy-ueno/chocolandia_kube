# Headlamp Web UI Module

OpenTofu module for deploying Headlamp Kubernetes dashboard with Traefik ingress, cert-manager TLS certificates, and Cloudflare Access authentication.

## Features

- **Web-based Dashboard**: Modern Kubernetes management UI
- **Read-Only RBAC**: ServiceAccount with ClusterRole "view" for safe cluster exploration
- **HTTPS Access**: Automatic TLS certificates via cert-manager (Let's Encrypt)
- **OAuth Authentication**: Cloudflare Access with Google OAuth integration
- **High Availability**: 2 replicas with pod anti-affinity
- **Prometheus Integration**: Metrics visualization within Headlamp UI

## Prerequisites

Before using this module, ensure the following are deployed:

- K3s cluster v1.28+ (Feature 001)
- Traefik v3.1.0 ingress controller (Feature 005)
- cert-manager v1.13.x (Feature 006)
- Cloudflare Zero Trust tunnel (Feature 004)
- Prometheus + Grafana monitoring stack

## Usage

### Basic Configuration

```hcl
module "headlamp" {
  source = "../../modules/headlamp"

  namespace         = "headlamp"
  domain            = "headlamp.chocolandiadc.com"
  replicas          = 2

  # Cloudflare Access authentication
  cloudflare_account_id   = var.cloudflare_account_id
  google_oauth_idp_id     = var.google_oauth_idp_id
  authorized_emails       = ["admin@example.com"]

  # cert-manager certificate
  cluster_issuer          = "letsencrypt-production"

  # Prometheus integration (optional)
  prometheus_url          = "http://prometheus-kube-prometheus-prometheus.monitoring:9090"
}
```

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `namespace` | string | Kubernetes namespace for Headlamp deployment |
| `domain` | string | Domain name for Headlamp (e.g., headlamp.example.com) |
| `cloudflare_account_id` | string | Cloudflare account ID for Access configuration |
| `google_oauth_idp_id` | string | Google OAuth identity provider ID |
| `authorized_emails` | list(string) | List of authorized email addresses for Cloudflare Access |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `replicas` | number | 2 | Number of Headlamp pod replicas |
| `cluster_issuer` | string | "letsencrypt-production" | cert-manager ClusterIssuer name |
| `prometheus_url` | string | "" | Prometheus server URL for metrics integration |

## Outputs

| Output | Description |
|--------|-------------|
| `namespace` | Kubernetes namespace where Headlamp is deployed |
| `service_name` | Headlamp service name |
| `ingress_hostname` | Headlamp ingress hostname (HTTPS URL) |
| `certificate_secret` | TLS certificate secret name |
| `serviceaccount_token_secret` | ServiceAccount token secret name |
| `cloudflare_access_application_id` | Cloudflare Access application ID |

## Authentication

Headlamp uses **two-factor authentication**:

1. **First layer**: Cloudflare Access with Google OAuth (identity verification)
2. **Second layer**: Kubernetes ServiceAccount token (authorization)

### Obtaining ServiceAccount Token

```bash
kubectl get secret headlamp-admin-token -n headlamp \
  -o jsonpath='{.data.token}' | base64 -d
```

Save this token securely (password manager). You'll need it for Headlamp UI login.

## RBAC Permissions

The Headlamp ServiceAccount (`headlamp-admin`) is bound to the **ClusterRole "view"**, providing:

✅ **Allowed Operations**:
- View pods, deployments, services, configmaps
- View custom resources (IngressRoutes, Certificates, etc.)
- Stream logs from pods
- View resource metrics (CPU, memory)

❌ **Blocked Operations**:
- View secrets (security)
- Create, update, or delete any resources
- Exec into pods
- Port-forward to pods

This read-only access ensures safe cluster exploration without risk of destructive operations.

## Accessing Headlamp

1. **Open browser**: https://headlamp.chocolandiadc.com
2. **Cloudflare Access**: Click "Sign in with Google", authenticate with authorized email
3. **Headlamp Login**: Select "Token" authentication, paste ServiceAccount token
4. **Dashboard**: Explore cluster resources (pods, services, deployments, etc.)

## Monitoring

Headlamp integrates with Prometheus to display metrics charts within the UI:

- **Pod metrics**: CPU and memory usage graphs
- **Deployment metrics**: Replica status and resource consumption
- **Cluster overview**: Aggregated metrics across namespaces

Note: Headlamp is a **metrics consumer**, not exporter. It does not expose a `/metrics` endpoint. For monitoring Headlamp pods themselves, use `kube-state-metrics`.

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues:

- Certificate not ready
- Cloudflare Access denies login
- Pods not running
- IngressRoute not working
- Token authentication fails

## Security Considerations

See [SECURITY.md](./SECURITY.md) for security best practices:

- ServiceAccount token management
- RBAC permissions scope
- Cloudflare Access configuration
- Network policies (optional)

## Module Structure

```
terraform/modules/headlamp/
├── main.tf              # Namespace, Helm release
├── rbac.tf              # ServiceAccount, ClusterRoleBinding, Secret
├── ingress.tf           # IngressRoute, Certificate, Middleware
├── cloudflare.tf        # Access Application, Policy
├── monitoring.tf        # Prometheus integration (Helm values)
├── variables.tf         # Module inputs
├── outputs.tf           # Module outputs
├── versions.tf          # Provider requirements
├── README.md            # This file
├── TROUBLESHOOTING.md   # Common issues and solutions
└── SECURITY.md          # Security documentation
```

## Related Documentation

- [Feature Specification](../../../specs/007-headlamp-web-ui/spec.md)
- [Implementation Plan](../../../specs/007-headlamp-web-ui/plan.md)
- [Quickstart Guide](../../../specs/007-headlamp-web-ui/quickstart.md)
- [Headlamp Official Docs](https://headlamp.dev/docs/)

## License

Part of the chocolandia_kube homelab infrastructure project.
