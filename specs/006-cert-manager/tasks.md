# Implementation Tasks: cert-manager for SSL/TLS Certificate Management

**Feature**: 006-cert-manager
**Branch**: `006-cert-manager`
**Generated**: 2025-11-11
**Total Tasks**: 79

This document provides a complete, ordered task breakdown for implementing cert-manager with Let's Encrypt integration.

---

## Task Organization

Tasks are organized by user story (from spec.md) to enable independent implementation and testing:

- **Phase 1**: Setup (4 tasks) - Project initialization
- **Phase 2**: Foundational (6 tasks) - Blocking prerequisites
- **Phase 3**: User Story 1 - Deploy cert-manager (P1, MVP) - 15 tasks
- **Phase 4**: User Story 2 - Configure Let's Encrypt Staging Issuer (P1, MVP) - 11 tasks
- **Phase 5**: User Story 3 - Configure Let's Encrypt Production Issuer (P2) - 10 tasks
- **Phase 6**: User Story 4 - Integrate with Traefik Ingress (P2) - 12 tasks
- **Phase 7**: User Story 5 - Configure Certificate Renewal (P3) - 8 tasks
- **Phase 8**: User Story 6 - Enable Prometheus Metrics (P3) - 7 tasks
- **Phase 9**: Polish & Cross-Cutting Concerns - 6 tasks

**MVP Scope**: Phase 1-4 (46 tasks, ~90 minutes) - Includes cert-manager deployment and staging certificate validation

**Full Feature**: All phases (79 tasks, ~150 minutes)

---

## Dependencies

### User Story Completion Order

```
Phase 1 (Setup) → Phase 2 (Foundational)
                          ↓
                    Phase 3 (US1: Deploy cert-manager) [REQUIRED FOR ALL]
                          ↓
          ┌───────────────┴───────────────┐
          ↓                               ↓
   Phase 4 (US2: Staging)          Phase 6 (US4: Traefik)
          ↓                               ↓
   Phase 5 (US3: Production)        Phase 7 (US5: Renewal)
          ↓                               ↓
          └───────────────┬───────────────┘
                          ↓
                   Phase 8 (US6: Metrics)
                          ↓
                   Phase 9 (Polish)
```

**Critical Path**: Phase 1 → 2 → 3 (US1) → 4 (US2) → 5 (US3)

**Independent Stories** (after US1):
- US2, US4, US6 can be implemented in parallel after US1
- US3 depends on US2 (staging validation first)
- US5 depends on US2 or US3 (needs certificates to test renewal)

---

## Phase 1: Setup

**Goal**: Initialize module structure and test directories

**Tasks**:

- [ ] T001 [P] Create cert-manager module directory at terraform/modules/cert-manager/
- [ ] T002 [P] Create test directory at tests/integration/cert-manager/
- [ ] T003 [P] Create module documentation file at terraform/modules/cert-manager/README.md
- [ ] T004 [P] Create environment configuration file at terraform/environments/chocolandiadc-mvp/cert-manager.tf

**Parallel Opportunities**: All 4 tasks can run in parallel (different files, no dependencies)

---

## Phase 2: Foundational

**Goal**: Create OpenTofu module scaffolding and validate prerequisites

**Tasks**:

- [ ] T005 Verify K3s cluster is running and accessible via kubectl
- [ ] T006 Verify Traefik ingress controller is deployed and healthy (Feature 005 dependency)
- [ ] T007 [P] Create versions.tf with required providers (Helm, Kubernetes) at terraform/modules/cert-manager/versions.tf
- [ ] T008 [P] Create variables.tf with module input variables at terraform/modules/cert-manager/variables.tf
- [ ] T009 [P] Create outputs.tf with module output values at terraform/modules/cert-manager/outputs.tf
- [ ] T010 Run tofu fmt and tofu validate on module scaffolding

**Sequential Dependencies**: T005-T006 must complete first (verify prerequisites), then T007-T009 [P], then T010

---

## Phase 3: User Story 1 - Deploy cert-manager (Priority: P1, MVP)

