# Cloudflare Zero Trust Tunnel Module

Terraform module for deploying Cloudflare Zero Trust Tunnel (cloudflared) on Kubernetes with integrated Google OAuth access control.

## Features

- **Zero Public Ports**: Securely expose internal services without opening firewall ports
- **Cloudflare Access Integration**: Google OAuth 2.0 authentication for all protected services
- **High Availability**: Support for multiple replicas with PodDisruptionBudget
- **Automated DNS**: Automatic CNAME record creation for exposed services
- **Kubernetes Native**: Deployment with health probes, resource limits, and proper security contexts
- **Prometheus Metrics**: Built-in metrics endpoint for monitoring

## Architecture

```
Internet
   ↓
Cloudflare Edge (Zero Trust)
   ↓
Google OAuth Authentication
   ↓
Cloudflare Tunnel (cloudflared pods in K8s)
   ↓
Internal K8s Services (Pi-hole, Grafana, etc.)
```

## Prerequisites

- Kubernetes cluster (K3s, EKS, GKE, etc.)
- Cloudflare account with:
  - Domain managed by Cloudflare
  - Account ID and Zone ID
  - API token with required permissions:
    - Account: Cloudflare Tunnel (Edit)
    - Account: Access: Apps and Policies (Edit)
    - Account: Access: Organizations, Identity Providers, and Groups (Edit)
    - Zone: DNS (Edit)
    - Zone: Zone Settings (Read)
- Google OAuth 2.0 credentials:
  - Client ID and Client Secret
  - Authorized redirect URI: `https://<team-name>.cloudflareaccess.com/cdn-cgi/access/callback`

## Usage

```hcl
module "cloudflare_tunnel" {
  source = "../../modules/cloudflare-tunnel"

  # Cloudflare Configuration
  tunnel_name           = "homelab-tunnel"
  cloudflare_account_id = "abc123..."
  cloudflare_zone_id    = "def456..."
  domain_name           = "example.com"

  # Kubernetes Configuration
  namespace     = "cloudflare-tunnel"
  replica_count = 2  # Set to 2+ for HA

  # Ingress Rules (public hostname → internal service)
  ingress_rules = [
    {
      hostname = "pihole.example.com"
      service  = "http://pihole-web.pihole.svc.cluster.local:80"
    },
    {
      hostname = "grafana.example.com"
      service  = "http://grafana.monitoring.svc.cluster.local:3000"
    }
  ]

  # Access Control (Google OAuth)
  google_oauth_client_id     = "123456-xxx.apps.googleusercontent.com"
  google_oauth_client_secret = var.google_oauth_client_secret  # Keep secret!
  authorized_emails          = [
    "admin@example.com",
    "user@example.com"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tunnel_name | Human-readable name for the Cloudflare Tunnel | `string` | n/a | yes |
| cloudflare_account_id | Cloudflare Account ID (32-char hex) | `string` | n/a | yes |
| cloudflare_zone_id | Cloudflare Zone ID for DNS records (32-char hex) | `string` | n/a | yes |
| domain_name | Cloudflare-managed domain (e.g., example.com) | `string` | n/a | yes |
| namespace | Kubernetes namespace for deployment | `string` | `"cloudflare-tunnel"` | no |
| replica_count | Number of cloudflared replicas (1-10) | `number` | `1` | no |
| cloudflared_image | Cloudflared Docker image | `string` | `"cloudflare/cloudflared:latest"` | no |
| resource_limits_cpu | CPU limit for pods | `string` | `"500m"` | no |
| resource_limits_memory | Memory limit for pods | `string` | `"200Mi"` | no |
| resource_requests_cpu | CPU request for pods | `string` | `"100m"` | no |
| resource_requests_memory | Memory request for pods | `string` | `"100Mi"` | no |
| ingress_rules | List of ingress rules (hostname + service URL) | `list(object)` | n/a | yes |
| google_oauth_client_id | Google OAuth Client ID | `string` | n/a | yes |
| google_oauth_client_secret | Google OAuth Client Secret (sensitive) | `string` | n/a | yes |
| authorized_emails | List of authorized email addresses | `list(string)` | n/a | yes |
| access_policy_name | Name for Cloudflare Access policy | `string` | `"Email Authorization Policy"` | no |

## Outputs

| Name | Description |
|------|-------------|
| tunnel_id | Cloudflare Tunnel ID |
| tunnel_cname | Tunnel CNAME target for DNS records |
| tunnel_name | Cloudflare Tunnel name |
| tunnel_token | Tunnel token (sensitive, base64-encoded) |
| namespace | Kubernetes namespace |
| deployment_name | Cloudflared deployment name |
| secret_name | Kubernetes secret name for credentials |
| dns_records | Map of DNS CNAME records created |
| ingress_hostnames | List of public hostnames exposed |
| access_identity_provider_id | Google OAuth identity provider ID |
| access_application_ids | Map of Cloudflare Access application IDs |
| access_policy_ids | Map of Cloudflare Access policy IDs |
| service_urls | Map of service URLs (service_name → https://hostname) |

## Examples

### Basic Setup (Single Replica)

```hcl
module "cloudflare_tunnel" {
  source = "./modules/cloudflare-tunnel"

