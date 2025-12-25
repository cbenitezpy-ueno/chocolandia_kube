# Feature Specification: Cluster Version Audit & Update Plan

**Feature Branch**: `020-cluster-version-audit`
**Created**: 2025-12-23
**Status**: Draft
**Input**: User description: "verificar las versiones de todo lo instalado en el cluster y verificar si hay actualizaciones. recomendar un plan de accion de acuerdo a lo que encuentres"

## Executive Summary

Este documento presenta un análisis completo de las versiones actualmente instaladas en el cluster chocolandiadc-mvp versus las versiones más recientes disponibles. Se incluye una evaluación de riesgos y un plan de acción priorizado para las actualizaciones.

## Current State Analysis

### Cluster Infrastructure

| Componente | Versión Actual | Versión Disponible | Diferencia | Prioridad |
|------------|----------------|-------------------|------------|-----------|
| **K3s (Kubernetes)** | v1.28.3+k3s1 | v1.33.7+k3s1 | **5 versiones menor** | CRÍTICA |
| **kubectl (client)** | v1.34.2 | v1.34.2 | Actual | - |

### Ubuntu Server Nodes

| Nodo | Rol | IP | Ubuntu | Kernel | Estado |
|------|-----|-----|--------|--------|--------|
| **master1** | control-plane, etcd | 192.168.4.101 | 24.04.3 LTS | 6.8.0-88-generic | Parches pendientes |
| **nodo03** | control-plane, etcd | 192.168.4.103 | 24.04.3 LTS | 6.8.0-88-generic | Parches pendientes |
| **nodo04** | worker | 192.168.4.104 | 24.04.3 LTS | 6.8.0-88-generic | Parches pendientes |
| **nodo1** | worker | 192.168.4.102 | 24.04.3 LTS | 6.8.0-87-generic | Parches pendientes |

**Análisis Ubuntu**:
- **Point Release**: Ubuntu 24.04.3 LTS es la versión más reciente (lanzada agosto 2025)
- **Kernel**: Hay actualizaciones de seguridad recientes (diciembre 2025) que corrigen 70+ CVEs
- **HWE Kernel**: Ubuntu 24.04.3 incluye opción de kernel HWE 6.14 (desde Ubuntu 25.04)
- **Soporte**: Hasta abril 2029 (5 años), extensible con Ubuntu Pro

### Helm Releases

| Release | Namespace | Versión Chart Actual | Versión App Actual | Versión Disponible | Diferencia |
|---------|-----------|---------------------|-------------------|-------------------|------------|
| **kube-prometheus-stack** | monitoring | 55.5.0 | v0.70.0 | 80.6.0 / v0.87.1 | 25 versiones |
| **longhorn** | longhorn-system | 1.5.5 | v1.5.5 | 1.10.1 / v1.10.1 | 5 versiones menor |
| **argocd** | argocd | 5.51.0 | v2.9.0 | 9.2.0 / v3.2.2 | 2 versiones mayor |
| **cert-manager** | cert-manager | v1.13.3 | v1.13.3 | v1.19.2 | 6 versiones menor |
| **traefik** | traefik | 30.0.2 | v3.1.0 | 38.0.1 / v3.6.5 | 5 versiones menor |
| **redis-shared** | redis | 23.2.12 | 8.2.3 | 24.1.0 / 8.4.0 | 1 versión mayor |
| **postgres-ha** | postgresql | 18.1.9 | 18.1.0 | 18.2.0 | Minor update |
| **headlamp** | headlamp | 0.38.0 | 0.38.0 | - | Verificar |
| **arc-controller** | github-actions | 0.13.0 | 0.13.0 | 0.13.1 | Patch |

### Container Images (No Helm)

| Imagen | Namespace | Versión Actual | Versión Disponible | Estado |
|--------|-----------|----------------|-------------------|--------|
| **pihole** | default | latest | 2025.11.1 | Pin version |
| **home-assistant** | home-assistant | stable | 2025.12.4 | Pin version |
| **homepage** | homepage | latest | v1.8.0 | Pin version |
| **mosquitto** | home-assistant | 2.0.18 | 2.0.18+ | Actual |
| **govee2mqtt** | home-assistant | 2025.11.25 | - | Reciente |
| **ntfy** | ntfy | v2.8.0 | v2.15.0 | 7 versiones |
| **minio** | minio | 2024-01-01 | 2025-10-15 | ~10 meses |
| **nexus** | nexus | latest | 3.87.1 | Pin version |
| **cloudflared** | cloudflare-tunnel | latest | - | Pin version |
| **localstack** | localstack | latest | - | Pin version |
| **metallb** | metallb-system | v0.14.8 | v0.15.3 | 1 versión menor |
| **registry** | registry | 2 | 2 | Actual |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Auditoría de Seguridad del Cluster (Priority: P1)