**Story Goal**: Deploy cert-manager in K3s cluster to enable automated SSL/TLS certificate management

**Independent Test**: cert-manager pods running, CRDs installed, webhook configured

**Acceptance Criteria**:
- ✅ cert-manager controller, webhook, cainjector pods running and healthy
- ✅ All CRDs installed (Certificate, ClusterIssuer, etc.)
- ✅ ValidatingWebhookConfiguration and MutatingWebhookConfiguration configured

**Tasks**:

### Infrastructure - Helm Chart Deployment

- [ ] T011 [P] [US1] Create Helm values template file at terraform/modules/cert-manager/helm-values.yaml with resource limits and metrics config
- [ ] T012 [P] [US1] Define helm_release resource for cert-manager in terraform/modules/cert-manager/main.tf (chart: jetstack/cert-manager v1.13.x)
- [ ] T013 [US1] Configure cert-manager namespace creation and RBAC via Helm chart values in main.tf

### Resource Configuration

- [ ] T014 [P] [US1] Configure controller pod resource limits (10m CPU, 32Mi memory requests; 100m CPU, 128Mi limits) in helm-values.yaml
- [ ] T015 [P] [US1] Configure webhook pod resource limits (10m CPU, 32Mi memory requests; 100m CPU, 128Mi limits) in helm-values.yaml
- [ ] T016 [P] [US1] Configure cainjector pod resource limits (10m CPU, 32Mi memory requests; 100m CPU, 128Mi limits) in helm-values.yaml
- [ ] T017 [P] [US1] Enable CRD installation via Helm chart (installCRDs: true) in helm-values.yaml

### Health Checks & Logging

- [ ] T018 [P] [US1] Configure liveness and readiness probes for controller pod in helm-values.yaml
- [ ] T019 [P] [US1] Configure liveness and readiness probes for webhook pod in helm-values.yaml
- [ ] T020 [P] [US1] Configure liveness and readiness probes for cainjector pod in helm-values.yaml
- [ ] T021 [P] [US1] Enable structured logging (JSON format) for all components in helm-values.yaml

### Environment Configuration

- [ ] T022 [US1] Add cert-manager module invocation in terraform/environments/chocolandiadc-mvp/cert-manager.tf with required variables
- [ ] T023 [US1] Add ACME email variable to terraform/environments/chocolandiadc-mvp/terraform.tfvars (replace with actual email)

### Deployment & Validation

- [ ] T024 [US1] Run tofu fmt, tofu validate, tofu plan on cert-manager module
- [ ] T025 [US1] Deploy cert-manager via tofu apply from chocolandiadc-mvp environment

**Integration Tests** (User Story 1):

- [ ] T026 [US1] Verify cert-manager pods achieve Running status within 60 seconds: kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s
- [ ] T027 [US1] Verify all 6 CRDs are installed: kubectl get crd | grep cert-manager | wc -l (expected: 6)
- [ ] T028 [US1] Verify webhook ValidatingWebhookConfiguration exists: kubectl get validatingwebhookconfiguration cert-manager-webhook
- [ ] T029 [US1] Verify webhook service is reachable: kubectl get svc -n cert-manager cert-manager-webhook
- [ ] T030 [US1] Check cert-manager controller logs for errors: kubectl logs -n cert-manager -l app=cert-manager --tail=50

**Parallel Opportunities**:
- T011-T012 can run in parallel (different sections of config)
- T014-T017 can run in parallel (different resource configurations)
- T018-T021 can run in parallel (independent probe configs)
- T026-T029 can run in parallel after deployment (independent validations)

---

## Phase 4: User Story 2 - Configure Let's Encrypt Staging Issuer (Priority: P1, MVP)

**Story Goal**: Create ClusterIssuer for Let's Encrypt staging to test certificate issuance without rate limits

**Independent Test**: Staging ClusterIssuer ready, test certificate issued successfully

**Acceptance Criteria**:
- ✅ Staging ClusterIssuer in Ready state
- ✅ ACME challenge initiated and completed successfully
- ✅ Staging certificate issued and stored in Kubernetes Secret

