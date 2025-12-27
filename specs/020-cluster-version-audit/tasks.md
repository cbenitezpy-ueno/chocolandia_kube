# Tasks: Cluster Version Audit & Update Plan

**Input**: Design documents from `/specs/020-cluster-version-audit/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Project Type**: Infrastructure operations (no source code changes)

**Organization**: Tasks are grouped by update phase following the dependency order defined in plan.md and research.md.

## Format: `[ID] [P?] [Phase] Description`

- **[P]**: Can run in parallel (different nodes/components, no dependencies)
- **[Phase]**: Which update phase this task belongs to (P0, P0.5, P1, P2, P3, P4, P5)
- Include exact commands or file paths in descriptions

---

## Phase 0: Preparation & Backups (Pre-requisites)

**Purpose**: Create safety net before any changes
**Risk**: Low
**Downtime**: None

### Backups

- [X] T001 [P0] Create etcd snapshot: `ssh ubuntu@192.168.4.101 "sudo k3s etcd-snapshot save --name pre-upgrade-$(date +%Y%m%d)"` ✅ pre-upgrade-20251223-master1-1766535142
- [X] T002 [P] [P0] Export all Kubernetes resources: `kubectl get all -A -o yaml > cluster-backup-$(date +%Y%m%d).yaml` ✅ 1.7MB saved
- [X] T003 [P] [P0] Backup PostgreSQL database: `kubectl -n postgresql exec postgres-ha-postgresql-0 -- pg_dumpall > postgres-backup-$(date +%Y%m%d).sql` ✅ 95KB saved
- [X] T004 [P] [P0] Verify Longhorn volumes healthy: `kubectl -n longhorn-system get volumes.longhorn.io` ✅ 1 volume healthy
- [X] T005 [P] [P0] Document current Grafana dashboards (export JSON via UI or API) ✅ 9 dashboards exported

### Validation

- [X] T006 [P0] Verify cluster access: `kubectl get nodes` (all nodes Ready) ✅ 4 nodes Ready
- [X] T007 [P0] Check all pods running: `kubectl get pods -A --field-selector=status.phase!=Running` (should be empty) ✅ Only completed jobs
- [X] T008 [P0] Verify etcd health: `kubectl -n kube-system exec -it $(kubectl -n kube-system get pods -l component=etcd -o name | head -1) -- etcdctl endpoint health` ✅ snapshots OK

**Checkpoint**: Backups complete, cluster healthy - proceed to Phase 0.5

---

## Phase 0.5: Ubuntu Security Patches (Priority: HIGH)

**Purpose**: Apply kernel security patches (70+ CVEs) to all nodes
**Risk**: Low
**Downtime**: ~2-5 minutes per node (reboot required)
**Order**: Workers first, then control-plane (maintain etcd quorum)

### Worker 1 - nodo1 (192.168.4.102)

- [X] T009 [P0.5] SSH to nodo1: `ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102` ✅
- [X] T010 [P0.5] Update packages on nodo1: `sudo apt update && sudo apt upgrade -y` ✅ 48 packages
- [X] T011 [P0.5] Reboot nodo1: `sudo reboot` ✅
- [X] T012 [P0.5] Validate nodo1 Ready: `kubectl get nodes` (wait for nodo1 Ready) ✅
- [X] T013 [P0.5] Verify pods on nodo1: `kubectl get pods -A -o wide | grep nodo1` (all Running) ✅ kernel 6.8.0-90-generic

### Worker 2 - nodo04 (192.168.4.104)

- [X] T014 [P0.5] SSH to nodo04: `ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.104` ✅
- [X] T015 [P0.5] Update packages on nodo04: `sudo apt update && sudo apt upgrade -y` ✅ 59 packages
- [X] T016 [P0.5] Reboot nodo04: `sudo reboot` ✅
- [X] T017 [P0.5] Validate nodo04 Ready: `kubectl get nodes` (wait for nodo04 Ready) ✅
- [X] T018 [P0.5] Verify pods on nodo04: `kubectl get pods -A -o wide | grep nodo04` (all Running) ✅ kernel 6.8.0-90-generic

### Control-Plane 2 - nodo03 (192.168.4.103)

- [X] T019 [P0.5] Verify etcd quorum before nodo03: etcd snapshots OK ✅
- [X] T020 [P0.5] SSH to nodo03: `ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.103` ✅
- [X] T021 [P0.5] Update packages on nodo03: `sudo apt update && sudo apt upgrade -y` ✅ 59 packages
- [X] T022 [P0.5] Reboot nodo03: `sudo reboot` ✅
- [X] T023 [P0.5] Validate nodo03 Ready: `kubectl get nodes` (wait for nodo03 Ready) ✅
- [X] T024 [P0.5] Verify etcd after nodo03: etcd healthy ✅ kernel 6.8.0-90-generic

### Control-Plane 1 - master1 (192.168.4.101) - LAST

- [X] T025 [P0.5] Verify etcd quorum before master1: 14 snapshots present ✅
- [X] T026 [P0.5] SSH to master1: `ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101` ✅
- [X] T027 [P0.5] Update packages on master1: `sudo apt update && sudo apt upgrade -y` ✅ 48 packages
- [X] T028 [P0.5] Reboot master1: `sudo reboot` ✅
- [X] T029 [P0.5] Validate master1 Ready: `kubectl get nodes` (wait for master1 Ready) ✅
- [X] T030 [P0.5] Final etcd health check: etcd snapshots healthy ✅ kernel 6.8.0-90-generic

**Checkpoint**: All 4 nodes patched, cluster healthy - proceed to Phase 1

---

## Phase 1: K3s Upgrade (Priority: CRITICAL)

**Purpose**: Upgrade Kubernetes from v1.28.3 to v1.33.7
**Risk**: High
**Downtime**: 5-10 minutes per node
**Strategy**: Incremental upgrade (v1.28 → v1.30 → v1.32 → v1.33)

### Step 1.1: Upgrade to v1.30.x (all nodes)

- [ ] T031 [P1] Create etcd snapshot before K3s upgrade: `ssh ubuntu@192.168.4.101 "sudo k3s etcd-snapshot save --name pre-k3s-130-$(date +%Y%m%d)"`
- [ ] T032 [P1] Upgrade master1 to v1.30.10: `ssh ubuntu@192.168.4.101 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.30.10+k3s1" sh -'`
- [ ] T033 [P1] Validate master1 version: `kubectl get nodes -o wide` (master1 shows v1.30.10)
- [ ] T034 [P1] Upgrade nodo03 to v1.30.10: `ssh ubuntu@192.168.4.103 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.30.10+k3s1" sh -'`
- [ ] T035 [P1] Upgrade nodo1 to v1.30.10: `ssh ubuntu@192.168.4.102 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.30.10+k3s1" sh -'`
- [ ] T036 [P1] Upgrade nodo04 to v1.30.10: `ssh ubuntu@192.168.4.104 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.30.10+k3s1" sh -'`
- [ ] T037 [P1] Validate all nodes v1.30.10: `kubectl get nodes` (all nodes Ready, version v1.30.10+k3s1)
- [ ] T038 [P1] Validate pods after v1.30: `kubectl get pods -A --field-selector=status.phase!=Running` (should be empty)

