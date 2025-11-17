# Data Model: Longhorn and MinIO Storage Infrastructure

**Feature**: 001-longhorn-minio
**Date**: 2025-11-16
**Phase**: 1 - Design & Contracts

## Overview

This document defines the key entities and their relationships for the Longhorn and MinIO storage infrastructure. While this is an infrastructure deployment (not a data-driven application), these entities represent the core storage abstractions and their lifecycle.

## Entity: Longhorn Volume

### Description
A Longhorn Volume represents a distributed block storage volume with configurable replica count, size, and performance characteristics. Volumes maintain replicas across multiple nodes for high availability.

### Attributes

| Attribute | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `name` | string | Yes | K8s naming rules | Unique identifier for the volume (auto-generated from PVC name) |
| `size` | quantity | Yes | >= 1Gi | Volume capacity (e.g., "10Gi", "100Gi") |
| `numberOfReplicas` | integer | Yes | 2 (configurable) | Number of data replicas across nodes |
| `dataLocality` | enum | No | disabled, best-effort | Whether to prefer scheduling pods on nodes with volume replicas |
| `accessMode` | enum | Yes | RWO, RWX, ROX | Kubernetes volume access mode (typically RWO for block) |
| `replicaAutoBalance` | enum | No | disabled, least-effort, best-effort | Automatic replica distribution strategy |
| `encrypted` | boolean | No | true/false | Whether volume data is encrypted at rest |
| `state` | enum | Yes | creating, attached, detached, deleting | Current volume lifecycle state |
| `robustness` | enum | Yes | healthy, degraded, faulted | Volume health status |
| `storageClass` | string | Yes | - | Kubernetes StorageClass name (e.g., "longhorn") |

### Relationships

- **Has Many**: Replicas (Longhorn Replica entities)
- **Belongs To**: PersistentVolumeClaim (Kubernetes)
- **Belongs To**: Longhorn Node (for each replica placement)
- **Has Many**: Snapshots (Longhorn Snapshot entities)
- **Has Many**: Backups (Longhorn Backup entities, stored in MinIO)

### State Transitions

```
[creating] → [detached] → [attached] → [detached] → [deleting] → [deleted]
                ↓            ↓
            [degraded]   [faulted]
                ↓            ↓
            [healthy]    [healthy]
```

### Validation Rules

1. `numberOfReplicas` must be ≤ number of available storage nodes
2. `size` must be ≤ available capacity across nodes (considering replica count)
3. Cannot transition to `deleting` while `state` is `attached` (must detach first)
4. `robustness` = `healthy` requires all `numberOfReplicas` to be in sync
5. `robustness` = `degraded` indicates 1+ replicas are rebuilding or unavailable
6. `robustness` = `faulted` indicates majority of replicas are unavailable

## Entity: Longhorn Node

### Description
A Longhorn Node represents a K3s cluster node participating in the Longhorn storage cluster. It tracks available disk capacity, scheduled volumes, and node health status.

### Attributes

| Attribute | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `name` | string | Yes | K8s node name | Node identifier (e.g., "master1", "nodo03") |
| `allowScheduling` | boolean | Yes | true/false | Whether new volume replicas can be scheduled on this node |
| `evictionRequested` | boolean | No | true/false | Whether replicas should be migrated off this node |
| `region` | string | No | - | Logical region/zone for replica distribution |
| `zone` | string | No | - | Logical zone within region for replica distribution |
| `disks` | array | Yes | At least 1 disk | List of storage disks on this node |

### Disk Sub-Entity

| Attribute | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `path` | string | Yes | Valid filesystem path | Mount point (e.g., "/var/lib/longhorn", "/media/usb/longhorn-storage") |
| `allowScheduling` | boolean | Yes | true/false | Whether this disk can store new replicas |
| `storageReserved` | quantity | No | >= 0 | Space reserved (not used by Longhorn) |
| `storageAvailable` | quantity | Yes | >= 0 | Free space available for replicas |
| `storageScheduled` | quantity | Yes | >= 0 | Space allocated to scheduled replicas |
| `storageMaximum` | quantity | Yes | > 0 | Total disk capacity |
| `diskType` | string | No | - | Disk type hint (e.g., "ssd", "hdd", "usb") |

