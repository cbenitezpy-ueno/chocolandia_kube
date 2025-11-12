# Tasks: Headlamp Web UI for K3s Cluster Management

**Input**: Design documents from `/specs/007-headlamp-web-ui/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

## Path Conventions

Infrastructure-as-Code project using OpenTofu modules:
- **Module files**: `terraform/modules/headlamp/`
- **Environment config**: `terraform/environments/chocolandiadc-mvp/`
- **Validation scripts**: `scripts/validation/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create module structure and initialize directories

- [X] T001 Create Headlamp module directory at terraform/modules/headlamp/
- [X] T002 [P] Create validation scripts directory at scripts/validation/
- [X] T003 [P] Create module README.md at terraform/modules/headlamp/README.md with module purpose and usage

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story implementation

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Verify K3s cluster is running and accessible via kubeconfig at terraform/environments/chocolandiadc-mvp/kubeconfig
- [X] T005 [P] Verify Traefik v3.1.0 is deployed in kube-system namespace (kubectl get deployment traefik -n kube-system)
- [X] T006 [P] Verify cert-manager v1.13.x is deployed in cert-manager namespace (kubectl get deployment cert-manager -n cert-manager)
- [X] T007 [P] Verify Cloudflare Zero Trust tunnel is configured (Feature 004 dependency)
- [X] T008 [P] Verify Prometheus + Grafana stack is deployed in monitoring namespace
- [X] T009 Create provider versions configuration at terraform/modules/headlamp/versions.tf (Helm, Kubernetes, Cloudflare providers)
- [X] T010 Create module variables at terraform/modules/headlamp/variables.tf (namespace, domain, replicas, authorized_emails, etc.)
- [X] T011 Create module outputs at terraform/modules/headlamp/outputs.tf (service_name, ingress_hostname, namespace)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Deploy Headlamp with Helm via OpenTofu (Priority: P1) 🎯 MVP

**Goal**: Deploy Headlamp Kubernetes dashboard using Helm chart managed by OpenTofu, providing web-based UI for cluster management

**Independent Test**: Deploy Headlamp via `tofu apply`, verify pods Running, port-forward to service, access UI at http://localhost:port

### Implementation for User Story 1

