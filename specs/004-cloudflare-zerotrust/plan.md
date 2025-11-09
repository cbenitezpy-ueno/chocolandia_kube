# Implementation Plan: Cloudflare Zero Trust VPN Access

**Branch**: `004-cloudflare-zerotrust` | **Date**: 2025-11-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-cloudflare-zerotrust/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy Cloudflare Tunnel connector (cloudflared) as a Kubernetes deployment in the K3s cluster to provide secure remote access to internal services (Pi-hole, future services) without exposing public ports. Integrate with Cloudflare Access using Google OAuth for authentication. All infrastructure defined as OpenTofu modules with Kubernetes manifests (YAML) for deployment.

## Technical Context

**Language/Version**: YAML (Kubernetes manifests), HCL (OpenTofu) 1.6+
**Primary Dependencies**:
- cloudflared container (cloudflare/cloudflared:latest)
- Kubernetes 1.28+ (K3s cluster)
- Cloudflare account with Zero Trust plan (free tier sufficient)
- Domain name managed by Cloudflare DNS
**Storage**: Kubernetes Secret (tunnel token), ConfigMap (tunnel config file - ingress rules)
**Testing**: kubectl integration tests, manual connectivity tests from external networks, OpenTofu validate
**Target Platform**: K3s cluster (3 control-plane + 1 worker node, homelab environment)
**Project Type**: Infrastructure deployment (Kubernetes + IaC)
**Performance Goals**:
- Tunnel connection established < 10 seconds after pod start
- HTTP request latency < 200ms added overhead vs local access
- Tunnel reconnection < 30 seconds after failure
**Constraints**:
- Zero public ports exposed on home router
- Must integrate with existing Pi-hole service
- Must work with Eero network (no VLAN segmentation on homelab network currently)
- **Tunnel Creation Method** (RESOLVED): Dashboard/remotely-managed tunnels (Cloudflare 2024 recommendation, stateless, HA-friendly)
- **DNS Domain** (USER PROVIDED): User will provide domain name managed by Cloudflare DNS
- **Initial Services** (RESOLVED): Pi-hole (confirmed) + future services (Grafana, Homepage) via extensible ingress rules
**Scale/Scope**:
- 1 tunnel deployment (single replica, P3 story adds HA)
- 2-5 ingress routes initially (Pi-hole + future services)
- 1-10 concurrent users (family/friends access)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Infrastructure as Code - OpenTofu First
✅ **PASS**: Cloudflare Tunnel deployment defined in OpenTofu module (Kubernetes provider). All manifests (Secret, ConfigMap, Deployment, Service) managed as IaC. Tunnel configuration stored in ConfigMap for version control.

### II. GitOps Workflow
✅ **PASS**: All changes via Git commits. OpenTofu plan reviewed before apply. Tunnel token stored as Secret (not in Git). ConfigMap for tunnel config versioned in Git.

### III. Container-First Development
✅ **PASS**: cloudflared runs as container (cloudflare/cloudflared:latest). Stateless deployment - tunnel config via ConfigMap, credentials via Secret mount. Health checks (liveness/readiness probes) mandatory for tunnel connectivity validation.

### IV. Observability & Monitoring - Prometheus + Grafana Stack
⚠️ **PARTIAL (acceptable for MVP)**: P3 story adds monitoring integration. cloudflared exposes /metrics endpoint. Grafana dashboard for tunnel status is enhancement. MVP focuses on basic connectivity - monitoring deferred to P3 iteration.

**Justification**: Core functionality (remote access) doesn't require monitoring. Monitoring valuable for operational insight but not blocking for initial deployment. P3 story explicitly addresses this.

### V. Security Hardening
✅ **PASS**:
- Network perimeter: Cloudflare edge network acts as perimeter (no public ports exposed)
- Authentication: Google OAuth via Cloudflare Access enforces authentication
- Secrets management: Tunnel token stored as Kubernetes Secret (encrypted in etcd)
- Principle of least privilege: Only specified email addresses can access via Access policies
- Resource limits: Defined for cloudflared pod (CPU/memory)

**Note**: VLAN segmentation not applicable (Eero network limitation documented in constraints). Cloudflare Tunnel provides defense-in-depth via authentication layer.