### Relationships

- **Has Many**: Disks (disk configuration per node)
- **Has Many**: Replicas (Longhorn Replica entities scheduled on this node)
- **Belongs To**: Kubernetes Node

### Validation Rules

1. `storageScheduled` + `storageReserved` ≤ `storageMaximum`
2. Cannot set `allowScheduling = true` if `storageAvailable < minimum replica size`
3. At least one node must have `allowScheduling = true` for new volumes to be created
4. `evictionRequested = true` triggers replica migration (if target nodes available)

## Entity: Longhorn Snapshot

### Description
A Longhorn Snapshot represents a point-in-time copy of a volume's data. Snapshots can be used for backup or volume cloning.

### Attributes

| Attribute | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `name` | string | Yes | K8s naming rules | Unique identifier (auto-generated or user-defined) |
| `volumeName` | string | Yes | Existing volume name | Volume this snapshot belongs to |
| `created` | timestamp | Yes | ISO 8601 format | Snapshot creation time |
| `size` | quantity | Yes | > 0 | Snapshot data size |
| `labels` | map[string]string | No | - | User-defined metadata tags |
| `usercreated` | boolean | Yes | true/false | Whether created by user (vs system/recurring) |

### Relationships

- **Belongs To**: Longhorn Volume
- **Can Have**: Longhorn Backup (if backed up to external target)

### State Transitions

```
[creating] → [ready] → [deleting] → [deleted]
```

### Validation Rules

1. Cannot delete snapshot if it's the parent of active replicas (must delete children first)
2. Cannot create snapshot of volume in `faulted` state
3. Snapshot `size` ≤ parent volume `size`
4. Snapshots are immutable (cannot modify data after creation)

## Entity: Longhorn Backup

### Description
An off-cluster copy of a snapshot stored in an external backup target (MinIO S3). Enables disaster recovery.

### Attributes

| Attribute | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `name` | string | Yes | K8s naming rules | Unique identifier |
| `volumeName` | string | Yes | Existing volume name | Original volume name |
| `snapshotName` | string | Yes | Existing snapshot name | Snapshot this backup was created from |
| `created` | timestamp | Yes | ISO 8601 format | Backup creation time |
| `size` | quantity | Yes | > 0 | Backup data size (compressed) |
| `labels` | map[string]string | No | - | User-defined metadata tags |
| `backupURL` | string | Yes | S3 URL format | Location in MinIO (e.g., "s3://longhorn-backups@s3/...") |
| `state` | enum | Yes | Completed, InProgress, Error | Backup operation status |

### Relationships

- **Belongs To**: Longhorn Volume (original)
- **Belongs To**: Longhorn Snapshot (source)
- **Stored In**: MinIO Bucket (`longhorn-backups`)

### State Transitions

```
[InProgress] → [Completed]
              → [Error]
```

### Validation Rules

1. Cannot create backup if volume is `faulted`
2. Backup URL must point to valid S3-compatible target (MinIO)
3. Backup name must be unique across all backups in target
4. Can restore backup to new volume with different name
5. Restored volume must have `size` >= backup `size`

## Entity: MinIO Bucket

### Description
An S3-compatible storage container for objects. Supports versioning, lifecycle policies, and access controls.

### Attributes

| Attribute | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `name` | string | Yes | S3 bucket naming rules | Bucket identifier (e.g., "longhorn-backups") |
| `versioning` | boolean | No | true/false | Whether to keep multiple versions of objects |
| `quota` | quantity | No | > 0 | Storage quota limit (optional) |
| `creationDate` | timestamp | Yes | ISO 8601 format | Bucket creation time |
| `policy` | JSON | No | Valid bucket policy | Access control policy |
| `lifecycle` | JSON | No | Valid lifecycle config | Expiration/transition rules |

