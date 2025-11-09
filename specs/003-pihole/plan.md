# Implementation Plan: Pi-hole DNS Ad Blocker

**Branch**: `003-pihole` | **Date**: 2025-11-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-pihole/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy Pi-hole as a containerized DNS ad blocker on the existing K3s cluster (Feature 002 MVP) to provide network-wide ad blocking for devices on the Eero network. Pi-hole will be exposed via NodePort for web admin access from the user's notebook, with persistent storage for configuration and query history.

## Technical Context

**Language/Version**: YAML (Kubernetes manifests) / HCL (OpenTofu) 1.6+
**Primary Dependencies**: Pi-hole Docker image (pihole/pihole:latest), K3s local-path-provisioner, kubectl, Helm (optional)
**Storage**: Kubernetes PersistentVolume (local-path-provisioner) for /etc/pihole and /etc/dnsmasq.d
**Testing**: Bash integration tests (DNS query validation, web interface accessibility, service availability)
**Target Platform**: K3s cluster on Eero network (192.168.4.0/24) - 2 nodes (master1: 192.168.4.101, nodo1: 192.168.4.102)
**Project Type**: Infrastructure deployment (Kubernetes workload + OpenTofu modules)
**Performance Goals**: <100ms DNS query latency (95th percentile cached), >15% ad blocking rate, 99% uptime
**Constraints**: Single pod deployment (no HA initially), must fit in ~512Mi memory and ~0.5 CPU, NodePort range 30000-32767
**Scale/Scope**: Home network with 10-20 devices, ~1000 DNS queries/day, single Pi-hole instance

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ I. Infrastructure as Code - OpenTofu First
- **Status**: PASS
- **Validation**: Pi-hole deployment will use OpenTofu modules or Kubernetes manifests (via OpenTofu kubernetes provider)
- **Compliance**: All infrastructure changes tracked in Git, deployed via `tofu apply`

### ✅ II. GitOps Workflow
- **Status**: PASS
- **Validation**: Feature branch `003-pihole`, PR review before merge to main, all changes version-controlled
- **Compliance**: Follows existing GitOps workflow from Feature 002

### ✅ III. Container-First Development
- **Status**: PASS
- **Validation**: Pi-hole runs as Docker container (pihole/pihole image), uses PersistentVolumes for state
- **Compliance**: Official Pi-hole Docker image, health checks via readiness/liveness probes

### ✅ IV. Observability & Monitoring - Prometheus + Grafana Stack
- **Status**: PASS (with optional P3 enhancement)
- **Validation**: Pi-hole metrics can be exposed to Prometheus (P3 user story), existing Grafana stack available
- **Compliance**: MVP works standalone with Pi-hole built-in dashboard, Prometheus integration is enhancement

### ✅ V. Security Hardening
- **Status**: PASS
- **Validation**: Admin password stored in Kubernetes Secret, NodePort only accessible from Eero network (192.168.4.0/24)
- **Compliance**: No public exposure, secret management follows best practices, resource limits defined

### ✅ VI. High Availability (HA) Architecture
- **Status**: JUSTIFIED DEVIATION
- **Validation**: Single Pi-hole pod (not HA), but acceptable for home network
- **Justification**: DNS service is non-critical for learning environment; single pod simplifies deployment while learning Pi-hole. Future enhancement can add HA if needed. Devices can fall back to upstream DNS (Eero default) if Pi-hole fails.

### ✅ VII. Test-Driven Learning
- **Status**: PASS
- **Validation**: Integration tests for DNS resolution, web interface accessibility, service availability, query blocking
- **Compliance**: Each user story has independent test scenarios, automated validation scripts planned

### ✅ VIII. Documentation-First
- **Status**: PASS
- **Validation**: Specification complete, implementation plan in progress, troubleshooting guide and runbook will be created
- **Compliance**: Documentation for device DNS configuration, common issues (false positives, pod failures)

### ✅ IX. Network-First Security
- **Status**: PASS (within Eero constraints)
- **Validation**: Pi-hole DNS and web interface only accessible from Eero network (192.168.4.0/24)
- **Compliance**: No public exposure, network access controlled by NodePort + Eero network isolation
- **Note**: Full VLAN segmentation not available on Eero (consumer router), but network isolation enforced at router level

**Overall Gate Status**: ✅ PASS - All principles satisfied or deviations justified

**Deviations**:
- **HA Architecture**: Single pod deployment (not HA)
  - **Justification**: Home network DNS is not mission-critical; single pod reduces complexity for learning Pi-hole basics. Failure impact is limited (devices fall back to Eero default DNS). HA can be added later if uptime becomes critical.
- **Network-First Security**: Limited to Eero router capabilities (no VLAN segmentation)
  - **Justification**: Eero is consumer mesh router without VLAN support. Network isolation enforced at router level (192.168.4.0/24 subnet). Future migration to FortiGate (Feature 001) will enable full VLAN segmentation.

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
├── modules/
│   └── pihole/                    # Pi-hole deployment module
│       ├── main.tf                # Kubernetes resources (Deployment, Service, Secret, PVC)
│       ├── variables.tf           # Module input variables
│       ├── outputs.tf             # Module outputs (NodePort, admin password retrieval)
│       └── manifests/             # Alternative: Raw Kubernetes YAML manifests
│           ├── deployment.yaml
│           ├── service-dns.yaml
│           ├── service-web.yaml
│           ├── pvc.yaml
│           └── secret.yaml
└── environments/
    └── chocolandiadc-mvp/
        ├── pihole.tf              # Pi-hole module invocation for MVP environment
        └── kubeconfig             # Existing K3s cluster kubeconfig

tests/
└── integration/
    ├── test-pihole-dns.sh         # DNS query validation tests
    ├── test-pihole-web.sh         # Web interface accessibility tests
    └── test-pihole-blocking.sh    # Ad blocking effectiveness tests

docs/
├── pihole-setup.md                # Pi-hole deployment and configuration guide
├── pihole-troubleshooting.md      # Common issues and solutions
└── device-dns-config.md           # How to configure devices to use Pi-hole
```

**Structure Decision**: Infrastructure-focused project using OpenTofu modules for Kubernetes resource deployment. Pi-hole is deployed as a Kubernetes workload (Deployment + Services + PersistentVolumeClaim + Secret) on the existing K3s cluster. Integration tests validate DNS functionality, web interface accessibility, and ad blocking effectiveness.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Single pod (no HA) | Simplifies learning Pi-hole deployment and operation | HA adds complexity (multiple replicas, DNS load balancing) without significant benefit for home network. DNS is not mission-critical; devices fall back to Eero default DNS on failure. HA can be added later if uptime becomes priority. |
| Eero network (no VLAN segmentation) | Temporary MVP environment while FortiGate is being repaired | Full VLAN segmentation requires FortiGate (Feature 001 HA architecture). Eero provides adequate network isolation for learning environment. Migration path to FortiGate documented in spec. |
