# Feature Specification: Longhorn and MinIO Storage Infrastructure

**Feature Branch**: `001-longhorn-minio`
**Created**: 2025-11-16
**Status**: Draft
**Input**: User description: "quiero instalar Longhorn y MinIO"

## Clarifications

### Session 2025-11-16

- Q: What domain to use for Longhorn UI? → A: longhorn.chocolandiadc.com
- Q: What domain to use for MinIO Console? → A: minio.chocolandiadc.com
- Q: What domain to use for MinIO S3 API endpoint? → A: s3.chocolandiadc.com
- Q: What initial volume size for MinIO persistent storage? → A: 100Gi
- Q: What MinIO deployment mode (single-server vs distributed)? → A: Single-server (1 replica)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Distributed Storage with Longhorn (Priority: P1)

As a homelab administrator, I need distributed block storage across my K3s cluster nodes so that my stateful applications have reliable, replicated persistent volumes that survive node failures.

**Why this priority**: This is the foundation for all persistent storage in the cluster. Without reliable storage, stateful applications (databases, file stores, configuration data) cannot run reliably. This is the MVP that delivers immediate value by replacing the local-path-provisioner with a production-grade storage solution.

**Independent Test**: Can be fully tested by creating a PersistentVolumeClaim, deploying a stateful application (e.g., PostgreSQL test instance), writing data, and verifying the data persists across pod restarts and survives simulated node failures.

**Acceptance Scenarios**:

1. **Given** the K3s cluster is running with 4 nodes, **When** Longhorn is deployed, **Then** all nodes appear as storage nodes in the Longhorn UI with their available disk capacity
2. **Given** Longhorn is installed, **When** I create a PVC requesting Longhorn storage, **Then** the volume is provisioned with the configured replica count across multiple nodes
3. **Given** a pod is using a Longhorn volume, **When** the pod is deleted and recreated, **Then** the data persists and is accessible by the new pod
4. **Given** a Longhorn volume has replicas on 3 nodes, **When** one node becomes unavailable, **Then** the volume remains accessible and data is intact

---

### User Story 2 - Longhorn Web UI Access (Priority: P2)

As a homelab administrator, I need secure web access to the Longhorn management UI so that I can monitor storage usage, manage volumes, create snapshots, and troubleshoot storage issues without using kubectl commands.

**Why this priority**: While Longhorn can be managed via kubectl, the web UI provides essential visibility into storage health, volume distribution, and capacity planning. This is a critical operational tool but secondary to the core storage functionality.

**Independent Test**: Can be tested by accessing the Longhorn UI URL via HTTPS, authenticating through Cloudflare Access, and performing operations like viewing volumes, creating snapshots, and checking node disk status.

**Acceptance Scenarios**:

1. **Given** Longhorn is deployed, **When** I navigate to https://longhorn.chocolandiadc.com, **Then** I am redirected to Cloudflare Access for authentication
2. **Given** I am authenticated via Cloudflare Access with my authorized email, **When** I access the Longhorn UI, **Then** I can view all volumes, nodes, and storage settings
3. **Given** I have volumes in the cluster, **When** I view the Longhorn dashboard, **Then** I can see volume health, replica status, disk usage per node, and snapshot information
4. **Given** I select a volume in the UI, **When** I create a snapshot, **Then** the snapshot is created and appears in the snapshot list with timestamp and size

---

### User Story 3 - Object Storage with MinIO (Priority: P1)

As a homelab administrator, I need S3-compatible object storage so that my applications can store and retrieve files, backups, and large objects using standard S3 APIs without requiring external cloud services.

**Why this priority**: MinIO provides critical object storage capabilities for backups (Longhorn backups, PostgreSQL backups, application data), media storage, and any application requiring S3-compatible storage. This is essential for a complete storage solution and operates independently from Longhorn.

**Independent Test**: Can be fully tested by deploying MinIO, creating a bucket via the MinIO console or API, uploading objects using S3 CLI or SDK, and verifying object retrieval and lifecycle policies work as expected.

**Acceptance Scenarios**:

1. **Given** the K3s cluster is running, **When** MinIO is deployed, **Then** the MinIO service is accessible and accepts S3 API requests
2. **Given** MinIO is running, **When** I create a bucket, **Then** the bucket is created and appears in the bucket list
3. **Given** a bucket exists, **When** I upload an object using S3 API, **Then** the object is stored and can be retrieved with the same content and metadata
4. **Given** MinIO is using Longhorn for persistent storage, **When** the MinIO pod restarts, **Then** all buckets and objects remain accessible

---

### User Story 4 - MinIO Web Console Access (Priority: P2)

As a homelab administrator, I need secure web access to the MinIO console so that I can manage buckets, monitor storage usage, configure access policies, and browse stored objects without using command-line tools.

**Why this priority**: The MinIO console provides essential management capabilities and visibility, but the core S3 API functionality (P1) is more critical for application integration.

**Independent Test**: Can be tested by accessing the MinIO console URL, authenticating, and performing bucket management operations like creating buckets, uploading files via the UI, and configuring bucket policies.

**Acceptance Scenarios**:

1. **Given** MinIO is deployed, **When** I navigate to https://minio.chocolandiadc.com, **Then** I am redirected to Cloudflare Access for authentication
2. **Given** I am authenticated, **When** I access the MinIO console, **Then** I can view all buckets, storage usage, and system health
3. **Given** I am in the MinIO console, **When** I create or delete buckets, **Then** the changes are reflected immediately in bucket listings and API responses
4. **Given** I have objects in a bucket, **When** I browse the bucket in the console, **Then** I can view object metadata, download objects, and delete objects

---

