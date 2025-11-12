# Implementation Tasks: GitOps Continuous Deployment with ArgoCD

**Feature**: 008-gitops-argocd
**Branch**: `008-gitops-argocd`
**Total Tasks**: 98 tasks
**Estimated Time**: ~180 minutes (3 hours)

## Task Organization

Tasks are organized by user story to enable independent implementation and testing:
- **Phase 1**: Setup (4 tasks, ~10 min)
- **Phase 2**: Foundational Prerequisites (6 tasks, ~15 min)
- **Phase 3**: User Story 1 - Deploy ArgoCD (P1) - 20 tasks, ~40 min
- **Phase 4**: User Story 2 - Configure Application (P1, MVP) - 14 tasks, ~25 min
- **Phase 5**: User Story 3 - Enable Auto-Sync (P1, MVP) - 12 tasks, ~20 min
- **Phase 6**: User Story 4 - Expose via Traefik + HTTPS (P2) - 15 tasks, ~30 min
- **Phase 7**: User Story 5 - Prometheus Integration (P3) - 10 tasks, ~20 min
- **Phase 8**: User Story 6 - Web App Template (P2) - 9 tasks, ~15 min
- **Phase 9**: Polish & Cross-Cutting Concerns (8 tasks, ~15 min)

---

## Phase 1: Setup (4 tasks, ~10 minutes)

**Goal**: Create project directory structure and initialize documentation per implementation plan.

### Tasks

- [ ] T001 [P] Create terraform/modules/argocd/ directory structure
- [ ] T002 [P] Create kubernetes/argocd/ directory structure with applications/ and projects/ subdirectories
- [ ] T003 [P] Create scripts/argocd/ directory for operational scripts
- [ ] T004 [P] Create tests/argocd/ directory for validation scripts

**Parallel Opportunities**: All 4 tasks can run in parallel (different directories)

---

## Phase 2: Foundational Prerequisites (6 tasks, ~15 minutes)

**Goal**: Verify cluster prerequisites and create OpenTofu module scaffolding before ArgoCD deployment.

**Blocking for**: All user stories (must complete before any user story)

### Tasks

- [ ] T005 Verify K3s cluster is running and accessible via kubectl in terraform/environments/chocolandiadc-mvp/kubeconfig
- [ ] T006 Verify Traefik ingress controller is deployed (kubectl get pods -n traefik)
- [ ] T007 Verify cert-manager is deployed (kubectl get pods -n cert-manager)
- [ ] T008 Verify Cloudflare Zero Trust tunnel is configured (kubectl get pods -n cloudflare-tunnel)
- [ ] T009 [P] Create terraform/modules/argocd/variables.tf with input variable declarations (argocd_domain, github_token, authorized_emails, etc.)
- [ ] T010 [P] Create terraform/modules/argocd/outputs.tf with module outputs (namespace, service_name, admin_password_secret)

**Parallel Opportunities**: T009 and T010 can run in parallel (different files)

**Validation**: All prerequisites verified before proceeding to User Story 1

---

## Phase 3: User Story 1 - Deploy ArgoCD in K3s Cluster (P1, MVP) - 20 tasks, ~40 minutes

**User Story**: Deploy ArgoCD using Helm chart managed through OpenTofu, establishing the GitOps foundation for automated continuous deployment.

**Independent Test**: ArgoCD pods Running, web UI accessible via port-forward, empty applications list visible.

**Acceptance Criteria**:
- ArgoCD namespace created and all components reach Running status within 2 minutes
- argocd-server service created and listening on port 443
- Initial admin password stored in Kubernetes Secret
- ArgoCD web UI accessible and shows empty applications list

### Tasks

#### ArgoCD Module - Main Configuration

