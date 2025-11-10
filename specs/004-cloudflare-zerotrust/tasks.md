# Implementation Tasks - Feature 004: Cloudflare Zero Trust VPN Access

> **Generated**: 2025-11-09
> **Feature**: Cloudflare Zero Trust VPN Access
> **Target**: K3s cluster on Eero network with Terraform-managed tunnels

---

## Task Legend

- **Task ID**: Sequential identifier (T001, T002, etc.)
- **[P]**: Parallelizable task (can be done concurrently with adjacent [P] tasks)
- **Story Labels**: [US1], [US2], [US3] for user story phases only
- **Estimated Time**: Approximate time per task (~15 min average)

---

## Phase 1: Setup (Project Initialization)

**Goal**: Create project structure and scaffolding
**Estimated Time**: 60-90 minutes

- [X] T001 Create Terraform module directory structure at `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/` (~10 min)
- [X] T002 Create environment directory at `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/` (~5 min)
- [X] T003 Create scripts directory and test skeleton at `/Users/cbenitez/chocolandia_kube/scripts/test-tunnel.sh` with executable permissions (~10 min)
- [X] T004 Create documentation directory at `/Users/cbenitez/chocolandia_kube/docs/004-cloudflare-tunnel/` (~5 min)
- [X] T005 Create `.gitignore` entries for `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars` and `.terraform/` directories (~5 min)
- [X] T006 Initialize Git tracking and commit setup phase changes (~10 min)

**Validation**: All directories exist, .gitignore configured, test-tunnel.sh is executable

---

## Phase 2: Foundational (Prerequisites)

**Goal**: Gather external resources and configure base Terraform
**Estimated Time**: 90-120 minutes

- [ ] T007 [P] Document manual step: Create Cloudflare API Token with Account.Tunnel:Edit, Account.Access:Edit, Zone.DNS:Edit permissions in `/Users/cbenitez/chocolandia_kube/docs/004-cloudflare-tunnel/SETUP.md` (~15 min)
- [ ] T008 [P] Document manual step: Retrieve Cloudflare Account ID and Zone ID for chocolandiadc.com in `/Users/cbenitez/chocolandia_kube/docs/004-cloudflare-tunnel/SETUP.md` (~10 min)
- [ ] T009 Create `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars.example` with placeholder values for API token, account ID, zone ID, authorized emails (~15 min)
- [ ] T010 Create actual `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars` file locally (NOT committed) with real values (~10 min)
- [ ] T011 Create `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/providers.tf` with Cloudflare provider (~> 4.0) and Kubernetes provider configuration (~20 min)
- [ ] T012 Create `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/versions.tf` with Terraform >= 1.6 and required provider versions (~10 min)
- [ ] T013 Run `tofu init` in environments/chocolandiadc-mvp/ to initialize providers and verify configuration (~10 min)
- [ ] T014 Document manual step: Configure Google OAuth application in Google Cloud Console (OAuth 2.0 Client ID) and record Client ID/Secret in `/Users/cbenitez/chocolandia_kube/docs/004-cloudflare-tunnel/SETUP.md` (~20 min)
- [ ] T015 Add Google OAuth Client ID and Client Secret to `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars` (~5 min)

**Validation**: tofu init succeeds, terraform.tfvars exists locally, SETUP.md documents all manual steps

---

## Phase 3: User Story 1 - Remote Secure Access (MVP)

**Goal**: Deploy functional Cloudflare Tunnel with DNS and ingress routes
**Estimated Time**: 180-240 minutes
**Priority**: P1 (MVP)

### Module Development

- [ ] T016 [US1] Create `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/variables.tf` with inputs: tunnel_name, cloudflare_account_id, cloudflare_zone_id, namespace, replica_count, ingress_rules (list), authorized_emails (~20 min)
- [ ] T017 [US1] Create `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/outputs.tf` with outputs: tunnel_id, tunnel_cname, namespace (~10 min)
- [ ] T018 [US1] Create `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/cloudflare.tf` with `random_password.tunnel_secret` resource (32 chars, special=false) (~15 min)
- [ ] T019 [US1] Add `cloudflare_tunnel` resource to `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/cloudflare.tf` with name, account_id, and secret (~15 min)
- [ ] T020 [US1] Add `cloudflare_tunnel_config` resource to `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/cloudflare.tf` with dynamic ingress rules from var.ingress_rules (~25 min)
- [ ] T021 [US1] Create `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/main.tf` with `kubernetes_namespace` resource (~10 min)
- [ ] T022 [US1] Add `kubernetes_secret` resource to `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/main.tf` with tunnel token (from cloudflare_tunnel.tunnel_token) (~15 min)
- [ ] T023 [US1] Add `kubernetes_deployment` resource to `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/main.tf` with cloudflared container (image: cloudflare/cloudflared:latest, args: ["tunnel", "--no-autoupdate", "run", "--token", "$(TOKEN)"]) (~30 min)
- [ ] T024 [US1] Add resource limits (cpu: 100m, memory: 128Mi) and requests to cloudflared container spec in `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/main.tf` (~10 min)
- [ ] T025 [US1] Add liveness and readiness probes (httpGet on localhost:2000/ready) to cloudflared container in `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/main.tf` (~15 min)