### VI. High Availability Architecture
⚠️ **PARTIAL (acceptable for MVP)**: P1 story deploys single replica. P3 story adds HA (multiple replicas, automatic reconnection tested). Single replica sufficient for learning/homelab MVP.

**Justification**: Cloudflare Tunnel automatically reconnects on failure. Single replica provides access during development. P3 explicitly addresses HA testing and multi-replica deployment.

### VII. Test-Driven Learning
✅ **PASS**:
- OpenTofu tests: `tofu validate` before apply
- Integration tests: Connectivity tests from external networks (mobile data, coffee shop)
- Authentication tests: Verify unauthorized access blocked, authorized access succeeds
- Failure tests: Pod deletion/restart validation (P3 story)
- Test documentation: Quickstart guide includes validation steps

### VIII. Documentation-First
✅ **PASS**:
- ADR: Why Cloudflare Zero Trust over VPN solutions (research.md)
- Runbooks: Tunnel creation, Access policy configuration (quickstart.md)
- Troubleshooting: Common issues (tunnel not connecting, DNS resolution, authentication failures)
- Code comments: OpenTofu modules document tunnel config structure
- Network diagrams: Traffic flow diagram (Cloudflare edge → tunnel → K3s service)

### IX. Network-First Security
⚠️ **DEVIATION JUSTIFIED**:
- Cloudflare Tunnel bypasses traditional network perimeter (outbound-only connection)
- No FortiGate integration (homelab uses Eero, no VLAN segmentation)
- Default deny posture: Cloudflare Access enforces authentication (no access without Google OAuth)
- Inter-VLAN routing: Not applicable (flat network)

**Justification**: Cloudflare Zero Trust provides alternative security model (Zero Trust Network Access vs traditional firewall). Eero network limitation prevents VLAN implementation. Cloudflare's edge network + Access authentication provides equivalent security (identity-based vs network-based). Learning value: Zero Trust architecture principles.

**Recommendation**: Future enhancement could integrate with FortiGate when homelab networking upgraded.

### Summary
- **9 principles evaluated**
- **6 PASS**, **3 PARTIAL/DEVIATION**
- **All deviations justified** with learning rationale or MVP scope limitations
- **No blocking violations**

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
terraform/
└── modules/
    └── cloudflare-tunnel/
        ├── main.tf                    # OpenTofu module entry (Kubernetes resources)
        ├── variables.tf               # Module inputs (tunnel_token, service_mappings, etc.)
        ├── outputs.tf                 # Module outputs (deployment status, service endpoints)
        ├── manifests/
        │   ├── secret.yaml           # Tunnel token Secret (template)
        │   ├── configmap.yaml        # Tunnel config file (ingress rules)
        │   ├── deployment.yaml       # cloudflared Deployment
        │   └── service.yaml          # Optional: metrics service (P3)
        └── README.md                  # Module documentation

terraform/environments/chocolandiadc-mvp/
├── cloudflare-tunnel.tf               # Environment-specific tunnel configuration
├── terraform.tfvars                   # Environment variables (NOT committed - contains secrets)
└── terraform.tfvars.example           # Example variables file (template)

scripts/
├── create-tunnel.sh                   # Helper script: Create tunnel via Cloudflare API/CLI
├── configure-access.sh                # Helper script: Configure Cloudflare Access policies
└── test-tunnel.sh                     # Integration test script (connectivity validation)
```

**Structure Decision**: Infrastructure-as-Code structure following existing project patterns (terraform/modules/ for reusable modules, terraform/environments/ for environment-specific configs). Kubernetes manifests managed via OpenTofu (kubernetes_manifest resources or kubectl provider). Helper scripts for one-time Cloudflare setup (tunnel creation, Access configuration).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Monitoring deferred to P3 | MVP focuses on core connectivity | Adding Prometheus integration upfront increases initial complexity. P3 story provides learning path for observability after core functionality validated. |
| Single replica (P1/P2) | Faster MVP delivery, simpler initial deployment | Multiple replicas require coordination testing and LoadBalancer service. Single replica sufficient for learning tunnel mechanics. P3 story explicitly addresses HA. |
| No FortiGate integration | Eero network limitation (no VLAN support) | Cannot implement VLAN segmentation with current home network equipment. Cloudflare Zero Trust provides alternative security model (authentication-based vs network-based). Future enhancement when FortiGate deployed. |