- [ ] T011 [US1] Create terraform/modules/argocd/main.tf with helm_release resource for ArgoCD chart (version 5.51.0)
- [ ] T012 [US1] Configure ArgoCD Helm values in terraform/modules/argocd/main.tf: global.domain, server replicas=1, resources limits
- [ ] T013 [US1] Configure ArgoCD repo-server Helm values in terraform/modules/argocd/main.tf: replicas=1, resources, metrics enabled
- [ ] T014 [US1] Configure ArgoCD application-controller Helm values in terraform/modules/argocd/main.tf: replicas=1, resources, metrics enabled
- [ ] T015 [US1] Configure ArgoCD redis Helm values in terraform/modules/argocd/main.tf: enabled=true, resources limits
- [ ] T016 [US1] Configure ArgoCD dex disabled in terraform/modules/argocd/main.tf: dex.enabled=false
- [ ] T017 [US1] Configure ArgoCD timeout.reconciliation=180s in terraform/modules/argocd/main.tf configs.cm section

#### Custom Health Checks for CRDs

- [ ] T018 [P] [US1] Add Traefik IngressRoute custom health check Lua script in terraform/modules/argocd/main.tf configs.cm.resource.customizations
- [ ] T019 [P] [US1] Add cert-manager Certificate custom health check Lua script in terraform/modules/argocd/main.tf configs.cm.resource.customizations

#### GitHub Credentials Secret

- [ ] T020 [US1] Create terraform/modules/argocd/github-credentials.tf with kubernetes_secret resource for repo authentication
- [ ] T021 [US1] Configure GitHub Secret in terraform/modules/argocd/github-credentials.tf: type=git, url, username, password (PAT from var.github_token)
- [ ] T022 [US1] Add argocd.argoproj.io/secret-type: repository label to Secret in terraform/modules/argocd/github-credentials.tf

#### Environment Configuration

- [ ] T023 [US1] Create terraform/environments/chocolandiadc-mvp/argocd.tf with module invocation for ArgoCD
- [ ] T024 [US1] Add ArgoCD variable declarations in terraform/environments/chocolandiadc-mvp/variables.tf (argocd_domain, github_token, etc.)
- [ ] T025 [US1] Add ArgoCD variable values in terraform/environments/chocolandiadc-mvp/terraform.tfvars (domain, token, authorized_emails)

#### Deployment and Verification

- [ ] T026 [US1] Run tofu init in terraform/environments/chocolandiadc-mvp/ to initialize ArgoCD module
- [ ] T027 [US1] Run tofu plan -target=module.argocd to preview ArgoCD deployment
- [ ] T028 [US1] Run tofu apply -target=module.argocd to deploy ArgoCD to cluster
- [ ] T029 [US1] Verify ArgoCD namespace created: kubectl get namespace argocd
- [ ] T030 [US1] Verify all ArgoCD pods Running: kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

**Independent Test for US1**:
```bash
# Verify ArgoCD deployment
kubectl get pods -n argocd
kubectl get svc -n argocd argocd-server

# Extract admin password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Port-forward to ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Access UI: https://localhost:8080 (admin / <password>)
# Expected: Empty applications list
```

**Parallel Opportunities**:
- T018, T019 (custom health checks, different CRDs)
- T020-T022 (GitHub credentials, can develop while Helm config is being written)

---

## Phase 4: User Story 2 - Configure ArgoCD Application for chocolandia_kube (P1, MVP) - 14 tasks, ~25 minutes

**User Story**: Create ArgoCD Application resource that monitors chocolandia_kube GitHub repository and synchronizes infrastructure changes when PRs are merged to main.

**Dependencies**: Requires US1 (ArgoCD deployed)

**Independent Test**: Application created, ArgoCD detects repository, shows OutOfSync status, manual sync applies changes, cluster resources updated.

**Acceptance Criteria**:
- Application appears in ArgoCD UI with repository URL and target path
- Application configured with auto-sync disabled (manual mode)
- Changes pushed to main branch detected as OutOfSync
- Manual sync via UI/CLI applies changes to cluster
- Cluster resources reflect Git state after sync

### Tasks

#### Application Manifest Creation

