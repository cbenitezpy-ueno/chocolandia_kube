# Implementation Plan: K3s MVP - 2-Node Cluster on Eero Network

**Branch**: `002-k3s-mvp-eero` | **Date**: 2025-11-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-k3s-mvp-eero/spec.md`

## Summary

This MVP deployment creates a minimal viable K3s cluster with 2 nodes (1 control-plane + 1 worker) connected directly to an Eero mesh network. It is designed as a temporary learning environment while FortiGate 100D is being repaired. The implementation focuses on rapid deployment, hands-on Kubernetes learning, and clear migration path to the full HA architecture defined in feature 001-k3s-cluster-setup.

**Primary Requirement**: Deploy functional K3s cluster on existing Eero network for immediate learning, with the ability to migrate to production FortiGate VLAN architecture when hardware is repaired.

**Technical Approach**: OpenTofu provisions 2 mini-PCs with K3s in single-server mode (SQLite datastore), basic Prometheus + Grafana monitoring, and local state management. No network segmentation, no HA control-plane, no remote backend—optimized for speed and simplicity.

## Technical Context

**Language/Version**: HCL (OpenTofu) 1.6+, Bash scripting for validation
**Primary Dependencies**: K3s v1.28+, OpenTofu 1.6+, kubectl, Helm
**Platform**: Ubuntu Server 22.04 LTS on mini-PCs (Lenovo/HP ProDesk)
**Network**: Eero mesh network (flat, no VLANs), DHCP subnet 192.168.4.0/24
**Testing**: Bash validation scripts, kubectl smoke tests, workload deployment tests
**Target Platform**: Bare metal (mini-PCs), Eero network connectivity (Ethernet preferred, WiFi supported)
**Project Type**: Infrastructure (OpenTofu modules + validation scripts)
**Performance Goals**: Cluster bootstrap < 10 minutes, test workload running < 60 seconds after node join
**Constraints**: Single control-plane (no HA), flat network (no FortiGate), local state (no remote backend), temporary architecture (migration to 001 required)
**Scale/Scope**: 2 nodes total (1 server + 1 agent), learning environment (not production)
**Storage**: SQLite datastore (embedded in K3s server), local OpenTofu state file, Kubernetes PersistentVolumes via local-path provisioner

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. OpenTofu First** | ✅ PASS | Using OpenTofu 1.6+ for all provisioning (SSH, K3s installation, Helm charts) |
| **II. GitOps Workflow** | ✅ PASS | Feature branch 002-k3s-mvp-eero, PR workflow, version control for all changes |
| **III. Container-First** | 🟡 PARTIAL | Infrastructure project (not containerized workloads yet); principle applies when deploying test applications |
| **IV. Prometheus + Grafana** | 🟡 DEFERRED | Planned for US2 (Phase 2); cluster deployment (US1) takes priority for MVP unblocking |
| **V. Security Hardening** | 🟡 PARTIAL | **VIOLATION: No FortiGate, no VLANs, flat Eero network**—acceptable for temporary learning environment; jump host pattern not applicable (flat network); SSH keys required |
| **VI. High Availability** | ❌ NOT MET | **DOCUMENTED TRADE-OFF: Single control-plane (no HA)**—SQLite datastore, single-server mode; acceptable for MVP learning; migration to 3-node HA cluster documented in US3 |
| **VII. Test-Driven Learning** | ✅ PASS | Bash validation scripts, `tofu validate`, connectivity tests, kubectl smoke tests, workload deployment validation |
| **VIII. Documentation-First** | ✅ PASS | Quickstart guide, runbooks, migration documentation (US3), troubleshooting guides, inline comments in OpenTofu code |
| **IX. Network-First Security** | ❌ NOT APPLICABLE | **BLOCKED: FortiGate offline**—no VLANs, no firewall, flat Eero network; this principle will be fulfilled when migrating to feature 001 |

**Compliance Summary**: 3 PASS, 2 PARTIAL, 2 NOT MET (documented trade-offs), 1 DEFERRED, 1 N/A. MVP intentionally sacrifices HA and network security for rapid learning unblocking. Migration path to full compliance documented in US3.

## Project Structure

### Documentation (this feature)

```text
specs/002-k3s-mvp-eero/
├── plan.md              # This file (/speckit.plan output)
├── research.md          # Phase 0 output (architectural decisions)
├── data-model.md        # Phase 1 output (entities and relationships)
├── quickstart.md        # Phase 1 output (operator onboarding guide)
├── contracts/           # Phase 1 output (configuration schemas)
│   ├── cluster-config.yaml
│   └── node-config.yaml
└── tasks.md             # Phase 2 output (/speckit.tasks - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── k3s-node/                 # Reusable module for K3s server/agent provisioning
│       ├── main.tf               # SSH provisioning, K3s installation
│       ├── variables.tf          # Node configuration (role, hostname, IP, K3s flags)
│       ├── outputs.tf            # Node IP, kubeconfig path, cluster token
│       └── scripts/
│           ├── install-k3s-server.sh   # K3s server installation (single-server mode, SQLite)
│           └── install-k3s-agent.sh    # K3s agent installation (join with token)
│
└── environments/
    └── chocolandiadc-mvp/        # MVP environment configuration
        ├── main.tf               # Cluster composition (1 server + 1 agent)
        ├── variables.tf          # Environment-specific variables (Eero network IPs)
        ├── outputs.tf            # Kubeconfig path, cluster endpoint, validation commands
        ├── terraform.tfvars      # Actual values (node IPs, SSH keys, hostnames)
        ├── terraform.tfstate     # Local state file (not committed to Git)
        └── scripts/
            ├── validate-cluster.sh      # Post-apply validation (nodes Ready, API accessible)
            ├── deploy-test-workload.sh  # Smoke test (nginx deployment)
            └── cleanup.sh               # Cluster teardown