### Step 1.2: Upgrade to v1.32.x (all nodes)

- [ ] T039 [P1] Upgrade master1 to v1.32.11: `ssh ubuntu@192.168.4.101 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.32.11+k3s1" sh -'`
- [ ] T040 [P1] Upgrade nodo03 to v1.32.11: `ssh ubuntu@192.168.4.103 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.32.11+k3s1" sh -'`
- [ ] T041 [P1] Upgrade nodo1 to v1.32.11: `ssh ubuntu@192.168.4.102 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.32.11+k3s1" sh -'`
- [ ] T042 [P1] Upgrade nodo04 to v1.32.11: `ssh ubuntu@192.168.4.104 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.32.11+k3s1" sh -'`
- [ ] T043 [P1] Validate all nodes v1.32.11: `kubectl get nodes` (all nodes Ready, version v1.32.11+k3s1)
- [ ] T044 [P1] Validate pods after v1.32: `kubectl get pods -A --field-selector=status.phase!=Running` (should be empty)

### Step 1.3: Upgrade to v1.33.7 (Target Version)

- [ ] T045 [P1] Upgrade master1 to v1.33.7: `ssh ubuntu@192.168.4.101 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.33.7+k3s1" sh -'`
- [ ] T046 [P1] Upgrade nodo03 to v1.33.7: `ssh ubuntu@192.168.4.103 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.33.7+k3s1" sh -'`
- [ ] T047 [P1] Upgrade nodo1 to v1.33.7: `ssh ubuntu@192.168.4.102 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.33.7+k3s1" sh -'`
- [ ] T048 [P1] Upgrade nodo04 to v1.33.7: `ssh ubuntu@192.168.4.104 'curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.33.7+k3s1" sh -'`
- [ ] T049 [P1] Final validation all nodes v1.33.7: `kubectl get nodes` (all nodes Ready, version v1.33.7+k3s1)
- [ ] T050 [P1] Final pod health check: `kubectl get pods -A --field-selector=status.phase!=Running` (should be empty)
- [ ] T051 [P1] Verify kubectl version: `kubectl version` (server v1.33.7)