- [ ] T031 [US2] Create kubernetes/argocd/applications/chocolandia-kube.yaml with Application CRD metadata
- [ ] T032 [US2] Configure Application spec.project=default in kubernetes/argocd/applications/chocolandia-kube.yaml
- [ ] T033 [US2] Configure Application spec.source in kubernetes/argocd/applications/chocolandia-kube.yaml: repoURL, targetRevision=main, path=kubernetes/argocd/applications
- [ ] T034 [US2] Configure Application spec.destination in kubernetes/argocd/applications/chocolandia-kube.yaml: server, namespace=argocd
- [ ] T035 [US2] Configure Application spec.syncPolicy in kubernetes/argocd/applications/chocolandia-kube.yaml: automated=null, syncOptions=[CreateNamespace=true, PruneLast=true]
- [ ] T036 [US2] Configure Application spec.syncPolicy.retry in kubernetes/argocd/applications/chocolandia-kube.yaml: limit=5, backoff (5s, factor=2, maxDuration=3m)
- [ ] T037 [US2] Configure Application spec.ignoreDifferences in kubernetes/argocd/applications/chocolandia-kube.yaml: ignore /spec/replicas for Deployments
- [ ] T038 [US2] Add finalizer resources-finalizer.argocd.argoproj.io in kubernetes/argocd/applications/chocolandia-kube.yaml

#### Application Deployment

- [ ] T039 [US2] Commit Application manifest to Git: git add kubernetes/argocd/applications/chocolandia-kube.yaml && git commit
- [ ] T040 [US2] Push Application manifest to GitHub: git push origin main
- [ ] T041 [US2] Apply Application to cluster: kubectl apply -f kubernetes/argocd/applications/chocolandia-kube.yaml
- [ ] T042 [US2] Verify Application created: kubectl get application -n argocd chocolandia-kube
- [ ] T043 [US2] Check Application status shows OutOfSync: argocd app get chocolandia-kube (or kubectl describe)
- [ ] T044 [US2] Manually trigger sync: argocd app sync chocolandia-kube (or via ArgoCD UI SYNC button)

**Independent Test for US2**:
```bash
# Verify Application exists
kubectl get application -n argocd chocolandia-kube

# Check Application details
argocd app get chocolandia-kube

# Expected output:
# - Sync Status: OutOfSync (before manual sync) → Synced (after)
# - Health Status: Unknown → Progressing → Healthy
# - Repository URL: https://github.com/cbenitez/chocolandia_kube
# - Target Path: kubernetes/argocd/applications
# - Manual sync completes successfully
```

**Parallel Opportunities**: None (sequential workflow: create → commit → push → apply → verify)

---

## Phase 5: User Story 3 - Enable Auto-Sync for Automatic PR Deployment (P1, MVP) - 12 tasks, ~20 minutes

**User Story**: Configure ArgoCD Application with auto-sync and self-heal to automatically apply approved GitHub PR changes without manual intervention.

**Dependencies**: Requires US2 (Application created and manually synced successfully)

**Independent Test**: Auto-sync detects Git changes within 3 minutes, automatically applies changes, self-heal reverts manual drift, error handling prevents bad manifests.

**Acceptance Criteria**:
- ArgoCD detects changes within 3 minutes and automatically initiates sync
- Sync completes successfully with Synced+Healthy status
- Self-heal reverts manual changes to match Git state
- Validation errors shown in Application status, no continuous retries

### Tasks

#### Enable Auto-Sync

- [ ] T045 [US3] Update kubernetes/argocd/applications/chocolandia-kube.yaml: Set syncPolicy.automated.prune=true
- [ ] T046 [US3] Update kubernetes/argocd/applications/chocolandia-kube.yaml: Set syncPolicy.automated.selfHeal=true
- [ ] T047 [US3] Update kubernetes/argocd/applications/chocolandia-kube.yaml: Set syncPolicy.automated.allowEmpty=false
- [ ] T048 [US3] Commit auto-sync changes: git add kubernetes/argocd/applications/chocolandia-kube.yaml && git commit -m "Enable auto-sync for chocolandia-kube Application"
- [ ] T049 [US3] Push auto-sync changes: git push origin main
- [ ] T050 [US3] Apply updated Application: kubectl apply -f kubernetes/argocd/applications/chocolandia-kube.yaml
- [ ] T051 [US3] Verify auto-sync enabled: kubectl get application -n argocd chocolandia-kube -o yaml | grep -A 3 automated

