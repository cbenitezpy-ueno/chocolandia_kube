# Quickstart: Longhorn and MinIO Deployment

**Feature**: 001-longhorn-minio
**Date**: 2025-11-16
**Prerequisites**: K3s cluster running, kubectl configured, OpenTofu installed

## Overview

This quickstart guide walks through deploying Longhorn distributed block storage and MinIO S3-compatible object storage to your K3s homelab cluster using OpenTofu modules.

## Prerequisites Checklist

Before starting, verify:

```bash
# 1. K3s cluster is running
kubectl get nodes
# Expected: All 4 nodes (master1, nodo03, nodo1, nodo04) in Ready state

# 2. OpenTofu is installed
tofu version
# Expected: OpenTofu v1.6.0 or higher

# 3. Helm is available (used by OpenTofu Helm provider)
helm version
# Expected: version.BuildInfo{Version:"v3.x.x"}

# 4. USB disk is mounted on master1
ssh master1 "df -h /media/usb"
# Expected: Filesystem mounted with ~931GB capacity

# 5. Existing infrastructure is healthy
kubectl get pods -n traefik       # Traefik ingress controller
kubectl get pods -n cert-manager  # cert-manager for TLS
kubectl get cloudflareaccess      # Cloudflare Access applications (if CRD installed)

# 6. Environment variables are set
echo $TF_VAR_cloudflare_api_token  # Cloudflare API token
echo $TF_VAR_authorized_emails     # Comma-separated authorized emails
```

## Deployment Steps

### Phase 1: Deploy Longhorn (P1)

#### 1.1 Navigate to Terraform Environment

```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp
```

#### 1.2 Review Longhorn Module Configuration

```bash
# Check longhorn.tf for configuration
cat longhorn.tf
```

Expected configuration:
- Helm chart: `longhorn/longhorn` v1.5.x
- Namespace: `longhorn-system`
- Replica count: 2
- USB disk path on master1: `/media/usb/longhorn-storage`
- Ingress domain: `longhorn.chocolandiadc.com`

#### 1.3 Initialize and Plan

```bash
# Initialize OpenTofu (if first time)
tofu init

# Plan Longhorn deployment
tofu plan -target=module.longhorn
```

Review the plan output:
- Helm release creation
- Cloudflare DNS records for longhorn.chocolandiadc.com
- Cloudflare Access application for UI authentication
- Traefik IngressRoute for HTTPS access

#### 1.4 Apply Longhorn

```bash
tofu apply -target=module.longhorn
```

Expected output:
```
Apply complete! Resources: X added, 0 changed, 0 destroyed.

Outputs:

longhorn_ui_url = "https://longhorn.chocolandiadc.com"
longhorn_storageclass_name = "longhorn"
longhorn_metrics_endpoint = "http://longhorn-backend:9500/metrics"
```

#### 1.5 Verify Longhorn Deployment

```bash
# Wait for Longhorn pods to be ready (may take 2-3 minutes)
kubectl wait --for=condition=ready pod \
  -l app=longhorn-manager \
  -n longhorn-system \
  --timeout=300s

# Check all Longhorn components
kubectl get pods -n longhorn-system
# Expected: All pods Running (longhorn-manager, longhorn-driver-deployer, longhorn-ui)

# Verify Longhorn nodes
kubectl get nodes.longhorn.io -n longhorn-system
# Expected: All 4 nodes listed with SchedulingDisabled=false

# Check StorageClass
kubectl get storageclass longhorn
# Expected: longhorn StorageClass with provisioner driver.longhorn.io
```

#### 1.6 Test Volume Provisioning

```bash
# Create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF

# Wait for PVC to be bound
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/longhorn-test-pvc --timeout=60s

# Verify volume created
kubectl get pvc longhorn-test-pvc
# Expected: STATUS=Bound, VOLUME=pvc-xxxx, STORAGECLASS=longhorn
```

#### 1.7 Access Longhorn UI

```bash
# Open Longhorn UI in browser
open https://longhorn.chocolandiadc.com
```

Expected flow:
1. Redirected to Cloudflare Access login
2. Authenticate with authorized Google account
3. Access Longhorn dashboard showing:
   - 4 nodes with disk capacity
   - 1 volume (longhorn-test-pvc)
   - Volume health: Healthy, 2 replicas

