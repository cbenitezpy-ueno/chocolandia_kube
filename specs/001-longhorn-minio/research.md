# Research: Longhorn and MinIO Storage Infrastructure

**Feature**: 001-longhorn-minio
**Date**: 2025-11-16
**Phase**: 0 - Outline & Research

## Overview

This document consolidates research findings for deploying Longhorn distributed block storage and MinIO S3-compatible object storage in a K3s homelab environment using OpenTofu.

## Decision 1: Longhorn vs Alternatives for Distributed Block Storage

### Decision
**Chosen**: Longhorn v1.5.x

### Rationale
- **Kubernetes-native**: Designed specifically for Kubernetes, integrates natively with K8s storage primitives (StorageClass, PVC, PV)
- **Lightweight**: Suitable for homelab/edge environments with limited resources (compared to Rook-Ceph)
- **Easy deployment**: Helm chart installation, minimal configuration for basic setup
- **Built-in UI**: Web interface for volume management, snapshots, and monitoring
- **Backup support**: Native integration with S3-compatible targets (MinIO) for off-cluster backups
- **Active development**: CNCF project with regular releases and strong community
- **USB disk support**: Can utilize heterogeneous storage (USB, local disks) across nodes

### Alternatives Considered
1. **Rook-Ceph**:
   - Pros: Enterprise-grade, very mature, extensive features
   - Cons: **Heavy resource requirements** (min 3 OSDs with dedicated disks), complex setup, overkill for homelab
   - Rejected: Too resource-intensive for 4-node mini PC cluster

2. **OpenEBS**:
   - Pros: Multiple storage engines (Jiva, cStor, LocalPV), flexible
   - Cons: **Complex architecture**, fragmented documentation, requires careful engine selection
   - Rejected: Complexity doesn't justify benefits for simple homelab use case

3. **NFS + local-path**:
   - Pros: Simple, well-understood technology
   - Cons: **No distribution** (single point of failure), no built-in replication, manual failover
   - Rejected: Doesn't meet HA requirements (FR-003: 2 replicas)

4. **Portworx**:
   - Pros: Enterprise features, good performance
   - Cons: **Commercial licensing** required for production features, heavy
   - Rejected: Not suitable for learning environment, licensing costs

## Decision 2: Longhorn Deployment Pattern (Helm vs Operator)

### Decision
**Chosen**: Helm Chart deployment via OpenTofu Helm provider

### Rationale
- Aligns with Constitution Principle I (Infrastructure as Code - OpenTofu First)
- Consistent with existing module patterns (traefik, cert-manager, headlamp all use Helm)
- Declarative configuration via Helm values (replica count, storage paths, UI settings)
- Easier version management and upgrades via Helm releases
- OpenTofu Helm provider provides idempotency and state tracking

### Alternatives Considered
1. **Kubectl apply manifests**:
   - Pros: Direct control, no Helm dependency
   - Cons: Manual lifecycle management, no templating, harder upgrades
   - Rejected: Doesn't align with existing Helm-based module pattern

2. **Longhorn Operator**:
   - Pros: GitOps-friendly CRDs
   - Cons: Additional complexity layer, less common pattern in project
   - Rejected: Helm is sufficient and more consistent with existing modules

## Decision 3: MinIO Deployment Mode (Single-Server vs Distributed)

### Decision
**Chosen**: Single-server mode (1 replica)

### Rationale
- **Longhorn provides HA**: MinIO data is stored on Longhorn volumes with 2 replicas, so storage layer already has redundancy
- **Resource efficiency**: Single MinIO instance uses less CPU/RAM than distributed mode (4+ instances)
- **Simplified operations**: No erasure coding complexity, simpler backup/restore
- **Sufficient for homelab**: No need for multi-tenant isolation or extreme throughput
- **Clear from clarifications**: User confirmed single-server in `/speckit.clarify` session

### Alternatives Considered
1. **Distributed MinIO (4 instances, erasure coding)**:
   - Pros: Higher throughput, data protection at MinIO layer
   - Cons: **4x resource usage**, requires min 4 drives (we have 1 USB), overkill complexity
   - Rejected: Redundant with Longhorn replication, excessive for homelab scale

