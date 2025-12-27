# Implementation Plan: Monitoring Stack Upgrade

**Branch**: `021-monitoring-stack-upgrade` | **Date**: 2025-12-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/021-monitoring-stack-upgrade/spec.md`

## Summary

Upgrade del stack de monitoreo kube-prometheus-stack de la versión 55.5.0 a 68.x+ para obtener compatibilidad con Kubernetes 1.33+, mejoras de seguridad y nuevas funcionalidades. El upgrade preservará los 15 días de métricas históricas, los dashboards existentes (38+ ConfigMaps), y la integración de alertas con Ntfy.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), YAML (Helm values)
**Primary Dependencies**:
- kube-prometheus-stack Helm chart (actual: 55.5.0 → target: 68.4.0)
- Prometheus Operator v0.70.0 → v0.79.2
- Grafana 10.x → 11.4.0
- Alertmanager v0.26.x → v0.27.x
**Storage**: PersistentVolume 10Gi (Prometheus), 5Gi (Grafana) via local-path-provisioner
**Testing**: kubectl, helm, tofu validate/plan, curl (alertas de prueba)
**Target Platform**: K3s cluster (4 nodes: 2 control-plane, 2 workers)
**Project Type**: Infrastructure upgrade (IaC)
**Performance Goals**: Downtime < 5 minutos, scraping continuo
**Constraints**:
- Rollback reversible sin pérdida de datos
- NodePort 30000 para Grafana
- Retención de métricas 15 días
**Scale/Scope**:
- 20+ ServiceMonitors
- 38+ Dashboard ConfigMaps
- 3 receivers de Alertmanager (null, ntfy-homelab, ntfy-critical)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Infrastructure as Code - OpenTofu First | ✅ PASS | Upgrade vía `terraform/environments/chocolandiadc-mvp/monitoring.tf` |
| II. GitOps Workflow | ✅ PASS | Feature branch `021-monitoring-stack-upgrade`, PR antes de merge |
| IV. Observability & Monitoring | ✅ PASS | Mantiene Prometheus + Grafana stack (principio NON-NEGOTIABLE) |
| V. Security Hardening | ✅ PASS | No expone nuevos puertos, mantiene acceso via NodePort existente |
| VI. High Availability | ✅ PASS | Upgrade rolling, downtime < 5 min |
| VII. Test-Driven Learning | ✅ PASS | Validación pre/post upgrade documentada |
| VIII. Documentation-First | ✅ PASS | Procedimiento de rollback documentado |

**Gate Status**: ✅ PASS - Proceder con Phase 0

## Project Structure

### Documentation (this feature)

```text
specs/021-monitoring-stack-upgrade/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output - breaking changes analysis
├── data-model.md        # Phase 1 output - configuration entities
├── quickstart.md        # Phase 1 output - upgrade procedure
├── checklists/          # Validation checklists
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
terraform/
├── environments/
│   └── chocolandiadc-mvp/
│       ├── monitoring.tf           # Main monitoring configuration (MODIFY)
│       └── kubeconfig              # Cluster access
└── dashboards/
    └── homelab-overview.json       # Custom dashboard (PRESERVE)
```

**Structure Decision**: Modificación in-place del archivo `monitoring.tf` existente. No se requieren nuevos módulos ya que el upgrade es del chart Helm, no de la arquitectura.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Ninguno | N/A | N/A |

## Upgrade Path Analysis

### Current State (v55.5.0)
- Prometheus Operator: v0.70.0
- Prometheus: v2.48.x
- Grafana: v10.2.x
- Alertmanager: v0.26.x
- Node Exporter: v1.7.x

### Target State (v68.4.0 - Achieved)
- Prometheus Operator: v0.79.2
- Prometheus: v2.55.x
- Grafana: v11.4.0
- Alertmanager: v0.27.x (uses v2 API, v1 deprecated)
- Node Exporter: v1.8.x (hostNetwork kept false)

### Breaking Changes Identified (from /speckit.clarify)

1. **Prometheus Operator CRDs**: Nuevos campos requeridos en ServiceMonitor/PodMonitor
   - **Decisión**: Auditar y actualizar manualmente antes del upgrade

2. **Grafana Sidecar Labels**: Cambios en labels para dashboard provisioning
   - **Decisión**: Actualizar labels en ConfigMaps antes del upgrade

3. **Alertmanager Receivers**: Nueva estructura para receivers
   - **Decisión**: Validar en entorno de prueba antes del upgrade

4. **Node Exporter hostNetwork**: Cambios en configuración
   - **Decisión**: Mantener configuración explícita en values
