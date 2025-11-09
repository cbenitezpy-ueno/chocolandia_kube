# Tasks: K3s HA Cluster Setup - ChocolandiaDC

**Input**: Design documents from `/specs/001-k3s-cluster-setup/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: This feature explicitly requires comprehensive testing as per Constitution Principle VII (Test-Driven Learning). All test tasks are MANDATORY.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

This is an infrastructure project using Terraform modules:
- Terraform code: `terraform/modules/`, `terraform/environments/chocolandiadc/`
- Testing scripts: `scripts/`
- Documentation: `docs/runbooks/`, `docs/adrs/`
- Integration tests: `tests/integration/`

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create project directory structure and initialize Terraform workspace

- [ ] T001 Create Terraform project structure per plan.md (terraform/modules/, terraform/environments/chocolandiadc/, scripts/, docs/, tests/)
- [ ] T002 Initialize Terraform backend configuration in terraform/environments/chocolandiadc/backend.tf (local state initially)
- [ ] T003 [P] Create .gitignore for Terraform (exclude terraform.tfstate, .terraform/, *.tfvars with sensitive data)
- [ ] T004 [P] Create .terraform-version file specifying Terraform 1.6+ requirement
- [ ] T005 [P] Create README.md in terraform/ directory with project overview and usage instructions
- [ ] T006 [P] Create terraform/modules/README.md explaining module organization

**Checkpoint**: Project structure ready for Terraform development

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Terraform modules and configuration that MUST be complete before provisioning any nodes

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Terraform Module Foundations

- [ ] T007 Create k3s-node module structure in terraform/modules/k3s-node/ (main.tf, variables.tf, outputs.tf)
- [ ] T008 Define k3s-node module variables in terraform/modules/k3s-node/variables.tf (hostname, ip_address, ssh_user, ssh_key_path, role, is_first_node, cluster_token)
- [ ] T009 Implement SSH connection provisioner in terraform/modules/k3s-node/main.tf (null_resource with remote-exec)
- [ ] T010 Implement K3s installation logic in terraform/modules/k3s-node/main.tf (control-plane vs worker installation commands)
- [ ] T011 Define k3s-node module outputs in terraform/modules/k3s-node/outputs.tf (node_id, node_status, kubeconfig for control-plane nodes)
- [ ] T012 Create terraform/modules/k3s-node/README.md documenting module usage and examples

### Cluster Orchestration Module

- [ ] T013 Create k3s-cluster module structure in terraform/modules/k3s-cluster/ (main.tf, variables.tf, outputs.tf)
- [ ] T014 Define k3s-cluster module variables in terraform/modules/k3s-cluster/variables.tf (cluster_name, k3s_version, control_plane_nodes, worker_nodes)
- [ ] T015 Implement cluster token generation logic in terraform/modules/k3s-cluster/main.tf (retrieve from first control-plane node)
- [ ] T016 Implement kubeconfig retrieval and processing in terraform/modules/k3s-cluster/main.tf (download from master1, update server URL)
- [ ] T017 Define k3s-cluster module outputs in terraform/modules/k3s-cluster/outputs.tf (cluster_name, api_endpoint, kubeconfig, cluster_token)
- [ ] T018 Create terraform/modules/k3s-cluster/README.md documenting cluster module architecture

### Environment Configuration

- [ ] T019 Create terraform/environments/chocolandiadc/variables.tf defining all required variables (cluster_name, k3s_version, control_plane_nodes, worker_nodes, monitoring config)
- [ ] T020 Create terraform/environments/chocolandiadc/terraform.tfvars.example as template with placeholder values (IPs, SSH user, hostnames)
- [ ] T021 Create terraform/environments/chocolandiadc/outputs.tf defining cluster outputs (api_endpoint, kubeconfig_path, grafana_admin_password)
- [ ] T022 Create terraform/environments/chocolandiadc/README.md with deployment instructions

**Checkpoint**: Terraform foundation ready - user story implementation can now begin sequentially

---

## Phase 3: User Story 1 - Initial Cluster Bootstrap (Priority: P1) 🎯 MVP

**Goal**: Deploy a single control-plane node (master1) with a working Kubernetes API

**Independent Test**: Execute `kubectl get nodes` and verify master1 appears as Ready; deploy a test pod and verify it reaches Running state

### Tests for User Story 1 ⚠️ MANDATORY

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T023 [P] [US1] Create validation script scripts/validate-single-node.sh to check master1 node Ready status
- [ ] T024 [P] [US1] Create smoke test script scripts/deploy-test-workload.sh to deploy and validate nginx pod

### Implementation for User Story 1

- [ ] T025 [US1] Create terraform/environments/chocolandiadc/main.tf calling k3s-cluster module with single control-plane node (master1 only)
- [ ] T026 [US1] Implement first node bootstrap logic in k3s-cluster module to install K3s with --cluster-init flag
- [ ] T027 [US1] Implement cluster token retrieval via SSH from /var/lib/rancher/k3s/server/node-token in k3s-cluster module
- [ ] T028 [US1] Implement kubeconfig download and local storage in terraform/environments/chocolandiadc/kubeconfig
- [ ] T029 [US1] Add terraform provisioner to wait for master1 node Ready status before completion
- [ ] T030 [US1] Write terraform/environments/chocolandiadc/terraform.tfvars with master1 configuration (IP: REPLACE_WITH_ACTUAL, hostname: master1)

**Checkpoint**: Single-node cluster operational - kubectl access verified, test pod deployed successfully

---

## Phase 4: User Story 2 - High Availability Control Plane (Priority: P2)

**Goal**: Add master2 and master3 to establish etcd quorum and HA capability

**Independent Test**: Shutdown master1, verify kubectl still works via master2/master3; verify etcd quorum is 2/3

### Tests for User Story 2 ⚠️ MANDATORY

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T031 [P] [US2] Create HA failover test script scripts/test-ha-failover.sh to simulate master1 failure and verify API availability
- [ ] T032 [P] [US2] Create etcd quorum validation script scripts/validate-etcd-quorum.sh to check 3/3 members and quorum status

### Implementation for User Story 2

- [ ] T033 [US2] Update terraform/environments/chocolandiadc/terraform.tfvars to add master2 and master3 configurations (IPs: REPLACE_WITH_ACTUAL)
- [ ] T034 [US2] Update terraform/environments/chocolandiadc/main.tf to provision master2 and master3 in parallel with depends_on master1
- [ ] T035 [US2] Implement additional control-plane node join logic in k3s-cluster module (--server flag with master1 IP and cluster token)
- [ ] T036 [US2] Add terraform provisioners to wait for all 3 control-plane nodes Ready status
- [ ] T037 [US2] Add terraform provisioner to verify etcd quorum established (3/3 members)
- [ ] T038 [US2] Update kubeconfig handling to use all 3 control-plane IPs for HA API access (optional: configure round-robin or load balancer)

**Checkpoint**: HA control-plane operational - all 3 masters Ready, etcd quorum verified, API survives master1 failure

---

## Phase 5: User Story 3 - Worker Node Addition (Priority: P3)

**Goal**: Add worker node (nodo1) for dedicated workload execution separate from control-plane

**Independent Test**: Deploy workload with node selector for workers, verify pod schedules on nodo1 not on master nodes

### Tests for User Story 3 ⚠️ MANDATORY

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T039 [P] [US3] Create worker node validation script scripts/validate-worker-nodes.sh to verify nodo1 is Ready with worker role
- [ ] T040 [P] [US3] Create workload scheduling test script scripts/test-worker-scheduling.sh to deploy pod with node affinity and verify scheduling on nodo1

### Implementation for User Story 3

- [ ] T041 [US3] Update terraform/environments/chocolandiadc/terraform.tfvars to add nodo1 configuration (IP: REPLACE_WITH_ACTUAL, hostname: nodo1)
- [ ] T042 [US3] Update terraform/environments/chocolandiadc/main.tf to provision nodo1 as worker with depends_on all control-plane nodes
- [ ] T043 [US3] Implement worker node join logic in k3s-node module (K3s agent installation with --server and --token flags)
- [ ] T044 [US3] Add terraform provisioner to wait for nodo1 node Ready status
- [ ] T045 [US3] Add optional terraform configuration to taint control-plane nodes (NoSchedule) to prevent workload pods on masters (optional based on preferences)

**Checkpoint**: Worker node operational - nodo1 Ready, workloads schedule on worker, full 4-node cluster functional

---

## Phase 6: User Story 4 - Monitoring Stack Deployment (Priority: P4)

**Goal**: Deploy Prometheus and Grafana for comprehensive cluster observability

**Independent Test**: Verify Prometheus scrapes all nodes and K3s components; verify Grafana dashboards load with real-time metrics

### Tests for User Story 4 ⚠️ MANDATORY

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T046 [P] [US4] Create Prometheus validation script scripts/validate-prometheus.sh to check all targets are up
- [ ] T047 [P] [US4] Create Grafana validation script scripts/validate-grafana.sh to verify Grafana API health and dashboard accessibility

### Implementation for User Story 4

- [ ] T048 [US4] Create monitoring-stack module structure in terraform/modules/monitoring-stack/ (main.tf, variables.tf, outputs.tf)
- [ ] T049 [US4] Define monitoring-stack module variables in terraform/modules/monitoring-stack/variables.tf (namespace, prometheus_retention, prometheus_storage_size, grafana_admin_user)
- [ ] T050 [US4] Implement Helm provider configuration in terraform/modules/monitoring-stack/main.tf (using kubeconfig from cluster module)
- [ ] T051 [US4] Implement Prometheus deployment in terraform/modules/monitoring-stack/main.tf (kube-prometheus-stack Helm chart)
- [ ] T052 [US4] Create Prometheus values file in terraform/modules/monitoring-stack/helm-values/prometheus-values.yaml (retention, storage, scrape configs)
- [ ] T053 [US4] Implement Grafana deployment in terraform/modules/monitoring-stack/main.tf (included in kube-prometheus-stack chart)
- [ ] T054 [US4] Create Grafana values file in terraform/modules/monitoring-stack/helm-values/grafana-values.yaml (admin user, dashboards, data sources)
- [ ] T055 [US4] Configure Prometheus to scrape K3s components in helm-values/prometheus-values.yaml (kubelet, apiserver, etcd, scheduler, controller-manager)
- [ ] T056 [US4] Configure Grafana dashboards in helm-values/grafana-values.yaml (import Kubernetes cluster overview, etcd, node exporter dashboards)
- [ ] T057 [US4] Define monitoring-stack module outputs in terraform/modules/monitoring-stack/outputs.tf (prometheus_url, grafana_url, grafana_admin_password)
- [ ] T058 [US4] Update terraform/environments/chocolandiadc/main.tf to call monitoring-stack module with depends_on all nodes
- [ ] T059 [US4] Add terraform provisioner to wait for Prometheus and Grafana pods Running status
- [ ] T060 [US4] Create terraform/modules/monitoring-stack/README.md documenting monitoring stack configuration

**Checkpoint**: Monitoring operational - Prometheus scraping all targets, Grafana dashboards display cluster metrics

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, testing infrastructure, and operational guides

### Documentation

- [ ] T061 [P] Create Architecture Decision Record docs/adrs/001-terraform-over-ansible.md documenting why Terraform was chosen
- [ ] T062 [P] Create Architecture Decision Record docs/adrs/002-k3s-over-k8s.md documenting why K3s was chosen
- [ ] T063 [P] Create Architecture Decision Record docs/adrs/003-3plus1-topology.md documenting 3 control-plane + 1 worker topology rationale
- [ ] T064 [P] Create Architecture Decision Record docs/adrs/004-prometheus-grafana-stack.md documenting monitoring stack choice
- [ ] T065 [P] Create runbook docs/runbooks/cluster-bootstrap.md with step-by-step bootstrap instructions
- [ ] T066 [P] Create runbook docs/runbooks/adding-nodes.md with instructions to add worker nodes (nodo2, nodo3)
- [ ] T067 [P] Create runbook docs/runbooks/disaster-recovery.md with cluster recovery procedures
- [ ] T068 [P] Create runbook docs/runbooks/troubleshooting.md with common issues and solutions
- [ ] T069 [P] Create docs/README.md as documentation index

### Validation & Testing Infrastructure

- [ ] T070 Create comprehensive validation script scripts/validate-cluster.sh combining all validation checks (nodes, etcd, monitoring)
- [ ] T071 Create integration test suite in tests/integration/test-cluster-bootstrap.sh validating full cluster bootstrap
- [ ] T072 Create integration test in tests/integration/test-ha-quorum.sh validating etcd HA and failover
- [ ] T073 Create integration test in tests/integration/test-monitoring-stack.sh validating Prometheus and Grafana functionality
- [ ] T074 Create tests/README.md documenting test execution and CI/CD integration
- [ ] T075 Create scripts/README.md documenting all validation and testing scripts

### Terraform Best Practices

- [ ] T076 Add terraform fmt validation check to scripts/validate-cluster.sh
- [ ] T077 Add terraform validate check to scripts/validate-cluster.sh
- [ ] T078 Configure Terraform state backup automation in terraform/environments/chocolandiadc/main.tf (local_file resource for backups)
- [ ] T079 Add .editorconfig file to enforce consistent code formatting (Terraform, YAML, Bash)

### Security & Compliance

- [ ] T080 Document SSH key management procedures in docs/runbooks/cluster-bootstrap.md
- [ ] T081 Add kubeconfig file permissions enforcement (chmod 0600) in k3s-cluster module
- [ ] T082 Configure RBAC validation in scripts/validate-cluster.sh (verify default roles/bindings)
- [ ] T083 Add resource limits validation to scripts/validate-cluster.sh (verify Prometheus/Grafana limits applied)

### Quickstart Validation

- [ ] T084 Execute quickstart.md end-to-end on test environment and validate all steps
- [ ] T085 Update quickstart.md with any corrections or clarifications from validation
- [ ] T086 Create quickstart validation checklist in tests/quickstart-validation-checklist.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - can start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 completion - BLOCKS all user stories
- **Phase 3 (User Story 1)**: Depends on Phase 2 completion - No dependencies on other stories
- **Phase 4 (User Story 2)**: Depends on Phase 3 completion (requires master1 as bootstrap node)
- **Phase 5 (User Story 3)**: Depends on Phase 4 completion (requires control-plane HA for production-grade cluster)
- **Phase 6 (User Story 4)**: Depends on Phase 5 completion (requires full cluster with compute capacity)
- **Phase 7 (Polish)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Deploys master1 (MVP)
- **User Story 2 (P2)**: DEPENDS on User Story 1 - Requires master1 as bootstrap node for master2/master3 to join
- **User Story 3 (P3)**: DEPENDS on User Story 2 - Worker should join HA cluster (not single-node cluster)
- **User Story 4 (P4)**: DEPENDS on User Story 3 - Monitoring requires full cluster for comprehensive metrics

**NOTE**: Unlike typical user stories that are independent, this infrastructure project has sequential dependencies because:
- Master1 must exist before additional control-plane nodes can join (etcd cluster initialization)
- HA control-plane should be established before adding workers (production best practice)
- Monitoring stack requires compute capacity (all nodes operational)

### Within Each User Story

- Tests MUST be written and FAIL before implementation (Test-Driven Learning principle)
- Terraform modules before environment configuration
- Module variables/outputs before main.tf implementation
- Validation provisioners after resource creation
- Documentation after implementation

### Parallel Opportunities

**Phase 1 (Setup)**: T003, T004, T005, T006 can run in parallel (independent file creation)

**Phase 2 (Foundational)**:
- T007-T012 (k3s-node module) can run in parallel with T013-T018 (k3s-cluster module)
- T019-T022 (environment config) depend on modules being complete

**User Story 1**: T023, T024 (test scripts) can run in parallel before implementation

**User Story 2**: T031, T032 (test scripts) can run in parallel before implementation

**User Story 3**: T039, T040 (test scripts) can run in parallel before implementation

**User Story 4**:
- T046, T047 (test scripts) can run in parallel before implementation
- T052, T054 (Helm values files) can run in parallel during implementation

**Phase 7 (Polish)**:
- All ADRs (T061-T064) can run in parallel
- All runbooks (T065-T069) can run in parallel
- T070-T075 (testing infrastructure) sequential (tests depend on previous tests)

---

## Parallel Example: User Story 4 (Monitoring Stack)

```bash
# Launch test scripts in parallel (before implementation):
Task: "Create Prometheus validation script scripts/validate-prometheus.sh"
Task: "Create Grafana validation script scripts/validate-grafana.sh"