#### Test Auto-Sync Detection

- [ ] T052 [US3] Create test file in repository: echo "# Test auto-sync" >> kubernetes/argocd/README.md
- [ ] T053 [US3] Commit and push test change: git add kubernetes/argocd/README.md && git commit -m "test: Verify auto-sync detection" && git push origin main
- [ ] T054 [US3] Wait 3 minutes for ArgoCD polling interval
- [ ] T055 [US3] Verify auto-sync triggered: argocd app get chocolandia-kube (check Sync Status, Operation State)

#### Test Self-Heal

- [ ] T056 [US3] Create operational script scripts/argocd/enable-auto-sync.sh with auto-sync enablement procedure and validation

**Independent Test for US3**:
```bash
# Test 1: Auto-sync detection
echo "# Test change" >> README.md
git add README.md && git commit -m "test: auto-sync" && git push

# Wait 3 minutes, check ArgoCD
argocd app get chocolandia-kube
# Expected: Auto-sync triggered, Application Synced

# Test 2: Self-heal drift
kubectl scale deployment <some-deployment> --replicas=5

# Wait 3 minutes, check deployment
kubectl get deployment <some-deployment>
# Expected: Replicas reverted to Git-defined value
```

**Parallel Opportunities**: T045-T047 (updating same file, but different fields - can be done as single edit)

---

## Phase 6: User Story 4 - Expose ArgoCD via Traefik with HTTPS and Cloudflare Access (P2) - 15 tasks, ~30 minutes

**User Story**: Create Traefik IngressRoute to expose ArgoCD web UI securely with HTTPS certificate from cert-manager and Cloudflare Access authentication.

**Dependencies**: Requires US1 (ArgoCD deployed)

**Independent Test**: IngressRoute created, Certificate issued, Cloudflare Access configured, HTTPS access works, Google OAuth authentication successful.

**Acceptance Criteria**:
- Cloudflare Access application created with Google OAuth identity provider
- TLS certificate issued for argocd.chocolandiadc.com
- Unauthenticated users redirected to Cloudflare Access login
- Authorized users can access ArgoCD UI after Google OAuth

### Tasks

#### Traefik IngressRoute

- [ ] T057 [P] [US4] Create terraform/modules/argocd/ingress.tf with kubernetes_manifest resource for IngressRoute
- [ ] T058 [US4] Configure IngressRoute in terraform/modules/argocd/ingress.tf: entryPoints=[websecure], routes.match=Host(`${var.argocd_domain}`)
- [ ] T059 [US4] Configure IngressRoute service in terraform/modules/argocd/ingress.tf: name=argocd-server, port=443
- [ ] T060 [US4] Configure IngressRoute TLS in terraform/modules/argocd/ingress.tf: secretName=argocd-tls

#### cert-manager Certificate

- [ ] T061 [P] [US4] Create kubernetes_manifest resource for Certificate in terraform/modules/argocd/ingress.tf
- [ ] T062 [US4] Configure Certificate in terraform/modules/argocd/ingress.tf: secretName=argocd-tls, issuerRef.name=var.cluster_issuer
- [ ] T063 [US4] Configure Certificate dnsNames in terraform/modules/argocd/ingress.tf: [var.argocd_domain]
- [ ] T064 [US4] Configure Certificate duration and renewBefore in terraform/modules/argocd/ingress.tf: 2160h, 720h

#### Cloudflare Access Application + Policy

- [ ] T065 [P] [US4] Create terraform/modules/argocd/cloudflare-access.tf with cloudflare_access_application resource
- [ ] T066 [US4] Configure Access Application in terraform/modules/argocd/cloudflare-access.tf: name, domain=var.argocd_domain, type=self_hosted, session_duration=24h
- [ ] T067 [US4] Create cloudflare_access_policy resource in terraform/modules/argocd/cloudflare-access.tf: name="ArgoCD Authorized Users", decision=allow
- [ ] T068 [US4] Configure Access Policy include in terraform/modules/argocd/cloudflare-access.tf: email=var.authorized_emails
- [ ] T069 [US4] Configure Access Policy require in terraform/modules/argocd/cloudflare-access.tf: login_method=[var.google_oauth_idp_id]