- [X] T012 [P] [US1] Create Kubernetes namespace resource for headlamp at terraform/modules/headlamp/main.tf
- [X] T013 [US1] Add Helm provider configuration for headlamp chart (repository: https://kubernetes-sigs.github.io/headlamp/) at terraform/modules/headlamp/main.tf
- [X] T014 [US1] Create Helm release resource for headlamp chart v0.38.0 with replicaCount=2 at terraform/modules/headlamp/main.tf
- [X] T015 [US1] Configure Helm values: resources (100m CPU/128Mi RAM requests, 200m CPU/256Mi RAM limits) at terraform/modules/headlamp/main.tf
- [X] T016 [US1] Configure Helm values: service.type=ClusterIP, service.port=80 at terraform/modules/headlamp/main.tf
- [X] T017 [US1] Configure Helm values: ingress.enabled=false (using Traefik IngressRoute) at terraform/modules/headlamp/main.tf
- [X] T018 [US1] Configure Helm values: config.baseURL="" (dedicated domain) at terraform/modules/headlamp/main.tf
- [X] T019 [US1] Configure Helm values: podDisruptionBudget.enabled=true, minAvailable=1 at terraform/modules/headlamp/main.tf
- [X] T020 [US1] Configure Helm values: affinity.podAntiAffinity for node distribution at terraform/modules/headlamp/main.tf
- [X] T021 [US1] Configure Helm values: livenessProbe and readinessProbe (path=/, port=http) at terraform/modules/headlamp/main.tf
- [X] T022 [US1] Configure Helm values: env variable HEADLAMP_DISABLE_ANALYTICS=true at terraform/modules/headlamp/main.tf
- [X] T023 [US1] Create module invocation at terraform/environments/chocolandiadc-mvp/headlamp.tf with module source and variables
- [X] T024 [US1] Update terraform.tfvars at terraform/environments/chocolandiadc-mvp/terraform.tfvars with headlamp_enabled=true, headlamp_domain, authorized_emails
- [X] T025 [US1] Run tofu init in terraform/environments/chocolandiadc-mvp/ to initialize module
- [X] T026 [US1] Run tofu validate in terraform/environments/chocolandiadc-mvp/ to validate HCL syntax
- [X] T027 [US1] Run tofu fmt -check in terraform/environments/chocolandiadc-mvp/ to verify formatting
- [X] T028 [US1] Run tofu plan in terraform/environments/chocolandiadc-mvp/ and review output for namespace, helm_release resources
- [X] T029 [US1] Run tofu apply in terraform/environments/chocolandiadc-mvp/ and confirm deployment
- [X] T030 [US1] Verify pods are Running: kubectl get pods -n headlamp (expect 2 pods Running)
- [X] T031 [US1] Verify service created: kubectl get svc headlamp -n headlamp (expect ClusterIP on port 80)
- [X] T032 [US1] Verify pod resource consumption: kubectl top pod -n headlamp (expect <128Mi memory, <200m CPU)
- [X] T033 [US1] Test internal access: kubectl port-forward svc/headlamp -n headlamp 8080:80 and access http://localhost:8080

**Checkpoint**: At this point, Headlamp is deployed and accessible internally within cluster

---

## Phase 4: User Story 2 - Configure RBAC for Read-Only Access (Priority: P1, MVP)

**Goal**: Create ServiceAccount with read-only ClusterRole binding for secure, non-destructive cluster access

**Independent Test**: Generate token, authenticate to Headlamp, verify resources visible, attempt delete (should fail with permission error)

### Implementation for User Story 2

- [ ] T034 [P] [US2] Create ServiceAccount resource for headlamp-admin at terraform/modules/headlamp/rbac.tf
- [ ] T035 [P] [US2] Create Secret resource for long-lived ServiceAccount token (type: kubernetes.io/service-account-token) at terraform/modules/headlamp/rbac.tf
- [ ] T036 [US2] Create ClusterRoleBinding resource binding ServiceAccount to ClusterRole "view" at terraform/modules/headlamp/rbac.tf
- [ ] T037 [US2] Add rbac.tf to OpenTofu module dependency in main.tf (depends_on helm_release)
- [ ] T038 [US2] Run tofu plan in terraform/environments/chocolandiadc-mvp/ and verify ServiceAccount, Secret, ClusterRoleBinding resources
- [ ] T039 [US2] Run tofu apply in terraform/environments/chocolandiadc-mvp/ to create RBAC resources
- [ ] T040 [US2] Verify ServiceAccount created: kubectl get sa headlamp-admin -n headlamp
- [ ] T041 [US2] Verify ClusterRoleBinding created: kubectl get clusterrolebinding headlamp-view-binding
- [ ] T042 [US2] Verify Secret created: kubectl get secret headlamp-admin-token -n headlamp
- [ ] T043 [US2] Extract bearer token: kubectl get secret headlamp-admin-token -n headlamp -o jsonpath='{.data.token}' | base64 -d (save for UI login)
- [ ] T044 [US2] Test RBAC: kubectl auth can-i get pods --as=system:serviceaccount:headlamp:headlamp-admin (expect yes)
- [ ] T045 [US2] Test RBAC: kubectl auth can-i delete pods --as=system:serviceaccount:headlamp:headlamp-admin (expect no)
- [ ] T046 [US2] Test RBAC: kubectl auth can-i get secrets --as=system:serviceaccount:headlamp:headlamp-admin (expect no - Secrets excluded)
- [ ] T047 [US2] Add output for ServiceAccount token secret name at terraform/modules/headlamp/outputs.tf

**Checkpoint**: At this point, RBAC is configured and token can be used to authenticate to Headlamp with read-only access

---

## Phase 5: User Story 3 - Expose Headlamp via Traefik with HTTPS (Priority: P2)

**Goal**: Create Traefik IngressRoute with automatic HTTPS certificate from cert-manager for secure remote access

**Independent Test**: Access https://headlamp.chocolandiadc.com, verify valid certificate, UI loads, HTTP redirects to HTTPS

### Implementation for User Story 3

- [ ] T048 [P] [US3] Create Middleware resource for HTTPS redirect (redirectScheme: https, permanent: true) at terraform/modules/headlamp/ingress.tf
- [ ] T049 [P] [US3] Create Certificate resource for headlamp.chocolandiadc.com (issuerRef: letsencrypt-production, secretName: headlamp-tls) at terraform/modules/headlamp/ingress.tf
- [ ] T050 [US3] Create IngressRoute resource for HTTP (entryPoints: web, middleware: https-redirect, service: noop@internal) at terraform/modules/headlamp/ingress.tf
- [ ] T051 [US3] Create IngressRoute resource for HTTPS (entryPoints: websecure, service: headlamp:80, tls.secretName: headlamp-tls) at terraform/modules/headlamp/ingress.tf
- [ ] T052 [US3] Add depends_on helm_release to IngressRoute resources at terraform/modules/headlamp/ingress.tf
- [ ] T053 [US3] Run tofu plan in terraform/environments/chocolandiadc-mvp/ and verify Middleware, Certificate, 2 IngressRoute resources
- [ ] T054 [US3] Run tofu apply in terraform/environments/chocolandiadc-mvp/ to create ingress resources
- [ ] T055 [US3] Verify Middleware created: kubectl get middleware https-redirect -n headlamp
- [ ] T056 [US3] Verify Certificate created: kubectl get certificate headlamp-cert -n headlamp
- [ ] T057 [US3] Wait for Certificate Ready: kubectl wait --for=condition=Ready certificate/headlamp-cert -n headlamp --timeout=300s
- [ ] T058 [US3] Verify TLS Secret created: kubectl get secret headlamp-tls -n headlamp
- [ ] T059 [US3] Verify IngressRoutes created: kubectl get ingressroute -n headlamp (expect headlamp-http, headlamp-https)
- [ ] T060 [US3] Test DNS resolution: dig headlamp.chocolandiadc.com (verify points to cluster)
- [ ] T061 [US3] Test HTTP redirect: curl -I http://headlamp.chocolandiadc.com (expect 301 redirect to https)
- [ ] T062 [US3] Test HTTPS access: curl -k https://headlamp.chocolandiadc.com (expect 200 OK)
- [ ] T063 [US3] Verify certificate validity: openssl s_client -connect headlamp.chocolandiadc.com:443 -servername headlamp.chocolandiadc.com | openssl x509 -noout -dates
- [ ] T064 [US3] Test browser access: Open https://headlamp.chocolandiadc.com and verify Headlamp UI loads
- [ ] T065 [US3] Add outputs for ingress_hostname and certificate_secret at terraform/modules/headlamp/outputs.tf

**Checkpoint**: At this point, Headlamp is accessible externally via HTTPS with valid Let's Encrypt certificate

---

## Phase 6: User Story 4 - Integrate with Cloudflare Access for Authentication (Priority: P2)

**Goal**: Configure Cloudflare Access policy with Google OAuth to protect Headlamp and prevent unauthorized access

**Independent Test**: Access Headlamp without authentication (should redirect to Cloudflare Access), authenticate with Google OAuth (authorized email), verify access granted

### Implementation for User Story 4

- [ ] T066 [P] [US4] Create Cloudflare Access Application resource for headlamp.chocolandiadc.com at terraform/modules/headlamp/cloudflare.tf
- [ ] T067 [P] [US4] Configure Access Application: name="Headlamp Kubernetes Dashboard", type="self_hosted", session_duration="24h" at terraform/modules/headlamp/cloudflare.tf
- [ ] T068 [P] [US4] Configure Access Application: auto_redirect_to_identity=true, app_launcher_visible=true at terraform/modules/headlamp/cloudflare.tf
- [ ] T069 [P] [US4] Configure Access Application: cors_headers (allowed_methods, allowed_origins, max_age) at terraform/modules/headlamp/cloudflare.tf
- [ ] T070 [US4] Create Cloudflare Access Policy resource "Allow Homelab Admins" at terraform/modules/headlamp/cloudflare.tf
- [ ] T071 [US4] Configure Access Policy: decision="allow", precedence=1, include.email=[authorized emails] at terraform/modules/headlamp/cloudflare.tf
- [ ] T072 [US4] Configure Access Policy: require.login_method=[Google OAuth IdP ID] at terraform/modules/headlamp/cloudflare.tf
- [ ] T073 [US4] Add variable google_oauth_idp_id to terraform/modules/headlamp/variables.tf (sensitive)
- [ ] T074 [US4] Update terraform.tfvars at terraform/environments/chocolandiadc-mvp/terraform.tfvars with google_oauth_idp_id (from Feature 004)
- [ ] T075 [US4] Run tofu plan in terraform/environments/chocolandiadc-mvp/ and verify Access Application and Policy resources
- [ ] T076 [US4] Run tofu apply in terraform/environments/chocolandiadc-mvp/ to create Cloudflare Access resources
- [ ] T077 [US4] Verify Access Application in Cloudflare Zero Trust dashboard (Applications list)
- [ ] T078 [US4] Verify Access Policy attached to application (Policy list shows "Allow Homelab Admins")
- [ ] T079 [US4] Test unauthenticated access: Open headlamp.chocolandiadc.com in incognito (expect redirect to Cloudflare Access login)
- [ ] T080 [US4] Test Google OAuth flow: Click "Sign in with Google", authenticate with authorized email, verify redirect to Headlamp
- [ ] T081 [US4] Test unauthorized email: Attempt authentication with non-authorized email (expect Access Denied 403)
- [ ] T082 [US4] Verify session persistence: Close browser, reopen headlamp.chocolandiadc.com within 24h (should not prompt login)
- [ ] T083 [US4] Add output for cloudflare_access_application_id at terraform/modules/headlamp/outputs.tf

**Checkpoint**: At this point, Headlamp is protected by Cloudflare Access with Google OAuth authentication

---

## Phase 7: User Story 5 - Enable Prometheus Metrics for Headlamp Monitoring (Priority: P3)

**Goal**: Configure Headlamp to integrate with Prometheus for metrics visualization and create documentation

**Independent Test**: Configure Prometheus URL in Headlamp, verify metrics charts display in UI, check Prometheus integration

### Implementation for User Story 5

- [ ] T084 [P] [US5] Add Prometheus URL configuration to Helm values: config.prometheusUrl="http://prometheus-kube-prometheus-prometheus.monitoring:9090" at terraform/modules/headlamp/main.tf
- [ ] T085 [P] [US5] Create monitoring documentation at terraform/modules/headlamp/MONITORING.md explaining Headlamp metrics consumption (not exposition)
- [ ] T086 [US5] Run tofu plan in terraform/environments/chocolandiadc-mvp/ and verify Helm release update with prometheusUrl
- [ ] T087 [US5] Run tofu apply in terraform/environments/chocolandiadc-mvp/ to update Headlamp configuration
- [ ] T088 [US5] Verify Headlamp pods restart with new configuration: kubectl rollout status deployment headlamp -n headlamp
- [ ] T089 [US5] Test Prometheus integration in Headlamp UI: Navigate to any pod, verify metrics charts display (CPU, memory graphs)
- [ ] T090 [US5] Verify Prometheus accessibility from Headlamp pod: kubectl exec -n headlamp deployment/headlamp -- curl -s http://prometheus-kube-prometheus-prometheus.monitoring:9090/api/v1/query?query=up
- [ ] T091 [US5] Document in MONITORING.md: Headlamp is metrics consumer, not exporter (no /metrics endpoint)
- [ ] T092 [US5] Document in MONITORING.md: Use kube-state-metrics for Headlamp pod metrics if needed

**Checkpoint**: At this point, Headlamp displays Prometheus metrics for cluster workloads in the UI

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and final touches affecting all user stories

- [ ] T093 [P] Create module README.md at terraform/modules/headlamp/README.md with usage examples, variables, outputs documentation
- [ ] T094 [P] Create validation script at scripts/validation/test-headlamp.sh for automated integration tests (pod status, RBAC, HTTPS, OAuth)
- [ ] T095 [P] Create troubleshooting guide at terraform/modules/headlamp/TROUBLESHOOTING.md (common issues: certificate not ready, Access denied, token invalid)
- [ ] T096 [P] Create security documentation at terraform/modules/headlamp/SECURITY.md (RBAC permissions, token management, Cloudflare Access setup)
- [ ] T097 Run tofu fmt in terraform/modules/headlamp/ to format all HCL files
- [ ] T098 Run tofu validate in terraform/environments/chocolandiadc-mvp/ final validation check
- [ ] T099 Update CLAUDE.md at /Users/cbenitez/chocolandia_kube/CLAUDE.md with Feature 007 technologies (already done by setup script)
- [ ] T100 Run end-to-end quickstart validation from specs/007-headlamp-web-ui/quickstart.md (Steps 1-11)
- [ ] T101 Verify all success criteria from spec.md: SC-001 through SC-012 (pod startup, UI load time, HTTPS, OAuth, RBAC, etc.)
- [ ] T102 Create backup of ServiceAccount token in secure location (password manager)
- [ ] T103 Test Headlamp access from external device (phone/tablet) via https://headlamp.chocolandiadc.com
- [ ] T104 Document deployed configuration in module README: namespace, domain, replicas, authorized emails
- [ ] T105 Commit all changes with message: "feat: Feature 007 - Headlamp Web UI deployment (US1-US5 complete)"

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational phase - Foundation for all other stories
- **User Story 2 (Phase 4)**: Depends on Foundational phase - Can run in parallel with US1 but logically follows US1
- **User Story 3 (Phase 5)**: Depends on US1 (requires Headlamp service) - Can run in parallel with US2
- **User Story 4 (Phase 6)**: Depends on US3 (requires IngressRoute) - Sequential after US3
- **User Story 5 (Phase 7)**: Depends on US1 (requires Headlamp deployed) - Can run in parallel with US2-US4
- **Polish (Phase 8)**: Depends on all user stories completion

### User Story Dependencies

```
Foundational (Phase 2) [BLOCKING]
    ↓
US1 (Phase 3) - Deploy Headlamp [P1] 🎯 MVP
    ↓
    ├─→ US2 (Phase 4) - RBAC [P1, MVP] (depends on US1, can overlap)
    ├─→ US3 (Phase 5) - Traefik + HTTPS [P2] (depends on US1)
    │       ↓
    │       └─→ US4 (Phase 6) - Cloudflare Access [P2] (depends on US3)
    │
    └─→ US5 (Phase 7) - Prometheus Metrics [P3] (depends on US1, independent)
```

### Within Each User Story

- **US1**: Module structure → Helm release → Verify deployment → Port-forward test
- **US2**: ServiceAccount → Secret → ClusterRoleBinding → Token extraction → RBAC test
- **US3**: Middleware → Certificate → IngressRoutes → Wait for cert → HTTPS test
- **US4**: Access Application → Access Policy → Verify in dashboard → OAuth flow test
- **US5**: Prometheus URL config → Update deployment → Verify metrics display

### Parallel Opportunities

**Phase 1 (Setup)**: All 3 tasks can run in parallel
```bash
T001 (module directory) || T002 (validation directory) || T003 (README)
```

**Phase 2 (Foundational)**: Tasks T005-T008 can run in parallel (verification checks)
```bash
T005 (Traefik check) || T006 (cert-manager check) || T007 (Cloudflare check) || T008 (Prometheus check)
```

**Phase 3 (US1)**: Task T012 can start immediately, then parallel execution possible
```bash
After T013 (Helm provider):
T014 || T015 || T016 || T017 || T018 || T019 || T020 || T021 || T022 (Helm values configuration)
```

**Phase 4 (US2)**: Tasks T034-T036 can run in parallel (RBAC resources)
```bash
T034 (ServiceAccount) || T035 (Secret) || T036 (ClusterRoleBinding)
```

**Phase 5 (US3)**: Tasks T048-T049 can run in parallel
```bash
T048 (Middleware) || T049 (Certificate)
```

**Phase 6 (US4)**: Tasks T066-T069 can run in parallel (Access Application config)
```bash
T066 || T067 || T068 || T069 (Access Application configuration)
```

**Phase 7 (US5)**: Tasks T084-T085 can run in parallel
```bash
T084 (Prometheus URL) || T085 (Monitoring docs)
```

**Phase 8 (Polish)**: Tasks T093-T096 can run in parallel (documentation)
```bash
T093 (README) || T094 (test script) || T095 (troubleshooting) || T096 (security docs)
```

**Cross-Story Parallelism** (if team capacity):
- After Foundational complete, US2 and US5 can start while US1 is in progress (minimal dependency)
- US3 can start once US1 service is created (around T030)
- US4 can start once US3 IngressRoute is created (around T059)

---

## Parallel Example: Multiple Developers

### Scenario: 2 Developers

**Developer 1 focuses on MVP (US1 + US2)**:
1. Complete Setup + Foundational together
2. Work on US1 (Deploy Headlamp) - Tasks T012-T033
3. Work on US2 (RBAC) - Tasks T034-T047
4. Test MVP: Headlamp deployed with read-only access

**Developer 2 focuses on External Access (US3 + US4)**:
1. Wait for US1 Service creation (after T031)
2. Work on US3 (Traefik + HTTPS) - Tasks T048-T065
3. Work on US4 (Cloudflare Access) - Tasks T066-T083
4. Test external access: HTTPS with OAuth authentication

**Both complete**: US5 (Prometheus) can be done by either developer - Tasks T084-T092

### Scenario: Solo Developer (Priority Order)

1. Complete Setup + Foundational (T001-T011)
2. ✅ **MVP Checkpoint**: US1 + US2 (T012-T047) → Test internally with token
3. Add external access: US3 + US4 (T048-T083) → Test HTTPS + OAuth
4. Add observability: US5 (T084-T092) → Test Prometheus integration
5. Polish: Phase 8 (T093-T105) → Final validation

---

## Implementation Strategy

### MVP First (US1 + US2 Only) - Estimated 90 minutes

**Goal**: Headlamp deployed with read-only RBAC access, testable internally

1. **Complete Phase 1: Setup** (T001-T003) - ~5 min
2. **Complete Phase 2: Foundational** (T004-T011) - ~15 min
3. **Complete Phase 3: US1** (T012-T033) - ~45 min
4. **Complete Phase 4: US2** (T034-T047) - ~25 min
5. **STOP and VALIDATE**:
   - Port-forward to Headlamp service
   - Login with ServiceAccount token
   - Verify cluster resources visible
   - Verify read-only (delete attempt fails)
6. **MVP COMPLETE**: Headlamp functional for internal cluster management

### Incremental Delivery - Estimated 210 minutes total

1. **MVP (US1 + US2)** → ~90 min → Test internally → ✅ MVP functional
2. **Add US3 (HTTPS)** → ~60 min → Test https://headlamp.chocolandiadc.com → ✅ External HTTPS access
3. **Add US4 (OAuth)** → ~45 min → Test Google OAuth flow → ✅ Authenticated access
4. **Add US5 (Metrics)** → ~30 min → Test Prometheus charts → ✅ Observability complete
5. **Polish (Docs + Validation)** → ~30 min → Run quickstart validation → ✅ Feature complete

### Recommended Deployment Flow

```
1. Develop on feature branch (007-headlamp-web-ui)
2. Complete MVP (US1 + US2) → Commit: "feat: Headlamp MVP (US1+US2)"
3. Test MVP internally
4. Add US3 → Commit: "feat: Headlamp HTTPS access (US3)"
5. Add US4 → Commit: "feat: Headlamp OAuth authentication (US4)"
6. Add US5 → Commit: "feat: Headlamp Prometheus integration (US5)"
7. Polish → Commit: "feat: Headlamp documentation and validation"
8. Create PR to main
9. Review, test, merge
10. Deploy to production cluster via tofu apply from main branch
```

---

## Task Summary

**Total Tasks**: 105
- **Phase 1 (Setup)**: 3 tasks (~5 min)
- **Phase 2 (Foundational)**: 8 tasks (~15 min)
- **Phase 3 (US1 - Deploy Headlamp)**: 22 tasks (~45 min) 🎯 MVP
- **Phase 4 (US2 - RBAC)**: 14 tasks (~25 min) 🎯 MVP
- **Phase 5 (US3 - HTTPS)**: 18 tasks (~60 min)
- **Phase 6 (US4 - OAuth)**: 18 tasks (~45 min)
- **Phase 7 (US5 - Metrics)**: 9 tasks (~30 min)
- **Phase 8 (Polish)**: 13 tasks (~30 min)

**Parallel Opportunities**: 35 tasks marked [P] can run concurrently (33% parallelizable)

**MVP Scope** (recommended first delivery):
- US1 + US2 = 36 tasks (~90 minutes)
- Delivers: Headlamp functional with read-only access (internal)

**Full Feature Scope**:
- All user stories = 105 tasks (~210 minutes)
- Delivers: Headlamp with HTTPS, OAuth, Prometheus integration

**Independent Test Criteria**:
- ✅ **US1**: Port-forward to service, access UI, verify cluster overview
- ✅ **US2**: Authenticate with token, view resources, delete fails with permission error
- ✅ **US3**: Access via https://headlamp.chocolandiadc.com, valid certificate, UI loads
- ✅ **US4**: Unauthenticated access blocked, Google OAuth succeeds, authorized email grants access
- ✅ **US5**: Prometheus metrics charts display in Headlamp UI for pods/deployments

---

## Notes

- **[P] tasks**: Different files or independent checks, safe to run in parallel
- **[Story] labels**: Map tasks to specific user stories for traceability
- **File paths**: All tasks include exact file paths for immediate execution
- **Checkpoints**: Each user story phase ends with validation checkpoint
- **MVP first**: US1 + US2 provide core value (internal cluster management)
- **Incremental**: Each story adds value without breaking previous functionality
- **Constitution compliance**: All tasks follow OpenTofu IaC, GitOps, Security Hardening principles
- **No test tasks**: Tests not explicitly requested in specification, omitted per guidelines
- **Dependencies**: Clear separation between foundational work and user stories
- **Time estimates**: Based on similar IaC modules (Traefik, cert-manager, Cloudflare from Features 004-006)