### Environment Configuration

- [ ] T026 [US1] Create `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare-tunnel.tf` calling the cloudflare-tunnel module with tunnel_name="chocolandiadc-tunnel" (~15 min)
- [ ] T027 [US1] Define ingress_rules variable in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare-tunnel.tf` with pihole.chocolandiadc.com → http://pihole-web.pihole.svc.cluster.local:80 (~15 min)
- [ ] T028 [US1] Add grafana.chocolandiadc.com → http://grafana.monitoring.svc.cluster.local:3000 to ingress_rules in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare-tunnel.tf` (~10 min)
- [ ] T029 [US1] Create `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare-dns.tf` with `cloudflare_record` resource for pihole.chocolandiadc.com CNAME to tunnel CNAME (~20 min)
- [ ] T030 [US1] Add `cloudflare_record` resource for grafana.chocolandiadc.com CNAME to `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare-dns.tf` (~10 min)

### Deployment and Testing

- [ ] T031 [US1] Run `tofu fmt` and `tofu validate` in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/` to check syntax (~5 min)
- [ ] T032 [US1] Run `tofu plan` in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/` and review planned changes (~10 min)
- [ ] T033 [US1] Run `tofu apply` in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/` to deploy tunnel infrastructure (~15 min)
- [ ] T034 [US1] Verify cloudflared pod is running: `kubectl get pods -n cloudflare-tunnel` (~5 min)
- [ ] T035 [US1] Check cloudflared logs for successful connection: `kubectl logs -n cloudflare-tunnel -l app=cloudflare-tunnel` (~5 min)
- [ ] T036 [US1] Test external connectivity: Access https://pihole.chocolandiadc.com from mobile network (NOT home WiFi) and verify DNS reaches tunnel (~10 min)
- [ ] T037 [US1] Test grafana connectivity: Access https://grafana.chocolandiadc.com from mobile network and verify response (~10 min)
- [ ] T038 [US1] Verify DNS records: `dig pihole.chocolandiadc.com` and `dig grafana.chocolandiadc.com` return Cloudflare CNAME (~5 min)

**Validation**: SC-001 (access within 5s), SC-004 (no public ports), SC-005 (2+ services), SC-006 (Terraform-only deployment)

---

## Phase 4: User Story 2 - Access Control (P2)

**Goal**: Implement email-based authentication with Google OAuth
**Estimated Time**: 90-120 minutes
**Priority**: P2

- [ ] T039 [US2] Create `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare-access.tf` with `cloudflare_access_identity_provider` resource (type: google, Google OAuth client ID/secret from tfvars) (~25 min)
- [ ] T040 [US2] Add `cloudflare_access_application` resource to `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare-access.tf` for *.chocolandiadc.com wildcard (~20 min)
- [ ] T041 [US2] Add `cloudflare_access_policy` resource to `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare-access.tf` with email whitelist from var.authorized_emails (~20 min)
- [ ] T042 [US2] Add authorized_emails variable to `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars` with your Gmail address (~5 min)
- [ ] T043 [US2] Run `tofu plan` and `tofu apply` in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/` to deploy access policies (~10 min)
- [ ] T044 [US2] Test authorized access: Access https://pihole.chocolandiadc.com from mobile network, verify Google OAuth redirect and successful login (~10 min)
- [ ] T045 [US2] Test unauthorized access: Access https://pihole.chocolandiadc.com using non-whitelisted Gmail account, verify blocked within 2 seconds (~10 min)
- [ ] T046 [US2] Verify session persistence: Reload page without re-authenticating (~5 min)

**Validation**: SC-002 (unauthorized blocked within 2s), email-based authorization working

---

## Phase 5: User Story 3 - HA & Monitoring (P3)

**Goal**: Multi-replica deployment with auto-recovery
**Estimated Time**: 60-90 minutes
**Priority**: P3

- [ ] T047 [US3] Update replica_count to 2 in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/cloudflare-tunnel.tf` module call (~5 min)
- [ ] T048 [US3] Create `kubernetes_pod_disruption_budget` resource in `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/main.tf` with minAvailable=1 (~15 min)
- [ ] T049 [US3] Run `tofu apply` in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/` to scale to 2 replicas (~10 min)
- [ ] T050 [US3] Verify 2 cloudflared pods running: `kubectl get pods -n cloudflare-tunnel` (~5 min)
- [ ] T051 [US3] Test auto-recovery: Delete one pod `kubectl delete pod -n cloudflare-tunnel -l app=cloudflare-tunnel --field-selector status.phase=Running | head -1` and verify new pod starts within 30 seconds (~15 min)
- [ ] T052 [US3] Test connectivity during pod deletion: Continuously curl https://pihole.chocolandiadc.com while deleting pod, verify zero downtime (~15 min)
- [ ] T053 [US3] [P] (Optional) Create `kubernetes_service` resource in `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/main.tf` exposing Prometheus metrics on port 2000 (~20 min)

