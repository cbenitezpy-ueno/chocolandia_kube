# Implementation Plan: Home Assistant with Prometheus Temperature Monitoring

**Branch**: `018-home-assistant` | **Date**: 2025-12-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/018-home-assistant/spec.md`
**Scope**: Phase 1 - Base Installation + Prometheus Integration (Govee deferred)

## Summary

Deploy Home Assistant as a containerized application on the K3s cluster with Prometheus integration to visualize CPU temperature metrics. Home Assistant will be exposed via dual Traefik ingress (local-ca for .local domain, Let's Encrypt for .com domain). HACS will be installed to enable the ha-prometheus-sensor custom integration for reading temperature data from the existing Prometheus monitoring stack.

## Technical Context

**Language/Version**: YAML (Kubernetes manifests) / HCL (OpenTofu) 1.6+
**Primary Dependencies**: Home Assistant Core (ghcr.io/home-assistant/home-assistant:stable), HACS, ha-prometheus-sensor
**Storage**: Kubernetes PersistentVolume via local-path-provisioner (10Gi for /config)
**Testing**: Manual validation scripts (kubectl commands, curl tests)
**Target Platform**: K3s cluster (chocolandiadc-mvp environment)
**Project Type**: Infrastructure deployment (OpenTofu module)
**Performance Goals**: Dashboard load <3 seconds, sensor update <60 seconds
**Constraints**: No automation in Phase 1, Govee integration deferred
**Scale/Scope**: Single Home Assistant instance, single temperature sensor

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code | ✅ PASS | OpenTofu module for all K8s resources |
| II. GitOps Workflow | ✅ PASS | Feature branch, PR before merge |
| III. Container-First | ✅ PASS | Official HA container image with probes |
| IV. Observability | ✅ PASS | Integrates with existing Prometheus |
| V. Security Hardening | ✅ PASS | TLS on both domains, K8s secrets |
| VI. High Availability | ⚠️ PARTIAL | Single replica (acceptable for home automation) |
| VII. Test-Driven Learning | ✅ PASS | tofu validate, connectivity tests |
| VIII. Documentation-First | ✅ PASS | quickstart.md, spec.md |
| IX. Network-First Security | ✅ PASS | Uses existing VLAN/network config |

**HA Justification**: Single replica is acceptable because:
1. Home Assistant is a stateful application with embedded database
2. Phase 1 scope is visualization only (no critical automation)
3. PVC ensures configuration persistence across restarts

## Project Structure

### Documentation (this feature)

```text
specs/018-home-assistant/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── contracts/           # Phase 1 output
    └── kubernetes-resources.yaml
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── home-assistant/
│       ├── main.tf          # Namespace, PVC, Deployment, Service, Ingress
│       ├── variables.tf     # Configurable parameters
│       └── outputs.tf       # Service endpoints
└── environments/
    └── chocolandiadc-mvp/
        └── home-assistant.tf  # Module instantiation
```

**Structure Decision**: OpenTofu module follows existing patterns (pihole, nexus, etc.) with module definition in `terraform/modules/` and instantiation in environment directory.
