# Feature 005: Traefik Ingress Controller - Implementation Tasks

## Overview
This document contains the complete task breakdown for implementing Traefik Ingress Controller on the K3s cluster. Tasks are organized by implementation phase and labeled with user story references where applicable.

## Dependencies
- **Required**: K3s cluster running (Feature 002)
- **Required**: MetalLB LoadBalancer deployed (Feature 002)
- **Required**: kubectl CLI configured
- **Required**: Helm v3 installed
- **Required**: OpenTofu 1.6+ installed

## User Story Mapping
- **US1**: Deploy Traefik Ingress Controller (P1 - MVP Required)
- **US2**: Configure Basic HTTP Routing (P1 - MVP Required)
- **US3**: Enable Dashboard Access (P2 - Enhancement)
- **US4**: Configure SSL/TLS Termination (P2 - Enhancement)
- **US5**: Integrate Prometheus Metrics (P3 - Enhancement)

## Implementation Strategy
- **MVP**: US1 + US2 (Deploy Traefik + Basic HTTP Routing)
- **Phase 1 Enhancement**: US3 + US4 (Dashboard + TLS)
- **Phase 2 Enhancement**: US5 (Metrics)

## Parallel Execution Examples
- **US1**: Tasks T011-T013 [P] can run in parallel (create module files)
- **US2**: Tasks T040-T041 [P] can run in parallel (create test manifests)
- **US3**: Tasks T058-T059 [P] can run in parallel (configure dashboard)
- **US4**: Tasks T072-T073 [P] can run in parallel (create certificates)
- **Polish**: Tasks T093-T095 [P] can run in parallel (create documentation)

---

## Phase 1: Project Setup (4 tasks)

**Goal**: Create directory structure for Traefik module, manifests, and documentation.

- [ ] T001 [P] Create Traefik module directory: /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/
- [ ] T002 [P] Create Traefik manifests directory: /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/
- [ ] T003 [P] Create Traefik tests directory: /Users/cbenitez/chocolandia_kube/tests/traefik/
- [ ] T004 [P] Create Traefik documentation directory: /Users/cbenitez/chocolandia_kube/docs/traefik/

---

## Phase 2: Foundational Prerequisites (7 tasks)

**Goal**: Verify cluster prerequisites and prepare Helm repository for Traefik deployment.

- [ ] T005 Verify K3s cluster running: `kubectl get nodes` (expect 4 nodes Ready)
- [ ] T006 Verify MetalLB pods running: `kubectl get pods -n metallb-system` (expect speaker + controller)
- [ ] T007 Add Traefik Helm repository: `helm repo add traefik https://traefik.github.io/charts`
- [ ] T008 Update Helm repositories: `helm repo update`
- [ ] T009 Search Traefik chart versions: `helm search repo traefik/traefik --versions` (verify v3.x available)
- [ ] T010 Create Traefik namespace: `kubectl create namespace traefik` (if not exists)
- [ ] T011 Verify namespace created: `kubectl get namespace traefik`

---

## Phase 3: User Story 1 - Deploy Traefik Ingress Controller (P1 - MVP) (25 tasks)

**Goal**: Deploy highly available Traefik ingress controller with MetalLB LoadBalancer integration, 2 replicas, and proper resource limits.

**Test Criteria**: Traefik pods running (2/2), LoadBalancer IP assigned (192.168.4.201), CRDs installed, HTTP/HTTPS endpoints responding with 404.