### User Story 5 - Longhorn Backup to MinIO (Priority: P3)

As a homelab administrator, I need Longhorn to automatically backup volumes to MinIO so that I have point-in-time recovery capabilities for my persistent data independent of the Longhorn cluster itself.

**Why this priority**: This provides disaster recovery capabilities and allows restoration even if the entire Longhorn cluster is lost. While valuable, it's lower priority than establishing the core storage infrastructure (P1) and basic management capabilities (P2).

**Independent Test**: Can be tested by configuring Longhorn backup target to point to MinIO S3 endpoint, creating a volume snapshot, triggering a backup, and verifying the backup appears in the MinIO bucket and can be used to restore a volume.

**Acceptance Scenarios**:

1. **Given** Longhorn and MinIO are both running, **When** I configure MinIO as the Longhorn backup target, **Then** Longhorn can connect to MinIO and list existing backups
2. **Given** a Longhorn volume exists with data, **When** I create a backup of the volume, **Then** the backup is stored in the MinIO bucket and appears in the Longhorn backup list
3. **Given** a backup exists in MinIO, **When** I restore from that backup to a new volume, **Then** the new volume contains the same data as the original at the time of backup
4. **Given** scheduled backups are configured, **When** the schedule triggers, **Then** new backups are created automatically and older backups are retained according to retention policy

---

### Edge Cases

- What happens when a storage node runs out of disk space during volume provisioning?
- How does Longhorn handle network partitions between nodes during replica synchronization?
- What occurs when MinIO pods restart while S3 uploads are in progress?
- How does the system behave when attempting to restore a Longhorn backup from MinIO while MinIO is unavailable?
- What happens when trying to create a Longhorn volume larger than the available capacity across all nodes?
- How are orphaned volumes handled when a node is permanently removed from the cluster?
- What occurs when MinIO bucket quotas are exceeded during backup operations?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy Longhorn distributed block storage across all K3s cluster nodes
- **FR-002**: Longhorn MUST provide a StorageClass that can be used for dynamic PersistentVolume provisioning
- **FR-003**: Longhorn MUST replicate volume data across 2 replicas to balance storage capacity with node failure protection
- **FR-004**: System MUST provide HTTPS access to Longhorn web UI at longhorn.chocolandiadc.com protected by Cloudflare Access authentication
- **FR-005**: Longhorn MUST use the external USB disk mounted at `/media/usb` on master1 as additional storage capacity
- **FR-006**: System MUST deploy MinIO object storage in single-server mode (1 replica) with S3-compatible API endpoints
- **FR-007**: MinIO MUST use a 100Gi Longhorn volume for persistent storage of object data
- **FR-008**: System MUST provide HTTPS access to MinIO console at minio.chocolandiadc.com protected by Cloudflare Access authentication
- **FR-009**: System MUST expose MinIO S3 API endpoint at s3.chocolandiadc.com for S3 operations
- **FR-010**: MinIO MUST support standard S3 operations including bucket creation, object upload/download, and object deletion
- **FR-011**: System MUST configure MinIO as a backup target for Longhorn volume backups
- **FR-012**: Longhorn MUST support creating snapshots of volumes and backing them up to MinIO
- **FR-013**: System MUST expose Prometheus metrics for both Longhorn and MinIO for monitoring integration
- **FR-014**: All infrastructure MUST be deployed and managed via OpenTofu (Terraform) modules
- **FR-015**: System MUST integrate with existing cert-manager for TLS certificate provisioning
- **FR-016**: System MUST use existing Traefik ingress controller for HTTP/HTTPS routing

### Key Entities

- **Longhorn Volume**: Represents a distributed block storage volume with configurable replica count, size, and performance characteristics; maintains replicas across multiple nodes for high availability
- **Longhorn Node**: Represents a K3s cluster node participating in the Longhorn storage cluster; tracks available disk capacity, scheduled volumes, and node health status
- **Longhorn Snapshot**: Point-in-time copy of a volume's data; can be used for backup or volume cloning
- **Longhorn Backup**: Off-cluster copy of a snapshot stored in an external backup target (MinIO S3); enables disaster recovery
- **MinIO Bucket**: S3-compatible storage container for objects; supports versioning, lifecycle policies, and access controls
- **MinIO Object**: File or data blob stored in a bucket; includes metadata, content type, and custom attributes
- **MinIO User/AccessKey**: Authentication credentials for accessing MinIO S3 API; supports policy-based access control
- **StorageClass**: Kubernetes resource defining storage provisioner (Longhorn) and parameters for dynamic volume creation

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrator can provision a new persistent volume in under 30 seconds from PVC creation to bound status (measured as average over 10 test provisions)
- **SC-002**: Longhorn volumes survive simulated node failures with zero data loss and automatic failover to healthy replicas
- **SC-003**: Administrator can access and navigate both Longhorn UI and MinIO console within 10 seconds of authentication
- **SC-004**: Applications using Longhorn volumes experience read/write latency comparable to local disk (within 20% overhead, baseline established during Phase 1 testing)
- **SC-005**: MinIO S3 API handles object uploads and downloads at speeds limited only by network bandwidth (not storage backend)
- **SC-006**: Longhorn volume backups to MinIO complete successfully with 100% data integrity verification
- **SC-007**: System maintains 99% storage availability measured over a 30-day period
- **SC-008**: Volume snapshots and backups can be created without impacting running application performance (no noticeable slowdown)
- **SC-009**: Administrator can restore a volume from MinIO backup within 5 minutes of initiating the restore operation
- **SC-010**: Storage monitoring dashboards in Grafana show real-time metrics for Longhorn volume health, capacity, and MinIO object storage usage