Como administrador del cluster, necesito conocer qué componentes tienen actualizaciones de seguridad pendientes para poder priorizar los parches críticos.

**Why this priority**: Las vulnerabilidades de seguridad en componentes desactualizados (especialmente K3s con 5 versiones de atraso) representan un riesgo significativo para la integridad del cluster.

**Independent Test**: Se puede verificar consultando los CVEs publicados para las versiones actuales vs las nuevas.

**Acceptance Scenarios**:

1. **Given** el cluster tiene K3s v1.28.3, **When** se consultan los release notes de v1.29-v1.33, **Then** se identifican los CVEs corregidos
2. **Given** hay componentes con tag "latest", **When** se audita el cluster, **Then** se identifican todos los componentes sin versión fija

---

### User Story 2 - Plan de Actualización por Fases (Priority: P1)

Como administrador, necesito un plan de actualización estructurado por fases que minimice el riesgo de downtime y permita rollback.

**Why this priority**: Las actualizaciones no planificadas pueden causar interrupciones del servicio. Un plan estructurado reduce riesgos.

**Independent Test**: Cada fase puede ejecutarse y verificarse independientemente antes de proceder a la siguiente.

**Acceptance Scenarios**:

1. **Given** existe un plan de actualización, **When** se ejecuta la Fase 1, **Then** los componentes actualizados funcionan correctamente sin afectar a otros
2. **Given** una actualización falla, **When** se inicia rollback, **Then** el componente vuelve a la versión anterior en menos de 10 minutos

---

### User Story 3 - Eliminación de Tags "latest" (Priority: P2)

Como administrador, necesito fijar versiones específicas en lugar de "latest" para tener deployments reproducibles y auditables.

**Why this priority**: El uso de "latest" hace imposible reproducir el estado exacto del cluster y dificulta el troubleshooting.

**Independent Test**: Verificar que cada imagen tenga un tag específico (semver o SHA) en los manifiestos de Kubernetes.

**Acceptance Scenarios**:

1. **Given** pihole usa tag "latest", **When** se actualiza a "2025.11.1", **Then** el pod funciona correctamente
2. **Given** homepage usa "latest", **When** se actualiza a "v1.8.0", **Then** el dashboard carga sin errores

---

### User Story 4 - Documentación de Compatibilidad (Priority: P3)

Como administrador, necesito documentar las compatibilidades entre versiones para futuras actualizaciones.

**Why this priority**: Facilita futuras actualizaciones y reduce el tiempo de investigación.

**Independent Test**: Verificar que la documentación cubra las dependencias críticas entre componentes.

**Acceptance Scenarios**:

1. **Given** existe matriz de compatibilidad, **When** se planifica actualizar ArgoCD, **Then** se conocen los requisitos de K8s mínimo
2. **Given** se documenta una actualización, **When** se consulta la documentación, **Then** se encuentra el proceso paso a paso

---

### Edge Cases

- ¿Qué pasa si K3s falla durante la actualización y el cluster queda inaccesible?
- ¿Cómo se manejan actualizaciones de Longhorn que requieren migración de volúmenes?
- ¿Qué sucede si ArgoCD se actualiza y los CRDs son incompatibles con las apps existentes?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Sistema DEBE tener un inventario documentado de todas las versiones instaladas
- **FR-002**: Plan de actualización DEBE incluir procedimientos de rollback para cada componente
- **FR-003**: Actualizaciones DEBEN ejecutarse en orden de dependencia (K3s primero, luego componentes)
- **FR-004**: Componentes con tag "latest" DEBEN actualizarse a versiones específicas
- **FR-005**: Cada fase de actualización DEBE incluir validación de funcionamiento antes de continuar
- **FR-006**: Backups DEBEN crearse antes de cada actualización crítica (etcd, bases de datos)
- **FR-007**: Prometheus alerts DEBEN monitorear el proceso de upgrade para detectar fallos automáticamente (node down, pod failures, volume issues)

### Key Entities

- **Component**: Representa cada servicio instalado (nombre, versión actual, versión target, namespace)
- **Update Phase**: Agrupa componentes por prioridad y dependencia de actualización
- **Compatibility Matrix**: Documenta requisitos de versión entre componentes dependientes

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% de los componentes tienen versiones documentadas en el inventario
- **SC-002**: 0 componentes usan tag "latest" al finalizar el plan
- **SC-003**: Todas las actualizaciones completadas correctamente con validación exhaustiva (priorizar calidad sobre uptime; sin RTO estricto)
- **SC-004**: Todos los componentes con vulnerabilidades conocidas (CVE) son actualizados
- **SC-005**: Diferencia máxima de 2 versiones menores entre versión instalada y disponible para componentes críticos

## Recommended Action Plan

### Fase 0: Preparación (Pre-requisitos)