2. **MinIO with 2 replicas (active-passive)**:
   - Pros: Some redundancy at app layer
   - Cons: Still duplicates Longhorn's HA, wastes resources
   - Rejected: Single replica + Longhorn HA is cleaner architecture

## Decision 4: MinIO Storage Size and Growth Strategy

### Decision
**Chosen**: Initial 100Gi PVC, expandable on-demand

### Rationale
- **Balanced start**: 100Gi sufficient for:
  - Longhorn volume backups (~20-30GB PostgreSQL + workloads)
  - Application media/data
  - Learning S3 operations
- **With 2 Longhorn replicas**: 100Gi × 2 = 200GB consumed from 931GB USB (leaves 731GB free)
- **Expandable**: Longhorn supports online volume expansion (resize PVC, MinIO recognizes new space)
- **Conservative**: Start small, grow as needs emerge (avoid premature capacity allocation)

### Alternatives Considered
1. **50Gi (very conservative)**:
   - Rejected: Too small for realistic backup scenarios
2. **200Gi (generous)**:
   - Rejected: May constrain future workloads unnecessarily early
3. **500Gi (aggressive)**:
   - Rejected: Over-commits capacity before understanding actual usage patterns

## Decision 5: Longhorn USB Disk Integration Strategy

### Decision
**Chosen**: Configure master1 with USB disk as additional storage path (`/media/usb/longhorn-storage`), all nodes contribute storage

### Rationale
- **Hybrid capacity**: USB provides bulk storage (931GB), local disks provide distribution
- **2-replica strategy**: Volumes can have replicas on:
  - Master1 (USB or local)
  - Nodo03, nodo1, or nodo04 (local)
- **Flexibility**: Longhorn scheduler distributes replicas based on available capacity and node health
- **No single point of failure**: If master1 fails, replicas on other nodes keep volumes available

### Implementation Details
- **Disk path configuration**: Set Longhorn default disk path on master1 to `/media/usb/longhorn-storage`
- **Node selector/taints**: No restrictions; all 4 nodes participate in storage pool
- **Replica placement**: Let Longhorn scheduler optimize (prefers distributing across nodes for HA)

## Decision 6: Cloudflare Access Integration Pattern

### Decision
**Chosen**: Reuse existing Cloudflare Access setup, add new applications for Longhorn and MinIO UIs

### Rationale
- **Consistent with existing services**: Headlamp, ArgoCD, Grafana already use Cloudflare Access
- **Minimal new infrastructure**: Leverage existing Google OAuth IdP configuration
- **Secure by default**: No public access to storage management UIs
- **Clear from spec**: FR-004, FR-008 mandate Cloudflare Access

### Configuration
- **Longhorn UI**: New Cloudflare Access application for `longhorn.chocolandiadc.com`
- **MinIO Console**: New application for `minio.chocolandiadc.com`
- **MinIO S3 API**: New application for `s3.chocolandiadc.com` (may need API-friendly policy)
- **Auth policy**: Email-based authorization (same authorized_emails list as other services)

## Decision 7: Longhorn Backup Target Configuration

### Decision
**Chosen**: Configure MinIO as Longhorn backup target after both services are deployed

### Rationale
- **Off-cluster backups**: MinIO provides external backup location (not dependent on Longhorn cluster)
- **S3 compatibility**: Longhorn natively supports S3-compatible backup targets
- **DR capability**: Backups can restore volumes even if Longhorn cluster is completely lost
- **Clear from spec**: User Story 5 (P3) requires Longhorn-to-MinIO backup integration

### Implementation Approach
1. Deploy Longhorn first (P1)
2. Deploy MinIO on Longhorn volume (P1)
3. Create dedicated MinIO bucket for Longhorn backups (e.g., `longhorn-backups`)
4. Configure Longhorn backup target: S3 endpoint `s3.chocolandiadc.com`, bucket name, access credentials
5. Test backup: Create snapshot, backup to MinIO, verify in bucket
6. Test restore: Restore volume from MinIO backup, validate data integrity

## Decision 8: Prometheus Metrics Integration

### Decision
**Chosen**: Enable Prometheus metrics for both Longhorn and MinIO, configure ServiceMonitors