#### Deployment and Verification

- [ ] T070 [US4] Apply IngressRoute, Certificate, and Cloudflare Access: tofu apply -target=module.argocd
- [ ] T071 [US4] Verify Certificate issued: kubectl get certificate -n argocd argocd-tls (READY=True)

**Independent Test for US4**:
```bash
# Verify IngressRoute
kubectl get ingressroute -n argocd argocd-server

# Verify Certificate issued
kubectl get certificate -n argocd argocd-tls
# Expected: READY=True

# Test HTTPS access (unauthenticated)
curl https://argocd.chocolandiadc.com
# Expected: Cloudflare Access login page

# Test authenticated access (browser)
# 1. Navigate to https://argocd.chocolandiadc.com
# 2. Cloudflare Access → Google OAuth
# 3. Authenticate with authorized email
# 4. ArgoCD UI loads
```

**Parallel Opportunities**:
- T057-T060 (IngressRoute), T061-T064 (Certificate), T065-T069 (Cloudflare Access) - 3 separate files

---

## Phase 7: User Story 5 - Integrate ArgoCD with Prometheus for GitOps Metrics (P3) - 10 tasks, ~20 minutes

**User Story**: Configure ArgoCD to expose Prometheus metrics and create ServiceMonitor for automatic scraping, enabling observability of GitOps sync operations.

**Dependencies**: Requires US1 (ArgoCD deployed)

**Independent Test**: ServiceMonitor created, Prometheus scrapes ArgoCD targets (UP status), metrics available in Grafana, sync metrics increment on operations.

**Acceptance Criteria**:
- /metrics endpoint returns Prometheus-format metrics
- ServiceMonitor created and Prometheus operator processes it
- ArgoCD targets appear in Prometheus with UP status
- Metrics available: argocd_app_sync_total, argocd_app_health_status, etc.

### Tasks

#### ServiceMonitor Creation

- [ ] T072 [P] [US5] Create terraform/modules/argocd/prometheus.tf with kubernetes_manifest resource for ServiceMonitor
- [ ] T073 [US5] Configure ServiceMonitor in terraform/modules/argocd/prometheus.tf: name=argocd-metrics, namespace=argocd
- [ ] T074 [US5] Configure ServiceMonitor selector in terraform/modules/argocd/prometheus.tf: matchLabels for ArgoCD services
- [ ] T075 [US5] Configure ServiceMonitor endpoints in terraform/modules/argocd/prometheus.tf: port=metrics, interval=30s, path=/metrics for server, repo-server, controller
- [ ] T076 [US5] Add conditional creation in terraform/modules/argocd/prometheus.tf: count = var.enable_prometheus_metrics ? 1 : 0

#### Deployment and Verification

- [ ] T077 [US5] Apply ServiceMonitor: tofu apply -target=module.argocd
- [ ] T078 [US5] Verify ServiceMonitor created: kubectl get servicemonitor -n argocd argocd-metrics
- [ ] T079 [US5] Verify Prometheus targets: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 → http://localhost:9090/targets (search "argocd", state=UP)
- [ ] T080 [US5] Query ArgoCD metrics in Prometheus: argocd_app_sync_total, argocd_app_health_status, argocd_app_sync_status
- [ ] T081 [US5] Create documentation in terraform/modules/argocd/README.md section for Prometheus integration and available metrics

**Independent Test for US5**:
```bash
# Verify ServiceMonitor
kubectl get servicemonitor -n argocd argocd-metrics

# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser: http://localhost:9090/targets
# Search: "argocd"
# Expected: 3 targets (server, repo-server, controller) with state=UP

# Query metrics
# argocd_app_sync_total
# argocd_app_health_status
# argocd_app_sync_status
```