# During implementation, Helm values files can be created in parallel:
Task: "Create Prometheus values file terraform/modules/monitoring-stack/helm-values/prometheus-values.yaml"
Task: "Create Grafana values file terraform/modules/monitoring-stack/helm-values/grafana-values.yaml"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (6 tasks, ~30 minutes)
2. Complete Phase 2: Foundational (16 tasks, ~2-3 hours)
3. Complete Phase 3: User Story 1 (8 tasks, ~1-2 hours)
4. **STOP and VALIDATE**:
   - Run scripts/validate-single-node.sh (master1 Ready)
   - Run scripts/deploy-test-workload.sh (nginx pod Running)
   - Manually test kubectl access
5. **MVP DEPLOYED**: Single-node K3s cluster operational

**MVP Scope**: 30 tasks, ~4-6 hours total
**Deliverable**: Functional single-node Kubernetes cluster with kubectl access

### Incremental Delivery

1. **MVP (US1)**: Single-node cluster → Validate → Demo
   - Deliverable: Working Kubernetes API, kubectl access, basic workload deployment

2. **MVP + HA (US1+US2)**: Add HA control-plane → Validate → Demo
   - Deliverable: Fault-tolerant cluster, etcd quorum, API survives node failure
   - Validation: Shutdown master1, verify cluster operational