1. **Backup completo del cluster**
   - Snapshot de etcd
   - Export de todos los recursos de Kubernetes
   - Backup de PersistentVolumes críticos (PostgreSQL, Redis)

2. **Fijar versiones "latest"**
   - Actualizar manifiestos para usar versiones específicas
   - Componentes afectados: pihole, home-assistant, homepage, nexus, cloudflared, localstack

### Fase 0.5: Actualización de Seguridad Ubuntu

**Prioridad**: MEDIA-ALTA
**Riesgo**: Bajo
**Downtime**: ~2-5 minutos por nodo (reboot)

| Nodo | Orden | Kernel Actual | Acción |
|------|-------|---------------|--------|
| nodo1 | 1 | 6.8.0-87-generic | apt upgrade + reboot |
| nodo04 | 2 | 6.8.0-88-generic | apt upgrade + reboot |
| nodo03 | 3 | 6.8.0-88-generic | apt upgrade + reboot (verificar etcd) |
| master1 | 4 | 6.8.0-88-generic | apt upgrade + reboot (último, verificar quorum) |

**Nota**: Ver sección "Ubuntu Server Update Risk Assessment" para detalles completos.

### Fase 1: Actualización de K3s (CRÍTICA)

**Prioridad**: ALTA
**Riesgo**: Alto
**Downtime estimado**: 5-10 minutos por nodo

**Plan**:
1. Actualizar K3s de v1.28.3 a v1.30.x (salto seguro de 2 versiones menores)
2. Validar funcionamiento del cluster
3. Actualizar de v1.30.x a v1.32.x
4. Validar funcionamiento
5. Actualizar a v1.33.7 (versión target)

**Rollback**: Reinstalar binario K3s de versión anterior

### Fase 2: Storage y Datos

**Prioridad**: ALTA

| Componente | De | A | Notas |
|------------|-----|-----|-------|
| Longhorn | v1.5.5 | v1.10.1 | Requiere migración de engine, hacer en ventana de mantenimiento |
| PostgreSQL | 18.1.9 | 18.2.0 | Minor update, bajo riesgo |
| Redis | 8.2.3 | 8.4.0 | Minor update, bajo riesgo |

### Fase 3: Observabilidad y Seguridad

**Prioridad**: MEDIA-ALTA

| Componente | De | A | Notas |
|------------|-----|-----|-------|
| kube-prometheus-stack | v0.70.0 | v0.87.1 | Muchos cambios, revisar breaking changes |
| cert-manager | v1.13.3 | v1.19.2 | Actualizar CRDs primero |
| ntfy | v2.8.0 | v2.15.0 | Actualización directa posible |

### Fase 4: Ingress y GitOps

**Prioridad**: MEDIA

| Componente | De | A | Notas |
|------------|-----|-----|-------|
| Traefik | v3.1.0 | v3.6.5 | Revisar cambios en middlewares |
| ArgoCD | v2.9.0 | v3.2.2 | Salto de versión mayor, requiere planificación |
| MetalLB | v0.14.8 | v0.15.3 | Revisar cambios en CRDs |

### Fase 5: Aplicaciones

**Prioridad**: BAJA

| Componente | De | A | Notas |
|------------|-----|-----|-------|
| Headlamp | 0.38.0 | verificar | Bajo impacto |
| Homepage | latest | v1.8.0 | Fijar versión |
| Pi-hole | latest | 2025.11.1 | Fijar versión |
| Home Assistant | stable | 2025.12.4 | Fijar versión |
| MinIO | 2024-01-01 | 2025-10-15 | Actualización significativa |

## Risk Assessment

### Riesgos Altos
1. **K3s 5 versiones atrás**: Vulnerabilidades de seguridad conocidas, APIs deprecadas
2. **Longhorn 5 versiones atrás**: Posibles bugs en storage, riesgo de pérdida de datos

### Riesgos Medios
1. **ArgoCD v2 a v3**: Cambios breaking en API, posible reconfiguración necesaria
2. **kube-prometheus-stack**: Muchos cambios acumulados, posible pérdida de dashboards

### Riesgos Bajos
1. **Tags "latest"**: No es un riesgo de seguridad inmediato pero dificulta reproducibilidad

---

## Ubuntu Server Update Risk Assessment

### Estado Actual
- **Ubuntu Version**: 24.04.3 LTS (Noble Numbat) - ÚLTIMA point release disponible
- **Kernel**: 6.8.0-87/88-generic - Parches de seguridad pendientes
- **containerd**: 1.7.7-k3s1 (bundled con K3s)

### Tipo de Actualización Requerida