**Validation**: SC-003 (auto-recovery within 30s), HA with 2 replicas

---

## Phase 6: Polish (Documentation & Validation)

**Goal**: Finalize documentation, reproducibility testing, troubleshooting guides
**Estimated Time**: 90-120 minutes

- [ ] T054 [P] Create `/Users/cbenitez/chocolandia_kube/terraform/modules/cloudflare-tunnel/README.md` with module description, inputs, outputs, usage example (~30 min)
- [ ] T055 [P] Create `/Users/cbenitez/chocolandia_kube/docs/004-cloudflare-tunnel/TROUBLESHOOTING.md` with common issues (pod not starting, tunnel not connecting, DNS not resolving, OAuth errors) (~30 min)
- [ ] T056 Create `/Users/cbenitez/chocolandia_kube/scripts/test-tunnel.sh` with automated checks: kubectl pod status, DNS resolution, HTTP 200 from pihole/grafana, OAuth redirect present (~30 min)
- [ ] T057 Run `tofu fmt -recursive` in `/Users/cbenitez/chocolandia_kube/terraform/` to format all .tf files (~5 min)
- [ ] T058 Run `tofu validate` in all modules and environments to ensure no errors (~5 min)
- [ ] T059 Test SC-006 reproducibility: Run `tofu destroy` in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/`, verify all resources deleted (~10 min)
- [ ] T060 Test SC-006 reproducibility: Run `tofu apply` again in `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/`, verify identical infrastructure recreated (~15 min)
- [ ] T061 Run `/Users/cbenitez/chocolandia_kube/scripts/test-tunnel.sh` end-to-end validation script and verify all checks pass (~10 min)
- [ ] T062 Update `/Users/cbenitez/chocolandia_kube/CLAUDE.md` with Cloudflare Zero Trust, cloudflared, Terraform provider ~> 4.0 to Active Technologies section (~10 min)
- [ ] T063 Create final commit with all changes and tag as `feature-004-complete` (~10 min)

**Validation**: All success criteria met (SC-001 through SC-006), documentation complete, reproducible infrastructure

---

## Dependency Graph

```
Phase 1 (Setup)
  ↓
Phase 2 (Foundational)
  ↓
Phase 3 (US1 - MVP) ────→ Feature Ready for Basic Use
  ↓
Phase 4 (US2) ───────────→ Feature Ready for Production
  ↓
Phase 5 (US3) ───────────→ Feature Complete
  ↓
Phase 6 (Polish) ────────→ Feature Production-Ready
```

**User Story Completion Order**:
1. **US1** (P1, MVP): T016-T038 - Core tunnel connectivity
2. **US2** (P2): T039-T046 - Access control
3. **US3** (P3): T047-T053 - High availability

---

## Parallel Execution Examples

### Phase 2 (Foundational):
- **Parallel Group 1**: T007 (API token docs) + T008 (Account/Zone ID docs) can run simultaneously

### Phase 6 (Polish):
- **Parallel Group 1**: T054 (module README) + T055 (troubleshooting guide) + T053 (metrics service) can run simultaneously

---

## MVP Scope Definition

**Minimum Viable Product (MVP)** = Phase 1 + Phase 2 + Phase 3 (US1 only)

**MVP Deliverables**:
- Cloudflare Tunnel deployed via Terraform
- 2 services accessible externally (Pi-hole, Grafana)
- DNS records automated
- Kubernetes deployment with health probes
- Zero public ports exposed
- 100% reproducible via `tofu apply`

**MVP Success Criteria**: SC-001, SC-004, SC-005, SC-006

**Post-MVP** (P2/P3): Access control (US2), HA/monitoring (US3)

---

## Estimated Total Time

- **Phase 1**: 60-90 min
- **Phase 2**: 90-120 min
- **Phase 3 (US1)**: 180-240 min
- **Phase 4 (US2)**: 90-120 min
- **Phase 5 (US3)**: 60-90 min
- **Phase 6**: 90-120 min

**Total Estimated Time**: 570-780 minutes (9.5-13 hours)

**MVP Time** (Phase 1-3): 330-450 minutes (5.5-7.5 hours)

---

## Notes

- All Terraform work uses OpenTofu 1.6+ (`tofu` commands)
- Never commit `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars` (contains secrets)
- Always test from external network (mobile data) to verify tunnel, NOT from home WiFi
- Cloudflare API token requires Account and Zone level permissions
- Google OAuth requires manual setup in Google Cloud Console (cannot be automated)
- Module follows Terraform best practices: variables, outputs, inline Kubernetes resources
- All tasks include absolute file paths as required

---

**End of tasks.md**
