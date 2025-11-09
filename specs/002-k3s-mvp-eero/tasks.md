# Implementation Tasks: K3s MVP - 2-Node Cluster on Eero Network

**Feature**: 002-k3s-mvp-eero
**Status**: Ready for Implementation
**Created**: 2025-11-09
**Total Tasks**: 48

---

## Overview

This task list implements a minimal viable K3s cluster with 2 nodes (1 control-plane + 1 worker) on Eero mesh network. The implementation is phased to prioritize US1 (MVP cluster deployment) first, with US2 (monitoring) and US3 (migration docs) as optional enhancements.

**User Story Priority**:
- **US1** (P1 - MVP): Two-Node K3s Cluster Deployment - MUST HAVE
- **US2** (P2): Basic Monitoring with Prometheus + Grafana - SHOULD HAVE
- **US3** (P3): Future Expansion Preparation - NICE TO HAVE

**Implementation Strategy**: Deploy US1 first to unblock learning, then add US2 and US3 incrementally.

---

## Dependencies

**Critical Path** (blocks all user stories):
- Phase 1 (Setup) → Phase 2 (Foundational k3s-node module) → Phase 3 (US1 cluster deployment)

**Parallel Opportunities**:
- US2 (monitoring) and US3 (migration docs) can be developed in parallel after US1 is complete
- Tests can be written in parallel with implementation within each user story
- Documentation tasks can be done independently of code tasks

**External Dependencies**:
- 2 mini-PCs available with Ubuntu Server 22.04 LTS
- Eero mesh network operational with DHCP
- SSH keys configured on both nodes
- OpenTofu 1.6+ installed on operator laptop
- kubectl installed on operator laptop
- Internet connectivity via Eero for K3s binary/image downloads

---

## Phase 1: Project Setup (Tasks T001-T007)

**Purpose**: Initialize project structure, create directory layout, configure Git, set up OpenTofu workspace.

**Duration**: ~30 minutes

**Completion Criteria**: Directory structure exists, OpenTofu workspace initialized, .gitignore configured, basic README created.

### Directory Structure & Initialization

- [x] T001 [P1] [Setup] Create OpenTofu module directory structure at /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/
- [x] T002 [P1] [Setup] Create OpenTofu environment directory structure at /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/
- [x] T003 [P1] [Setup] Create scripts directory at /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/scripts/
- [x] T004 [P1] [Setup] Create validation scripts directory at /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/scripts/
- [x] T005 [P1] [Setup] Create tests directory at /Users/cbenitez/chocolandia_kube/tests/integration/
- [x] T006 [P1] [Setup] Create runbooks directory at /Users/cbenitez/chocolandia_kube/docs/runbooks/
- [x] T007 [P1] [Setup] Initialize OpenTofu workspace in /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/ (run `tofu init`)

### Git Configuration

- [x] T008 [P1] [Setup] Create .gitignore file at /Users/cbenitez/chocolandia_kube/.gitignore with entries for *.tfstate, *.tfstate.*, .terraform/, *.tfvars (sensitive data)
- [x] T009 [P1] [Setup] Create placeholder README.md at /Users/cbenitez/chocolandia_kube/terraform/README.md describing OpenTofu structure and MVP purpose
- [x] T010 [P1] [Setup] Commit initial project structure to branch 002-k3s-mvp-eero

---

## Phase 2: Foundational Infrastructure (Tasks T011-T022)

**Purpose**: Create reusable k3s-node OpenTofu module supporting both server and agent roles.

**Duration**: ~2 hours

**Completion Criteria**: k3s-node module can provision a K3s server or agent on a target node via SSH.

**Blocks**: All user stories (US1, US2, US3)

### k3s-node Module - Core Infrastructure

- [x] T011 [P1] [Foundational] Create /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/variables.tf defining input variables (hostname, role, ip_address, ssh_user, ssh_key_path, k3s_version, k3s_flags, cluster_token, server_url)
- [x] T012 [P1] [Foundational] Create /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/outputs.tf defining outputs (node_ip, kubeconfig_path, cluster_token_path)
- [x] T013 [P1] [Foundational] Create /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/main.tf with null_resource for SSH-based provisioning
- [x] T014 [P1] [Foundational] Add SSH connection block to /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/main.tf using ssh_user, ssh_key_path, ip_address variables