- [ ] T012 [P] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/main.tf with helm_release resource for Traefik
- [ ] T013 [P] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/variables.tf (replicas, loadbalancer_ip, chart_version, namespace, resources)
- [ ] T014 [P] [US1] Create /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/outputs.tf (loadbalancer_ip, deployment_status, namespace, service_name)
- [ ] T015 [US1] Create /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/versions.tf (Helm provider ~> 2.0, Kubernetes provider ~> 2.0)
- [ ] T016 [US1] Create /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/values.yaml with Helm chart values (deployment.replicas: 2, service.type: LoadBalancer)
- [ ] T017 [US1] Configure values.yaml: set service.spec.loadBalancerIP to 192.168.4.201 (MetalLB IP)
- [ ] T018 [US1] Configure values.yaml: set ports.web (80), ports.websecure (443), ports.metrics (9100)
- [ ] T019 [US1] Configure values.yaml: set resource requests/limits (memory: 128Mi/256Mi, cpu: 100m/200m)
- [ ] T020 [US1] Configure values.yaml: set readinessProbe and livenessProbe (httpGet /ping on port 9000)
- [ ] T021 [US1] Configure values.yaml: enable dashboard (dashboard.enabled: true, dashboard.insecure: true)
- [ ] T022 [US1] Configure values.yaml: enable metrics (metrics.prometheus.enabled: true, metrics.prometheus.entryPoint: metrics)
- [ ] T023 [US1] Configure values.yaml: set logs.general.level to INFO, logs.access.enabled to true
- [ ] T024 [US1] Create /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/README.md with module documentation
- [ ] T025 [US1] Create /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/traefik.tf calling traefik module
- [ ] T026 [US1] Update /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/terraform.tfvars with Traefik variables
- [ ] T027 [US1] Run `tofu init` in /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/
- [ ] T028 [US1] Run `tofu validate` in environment directory (expect success)
- [ ] T029 [US1] Run `tofu plan` in environment directory (review output for Helm release creation)
- [ ] T030 [US1] Run `tofu apply` in environment directory (deploy Traefik)
- [ ] T031 [US1] Verify Traefik namespace exists: `kubectl get ns traefik` (expect Active)
- [ ] T032 [US1] Verify Traefik pods running: `kubectl get pods -n traefik` (expect 2/2 Running)
- [ ] T033 [US1] Verify 2 replicas: `kubectl get deployment traefik -n traefik` (expect READY 2/2)
- [ ] T034 [US1] Verify LoadBalancer service created: `kubectl get svc traefik -n traefik` (expect TYPE LoadBalancer)
- [ ] T035 [US1] Verify LoadBalancer IP assigned: check EXTERNAL-IP is 192.168.4.201 (MetalLB)
- [ ] T036 [US1] Verify Traefik CRDs installed: `kubectl get crd | grep traefik` (expect IngressRoute, Middleware, TLSOption, etc.)
- [ ] T037 [US1] Verify IngressRoute CRD exists: `kubectl get crd ingressroutes.traefik.io`
- [ ] T038 [US1] Verify Middleware CRD exists: `kubectl get crd middlewares.traefik.io`
- [ ] T039 [US1] Verify TLSOption CRD exists: `kubectl get crd tlsoptions.traefik.io`
- [ ] T040 [US1] Verify PodDisruptionBudget created: `kubectl get pdb -n traefik` (expect maxUnavailable: 1)
- [ ] T041 [US1] Verify resource limits set: `kubectl describe pod -n traefik | grep -A 5 "Limits"`
- [ ] T042 [US1] Verify health probes configured: `kubectl describe pod -n traefik | grep -A 3 "Liveness\|Readiness"`
- [ ] T043 [US1] Test HTTP connectivity: `curl http://192.168.4.201` (expect 404 - no routes configured yet)
- [ ] T044 [US1] Test HTTPS connectivity: `curl https://192.168.4.201 -k` (expect 404 or TLS error)
- [ ] T045 [US1] Verify Traefik logs: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik` (expect no errors)
- [ ] T046 [US1] Create /Users/cbenitez/chocolandia_kube/docs/traefik/deployment.md documenting deployment process

---

## Phase 4: User Story 2 - Configure Basic HTTP Routing (P1 - MVP) (18 tasks)

**Goal**: Configure basic HTTP routing using IngressRoute CRD with hostname-based routing to test services.

**Test Criteria**: HTTP requests to whoami.local routed correctly, multiple hostnames supported, Traefik logs show routing activity.

- [ ] T047 [P] [US2] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-deployment.yaml (containous/whoami image)
- [ ] T048 [P] [US2] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-service.yaml (ClusterIP, port 80)
- [ ] T049 [US2] Deploy whoami test service: `kubectl apply -f whoami-deployment.yaml -f whoami-service.yaml`
- [ ] T050 [US2] Verify whoami pods running: `kubectl get pods -l app=whoami` (expect 1/1 Running)
- [ ] T051 [US2] Verify whoami service created: `kubectl get svc whoami` (expect ClusterIP)
- [ ] T052 [US2] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-ingressroute.yaml (IngressRoute CRD)
- [ ] T053 [US2] Configure IngressRoute: set entryPoints to ["web"] (HTTP port 80)
- [ ] T054 [US2] Configure IngressRoute: add route with Host(`whoami.local`) match rule
- [ ] T055 [US2] Configure IngressRoute: set services backend to whoami:80
- [ ] T056 [US2] Apply IngressRoute: `kubectl apply -f whoami-ingressroute.yaml`
- [ ] T057 [US2] Verify IngressRoute created: `kubectl get ingressroute` (expect whoami-http)
- [ ] T058 [US2] Describe IngressRoute: `kubectl describe ingressroute whoami-http` (verify routes configured)
- [ ] T059 [US2] Add /etc/hosts entry: `echo "192.168.4.201 whoami.local" | sudo tee -a /etc/hosts`
- [ ] T060 [US2] Test HTTP routing with hostname: `curl http://whoami.local` (expect whoami response with headers)
- [ ] T061 [US2] Test HTTP routing with Host header: `curl -H "Host: whoami.local" http://192.168.4.201` (expect whoami response)
- [ ] T062 [P] [US2] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/echo-deployment.yaml (ealen/echo-server image)
- [ ] T063 [P] [US2] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/echo-ingressroute.yaml with Host(`echo.local`)
- [ ] T064 [US2] Deploy echo service and IngressRoute: `kubectl apply -f echo-deployment.yaml -f echo-ingressroute.yaml`
- [ ] T065 [US2] Add /etc/hosts entry: `echo "192.168.4.201 echo.local" | sudo tee -a /etc/hosts`
- [ ] T066 [US2] Test second service routing: `curl http://echo.local` (expect echo-server response)
- [ ] T067 [US2] Verify both hostnames work: test whoami.local and echo.local (both should respond correctly)
- [ ] T068 [US2] Verify Traefik logs show routing: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik | grep whoami`
- [ ] T069 [US2] Create /Users/cbenitez/chocolandia_kube/docs/traefik/routing.md documenting IngressRoute configuration

---

## Phase 5: User Story 3 - Enable Dashboard Access (P2 - Enhancement) (15 tasks)

**Goal**: Enable and expose Traefik dashboard for monitoring ingress routes, services, and metrics.

**Test Criteria**: Dashboard accessible at http://traefik.local/dashboard/, shows IngressRoutes, services, routers, and request metrics.

- [ ] T070 [US3] Verify dashboard enabled in values.yaml: check `dashboard.enabled: true`
- [ ] T071 [US3] Verify dashboard insecure mode: check `dashboard.insecure: true` (for internal access)
- [ ] T072 [P] [US3] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/dashboard-ingressroute.yaml
- [ ] T073 [US3] Configure dashboard IngressRoute: set entryPoints to ["web"]
- [ ] T074 [US3] Configure dashboard IngressRoute: add route with Host(`traefik.local`) match
- [ ] T075 [US3] Configure dashboard IngressRoute: set services to api@internal (Traefik built-in service)
- [ ] T076 [US3] Apply dashboard IngressRoute: `kubectl apply -f dashboard-ingressroute.yaml`
- [ ] T077 [US3] Verify dashboard IngressRoute created: `kubectl get ingressroute dashboard`
- [ ] T078 [US3] Add /etc/hosts entry: `echo "192.168.4.201 traefik.local" | sudo tee -a /etc/hosts`
- [ ] T079 [US3] Test dashboard HTTP access: `curl http://traefik.local/dashboard/` (expect HTML response)
- [ ] T080 [US3] Open browser to http://traefik.local/dashboard/ (verify dashboard loads)
- [ ] T081 [US3] Verify dashboard shows HTTP routers section (expect whoami-http, echo-http, dashboard routers)
- [ ] T082 [US3] Verify dashboard shows services section (expect whoami, echo, api@internal services)
- [ ] T083 [US3] Verify dashboard shows IngressRoutes (expect all configured routes)
- [ ] T084 [US3] Verify dashboard shows metrics: check request counts, response codes, average response time
- [ ] T085 [US3] Generate traffic to whoami.local: run `for i in {1..10}; do curl http://whoami.local; done`
- [ ] T086 [US3] Refresh dashboard: verify request count increased for whoami service
- [ ] T087 [US3] Create /Users/cbenitez/chocolandia_kube/docs/traefik/dashboard.md documenting dashboard access and features