### Relationships

- **Has Many**: MinIO Objects
- **Stored On**: Longhorn Volume (MinIO data PVC)
- **Contains**: Longhorn Backups (for `longhorn-backups` bucket)

### Validation Rules

1. Bucket name must be globally unique within MinIO instance
2. Bucket name must be 3-63 characters, lowercase, no underscores
3. Cannot delete bucket if it contains objects (must empty first, or use force delete)
4. Versioning cannot be disabled once enabled (can only be suspended)
5. Quota enforcement: reject uploads that would exceed quota

## Entity: MinIO Object

### Description
A file or data blob stored in a bucket. Includes metadata, content type, and custom attributes.

### Attributes

| Attribute | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `key` | string | Yes | S3 object key rules | Object path/name within bucket |
| `bucket` | string | Yes | Existing bucket name | Bucket containing this object |
| `size` | quantity | Yes | >= 0 | Object data size |
| `etag` | string | Yes | MD5 hash | Content hash for integrity verification |
| `lastModified` | timestamp | Yes | ISO 8601 format | Last modification time |
| `contentType` | string | No | MIME type | Object content type (e.g., "application/octet-stream") |
| `metadata` | map[string]string | No | - | User-defined key-value metadata |
| `versionId` | string | No | - | Version identifier (if bucket versioning enabled) |
| `storageClass` | string | No | STANDARD, REDUCED_REDUNDANCY | Storage class (for tiering) |

### Relationships

- **Belongs To**: MinIO Bucket
- **May Represent**: Longhorn Backup (if stored in `longhorn-backups` bucket)

### Validation Rules

1. Object `key` must be unique within bucket (unless versioning enabled)
2. Object `size` must be ≤ bucket quota (if quota enforced)
3. `etag` must match content hash (enforced on upload)
4. Cannot modify object (immutable); updates create new version or replace
5. Multipart upload required for objects > 5GB

## Entity: MinIO User/AccessKey

### Description
Authentication credentials for accessing MinIO S3 API. Supports policy-based access control.

### Attributes

| Attribute | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `accessKey` | string | Yes | 3-20 chars | Access key ID (like AWS access key) |
| `secretKey` | string | Yes | 8-40 chars | Secret key (password-like, never displayed after creation) |
| `policy` | JSON | No | Valid IAM policy | Permissions policy (which buckets/actions allowed) |
| `status` | enum | Yes | enabled, disabled | Whether credentials are active |
| `creationDate` | timestamp | Yes | ISO 8601 format | Credential creation time |

### Relationships

- **Has Permissions On**: MinIO Buckets (via policy)
- **Stored As**: Kubernetes Secret (in K8s cluster)

### Validation Rules

1. `accessKey` must be unique across all MinIO users
2. `secretKey` must meet minimum complexity requirements
3. `policy` must grant at least one permission (or use default policy)
4. Cannot delete user if actively used (check for active sessions)
5. Credentials stored in Kubernetes Secret must match MinIO config

## Entity: StorageClass

### Description
Kubernetes resource defining storage provisioner (Longhorn) and parameters for dynamic volume creation.

### Attributes

| Attribute | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| `name` | string | Yes | K8s naming rules | StorageClass name (e.g., "longhorn") |
| `provisioner` | string | Yes | Must be "driver.longhorn.io" | Longhorn CSI driver |
| `reclaimPolicy` | enum | Yes | Delete, Retain | What happens to PV when PVC deleted |
| `allowVolumeExpansion` | boolean | Yes | true/false | Whether volumes can be resized |
| `volumeBindingMode` | enum | Yes | Immediate, WaitForFirstConsumer | When to provision volume |
| `parameters` | map[string]string | No | - | Longhorn-specific parameters |

