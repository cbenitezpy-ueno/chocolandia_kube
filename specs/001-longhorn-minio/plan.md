# Implementation Plan: Longhorn and MinIO Storage Infrastructure

**Branch**: `001-longhorn-minio` | **Date**: 2025-11-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-longhorn-minio/spec.md`

## Summary

Deploy Longhorn distributed block storage and MinIO S3-compatible object storage to the K3s homelab cluster using OpenTofu modules. Longhorn will provide replicated persistent volumes (2 replicas) using the external USB disk on master1 plus local storage on other nodes. MinIO will run in single-server mode with a 100Gi Longhorn volume for S3 object storage. Both services will be exposed via Traefik ingress with Cloudflare Access authentication and cert-manager TLS certificates.

## Technical Context

**Language/Version**: HCL (OpenTofu) 1.6+, YAML (Kubernetes manifests), Bash (validation scripts)
**Primary Dependencies**:
- Longhorn v1.5.x (Helm chart)
- MinIO RELEASE.2024-01-xx (Helm chart or Kubernetes manifests)
- Helm provider ~> 2.12
- Kubernetes provider ~> 2.23
- Cloudflare provider ~> 4.0 (for DNS and Access)

**Storage**:
- Longhorn: Distributed block storage across 4 K3s nodes
  - Primary: USB disk 931GB at /media/usb on master1
  - Secondary: Local storage on master1, nodo03, nodo1, nodo04
  - Replication: 2 replicas per volume
- MinIO: 100Gi Longhorn PersistentVolume for S3 objects

**Testing**:
- OpenTofu: `tofu validate`, `tofu plan`, `tofu apply`
- Kubernetes: kubectl validation, PVC creation tests, pod restart persistence tests
- Integration: Volume provisioning tests, backup/restore tests, S3 API tests
- HA: Node failure simulation, replica synchronization tests

**Target Platform**: K3s v1.28.3+ on Linux (4-node cluster: 2 control-plane + 2 workers)

**Project Type**: Infrastructure as Code (OpenTofu modules for K8s storage infrastructure)

**Performance Goals**:
- Volume provisioning: < 30 seconds from PVC creation to bound
- Read/write latency: Within 20% overhead vs local disk
- S3 operations: Network-limited (not storage-limited)
- Backup completion: Volume snapshots without performance impact

**Constraints**:
- Single USB disk (931GB) on master1 only
- 2 replicas maximum (balance capacity vs redundancy)
- Homelab hardware (mini PCs, limited RAM/CPU)
- Integration with existing stack (Traefik, cert-manager, Cloudflare Access, Prometheus)

**Scale/Scope**:
- 4 cluster nodes (master1, nodo03 as storage+control-plane; nodo1, nodo04 as workers)
- Initial MinIO storage: 100Gi (expandable)
- Longhorn total capacity: ~465GB effective (with 2 replicas from 931GB USB)
- Support for multiple workloads (PostgreSQL, backups, application data)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Compliance | Evidence |
|-----------|------------|----------|
| **I. Infrastructure as Code - OpenTofu First** | ✅ PASS | All Longhorn and MinIO deployment via OpenTofu modules |
| **II. GitOps Workflow** | ✅ PASS | Changes committed to feature branch, PR workflow before merge |
| **III. Container-First Development** | ✅ PASS | Longhorn and MinIO run as containerized workloads in K8s |
| **IV. Observability - Prometheus + Grafana** | ✅ PASS | Both Longhorn and MinIO expose Prometheus /metrics endpoints (FR-013) |
| **V. Security Hardening** | ✅ PASS | Cloudflare Access for UI auth, TLS via cert-manager, K8s Secrets for credentials |
| **VI. High Availability** | ✅ PASS | Longhorn 2-replica distribution, cluster survives single node failure |
| **VII. Test-Driven Learning** | ✅ PASS | Validation tests for volume provisioning, persistence, HA failover |
| **VIII. Documentation-First** | ✅ PASS | Spec, plan, research artifacts; runbooks for backup/restore |
| **IX. Network-First Security** | ✅ PASS | Services exposed via Traefik (existing network layer), Cloudflare Access |

**Result**: All constitution principles satisfied. No complexity violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/001-longhorn-minio/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (Longhorn vs alternatives, MinIO deployment patterns)
├── data-model.md        # Phase 1 output (Longhorn volumes, MinIO buckets entities)
├── quickstart.md        # Phase 1 output (deployment and validation steps)
├── contracts/           # Phase 1 output (not applicable - infrastructure, not API)
│   └── README.md        # Explanation: No API contracts for infrastructure deployment
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created yet)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   ├── longhorn/
│   │   ├── main.tf           # Longhorn Helm release, storage configuration
│   │   ├── variables.tf      # Configurable parameters (replica count, USB path, domains)
│   │   ├── outputs.tf        # StorageClass name, UI URL, metrics endpoints
│   │   ├── ingress.tf        # Traefik IngressRoute for Longhorn UI
│   │   ├── cloudflare.tf     # Cloudflare Access + DNS for longhorn.chocolandiadc.com
│   │   └── README.md         # Module documentation
│   │
│   └── minio/
│       ├── main.tf           # MinIO deployment, PVC, Service
│       ├── variables.tf      # Configurable parameters (volume size, domains, credentials)
│       ├── outputs.tf        # S3 endpoint, Console URL, access keys
│       ├── ingress.tf        # Traefik IngressRoute for MinIO console + S3 API
│       ├── cloudflare.tf     # Cloudflare Access + DNS for minio + s3 subdomains
│       ├── backup-config.tf  # Longhorn backup target configuration
│       └── README.md         # Module documentation
│
└── environments/
    └── chocolandiadc-mvp/
        ├── longhorn.tf       # Longhorn module instantiation
        ├── minio.tf          # MinIO module instantiation
        └── variables.tf      # Environment-specific variables (domains, node labels)

scripts/
└── storage/
    ├── validate-longhorn.sh      # Test Longhorn deployment and volume provisioning
    ├── validate-minio.sh          # Test MinIO S3 API and console access
    ├── test-ha-failover.sh        # Simulate node failure and verify persistence
    └── configure-backup-target.sh # Configure Longhorn to backup to MinIO
```

**Structure Decision**: Infrastructure-only repository structure with OpenTofu modules for Longhorn and MinIO. Modules follow existing pattern (e.g., `terraform/modules/headlamp`, `terraform/modules/traefik`) with clear separation between module definition and environment-specific instantiation. Validation scripts in `/scripts/storage/` for integration testing per Constitution Principle VII (Test-Driven Learning).

## Complexity Tracking

> **Not applicable** - No constitution violations. All principles satisfied without requiring justification for added complexity.