**Parallel Opportunities**: T072-T076 (single file creation, sequential)

---

## Phase 8: User Story 6 - Create ArgoCD Project Template for Web Applications (P2) - 9 tasks, ~15 minutes

**User Story**: Create reusable ArgoCD Application manifest template that can be easily adapted for future web development projects.

**Dependencies**: Requires US2 (Application pattern established)

**Independent Test**: Template file created, documentation explains usage, template successfully deploys test web app, web app runs in target namespace.

**Acceptance Criteria**:
- Template requires only 4 values: APP_NAME, REPO_URL, TARGET_PATH, NAMESPACE
- Template successfully deploys web app to cluster
- Web app pods Running in target namespace
- Web app accessible via ingress

### Tasks

#### Template Creation

- [ ] T082 [P] [US6] Create kubernetes/argocd/applications/web-app-template.yaml with parameterized Application CRD (placeholders: APP_NAME, REPO_URL, TARGET_PATH, NAMESPACE)
- [ ] T083 [P] [US6] Configure template with sensible defaults in kubernetes/argocd/applications/web-app-template.yaml: project=default, targetRevision=main, syncPolicy=manual initially
- [ ] T084 [P] [US6] Add usage instructions as YAML comments in kubernetes/argocd/applications/web-app-template.yaml: copy template, replace 4 placeholders, apply, verify

#### Documentation

- [ ] T085 [P] [US6] Create kubernetes/argocd/applications/README.md with template documentation
- [ ] T086 [US6] Document prerequisites in kubernetes/argocd/applications/README.md: web project repo with K8s manifests, GitHub access
- [ ] T087 [US6] Document quick start workflow in kubernetes/argocd/applications/README.md: copy template, replace placeholders, apply, sync, enable auto-sync
- [ ] T088 [US6] Add example usage in kubernetes/argocd/applications/README.md: portfolio-app example with filled values

#### Template Testing

- [ ] T089 [US6] Test template with sample web app: Copy template, fill values, apply to cluster, verify deployment
- [ ] T090 [US6] Commit template and documentation: git add kubernetes/argocd/applications/ && git commit -m "Add ArgoCD web app template for future projects" && git push

**Independent Test for US6**:
```bash
# Copy template
cp kubernetes/argocd/applications/web-app-template.yaml my-app.yaml

# Edit my-app.yaml:
# - APP_NAME: "my-app"
# - REPO_URL: "https://github.com/user/my-app"
# - TARGET_PATH: "kubernetes/"
# - NAMESPACE: "web-apps"

# Apply Application
kubectl apply -f my-app.yaml

# Sync Application
argocd app sync my-app

# Verify deployment
kubectl get all -n web-apps
# Expected: Pods Running, Service created, Ingress configured
```

**Parallel Opportunities**: T082-T084 (template file), T085-T088 (documentation) - 2 separate files can be developed in parallel

---

## Phase 9: Polish & Cross-Cutting Concerns (8 tasks, ~15 minutes)

**Goal**: Finalize implementation with code formatting, validation, documentation, and end-to-end testing.

### Tasks

#### Code Quality

- [ ] T091 [P] Run tofu fmt on all OpenTofu files: tofu fmt -recursive terraform/
- [ ] T092 [P] Run tofu validate on ArgoCD module: cd terraform/environments/chocolandiadc-mvp && tofu validate
- [ ] T093 [P] Verify all Kubernetes manifests are valid YAML: kubectl apply --dry-run=client -f kubernetes/argocd/applications/

#### Operational Scripts

