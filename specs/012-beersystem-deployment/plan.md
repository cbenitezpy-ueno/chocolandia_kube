# Implementation Plan: BeerSystem Cluster Deployment

**Branch**: `012-beersystem-deployment` | **Date**: 2025-11-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/012-beersystem-deployment/spec.md`

**Note**: This plan has been regenerated after clarification session to align with confirmed Cloudflare Tunnel architecture.

## Summary

Deploy the existing BeerSystem web application (already containerized) to the Kubernetes cluster with public access via beer.chocolandiadc.com subdomain, PostgreSQL database provisioning (beersystem_stage), and ArgoCD GitOps synchronization from the beersystem repository's k8s/ directory.

## Technical Context

**Language/Version**: Containerized application (existing Dockerfile), Kubernetes manifests (YAML), OpenTofu 1.6+ for database provisioning
**Primary Dependencies**:
- Existing K3s cluster (feature 002-k3s-mvp-eero)
- PostgreSQL cluster (feature 011-postgresql-cluster)
- ArgoCD (feature 008-gitops-argocd)
- Cloudflare Tunnel (feature 004-cloudflare-zerotrust)

**Storage**: PostgreSQL database "beersystem_stage" with persistent storage via CloudNativePG PersistentVolumes
**Testing**: Integration tests (application accessibility, database connectivity, ArgoCD sync validation), manual validation per quickstart.md, explicit data persistence test
**Target Platform**: K3s Kubernetes cluster on Lenovo/HP ProDesk nodes
**Project Type**: Infrastructure deployment (Kubernetes manifests + OpenTofu for database)
**Performance Goals**: TTFB <2s, 10min deployment time via ArgoCD
**Constraints**:
- Must use existing PostgreSQL cluster from feature 011
- Must use Cloudflare Tunnel for public access (no cert-manager, no Traefik Ingress)
- Must not modify beersystem application code
- Database name: beersystem_stage
- Domain: beer.chocolandiadc.com subdomain
- Health endpoints (/health, /health/ready) being implemented in application

**Scale/Scope**: Single application deployment, 1 database, 1 ArgoCD application resource, Cloudflare Tunnel routing

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Infrastructure as Code - OpenTofu First
✅ **PASS** - Database provisioning will use OpenTofu to create beersystem_stage database and user
✅ **PASS** - Kubernetes manifests will be declarative YAML (infrastructure as code)
✅ **PASS** - Cloudflare Tunnel routing configured via OpenTofu

### Principle II: GitOps Workflow
✅ **PASS** - ArgoCD will monitor beersystem repo k8s/ directory for manifest changes
✅ **PASS** - All changes will go through Git commits and PR review
✅ **PASS** - Rollbacks via Git revert and ArgoCD sync

### Principle III: Container-First Development
✅ **PASS** - BeerSystem already containerized with existing Dockerfile
✅ **PASS** - Database will use PersistentVolume for stateful data
✅ **PASS** - Health checks (liveness/readiness) will be configured in Kubernetes manifests

### Principle IV: Observability & Monitoring - Prometheus + Grafana Stack
✅ **PASS** - Application health endpoints will be exposed for monitoring
⏭️ **DEFERRED** - Prometheus scraping and Grafana dashboards not in scope (basic health checks only per spec)

### Principle V: Security Hardening
✅ **PASS** - TLS certificates via Cloudflare Universal SSL (automatic)
✅ **PASS** - Database credentials will use Kubernetes Secrets
✅ **PASS** - Resource limits will be defined in manifests
✅ **PASS** - Least privilege: database user with only necessary DDL privileges
⏭️ **DEFERRED** - Network policies not in scope (defense in depth deferred)

### Principle VI: High Availability Architecture
⏭️ **DEFERRED** - Single application deployment (HA not required per spec - staging MVP)
✅ **PASS** - PostgreSQL cluster already HA (from feature 011)
✅ **PASS** - Persistent storage for database

### Principle VII: Test-Driven Learning
✅ **PASS** - OpenTofu validate/plan before apply
✅ **PASS** - Integration tests for connectivity, accessibility, and sync
✅ **PASS** - Manual validation steps documented in quickstart.md
✅ **PASS** - Explicit data persistence test (FR-007: insert → restart → verify)

### Principle VIII: Documentation-First
✅ **PASS** - This plan documents architecture and approach
✅ **PASS** - research.md documents technical decisions
✅ **PASS** - quickstart.md provides deployment runbook
✅ **PASS** - data-model.md documents database requirements
✅ **PASS** - contracts/cloudflare-tunnel-spec.yaml documents tunnel configuration

### Principle IX: Network-First Security
✅ **PASS** - Application will run in cluster VLAN (network already configured)
✅ **PASS** - Cloudflare Tunnel provides secure public access (outbound-only encrypted tunnel)
⚠️ **EXCEPTION** - Cloudflare Tunnel bypasses FortiGate perimeter (approved in feature 004)
  - **Justification**: Outbound-only encrypted connection to Cloudflare edge doesn't violate network-first security principle
  - Traffic flow: Internet → Cloudflare Edge (HTTPS) → Encrypted Tunnel → cloudflared pod → beersystem-service (HTTP internal)
  - No inbound ports exposed on FortiGate or cluster nodes
  - TLS termination at Cloudflare edge provides first layer of security

**Overall Gate Status**: ✅ **PASS** - No blocking violations. Partial compliance items are acceptable for this feature scope. Cloudflare Tunnel exception documented with justification.

## Project Structure

### Documentation (this feature)

```text
specs/012-beersystem-deployment/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (deployment strategy decisions)
├── data-model.md        # Phase 1 output (database schema requirements)
├── quickstart.md        # Phase 1 output (deployment runbook)
├── contracts/           # Phase 1 output
│   └── cloudflare-tunnel-spec.yaml  # Cloudflare Tunnel configuration specification
└── tasks.md             # Phase 2 output (/speckit.tasks command - already generated)
```

### Source Code (beersystem repository + chocolandia_kube repository)

```text
# Beersystem repository (external repo at /Users/cbenitez/beersystem)
/Users/cbenitez/beersystem/
├── Dockerfile                    # Existing containerization
├── .env.staging                  # Environment config reference
└── k8s/                          # NEW - Kubernetes manifests (to be created)
    ├── namespace.yaml            # beersystem namespace
    ├── deployment.yaml           # Application deployment with health checks
    ├── service.yaml              # ClusterIP service for application
    ├── configmap.yaml            # Application configuration
    └── secret.yaml.template      # Database credentials template (actual secret via manual creation)