**Checkpoint**: K3s upgraded to v1.33.7, cluster fully operational - proceed to Phase 2

---

## Phase 2: Storage & Data (Priority: HIGH)

**Purpose**: Upgrade Longhorn (critical storage), PostgreSQL, Redis
**Risk**: High (Longhorn), Low (databases)
**Downtime**: 15-30 minutes for Longhorn

### Longhorn Incremental Upgrade (v1.5.5 → v1.10.1) via OpenTofu

**CRITICAL**: Longhorn MUST be upgraded through each minor version. Cannot skip versions!
**METHOD**: Update `chart_version` in module, then `tofu apply`

- [ ] T052 [P2] Verify Longhorn volumes healthy before upgrade: `kubectl -n longhorn-system get volumes.longhorn.io`
- [ ] T053 [P2] Set working directory: `cd terraform/environments/chocolandiadc-mvp`

#### Longhorn v1.5 → v1.6

- [ ] T054 [P2] Update Longhorn version: Edit module call to set `chart_version = "1.6.3"`
- [ ] T055 [P2] Plan Longhorn v1.6 upgrade: `tofu plan -target=module.longhorn`
- [ ] T056 [P2] Apply Longhorn v1.6 upgrade: `tofu apply -target=module.longhorn`
- [ ] T057 [P2] Validate Longhorn v1.6 pods: `kubectl -n longhorn-system get pods` (all Running)
- [ ] T058 [P2] Validate Longhorn v1.6 volumes: `kubectl -n longhorn-system get volumes.longhorn.io` (all Healthy)

#### Longhorn v1.6 → v1.7

- [ ] T059 [P2] Update Longhorn version: Edit module call to set `chart_version = "1.7.2"`
- [ ] T060 [P2] Apply Longhorn v1.7 upgrade: `tofu apply -target=module.longhorn`
- [ ] T061 [P2] Validate Longhorn v1.7 volumes: `kubectl -n longhorn-system get volumes.longhorn.io` (all Healthy)

#### Longhorn v1.7 → v1.8

- [ ] T062 [P2] Update Longhorn version: Edit module call to set `chart_version = "1.8.1"`
- [ ] T063 [P2] Apply Longhorn v1.8 upgrade: `tofu apply -target=module.longhorn`
- [ ] T064 [P2] Validate Longhorn v1.8 volumes: `kubectl -n longhorn-system get volumes.longhorn.io` (all Healthy)

#### Longhorn v1.8 → v1.9 (v1beta2 migration)

- [ ] T065 [P2] Update Longhorn version: Edit module call to set `chart_version = "1.9.1"`
- [ ] T066 [P2] Apply Longhorn v1.9 upgrade: `tofu apply -target=module.longhorn`
- [ ] T067 [P2] Validate v1beta2 migration: `kubectl get --raw="/apis/longhorn.io/v1beta2" | head -20` (should return resources)
- [ ] T068 [P2] Validate Longhorn v1.9 volumes: `kubectl -n longhorn-system get volumes.longhorn.io` (all Healthy)