### k3s-node Module - Installation Scripts

- [x] T015 [P1] [Foundational] Create /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/scripts/install-k3s-server.sh for K3s server installation (single-server mode, SQLite, --cluster-init=false)
- [x] T016 [P1] [Foundational] Add --tls-san flag support to install-k3s-server.sh to accept dynamic IP addresses for API server certificate
- [x] T017 [P1] [Foundational] Add optional --disable flags support to install-k3s-server.sh (traefik, servicelb) based on variables
- [x] T018 [P1] [Foundational] Create /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/scripts/install-k3s-agent.sh for K3s agent installation with K3S_URL and K3S_TOKEN support
- [x] T019 [P1] [Foundational] Add node label support to install-k3s-agent.sh (e.g., --node-label role=worker)

### k3s-node Module - Provisioning Logic

- [x] T020 [P1] [Foundational] Add remote-exec provisioner to /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/main.tf for copying installation scripts to target node
- [x] T021 [P1] [Foundational] Add conditional logic to /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/main.tf to execute install-k3s-server.sh if role=server or install-k3s-agent.sh if role=agent
- [x] T022 [P1] [Foundational] Add validation to /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/variables.tf ensuring cluster_token and server_url are provided only when role=agent

---

## Phase 3: US1 - Two-Node K3s Cluster Deployment (Tasks T023-T036)

**Purpose**: Deploy functional 2-node cluster (master1 + nodo1) on Eero network.

**Duration**: ~2 hours

**Completion Criteria**: Both nodes Ready in `kubectl get nodes`, test workload deployed and running.

**Depends On**: Phase 2 (k3s-node module)

**MVP Milestone**: This phase completes the minimum viable cluster for learning.

### US1 Tests (Write Tests First)

- [x] T023 [P1] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/scripts/validate-single-node.sh to verify master1 is Ready and API accessible
- [x] T024 [P1] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/scripts/validate-cluster.sh to verify both nodes are Ready (master1 + nodo1)
- [x] T025 [P1] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/scripts/deploy-test-workload.sh to deploy nginx pod and verify Running status on nodo1

### US1 Environment Configuration

- [x] T026 [P1] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/providers.tf defining required_providers (null, local) and OpenTofu version constraint (>=1.6)
- [x] T027 [P1] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/variables.tf defining environment-specific variables (master1_ip, nodo1_ip, ssh_user, ssh_key_path, k3s_version, cluster_name)
- [x] T028 [P1] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars.example with sample values (192.168.4.10, 192.168.4.11, ubuntu, /Users/cbenitez/.ssh/id_rsa, v1.28.5+k3s1, chocolandiadc-mvp)
- [x] T029 [P1] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/outputs.tf defining outputs (kubeconfig_command, cluster_endpoint, validation_commands)

### US1 Cluster Deployment

- [x] T030 [P1] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/main.tf invoking k3s-node module for master1 as server (hostname=master1, role=server, ip=var.master1_ip, k3s_flags="--cluster-init=false --disable traefik --tls-san ${var.master1_ip}")
- [x] T031 [P1] [US1] Add null_resource to /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/main.tf to retrieve cluster token from master1 at /var/lib/rancher/k3s/server/token
- [x] T032 [P1] [US1] Add k3s-node module invocation to /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/main.tf for nodo1 as agent (hostname=nodo1, role=agent, ip=var.nodo1_ip, server_url="https://${var.master1_ip}:6443", cluster_token=<retrieved from T031>)
- [x] T033 [P1] [US1] Add depends_on relationship to /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/main.tf ensuring nodo1 provisioning waits for master1 token retrieval
- [x] T034 [P1] [US1] Add local_file resource to /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/main.tf to copy kubeconfig from master1 to /Users/cbenitez/.kube/config and replace 127.0.0.1 with master1 IP

### US1 Validation & Testing

- [x] T035 [P1] [US1] Run `tofu apply` in /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/ and verify cluster creation (capture output for documentation)
- [x] T036 [P1] [US1] Execute /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/scripts/validate-cluster.sh and /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/scripts/deploy-test-workload.sh to verify cluster functionality

