# Feature Specification: Monitoring & Alerting System

**Feature Branch**: `014-monitoring-alerts`
**Created**: 2025-11-22
**Status**: Draft
**Input**: Sistema de monitoreo con alertas para nodos caídos y servicios no disponibles, golden signals por aplicación y nodo, con notificaciones vía Ntfy (self-hosted)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recibir Alerta de Nodo Caído (Priority: P1)

Como administrador del homelab, quiero recibir una notificación inmediata en mi dispositivo móvil cuando un nodo del cluster deja de responder, para poder investigar y restaurar el servicio rápidamente.

**Why this priority**: Un nodo caído puede afectar múltiples servicios y workloads. Es la alerta más crítica para mantener la disponibilidad del cluster.

**Independent Test**: Apagar un nodo del cluster y verificar que llega una notificación push al dispositivo móvil dentro del tiempo esperado.

**Acceptance Scenarios**:

1. **Given** todos los nodos están operativos, **When** un nodo deja de responder por más de 60 segundos, **Then** recibo una notificación push con el nombre del nodo afectado y timestamp
2. **Given** un nodo estaba caído, **When** el nodo vuelve a estar operativo, **Then** recibo una notificación de recuperación
3. **Given** múltiples nodos caen simultáneamente, **When** se detecta la falla, **Then** recibo notificaciones individuales por cada nodo afectado

---

### User Story 2 - Recibir Alerta de Servicio No Disponible (Priority: P1)

Como administrador del homelab, quiero recibir una notificación cuando un servicio crítico (pod/deployment) no está disponible, para poder actuar antes de que los usuarios finales se vean afectados.

**Why this priority**: Los servicios son lo que los usuarios finales consumen. Una caída de servicio tiene impacto directo en la experiencia del usuario.

**Independent Test**: Escalar un deployment a 0 réplicas y verificar que llega una notificación indicando el servicio afectado.

**Acceptance Scenarios**:

1. **Given** un deployment tiene réplicas configuradas, **When** todas las réplicas fallan o están en estado no-Running, **Then** recibo una notificación con namespace y nombre del servicio
2. **Given** un pod está en estado CrashLoopBackOff por más de 3 minutos, **When** el sistema detecta esta condición, **Then** recibo una notificación con detalles del pod
3. **Given** un servicio estaba caído, **When** se recupera y tiene pods Running, **Then** recibo una notificación de recuperación

---

### User Story 3 - Visualizar Golden Signals por Aplicación (Priority: P2)

Como administrador del homelab, quiero ver las 4 golden signals (latencia, tráfico, errores, saturación) de cada aplicación para entender el estado de salud de mis servicios.

**Why this priority**: Las golden signals permiten detectar problemas antes de que causen caídas completas y entender tendencias de rendimiento.

**Independent Test**: Acceder a un dashboard y verificar que cada aplicación muestra métricas de latencia, tráfico, errores y saturación.

**Acceptance Scenarios**:

1. **Given** una aplicación está desplegada y recibiendo tráfico, **When** accedo al dashboard de monitoreo, **Then** veo las 4 golden signals actualizadas en los últimos 5 minutos
2. **Given** una aplicación tiene errores HTTP 5xx, **When** consulto el dashboard, **Then** veo el porcentaje de errores claramente visible
3. **Given** quiero ver el historial de una métrica, **When** selecciono un rango de tiempo, **Then** veo la evolución de las golden signals en ese período

---

### User Story 4 - Visualizar Golden Signals por Nodo (Priority: P2)

Como administrador del homelab, quiero ver métricas de cada nodo (CPU, memoria, disco, red) para identificar nodos sobrecargados o con problemas de recursos.

**Why this priority**: Permite planificar capacidad y detectar problemas de recursos antes de que afecten a las aplicaciones.

**Independent Test**: Acceder al dashboard y verificar que cada nodo muestra métricas de recursos actualizadas.

**Acceptance Scenarios**:

1. **Given** el cluster tiene múltiples nodos, **When** accedo al dashboard, **Then** veo métricas de CPU, memoria, disco y red por cada nodo
2. **Given** un nodo tiene uso de CPU > 80%, **When** consulto el dashboard, **Then** el nodo aparece destacado visualmente como en riesgo
3. **Given** un nodo tiene disco > 90% usado, **When** se detecta esta condición, **Then** recibo una alerta preventiva