3. **Full Cluster (US1+US2+US3)**: Add worker node → Validate → Demo
   - Deliverable: Production-grade 4-node cluster, workload/control-plane separation
   - Validation: Schedule workloads on worker, verify no pods on masters

4. **Complete (US1+US2+US3+US4)**: Add monitoring → Validate → Demo
   - Deliverable: Fully observable cluster, Prometheus metrics, Grafana dashboards
   - Validation: Check all Prometheus targets up, load Grafana dashboards

5. **Production-Ready (All + Polish)**: Documentation, tests, runbooks → Validate → Handoff
   - Deliverable: Deployable, documented, tested infrastructure
   - Validation: Run full integration test suite, execute quickstart guide

### Sequential Execution (Solo Operator)

**Recommended approach for learning**:

1. **Week 1**: Setup + Foundational + US1 (MVP)
   - Understand Terraform basics, K3s installation, single-node cluster

2. **Week 2**: US2 (HA Control Plane)
   - Learn etcd, distributed consensus, high availability

3. **Week 3**: US3 (Worker Nodes) + US4 (Monitoring)
   - Learn workload scheduling, Prometheus, Grafana

4. **Week 4**: Polish (Documentation, Testing)
   - Operational readiness, runbooks, troubleshooting skills

**Total Time Estimate**: 4 weeks part-time (~40 hours total)

