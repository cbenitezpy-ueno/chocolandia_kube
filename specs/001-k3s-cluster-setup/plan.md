# Implementation Plan: K3s HA Cluster Setup - ChocolandiaDC

**Branch**: `001-k3s-cluster-setup` | **Date**: 2025-11-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-k3s-cluster-setup/spec.md`

## Summary

Provision a 4-node K3s high-availability cluster named "chocolandiadc" using Terraform as Infrastructure as Code. The cluster will consist of 3 control-plane nodes (master1, master2, master3) with embedded etcd for HA, and 1 worker node (nodo1). Prometheus and Grafana will be deployed for comprehensive cluster observability. This is a learning-focused implementation with emphasis on testing, documentation, and understanding distributed systems.

**Primary Requirement**: Create a production-grade HA Kubernetes cluster using K3s on bare-metal mini-PCs
**Technical Approach**: Terraform-driven provisioning with modular structure, automated testing at each phase, and comprehensive documentation

## Technical Context

**Language/Version**: HCL (Terraform) 1.6+, Bash scripting for validation
**Primary Dependencies**:
- Terraform 1.6+ (IaC orchestration)
- K3s latest stable (lightweight Kubernetes)
- Helm 3+ (chart deployment for monitoring stack)
- kubectl latest (cluster interaction)
- SSH (remote node provisioning)

**Storage**:
- Etcd embedded in K3s control-plane nodes (cluster state)
- Local storage for initial deployment (K3s default local-path provisioner)
- Optional: Longhorn for distributed block storage (future enhancement)

**Testing**:
- `terraform validate` and `terraform plan` (syntax and planning validation)
- Custom bash scripts for cluster health checks (kubectl-based)
- Smoke tests for workload deployment
- HA failure injection tests (node shutdown simulation)
- Integration tests for Prometheus/Grafana functionality

**Target Platform**: Linux mini-PCs (Ubuntu 22.04 LTS or Debian 12 recommended, RHEL-family compatible)

**Project Type**: Infrastructure (Terraform modules + validation scripts)

**Performance Goals**:
- Cluster bootstrap: < 15 minutes end-to-end
- API response time: < 2 seconds for `kubectl get nodes`
- Monitoring stack deployment: < 5 minutes
- Node join time: < 3 minutes per additional node

**Constraints**:
- Bare-metal hardware (4 mini-PCs with limited resources)
- Minimum 2 CPU cores, 4GB RAM, 20GB disk per node
- Local network only (no cloud provider dependencies)
- Terraform-only provisioning (no manual configuration)
- Must survive single node failure without service interruption

**Scale/Scope**:
- 4 physical nodes total
- 3 control-plane nodes (HA quorum)
- 1 worker node (expandable to 3 per spec)
- Support for ~20-30 lightweight pods in learning scenarios
- Metrics retention: 15 days minimum

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ I. Infrastructure as Code - Terraform First
**Status**: PASS
- All infrastructure will be defined in Terraform (.tf files)
- Terraform modules for cluster, nodes, monitoring
- State management configured (local backend initially, remote optional)
- No manual changes permitted

### ✅ II. GitOps Workflow
**Status**: PASS
- All changes committed to Git before apply
- Feature branch workflow (001-k3s-cluster-setup)
- Terraform plan reviewed before apply
- Rollback via Git revert + Terraform apply

### ✅ III. Container-First Development
**Status**: PASS
- K3s runs all components as containers
- Prometheus and Grafana deployed as containerized workloads
- Health checks (liveness/readiness) configured for monitoring stack
- Stateless design (cluster state in etcd, metrics in Prometheus)

### ✅ IV. Observability & Monitoring - Prometheus + Grafana Stack (NON-NEGOTIABLE)
**Status**: PASS
- Prometheus: scraping all nodes and K3s components (kubelet, apiserver, etcd)
- Grafana: pre-configured dashboards for cluster metrics
- Alerting configured for critical scenarios (node NotReady, disk space)
- Metrics retention: 15 days
- Structured logging to stdout/stderr

### ✅ V. Security Hardening
**Status**: PASS (with learning environment considerations)
- RBAC enabled (K3s default)
- Resource limits defined for Prometheus/Grafana
- Secrets via Kubernetes Secrets (etcd encryption enabled)
- SSH key-based authentication (no passwords)
- **Note**: Vulnerability scanning marked as SHOULD (learning environment)

### ✅ VI. High Availability (HA) Architecture
**Status**: PASS
- **Topology**: 3 control-plane + 1 worker (3+1 configuration)
- **Justification**: 3 control-plane nodes required for etcd quorum (minimum for fault tolerance)
- Embedded etcd in HA mode (3 replicas)
- K3s built-in load balancing for API endpoints
- Survives single node failure (tested via failure injection)

### ✅ VII. Test-Driven Learning (NON-NEGOTIABLE)
**Status**: PASS
- Terraform validation before apply
- Cluster health tests after each provisioning phase
- HA tests via node failure simulation
- Integration tests for monitoring stack
- All tests documented with learning objectives

### ✅ VIII. Documentation-First
**Status**: PASS
- This plan.md documents architecture decisions
- research.md will capture technology choices and rationale (Phase 0)
- Runbooks for cluster bootstrap, recovery, troubleshooting (Phase 1)
- Inline comments in Terraform code explaining why, not just what
- README files for each module directory

**Overall Constitution Compliance**: ✅ **PASS** - No violations, all gates satisfied

## Project Structure

### Documentation (this feature)

```text
specs/001-k3s-cluster-setup/
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0: Technology choices and best practices
├── data-model.md        # Phase 1: Cluster entities and configuration schema
├── quickstart.md        # Phase 1: Quick start guide for cluster deployment
├── contracts/           # Phase 1: Terraform variable schemas and outputs
│   └── cluster-config.yaml  # Cluster configuration contract
├── checklists/          # Quality validation checklists
│   └── requirements.md  # Specification quality checklist
└── tasks.md             # Phase 2: Generated by /speckit.tasks command
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   ├── k3s-cluster/          # Main cluster orchestration module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── k3s-node/             # Individual node provisioning module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── monitoring-stack/     # Prometheus + Grafana deployment module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── helm-values/
│       │   ├── prometheus-values.yaml
│       │   └── grafana-values.yaml
│       └── README.md
├── environments/
│   └── chocolandiadc/        # Main cluster configuration
│       ├── main.tf           # Root module composition
│       ├── variables.tf      # Cluster-specific variables
│       ├── terraform.tfvars  # Variable values (IPs, hostnames)
│       └── outputs.tf        # Cluster outputs (kubeconfig, endpoints)
└── README.md                 # Terraform usage guide

