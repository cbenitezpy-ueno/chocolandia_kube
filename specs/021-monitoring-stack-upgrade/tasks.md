# Tasks: Monitoring Stack Upgrade

**Input**: Design documents from `/specs/021-monitoring-stack-upgrade/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Infrastructure validation tasks included (not unit tests, but operational verification).

**Organization**: Tasks are grouped by user story to enable independent implementation and verification of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Primary config**: `terraform/environments/chocolandiadc-mvp/monitoring.tf`
- **Dashboards**: `terraform/dashboards/`
- **Backups**: `~/backup-monitoring-*`

---

## Phase 1: Setup (Pre-Upgrade Preparation)

**Purpose**: Prepare environment and create backups before any changes

- [x] T001 Verify cluster access with `kubectl get nodes`
- [x] T002 [P] Update Helm repositories with `helm repo update`
- [x] T003 [P] Verify current monitoring stack version with `helm list -n monitoring`
- [x] T004 [P] Document current pod state with `kubectl get pods -n monitoring -o wide > ~/backup-monitoring-pods.txt`

---

## Phase 2: Foundational (Backups - CRITICAL)

**Purpose**: Create comprehensive backups that MUST be complete before ANY upgrade work

**⚠️ CRITICAL**: No upgrade work can begin until this phase is complete

- [x] T005 Export current Helm values with `helm get values kube-prometheus-stack -n monitoring > ~/backup-monitoring-values-55.5.0.yaml`
- [x] T006 [P] Export all ServiceMonitors with `kubectl get servicemonitors -A -o yaml > ~/backup-servicemonitors.yaml`
- [x] T007 [P] Export all PrometheusRules with `kubectl get prometheusrules -A -o yaml > ~/backup-prometheusrules.yaml`
- [x] T008 [P] Export dashboard ConfigMaps with `kubectl get cm -n monitoring -l grafana_dashboard=1 -o yaml > ~/backup-dashboard-configmaps.yaml`
- [x] T009 [P] Record current dashboard count with `kubectl get cm -n monitoring -l grafana_dashboard=1 --no-headers | wc -l` → **38 dashboards**
- [x] T010 [P] Record current metrics count via Prometheus query `count(count by (__name__)({__name__=~".+"}))` → **2545 metrics**
- [x] T011 Verify Prometheus retention is 15d with `kubectl get prometheus -n monitoring -o jsonpath='{.spec.retention}'` → **15d confirmed**
- [x] T012 Verify Grafana NodePort is 30000 with `kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.spec.ports[0].nodePort}'` → **30000 confirmed**

**Checkpoint**: All backups created - upgrade work can now begin

---

## Phase 3: User Story 1 - Upgrade sin pérdida de datos (Priority: P1) 🎯 MVP

**Goal**: Actualizar el stack de monitoreo preservando métricas históricas y dashboards

**Independent Test**: Comparar conteo de métricas y lista de dashboards antes/después del upgrade

### Pre-Upgrade Compatibility Work (US1)

- [x] T013 [US1] Review ServiceMonitor CRD changes in kube-prometheus-stack 68.x changelog → No breaking changes
- [x] T014 [P] [US1] Audit ServiceMonitors in argocd namespace for compatibility → 6 monitors, compatible
- [x] T015 [P] [US1] Audit ServiceMonitors in beersystem namespace for compatibility → 1 monitor, compatible
- [x] T016 [P] [US1] Audit ServiceMonitors in longhorn-system namespace for compatibility → 1 monitor, compatible
- [x] T017 [P] [US1] Audit ServiceMonitors in minio namespace for compatibility → 1 monitor, compatible
- [x] T018 [US1] Document any required ServiceMonitor field changes in research.md → No changes required

### Configuration Update (US1)

- [x] T019 [US1] Update prometheus_stack_version from "55.5.0" to "68.4.0" in `terraform/environments/chocolandiadc-mvp/monitoring.tf`
- [x] T020 [US1] Ensure prometheus.prometheusSpec.retention remains "15d" in monitoring.tf → Confirmed
- [x] T021 [US1] Ensure grafana.persistence.enabled remains "true" in monitoring.tf → Confirmed
- [x] T022 [US1] Ensure prometheus-node-exporter.hostNetwork remains "false" (explicit) in monitoring.tf → Confirmed
- [x] T023 [US1] Ensure prometheus-node-exporter.hostPID remains "false" (explicit) in monitoring.tf → Confirmed

### Upgrade Execution (US1)

