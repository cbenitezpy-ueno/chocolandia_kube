# Paperless-ngx Module

OpenTofu module for deploying Paperless-ngx document management system on Kubernetes.

## Features

- Paperless-ngx deployment with PostgreSQL and Redis integration
- Samba sidecar for scanner integration (SMB share)
- Local (.local) and public (Cloudflare) ingress support
- Prometheus metrics and ServiceMonitor for Grafana monitoring
- OCR processing with multi-language support (Spanish + English)

## Usage

```hcl
module "paperless_ngx" {
  source = "../../modules/paperless-ngx"

  namespace = "paperless"

  # Database
  db_host     = "192.168.4.204"
  db_name     = "paperless"
  db_user     = "paperless"
  db_password = random_password.paperless_db.result

  # Redis
  redis_url = "redis://192.168.4.203:6379"

  # Application
  secret_key     = random_password.paperless_secret_key.result
  admin_user     = "admin"
  admin_password = random_password.paperless_admin.result
  admin_email    = "admin@example.com"
  ocr_language   = "spa+eng"
  timezone       = "America/Asuncion"

  # Ingress
  public_host = "paperless.chocolandiadc.com"
  local_host  = "paperless.chocolandiadc.local"

  # Samba (for scanner)
  samba_user     = "scanner"
  samba_password = random_password.samba_password.result

  # Storage (50GB total)
  data_storage_size    = "5Gi"
  media_storage_size   = "40Gi"
  consume_storage_size = "5Gi"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| namespace | Kubernetes namespace | string | "paperless" |
| app_name | Application name for labels | string | "paperless-ngx" |
| image | Paperless-ngx container image | string | "ghcr.io/paperless-ngx/paperless-ngx:2.14.7" |
| samba_image | Samba sidecar container image | string | "dperson/samba:latest" |
| db_host | PostgreSQL host address | string | - |
| db_port | PostgreSQL port | number | 5432 |
| db_name | PostgreSQL database name | string | "paperless" |
| db_user | PostgreSQL username | string | "paperless" |
| db_password | PostgreSQL password | string | - |
| redis_url | Redis connection URL | string | "redis://192.168.4.203:6379" |
| storage_class | Kubernetes StorageClass | string | "local-path" |
| data_storage_size | Size of data PVC | string | "5Gi" |
| media_storage_size | Size of media PVC | string | "40Gi" |
| consume_storage_size | Size of consume PVC | string | "5Gi" |
| secret_key | Django secret key | string | - |
| admin_user | Initial admin username | string | "admin" |
| admin_password | Initial admin password | string | - |
| ocr_language | OCR language(s) | string | "spa+eng" |
| timezone | Application timezone | string | "America/Asuncion" |
| public_host | Public hostname (Cloudflare) | string | "paperless.chocolandiadc.com" |
| local_host | Local hostname (LAN) | string | "paperless.chocolandiadc.local" |
| samba_user | Samba share username | string | "scanner" |
| samba_password | Samba share password | string | - |
| enable_metrics | Enable Prometheus metrics | bool | true |
| create_service_monitor | Create ServiceMonitor | bool | true |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Kubernetes namespace |
| service_name | Kubernetes service name |
| service_port | Service port |
| internal_url | Internal cluster URL |
| public_url | Public URL (Cloudflare) |
| local_url | Local LAN URL |
| samba_service_name | Samba LoadBalancer service name |
| consume_pvc_name | Consume folder PVC name |

## Scanner Configuration

After deployment, configure your network scanner with:

| Setting | Value |
|---------|-------|
| Protocol | SMB/CIFS |
| Server | LoadBalancer IP (from `kubectl get svc samba-smb -n paperless`) |
| Share | consume |
| Username | scanner |
| Password | (from Terraform output) |

## Requirements

- Kubernetes 1.28+
- cert-manager with local-ca issuer
- Traefik ingress controller
- PostgreSQL cluster (192.168.4.204)
- Redis instance (192.168.4.203)
- MetalLB for LoadBalancer services

## Related Features

- 004-cloudflare-zerotrust: Internet access via tunnel
- 006-cert-manager: TLS certificates
- 011-postgresql-cluster: Database backend
- 013-redis-deployment: Redis backend
- 014-monitoring-alerts: Prometheus monitoring
