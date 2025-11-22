# Implementation Plan: Monitoring & Alerting System

**Branch**: `014-monitoring-alerts` | **Date**: 2025-11-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/014-monitoring-alerts/spec.md`

## Summary

Implementar un sistema completo de monitoreo y alertas para el homelab K3s que incluye:
- Detección de nodos caídos y servicios no disponibles con alertas inmediatas
- Recolección de Golden Signals (latencia, tráfico, errores, saturación) por aplicación y nodo
- Notificaciones push vía Ntfy (self-hosted) como canal de alertas

El stack técnico será Prometheus + Grafana + Alertmanager + Ntfy, alineado con la constitución del proyecto (Principio IV: Prometheus + Grafana NON-NEGOTIABLE).

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), YAML (Kubernetes manifests), Bash (scripts de validación)
**Primary Dependencies**: Prometheus (kube-prometheus-stack Helm chart), Grafana, Alertmanager, Ntfy
**Storage**: Kubernetes PersistentVolumes via local-path-provisioner (métricas 7-14 días retención)
**Testing**: OpenTofu validate, kubectl smoke tests, alerting tests (simular caídas)
**Target Platform**: K3s cluster (4 nodos: 2 control-plane, 2 workers)
**Project Type**: Infrastructure (OpenTofu modules + Helm deployments)
**Performance Goals**: Métricas con <1 min delay, alertas en <2 min desde detección
**Constraints**: Recursos limitados de homelab, retención 7-14 días, sin dependencias externas
**Scale/Scope**: 4 nodos, ~20 servicios monitoreados, 1 administrador

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code - OpenTofu First | PASS | Todo en módulos OpenTofu + Helm |
| II. GitOps Workflow | PASS | Cambios via Git, review antes de apply |
| III. Container-First Development | PASS | Prometheus/Grafana/Ntfy como containers |
| IV. Observability & Monitoring (NON-NEGOTIABLE) | PASS | Este feature implementa exactamente esto |
| V. Security Hardening | PASS | Secrets en K8s, acceso via Cloudflare Access |
| VI. High Availability | PASS | Prometheus con PVC persistente |
| VII. Test-Driven Learning (NON-NEGOTIABLE) | PASS | Tests de conectividad y alertas |
| VIII. Documentation-First | PASS | Runbooks y dashboards documentados |
| IX. Network-First Security | PASS | Ntfy expuesto via Traefik/Cloudflare |

**Gate Result**: PASS - Proceder a Phase 0

## Project Structure

### Documentation (this feature)

```text
specs/014-monitoring-alerts/
├── plan.md              # This file
├── research.md          # Phase 0: Technology decisions
├── data-model.md        # Phase 1: Alert/metric entities
├── quickstart.md        # Phase 1: Deployment guide
├── contracts/           # Phase 1: Alert definitions, API specs
└── tasks.md             # Phase 2: Implementation tasks
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   ├── prometheus-stack/     # Prometheus + Grafana + Alertmanager
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── values/
│   │       └── prometheus-values.yaml
│   ├── ntfy/                 # Ntfy notification server
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── alerting-rules/       # Alert rules as ConfigMaps
│       ├── main.tf
│       └── rules/
│           ├── node-alerts.yaml
│           └── service-alerts.yaml
└── environments/
    └── chocolandiadc-mvp/
        ├── monitoring.tf     # Module instantiation
        └── ntfy.tf           # Ntfy deployment

scripts/
└── monitoring/
    ├── test-alerts.sh        # Test alerting pipeline
    └── validate-metrics.sh   # Verify metrics collection
```

**Structure Decision**: Infrastructure-only project. No backend/frontend code - pure OpenTofu modules for deploying and configuring the monitoring stack via Helm charts.

## Complexity Tracking

> No violations detected. Feature aligns with constitution principles.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |
