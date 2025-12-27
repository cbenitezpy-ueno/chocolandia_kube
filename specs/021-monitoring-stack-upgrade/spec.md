# Feature Specification: Monitoring Stack Upgrade

**Feature Branch**: `021-monitoring-stack-upgrade`
**Created**: 2025-12-27
**Status**: Complete
**Completed**: 2025-12-27
**Input**: Actualizar el stack de monitoreo (Prometheus, Grafana, Alertmanager) a la última versión estable para obtener mejoras de seguridad, nuevas funcionalidades y compatibilidad con Kubernetes 1.33+.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Upgrade sin pérdida de datos (Priority: P1)

Como administrador del cluster, necesito actualizar los componentes de monitoreo a versiones estables actuales sin perder los datos históricos de métricas ni los dashboards personalizados existentes.

**Why this priority**: La preservación de datos es crítica. Perder 15 días de métricas o dashboards configurados representa horas de trabajo perdido y pérdida de visibilidad histórica para troubleshooting.

**Independent Test**: Se puede verificar comparando el conteo de métricas y la lista de dashboards antes y después del upgrade.

**Acceptance Scenarios**:

1. **Given** el stack de monitoreo actual con 15 días de métricas, **When** se completa el upgrade, **Then** las métricas históricas siguen siendo consultables en Grafana
2. **Given** 6 dashboards existentes (K3s, Node Exporter, Traefik, Redis, PostgreSQL, Longhorn), **When** se completa el upgrade, **Then** todos los dashboards están disponibles y funcionales
3. **Given** configuración de retención de 15 días, **When** se verifica la configuración post-upgrade, **Then** la retención sigue configurada en 15 días

---

### User Story 2 - Continuidad del servicio de alertas (Priority: P1)

Como administrador del cluster, necesito que las alertas sigan funcionando durante y después del upgrade para no perder notificaciones de problemas críticos.

**Why this priority**: Las alertas son el mecanismo principal de detección de problemas. Una interrupción en el sistema de alertas puede causar que incidentes pasen desapercibidos.

**Independent Test**: Enviar una alerta de prueba y verificar que llega a Ntfy correctamente.

**Acceptance Scenarios**:

1. **Given** la integración Alertmanager-Ntfy configurada, **When** se completa el upgrade, **Then** las alertas de prueba llegan correctamente a Ntfy
2. **Given** reglas de alerta existentes, **When** se consultan las reglas post-upgrade, **Then** todas las reglas están activas y en estado correcto
3. **Given** el proceso de upgrade en curso, **When** ocurre una condición de alerta, **Then** la notificación se envía dentro del tiempo máximo de downtime permitido (5 minutos)

---

### User Story 3 - Acceso continuo a Grafana (Priority: P2)

Como usuario del sistema de monitoreo, necesito acceder a los dashboards de Grafana durante el proceso de upgrade con mínima interrupción.

**Why this priority**: El acceso a métricas en tiempo real es importante para operaciones diarias, pero breves interrupciones son tolerables si el upgrade es exitoso.

**Independent Test**: Acceder a Grafana via NodePort 30000 y ejecutar una consulta de métricas.

**Acceptance Scenarios**:

1. **Given** Grafana expuesto en NodePort 30000, **When** se completa el upgrade, **Then** Grafana sigue accesible en el mismo puerto
2. **Given** una consulta de métricas en Grafana, **When** se ejecuta post-upgrade, **Then** retorna resultados correctos de Prometheus
3. **Given** el proceso de upgrade, **When** hay interrupción temporal, **Then** la interrupción no excede 5 minutos

---

### User Story 4 - Rollback en caso de fallo (Priority: P2)

Como administrador del cluster, necesito poder revertir el upgrade rápidamente si algo sale mal para restaurar la funcionalidad de monitoreo.

**Why this priority**: Un plan de rollback es esencial para operaciones de producción. Reduce el riesgo del upgrade al garantizar que siempre hay un camino de recuperación.

**Independent Test**: Ejecutar el procedimiento de rollback documentado y verificar que el estado anterior se restaura.

**Acceptance Scenarios**:

1. **Given** un backup del estado previo al upgrade, **When** se ejecuta el rollback, **Then** el stack vuelve a la versión anterior
2. **Given** el rollback ejecutado, **When** se verifican los pods, **Then** todos los pods están en estado Running
3. **Given** el rollback ejecutado, **When** se verifican las métricas, **Then** los datos históricos están intactos

---

### Edge Cases

