# Implementation Plan: Govee2MQTT Integration

**Branch**: `019-govee2mqtt` | **Date**: 2025-12-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/019-govee2mqtt/spec.md`

## Summary

Integrar dispositivos Govee con Home Assistant mediante govee2mqtt, un bridge que conecta dispositivos Govee via MQTT usando control LAN-first para baja latencia. Requiere desplegar un broker MQTT (Mosquitto) como dependencia y configurar govee2mqtt con las credenciales del usuario.

## Technical Context

**Language/Version**: YAML (Kubernetes manifests), HCL (OpenTofu 1.6+)
**Primary Dependencies**: govee2mqtt (ghcr.io/wez/govee2mqtt), Eclipse Mosquitto (MQTT broker), Home Assistant MQTT integration
**Storage**: PersistentVolume para caché de govee2mqtt (opcional), PV para Mosquitto (persistencia de mensajes)
**Testing**: kubectl smoke tests, MQTT connectivity tests, device discovery validation
**Target Platform**: K3s cluster (Kubernetes 1.28+)
**Project Type**: Infrastructure deployment (OpenTofu modules)
**Performance Goals**: Control de dispositivos < 2 segundos latencia (LAN), descubrimiento < 5 minutos
**Constraints**: Requiere network_mode=host o hostNetwork para descubrimiento LAN de dispositivos Govee
**Scale/Scope**: Single instance deployment, ~10-50 dispositivos Govee típicos

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code - OpenTofu First | PASS | Módulo OpenTofu para Mosquitto + govee2mqtt |
| II. GitOps Workflow | PASS | Cambios via PR, no manual |
| III. Container-First Development | PASS | Ambos servicios en contenedores oficiales |
| IV. Observability & Monitoring | PASS | govee2mqtt expone métricas, integración con Prometheus existente |
| V. Security Hardening | PASS | Credenciales en Kubernetes Secrets |
| VI. High Availability | N/A | Single instance suficiente para homelab |
| VII. Test-Driven Learning | PASS | Tests de conectividad MQTT y descubrimiento |
| VIII. Documentation-First | PASS | Documentación en specs/ |
| IX. Network-First Security | PASS | Servicios en namespace dedicado, acceso controlado |

## Project Structure

### Documentation (this feature)

```text
specs/019-govee2mqtt/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── kubernetes-resources.yaml
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   ├── mosquitto/           # NEW: MQTT broker module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── govee2mqtt/          # NEW: Govee bridge module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    └── chocolandiadc-mvp/
        └── govee2mqtt.tf    # NEW: Module instantiation
```

**Structure Decision**: Dos módulos OpenTofu separados (Mosquitto y govee2mqtt) para reutilización. Mosquitto puede ser usado por otros servicios en el futuro. Ambos en namespace `home-assistant` para colocación con Home Assistant existente.

## Complexity Tracking

> No violations detected - complexity is appropriate for the feature scope.

| Decision | Rationale |
|----------|-----------|
| Mosquitto como broker separado | Reutilizable para otras integraciones MQTT futuras |
| hostNetwork para govee2mqtt | Requerido para descubrimiento LAN de dispositivos Govee |
| Namespace compartido con Home Assistant | Simplifica comunicación MQTT intra-namespace |