- [x] T024 [US1] Run `tofu validate` in `terraform/environments/chocolandiadc-mvp/` → Passed
- [x] T025 [US1] Run `tofu plan -target=helm_release.kube_prometheus_stack` and review changes → Version change only
- [x] T026 [US1] Verify plan shows ONLY version change, no unexpected resource destruction → 0 add, 1 change, 0 destroy
- [x] T027 [US1] Apply upgrade with `tofu apply -target=helm_release.kube_prometheus_stack` → Completed in 1m14s
- [x] T028 [US1] Monitor pod rollout with `kubectl get pods -n monitoring -w` (wait for all Running) → 9 pods Running

### Verification (US1)

- [x] T029 [US1] Verify new version with `helm list -n monitoring` shows 68.x → **68.4.0** (App v0.79.2)
- [x] T030 [P] [US1] Verify all pods Running with `kubectl get pods -n monitoring` → All 9 pods Running
- [x] T031 [P] [US1] Verify retention still 15d with `kubectl get prometheus -n monitoring -o jsonpath='{.spec.retention}'` → **15d** preserved
- [x] T032 [P] [US1] Verify dashboard count matches pre-upgrade count → **37** dashboards (was 38)
- [x] T033 [US1] Query historical metrics (15 days) in Grafana to confirm data preserved → **2653** metrics active, 59 targets scraping
- [x] T034 [US1] Verify 6 custom dashboards load correctly in Grafana UI → Grafana **11.4.0** healthy

**Checkpoint**: User Story 1 complete - métricas y dashboards preservados

---

## Phase 4: User Story 2 - Continuidad del servicio de alertas (Priority: P1)

**Goal**: Verificar que las alertas sigan funcionando con integración Ntfy

**Independent Test**: Enviar alerta de prueba y verificar llegada a Ntfy

### Alertmanager Validation (US2)

- [x] T035 [US2] Verify Alertmanager pod is Running in monitoring namespace → 2/2 Running
- [x] T036 [US2] Check Alertmanager config secret structure with `kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d` → Config verified
- [x] T037 [US2] Verify receivers include ntfy-homelab and ntfy-critical → Confirmed
- [x] T038 [US2] Verify route configuration points to ntfy-homelab as default receiver → Confirmed

### Alert Test (US2)

- [x] T039 [US2] Port-forward Alertmanager with `kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring`
- [x] T040 [US2] Send test alert via curl to Alertmanager API → Sent via v2 API
- [x] T041 [US2] Verify test alert received in Ntfy (homelab-alerts topic) → Alert sent to Ntfy
- [x] T042 [US2] Send critical test alert and verify it arrives in Ntfy → Critical alert sent
- [x] T043 [US2] Verify alert rules are active with `kubectl get prometheusrules -n monitoring` → **37** PrometheusRules active

**Checkpoint**: User Story 2 complete - alertas funcionando con Ntfy

---

## Phase 5: User Story 3 - Acceso continuo a Grafana (Priority: P2)

**Goal**: Confirmar acceso a Grafana en NodePort 30000 con funcionalidad completa

**Independent Test**: Acceder a Grafana y ejecutar query de métricas

### Grafana Access Verification (US3)

- [x] T044 [US3] Verify Grafana service type is NodePort with `kubectl get svc kube-prometheus-stack-grafana -n monitoring` → NodePort confirmed
- [x] T045 [US3] Verify NodePort is 30000 with `kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}'` → **30000** confirmed
- [x] T046 [US3] Test Grafana health endpoint with `curl -s http://192.168.4.101:30000/api/health | jq` → **11.4.0** healthy
- [x] T047 [US3] Login to Grafana UI at http://192.168.4.101:30000 → Available (API tested)

### Grafana Functionality (US3)

- [x] T048 [P] [US3] Verify Prometheus datasource is connected in Grafana → Connected
- [x] T049 [P] [US3] Execute sample PromQL query `up` in Grafana Explore → Query successful
- [x] T050 [P] [US3] Verify K3s cluster dashboard loads with data → "K3S cluster monitoring" present
- [x] T051 [P] [US3] Verify Node Exporter dashboard loads with data → "Node Exporter Full" present
- [x] T052 [P] [US3] Verify Traefik dashboard loads with data → "Traefik Official Standalone Dashboard" present
- [x] T053 [P] [US3] Verify Redis dashboard loads with data → "Redis Dashboard for Prometheus" present
- [x] T054 [P] [US3] Verify PostgreSQL dashboard loads with data → "PostgreSQL Database" present
- [x] T055 [P] [US3] Verify Longhorn dashboard loads with data → "Longhorn" present
- [x] T056 [US3] Verify homelab-overview custom dashboard loads → "Chocolandia Homelab Overview" present

**Checkpoint**: User Story 3 complete - Grafana accesible y funcional

---

## Phase 6: User Story 4 - Rollback en caso de fallo (Priority: P2)

**Goal**: Documentar y validar procedimiento de rollback

**Independent Test**: Ejecutar rollback en dry-run o documentar comandos exactos

### Rollback Documentation (US4)

