# Implementation Plan: Traefik Ingress Controller

**Branch**: `005-traefik` | **Date**: 2025-11-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-traefik/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy Traefik v3.x as the primary ingress controller in the K3s cluster using the official Helm chart managed via OpenTofu. Enable HTTP/HTTPS routing with MetalLB LoadBalancer integration, configure basic IngressRoute CRDs for service exposure, enable Traefik dashboard for operational visibility, and prepare for future cert-manager integration. All infrastructure defined as OpenTofu modules with HA configuration (2+ replicas).

## Technical Context

**Language/Version**: HCL (OpenTofu) 1.6+, YAML (Kubernetes manifests), Bash for validation
**Primary Dependencies**:
- Traefik Helm chart v3.x (traefik/traefik)
- Helm provider for OpenTofu (~> 2.0)
- Kubernetes provider for OpenTofu (~> 2.0)
- MetalLB (already deployed from Feature 002)
- kubectl CLI for validation
**Storage**: N/A (Traefik is stateless, configuration via Kubernetes CRDs)
**Testing**: kubectl validation commands, curl for HTTP/HTTPS endpoint tests, integration test scripts
**Target Platform**: K3s cluster (3 control-plane + 1 worker node, homelab environment on Eero network)
**Project Type**: Infrastructure deployment (OpenTofu modules + Kubernetes)
**Performance Goals**:
- HTTP request routing latency < 100ms p95
- Handle 100 concurrent requests without degradation
- Pod startup time < 60 seconds
- LoadBalancer IP assignment < 30 seconds
**Constraints**:
- Must integrate with existing MetalLB LoadBalancer
- Must support HA (2+ Traefik replicas with PodDisruptionBudget)
- Must work on Eero network (no VLAN segmentation, no FortiGate)
- All configuration via Kubernetes resources (CRDs), no file-based config
- Prepare for cert-manager integration (Feature 006) - TLS config extensible
**Scale/Scope**:
- Homelab cluster (4 nodes total)
- Foundation for future web services (Pi-hole, Grafana, Homepage, etc.)
- 5-10 IngressRoute resources initially
- 2-5 concurrent users (family/friends)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Infrastructure as Code - OpenTofu First
✅ **PASS**: Traefik deployment fully defined in OpenTofu using helm_release resource. Helm values.yaml managed in Git. All IngressRoute, Middleware, TLSOption CRDs created via Kubernetes provider or kubectl manifests. Zero manual Helm/kubectl commands.

### II. GitOps Workflow
✅ **PASS**: All changes via Git commits. OpenTofu plan reviewed before apply. Helm chart version pinned in terraform.tfvars. Traefik configuration changes via values.yaml in Git. IngressRoute manifests version-controlled.

### III. Container-First Development
✅ **PASS**: Traefik runs as containerized deployment (traefik:v3.x image). Stateless architecture - configuration via CRDs and ConfigMaps. Health checks (liveness/readiness probes) configured via Helm values. Resource limits (CPU/memory) defined.

### IV. Observability & Monitoring - Prometheus + Grafana Stack
⚠️ **PARTIAL (acceptable for MVP)**: Prometheus/Grafana not deployed yet (future feature). Traefik metrics endpoint (/metrics) enabled and configured in Helm values. Prometheus ServiceMonitor CRD prepared (commented out) for future activation. Dashboard provides immediate operational visibility.

**Justification**: Metrics endpoint preparation doesn't block deployment. Traefik dashboard provides operational visibility for MVP. Full Prometheus integration deferred to monitoring stack feature. This is an acceptable progressive enhancement.

### V. Security Hardening
⚠️ **DEVIATION JUSTIFIED**:
- Network perimeter: No FortiGate (homelab uses Eero network)
- VLAN segmentation: Not available on Eero network
- MetalLB LoadBalancer: Provides L4 load balancing (replaces FortiGate VIP)
- Principle of least privilege: Resource limits enforced, RBAC permissions minimal
- Secrets management: TLS certificates stored as Kubernetes Secrets
- Container security: Official Traefik image from Docker Hub, non-root user

**Justification**: Eero network limitation prevents FortiGate/VLAN implementation (documented in Feature 002 context). MetalLB provides equivalent LoadBalancer functionality for homelab. TLS termination at Traefik provides transport security. Future enhancement: cert-manager for automated TLS.

### VI. High Availability Architecture
✅ **PASS**:
- 2+ Traefik replicas configured via Helm values (deployment.replicas: 2)
- PodDisruptionBudget ensures at least 1 replica always available
- LoadBalancer service distributes traffic across replicas
- Cluster survives single Traefik pod failure without interruption
- Anti-affinity rules spread replicas across nodes