---

## Phase 6: User Story 4 - Configure SSL/TLS Termination (P2 - Enhancement) (20 tasks)

**Goal**: Configure TLS termination with self-signed certificates and HTTP to HTTPS redirection.

**Test Criteria**: HTTPS endpoints respond with valid certificates, HTTP requests redirect to HTTPS, dashboard accessible via HTTPS.

- [ ] T088 [P] [US4] Generate self-signed certificate for whoami.local: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout whoami.key -out whoami.crt -subj "/CN=whoami.local"`
- [ ] T089 [US4] Create Kubernetes TLS Secret: `kubectl create secret tls whoami-tls-cert --cert=whoami.crt --key=whoami.key`
- [ ] T090 [US4] Verify TLS secret created: `kubectl get secret whoami-tls-cert` (expect type kubernetes.io/tls)
- [ ] T091 [P] [US4] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-ingressroute-tls.yaml
- [ ] T092 [US4] Configure HTTPS IngressRoute: set entryPoints to ["websecure"] (HTTPS port 443)
- [ ] T093 [US4] Configure HTTPS IngressRoute: add route with Host(`whoami.local`) match
- [ ] T094 [US4] Configure HTTPS IngressRoute: set services backend to whoami:80
- [ ] T095 [US4] Configure HTTPS IngressRoute: add tls.secretName reference to whoami-tls-cert
- [ ] T096 [US4] Apply HTTPS IngressRoute: `kubectl apply -f whoami-ingressroute-tls.yaml`
- [ ] T097 [US4] Verify HTTPS IngressRoute created: `kubectl get ingressroute whoami-https`
- [ ] T098 [US4] Test HTTPS routing: `curl https://whoami.local -k` (expect whoami response)
- [ ] T099 [US4] Verify certificate presented: `openssl s_client -connect 192.168.4.201:443 -servername whoami.local` (expect CN=whoami.local)
- [ ] T100 [P] [US4] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/https-redirect-middleware.yaml
- [ ] T101 [US4] Configure Middleware: set redirectScheme.scheme to https, redirectScheme.permanent to true
- [ ] T102 [US4] Apply Middleware: `kubectl apply -f https-redirect-middleware.yaml`
- [ ] T103 [US4] Verify Middleware created: `kubectl get middleware https-redirect`
- [ ] T104 [US4] Update HTTP IngressRoute: add middlewares reference to https-redirect
- [ ] T105 [US4] Re-apply HTTP IngressRoute: `kubectl apply -f whoami-ingressroute.yaml`
- [ ] T106 [US4] Test HTTP redirect: `curl -I http://whoami.local` (expect 301 Moved Permanently, Location: https://whoami.local)
- [ ] T107 [US4] Test HTTP redirect with follow: `curl -L http://whoami.local -k` (expect whoami HTTPS response)
- [ ] T108 [P] [US4] Generate self-signed certificate for traefik.local: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout traefik.key -out traefik.crt -subj "/CN=traefik.local"`
- [ ] T109 [US4] Create Kubernetes TLS Secret for dashboard: `kubectl create secret tls traefik-tls-cert --cert=traefik.crt --key=traefik.key -n traefik`
- [ ] T110 [P] [US4] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/dashboard-ingressroute-tls.yaml
- [ ] T111 [US4] Configure dashboard HTTPS IngressRoute with websecure entryPoint and traefik-tls-cert secret
- [ ] T112 [US4] Apply dashboard HTTPS IngressRoute: `kubectl apply -f dashboard-ingressroute-tls.yaml`
- [ ] T113 [US4] Test dashboard HTTPS access: `curl https://traefik.local/dashboard/ -k` (expect HTML response)
- [ ] T114 [US4] Open browser to https://traefik.local/dashboard/ (verify dashboard loads via HTTPS)
- [ ] T115 [US4] Create /Users/cbenitez/chocolandia_kube/docs/traefik/tls.md documenting TLS configuration and certificate management

---

## Phase 7: User Story 5 - Integrate Prometheus Metrics (P3 - Enhancement) (12 tasks)

**Goal**: Enable Prometheus metrics endpoint and document future Prometheus/Grafana integration.

**Test Criteria**: Metrics endpoint accessible, Traefik metrics available, ServiceMonitor manifest ready for future use.

- [ ] T116 [US5] Verify metrics enabled in values.yaml: check `metrics.prometheus.enabled: true`
- [ ] T117 [US5] Verify metrics port configured: check `metrics.prometheus.entryPoint: metrics` on port 9100
- [ ] T118 [US5] Port-forward to Traefik metrics port: `kubectl port-forward -n traefik svc/traefik 9100:9100` (run in background)
- [ ] T119 [US5] Test metrics endpoint: `curl http://localhost:9100/metrics` (expect Prometheus format)
- [ ] T120 [US5] Verify traefik_entrypoint_requests_total metric exists: `curl -s http://localhost:9100/metrics | grep traefik_entrypoint_requests_total`
- [ ] T121 [US5] Verify traefik_entrypoint_request_duration_seconds metric: `curl -s http://localhost:9100/metrics | grep traefik_entrypoint_request_duration_seconds`
- [ ] T122 [US5] Verify traefik_service_requests_total metric: `curl -s http://localhost:9100/metrics | grep traefik_service_requests_total`
- [ ] T123 [US5] Verify traefik_service_request_duration_seconds metric exists
- [ ] T124 [P] [US5] Create /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/servicemonitor.yaml (commented, for future Prometheus Operator)
- [ ] T125 [US5] Configure ServiceMonitor: set matchLabels for Traefik service, endpoints port to metrics (9100)
- [ ] T126 [P] [US5] Create /Users/cbenitez/chocolandia_kube/docs/traefik/metrics.md documenting metrics endpoint and available metrics
- [ ] T127 [US5] Document future Prometheus integration in metrics.md: ServiceMonitor deployment, Prometheus scraping configuration
- [ ] T128 [P] [US5] Create /Users/cbenitez/chocolandia_kube/docs/traefik/grafana-dashboard.json (example Traefik dashboard, commented)
- [ ] T129 [US5] Document Grafana dashboard import procedure in metrics.md

---

## Phase 8: Polish & Cross-Cutting Concerns (15 tasks)

**Goal**: Format code, create comprehensive documentation, validate end-to-end functionality, and prepare for PR review.

- [ ] T130 [P] Run `tofu fmt` on all .tf files in /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/
- [ ] T131 [P] Run `tofu fmt` on /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/traefik.tf
- [ ] T132 Run `tofu validate` in /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/ (expect success)
- [ ] T133 Update /Users/cbenitez/chocolandia_kube/terraform/modules/traefik/README.md with comprehensive documentation
- [ ] T134 Document prerequisites in README.md: K3s cluster, MetalLB LoadBalancer, kubectl, Helm v3, OpenTofu 1.6+
- [ ] T135 Document deployment procedure in README.md: step-by-step guide from `tofu init` to verification
- [ ] T136 [P] Create /Users/cbenitez/chocolandia_kube/docs/traefik/troubleshooting.md with common issues and solutions
- [ ] T137 Document troubleshooting: LoadBalancer IP not assigned (check MetalLB), pods CrashLoopBackOff (check resource limits), routing not working (check IngressRoute)
- [ ] T138 [P] Create /Users/cbenitez/chocolandia_kube/tests/traefik/quickstart.sh script for automated deployment validation
- [ ] T139 Configure quickstart.sh: verify prerequisites, deploy Traefik, create test IngressRoutes, validate routing
- [ ] T140 Test HA behavior: delete one Traefik pod, verify second pod continues handling requests
- [ ] T141 Verify routing continues during pod deletion: `while true; do curl http://whoami.local; sleep 1; done` (expect no interruption)
- [ ] T142 Verify pod automatically recreated: `kubectl get pods -n traefik` (expect 2/2 Running after deletion)
- [ ] T143 Test rolling update simulation: `kubectl rollout restart deployment traefik -n traefik`, verify zero downtime
- [ ] T144 Verify all IngressRoutes working: test whoami.local (HTTP/HTTPS), echo.local (HTTP), traefik.local/dashboard/ (HTTP/HTTPS)
- [ ] T145 Verify dashboard accessible and showing all routers/services
- [ ] T146 Run end-to-end validation: execute quickstart.sh script, verify all tests pass
- [ ] T147 Update /Users/cbenitez/chocolandia_kube/CLAUDE.md: add "Traefik Ingress Controller v3.x, Helm v3" to Active Technologies
- [ ] T148 Update CLAUDE.md: add "Kubernetes IngressRoute (Traefik CRD), LoadBalancer service (MetalLB), Helm release" to Active Technologies
- [ ] T149 Create PR checklist in /Users/cbenitez/chocolandia_kube/specs/005-traefik/pr-checklist.md

---

## Summary

**Total Tasks**: 149
**Estimated Time**: ~300 minutes (~5 hours)

**Task Distribution by Phase**:
- Phase 1 (Setup): 4 tasks (~5 min)
- Phase 2 (Foundational): 7 tasks (~15 min)
- Phase 3 (US1 - Deploy Traefik): 35 tasks (~70 min)
- Phase 4 (US2 - Basic Routing): 23 tasks (~50 min)
- Phase 5 (US3 - Dashboard): 18 tasks (~35 min)
- Phase 6 (US4 - TLS): 28 tasks (~60 min)
- Phase 7 (US5 - Metrics): 14 tasks (~30 min)
- Phase 8 (Polish): 20 tasks (~35 min)

**MVP Completion**: Tasks T001-T069 (Phase 1-4, US1+US2)
**Enhancement 1**: Tasks T070-T115 (Phase 5-6, US3+US4)
**Enhancement 2**: Tasks T116-T129 (Phase 7, US5)
**Polish**: Tasks T130-T149 (Phase 8)

**Parallelizable Task Groups**:
- T001-T004 [P] (directory creation)
- T012-T014 [P] (module files creation)
- T047-T048 [P] (whoami manifests)
- T062-T063 [P] (echo manifests)
- T072 [P] (dashboard IngressRoute)
- T088, T091, T100, T108, T110, T124, T126, T128 [P] (manifest/doc creation)
- T130-T131 [P] (tofu fmt)
- T136, T138 [P] (documentation creation)

**Critical Path**:
1. Phase 2 (Prerequisites) → Phase 3 (US1 Deploy) → Phase 4 (US2 Routing) = MVP
2. MVP → Phase 5 (US3 Dashboard) + Phase 6 (US4 TLS) = Enhancement 1
3. Enhancement 1 → Phase 7 (US5 Metrics) = Enhancement 2
4. All phases → Phase 8 (Polish) = Production Ready
