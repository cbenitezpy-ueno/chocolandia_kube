# Tasks: Monitoring & Alerting System

**Input**: Design documents from `/specs/014-monitoring-alerts/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Infrastructure validation tests included as part of each phase.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

```text
terraform/
├── modules/
│   ├── prometheus-stack/
│   ├── ntfy/
│   └── alerting-rules/
└── environments/
    └── chocolandiadc-mvp/
scripts/
└── monitoring/
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and module structure

- [x] T001 Create prometheus-stack module directory structure in terraform/modules/prometheus-stack/
- [x] T002 [P] Create ntfy module directory structure in terraform/modules/ntfy/
- [x] T003 [P] Create alerting-rules module directory structure in terraform/modules/alerting-rules/
- [x] T004 [P] Create monitoring scripts directory in scripts/monitoring/
- [x] T005 Add helm provider configuration to terraform/environments/chocolandiadc-mvp/providers.tf

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Deploy core monitoring stack that ALL alert stories depend on

**⚠️ CRITICAL**: No alert rules can work until Prometheus + Alertmanager + Ntfy are running

- [ ] T006 Create prometheus-stack module variables in terraform/modules/prometheus-stack/variables.tf
- [ ] T007 Create prometheus-stack module outputs in terraform/modules/prometheus-stack/outputs.tf
- [ ] T008 Create Helm values for kube-prometheus-stack in terraform/modules/prometheus-stack/values/prometheus-values.yaml
- [ ] T009 Implement prometheus-stack main.tf with Helm release in terraform/modules/prometheus-stack/main.tf
- [ ] T010 Create ntfy module variables in terraform/modules/ntfy/variables.tf
- [ ] T011 [P] Create ntfy module outputs in terraform/modules/ntfy/outputs.tf
- [ ] T012 Implement ntfy deployment in terraform/modules/ntfy/main.tf (Deployment, Service, Ingress)
- [ ] T013 Create monitoring.tf module instantiation in terraform/environments/chocolandiadc-mvp/monitoring.tf
- [ ] T014 Create ntfy.tf module instantiation in terraform/environments/chocolandiadc-mvp/ntfy.tf
- [ ] T015 Deploy and validate: tofu apply prometheus-stack and verify pods running in monitoring namespace
- [ ] T016 Deploy and validate: tofu apply ntfy and verify pod running in ntfy namespace
- [ ] T017 Verify Ntfy ingress accessible via https://ntfy.chocolandia.com

**Checkpoint**: Prometheus + Grafana + Alertmanager + Ntfy running - alert configuration can now begin

---

## Phase 3: User Story 1 - Alertas de Nodo Caído (Priority: P1) 🎯 MVP

**Goal**: Recibir notificación push cuando un nodo del cluster cae

**Independent Test**: Apagar nodo04 (worker) y verificar que llega notificación Ntfy en <2 minutos

### Implementation for User Story 1

- [ ] T018 [US1] Create node alert rules YAML in terraform/modules/alerting-rules/rules/node-alerts.yaml
- [ ] T019 [US1] Create alerting-rules module variables in terraform/modules/alerting-rules/variables.tf
- [ ] T020 [P] [US1] Create alerting-rules module outputs in terraform/modules/alerting-rules/outputs.tf
- [ ] T021 [US1] Implement alerting-rules main.tf with PrometheusRule CRD in terraform/modules/alerting-rules/main.tf
- [ ] T022 [US1] Configure Alertmanager webhook receiver for Ntfy in prometheus-values.yaml
- [ ] T023 [US1] Add alerting-rules module to monitoring.tf in terraform/environments/chocolandiadc-mvp/monitoring.tf
- [ ] T024 [US1] Deploy alert rules: tofu apply and verify PrometheusRule created
- [ ] T025 [US1] Create test-node-alerts.sh validation script in scripts/monitoring/test-node-alerts.sh
- [ ] T026 [US1] Run validation: Test node down alert by stopping kubelet on nodo04 and verify Ntfy notification