### VII. Test-Driven Learning
✅ **PASS**:
- OpenTofu tests: `tofu validate`, `tofu plan` before apply
- Deployment validation: kubectl checks for Running pods, LoadBalancer IP assigned
- Routing validation: curl tests to verify HTTP requests reach backend services
- HA validation: Pod deletion test ensures traffic continues via remaining replicas
- Integration tests: Test whoami service deployment + IngressRoute creation
- Dashboard validation: Access dashboard via browser, verify routes displayed
- Test documentation: Quickstart guide includes all validation steps

### VIII. Documentation-First
✅ **PASS**:
- ADR: Why Traefik over NGINX Ingress (research.md)
- Data model: Entity relationships (IngressRoute, Middleware, Service mappings)
- Runbooks: Deployment procedure, validation steps (quickstart.md)
- Troubleshooting: Common issues (LoadBalancer pending, routing not working, dashboard access)
- Code comments: OpenTofu modules document Helm values structure
- Network diagrams: Traffic flow (External → MetalLB → Traefik → Service → Pod)

### IX. Network-First Security
⚠️ **DEVIATION JUSTIFIED**:
- No FortiGate: Homelab uses Eero network (consumer router, no enterprise features)
- No VLAN segmentation: Eero limitation (flat network)
- MetalLB LoadBalancer: Provides L4 load balancing in cluster network
- Default deny: Traefik only routes traffic for explicitly defined IngressRoutes
- Inter-VLAN routing: Not applicable (flat network)

**Justification**: Eero network is homelab reality (documented in Feature 002). Traefik provides application-layer routing security (hostname/path matching). Future Cloudflare Access (Feature 004) adds authentication layer. MetalLB provides LoadBalancer abstraction equivalent to FortiGate VIP for homelab scale. Learning value: Cloud-native ingress patterns, preparing for production Kubernetes environments where ingress controllers are standard.

**Recommendation**: If homelab network upgraded to managed switch + router in future, VLAN segmentation can be added without changing Traefik deployment.

### Summary
- **9 principles evaluated**
- **6 PASS**, **3 PARTIAL/DEVIATION**
- **All deviations justified** with homelab network limitations (Eero) and progressive enhancement (Prometheus)
- **No blocking violations**

## Project Structure

### Documentation (this feature)

```text
specs/005-traefik/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── traefik/
│       ├── main.tf                    # Helm release resource for Traefik chart
│       ├── variables.tf               # Module inputs (replicas, resources, LoadBalancer IP, etc.)
│       ├── outputs.tf                 # Module outputs (LoadBalancer IP, deployment status)
│       ├── values.yaml                # Traefik Helm chart values (ports, dashboard, metrics, HA)
│       ├── versions.tf                # Provider version constraints
│       └── README.md                  # Module documentation
│
├── environments/
│   └── chocolandiadc-mvp/
│       ├── traefik.tf                 # Module instantiation for Traefik ingress
│       ├── terraform.tfvars           # Environment-specific values (replicas, LoadBalancer IP)
│       └── providers.tf               # Helm + Kubernetes provider configuration (already exists)
│
└── manifests/
    └── traefik/
        ├── whoami-test.yaml           # Test deployment (whoami service)
        ├── whoami-ingressroute.yaml   # Test IngressRoute (HTTP routing validation)
        └── dashboard-ingressroute.yaml # Dashboard IngressRoute (admin UI access)

tests/
└── traefik/
    ├── test_deployment.sh             # Validate Traefik pods running, LoadBalancer IP assigned
    ├── test_routing.sh                # Validate HTTP routing to whoami service
    └── test_dashboard.sh              # Validate dashboard accessibility
```

**Structure Decision**: Infrastructure-as-Code structure following existing project patterns (terraform/modules/ for reusable modules, terraform/environments/ for environment-specific configs). Helm chart managed via OpenTofu helm_release resource. Test IngressRoutes created as separate manifests for easy experimentation. Integration tests validate end-to-end functionality.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| No FortiGate / No VLANs (Principle V & IX) | Eero network is homelab reality | FortiGate requires enterprise router/switch. Eero consumer router has no VLAN support. MetalLB provides equivalent LoadBalancer for homelab scale. |
| Prometheus metrics not active (Principle IV) | Prometheus/Grafana not deployed yet | Deploying monitoring stack is separate feature. Metrics endpoint prepared but not consumed yet. Dashboard provides operational visibility for MVP. |