### Parallel Team Strategy

**Not applicable** - This is a single-operator learning project. However, if working with a team:

1. Team completes Setup + Foundational together (pair programming recommended)
2. Sequential user story implementation (dependencies prevent parallelization)
3. Polish phase can be parallelized (different team members write different ADRs/runbooks)

---

## Notes

- **[P] tasks**: Different files, no dependencies - safe to parallelize
- **[Story] label**: Maps task to specific user story for traceability
- **Sequential dependencies**: User stories MUST be completed in order (US1 → US2 → US3 → US4)
- **Test-First**: All test scripts must be written before implementation tasks (TDD approach)
- **Commit frequently**: Commit after each task or logical group (e.g., after completing a module)
- **Validate at checkpoints**: Run validation scripts after each user story before proceeding
- **Document as you go**: Update ADRs and runbooks during implementation, not after
- **IPs and SSH config**: Update terraform.tfvars with actual mini-PC IPs before terraform apply
- **Terraform workflow**: Always run `terraform fmt`, `terraform validate`, `terraform plan` before `terraform apply`
- **State backup**: Manually backup terraform.tfstate after each successful apply
- **Learning focus**: This is a learning project - take time to understand each component, read K3s docs, experiment with failures

---

## Success Criteria Checklist

After completing all tasks, verify against spec.md success criteria:

