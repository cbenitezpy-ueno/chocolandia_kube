# API Contracts: Longhorn and MinIO

**Feature**: 001-longhorn-minio
**Date**: 2025-11-16

## Why No Custom API Contracts?

This feature deploys **existing, upstream open-source projects** (Longhorn and MinIO) to the K3s cluster. We are not building custom APIs or services that require new contract definitions.

Instead, we consume well-documented, stable APIs provided by these projects:

## Consumed APIs

### 1. Longhorn REST API

**Provider**: Longhorn (CNCF project)
**Documentation**: https://longhorn.io/docs/latest/references/longhorn-manager-api/
**Version**: v1.5.x

**Purpose**: Manage distributed block storage programmatically

**Key Endpoints**:
- `GET /v1/volumes` - List all Longhorn volumes
- `POST /v1/volumes` - Create a new volume
- `GET /v1/volumes/{name}` - Get volume details
- `DELETE /v1/volumes/{name}` - Delete a volume
- `POST /v1/volumes/{name}?action=snapshotCreate` - Create snapshot
- `POST /v1/volumes/{name}?action=snapshotBackup` - Backup snapshot to external target
- `GET /v1/nodes` - List Longhorn nodes and disk status
- `GET /v1/settings` - Get Longhorn cluster settings
- `PUT /v1/settings/{name}` - Update settings (e.g., backup target)

**Authentication**: None required (internal cluster API, accessed via kubectl proxy or Longhorn UI)

**Contract Stability**: Stable API, backward-compatible versioning

**Our Usage**:
- Accessed indirectly via Kubernetes CRDs (`volumes.longhorn.io`, `nodes.longhorn.io`)
- Direct API usage for backup target configuration (automated scripts)
- Monitoring via Prometheus metrics endpoint

---

### 2. MinIO S3-Compatible API

**Provider**: MinIO, Inc.
**Documentation**: https://min.io/docs/minio/linux/developers/minio-drivers.html
**Version**: S3 API v4 signature (AWS S3-compatible)

**Purpose**: Store and retrieve objects using standard S3 protocol

**Key Operations** (S3 API):
- `ListBuckets` - List all buckets
- `CreateBucket` - Create a new bucket
- `PutObject` - Upload an object
- `GetObject` - Download an object
- `DeleteObject` - Delete an object
- `ListObjects` / `ListObjectsV2` - List objects in a bucket
- `HeadObject` - Get object metadata
- `CopyObject` - Copy object within or across buckets

**Authentication**: AWS Signature Version 4 (access key + secret key)

**Contract Stability**: Fully compatible with AWS S3 API, industry-standard contract

**Our Usage**:
- Longhorn backup storage (S3 client in Longhorn uploads snapshot data)
- Application object storage (via AWS SDKs, s3cmd, mc, or rclone)
- Accessible via `s3.chocolandiadc.com` endpoint

**Example S3 Request** (AWS CLI):
```bash
aws s3 cp myfile.txt s3://my-bucket/myfile.txt \
  --endpoint-url https://s3.chocolandiadc.com
```

---

### 3. MinIO Admin API

**Provider**: MinIO, Inc.
**Documentation**: https://min.io/docs/minio/linux/reference/minio-mc-admin.html
**Version**: MinIO Admin API (mc admin commands)

**Purpose**: Administrative operations (bucket policies, user management, monitoring)

**Key Operations** (via MinIO Console or `mc admin`):
- User management: Create/delete users, assign policies
- Bucket policies: Configure access control
- Server info: Get MinIO server status and configuration
- Healing: Trigger data healing operations
- Prometheus metrics: Export Prometheus-compatible metrics

**Authentication**: MinIO access key + secret key (admin privileges required)

**Contract Stability**: Stable, evolves with MinIO releases

**Our Usage**:
- Accessed via MinIO Console UI (`minio.chocolandiadc.com`)
- Monitoring integration via `/minio/v2/metrics/cluster` endpoint
- Automated user/bucket management via Terraform (if needed in future)