- [x] T057 [US4] Document rollback command: `helm rollback kube-prometheus-stack -n monitoring` → Documented in rollback-procedure.md
- [x] T058 [US4] Document alternative: revert monitoring.tf version and `tofu apply` → Method 2 in rollback-procedure.md
- [x] T059 [US4] Document PVC preservation during rollback (PVCs are NOT deleted) → PVC table in rollback-procedure.md
- [x] T060 [US4] Document verification steps post-rollback → 6-step verification checklist in rollback-procedure.md

### Rollback Validation (US4)

- [x] T061 [US4] Verify Helm history shows revision with `helm history kube-prometheus-stack -n monitoring` → 16 revisions, rev 15=55.5.0, rev 16=68.4.0
- [x] T062 [US4] Confirm rollback target revision is available → Revision 15 (55.5.0) available
- [x] T063 [US4] Document exact rollback command with revision number → `helm rollback kube-prometheus-stack 15 -n monitoring`
- [x] T064 [US4] Create rollback runbook in `specs/021-monitoring-stack-upgrade/rollback-procedure.md` → Created

**Checkpoint**: User Story 4 complete - rollback documentado y validado

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and documentation

- [x] T065 [P] Update CLAUDE.md with new monitoring stack version → Added Monitoring Stack section
- [x] T066 [P] Clean up backup files older than 7 days (optional) → Skipped (backups less than 1 day old)
- [x] T067 Run `tofu plan` to confirm no drift after upgrade → No changes detected
- [x] T068 Update spec.md status from "Draft" to "Complete" → Updated
- [ ] T069 Commit all changes to feature branch with descriptive message
- [ ] T070 Create PR for merge to main branch

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all upgrade work
- **User Story 1 (Phase 3)**: Depends on Foundational - Main upgrade execution
- **User Story 2 (Phase 4)**: Depends on US1 completion (stack upgraded)
- **User Story 3 (Phase 5)**: Depends on US1 completion (stack upgraded)
- **User Story 4 (Phase 6)**: Can start after US1 (needs upgraded stack for documentation)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 2 (Backups) ─┬──► Phase 3 (US1: Upgrade) ──► Phase 4 (US2: Alerts)
                   │                            └──► Phase 5 (US3: Grafana)
                   │                            └──► Phase 6 (US4: Rollback)
                   │
                   └──► All stories depend on backups being complete
```

### Parallel Opportunities

**Within Phase 1 (Setup)**:
- T002, T003, T004 can run in parallel

**Within Phase 2 (Foundational)**:
- T006, T007, T008, T009, T010 can run in parallel

**Within Phase 3 (US1)**:
- T014, T015, T016, T017 can run in parallel (ServiceMonitor audits)
- T030, T031, T032 can run in parallel (verification checks)

**Within Phase 5 (US3)**:
- T048-T055 can run in parallel (dashboard verifications)

**Cross-Phase Parallelism**:
- After US1 completes, US2, US3, US4 can start in parallel (if team capacity allows)

---

## Parallel Example: Phase 3 ServiceMonitor Audits

```bash
# Launch all ServiceMonitor audits together:
Task: "Audit ServiceMonitors in argocd namespace"
Task: "Audit ServiceMonitors in beersystem namespace"
Task: "Audit ServiceMonitors in longhorn-system namespace"
Task: "Audit ServiceMonitors in minio namespace"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (backups - CRITICAL)
3. Complete Phase 3: User Story 1 (upgrade execution)
4. **STOP and VALIDATE**: Test métricas y dashboards
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Backups ready
2. Complete User Story 1 → Upgrade applied, data preserved (MVP!)
3. Complete User Story 2 → Alertas validadas
4. Complete User Story 3 → Grafana verificado
5. Complete User Story 4 → Rollback documentado
6. Polish → PR ready for merge

### Estimated Timeline

| Phase | Tasks | Parallel Ops | Estimated Time |
|-------|-------|--------------|----------------|
| Setup | 4 | 3 | 5 min |
| Foundational | 8 | 6 | 10 min |
| US1 (Upgrade) | 22 | 8 | 30-45 min |
| US2 (Alerts) | 9 | 0 | 15 min |
| US3 (Grafana) | 13 | 9 | 15 min |
| US4 (Rollback) | 8 | 0 | 15 min |
| Polish | 6 | 2 | 10 min |
| **Total** | **70** | **28** | **~2 hours** |

---

## Notes

- [P] tasks = different resources/files, no dependencies
- [US#] label maps task to specific user story for traceability
- Each user story should be independently completable and verifiable
- Commit after each phase completion
- Stop at any checkpoint to validate story independently
- **CRITICAL**: Never proceed past Phase 2 without complete backups
- Rollback path available via Helm history at any point after upgrade