- [ ] **SC-001**: Cluster bootstrap completed in < 15 minutes (Phase 3 complete)
- [ ] **SC-002**: All 4 nodes Ready within 5 minutes of last node join (Phase 5 complete)
- [ ] **SC-003**: API responsive < 2s after master1 shutdown (Phase 4 HA test)
- [ ] **SC-004**: Prometheus scraping all nodes 100% (Phase 6 complete)
- [ ] **SC-005**: Grafana dashboards load < 3s (Phase 6 complete)
- [ ] **SC-006**: Test workload Running < 60s (Phase 3 smoke test)
- [ ] **SC-007**: Cluster survives master1 shutdown (Phase 4 HA test)
- [ ] **SC-008**: `terraform plan` shows no drift (validate after Phase 6)
- [ ] **SC-009**: kubectl works without manual config (Phase 3 kubeconfig)
- [ ] **SC-010**: `terraform destroy` and `terraform apply` reproduces cluster (validate after Phase 7)
- [ ] **SC-011**: Recovery runbook executable < 30 min (Phase 7, T067)
- [ ] **SC-012**: Monitoring alerts fire < 2 min for NotReady nodes (Phase 6, Prometheus alerting)

---

## Task Summary

**Total Tasks**: 86
- Phase 1 (Setup): 6 tasks
- Phase 2 (Foundational): 16 tasks
- Phase 3 (User Story 1 - MVP): 8 tasks (2 tests + 6 implementation)
- Phase 4 (User Story 2 - HA): 8 tasks (2 tests + 6 implementation)
- Phase 5 (User Story 3 - Worker): 7 tasks (2 tests + 5 implementation)
- Phase 6 (User Story 4 - Monitoring): 15 tasks (2 tests + 13 implementation)
- Phase 7 (Polish): 26 tasks (documentation, testing, validation)

**Parallel Opportunities**: 32 tasks marked [P] (37% of total)

**MVP Scope**: 30 tasks (Phases 1-3)
**HA Scope**: 38 tasks (Phases 1-4)
**Full Cluster**: 45 tasks (Phases 1-5)
**Complete**: 86 tasks (All phases)

**Estimated Time**:
- MVP (Phases 1-3): 4-6 hours
- HA (Phases 1-4): 6-9 hours
- Full Cluster (Phases 1-5): 8-12 hours
- Complete (All phases): 30-40 hours total

Ready for implementation via `/speckit.implement` or manual execution following user story priorities.
