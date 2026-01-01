# Research: Paperless-ngx Document Management

**Feature**: 027-paperless-ngx
**Date**: 2026-01-01
**Status**: Complete

## Research Tasks

### 1. Paperless-ngx Deployment Method

**Decision**: Use gabe565 Helm chart via OpenTofu Helm provider

**Rationale**:
- Well-maintained chart with recent updates (2025-02-20)
- Automatic configuration of PostgreSQL and Redis connection strings
- Supports all required persistence volumes (consume, media, data, export)
- Follows bjw-s common library patterns
- Can disable bundled PostgreSQL/Redis to use existing cluster services

**Alternatives Considered**:
- **CrystalNET Helm chart**: Good but includes FTP functionality we don't need
- **Raw Kubernetes manifests via OpenTofu**: More control but more maintenance
- **Docker Compose on node**: Against Constitution (must be Kubernetes-native)

**Sources**:
- [gabe565 Helm Charts - Paperless-ngx](https://charts.gabe565.com/charts/paperless-ngx/)
- [Paperless-ngx Official Docs](https://docs.paperless-ngx.com/)

---

### 2. Samba Server for Scanner Integration

**Decision**: Use dperson/samba container with simple Kubernetes Deployment

**Rationale**:
- Lightweight, well-documented container image
- Simple configuration via environment variables
- No need for complex operator (samba-operator is minimally maintained)
- Can mount same PVC as Paperless-ngx consume folder
- Exposes port 445 for SMB access

**Alternatives Considered**:
- **samba-operator**: Minimally maintained, overkill for single share
- **samba-in-kubernetes container**: Good but more complex configuration
- **NFS instead of SMB**: Less compatible with network scanners

**Implementation Notes**:
- Deploy in same namespace as Paperless-ngx
- Share Paperless consume PVC between Samba and Paperless pods
- Use LoadBalancer service type for direct LAN access on port 445
- Configure with single user for scanner authentication

**Sources**:
- [dperson/samba Docker Hub](https://hub.docker.com/r/dperson/samba)
- [Samba-in-Kubernetes Project](https://github.com/samba-in-kubernetes/samba-container)

---

### 3. PostgreSQL Integration

**Decision**: Create new database `paperless` using existing postgresql-database module

**Rationale**:
- Existing PostgreSQL cluster at 192.168.4.204 has capacity
- postgresql-database module already handles user/database creation
- Paperless-ngx requires PostgreSQL >= 13 (cluster has compatible version)
- Consistent with other applications (beersystem, etc.)

**Configuration**:
```hcl
module "paperless_database" {
  source      = "../modules/postgresql-database"
  db_name     = "paperless"
  db_user     = "paperless"
  db_password = random_password.paperless_db.result
}
```

**Environment Variables for Paperless**:
- `PAPERLESS_DBENGINE=postgresql`
- `PAPERLESS_DBHOST=192.168.4.204`
- `PAPERLESS_DBPORT=5432`
- `PAPERLESS_DBNAME=paperless`
- `PAPERLESS_DBUSER=paperless`
- `PAPERLESS_DBPASS=<from secret>`

---

### 4. Redis Integration

**Decision**: Use existing Redis instance at 192.168.4.203

**Rationale**:
- Redis is required for Paperless-ngx task queue (Celery)
- Existing shared Redis has sufficient capacity
- Consistent with other applications using shared Redis

**Configuration**:
- `PAPERLESS_REDIS=redis://192.168.4.203:6379`

**Note**: Consider using a dedicated Redis database number (e.g., db 1) to avoid key collisions with other applications.

---

### 5. Storage Architecture

**Decision**: Three PersistentVolumeClaims via local-path-provisioner

**Rationale**:
- 50GB total allocated per clarification
- Separate volumes for better organization and potential backup strategies
- local-path-provisioner is the cluster standard

**Volume Layout**:
| Volume | Size | Purpose | Access Mode |
|--------|------|---------|-------------|
| paperless-data | 5Gi | Application data, search index | ReadWriteOnce |
| paperless-media | 40Gi | Original + archived documents | ReadWriteOnce |
| paperless-consume | 5Gi | Incoming documents (shared with Samba) | ReadWriteMany* |

*Note: local-path-provisioner doesn't support RWX. Solution: Use single pod affinity or deploy Samba as sidecar container.

**Revised Approach**: Deploy Samba as sidecar container in Paperless pod to share consume volume without RWX requirement.

---

### 6. Ingress Architecture

**Decision**: Dual ingress - Cloudflare tunnel (internet) + Traefik IngressRoute (LAN)

**Internet Access (paperless.chocolandiadc.com)**:
- Add ingress rule to existing Cloudflare tunnel module
- Service points to `http://paperless-ngx.paperless.svc.cluster.local:8000`
- Protected by Cloudflare Access (Google OAuth)

**LAN Access (paperless.chocolandiadc.local)**:
- Traefik IngressRoute with TLS (local-ca issuer)
- Accessible from LAN without Cloudflare proxy
- Required for scanner integration (scanner may not support Cloudflare Access)

**Configuration Pattern** (following existing modules):
```hcl
# In cloudflare.tf
resource "cloudflare_record" "paperless" {
  # Add to tunnel ingress rules
}

# In ingress.tf
resource "kubernetes_manifest" "paperless_ingressroute" {
  # Traefik IngressRoute for .local domain
}
```

---

### 7. Monitoring Integration

**Decision**: Enable Paperless-ngx Prometheus metrics + ServiceMonitor

**Rationale**:
- Paperless-ngx exposes metrics via django-prometheus
- Existing kube-prometheus-stack will scrape via ServiceMonitor
- Grafana dashboard for document processing metrics

**Configuration**:
- `PAPERLESS_ENABLE_METRICS=true`
- ServiceMonitor targeting port 8000, path /metrics
- Dashboard JSON imported to Grafana ConfigMap

**Metrics Available**:
- Document count, processing queue length
- OCR processing time, success/failure rates
- HTTP request metrics (django-prometheus)

---

### 8. Security Considerations

**Decision**: Follow existing security patterns

**Credentials Management**:
- PostgreSQL password: Kubernetes Secret (generated by OpenTofu)
- Paperless secret key: Kubernetes Secret (random 50-char string)
- Samba credentials: Kubernetes Secret
- Admin user: Created via initial setup or environment variable

**Network Security**:
- Internet: Cloudflare Access with Google OAuth (email whitelist)
- LAN: Traefik + TLS (self-signed via local-ca)
- Samba: LAN-only, LoadBalancer with no external routing

**Environment Variables Security**:
```hcl
env_from {
  secret_ref {
    name = kubernetes_secret.paperless_credentials.metadata[0].name
  }
}
```

---

### 9. OCR Language Support

**Decision**: Configure Spanish + English OCR

**Rationale**:
- User is Spanish-speaking (based on conversation)
- English for international documents
- Tesseract supports both languages natively

**Configuration**:
- `PAPERLESS_OCR_LANGUAGE=spa+eng`
- `PAPERLESS_OCR_MODE=skip` (only OCR if needed, preserve existing text)

---

### 10. Resource Requirements

**Decision**: Conservative resource allocation

**Rationale**:
- OCR is CPU-intensive but can be throttled
- Memory needed for document parsing
- Homelab cluster has limited resources

**Resource Allocation**:
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "2000m"  # Allow burst for OCR
```

**Samba Resources**:
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

---

## Architecture Diagram

```
                                    Internet
                                        │
                                        ▼
                              ┌─────────────────┐
                              │   Cloudflare    │
                              │  Zero Trust     │
                              │  (OAuth Auth)   │
                              └────────┬────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                      │
                    ▼                                      │
        ┌───────────────────┐                             │
        │  paperless.       │                             │
        │  chocolandiadc.   │                             │
        │  com              │                             │
        └─────────┬─────────┘                             │
                  │                                        │
                  │ Cloudflare Tunnel                     │
                  │                                        │
    ═══════════════════════════════════════════════════════════════
                           K3s Cluster
    ═══════════════════════════════════════════════════════════════
                  │                                        │
                  ▼                                        ▼
        ┌─────────────────┐                    ┌─────────────────┐
        │     Traefik     │◄───────────────────│     Traefik     │
        │   (Internet)    │                    │     (LAN)       │
        └────────┬────────┘                    └────────┬────────┘
                 │                                      │
                 │                    ┌─────────────────┘
                 │                    │
                 ▼                    ▼
        ┌───────────────────────────────────┐
        │       Paperless-ngx Pod           │
        │  ┌─────────────┬───────────────┐  │
        │  │ paperless   │    samba      │  │
        │  │ (port 8000) │  (port 445)   │  │
        │  └──────┬──────┴───────┬───────┘  │
        │         │              │          │
        │         ▼              ▼          │
        │  ┌──────────────────────────┐     │
        │  │    Shared Consume PVC    │     │
        │  │      (5Gi RWO)           │     │
        │  └──────────────────────────┘     │
        │                                   │
        │  ┌──────────┐  ┌──────────────┐   │
        │  │ Data PVC │  │  Media PVC   │   │
        │  │  (5Gi)   │  │   (40Gi)     │   │
        │  └──────────┘  └──────────────┘   │
        └───────────────────────────────────┘
                 │
                 │
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌────────────┐        ┌────────────┐
│ PostgreSQL │        │   Redis    │
│192.168.4.204│       │192.168.4.203│
│  (paperless)│        │  (shared)  │
└────────────┘        └────────────┘

                    LAN
                     │
    ┌────────────────┴────────────────┐
    │                                  │
    ▼                                  ▼
┌────────────────┐          ┌─────────────────┐
│ Scanner        │          │ paperless.      │
│ (SMB to 445)   │          │ chocolandiadc.  │
│                │          │ local (Traefik) │
└────────────────┘          └─────────────────┘
```

## Open Questions (Resolved)

All research questions have been resolved. No NEEDS CLARIFICATION items remain.

## References

- [Paperless-ngx Documentation](https://docs.paperless-ngx.com/)
- [gabe565 Helm Chart](https://charts.gabe565.com/charts/paperless-ngx/)
- [dperson/samba Container](https://hub.docker.com/r/dperson/samba)
- [Samba-in-Kubernetes](https://github.com/samba-in-kubernetes/samba-container)
- [Cloudflare Zero Trust](https://developers.cloudflare.com/cloudflare-one/)