**Tasks**:

### ClusterIssuer Configuration

- [ ] T031 [P] [US2] Define letsencrypt-staging ClusterIssuer resource in terraform/modules/cert-manager/main.tf with ACME staging server URL
- [ ] T032 [P] [US2] Configure ACME account email (from variable) in staging ClusterIssuer
- [ ] T033 [P] [US2] Configure HTTP-01 challenge solver with Traefik ingress class in staging ClusterIssuer
- [ ] T034 [P] [US2] Define Kubernetes Secret for ACME account private key in staging ClusterIssuer (letsencrypt-staging-account)

### Test Certificate Manifest

- [ ] T035 [P] [US2] Create test staging certificate manifest at tests/integration/cert-manager/test-staging-cert.yaml (domain: test-staging.chocolandiadc.com)
- [ ] T036 [US2] Configure Certificate resource with staging issuer reference in test manifest
- [ ] T037 [US2] Apply staging ClusterIssuer via tofu apply

### Integration Tests (User Story 2)

- [ ] T038 [US2] Verify staging ClusterIssuer is Ready: kubectl get clusterissuer letsencrypt-staging -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
- [ ] T039 [US2] Apply test staging certificate: kubectl apply -f tests/integration/cert-manager/test-staging-cert.yaml
- [ ] T040 [US2] Wait for certificate issuance (max 5 minutes): kubectl wait --for=condition=ready certificate/test-cert-staging -n default --timeout=300s
- [ ] T041 [US2] Verify Secret created: kubectl get secret test-cert-staging-tls -n default
- [ ] T042 [US2] Verify certificate issuer is Let's Encrypt Staging: kubectl get secret test-cert-staging-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer
- [ ] T043 [US2] Check ACME challenge logs: kubectl logs -n cert-manager -l app=cert-manager --tail=100 | grep -i challenge
- [ ] T044 [US2] Clean up test certificate: kubectl delete certificate test-cert-staging -n default

**Parallel Opportunities**:
- T031-T034 can run in parallel (different ClusterIssuer sections)
- T035-T036 can run in parallel (test manifest creation)
- T041-T043 can run in parallel after cert issuance (independent validations)

---

## Phase 5: User Story 3 - Configure Let's Encrypt Production Issuer (Priority: P2)

**Story Goal**: Create ClusterIssuer for Let's Encrypt production to issue trusted certificates

**Independent Test**: Production ClusterIssuer ready, trusted certificate issued and browser-trusted

**Acceptance Criteria**:
- ✅ Production ClusterIssuer in Ready state
- ✅ Trusted certificate issued for production domain
- ✅ Certificate signed by Let's Encrypt and trusted by browsers

**Tasks**:

### ClusterIssuer Configuration

- [ ] T045 [P] [US3] Define letsencrypt-production ClusterIssuer resource in terraform/modules/cert-manager/main.tf with ACME production server URL
- [ ] T046 [P] [US3] Configure ACME account email (from variable) in production ClusterIssuer
- [ ] T047 [P] [US3] Configure HTTP-01 challenge solver with Traefik ingress class in production ClusterIssuer
- [ ] T048 [P] [US3] Define Kubernetes Secret for ACME account private key in production ClusterIssuer (letsencrypt-production-account)

### Test Certificate Manifest

- [ ] T049 [P] [US3] Create test production certificate manifest at tests/integration/cert-manager/test-production-cert.yaml (domain: test-prod.chocolandiadc.com)
- [ ] T050 [US3] Configure Certificate resource with production issuer reference in test manifest
- [ ] T051 [US3] Apply production ClusterIssuer via tofu apply

### Integration Tests (User Story 3)