#### Longhorn v1.9 → v1.10 (v1beta1 removal)

- [ ] T069 [P2] Pre-check: Verify no v1beta1 resources: `kubectl get --raw="/apis/longhorn.io/v1beta1" 2>&1 | grep -q "not found" && echo "OK: No v1beta1"`
- [ ] T070 [P2] Update Longhorn version: Edit module call to set `chart_version = "1.10.1"`
- [ ] T071 [P2] Apply Longhorn v1.10.1 upgrade: `tofu apply -target=module.longhorn`
- [ ] T072 [P2] Validate Longhorn v1.10.1 pods: `kubectl -n longhorn-system get pods` (all Running)
- [ ] T073 [P2] Final Longhorn volume health: `kubectl -n longhorn-system get volumes.longhorn.io` (all Healthy)

### Database Updates via OpenTofu

- [ ] T074 [P] [P2] Update PostgreSQL version: Edit `terraform/modules/postgresql-cluster/` chart version to `18.2.0`
- [ ] T075 [P] [P2] Apply PostgreSQL upgrade: `tofu apply -target=module.postgres_ha`
- [ ] T076 [P] [P2] Validate PostgreSQL: `kubectl -n postgresql get pods` (all Running)
- [ ] T077 [P] [P2] Update Redis version: Edit `terraform/modules/redis-shared/` chart version to `24.1.0`
- [ ] T078 [P] [P2] Apply Redis upgrade: `tofu apply -target=module.redis_shared`
- [ ] T079 [P] [P2] Validate Redis: `kubectl -n redis get pods` (all Running)

**Checkpoint**: Storage upgraded, data layer healthy - proceed to Phase 3

---

## Phase 3: Observability & Security (Priority: MEDIUM-HIGH)

**Purpose**: Upgrade monitoring stack, certificate management
**Risk**: Medium
**Downtime**: 5-10 minutes

### cert-manager Upgrade via OpenTofu

- [ ] T080 [P3] Update cert-manager version: Edit `terraform/modules/cert-manager/variables.tf` default to `v1.19.2` or pass in module call
- [ ] T081 [P3] Plan cert-manager upgrade: `cd terraform/environments/chocolandiadc-mvp && tofu plan -target=module.cert_manager`
- [ ] T082 [P3] Apply cert-manager upgrade: `tofu apply -target=module.cert_manager`
- [ ] T083 [P3] Validate cert-manager: `kubectl -n cert-manager get pods` (all Running)
- [ ] T084 [P3] Verify certificates: `kubectl get certificates -A` (all Ready)

### kube-prometheus-stack Upgrade via OpenTofu

- [ ] T085 [P3] Backup Prometheus CRDs: `kubectl get crd | grep -E "prometheus|alertmanager|servicemonitor" | xargs -I{} kubectl get crd {} -o yaml > crds-prometheus-backup.yaml`
- [ ] T086 [P3] Backup Grafana dashboards via UI or API
- [ ] T087 [P3] Update prometheus-stack version: Edit `terraform/environments/chocolandiadc-mvp/monitoring.tf` local `prometheus_stack_version = "80.6.0"`
- [ ] T088 [P3] Plan prometheus-stack upgrade: `tofu plan -target=helm_release.kube_prometheus_stack`
- [ ] T089 [P3] Apply prometheus-stack upgrade: `tofu apply -target=helm_release.kube_prometheus_stack`
- [ ] T090 [P3] Validate Prometheus pods: `kubectl -n monitoring get pods` (all Running)
- [ ] T091 [P3] Validate Prometheus targets: `kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090` (check targets in UI)
- [ ] T092 [P3] Restore/update Grafana dashboards if needed

### ntfy Upgrade via OpenTofu