#### 1.8 Cleanup Test Resources

```bash
# Delete test PVC
kubectl delete pvc longhorn-test-pvc -n default

# Verify volume is deleted
kubectl get volumes.longhorn.io -n longhorn-system
# Expected: longhorn-test-pvc volume no longer listed (may take 30s)
```

---

### Phase 2: Deploy MinIO (P1)

#### 2.1 Review MinIO Module Configuration

```bash
# Check minio.tf for configuration
cat minio.tf
```

Expected configuration:
- Deployment: Single-server mode (1 replica)
- Storage: 100Gi Longhorn PersistentVolume
- Console domain: `minio.chocolandiadc.com`
- S3 API domain: `s3.chocolandiadc.com`
- Credentials: Auto-generated and stored in Kubernetes Secret

#### 2.2 Plan MinIO Deployment

```bash
tofu plan -target=module.minio
```

Review the plan output:
- MinIO Deployment (1 replica)
- PersistentVolumeClaim (100Gi, StorageClass: longhorn)
- Service (ClusterIP for console, S3 API)
- Cloudflare DNS records (minio, s3 subdomains)
- Cloudflare Access applications
- Traefik IngressRoutes (console, S3 API)

#### 2.3 Apply MinIO

```bash
tofu apply -target=module.minio
```

Expected output:
```
Apply complete! Resources: X added, 0 changed, 0 destroyed.

Outputs:

minio_console_url = "https://minio.chocolandiadc.com"
minio_s3_endpoint = "https://s3.chocolandiadc.com"
minio_access_key = <sensitive>
minio_secret_key = <sensitive>
```

#### 2.4 Verify MinIO Deployment

```bash
# Wait for MinIO pod to be ready
kubectl wait --for=condition=ready pod \
  -l app=minio \
  -n default \
  --timeout=180s

# Check MinIO pod
kubectl get pods -l app=minio
# Expected: 1/1 Running

# Verify PVC is bound
kubectl get pvc minio-data-pvc
# Expected: STATUS=Bound, CAPACITY=100Gi, STORAGECLASS=longhorn

# Check Longhorn volume for MinIO
kubectl get volumes.longhorn.io -n longhorn-system | grep minio
# Expected: Volume with 100Gi, 2 replicas, robustness=healthy
```

#### 2.5 Retrieve MinIO Credentials

```bash
# Get MinIO access key
kubectl get secret minio-credentials -o jsonpath='{.data.accesskey}' | base64 -d
echo

# Get MinIO secret key
kubectl get secret minio-credentials -o jsonpath='{.data.secretkey}' | base64 -d
echo
```