  tunnel_name           = "my-tunnel"
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
  domain_name           = "mydomain.com"

  ingress_rules = [
    {
      hostname = "app.mydomain.com"
      service  = "http://my-app.default.svc.cluster.local:8080"
    }
  ]

  google_oauth_client_id     = var.google_oauth_client_id
  google_oauth_client_secret = var.google_oauth_client_secret
  authorized_emails          = ["admin@mydomain.com"]
}
```

### High Availability Setup

```hcl
module "cloudflare_tunnel" {
  source = "./modules/cloudflare-tunnel"

  # ... basic config ...

  replica_count = 2  # HA with 2 replicas

  # PodDisruptionBudget is automatically created with minAvailable=1
}
```

### Multiple Services

```hcl
module "cloudflare_tunnel" {
  source = "./modules/cloudflare-tunnel"

  # ... basic config ...

  ingress_rules = [
    {
      hostname = "dashboard.example.com"
      service  = "http://dashboard.monitoring.svc.cluster.local:3000"
    },
    {
      hostname = "api.example.com"
      service  = "http://api.backend.svc.cluster.local:8080"
    },
    {
      hostname = "admin.example.com"
      service  = "http://admin.admin.svc.cluster.local:80"
    }
  ]

  authorized_emails = [
    "admin@example.com",
    "developer@example.com",
    "ops@example.com"
  ]
}
```

## How It Works

1. **Tunnel Creation**: Creates a Cloudflare Tunnel with secure credentials
2. **Kubernetes Deployment**: Deploys cloudflared pods with proper security context
3. **DNS Automation**: Creates CNAME records pointing to the tunnel
4. **Access Control**: Sets up Google OAuth identity provider and access policies
5. **Traffic Flow**:
   - User requests `https://app.example.com`
   - Cloudflare Edge receives request
   - Google OAuth authentication (if not logged in)
   - Email authorization check
   - Tunnel routes traffic to internal K8s service
   - Response flows back through tunnel

## High Availability

When `replica_count > 1`:
- Multiple cloudflared pods run across different nodes
- PodDisruptionBudget ensures at least 1 pod remains during voluntary disruptions
- Cloudflare automatically routes traffic across all healthy replicas
- Zero-downtime updates and node maintenance

## Monitoring

Prometheus metrics are exposed on port 2000 (`/metrics`) with annotations:
- `prometheus.io/scrape: "true"`
- `prometheus.io/port: "2000"`
- `prometheus.io/path: "/metrics"`

## Security

- **No Public Ports**: All traffic flows through Cloudflare tunnel
- **OAuth Authentication**: Google OAuth 2.0 with email-based authorization
- **Secure Credentials**: Tunnel credentials stored as Kubernetes Secret
- **Pod Security**: Non-root user (UID 65532), read-only root filesystem, dropped capabilities
- **Network Security**: DNS configured to prevent loops during image pull

## Troubleshooting

See [TROUBLESHOOTING.md](../../../docs/004-cloudflare-tunnel/TROUBLESHOOTING.md) for common issues and solutions.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| cloudflare | ~> 4.0 |
| kubernetes | ~> 2.23 |
| random | ~> 3.5 |

## Resources Created

- **Cloudflare**:
  - `cloudflare_zero_trust_tunnel_cloudflared`: Tunnel resource
  - `cloudflare_zero_trust_tunnel_cloudflared_config`: Tunnel configuration
  - `cloudflare_record`: DNS CNAME records (one per ingress rule)
  - `cloudflare_zero_trust_access_identity_provider`: Google OAuth provider
  - `cloudflare_zero_trust_access_application`: Access applications (one per service)
  - `cloudflare_zero_trust_access_policy`: Authorization policies (one per service)

- **Kubernetes**:
  - `kubernetes_namespace`: Dedicated namespace
  - `kubernetes_secret`: Tunnel credentials
  - `kubernetes_deployment`: Cloudflared pods
  - `kubernetes_pod_disruption_budget_v1`: HA protection (when replica_count > 1)

- **Other**:
  - `random_password`: Tunnel secret generation

## License

This module is part of the ChocolandiaDC homelab project.

## Authors

- Cristhian Benitez