**Checkpoint**: Node down alerts working end-to-end with Ntfy delivery

---

## Phase 4: User Story 2 - Alertas de Servicio No Disponible (Priority: P1)

**Goal**: Recibir notificación push cuando un deployment/pod falla

**Independent Test**: Escalar beersystem-backend a 0 réplicas y verificar notificación

### Implementation for User Story 2

- [ ] T027 [US2] Create service alert rules YAML in terraform/modules/alerting-rules/rules/service-alerts.yaml
- [ ] T028 [US2] Add service alerts to alerting-rules main.tf in terraform/modules/alerting-rules/main.tf
- [ ] T029 [US2] Deploy service alert rules: tofu apply
- [ ] T030 [US2] Create test-service-alerts.sh validation script in scripts/monitoring/test-service-alerts.sh
- [ ] T031 [US2] Run validation: Scale beersystem-backend to 0 and verify Ntfy notification

**Checkpoint**: Service down alerts working with CrashLoopBackOff, ImagePullBackOff, DeploymentUnavailable detection

---

## Phase 5: User Story 3 - Golden Signals por Aplicación (Priority: P2)

**Goal**: Dashboard Grafana con latencia, tráfico, errores, saturación por aplicación

**Independent Test**: Acceder a dashboard y ver métricas de Traefik actualizadas

### Implementation for User Story 3

- [ ] T032 [US3] Enable Traefik metrics scraping in prometheus-values.yaml ServiceMonitor
- [ ] T033 [US3] Create golden-signals-apps.json Grafana dashboard in terraform/modules/prometheus-stack/dashboards/
- [ ] T034 [US3] Add dashboard ConfigMap to prometheus-stack main.tf
- [ ] T035 [US3] Deploy dashboards: tofu apply and verify dashboard appears in Grafana
- [ ] T036 [US3] Create validate-golden-signals.sh script in scripts/monitoring/validate-golden-signals.sh
- [ ] T037 [US3] Run validation: Check Traefik metrics visible and 4 golden signals displayed

**Checkpoint**: Golden signals dashboard for applications working with real Traefik data

---

## Phase 6: User Story 4 - Golden Signals por Nodo (Priority: P2)

**Goal**: Dashboard Grafana con CPU, memoria, disco, red por nodo

**Independent Test**: Acceder a dashboard y ver métricas de los 4 nodos

### Implementation for User Story 4

- [ ] T038 [US4] Verify node-exporter DaemonSet deployed by kube-prometheus-stack
- [ ] T039 [US4] Create node-metrics.json Grafana dashboard in terraform/modules/prometheus-stack/dashboards/
- [ ] T040 [US4] Add node dashboard ConfigMap to prometheus-stack main.tf
- [ ] T041 [US4] Deploy node dashboard: tofu apply
- [ ] T042 [US4] Create resource threshold alerts (CPU>85%, disk>80%) in node-alerts.yaml
- [ ] T043 [US4] Run validation: Check all 4 nodes visible with resource metrics

**Checkpoint**: Node resource monitoring with visual highlighting of high-usage nodes

---

## Phase 7: User Story 5 - Gestión Ntfy (Priority: P3)

**Goal**: Suscripción fácil a alertas y prioridades configuradas

**Independent Test**: Suscribirse desde móvil y recibir alerta de prueba con prioridad correcta

### Implementation for User Story 5

- [ ] T044 [US5] Configure Ntfy topic with proper naming in ntfy main.tf
- [ ] T045 [US5] Configure Cloudflare Access for Ntfy ingress in Cloudflare Zero Trust
- [ ] T046 [US5] Create alert priority mapping in Alertmanager config (critical=5, warning=3, info=2)
- [ ] T047 [US5] Add resolved notification configuration to Alertmanager
- [ ] T048 [US5] Create send-test-notification.sh script in scripts/monitoring/
- [ ] T049 [US5] Run validation: Subscribe from Ntfy mobile app and receive test notification with correct priority

