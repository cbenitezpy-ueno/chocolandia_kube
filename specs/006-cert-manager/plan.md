# Implementation Plan: cert-manager for SSL/TLS Certificate Management

**Branch**: `006-cert-manager` | **Date**: 2025-11-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-cert-manager/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy cert-manager to automate SSL/TLS certificate management with Let's Encrypt. Provides automatic certificate issuance, renewal, and Traefik integration for HTTPS services. Uses ACME HTTP-01 challenges for domain validation and integrates with existing Traefik ingress controller.

## Technical Context

**Language/Version**: HCL (OpenTofu) 1.6+, YAML (Kubernetes manifests)
**Primary Dependencies**: cert-manager v1.13.x (Helm chart), Let's Encrypt ACME CA, Traefik v3.1.0 (ingress controller)
**Storage**: Kubernetes Secrets (TLS certificates and private keys), etcd (cert-manager state via CRDs)
**Testing**: OpenTofu validate/plan, kubectl integration tests, manual ACME challenge validation
**Target Platform**: K3s v1.28+ cluster on Linux (Lenovo/HP mini PCs)
**Project Type**: Infrastructure (Kubernetes cluster add-on)
**Performance Goals**: Certificate issuance within 5 minutes (staging) / 10 minutes (production), renewal automation 30 days before expiry
**Constraints**: Let's Encrypt rate limits (50 certs/week per domain production, 30k staging), HTTP-01 requires port 80 accessible, conservative resource limits for homelab
**Scale/Scope**: 10-50 certificates across homelab services, single namespace deployment (cert-manager), cluster-wide certificate issuance via ClusterIssuers

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Infrastructure as Code - OpenTofu First ✅
- All cert-manager deployment via OpenTofu Helm release
- ClusterIssuers defined as Kubernetes manifests via OpenTofu
- No manual kubectl commands for infrastructure
- State tracked in OpenTofu state file
- **Status**: PASS - Full IaC compliance

### Principle II: GitOps Workflow ✅
- All changes via Git commits and OpenTofu apply
- Pull request workflow for reviews
- OpenTofu plan reviewed before apply
- Rollback via Git revert and re-apply
- **Status**: PASS - GitOps compliant

### Principle III: Container-First Development ✅
- cert-manager runs as containerized pods
- Uses official jetstack/cert-manager images
- Health checks configured (liveness/readiness)
- Stateless containers (state in CRDs)
- **Status**: PASS - Container-native

### Principle IV: Observability & Monitoring - Prometheus + Grafana ✅
- Prometheus metrics enabled on all components
- Metrics endpoint: port 9402
- Certificate expiration metrics exposed
- ServiceMonitor support for Prometheus Operator
- **Status**: PASS - Full observability

### Principle V: Security Hardening ✅
- Resource limits defined (CPU/memory)
- Kubernetes Secrets for certificate storage
- Principle of least privilege (RBAC via Helm chart)
- Webhook validation prevents invalid configurations
- **Status**: PASS - Security compliant

### Principle VI: High Availability Architecture ⚠️  JUSTIFIED DEVIATION
- Single replica per component (controller, webhook, cainjector)
- **Justification**: Homelab environment, learning priority over HA
- cert-manager HA not critical for learning certificate automation
- Single replica sufficient for 10-50 certificates
- Future enhancement: Scale to 2-3 replicas if needed
- **Status**: JUSTIFIED DEVIATION - Acceptable for homelab scope

### Principle VII: Test-Driven Learning ✅
- OpenTofu validate/plan before apply
- Integration tests for certificate issuance (staging then production)
- ACME challenge validation tests
- Failure injection tests (blocked port 80, rate limits)
- **Status**: PASS - Comprehensive testing

### Principle VIII: Documentation-First ✅
- spec.md, research.md, data-model.md, quickstart.md created
- ADR documented: Let's Encrypt + HTTP-01 choice
- Runbook: Quickstart guide with troubleshooting
- Network diagram in data-model.md (certificate workflow)
- **Status**: PASS - Full documentation

### Principle IX: Network-First Security ⚠️ EXTERNAL DEPENDENCY
- HTTP-01 challenge requires port 80 accessible from internet
- Depends on Cloudflare Tunnel (Feature 004) for external access
- Depends on Traefik (Feature 005) for routing challenges
- **Justification**: Required by ACME protocol, no alternative for HTTP-01
- Future enhancement: DNS-01 for environments without port 80 access
- **Status**: JUSTIFIED DEVIATION - ACME protocol requirement

### Gate Results: ✅ PASS with 2 Justified Deviations

**Blocking Issues**: None

**Non-Blocking Deviations**:
1. Single replica deployment (learning priority over HA)
2. External dependency on port 80 access (ACME HTTP-01 requirement)

**Proceed to Phase 0**: ✅ Approved

---

## Project Structure

### Documentation (this feature)

```text
specs/006-cert-manager/
├── plan.md              # This file (implementation plan)
├── research.md          # Technical decisions and research ✅ COMPLETE
├── data-model.md        # Entity model and relationships ✅ COMPLETE
├── quickstart.md        # Deployment and usage guide ✅ COMPLETE
├── contracts/           # N/A (no API contracts for infrastructure)
└── tasks.md             # Phase 2 output (/speckit.tasks command - PENDING)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── cert-manager/                # New module for this feature
│       ├── main.tf                  # Helm release, ClusterIssuers
│       ├── variables.tf             # Configuration inputs
│       ├── outputs.tf               # Exported values (namespace, issuers)
│       ├── versions.tf              # Provider requirements
│       ├── helm-values.yaml         # cert-manager Helm chart values
│       └── README.md                # Module documentation
└── environments/
    └── chocolandiadc-mvp/
        ├── main.tf                  # References cert-manager module
        ├── cert-manager.tf          # Module invocation (NEW)
        └── terraform.tfvars         # ACME email, enable flags

tests/
└── integration/
    └── cert-manager/
        ├── test-staging-cert.yaml      # Staging certificate test
        ├── test-production-cert.yaml   # Production certificate test
        └── test-traefik-ingress.yaml   # Traefik integration test
```

**Structure Decision**: Infrastructure-as-Code structure (no application code). OpenTofu modules + test manifests. Follows existing project convention from Features 001-005.

---

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Single replica (HA deviation) | Homelab learning environment, resource constraints | HA adds complexity without learning value for certificate automation basics |
| Port 80 dependency (Network deviation) | ACME HTTP-01 protocol requires internet-accessible port 80 | DNS-01 requires DNS provider API credentials (adds external dependency and complexity) |