- [ ] T052 [US3] Verify production ClusterIssuer is Ready: kubectl get clusterissuer letsencrypt-production -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
- [ ] T053 [US3] Apply test production certificate: kubectl apply -f tests/integration/cert-manager/test-production-cert.yaml
- [ ] T054 [US3] Wait for certificate issuance (max 10 minutes): kubectl wait --for=condition=ready certificate/test-cert-production -n default --timeout=600s
- [ ] T055 [US3] Verify Secret created: kubectl get secret test-cert-production-tls -n default
- [ ] T056 [US3] Verify certificate issuer is Let's Encrypt Production (R3): kubectl get secret test-cert-production-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer
- [ ] T057 [US3] Test certificate in browser: open https://test-prod.chocolandiadc.com (verify green lock, no warnings)
- [ ] T058 [US3] Clean up test certificate: kubectl delete certificate test-cert-production -n default

**Parallel Opportunities**:
- T045-T048 can run in parallel (different ClusterIssuer sections)
- T049-T050 can run in parallel (test manifest creation)
- T055-T056 can run in parallel after cert issuance (independent validations)

---

## Phase 6: User Story 4 - Integrate with Traefik Ingress (Priority: P2)

**Story Goal**: Configure Traefik IngressRoutes to automatically request and use certificates from cert-manager

**Independent Test**: IngressRoute with cert-manager annotation automatically provisions certificate, HTTPS works

**Acceptance Criteria**:
- ✅ IngressRoute with annotation creates Certificate resource automatically
- ✅ ACME challenge completes, TLS secret created
- ✅ Browser shows valid certificate when accessing service via HTTPS

**Tasks**:

### Test Service Deployment

- [ ] T059 [P] [US4] Create test service manifest (whoami) at tests/integration/cert-manager/test-traefik-ingress.yaml with Deployment and Service
- [ ] T060 [P] [US4] Create IngressRoute with cert-manager.io/cluster-issuer annotation in test-traefik-ingress.yaml (domain: whoami.chocolandiadc.com)
- [ ] T061 [US4] Configure TLS section in IngressRoute referencing auto-generated secret name (whoami-tls)

### Integration Tests (User Story 4)

- [ ] T062 [US4] Apply test service and IngressRoute: kubectl apply -f tests/integration/cert-manager/test-traefik-ingress.yaml
- [ ] T063 [US4] Verify Certificate resource was created automatically: kubectl get certificate whoami-tls -n default
- [ ] T064 [US4] Wait for certificate issuance: kubectl wait --for=condition=ready certificate/whoami-tls -n default --timeout=600s
- [ ] T065 [US4] Verify TLS secret created: kubectl get secret whoami-tls -n default
- [ ] T066 [US4] Verify Traefik routes traffic: kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50 | grep whoami
- [ ] T067 [US4] Test HTTPS endpoint: curl -v https://whoami.chocolandiadc.com
- [ ] T068 [US4] Verify certificate in browser: open https://whoami.chocolandiadc.com (check cert details)
- [ ] T069 [US4] Verify HTTP-to-HTTPS redirect works (if configured): curl -I http://whoami.chocolandiadc.com
- [ ] T070 [US4] Clean up test resources: kubectl delete -f tests/integration/cert-manager/test-traefik-ingress.yaml

**Parallel Opportunities**:
- T059-T061 can run in parallel (different manifest sections)
- T065-T067 can run in parallel after cert issuance (independent validations)

---

## Phase 7: User Story 5 - Configure Certificate Renewal (Priority: P3)

**Story Goal**: Verify and monitor automatic certificate renewal before expiration

**Independent Test**: Renewal configuration validated, manual renewal tested successfully

**Acceptance Criteria**:
- ✅ Renewal time configured (30 days before expiry by default)
- ✅ Manual renewal triggers successfully
- ✅ New certificate stored in Secret after renewal

**Tasks**:

### Renewal Configuration

- [ ] T071 [P] [US5] Verify default renewBefore setting in Certificate resources (should be 720h = 30 days)
- [ ] T072 [P] [US5] Document renewal configuration in terraform/modules/cert-manager/README.md
- [ ] T073 [US5] Install cmctl CLI tool for manual certificate operations (brew install cmctl or download binary)

### Integration Tests (User Story 5)