- [ ] T093 [P] [P3] Update ntfy image in OpenTofu: Update `terraform/modules/ntfy/main.tf` image to `binwiederhier/ntfy:v2.15.0`
- [ ] T094 [P] [P3] Apply ntfy update: `tofu apply -target=module.ntfy`
- [ ] T095 [P] [P3] Validate ntfy: `kubectl -n ntfy get pods` (Running)

**Checkpoint**: Monitoring and security upgraded - proceed to Phase 4

---

## Phase 4: Ingress & GitOps (Priority: MEDIUM)

**Purpose**: Upgrade Traefik, ArgoCD, MetalLB
**Risk**: Medium
**Downtime**: 5-10 minutes
**METHOD**: All upgrades via OpenTofu modules

### Traefik Upgrade via OpenTofu

- [ ] T096 [P4] Update Traefik version: Edit `terraform/modules/traefik/variables.tf` default to `38.0.1` or pass in module call
- [ ] T097 [P4] Plan Traefik upgrade: `tofu plan -target=module.traefik`
- [ ] T098 [P4] Apply Traefik upgrade: `tofu apply -target=module.traefik`
- [ ] T099 [P4] Validate Traefik pods: `kubectl -n traefik get pods` (all Running)
- [ ] T100 [P4] Verify IngressRoutes: `kubectl get ingressroutes -A` (all configured)

### ArgoCD Upgrade (v2.9 → v3.2) via OpenTofu

- [ ] T101 [P4] Backup ArgoCD apps: `kubectl -n argocd get apps -o yaml > argocd-apps-backup.yaml`
- [ ] T102 [P4] Update ArgoCD version: Edit `terraform/modules/argocd/variables.tf` default `argocd_chart_version = "7.9.0"` (ArgoCD v3.2.x) or pass in module call
- [ ] T103 [P4] Plan ArgoCD upgrade: `tofu plan -target=module.argocd`
- [ ] T104 [P4] Apply ArgoCD upgrade: `tofu apply -target=module.argocd`
- [ ] T105 [P4] Wait for ArgoCD pods: `kubectl -n argocd rollout status deployment argocd-server`
- [ ] T106 [P4] Validate ArgoCD apps: `kubectl -n argocd get apps` (all Synced/Healthy)
- [ ] T107 [P4] Update RBAC if needed (check logs enforcement changes)

### MetalLB Upgrade via OpenTofu

- [ ] T108 [P4] Update MetalLB version: Edit `terraform/modules/metallb/variables.tf` default to `0.15.3` or pass in module call
- [ ] T109 [P4] Plan MetalLB upgrade: `tofu plan -target=module.metallb`
- [ ] T110 [P4] Apply MetalLB upgrade: `tofu apply -target=module.metallb`
- [ ] T111 [P4] Validate MetalLB pods: `kubectl -n metallb-system get pods` (all Running)
- [ ] T112 [P4] Verify LoadBalancer IPs: `kubectl get svc -A | grep LoadBalancer` (all have external IP)

**Checkpoint**: Ingress and GitOps upgraded - proceed to Phase 5

---

## Phase 5: Applications & Tag Pinning (Priority: LOW) 🎯 US3 MVP

**Purpose**: Pin "latest" tags to specific versions, update applications
**Risk**: Low
**Downtime**: 2-5 minutes per component
**METHOD**: All changes via OpenTofu modules

### Pin "latest" Tags in OpenTofu Modules

- [ ] T113 [P] [P5] [US3] Update Pi-hole image: Edit `terraform/modules/pihole/main.tf` to use `image = "pihole/pihole:2025.11.1"`
- [ ] T114 [P] [P5] [US3] Update Homepage image: Edit `terraform/modules/homepage/main.tf` to use `image = "ghcr.io/gethomepage/homepage:v1.8.0"`
- [ ] T115 [P] [P5] [US3] Update Nexus image: Edit `terraform/modules/nexus/main.tf` to use `image = "sonatype/nexus3:3.87.1"`
- [ ] T116 [P] [P5] [US3] Update cloudflared image: Edit `terraform/modules/cloudflare-tunnel/main.tf` to pin current version
- [ ] T117 [P] [P5] [US3] Update localstack image: Edit `terraform/modules/localstack/main.tf` to pin current version

