# Quickstart: Paperless-ngx Document Management

**Feature**: 027-paperless-ngx
**Date**: 2026-01-01

## Prerequisites

Before deploying Paperless-ngx, ensure:

1. **K3s cluster** is running and accessible via kubectl
2. **OpenTofu** is installed (1.6+)
3. **PostgreSQL** cluster is available at 192.168.4.204
4. **Redis** is available at 192.168.4.203
5. **Cloudflare** tunnel is configured (feature 004)
6. **cert-manager** with local-ca issuer is deployed (feature 006)
7. **Environment variables** are set:
   ```bash
   source terraform/environments/chocolandiadc-mvp/backend-env.sh
   ```

## Deployment Steps

### Step 1: Verify Prerequisites

```bash
# Check cluster connectivity
kubectl get nodes

# Check PostgreSQL
kubectl get pods -n postgresql

# Check Redis
kubectl get pods -n redis

# Check Cloudflare tunnel
kubectl get pods -n cloudflare-tunnel
```

### Step 2: Deploy Paperless-ngx Module

```bash
cd terraform/environments/chocolandiadc-mvp

# Initialize (if new module added)
tofu init

# Plan the deployment
tofu plan -target=module.paperless_ngx -target=module.paperless_database

# Apply
tofu apply -target=module.paperless_database -auto-approve
tofu apply -target=module.paperless_ngx -auto-approve
```

### Step 3: Verify Deployment

```bash
# Check pods
kubectl get pods -n paperless

# Check services
kubectl get svc -n paperless

# Check PVCs
kubectl get pvc -n paperless

# Check ingress
kubectl get ingressroute -n paperless
```

### Step 4: Get Access Credentials

```bash
# Get admin password (from OpenTofu output)
tofu output -raw paperless_admin_password

# Get Samba credentials
tofu output -raw samba_credentials
```

### Step 5: Access Paperless-ngx

**Internet Access** (requires Cloudflare authentication):
```
https://paperless.chocolandiadc.com
```

**LAN Access** (direct, requires local CA trust):
```
https://paperless.chocolandiadc.local
```

**Default Login**:
- Username: `admin`
- Password: (from Step 4)

## Scanner Configuration

### Step 1: Get Samba Share Details

```bash
# Get LoadBalancer IP
kubectl get svc samba-smb -n paperless -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Step 2: Configure Scanner

On your network scanner, configure scan-to-folder:

| Setting | Value |
|---------|-------|
| Protocol | SMB/CIFS |
| Server | `<LoadBalancer IP from Step 1>` |
| Share | `consume` |
| Username | `scanner` |
| Password | (from Step 4) |
| Path | `/` |

### Step 3: Test Scanner Integration

1. Scan a test document from your scanner
2. Wait 1-2 minutes for processing
3. Check Paperless-ngx dashboard for the new document

## Verification Checklist

- [ ] Paperless-ngx pod is Running
- [ ] Samba sidecar is Running
- [ ] Web UI accessible via internet (Cloudflare)
- [ ] Web UI accessible via LAN (.local)
- [ ] Can login with admin credentials
- [ ] Can upload a document via web UI
- [ ] Document is processed (OCR applied)
- [ ] Can search for text in document
- [ ] Scanner can connect to Samba share
- [ ] Scanned documents appear in Paperless-ngx
- [ ] Prometheus metrics visible at /metrics
- [ ] Grafana dashboard shows Paperless metrics

## Troubleshooting

### Pod not starting

```bash
# Check pod events
kubectl describe pod -n paperless -l app.kubernetes.io/name=paperless-ngx

# Check logs
kubectl logs -n paperless -l app.kubernetes.io/name=paperless-ngx -c paperless-ngx
kubectl logs -n paperless -l app.kubernetes.io/name=paperless-ngx -c samba
```

### Database connection issues

```bash
# Test PostgreSQL connectivity from pod (uses env var from secret)
kubectl exec -it -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  python3 -c "from django.db import connection; connection.ensure_connection(); print('PostgreSQL OK')"
```

### Redis connection issues

```bash
# Test Redis connectivity (uses PAPERLESS_REDIS env var from container)
kubectl exec -it -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  python3 -c "import os, redis; r=redis.from_url(os.environ['PAPERLESS_REDIS']); print('Redis OK:', r.ping())"
```

### Samba share not accessible

```bash
# Check Samba logs
kubectl logs -n paperless -l app.kubernetes.io/name=paperless-ngx -c samba

# Test SMB from another pod (use LoadBalancer IP 192.168.4.201)
kubectl run smbclient --image=dperson/samba --rm -it --restart=Never -- \
  smbclient //192.168.4.201/consume -U scanner
```

### OCR not working

```bash
# Check consume folder
kubectl exec -it -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  ls -la /usr/src/paperless/consume/

# Check OCR logs
kubectl logs -n paperless deployment/paperless-ngx -c paperless-ngx | grep -i ocr
```

### Documents not being processed

```bash
# Check Celery workers
kubectl exec -it -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  celery -A paperless inspect active

# Force reprocessing
kubectl exec -it -n paperless deployment/paperless-ngx -c paperless-ngx -- \
  python manage.py document_consumer
```

## Cleanup

To remove Paperless-ngx:

```bash
cd terraform/environments/chocolandiadc-mvp

# Destroy resources (WARNING: deletes all documents!)
tofu destroy -target=module.paperless_ngx
tofu destroy -target=module.paperless_database
```

**Note**: PVCs are set to `retain` policy. Manually delete PVCs to remove document data:

```bash
kubectl delete pvc -n paperless --all
kubectl delete namespace paperless
```

## Next Steps

1. **Configure document types**: Create categories like Invoice, Contract, Letter
2. **Set up correspondents**: Add frequent senders (companies, institutions)
3. **Create tags**: Organize with tags like "Tax", "Medical", "Personal"
4. **Set up matching rules**: Auto-classify documents based on content
5. **Configure Grafana dashboard**: Import Paperless metrics dashboard
6. **Set up alerts**: Create Prometheus alerts for processing failures
