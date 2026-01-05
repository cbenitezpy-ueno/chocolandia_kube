# Feature Specification: Paperless-ngx Google Drive Backup

**Feature Branch**: `028-paperless-gdrive-backup`
**Created**: 2026-01-04
**Status**: Draft
**Input**: User description: "Implementar un sistema de backup automatizado para Paperless-ngx que sincronice los documentos y datos a Google Drive usando rclone, ejecutado como CronJob en Kubernetes."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Backup Automático Diario (Priority: P1)

Como administrador del sistema, quiero que mis documentos de Paperless-ngx se respalden automáticamente a Google Drive todos los días, para tener una copia de seguridad fuera del cluster en caso de fallo del storage local.

**Why this priority**: La protección de datos es crítica. Los documentos en Paperless-ngx representan información importante (facturas, contratos, documentos personales) que no puede perderse. Un backup automático es la función principal de esta feature.

**Independent Test**: Se puede verificar completamente ejecutando el CronJob manualmente y confirmando que los archivos aparecen en Google Drive con la estructura correcta.

**Acceptance Scenarios**:

1. **Given** el CronJob está configurado y las credenciales de Google Drive son válidas, **When** se ejecuta el job de backup (automático o manual), **Then** todos los archivos de /data y /media se sincronizan a Google Drive en la carpeta destino configurada.

2. **Given** algunos archivos ya existen en Google Drive de backups anteriores, **When** se ejecuta el backup, **Then** solo se transfieren los archivos nuevos o modificados (sincronización incremental).

3. **Given** el job de backup se ejecuta a la hora programada, **When** no hay cambios en los archivos desde el último backup, **Then** el job completa exitosamente sin transferir datos innecesarios.

---

### User Story 2 - Notificaciones de Estado del Backup (Priority: P2)

Como administrador, quiero recibir una notificación cuando el backup complete exitosamente o falle, para estar informado del estado de mis respaldos sin tener que revisar logs manualmente.

**Why this priority**: Las notificaciones permiten actuar rápidamente ante fallos. Sin embargo, el backup funciona independientemente de las notificaciones, por lo que es secundario a la función principal.

**Independent Test**: Se puede verificar forzando un backup exitoso y uno fallido, y confirmando que las notificaciones llegan al canal ntfy configurado.

**Acceptance Scenarios**:

1. **Given** el backup completa exitosamente, **When** el job termina, **Then** se envía una notificación a ntfy indicando éxito, duración del backup y cantidad de archivos sincronizados.

2. **Given** el backup falla por cualquier razón (credenciales inválidas, Google Drive lleno, timeout), **When** el job termina con error, **Then** se envía una notificación a ntfy indicando el fallo y el mensaje de error.

---

### User Story 3 - Restauración desde Backup (Priority: P3)

Como administrador, quiero poder restaurar mis documentos desde Google Drive al cluster, para recuperar datos en caso de pérdida del storage local.

**Why this priority**: La restauración es menos frecuente que el backup pero es esencial para que el sistema de backup tenga valor. Es la validación final de que el backup es útil.

**Independent Test**: Se puede verificar eliminando archivos de prueba del PVC local, ejecutando el proceso de restauración, y confirmando que los archivos se recuperan correctamente.

**Acceptance Scenarios**:

1. **Given** existen backups válidos en Google Drive, **When** el administrador ejecuta el proceso de restauración, **Then** los archivos se descargan y colocan en los PVCs correctos (/data y /media).

2. **Given** el administrador necesita restaurar solo ciertos archivos, **When** especifica filtros o rutas específicas, **Then** solo se restauran los archivos indicados sin afectar otros datos existentes.

---

### Edge Cases