### Parameters (Longhorn-specific)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `numberOfReplicas` | string | "2" | Number of volume replicas |
| `staleReplicaTimeout` | string | "30" | Minutes before replica considered stale |
| `dataLocality` | string | "disabled" | Replica scheduling preference |
| `encrypted` | string | "false" | Enable volume encryption |

### Relationships

- **Provisions**: Longhorn Volumes (via Kubernetes CSI)
- **Used By**: PersistentVolumeClaims

### Validation Rules

1. `provisioner` must be exactly "driver.longhorn.io"
2. `parameters.numberOfReplicas` must be valid integer string
3. `allowVolumeExpansion = true` required for online volume resize
4. `volumeBindingMode = WaitForFirstConsumer` recommended for topology-aware scheduling

## Relationship Diagram

```
┌─────────────────────┐
│ Kubernetes Node     │
└──────────┬──────────┘
           │ 1:1
           ↓
┌─────────────────────┐        ┌─────────────────────┐
│ Longhorn Node       │◄──────►│ Disk (1:N)          │
└──────────┬──────────┘        └─────────────────────┘
           │ 1:N
           ↓
┌─────────────────────┐        ┌─────────────────────┐
│ Longhorn Replica    │        │ Longhorn Volume     │
└──────────┬──────────┘        └──────────┬──────────┘
           │                              │ 1:1
           │                              ↓
           │                   ┌─────────────────────┐
           │                   │ PersistentVolume    │
           │                   └──────────┬──────────┘
           │                              │ 1:1
           │                              ↓
           │                   ┌─────────────────────┐
           │                   │ PersistentVolumeClaim│
           │                   └─────────────────────┘
           │                              │
           │ N:M                          │ 1:1
           └──────────────────────────────┘
                                          │
                       ┌──────────────────┴──────────────────┐
                       │                                     │
                       ↓ 1:N                                 ↓ 1:N
            ┌─────────────────────┐              ┌─────────────────────┐
            │ Longhorn Snapshot   │              │ Pod (using volume)  │
            └──────────┬──────────┘              └─────────────────────┘
                       │ 1:1
                       ↓
            ┌─────────────────────┐
            │ Longhorn Backup     │────────┐
            └─────────────────────┘        │ Stored in
                                           ↓
                                ┌─────────────────────┐
                                │ MinIO Bucket        │
                                └──────────┬──────────┘
                                           │ 1:N
                                           ↓
                                ┌─────────────────────┐
                                │ MinIO Object        │
                                └─────────────────────┘
                                           ↑
                                           │ Stored on
                                           │
                                ┌──────────┴──────────┐
                                │ Longhorn Volume     │
                                │ (MinIO Data PVC)    │
                                └─────────────────────┘
```

## Lifecycle Management

### Volume Provisioning Flow

1. User creates PersistentVolumeClaim with `storageClassName: longhorn`
2. Longhorn CSI driver provisions Longhorn Volume
3. Longhorn scheduler selects `numberOfReplicas` nodes based on capacity and health
4. Longhorn creates Replicas on selected nodes
5. Volume enters `detached` state, ready for attachment
6. When Pod scheduled, Longhorn attaches Volume to Pod's node
7. Pod mounts volume and accesses data

### Backup/Restore Flow

1. User creates Longhorn Snapshot of Volume
2. User initiates backup operation (snapshot → MinIO)
3. Longhorn uploads snapshot data to MinIO bucket as MinIO Object
4. Longhorn Backup entity created, referencing MinIO backupURL
5. To restore: User creates new Volume from Backup
6. Longhorn downloads backup data from MinIO, creates new Volume
7. New Volume available for mounting by Pods

### MinIO Object Upload Flow

1. User/application uploads object via S3 API (PUT request to `s3.chocolandiadc.com`)
2. MinIO stores object in specified Bucket
3. MinIO persists object data to Longhorn PersistentVolume
4. Longhorn replicates data (2 replicas across nodes)
5. MinIO returns success response with `etag`

## Next Phase

Proceed to **Phase 1 (continued)**: Generate `quickstart.md` and `contracts/README.md`
