# Implementation Plan: Paperless-ngx Google Drive Backup

**Branch**: `028-paperless-gdrive-backup` | **Date**: 2026-01-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/028-paperless-gdrive-backup/spec.md`

## Summary

Implementar un sistema de backup automatizado para Paperless-ngx que sincronice los documentos y datos a Google Drive usando rclone, ejecutado como CronJob en Kubernetes. El backup será incremental, enviará notificaciones a ntfy, y proporcionará documentación para restauración.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), Bash scripting para scripts de backup
**Primary Dependencies**: rclone/rclone:latest, curl (para ntfy), kubectl
**Storage**: PVCs existentes (paperless-ngx-data 5Gi, paperless-ngx-media 40Gi), Google Drive como destino
**Testing**: `tofu validate`, `tofu plan`, kubectl exec manual tests
**Target Platform**: K3s cluster (Kubernetes 1.28+)
**Project Type**: Infrastructure (OpenTofu module + CronJob)
**Performance Goals**: Backup incremental < 5 min cuando no hay cambios, < 30 min para 1GB nuevos
**Constraints**: 512Mi RAM, 500m CPU, timeout 2 horas, PVCs son RWO (no RWX)
**Scale/Scope**: ~45GB de datos (5Gi data + 40Gi media), backup diario

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status | Notes |
|-----------|-------------|--------|-------|
| I. Infrastructure as Code | Todo en OpenTofu | PASS | Módulo TF para CronJob |
| II. GitOps Workflow | Cambios vía Git + PR | PASS | Feature branch creada |
| III. Container-First | Containers stateless | PASS | rclone es stateless, datos en PVCs |
| IV. Observability | Métricas + alertas | PASS | Notificaciones a ntfy, logs en stdout |
| V. Security Hardening | Secrets en K8s Secrets | PASS | Credenciales OAuth en Secret |
| VI. High Availability | Tolerar falla de nodo | N/A | CronJob es batch, no HA required |
| VII. Test-Driven | Tests de validación | PASS | Script de test manual incluido |
| VIII. Documentation-First | Documentación completa | PASS | quickstart.md con setup OAuth |
| IX. Network-First Security | VLAN segmentation | N/A | Tráfico interno cluster + egress a Google |

**Gate Result**: PASS - Proceder a Phase 0

## Project Structure

### Documentation (this feature)

```text
specs/028-paperless-gdrive-backup/
├── plan.md              # This file
├── research.md          # Phase 0: rclone config, PVC access patterns
├── data-model.md        # Phase 1: Kubernetes resources
├── quickstart.md        # Phase 1: Setup OAuth credentials
├── contracts/           # N/A (no API)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
terraform/
├── modules/
│   └── paperless-backup/          # NEW: Módulo de backup
│       ├── main.tf                # CronJob, Secret placeholder, ConfigMap
│       ├── variables.tf           # Schedule, resources, paths
│       ├── outputs.tf             # Secret name para documentación
│       └── README.md              # Uso del módulo
│
└── environments/
    └── chocolandiadc-mvp/
        └── paperless-backup.tf    # NEW: Instancia del módulo

scripts/
└── paperless-backup/              # NEW: Scripts auxiliares
    ├── backup.sh                  # Script principal del CronJob
    ├── restore.sh                 # Script de restauración manual
    └── setup-rclone.sh            # Helper para configurar OAuth
```

**Structure Decision**: Módulo OpenTofu separado en `terraform/modules/paperless-backup/` siguiendo el patrón de otros módulos del cluster. Scripts en `scripts/paperless-backup/` para lógica compleja fuera del container.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Script bash complejo | Manejo de errores y notificaciones | Inline en container sería ilegible |
| ConfigMap para script | Script > 4KB no cabe en args | Heredoc en TF es difícil de mantener |

## Technical Decisions Pending (Phase 0)

1. **PVC Access Strategy**: Los PVCs son RWO. Opciones:
   - a) Escalar Paperless a 0 replicas durante backup (downtime)
   - b) Usar hostPath directo al nodo donde está el PVC
   - c) Ejecutar backup como sidecar dentro del pod de Paperless
   - d) Usar snapshot del PV antes de backup

2. **rclone OAuth Setup**: Cómo crear las credenciales iniciales (requiere browser)

3. **Estructura de carpetas en Google Drive**: Decidir naming convention