---

## Phase 4: US2 - Basic Monitoring with Prometheus + Grafana (Tasks T037-T043)

**Purpose**: Deploy observability stack for cluster health monitoring.

**Duration**: ~1.5 hours

**Completion Criteria**: Prometheus scraping metrics from both nodes, Grafana dashboards accessible via NodePort.

**Depends On**: Phase 3 (US1 cluster operational)

**Optional Enhancement**: Can be deferred if rapid MVP unblocking is required.

### US2 Tests (Write Tests First)

- [x] T037 [P2] [US2] Create /Users/cbenitez/chocolandia_kube/tests/integration/test-prometheus.sh to verify Prometheus deployment and scrape targets (master1, nodo1 targets active)
- [x] T038 [P2] [US2] Create /Users/cbenitez/chocolandia_kube/tests/integration/test-grafana.sh to verify Grafana deployment and dashboard accessibility via NodePort 30000

### US2 Monitoring Stack Deployment

- [x] T039 [P2] [US2] Add Helm provider to /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/providers.tf with kubeconfig path from US1
- [x] T040 [P2] [US2] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/monitoring.tf with helm_release resource for kube-prometheus-stack chart (namespace=monitoring)
- [x] T041 [P2] [US2] Configure Prometheus scrape targets in /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/monitoring.tf for kubelet and node-exporter on both nodes
- [x] T042 [P2] [US2] Configure Grafana service in /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/monitoring.tf to expose via NodePort 30000 for Eero network access
- [x] T043 [P2] [US2] Add Grafana dashboard ConfigMaps to /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/monitoring.tf for CPU, memory, disk, network metrics

---

## Phase 5: US3 - Migration Preparation & Documentation (Tasks T044-T048)

**Purpose**: Document migration path to feature 001 (FortiGate + HA cluster).

**Duration**: ~1 hour

**Completion Criteria**: Migration runbook exists with tested backup procedures.

**Depends On**: Phase 3 (US1 cluster operational)

**Optional Enhancement**: Can be done in parallel with US2.

### US3 Migration Documentation

- [x] T044 [P3] [US3] Create /Users/cbenitez/chocolandia_kube/docs/runbooks/migration-to-feature-001.md documenting migration steps from Eero flat network to FortiGate VLANs
- [x] T045 [P3] [US3] Document in /Users/cbenitez/chocolandia_kube/docs/runbooks/migration-to-feature-001.md the backup procedures for SQLite datastore (/var/lib/rancher/k3s/server/db/state.db), OpenTofu state, and kubeconfig
- [x] T046 [P3] [US3] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/scripts/backup-state.sh to backup OpenTofu state and cluster token
- [x] T047 [P3] [US3] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/scripts/backup-cluster.sh to backup SQLite database and kubeconfig from master1
- [x] T048 [P3] [US3] Add migration checklist to /Users/cbenitez/chocolandia_kube/docs/runbooks/migration-to-feature-001.md with pre-migration validation steps (cluster health, workload backups, IP mappings)

---

## Phase 6: Polish & Cross-Cutting Concerns (Tasks T049-T055)

**Purpose**: Documentation, code quality, security hardening.

**Duration**: ~1 hour

**Completion Criteria**: Code formatted, validated, documented; security checklist complete.

**Depends On**: Phase 3 (US1 complete)

### Documentation

- [x] T049 [P1] [Polish] Validate /Users/cbenitez/chocolandia_kube/specs/002-k3s-mvp-eero/quickstart.md against actual deployment (update IPs, commands, expected outputs based on T035 results)
- [x] T050 [P2] [Polish] Create /Users/cbenitez/chocolandia_kube/docs/runbooks/troubleshooting-eero-network.md with common Eero connectivity issues (WiFi instability, DHCP IP changes, inter-node connectivity)
- [x] T051 [P1] [Polish] Update /Users/cbenitez/chocolandia_kube/terraform/README.md with usage instructions, prerequisites, and links to quickstart guide

### OpenTofu Code Quality