Save these credentials securely (you'll need them for S3 API access).

#### 2.6 Access MinIO Console

```bash
# Open MinIO Console in browser
open https://minio.chocolandiadc.com
```

Expected flow:
1. Redirected to Cloudflare Access login
2. Authenticate with authorized Google account
3. Redirected to MinIO login page
4. Login with MinIO access key and secret key (from step 2.5)
5. Access MinIO Console dashboard

#### 2.7 Test S3 API

```bash
# Install AWS CLI (if not already installed)
# macOS: brew install awscli
# Linux: apt-get install awscli

# Configure AWS CLI for MinIO
aws configure set aws_access_key_id <your-access-key>
aws configure set aws_secret_access_key <your-secret-key>

# Create test bucket
aws s3 mb s3://test-bucket --endpoint-url https://s3.chocolandiadc.com

# Upload test file
echo "Hello MinIO" > test.txt
aws s3 cp test.txt s3://test-bucket/test.txt --endpoint-url https://s3.chocolandiadc.com

# List bucket contents
aws s3 ls s3://test-bucket/ --endpoint-url https://s3.chocolandiadc.com
# Expected: test.txt

# Download test file
aws s3 cp s3://test-bucket/test.txt downloaded.txt --endpoint-url https://s3.chocolandiadc.com
cat downloaded.txt
# Expected: "Hello MinIO"

# Cleanup
rm test.txt downloaded.txt
aws s3 rm s3://test-bucket/test.txt --endpoint-url https://s3.chocolandiadc.com
aws s3 rb s3://test-bucket --endpoint-url https://s3.chocolandiadc.com
```

---

### Phase 3: Configure Longhorn Backup Target (P3)

#### 3.1 Create MinIO Bucket for Longhorn Backups

```bash
# Create bucket via AWS CLI
aws s3 mb s3://longhorn-backups --endpoint-url https://s3.chocolandiadc.com

# Verify bucket exists
aws s3 ls --endpoint-url https://s3.chocolandiadc.com
# Expected: longhorn-backups listed
```

Or via MinIO Console:
1. Navigate to https://minio.chocolandiadc.com
2. Click "Buckets" → "Create Bucket"
3. Name: `longhorn-backups`
4. Click "Create Bucket"

#### 3.2 Configure Longhorn Backup Target

Option A: Via Longhorn UI
1. Navigate to https://longhorn.chocolandiadc.com
2. Click "Setting" → "General" → "Backup Target"
3. Enter: `s3://longhorn-backups@us-east-1/`
4. Click "Backup Target Credential Secret"
5. Enter: `minio-credentials` (namespace: default)
6. Save settings

Option B: Via kubectl
```bash
kubectl patch settings.longhorn.io default-setting -n longhorn-system --type merge \
  --patch '{
    "backupTarget": "s3://longhorn-backups@us-east-1/",
    "backupTargetCredentialSecret": "minio-credentials"
  }'
```

#### 3.3 Verify Backup Configuration

```bash
# Check Longhorn settings
kubectl get settings.longhorn.io default-setting -n longhorn-system -o yaml | grep -A2 backup
# Expected: backupTarget and backupTargetCredentialSecret configured
```

#### 3.4 Test Backup and Restore

```bash
# Create test volume with data
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: backup-test-pod
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ["sh", "-c", "echo 'Test data' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: backup-test-pvc
EOF

# Wait for pod to write data
sleep 10

# Get Longhorn volume name
VOLUME_NAME=$(kubectl get pvc backup-test-pvc -o jsonpath='{.spec.volumeName}')
echo "Volume name: $VOLUME_NAME"

# Create snapshot via Longhorn UI or kubectl
# (Longhorn UI: Select volume → "Take Snapshot" → Name: "test-snapshot-1")
```

Via kubectl (create VolumeSnapshot CRD if available, or use Longhorn API):
```bash
# Note: Snapshot creation typically done via Longhorn UI for homelab use
# Check Longhorn UI at https://longhorn.chocolandiadc.com
# Select volume → "Snapshots" tab → "Take Snapshot"
```

Create backup from snapshot:
```bash
# Via Longhorn UI:
# 1. Select snapshot "test-snapshot-1"
# 2. Click "Backup" → "Create Backup"
# 3. Wait for backup to complete (Status: Completed)

# Verify backup in MinIO
aws s3 ls s3://longhorn-backups/backups/ --recursive --endpoint-url https://s3.chocolandiadc.com
# Expected: Backup files for the volume
```

Restore from backup:
```bash
# Delete original volume
kubectl delete pod backup-test-pod
kubectl delete pvc backup-test-pvc

# Via Longhorn UI:
# 1. Navigate to "Backup" tab
# 2. Select backup for $VOLUME_NAME
# 3. Click "Restore" → "Restore to New Volume"
# 4. Name: "restored-volume"
# 5. Wait for restore to complete

# Create PVC from restored volume
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  volumeName: restored-volume
  resources:
    requests:
      storage: 1Gi
EOF

# Mount and verify data
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: verify-pod
  namespace: default
spec:
  containers:
  - name: verify
    image: busybox
    command: ["sh", "-c", "cat /data/test.txt && sleep 60"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: restored-pvc
EOF

# Check logs
kubectl logs verify-pod
# Expected: "Test data"

# Cleanup
kubectl delete pod verify-pod
kubectl delete pvc restored-pvc
```

---

## Validation Scripts

For automated testing, use the provided validation scripts:

```bash
# Validate Longhorn deployment
./scripts/storage/validate-longhorn.sh

# Validate MinIO deployment
./scripts/storage/validate-minio.sh

# Test HA failover (simulates node failure)
./scripts/storage/test-ha-failover.sh

# Configure and test backup target
./scripts/storage/configure-backup-target.sh
```

---

## Common Troubleshooting

### Longhorn Issues

**Problem**: Longhorn pods stuck in `Pending` or `CrashLoopBackOff`

```bash
# Check pod events
kubectl describe pod -n longhorn-system <pod-name>

# Check node disk configuration
kubectl get nodes.longhorn.io -n longhorn-system -o yaml

# Verify USB disk is mounted on master1
ssh master1 "df -h /media/usb"
```

**Problem**: Volume provisioning fails with "no space available"

```bash
# Check available capacity per node
kubectl get nodes.longhorn.io -n longhorn-system

# Check Longhorn settings for storage reservation
kubectl get settings.longhorn.io -n longhorn-system
```

**Problem**: Volume stuck in "Degraded" state

```bash
# Check replica status
kubectl get replicas.longhorn.io -n longhorn-system | grep <volume-name>

# Check node connectivity
kubectl get nodes
```

### MinIO Issues

**Problem**: MinIO pod won't start

```bash
# Check pod logs
kubectl logs -l app=minio

# Check PVC status
kubectl get pvc minio-data-pvc

# Verify Longhorn volume health
kubectl get volumes.longhorn.io -n longhorn-system | grep minio
```

**Problem**: S3 API returns 403 Forbidden

```bash
# Verify credentials
kubectl get secret minio-credentials -o yaml

# Check MinIO bucket policies (via Console)
# Navigate to https://minio.chocolandiadc.com → Buckets → <bucket> → "Access Policy"
```

**Problem**: Backup to MinIO fails

```bash
# Check Longhorn backup target configuration
kubectl get settings.longhorn.io default-setting -n longhorn-system -o yaml | grep backup

# Test MinIO connectivity from Longhorn pod
kubectl exec -n longhorn-system <longhorn-manager-pod> -- \
  curl -I https://s3.chocolandiadc.com

# Check MinIO credentials secret
kubectl get secret minio-credentials -n default
```

### Cloudflare Access Issues

**Problem**: Can't access Longhorn/MinIO UI (redirect loop)

```bash
# Verify Cloudflare Access applications
# Check via Cloudflare Zero Trust dashboard:
# Access → Applications → longhorn.chocolandiadc.com
# Access → Applications → minio.chocolandiadc.com

# Verify DNS records
dig longhorn.chocolandiadc.com
dig minio.chocolandiadc.com
dig s3.chocolandiadc.com
```

**Problem**: Email not authorized

```bash
# Check authorized emails in Cloudflare Access policy
# Update TF_VAR_authorized_emails if needed
echo $TF_VAR_authorized_emails

# Re-apply Cloudflare Access configuration
tofu apply -target=module.longhorn.cloudflare_access_application.longhorn_ui
tofu apply -target=module.minio.cloudflare_access_application.minio_console
```

---

## Monitoring

### Prometheus Metrics

Verify metrics are being scraped:

```bash
# Check Longhorn ServiceMonitor
kubectl get servicemonitor -n longhorn-system

# Check MinIO ServiceMonitor
kubectl get servicemonitor -n default | grep minio

# Query Prometheus for Longhorn metrics
# (if Prometheus accessible via port-forward or Ingress)
curl http://prometheus.chocolandiadc.com/api/v1/query?query=longhorn_volume_actual_size_bytes
```

### Grafana Dashboards

Import community dashboards:

1. Navigate to Grafana (https://grafana.chocolandiadc.com)
2. Dashboards → Import
3. Longhorn: Dashboard ID 13032
4. MinIO: Dashboard ID 13502

---

## Next Steps

After successful deployment:

1. **Configure scheduled backups**: Set up recurring snapshots and backups for critical volumes
2. **Monitor storage usage**: Review Grafana dashboards weekly for capacity planning
3. **Document runbooks**: Create procedures for common operations (volume expansion, backup restoration)
4. **Test disaster recovery**: Practice restoring from MinIO backups in a controlled scenario
5. **Migrate existing workloads**: Move PostgreSQL and other stateful apps to Longhorn volumes

---

## References

- Longhorn Documentation: https://longhorn.io/docs/
- MinIO Documentation: https://min.io/docs/minio/kubernetes/upstream/
- Cloudflare Access: https://developers.cloudflare.com/cloudflare-one/applications/
- OpenTofu Helm Provider: https://registry.terraform.io/providers/hashicorp/helm/latest/docs
