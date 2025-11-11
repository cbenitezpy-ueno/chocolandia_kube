# cert-manager Terraform Module

Deploys cert-manager to automate SSL/TLS certificate management with Let's Encrypt.

## Features

- Automated certificate issuance and renewal via Let's Encrypt
- Staging and production ClusterIssuers for ACME protocol
- HTTP-01 challenge validation via Traefik ingress controller
- Prometheus metrics integration for certificate monitoring
- Kubernetes Secrets for secure certificate storage
- Automatic renewal at 60 days (2/3 of 90-day certificate lifetime)

## Prerequisites

- Kubernetes cluster (K3s v1.28+)
- Traefik ingress controller v3.1.0+ (Feature 005)
- Cloudflare Tunnel providing external connectivity on port 80 (Feature 004)
- Domain with public DNS records pointing to cluster

## Usage

```hcl
module "cert_manager" {
  source = "../../modules/cert-manager"

  namespace         = "cert-manager"
  chart_version     = "v1.13.3"
  acme_email        = "admin@chocolandiadc.com"
  enable_staging    = true
  enable_production = true
  enable_metrics    = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| namespace | Kubernetes namespace for cert-manager | string | "cert-manager" | no |
| chart_version | cert-manager Helm chart version | string | "v1.13.3" | no |
| acme_email | Email for Let's Encrypt account notifications | string | n/a | yes |
| enable_staging | Create staging ClusterIssuer | bool | true | no |
| enable_production | Create production ClusterIssuer | bool | true | no |
| enable_metrics | Enable Prometheus metrics | bool | true | no |
| controller_replicas | Number of controller replicas | number | 1 | no |
| webhook_replicas | Number of webhook replicas | number | 1 | no |
| cainjector_replicas | Number of cainjector replicas | number | 1 | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | cert-manager namespace |
| chart_version | Deployed Helm chart version |
| staging_issuer_name | Staging ClusterIssuer name |
| production_issuer_name | Production ClusterIssuer name |
| metrics_port | Prometheus metrics port |

## Certificate Request Example

After deploying this module, request a certificate by creating a Certificate resource:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
  namespace: default
spec:
  secretName: example-tls-secret
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  dnsNames:
    - example.chocolandiadc.com
```

## Traefik IngressRoute Integration

For automatic certificate provisioning via Traefik annotations:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: example-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`example.chocolandiadc.com`)
      kind: Rule
      services:
        - name: example-service
          port: 80
  tls:
    secretName: example-tls-secret
```

## Resource Limits

Conservative resource limits suitable for homelab environments:

- **Controller**: 10m CPU / 32Mi memory (requests), 100m CPU / 128Mi memory (limits)
- **Webhook**: 10m CPU / 32Mi memory (requests), 100m CPU / 128Mi memory (limits)
- **CAInjector**: 10m CPU / 32Mi memory (requests), 100m CPU / 128Mi memory (limits)

## Monitoring

Prometheus metrics are exposed on port 9402 for all components. Key metrics:

- `certmanager_certificate_expiration_timestamp_seconds`: Certificate expiry time
- `certmanager_certificate_ready_status`: Certificate readiness (0=not ready, 1=ready)
- `certmanager_http_acme_client_request_count`: ACME API request count
- `certmanager_http_acme_client_request_duration_seconds`: ACME API latency

## Rate Limits

Let's Encrypt rate limits:

- **Staging**: 30,000 registrations per IP/3hr (no certificate limit)
- **Production**: 50 certificates/week per domain, 300 pending authorizations per account

**Best Practice**: Always test with staging issuer first before requesting production certificates.

## Troubleshooting

### Certificate stuck in "Pending" state

Check cert-manager logs:
```bash
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

Verify ACME challenge status:
```bash
kubectl get challenge -A
kubectl describe challenge <challenge-name> -n <namespace>
```

### HTTP-01 challenge failures

Verify port 80 is accessible from internet:
```bash
curl -I http://chocolandiadc.com
```

Check Traefik is routing challenge requests:
```bash
kubectl get svc -n traefik traefik
```

### Rate limit errors

If production rate limit hit, use staging issuer:
```bash
kubectl annotate certificate <cert-name> cert-manager.io/cluster-issuer=letsencrypt-staging --overwrite
```

## Dependencies

- **Feature 001/002**: K3s cluster
- **Feature 004**: Cloudflare Tunnel (external connectivity)
- **Feature 005**: Traefik ingress controller (HTTP-01 challenge routing)

## Architecture

```
┌─────────────────┐
│  Let's Encrypt  │
│   ACME Server   │
└────────┬────────┘
         │ ACME Protocol
         ↓
┌─────────────────────────────────┐
│      cert-manager Pods          │
│  ┌───────────┬────────┬──────┐  │
│  │Controller │Webhook │CAInj.│  │
│  └───────────┴────────┴──────┘  │
└────────┬────────────────────────┘
         │ Creates
         ↓
┌─────────────────────────────────┐
│   Solver Pod (HTTP-01)          │
│   Serves: /.well-known/         │
│           acme-challenge/       │
└────────┬────────────────────────┘
         │ Routed by
         ↓
┌─────────────────────────────────┐
│   Traefik Ingress Controller    │
│   Port 80 (HTTP)                │
└────────┬────────────────────────┘
         │ Via Cloudflare Tunnel
         ↓
┌─────────────────────────────────┐
│   Let's Encrypt Validation      │
│   Servers (Internet)            │
└─────────────────────────────────┘
```

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [ACME Protocol](https://datatracker.ietf.org/doc/html/rfc8555)
- [Feature Specification](../../../specs/006-cert-manager/spec.md)
- [Quickstart Guide](../../../specs/006-cert-manager/quickstart.md)