---

### 4. Kubernetes API (CRDs)

**Provider**: Kubernetes + Longhorn CSI Driver
**Documentation**: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
**Version**: K8s v1.28+, Longhorn CRDs v1beta2

**Purpose**: Provision and manage persistent volumes declaratively

**Key Resources**:
- `PersistentVolume` (PV) - Cluster-wide storage resource
- `PersistentVolumeClaim` (PVC) - User request for storage
- `StorageClass` - Dynamic provisioning configuration
- `VolumeSnapshot` - Point-in-time volume snapshot (CSI)
- `volumes.longhorn.io` (Longhorn CRD) - Longhorn-specific volume config
- `nodes.longhorn.io` (Longhorn CRD) - Longhorn node and disk status

**Authentication**: Kubernetes RBAC (ServiceAccount tokens)

**Contract Stability**: Kubernetes API versioning (v1, v1beta1), Longhorn follows Kubernetes compatibility

**Our Usage**:
- Create PVCs with `storageClassName: longhorn`
- Kubernetes automatically provisions Longhorn volumes
- Monitor volumes via `kubectl get volumes.longhorn.io -n longhorn-system`
- Snapshots via `VolumeSnapshot` CRD (if CSI snapshot controller installed)

**Example PVC**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

---

## Integration Contracts

While we don't define custom APIs, we establish integration contracts for how our infrastructure components interact:

### Longhorn → MinIO Backup Integration

**Contract**: Longhorn uses S3-compatible API to store backups in MinIO

**Configuration**:
- Backup target URL: `s3://longhorn-backups@us-east-1/`
- Credential secret: `minio-credentials` (Kubernetes Secret in `default` namespace)
- Endpoint URL: Inferred from S3 region `us-east-1` → `https://s3.chocolandiadc.com`

**Secret Format** (Kubernetes Secret):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: default
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: <minio-access-key>
  AWS_SECRET_ACCESS_KEY: <minio-secret-key>
  AWS_ENDPOINTS: https://s3.chocolandiadc.com
```

**Expected Behavior**:
1. Longhorn reads backup target from Settings CRD
2. Longhorn fetches credentials from `minio-credentials` Secret
3. Longhorn initiates S3 PutObject requests to upload backup chunks
4. MinIO stores backup objects in `longhorn-backups` bucket
5. Longhorn tracks backup metadata in Longhorn API

**Failure Modes**:
- MinIO unavailable → Longhorn backup fails, retries
- Invalid credentials → 403 Forbidden, backup marked as "Error"
- Bucket missing → Longhorn creates bucket (if credentials allow)

---

### MinIO → Longhorn Storage

**Contract**: MinIO persistent data stored on Longhorn PersistentVolume

**Configuration**:
- PVC name: `minio-data-pvc`
- StorageClass: `longhorn`
- Capacity: 100Gi
- Access mode: ReadWriteOnce (RWO)

**Expected Behavior**:
1. MinIO Deployment requests PVC `minio-data-pvc`
2. Longhorn CSI driver provisions volume with 2 replicas
3. MinIO pod mounts volume at `/data`
4. MinIO writes objects, metadata, and bucket configuration to `/data`
5. Longhorn replicates data across 2 nodes for HA

**Failure Modes**:
- Longhorn volume degraded → MinIO continues operation (1 replica sufficient)
- Longhorn volume faulted → MinIO pod cannot start (volume not attachable)
- Volume full → MinIO rejects new uploads with 507 Insufficient Storage

---

## Observability Contracts

### Prometheus Metrics

Both Longhorn and MinIO expose Prometheus-compatible metrics endpoints:

**Longhorn Metrics**:
- Endpoint: `http://longhorn-backend.longhorn-system.svc:9500/metrics`
- Format: Prometheus text format
- Key metrics:
  - `longhorn_volume_actual_size_bytes` - Volume data size
  - `longhorn_volume_state` - Volume state (attached, detached)
  - `longhorn_volume_robustness` - Volume health (healthy, degraded, faulted)
  - `longhorn_node_storage_capacity_bytes` - Node storage capacity
  - `longhorn_disk_capacity_bytes` - Disk capacity per node