**Checkpoint**: End-to-end notification delivery with priorities and resolved states

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T050 [P] Create homelab-overview.json unified dashboard combining all metrics in dashboards/
- [ ] T051 [P] Configure alert inhibition rules (NodeDown suppresses NodeHighCPU for same node)
- [ ] T052 [P] Configure alert grouping to reduce notification spam
- [ ] T053 Update quickstart.md with actual deployment URLs and credentials
- [ ] T054 Create runbook documentation for each alert type in specs/014-monitoring-alerts/runbooks/
- [ ] T055 Run full end-to-end validation: scripts/monitoring/validate-full-stack.sh
- [ ] T056 Commit all changes with descriptive message

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - Node alerts
- **User Story 2 (Phase 4)**: Depends on Foundational - Service alerts (can parallel with US1)
- **User Story 3 (Phase 5)**: Depends on Foundational - App dashboards (can parallel with US1/US2)
- **User Story 4 (Phase 6)**: Depends on Foundational - Node dashboards (can parallel)
- **User Story 5 (Phase 7)**: Depends on US1 or US2 for Alertmanager config - Ntfy management
- **Polish (Phase 8)**: Depends on all user stories complete

### User Story Dependencies

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational) ◄─── CRITICAL BLOCKER
    │
    ├──► Phase 3 (US1: Node Alerts) ────┐
    │                                    │
    ├──► Phase 4 (US2: Service Alerts) ─┼──► Phase 7 (US5: Ntfy)
    │                                    │
    ├──► Phase 5 (US3: App Dashboards) ─┤
    │                                    │
    └──► Phase 6 (US4: Node Dashboards)─┘
                                         │
                                         ▼
                                    Phase 8 (Polish)
```

### Parallel Opportunities

- **Phase 1**: T002, T003, T004 can run in parallel (different directories)
- **Phase 2**: T010, T011 can run in parallel with T006-T009
- **After Phase 2**: US1, US2, US3, US4 can all start in parallel
- **Phase 8**: T050, T051, T052 can run in parallel

---

## Parallel Example: User Stories 1-4

```bash
# After Phase 2 completes, launch all alert implementations together:
# Worker A: User Story 1 (Node Alerts)
Task: "Create node alert rules YAML in terraform/modules/alerting-rules/rules/node-alerts.yaml"

# Worker B: User Story 2 (Service Alerts)
Task: "Create service alert rules YAML in terraform/modules/alerting-rules/rules/service-alerts.yaml"

# Worker C: User Story 3 (App Dashboards)
Task: "Create golden-signals-apps.json Grafana dashboard"

# Worker D: User Story 4 (Node Dashboards)
Task: "Create node-metrics.json Grafana dashboard"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (5 tasks)
2. Complete Phase 2: Foundational (12 tasks) - **Deploy Prometheus + Ntfy**
3. Complete Phase 3: User Story 1 - Node Alerts (9 tasks)
4. **STOP and VALIDATE**: Test node down alert manually
5. Complete Phase 4: User Story 2 - Service Alerts (5 tasks)
6. **DEPLOY MVP**: Critical alerting working

### Incremental Delivery

1. MVP (US1 + US2) → Critical alerts working
2. Add US3 → Application golden signals visible
3. Add US4 → Node resource monitoring visible
4. Add US5 → Notification management polished
5. Polish → Documentation and unified dashboard

### Estimated Task Counts

| Phase | Tasks | Cumulative |
|-------|-------|------------|
| Setup | 5 | 5 |
| Foundational | 12 | 17 |
| US1: Node Alerts | 9 | 26 |
| US2: Service Alerts | 5 | 31 |
| US3: App Dashboards | 6 | 37 |
| US4: Node Dashboards | 6 | 43 |
| US5: Ntfy Management | 6 | 49 |
| Polish | 7 | 56 |

**Total**: 56 tasks

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Infrastructure project: No unit tests, but validation scripts replace them
- All alerts follow contracts/alert-rules.yaml specification