### Apply OpenTofu Changes

- [ ] T118 [P5] [US3] Plan OpenTofu changes: `cd terraform/environments/chocolandiadc-mvp && tofu plan`
- [ ] T119 [P5] [US3] Apply OpenTofu changes: `tofu apply`
- [ ] T120 [P5] [US3] Validate Pi-hole: `kubectl get pods -l app=pihole` (Running with new image)
- [ ] T121 [P5] [US3] Validate Homepage: `kubectl -n homepage get pods` (Running with new image)
- [ ] T122 [P5] [US3] Validate Nexus: `kubectl -n nexus get pods` (Running with new image)

### Application Updates

- [ ] T123 [P] [P5] Update Home Assistant: Edit module to use `image = "ghcr.io/home-assistant/home-assistant:2025.12.4"`
- [ ] T124 [P] [P5] Update MinIO: Edit module to use `image = "minio/minio:RELEASE.2025-10-15T17-29-55Z"`
- [ ] T125 [P5] Apply remaining updates: `tofu apply`
- [ ] T126 [P5] Validate Home Assistant: `kubectl -n home-assistant get pods` (Running)
- [ ] T127 [P5] Validate MinIO: `kubectl -n minio get pods` (Running)

### Headlamp & ARC Controller via OpenTofu

- [ ] T128 [P] [P5] Update Headlamp version: Edit `terraform/modules/headlamp/variables.tf` chart version
- [ ] T129 [P] [P5] Update ARC controller version: Edit `terraform/modules/github-actions-runner/variables.tf` chart version to `0.13.1`
- [ ] T130 [P5] Apply Headlamp/ARC updates: `tofu apply -target=module.headlamp -target=module.github_actions_runner`
- [ ] T131 [P5] Validate Headlamp: `kubectl -n headlamp get pods` (Running)
- [ ] T132 [P5] Validate ARC controller: `kubectl -n github-actions get pods` (Running)

**Checkpoint**: All applications updated, tags pinned - proceed to Final Phase

---

## Phase 6: Documentation & Validation (Polish)

**Purpose**: Document final state, validate success criteria
**Risk**: None
**Downtime**: None

### Final Validation

- [ ] T133 Verify all nodes Ready: `kubectl get nodes -o wide`
- [ ] T134 Verify all pods Running: `kubectl get pods -A --field-selector=status.phase!=Running` (should be empty)
- [ ] T135 Verify Longhorn volumes: `kubectl -n longhorn-system get volumes.longhorn.io`
- [ ] T136 Verify ArgoCD apps: `kubectl -n argocd get apps`
- [ ] T137 Verify certificates: `kubectl get certificates -A`
- [ ] T138 Run connectivity tests to all services

### Documentation Updates

- [ ] T139 [P] [US4] Update data-model.md with final versions
- [ ] T140 [P] [US4] Document compatibility matrix in research.md
- [ ] T141 [P] [US4] Update CLAUDE.md with new version information
- [ ] T142 [US4] Create post-upgrade summary document

### Success Criteria Validation

- [ ] T143 [US1] SC-001: Verify 100% components documented in inventory
- [ ] T144 [US3] SC-002: Verify 0 components use "latest" tag: `kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | grep -c ":latest"` (should be 0)
- [ ] T145 [US2] SC-003: Document maximum downtime per component (target <5 min)
- [ ] T146 [US1] SC-004: Verify all CVE-affected components updated
- [ ] T147 [US2] SC-005: Verify no component >2 minor versions behind

---

## Dependencies & Execution Order

### Phase Dependencies

```text
Phase 0 (Backups) ─────────┐
                           ├──▶ Phase 1 (K3s) ──▶ Phase 2 (Storage) ──┐
Phase 0.5 (Ubuntu patches) ┘                                          │
                                                                       ▼
    ┌──────────────────────────────────────────────────────────────────┘
    │
    ├──▶ Phase 3 (Observability) ──▶ Phase 4 (Ingress/GitOps) ──▶ Phase 5 (Apps)
    │
    └──▶ Phase 6 (Documentation) ──▶ COMPLETE
```