- [ ] T094 [P] Create scripts/argocd/health-check.sh to verify ArgoCD components health (pods Running, services accessible)
- [ ] T095 [P] Create scripts/argocd/validate-sync.sh to check ArgoCD Application sync status and health
- [ ] T096 [P] Make scripts executable: chmod +x scripts/argocd/*.sh

#### Documentation

- [ ] T097 Create terraform/modules/argocd/README.md with module documentation (inputs, outputs, usage examples)

#### End-to-End Validation

- [ ] T098 Run full end-to-end validation per quickstart.md: deploy ArgoCD → create Application → manual sync → enable auto-sync → test auto-sync → verify metrics

**Parallel Opportunities**: T091, T092, T093, T094, T095, T096 (all independent tasks, different files/commands)

---

## Dependencies Between User Stories

```
┌──────────────────────────────────────────────────────────────┐
│                    Story Dependencies                         │
└──────────────────────────────────────────────────────────────┘

Setup (Phase 1) + Foundational (Phase 2)
    │
    ├──► US1: Deploy ArgoCD (P1) ◄──────────────┐
    │        │                                   │
    │        ├──► US2: Configure Application (P1, MVP)
    │        │         │
    │        │         ├──► US3: Enable Auto-Sync (P1, MVP)
    │        │         │
    │        │         └──► US6: Web App Template (P2)
    │        │
    │        ├──► US4: Expose via Traefik (P2)
    │        │
    │        └──► US5: Prometheus Integration (P3)
    │
    └──► Polish & Cross-Cutting (Phase 9)

Legend:
- Solid arrow (──►): Hard dependency (must complete parent first)
- US1 blocks: US2, US4, US5 (ArgoCD must be deployed)
- US2 blocks: US3, US6 (Application pattern must exist)
- US3, US4, US5, US6 are independent of each other
```

**Independent User Stories** (can be implemented in parallel after dependencies met):
- After US1: US4, US5 (no dependencies on US2/US3)
- After US2: US3, US6 (both depend on Application pattern)

---

## Parallel Execution Examples

### Phase 3 (US1) Parallelization

```bash
# Step 1: Create module files in parallel (3 developers)
Developer A: T011-T017 (main.tf Helm configuration)
Developer B: T018-T019 (custom health checks)
Developer C: T020-T022 (GitHub credentials)

# Step 2: Environment configuration (sequential, depends on module files)
T023-T025 (environment files)

# Step 3: Deployment (sequential)
T026-T030 (tofu apply + verification)
```

### Phase 6 (US4) Parallelization

```bash
# All 3 components can be developed in parallel:
Developer A: T057-T060 (ingress.tf - IngressRoute)
Developer B: T061-T064 (ingress.tf - Certificate)
Developer C: T065-T069 (cloudflare-access.tf)

# Final step: Deploy all together
T070-T071 (tofu apply + verification)
```

### Phase 9 (Polish) Parallelization

```bash
# All tasks independent, can run in parallel:
Developer A: T091 (tofu fmt)
Developer B: T092 (tofu validate)
Developer C: T093 (kubectl validate)
Developer D: T094-T096 (operational scripts)
Developer E: T097 (module README)

# Final step: End-to-end validation
T098 (sequential, depends on all polish tasks)
```

---

## Implementation Strategy

### MVP Scope (Phases 1-5)

**Goal**: Automated GitOps deployment for chocolandia_kube infrastructure

**Includes**:
- Phase 1: Setup (4 tasks)
- Phase 2: Foundational (6 tasks)
- Phase 3: US1 - Deploy ArgoCD (20 tasks)
- Phase 4: US2 - Configure Application (14 tasks)
- Phase 5: US3 - Enable Auto-Sync (12 tasks)

**Total**: 56 tasks, ~110 minutes (2 hours)

**Delivers**: User request satisfied - "al aprobar el PR en github, los cambios se bajen y se apliquen automaticamente"

### Full Feature Scope (All Phases)

**Goal**: Complete GitOps platform with secure access, monitoring, and web app template

**Includes**: MVP + US4 (Traefik/HTTPS) + US5 (Prometheus) + US6 (Template) + Polish

**Total**: 98 tasks, ~180 minutes (3 hours)

**Delivers**: Full production-ready GitOps platform with observability and reusability

### Incremental Delivery Strategy

1. **Iteration 1** (MVP): Phases 1-5 → Working auto-sync for infrastructure
2. **Iteration 2**: Phase 6 (US4) → Secure HTTPS access via Traefik
3. **Iteration 3**: Phase 7 (US5) → Prometheus monitoring integration
4. **Iteration 4**: Phase 8 (US6) → Web app template for future projects
5. **Iteration 5**: Phase 9 → Polish and finalize

---

## Testing Strategy

### Integration Tests per User Story

**US1 Tests** (ArgoCD Deployment):
- scripts/argocd/health-check.sh: Verify all pods Running
- Manual: Port-forward to UI, login with admin password
- Expected: Empty applications list

**US2 Tests** (Application Configuration):
- kubectl get application chocolandia-kube: Verify Application exists
- argocd app get chocolandia-kube: Check sync status
- Manual sync: argocd app sync chocolandia-kube
- Expected: Application Synced + Healthy

**US3 Tests** (Auto-Sync):
- Test change detection: Make Git commit, wait 3 min, verify auto-sync
- Test self-heal: kubectl scale deployment, verify revert
- Expected: Auto-sync within 3 min, drift corrected

**US4 Tests** (Traefik/HTTPS):
- curl https://argocd.chocolandiadc.com: Expect Cloudflare Access redirect
- Browser test: Google OAuth → ArgoCD UI access
- Expected: Certificate valid, authenticated access works

**US5 Tests** (Prometheus):
- kubectl get servicemonitor -n argocd: Verify ServiceMonitor exists
- Prometheus targets: Check 3 ArgoCD targets UP
- Query metrics: argocd_app_sync_total
- Expected: Metrics available in Prometheus

**US6 Tests** (Web App Template):
- Copy template, fill 4 values, apply
- argocd app sync <test-app>
- kubectl get all -n <namespace>
- Expected: Web app deployed successfully

### End-to-End Validation (Phase 9)

- Run complete quickstart.md procedure
- Verify all acceptance criteria from spec.md
- Confirm MVP user request satisfied
- Test failure scenarios (bad manifest, sync errors)

---

## Task Validation Checklist

✅ **Format Validation**:
- [x] All 98 tasks follow checklist format: `- [ ] T### [P?] [Story?] Description with file path`
- [x] Task IDs sequential (T001-T098)
- [x] [P] marker present for parallelizable tasks (23 tasks marked)
- [x] [Story] labels present for user story phases (US1-US6) (72 tasks with story labels)
- [x] File paths included in task descriptions

✅ **Completeness Validation**:
- [x] All 6 user stories have dedicated phases
- [x] Each user story phase has independent test criteria
- [x] Dependencies clearly documented (US1 blocks US2/US4/US5, US2 blocks US3/US6)
- [x] Parallel opportunities identified per phase
- [x] MVP scope defined (Phases 1-5, 56 tasks)

✅ **Technical Validation**:
- [x] All OpenTofu files referenced: main.tf, variables.tf, outputs.tf, ingress.tf, cloudflare-access.tf, prometheus.tf, github-credentials.tf
- [x] All Kubernetes manifests referenced: chocolandia-kube.yaml, web-app-template.yaml
- [x] All scripts referenced: health-check.sh, validate-sync.sh, enable-auto-sync.sh
- [x] All documentation referenced: README.md files for module and applications

✅ **Execution Validation**:
- [x] Setup phase tasks parallelizable (4 directories, different locations)
- [x] Foundational phase has blocking tasks (prerequisites verification)
- [x] User story phases follow dependency order (US1 → US2 → US3)
- [x] Polish phase tasks parallelizable (code formatting, validation, scripts)

---

## Summary

**Total Tasks**: 98 tasks organized across 9 phases
**MVP Tasks**: 56 tasks (Phases 1-5, ~2 hours)
**Full Implementation**: 98 tasks (~3 hours)

**Parallel Opportunities**: 23 tasks marked [P] for concurrent execution
**User Story Organization**: 6 user stories (US1-US6) with 72 story-specific tasks
**Dependencies**: Clear story dependencies documented (US1 → US2 → US3/US6, US1 → US4/US5)

**Ready for Implementation**: ✅ All tasks specific, executable, with file paths and validation criteria