tests/
└── integration/
    ├── test-cluster-bootstrap.sh       # End-to-end cluster creation test
    ├── test-workload-deployment.sh     # Application deployment test
    └── test-monitoring-stack.sh        # Prometheus + Grafana validation (Phase 2)

docs/
└── runbooks/
    ├── mvp-cluster-bootstrap.md        # Step-by-step cluster creation
    ├── troubleshooting-eero-network.md # Eero connectivity issues
    └── migration-to-feature-001.md     # Migration runbook (US3)
```

**Structure Decision**: Single project structure with OpenTofu modules. No backend/frontend (infrastructure-only). The `k3s-node` module is reusable for both server and agent roles, simplifying maintenance. Environment-specific configuration isolated in `environments/chocolandiadc-mvp/` for clear separation from future production environment (when feature 001 is deployed).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| **V. Security (no FortiGate/VLANs)** | FortiGate 100D has power supply failure requiring repair (several weeks estimated). Flat Eero network is the only available connectivity for mini-PCs. | Waiting for FortiGate repair would block all Kubernetes learning for weeks; this is a learning environment (not production) where temporary security reduction is acceptable. |
| **VI. High Availability (single control-plane)** | Single control-plane with SQLite datastore simplifies MVP and reduces resource consumption (1 node instead of 3). Sufficient for learning basic Kubernetes operations and workload deployment. | 3-node HA control-plane would consume all available mini-PCs (3 Lenovo + 1 HP ProDesk), leaving no worker capacity. Single-server mode allows 1 control-plane + 1 worker for actual workload testing. |
| **IX. Network-First (no firewall rules)** | No FortiGate available (hardware failure). Eero mesh network does not support VLAN segmentation or firewall rules. | Delaying cluster deployment until FortiGate is repaired would block learning for weeks. This MVP is explicitly temporary with documented migration path to full network security (feature 001). |

**Justification Summary**: All violations are hardware-constrained (FortiGate offline) or resource-optimized for learning (single control-plane preserves worker capacity). This is a phased approach: MVP now for immediate learning, full compliance later when FortiGate is repaired and migration to feature 001 is executed.