| Tipo | Acción | Riesgo | Recomendación |
|------|--------|--------|---------------|
| **apt upgrade** | Parches de seguridad del kernel | BAJO | RECOMENDADO |
| **Point release upgrade** | Ya en 24.04.3 (última) | N/A | No necesario |
| **LTS upgrade** (24.04 a 26.04) | Cambio de versión mayor | ALTO | NO recomendado aún |
| **HWE Kernel** (6.8 a 6.14) | Nuevo kernel hardware enablement | MEDIO | Opcional |

### Evaluación de Riesgo: apt upgrade (Parches de Seguridad)

**Nivel de Riesgo: BAJO**

#### Factores que REDUCEN el riesgo:
1. **No hay cambio de versión mayor** - Solo parches dentro de Ubuntu 24.04.3
2. **Kernel LTS estable** - El kernel 6.8 es maduro y bien probado
3. **K3s compatible** - K3s v1.28+ soporta completamente Ubuntu 24.04
4. **Rollback posible** - GRUB permite boot a kernel anterior si hay problemas
5. **CVEs críticos corregidos** - Actualizaciones de diciembre 2025 corrigen 70+ vulnerabilidades

#### Factores que AUMENTAN el riesgo:
1. **Requiere reboot** - Las actualizaciones de kernel requieren reinicio
2. **Nodos control-plane** - master1 y nodo03 tienen etcd, requieren coordinación
3. **Longhorn** - Los volúmenes deben estar healthy antes de reiniciar nodos
4. **Tiempo de inactividad** - Cada nodo estará offline durante el reboot (~2-5 min)

#### CVEs Recientes Corregidos (Diciembre 2025):
- CVE-2025-38666, CVE-2025-37958, CVE-2025-40018 (19 dic 2025)
- CVE-2025-22060, CVE-2025-39682 + 70 más (16 dic 2025)
- Vulnerabilidades en AF_UNIX socket, Overlay filesystem, Network traffic control

### Evaluación de Riesgo: HWE Kernel (6.8 a 6.14)

**Nivel de Riesgo: MEDIO**

#### Beneficios:
- Mejor soporte de hardware nuevo
- Mejoras de rendimiento
- Nuevas características de kernel

#### Riesgos:
- Kernel menos probado en producción
- Posibles incompatibilidades con drivers
- Mayor superficie de ataque (código más nuevo)

**Recomendación**: NO instalar HWE kernel a menos que haya requerimientos específicos de hardware.

### Plan de Actualización Ubuntu Recomendado

#### Fase 0.5: Actualización de Seguridad Ubuntu (Agregar al plan)

**Prioridad**: MEDIA-ALTA
**Riesgo**: Bajo
**Downtime**: ~2-5 minutos por nodo (reboot)

**Secuencia de actualización**:

1. **Workers primero** (nodo1, nodo04)
   ```
   # En cada worker, uno a la vez:
   sudo apt update
   sudo apt upgrade -y
   sudo reboot
   # Esperar que el nodo esté Ready antes de continuar
   ```

2. **Control-plane secundario** (nodo03)
   ```
   # Verificar que etcd esté healthy
   # Actualizar y reiniciar
   ```

3. **Control-plane primario** (master1)
   ```
   # Último para minimizar riesgo
   # Verificar quorum etcd antes y después
   ```

**Validaciones entre cada nodo**:
- `kubectl get nodes` - Nodo en estado Ready
- `kubectl get pods -A` - Todos los pods running
- Verificar Longhorn volumes healthy
- Verificar etcd cluster healthy (para control-plane)

**Rollback**:
- Seleccionar kernel anterior en GRUB si hay problemas de boot
- Máximo 5 minutos de rollback por nodo

### Orden Sugerido de Actualizaciones Completo

| Orden | Componente | Riesgo | Justificación |
|-------|------------|--------|---------------|
| 1 | Ubuntu apt upgrade (workers) | BAJO | Parches seguridad, menor impacto |
| 2 | Ubuntu apt upgrade (control-plane) | BAJO | Parches seguridad con coordinación etcd |
| 3 | K3s upgrade (gradual) | ALTO | Base del cluster, debe ser primero |
| 4 | Longhorn | ALTO | Storage crítico |
| 5 | Otros componentes | MEDIO-BAJO | Según plan original |

## Clarifications

### Session 2025-12-23

- Q: How should the upgrade process itself be monitored for failures during execution? → A: Prometheus alerts monitoring upgrade in progress
- Q: What is the maximum acceptable RTO if a critical upgrade fails and requires full rollback? → A: No strict RTO - prioritize correctness and testing over uptime

## Assumptions

- El cluster tiene capacidad de almacenamiento suficiente para backups
- Existe una ventana de mantenimiento disponible para actualizaciones críticas
- Los nodos del cluster están saludables y pueden reiniciarse
- Se mantiene acceso SSH a los nodos para recovery si es necesario
- **Filosofía de upgrade**: Priorizar correctness y testing exhaustivo sobre minimizar downtime; no hay RTO estricto para rollback