### Rationale
- **Constitution Principle IV**: Observability is non-negotiable
- **Longhorn metrics**: Volume health, capacity usage, IOPS, replica sync status
- **MinIO metrics**: S3 API requests, object counts, bucket sizes, uptime
- **Existing Grafana**: Can import community dashboards for Longhorn and MinIO
- **Clear from spec**: FR-013 mandates Prometheus metrics exposure

### Implementation
- **Longhorn**: Metrics enabled by default on Helm chart, expose via ServiceMonitor
- **MinIO**: Configure MinIO with Prometheus bearer token, create ServiceMonitor
- **Grafana dashboards**:
  - Longhorn: Dashboard ID 13032 (community dashboard)
  - MinIO: Dashboard ID 13502 (community dashboard)

## Decision 9: TLS Certificate Management

### Decision
**Chosen**: Use existing cert-manager with Let's Encrypt for all 3 domains

### Rationale
- **Existing infrastructure**: cert-manager already deployed and working
- **Consistency**: Headlamp, ArgoCD, Grafana all use cert-manager certificates
- **Clear from spec**: FR-015 mandates integration with cert-manager

### Certificates Required
1. `longhorn.chocolandiadc.com` (Longhorn UI)
2. `minio.chocolandiadc.com` (MinIO Console)
3. `s3.chocolandiadc.com` (MinIO S3 API)

All use ClusterIssuer: `letsencrypt-production`

## Decision 10: Testing Strategy

### Decision
**Chosen**: Multi-layered testing per Constitution Principle VII (Test-Driven Learning)

### Test Layers
1. **OpenTofu Validation**: `tofu validate`, `tofu plan` before apply
2. **Deployment Validation**: Wait for pods Ready, check Longhorn node status, MinIO pod running
3. **Functional Tests**:
   - Longhorn: Create PVC, deploy test pod, write data, restart pod, verify persistence
   - MinIO: Create bucket via S3 CLI, upload object, retrieve object, verify content
4. **HA Tests**:
   - Simulate master1 failure (shutdown node)
   - Verify volumes remain accessible from replicas on other nodes
   - Verify MinIO restarts on different node, data intact
5. **Backup/Restore Tests**:
   - Create Longhorn snapshot, backup to MinIO
   - Delete original volume, restore from MinIO backup
   - Verify restored data matches original

### Validation Scripts
- `scripts/storage/validate-longhorn.sh`: Automates Longhorn functional tests
- `scripts/storage/validate-minio.sh`: Automates MinIO S3 API tests
- `scripts/storage/test-ha-failover.sh`: Automates HA failure scenarios
- `scripts/storage/configure-backup-target.sh`: Configures and validates Longhorn→MinIO backup

## Open Questions (Resolved in Clarifications)

All initial unknowns resolved during `/speckit.clarify` session:

1. **Longhorn UI domain**: ✅ `longhorn.chocolandiadc.com`
2. **MinIO Console domain**: ✅ `minio.chocolandiadc.com`
3. **MinIO S3 API domain**: ✅ `s3.chocolandiadc.com`
4. **MinIO volume size**: ✅ `100Gi`
5. **MinIO deployment mode**: ✅ Single-server (1 replica)
6. **Longhorn replica count**: ✅ 2 replicas (from spec FR-003)

## References

- Longhorn Documentation: https://longhorn.io/docs/
- Longhorn Helm Chart: https://github.com/longhorn/longhorn
- MinIO Documentation: https://min.io/docs/minio/kubernetes/upstream/
- MinIO Operator vs Helm: https://github.com/minio/operator/blob/master/helm-releases/README.md
- Longhorn Best Practices: https://longhorn.io/docs/latest/best-practices/
- MinIO S3 Compatibility: https://min.io/docs/minio/linux/integrations/aws-cli-with-minio.html

## Next Phase

Proceed to **Phase 1: Design & Contracts** to generate:
- `data-model.md`: Entities (Longhorn volumes, MinIO buckets)
- `quickstart.md`: Deployment and validation steps
- `contracts/README.md`: Explanation of why no API contracts (infrastructure deployment)