scripts/
├── validate-cluster.sh       # Cluster health validation script
├── test-ha-failover.sh       # HA failure injection test
├── deploy-test-workload.sh   # Smoke test for workload deployment
└── README.md                 # Testing scripts documentation

docs/
├── runbooks/
│   ├── cluster-bootstrap.md      # Step-by-step bootstrap guide
│   ├── adding-nodes.md           # How to add new nodes
│   ├── disaster-recovery.md      # Cluster recovery procedures
│   └── troubleshooting.md        # Common issues and solutions
├── adrs/                         # Architecture Decision Records
│   ├── 001-terraform-over-ansible.md
│   ├── 002-k3s-over-k8s.md
│   ├── 003-3plus1-topology.md
│   └── 004-prometheus-grafana-stack.md
└── README.md                     # Documentation index

tests/
├── integration/
│   ├── test-cluster-bootstrap.sh
│   ├── test-ha-quorum.sh
│   ├── test-monitoring-stack.sh
│   └── README.md
└── README.md
```

**Structure Decision**: Infrastructure project using Terraform modules for composability and reusability. Modular design allows:
- Independent testing of each component (cluster, nodes, monitoring)
- Easy expansion (add more worker nodes by adjusting count)
- Clear separation of concerns (cluster orchestration vs node provisioning vs monitoring)
- Learning-focused structure (each module is a self-contained learning unit)

The `terraform/` directory contains all IaC definitions, `scripts/` provides validation and testing tools, `docs/` holds learning materials and operational guides, and `tests/` contains automated integration tests.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitution violations detected. All complexity is justified by learning objectives and HA requirements.