**MinIO Metrics**:
- Endpoint: `http://minio.default.svc:9000/minio/v2/metrics/cluster`
- Format: Prometheus text format
- Authentication: Bearer token (configured in MinIO)
- Key metrics:
  - `minio_bucket_objects_count` - Object count per bucket
  - `minio_bucket_usage_bytes` - Bucket size
  - `minio_s3_requests_total` - S3 API request count
  - `minio_disk_storage_used_bytes` - Disk usage
  - `minio_cluster_health_status` - Cluster health (1=healthy)

**ServiceMonitor CRDs** (for Prometheus Operator):
- Created by Terraform modules
- Auto-discovery by Prometheus
- Scrape interval: 30s

---

## API Versioning and Compatibility

### Longhorn API Compatibility

**Current Version**: v1.5.x
**API Version**: v1
**Upgrade Strategy**: Minor version upgrades (v1.5 → v1.6) are backward-compatible

**Breaking Changes**:
- Major version upgrades (v1.x → v2.x) may introduce breaking changes
- CRD schema changes announced in release notes
- Upgrade path: Longhorn UI provides migration tools

**Our Approach**:
- Pin Helm chart version in Terraform (`version = "~> 1.5.0"`)
- Test upgrades in staging before production
- Monitor Longhorn release notes for API changes

---

### MinIO API Compatibility

**Current Version**: RELEASE.2024-01-xx
**API Version**: S3 API v4 (AWS S3-compatible)
**Upgrade Strategy**: MinIO follows semantic versioning for releases

**Breaking Changes**:
- S3 API is stable (AWS compatibility guarantee)
- MinIO-specific extensions may change between releases
- Admin API evolves with MinIO features

**Our Approach**:
- Use Docker image tags (not `latest`)
- Test S3 operations after MinIO upgrades
- Monitor MinIO changelog for deprecated features

---

## Security Considerations

### API Access Control

**Longhorn API**:
- Internal cluster access only (no external exposure)
- Longhorn UI protected by Cloudflare Access (Google OAuth)
- No API authentication required (assumes trusted cluster network)

**MinIO S3 API**:
- Exposed externally via `s3.chocolandiadc.com`
- Authentication: AWS Signature v4 (access key + secret key)
- Protected by Cloudflare Access (application-level auth)
- Bucket policies for fine-grained access control

**MinIO Console**:
- Exposed externally via `minio.chocolandiadc.com`
- Authentication: MinIO access key + secret key
- Protected by Cloudflare Access (Google OAuth)

**Credential Management**:
- MinIO credentials stored in Kubernetes Secrets
- Secrets encrypted at rest (if K8s etcd encryption enabled)
- Rotation: Manual (can be automated via Terraform lifecycle)

---

## Conclusion

This feature does not introduce new API contracts because it deploys existing, well-documented upstream APIs (Longhorn REST API, MinIO S3 API). Our "contracts" are:

1. **Adherence to upstream API specifications** (Longhorn v1.5.x, MinIO S3 API v4)
2. **Integration contracts** (Longhorn → MinIO backup, MinIO → Longhorn storage)
3. **Observability contracts** (Prometheus metrics endpoints)

For detailed API documentation, refer to:
- Longhorn API: https://longhorn.io/docs/latest/references/longhorn-manager-api/
- MinIO S3 API: https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html
- MinIO Admin API: https://min.io/docs/minio/linux/reference/minio-mc-admin.html

All integration points are defined in the OpenTofu modules (`terraform/modules/longhorn`, `terraform/modules/minio`) and validated via the quickstart guide.