### Critical Path

1. **Phase 0**: MUST complete backups before ANY changes
2. **Phase 0.5**: Ubuntu patches can run in parallel with Phase 0
3. **Phase 1**: K3s upgrade BLOCKS all other component upgrades
4. **Phase 2**: Longhorn BLOCKS storage-dependent updates
5. **Phases 3-5**: Can proceed sequentially after Phase 2
6. **Phase 6**: Final validation after all upgrades

### Parallel Opportunities Within Phases

- **Phase 0**: T002, T003, T004, T005 can run in parallel
- **Phase 2**: PostgreSQL (T074-T076) and Redis (T077-T079) can run in parallel with Longhorn
- **Phase 3**: ntfy (T093-T095) can run in parallel with cert-manager/prometheus
- **Phase 5**: All OpenTofu module edits (T113-T117) can run in parallel
- **Phase 6**: All documentation tasks (T139-T142) can run in parallel

---

## Parallel Example: Phase 5 Tag Pinning

```bash
# Launch all module edits in parallel (different files):
Task: "Update Pi-hole image in terraform/modules/pihole/main.tf"
Task: "Update Homepage image in terraform/modules/homepage/main.tf"
Task: "Update Nexus image in terraform/modules/nexus/main.tf"
Task: "Update cloudflared image in terraform/modules/cloudflare-tunnel/main.tf"
Task: "Update localstack image in terraform/modules/localstack/main.tf"

# Then apply all at once:
Task: "Plan and apply OpenTofu changes"
```

---

## Rollback Procedures

### K3s Rollback

```bash
# Reinstall previous version on affected node
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.28.3+k3s1" sh -
```

### OpenTofu Rollback (Preferred Method)

```bash
# 1. Revert version in module variables.tf or module call
# 2. Plan the downgrade
cd terraform/environments/chocolandiadc-mvp
tofu plan -target=module.<module_name>

# 3. Apply the rollback
tofu apply -target=module.<module_name>

# Example: Rollback Longhorn from 1.10 to 1.9
# Edit module call: chart_version = "1.9.1"
tofu apply -target=module.longhorn
```

### Helm Rollback (Fallback for non-OpenTofu managed releases)

```bash
# List revisions
helm history <release-name> -n <namespace>

# Rollback to previous
helm rollback <release-name> <revision> -n <namespace>

# Note: Prefer using OpenTofu for managed releases to maintain state consistency
```

### Ubuntu Kernel Rollback

```text
# On boot, hold SHIFT to access GRUB
# Select "Advanced options for Ubuntu"
# Choose previous kernel version
```

---

## Implementation Strategy

### MVP First (Phase 0-1 Only)

1. Complete Phase 0: Backups
2. Complete Phase 0.5: Ubuntu patches
3. Complete Phase 1: K3s upgrade
4. **STOP and VALIDATE**: Test cluster health
5. Decide if more phases needed

### Full Upgrade

1. Complete all phases in order
2. Validate after each phase checkpoint
3. Document any issues encountered
4. Update compatibility matrix

### Estimated Duration

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| Phase 0 | T001-T008 | 30 min |
| Phase 0.5 | T009-T030 | 45 min (sequential reboots) |
| Phase 1 | T031-T051 | 60 min (3 K3s version jumps) |
| Phase 2 | T052-T079 | 90 min (Longhorn incremental) |
| Phase 3 | T080-T095 | 30 min |
| Phase 4 | T096-T112 | 30 min |
| Phase 5 | T113-T132 | 30 min |
| Phase 6 | T133-T147 | 30 min |
| **Total** | 147 tasks | **~5.5 hours** |

---

## Notes

- [P] tasks = different files/nodes, no dependencies
- [Phase] label maps task to specific update phase
- Each phase should be completed and validated before proceeding
- Commit changes to Git after each phase
- Keep terminal sessions open for quick rollback
- Monitor Prometheus/Grafana during upgrades