- ¿Qué pasa si el upgrade falla a mitad de proceso con algunos componentes actualizados y otros no?
- ¿Cómo se maneja si el almacenamiento de Prometheus se llena durante el upgrade?
- ¿Qué sucede si hay alertas activas durante el proceso de upgrade?
- ¿Cómo se recupera si los CRDs cambian de versión y hay incompatibilidades?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE mantener los datos de métricas existentes durante y después del upgrade
- **FR-002**: El sistema DEBE preservar la configuración de retención de 15 días
- **FR-003**: El sistema DEBE mantener todos los dashboards existentes funcionales (K3s, Node Exporter, Traefik, Redis, PostgreSQL, Longhorn)
- **FR-004**: El sistema DEBE mantener la integración de alertas con Ntfy operativa
- **FR-005**: El sistema DEBE mantener Grafana accesible en NodePort 30000
- **FR-006**: El proceso de upgrade DEBE incluir un procedimiento de rollback documentado
- **FR-007**: El sistema DEBE actualizar a una versión compatible con Kubernetes 1.33+
- **FR-008**: El downtime del sistema de monitoreo NO DEBE exceder 5 minutos
- **FR-009**: El sistema DEBE continuar el scraping de métricas durante el proceso de upgrade (con máximo 5 minutos de interrupción)
- **FR-010**: El proceso de upgrade DEBE ser reversible sin pérdida de datos
- **FR-011**: Se DEBE auditar y actualizar manualmente todos los ServiceMonitor/PodMonitor existentes para incluir los nuevos campos requeridos ANTES de ejecutar el upgrade
- **FR-012**: Se DEBE actualizar los labels en los ConfigMaps de dashboards para que sean compatibles con el nuevo Grafana sidecar ANTES del upgrade
- **FR-013**: Se DEBE validar la nueva estructura de receivers de Alertmanager (integración Ntfy) en un entorno de prueba ANTES del upgrade a producción
- **FR-014**: Se DEBE mantener la configuración de hostNetwork del Node Exporter explícitamente en los values del chart para evitar cambios por defaults

### Key Entities

- **Métricas de Prometheus**: Series temporales de datos recolectados de los targets configurados, con 15 días de retención
- **Dashboards de Grafana**: Visualizaciones configuradas que muestran métricas del cluster (6 dashboards existentes)
- **Reglas de Alerta**: Condiciones configuradas en Alertmanager que disparan notificaciones a Ntfy
- **Configuración de Scrape**: Definiciones de targets y frecuencia de recolección de métricas

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El stack de monitoreo muestra versión 68.x o superior después del upgrade
- **SC-002**: El 100% de los pods del namespace monitoring están en estado Running después del upgrade
- **SC-003**: Los 6 dashboards existentes cargan correctamente y muestran datos actuales
- **SC-004**: Las alertas de prueba llegan a Ntfy en menos de 60 segundos después de generarse
- **SC-005**: Las métricas de los últimos 15 días son consultables sin errores
- **SC-006**: El tiempo total de indisponibilidad del sistema de monitoreo es menor a 5 minutos
- **SC-007**: El proceso de infrastructure-as-code no muestra cambios inesperados post-upgrade
- **SC-008**: El procedimiento de rollback está documentado y probado

## Clarifications

### Session 2025-12-27

- Q: ¿Cómo manejar los cambios en campos requeridos de ServiceMonitor/PodMonitor? → A: Auditar y actualizar manualmente los CRDs existentes antes del upgrade
- Q: ¿Cómo manejar los cambios en labels del Grafana sidecar para dashboard provisioning? → A: Actualizar labels en ConfigMaps de dashboards antes del upgrade
- Q: ¿Cómo manejar la nueva estructura de receivers en Alertmanager? → A: Validar configuración de receivers en entorno de prueba antes del upgrade
- Q: ¿Cómo manejar los cambios en configuración de hostNetwork del Node Exporter? → A: Mantener configuración actual de hostNetwork explícitamente en values

## Assumptions

- La versión actual del stack es anterior a 68.x y requiere actualización
- El cluster tiene suficiente espacio de almacenamiento para mantener dos versiones durante la transición
- Los dashboards existentes son compatibles con las nuevas versiones de Grafana (o requieren ajustes menores)
- La integración con Ntfy usa la API estándar que no cambiará entre versiones
- Los PersistentVolumes de Prometheus tienen suficiente espacio para la retención de 15 días

## Out of Scope

- Cambios en la arquitectura del sistema de monitoreo (e.g., migrar a Thanos o Victoria Metrics)
- Agregar nuevos dashboards o targets de scraping
- Modificar el período de retención de métricas
- Cambiar el método de exposición de Grafana (mantener NodePort 30000)
- Migrar a una solución de alertas diferente a Ntfy

## Dependencies

- Acceso al cluster Kubernetes con permisos de administrador
- Disponibilidad del Helm chart kube-prometheus-stack versión 68.x
- Conectividad a los registros de contenedores para descargar nuevas imágenes
- Backup funcional del estado actual antes de iniciar el upgrade