# Chocolandia_kube repository (infrastructure repo - this repo)
/Users/cbenitez/chocolandia_kube/
└── terraform/
    └── modules/
        └── postgresql-database/  # NEW - OpenTofu module for database provisioning
            ├── main.tf           # Database and user creation
            ├── variables.tf      # Database name, user name inputs
            └── outputs.tf        # Connection string output
    └── environments/
        └── chocolandiadc-mvp/
            ├── beersystem-db/    # NEW - BeerSystem database instance
            │   ├── main.tf       # Instantiate postgresql-database module
            │   ├── terraform.tfvars  # beersystem_stage configuration
            │   └── outputs.tf    # Connection details for application
            └── cloudflare/       # EXISTING - Update tunnel config
                └── main.tf       # Add beersystem ingress rule and DNS record
```

**Structure Decision**:
- **Separation of concerns**: Application manifests live in beersystem repo (where app code lives), infrastructure provisioning (database) lives in chocolandia_kube repo (where cluster infrastructure lives)
- **ArgoCD target**: beersystem repo k8s/ directory for application deployment synchronization
- **OpenTofu workflow**: Database provisioning happens first (via chocolandia_kube), then application deployment (via ArgoCD from beersystem)
- **Rationale**: Follows GitOps best practice of keeping app manifests with app code, while keeping shared infrastructure (database, tunnel routing) in central infrastructure repo

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

### Cloudflare Tunnel Exception (Principle IX)

**Violation**: Cloudflare Tunnel bypasses FortiGate perimeter, violating "FortiGate MUST be the single entry/exit point"

**Justification**:
1. **Outbound-only connection**: Cloudflared pod initiates outbound connection to Cloudflare edge - no inbound ports exposed
2. **Approved architecture**: Feature 004 (cloudflare-zerotrust) established this pattern as acceptable for homelab
3. **Security maintained**: TLS termination at Cloudflare edge + encrypted tunnel provides equivalent security to FortiGate perimeter
4. **No FortiGate port forwarding needed**: Eliminates complexity and potential misconfiguration of FortiGate port forwarding rules
5. **Learning value**: Teaches cloud-native ingress patterns (Cloudflare Tunnel, Zero Trust) vs traditional firewall-based ingress

**Mitigation**: Traffic flow fully documented, troubleshooting guide in quickstart.md, tunnel health monitoring via cloudflared pod logs

---

## Post-Design Constitution Re-Check

*Re-evaluation after Phase 1 design completion*

### Principle I: Infrastructure as Code - OpenTofu First
✅ **CONFIRMED PASS** - Database provisioning designed with OpenTofu PostgreSQL provider
✅ **CONFIRMED PASS** - All Kubernetes resources defined as YAML manifests (declarative)
✅ **CONFIRMED PASS** - Cloudflare Tunnel routing configured via OpenTofu
✅ **CONFIRMED PASS** - No manual configuration required

### Principle II: GitOps Workflow
✅ **CONFIRMED PASS** - ArgoCD Application manifest created, auto-sync configured
✅ **CONFIRMED PASS** - All manifests version-controlled in beersystem repo
✅ **CONFIRMED PASS** - Rollback via Git revert documented in quickstart

### Principle III: Container-First Development
✅ **CONFIRMED PASS** - Using existing containerized application
✅ **CONFIRMED PASS** - Health checks (liveness/readiness) defined in deployment.yaml
✅ **CONFIRMED PASS** - Stateless application with database on PersistentVolume

### Principle IV: Observability & Monitoring
✅ **CONFIRMED PASS** - Health endpoints exposed for monitoring
⏭️ **CONFIRMED DEFERRED** - Prometheus/Grafana integration deferred per spec (future enhancement)

### Principle V: Security Hardening
✅ **CONFIRMED PASS** - TLS via Cloudflare Universal SSL (automatic certificate management)
✅ **CONFIRMED PASS** - Database credentials in Kubernetes Secret
✅ **CONFIRMED PASS** - Resource limits defined (100m/256Mi requests, 500m/512Mi limits)
✅ **CONFIRMED PASS** - Least privilege database user (DDL privileges only, no SUPERUSER)
✅ **CONFIRMED PASS** - runAsNonRoot security context in deployment
⏭️ **CONFIRMED DEFERRED** - Network policies deferred (future enhancement)

### Principle VI: High Availability Architecture
✅ **CONFIRMED PASS** - PostgreSQL cluster HA from feature 011
⏭️ **CONFIRMED DEFERRED** - Application HA (multiple replicas) deferred per spec (single replica MVP)

### Principle VII: Test-Driven Learning
✅ **CONFIRMED PASS** - Quickstart includes validation steps for each phase
✅ **CONFIRMED PASS** - OpenTofu validate/plan documented
✅ **CONFIRMED PASS** - Integration tests documented (connectivity, accessibility, sync)
✅ **CONFIRMED PASS** - Manual test procedures documented for database DDL
✅ **CONFIRMED PASS** - Explicit data persistence test added (FR-007 requirement)

### Principle VIII: Documentation-First
✅ **CONFIRMED PASS** - Complete implementation plan created
✅ **CONFIRMED PASS** - Research decisions documented (research.md)
✅ **CONFIRMED PASS** - Deployment runbook created (quickstart.md)
✅ **CONFIRMED PASS** - Data model documented (data-model.md)
✅ **CONFIRMED PASS** - Cloudflare Tunnel specification documented (contracts/cloudflare-tunnel-spec.yaml)
✅ **CONFIRMED PASS** - Troubleshooting guide included in quickstart

### Principle IX: Network-First Security
✅ **CONFIRMED PASS** - Application runs in cluster VLAN (existing network)
✅ **CONFIRMED PASS** - Cloudflare Tunnel for public access (outbound-only encrypted connection)
✅ **CONFIRMED PASS** - Database only accessible via ClusterIP (internal network)
✅ **CONFIRMED PASS** - No new VLAN or firewall changes required
✅ **CONFIRMED PASS** - Cloudflare Tunnel exception documented with justification

**Final Gate Status**: ✅ **PASS** - All design artifacts align with constitution principles. Deferred items are explicitly documented as future enhancements and do not violate core principles. Cloudflare Tunnel exception properly justified.

## Phase 0: Research (Complete)

**Status**: ✅ Complete - research.md already generated

Research artifacts document 8 key technical decisions:
1. Database provisioning strategy (OpenTofu PostgreSQL provider)
2. Container image registry (Docker Hub public)
3. Database connection configuration (Kubernetes Secret + env vars)
4. Health check endpoints (HTTP /health endpoints)
5. TLS certificate management (Cloudflare Universal SSL - **confirmed in clarifications**)
6. ArgoCD configuration (Auto-sync with self-heal)
7. Resource sizing (100m/256Mi requests, 500m/512Mi limits)
8. Namespace strategy (Dedicated beersystem namespace)

All decisions align with clarified architecture (Cloudflare Tunnel, no cert-manager/Traefik).

## Phase 1: Design & Contracts (Complete)

**Status**: ✅ Complete - All design artifacts already generated

### Generated Artifacts

1. **data-model.md** - PostgreSQL database infrastructure requirements
   - Database: beersystem_stage
   - User: beersystem_admin with DDL privileges
   - OpenTofu resource definitions for database, role, grants

2. **contracts/cloudflare-tunnel-spec.yaml** - Cloudflare Tunnel configuration
   - Traffic flow diagram
   - Tunnel ingress rule for beer.chocolandiadc.com
   - DNS CNAME record configuration
   - TLS certificate management (Cloudflare Universal SSL)
   - **Confirmed architecture** per clarification session

3. **quickstart.md** - Deployment runbook with 6 phases
   - Prerequisites (verify Cloudflare Tunnel operational)
   - Phase 1: Database provisioning with OpenTofu
   - Phase 2: Container image build and push
   - Phase 3: Kubernetes manifests creation
   - Phase 4: Cloudflare Tunnel configuration
   - Phase 5: ArgoCD application configuration
   - Phase 6: Verification and testing

### Agent Context Update

Updating CLAUDE.md with new technologies from this feature...