- [ ] T074 [US5] Check renewal time on existing certificate: kubectl describe certificate test-cert-production | grep "Renewal Time"
- [ ] T075 [US5] Manually trigger renewal for testing: cmctl renew test-cert-production -n default
- [ ] T076 [US5] Verify new CertificateRequest created: kubectl get certificaterequest -n default --sort-by=.metadata.creationTimestamp
- [ ] T077 [US5] Verify Secret updated with new certificate: kubectl get secret test-cert-production-tls -n default -o yaml | grep -A 5 metadata
- [ ] T078 [US5] Verify certificate expiry date extended: kubectl get secret test-cert-production-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

**Parallel Opportunities**:
- T071-T072 can run in parallel (documentation and verification)
- T076-T078 can run in parallel after renewal (independent validations)

---

## Phase 8: User Story 6 - Enable Prometheus Metrics (Priority: P3)

**Story Goal**: Configure cert-manager to export Prometheus metrics for monitoring certificate status and renewals

**Independent Test**: Metrics endpoint accessible, certificate metrics visible

**Acceptance Criteria**:
- ✅ Prometheus metrics endpoint returns 200 status code
- ✅ Certificate expiration metrics update on issuance/renewal
- ✅ Metrics appear in Prometheus (if deployed)

**Tasks**:

### Metrics Configuration

- [ ] T079 [P] [US6] Enable Prometheus metrics in helm-values.yaml (prometheus.enabled: true, prometheus.servicemonitor.enabled: true)
- [ ] T080 [P] [US6] Configure metrics port (9402) in helm-values.yaml
- [ ] T081 [US6] Apply metrics configuration via tofu apply

### Integration Tests (User Story 6)

- [ ] T082 [US6] Port-forward to metrics endpoint: kubectl port-forward -n cert-manager svc/cert-manager 9402:9402
- [ ] T083 [US6] Verify metrics endpoint accessible: curl http://localhost:9402/metrics
- [ ] T084 [US6] Verify certificate expiration metric exists: curl http://localhost:9402/metrics | grep certmanager_certificate_expiration_timestamp_seconds
- [ ] T085 [US6] Verify certificate ready status metric exists: curl http://localhost:9402/metrics | grep certmanager_certificate_ready_status
- [ ] T086 [US6] Document Grafana dashboard import (dashboard ID 11001) in terraform/modules/cert-manager/README.md (if Prometheus deployed)

**Parallel Opportunities**:
- T079-T080 can run in parallel (different metrics config sections)
- T084-T085 can run in parallel (independent metric checks)

---

## Phase 9: Polish & Cross-Cutting Concerns

**Goal**: Finalize documentation, validate all success criteria, and prepare for production use

**Tasks**:

### Documentation

- [ ] T087 [P] Create comprehensive module README at terraform/modules/cert-manager/README.md with usage examples, variables, outputs
- [ ] T088 [P] Create troubleshooting guide in specs/006-cert-manager/ documenting common issues and solutions
- [ ] T089 [P] Document Traefik integration patterns with examples in module README

### Code Quality

- [ ] T090 Run tofu fmt on all module files: tofu fmt -recursive terraform/modules/cert-manager/
- [ ] T091 Run tofu validate on module: cd terraform/modules/cert-manager && tofu validate

### End-to-End Validation

- [ ] T092 Run complete quickstart validation from specs/006-cert-manager/quickstart.md (all 8 steps)
- [ ] T093 Verify all success criteria from spec.md are met (SC-001 through SC-010)

**Parallel Opportunities**:
- T087-T089 can run in parallel (different documentation files)

---

## Success Criteria Verification

Before marking feature complete, verify all success criteria from spec.md:

- [ ] **SC-001**: cert-manager pods Running within 60s ✅ (T026)
- [ ] **SC-002**: Staging certificate issued within 5 min ✅ (T040)
- [ ] **SC-003**: Production certificate issued and browser-trusted ✅ (T057)
- [ ] **SC-004**: IngressRoute annotation auto-provisions cert ✅ (T068)
- [ ] **SC-005**: Renewal configured 30 days before expiry ✅ (T078)
- [ ] **SC-006**: Prometheus metrics endpoint returns 200 ✅ (T083)
- [ ] **SC-007**: All CRDs installed, webhook works ✅ (T027-T029)
- [ ] **SC-008**: HTTP-01 challenge completes successfully ✅ (T043)
- [ ] **SC-009**: Certificate logs visible ✅ (T030)
- [ ] **SC-010**: Grafana dashboard displays metrics ✅ (T086, if Prometheus deployed)

---

## Parallel Execution Summary

### Phase 1: All 4 tasks parallel
- T001, T002, T003, T004 (module structure creation)

### Phase 2: 3 tasks parallel
- T007, T008, T009 (scaffolding files)

### Phase 3 (US1): 13 tasks parallel
- T011-T012 (Helm config sections)
- T014-T017 (resource configs)
- T018-T021 (health checks)
- T026-T029 (deployment validations)

### Phase 4 (US2): 7 tasks parallel
- T031-T034 (ClusterIssuer sections)
- T035-T036 (test manifest)
- T041-T043 (validations)

### Phase 5 (US3): 7 tasks parallel
- T045-T048 (ClusterIssuer sections)
- T049-T050 (test manifest)
- T055-T056 (validations)

### Phase 6 (US4): 5 tasks parallel
- T059-T061 (IngressRoute manifest)
- T065-T067 (validations)

### Phase 7 (US5): 5 tasks parallel
- T071-T072 (renewal config)
- T076-T078 (renewal validations)

### Phase 8 (US6): 4 tasks parallel
- T079-T080 (metrics config)
- T084-T085 (metric checks)

### Phase 9: 3 tasks parallel
- T087-T089 (documentation)

**Total Parallel Opportunities**: 47 tasks can be executed in parallel (59% of total tasks)

---

## Implementation Strategy

### MVP Delivery (Phases 1-4)

**Time Estimate**: ~90 minutes
**Tasks**: T001-T044 (46 tasks)
**Deliverable**: cert-manager deployed with staging certificate validation

**Value**: Proves certificate automation works, safe to test without production rate limits

### Incremental Enhancements

1. **Production Certificates** (Phase 5): +10 tasks, ~20 minutes
2. **Traefik Integration** (Phase 6): +12 tasks, ~25 minutes
3. **Renewal & Monitoring** (Phases 7-8): +15 tasks, ~30 minutes
4. **Polish** (Phase 9): +6 tasks, ~15 minutes

### Testing Approach

- Integration tests after each phase validate user story independently
- Staging issuer tested before production (avoids rate limits)
- Manual renewal tested before relying on automation
- End-to-end quickstart validation ensures production readiness

---

## Notes

- **Prerequisites**: Traefik (Feature 005) and Cloudflare Tunnel (Feature 004) must be operational
- **Rate Limits**: Always test staging issuer first (production: 50 certs/week per domain)
- **Port 80**: ACME HTTP-01 challenges require internet-accessible port 80 via Cloudflare Tunnel
- **Email**: Replace `your-email@example.com` in terraform.tfvars with actual email for Let's Encrypt notifications
- **Cleanup**: Test certificates can be deleted after validation (kubectl delete certificate <name>)

---

## Estimated Time Breakdown

- Phase 1 (Setup): 4 tasks, ~5 minutes
- Phase 2 (Foundational): 6 tasks, ~10 minutes
- Phase 3 (US1): 20 tasks, ~35 minutes
- Phase 4 (US2): 13 tasks, ~25 minutes
- Phase 5 (US3): 13 tasks, ~20 minutes
- Phase 6 (US4): 12 tasks, ~25 minutes
- Phase 7 (US5): 8 tasks, ~15 minutes
- Phase 8 (US6): 7 tasks, ~10 minutes
- Phase 9 (Polish): 6 tasks, ~15 minutes

**Total Estimated Time**: ~150 minutes (~2.5 hours)

**MVP Time** (Phases 1-4): ~90 minutes (~1.5 hours)
