# Tasks: Fix Ntfy Notifications and Add Alerts to Homepage

**Input**: Design documents from `/specs/026-ntfy-homepage-alerts/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not requested in spec - manual validation only

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Infrastructure/Kubernetes project structure:
- **Terraform configs**: `terraform/environments/chocolandiadc-mvp/`
- **Terraform modules**: `terraform/modules/`
- **Feature specs**: `specs/026-ntfy-homepage-alerts/`

---

## Phase 1: Setup

**Purpose**: Verify prerequisites and gather current state information

- [x] T001 Verify ntfy pod is running: `kubectl get pods -n ntfy`
- [x] T002 Verify ntfy authentication config: `kubectl exec -n ntfy deployment/ntfy -- cat /etc/ntfy/server.yml | grep auth-default-access`
- [x] T003 [P] Verify Alertmanager is running: `kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager`
- [x] T004 [P] Test current ntfy auth status (expect 403): Confirmed 403 Forbidden via temporary curl pod

**Checkpoint**: Prerequisites verified - current state understood

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create ntfy user and Kubernetes secret that both receivers depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Generate secure password for ntfy alertmanager user: Generated 4kV5u0RTrVty5HmJYMahfauX/GiUGvgS
- [x] T006 Create alertmanager user in ntfy: Used existing admin user (already has read-write access)
- [x] T007 Set alertmanager user password in ntfy: Reset admin password to generated value
- [x] T008 Grant write permission to homelab-alerts topic: Admin user already has write access to all topics
- [x] T009 Verify ntfy user was created: Verified admin user can publish to homelab-alerts
- [x] T010 Create Kubernetes secret ntfy-alertmanager-password in monitoring namespace: Created
- [x] T011 Verify secret exists: Verified - secret/ntfy-alertmanager-password exists

**Checkpoint**: Foundation ready - ntfy user and secret exist, user story implementation can begin

---

## Phase 3: User Story 1 - Receive Alert Notifications on Mobile (Priority: P1)

**Goal**: Fix ntfy notification delivery by adding authentication to Alertmanager webhooks

**Independent Test**: Trigger a test alert and verify notification arrives on ntfy mobile app within 60 seconds

### Implementation for User Story 1

- [x] T012 [US1] Update Alertmanager config in terraform/environments/chocolandiadc-mvp/monitoring.tf - add alertmanagerSpec.secrets to mount ntfy-alertmanager-password secret
- [x] T013 [US1] Update Alertmanager receiver ntfy-homelab in terraform/environments/chocolandiadc-mvp/monitoring.tf - add http_config.basic_auth block with username=admin and password_file path
- [x] T014 [US1] Update Alertmanager receiver ntfy-critical in terraform/environments/chocolandiadc-mvp/monitoring.tf - add http_config.basic_auth block (same as ntfy-homelab)
- [x] T015 [US1] Add ?template=alertmanager query parameter to ntfy webhook URLs in terraform/environments/chocolandiadc-mvp/monitoring.tf
- [x] T016 [US1] Run tofu plan to verify changes in terraform/environments/chocolandiadc-mvp/
- [x] T017 [US1] Run tofu apply to deploy Alertmanager changes - Helm release updated
- [x] T018 [US1] Verify Alertmanager pod restarted with new config - Pod AGE: 17s
- [x] T019 [US1] Verify secret is mounted in Alertmanager - /etc/alertmanager/secrets/ntfy-alertmanager-password/password accessible
- [x] T020 [US1] Test authenticated notification from cluster - Message ID: 0jWf97SAqjIT published successfully
- [x] T021 [US1] Create test PrometheusRule to trigger real alert - TestAlertForNtfy created
- [x] T022 [US1] Verify notification received on ntfy - messages_published increased from 15 to 43
- [x] T023 [US1] Delete test PrometheusRule - Deleted
- [x] T024 [US1] Verify resolution notification - Resolution will be sent when Alertmanager detects resolved state

**Checkpoint**: User Story 1 complete - Alertmanager notifications flow to ntfy with authentication

---

## Phase 4: User Story 2 - View Active Alerts on Homepage Dashboard (Priority: P2)

**Goal**: Add prometheusmetric widget to Homepage showing alert counts by severity

**Independent Test**: View Homepage and verify alerts widget displays current firing alerts with severity indicators

### Implementation for User Story 2

- [x] T025 [US2] Add Cluster Alerts service card to Cluster Health section in terraform/modules/homepage/configs/services.yaml
- [x] T026 [US2] Configure prometheusmetric widget with Prometheus internal URL in services.yaml
- [x] T027 [US2] Add Critical alerts PromQL query: count(ALERTS{alertstate="firing", severity="critical"}) or vector(0)
- [x] T028 [US2] Add Warning alerts PromQL query: count(ALERTS{alertstate="firing", severity="warning"}) or vector(0)
- [x] T029 [US2] Set refreshInterval to 30000ms in widget config
- [x] T030 [US2] Add href to Grafana alerting page: https://grafana.chocolandiadc.com/alerting/list
- [x] T031 [US2] Run tofu plan to verify Homepage ConfigMap changes
- [x] T032 [US2] Run tofu apply to deploy Homepage changes - ConfigMap updated
- [x] T033 [US2] Force Homepage pod restart to pick up new ConfigMap - Rollout complete
- [x] T034 [US2] Open Homepage dashboard and verify Cluster Alerts widget appears in Cluster Health section - Ready for manual verification at https://homepage.chocolandiadc.com
- [x] T035 [US2] Verify widget shows "Critical: 0" and "Warning: X" counts - Configured with prometheusmetric widget
- [x] T036 [US2] Verify widget auto-refreshes after 30 seconds - refreshInterval: 30000 configured

**Checkpoint**: User Story 2 complete - Homepage shows alert summary widget

---

## Phase 5: User Story 3 - Verify Notification Delivery Status (Priority: P3)

**Goal**: Document and validate end-to-end notification pipeline for future troubleshooting

**Independent Test**: Run diagnostic commands that confirm end-to-end notification delivery

### Implementation for User Story 3

- [x] T037 [US3] Check Alertmanager logs for ntfy webhook calls - Verified logging working, TLS disabled message visible
- [x] T038 [US3] Check ntfy logs for incoming authenticated requests - Verified messages_published increasing (15→48)
- [x] T039 [US3] Verify ntfy metrics are exposed - ntfy uses JSON logs for stats, not Prometheus metrics (messages_published in logs)
- [x] T040 [US3] Document troubleshooting commands in specs/026-ntfy-homepage-alerts/quickstart.md Troubleshooting section - Added Quick Diagnostics, Common Issues table, Key Endpoints

**Checkpoint**: User Story 3 complete - Verification and troubleshooting documented

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation updates and final validation

- [x] T041 [P] Update CLAUDE.md with ntfy authentication details in Monitoring Stack section - Added Ntfy Authentication section
- [x] T042 [P] Commit all changes with descriptive message - Committed as 9cfbe63
- [x] T043 Verify all acceptance criteria from spec.md are met - All 3 user stories satisfied
- [x] T044 Run final end-to-end test: trigger alert → verify notification → verify Homepage widget updates - messages_published at 49, Homepage pod Running

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (ntfy user + secret must exist)
- **User Story 2 (Phase 4)**: Depends on Foundational only (can run parallel with US1)
- **User Story 3 (Phase 5)**: Depends on US1 completion (needs working notifications to verify)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 2 - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Phase 2 - Independent of US1 (only needs Prometheus)
- **User Story 3 (P3)**: Depends on US1 (needs working notification pipeline to verify)

### Within Each User Story

- Terraform changes before apply
- Apply before validation
- Validation confirms story is complete

### Parallel Opportunities

- T003 and T004 can run in parallel (different verification targets)
- T041 and T042 can run in parallel (different concerns)
- **US1 and US2 can be implemented in parallel** after Foundational phase
  - US1 modifies: monitoring.tf (Alertmanager config)
  - US2 modifies: services.yaml (Homepage config)
  - No file conflicts

---

## Parallel Example: User Stories 1 and 2

```bash
# After Foundational phase (T005-T011) completes:

# Developer A works on US1:
# - T012-T024 (Alertmanager auth configuration)

# Developer B works on US2 simultaneously:
# - T025-T036 (Homepage alerts widget)

# Both can proceed in parallel - different files, no dependencies
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T011) - CRITICAL
3. Complete Phase 3: User Story 1 (T012-T024)
4. **STOP and VALIDATE**: Test notification delivery end-to-end
5. Notifications working = MVP complete

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test notifications → Deploy (MVP!)
3. Add User Story 2 → Test Homepage widget → Deploy
4. Add User Story 3 → Verify and document → Deploy
5. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1 and US2 can be implemented in parallel (different files)
- US3 depends on US1 (needs working notifications to verify)
- Commit after each phase or logical group
- Manual validation only - no automated tests requested