---

### User Story 5 - Gestionar Notificaciones vía Ntfy (Priority: P3)

Como administrador del homelab, quiero poder suscribirme a las alertas desde cualquier dispositivo usando Ntfy, para recibir notificaciones sin depender de aplicaciones de mensajería.

**Why this priority**: Ntfy es el canal elegido para notificaciones. Debe ser fácil de configurar y usar.

**Independent Test**: Suscribirse a un topic de Ntfy y verificar que las alertas de prueba llegan correctamente.

**Acceptance Scenarios**:

1. **Given** Ntfy está desplegado en el cluster, **When** me suscribo al topic de alertas, **Then** recibo notificaciones push en mi dispositivo
2. **Given** estoy suscrito a alertas, **When** ocurre una alerta crítica, **Then** la notificación incluye prioridad alta y sonido distintivo
3. **Given** quiero recibir alertas en múltiples dispositivos, **When** me suscribo desde cada dispositivo, **Then** todos reciben las mismas alertas

---

### Edge Cases

- ¿Qué sucede si el servicio de notificaciones (Ntfy) está caído cuando ocurre una alerta?
- ¿Cómo se manejan alertas durante mantenimiento planificado (evitar ruido)?
- ¿Qué pasa si el sistema de monitoreo mismo falla?
- ¿Cómo se evita la fatiga de alertas por alertas repetitivas del mismo problema?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Sistema DEBE detectar nodos no disponibles dentro de 60 segundos de la falla
- **FR-002**: Sistema DEBE detectar pods/deployments en estado fallido (CrashLoopBackOff, ImagePullBackOff, etc.)
- **FR-003**: Sistema DEBE enviar notificaciones vía Ntfy con prioridad según severidad de la alerta
- **FR-004**: Sistema DEBE recopilar las 4 golden signals (latencia, tráfico, errores, saturación) por aplicación
- **FR-005**: Sistema DEBE recopilar métricas de recursos (CPU, memoria, disco, red) por nodo
- **FR-006**: Sistema DEBE proporcionar un dashboard visual para consultar métricas en tiempo real
- **FR-007**: Sistema DEBE enviar notificaciones de recuperación cuando un problema se resuelve
- **FR-008**: Sistema DEBE permitir configurar umbrales de alerta personalizados
- **FR-009**: Sistema DEBE agrupar alertas repetitivas para evitar spam de notificaciones
- **FR-010**: Sistema DEBE incluir en cada notificación: tipo de alerta, recurso afectado, timestamp, y enlace al dashboard

### Key Entities

- **Alerta**: Evento que indica una condición anormal (nodo caído, servicio no disponible, umbral excedido)
- **Métrica**: Valor numérico recolectado periódicamente (CPU %, latencia ms, errores/min)
- **Umbral**: Valor límite que dispara una alerta cuando es excedido
- **Notificación**: Mensaje enviado al usuario vía Ntfy cuando se genera una alerta
- **Topic**: Canal de Ntfy al que los usuarios se suscriben para recibir alertas

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El administrador recibe notificación de nodo caído en menos de 2 minutos desde la falla
- **SC-002**: El administrador recibe notificación de servicio no disponible en menos de 5 minutos
- **SC-003**: Las métricas de golden signals están disponibles con un retraso máximo de 1 minuto
- **SC-004**: El dashboard muestra métricas de los últimos 7 días como mínimo
- **SC-005**: Las notificaciones de Ntfy llegan a dispositivos móviles en menos de 30 segundos desde su generación
- **SC-006**: El sistema detecta y alerta sobre el 100% de los nodos caídos y el 95% de los servicios fallidos
- **SC-007**: Las alertas de recuperación se envían dentro de 2 minutos de la resolución del problema

## Assumptions

- El cluster K3s tiene conectividad de red estable para enviar métricas y alertas
- El administrador tiene acceso a un dispositivo móvil o desktop para recibir notificaciones Ntfy
- Los servicios críticos a monitorear son los que están en namespaces de producción (no kube-system)
- El almacenamiento de métricas históricas se limitará a 7-14 días para optimizar recursos del homelab
- Ntfy será desplegado como servicio self-hosted dentro del cluster
- Las alertas de saturación de disco se dispararán al 80% (warning) y 90% (critical)
- Las alertas de CPU se dispararán cuando el uso sostenido supere el 85% por más de 5 minutos