- **Google Drive lleno**: El job falla y envía notificación indicando falta de espacio. Se recomienda monitorear el espacio disponible.
- **Credenciales OAuth expiradas**: El job falla con error de autenticación. Se necesita regenerar el token OAuth (proceso manual documentado).
- **Backup excede timeout de 2 horas**: El job se termina por timeout. Se envía notificación de fallo. Se puede ajustar el timeout o ejecutar en horarios de menor actividad.
- **Cluster caído durante ventana de backup**: El CronJob no se ejecuta. El siguiente backup programado sincronizará los cambios acumulados.
- **Archivo borrado accidentalmente en Paperless**: El archivo se moverá a la papelera de Google Drive (no se borra permanentemente) gracias a la política de retención con trash.
- **Conflicto de acceso al PVC**: El CronJob monta los PVCs en modo solo lectura, evitando conflictos con el pod de Paperless.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Sistema DEBE ejecutar backups automáticamente según un schedule configurable (por defecto diario a las 3:00 AM).
- **FR-002**: Sistema DEBE realizar sincronización incremental, transfiriendo solo archivos nuevos o modificados.
- **FR-003**: Sistema DEBE respaldar el directorio /data (configuración y base de datos SQLite).
- **FR-004**: Sistema DEBE respaldar el directorio /media (documentos originales y procesados por OCR).
- **FR-005**: Sistema DEBE almacenar credenciales de Google Drive en un Kubernetes Secret, nunca en código o ConfigMaps.
- **FR-006**: Sistema DEBE mover archivos eliminados a la papelera de Google Drive en lugar de borrarlos permanentemente.
- **FR-007**: Sistema DEBE enviar notificación a ntfy cuando el backup complete (éxito o fallo).
- **FR-008**: Sistema DEBE limitar el consumo de recursos a máximo 512Mi RAM y 500m CPU.
- **FR-009**: Sistema DEBE terminar el job si excede 2 horas de ejecución (timeout configurable).
- **FR-010**: Sistema DEBE permitir ejecutar el backup manualmente además del schedule automático.
- **FR-011**: Sistema DEBE proporcionar documentación para configurar credenciales OAuth de Google Drive.
- **FR-012**: Sistema DEBE proporcionar instrucciones de restauración desde backup.

### Key Entities

- **CronJob de Backup**: Recurso de Kubernetes que ejecuta el contenedor rclone según schedule. Contiene configuración de recursos, timeout, y montajes de volúmenes.
- **Secret de Credenciales**: Almacena la configuración de rclone con tokens OAuth de Google Drive. Se crea manualmente después de autenticación inicial.
- **PVC Data**: Volumen persistente con configuración de Paperless (5Gi). Montado en solo lectura por el job de backup.
- **PVC Media**: Volumen persistente con documentos (40Gi). Montado en solo lectura por el job de backup.
- **Carpeta de Google Drive**: Destino del backup. Estructura: `Paperless-Backup/data/` y `Paperless-Backup/media/`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Backups automáticos se ejecutan diariamente sin intervención manual durante al menos 30 días consecutivos.
- **SC-002**: Tiempo de backup incremental (sin cambios) completa en menos de 5 minutos.
- **SC-003**: Sincronización de 1GB de archivos nuevos completa en menos de 30 minutos (depende de conexión a internet).
- **SC-004**: 100% de los archivos en PVCs locales tienen copia correspondiente en Google Drive después de backup exitoso.
- **SC-005**: Notificaciones de éxito/fallo llegan a ntfy en menos de 1 minuto después de completar el job.
- **SC-006**: Restauración completa de datos (5Gi data + 40Gi media) es posible siguiendo la documentación proporcionada.
- **SC-007**: Archivos eliminados localmente permanecen recuperables desde papelera de Google Drive por al menos 30 días.

## Assumptions

- El usuario ya tiene una cuenta de Google con suficiente espacio en Google Drive (mínimo 50GB recomendado).
- El cluster tiene acceso a internet para conectar con Google Drive API.
- El namespace `paperless` ya existe con los PVCs `paperless-data` y `paperless-media` creados y en uso.
- El servicio ntfy está desplegado y accesible en `http://ntfy.ntfy.svc.cluster.local/homelab-alerts`.
- Los PVCs de Paperless soportan montaje simultáneo en modo solo lectura (ReadOnlyMany) o el CronJob se ejecutará cuando Paperless tenga bajo uso.
- El usuario configurará manualmente las credenciales OAuth de Google Drive siguiendo la documentación (requiere acceso a navegador web).

## Out of Scope

- Backup de la base de datos PostgreSQL (Paperless usa PostgreSQL como DB principal, pero el backup de DB se maneja por separado).
- Cifrado adicional de datos antes de subir a Google Drive (Google Drive ya cifra datos en reposo).
- Múltiples destinos de backup (solo Google Drive).
- Interfaz web para gestionar backups (se gestiona via kubectl/OpenTofu).
- Backup en tiempo real o continuo (solo backup programado).
- Compresión de archivos antes de backup (rclone sube archivos tal cual).