- [x] T052 [P1] [Polish] Run `tofu fmt -recursive` on /Users/cbenitez/chocolandia_kube/terraform/ to ensure consistent formatting
- [x] T053 [P1] [Polish] Run `tofu validate` on /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/ and /Users/cbenitez/chocolandia_kube/terraform/modules/k3s-node/ to verify configuration syntax

### Security Hardening

- [x] T054 [P1] [Polish] Create /Users/cbenitez/chocolandia_kube/docs/security-checklist.md documenting security considerations (SSH key permissions 0600, kubeconfig permissions 0600, cluster token not committed to Git, Eero flat network risks)
- [x] T055 [P1] [Polish] Verify .gitignore at /Users/cbenitez/chocolandia_kube/.gitignore excludes sensitive files (*.tfstate, *.tfvars, kubeconfig, *.pem, *.key)

---

## Summary Statistics

**Total Tasks**: 55
- Phase 1 (Setup): 10 tasks (~30 minutes)
- Phase 2 (Foundational): 12 tasks (~2 hours)
- Phase 3 (US1 - MVP): 14 tasks (~2 hours) **← CRITICAL PATH**
- Phase 4 (US2 - Monitoring): 7 tasks (~1.5 hours)
- Phase 5 (US3 - Migration): 5 tasks (~1 hour)
- Phase 6 (Polish): 7 tasks (~1 hour)

**By Priority**:
- P1 (MVP - US1): 37 tasks
- P2 (Monitoring - US2): 8 tasks
- P3 (Migration - US3): 5 tasks
- P1 (Cross-cutting Polish): 5 tasks

**Critical Path Duration**: ~4.5 hours (Phase 1 + Phase 2 + Phase 3)

**Full Implementation Duration**: ~8 hours (all phases)

---

## Execution Strategy

### Minimal Viable Product (US1 Only)

To deploy a functional cluster as quickly as possible:

1. Execute **Phase 1** (Setup) - 10 tasks
2. Execute **Phase 2** (Foundational k3s-node module) - 12 tasks
3. Execute **Phase 3** (US1 cluster deployment) - 14 tasks

**Result**: Functional 2-node cluster with test workload in ~4.5 hours.

**Stop here** if goal is immediate learning unblocking. Proceed to US2/US3 later.

### Full Implementation (US1 + US2 + US3)

For complete MVP with monitoring and migration documentation:

1. Execute **Phase 1** (Setup)
2. Execute **Phase 2** (Foundational)
3. Execute **Phase 3** (US1 - MVP cluster)
4. Execute **Phase 4** (US2 - Monitoring) **in parallel with** **Phase 5** (US3 - Migration docs)
5. Execute **Phase 6** (Polish)

**Result**: Production-ready learning cluster with observability and migration path in ~8 hours.

---

## Parallel Execution Opportunities

Tasks that can be executed in parallel:

- **T011-T019** (k3s-node module files can be created concurrently by different developers)
- **T023-T025** (test scripts can be written while T026-T034 OpenTofu code is being developed)
- **T037-T038** (US2 tests) and **T044-T048** (US3 docs) can be done in parallel after US1 is complete
- **T049-T051** (documentation) can be done independently of code tasks

---

## Next Steps After Implementation

1. **Test US1 thoroughly**: Deploy, teardown, redeploy cluster multiple times to validate reproducibility
2. **Add US2 incrementally**: Deploy monitoring stack once US1 is stable
3. **Document lessons learned**: Update quickstart.md and troubleshooting guides based on actual deployment experience
4. **Plan for feature 001 migration**: Review migration runbook (US3) and begin FortiGate repair tracking

---

## Notes

- **Local state**: OpenTofu state stored locally at `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfstate` (not committed to Git)
- **Eero static IPs**: Strongly recommend configuring static DHCP reservations in Eero app before starting (prevents IP changes during bootstrap)
- **Ethernet recommended**: Master1 should use Ethernet connection to Eero for API server stability
- **Constitution trade-offs**: This MVP intentionally violates Principle V (no FortiGate/VLANs) and Principle VI (no HA) for rapid learning unblocking; migration path to compliance documented in US3
- **Testing philosophy**: Tests written before implementation (Principle VII) to ensure validation scripts exist before cluster deployment
