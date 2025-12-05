# Feature Specification: Govee2MQTT Integration

**Feature Branch**: `019-govee2mqtt`
**Created**: 2025-12-04
**Status**: Draft
**Input**: User description: "quiero integrar home-assistant con mis dispositivos govee encontre https://github.com/wez/govee2mqtt podes configurar eso?"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Control Local de Dispositivos Govee (Priority: P1)

Como usuario de Home Assistant con dispositivos Govee, quiero controlarlos localmente desde mi dashboard de Home Assistant para encender/apagar luces y cambiar colores sin depender de la nube de Govee.

**Why this priority**: Es la funcionalidad core - sin esto no hay integración. El control local proporciona menor latencia y funcionalidad offline.

**Independent Test**: Puede probarse encendiendo/apagando una luz Govee desde Home Assistant y verificando que responde en menos de 2 segundos.

**Acceptance Scenarios**:

1. **Given** govee2mqtt está desplegado y configurado, **When** el usuario enciende una luz Govee desde Home Assistant, **Then** la luz se enciende en menos de 2 segundos
2. **Given** una luz Govee está encendida, **When** el usuario cambia el color desde Home Assistant, **Then** la luz cambia al color seleccionado
3. **Given** la conexión a internet está caída, **When** el usuario controla un dispositivo con soporte LAN, **Then** el dispositivo responde normalmente vía red local

---

### User Story 2 - Descubrimiento Automático de Dispositivos (Priority: P2)

Como usuario, quiero que mis dispositivos Govee aparezcan automáticamente en Home Assistant después de configurar govee2mqtt, sin necesidad de configuración manual por dispositivo.

**Why this priority**: Mejora significativamente la experiencia de usuario al eliminar configuración manual repetitiva.

**Independent Test**: Después de desplegar govee2mqtt con credenciales válidas, verificar que los dispositivos aparecen en Home Assistant en menos de 5 minutos.

**Acceptance Scenarios**:

1. **Given** govee2mqtt tiene credenciales API válidas, **When** se inicia el servicio, **Then** los dispositivos compatibles aparecen automáticamente en Home Assistant
2. **Given** un nuevo dispositivo Govee se añade a la cuenta, **When** govee2mqtt se reinicia, **Then** el nuevo dispositivo aparece en Home Assistant

---

### User Story 3 - Monitoreo de Estado en Tiempo Real (Priority: P3)

Como usuario, quiero ver el estado actual de mis dispositivos Govee en Home Assistant (encendido/apagado, color actual, brillo) actualizado en tiempo real.

**Why this priority**: Proporciona feedback visual importante pero no es crítico para el control básico.

**Independent Test**: Cambiar el estado de un dispositivo Govee desde la app móvil de Govee y verificar que el cambio se refleja en Home Assistant.

**Acceptance Scenarios**:

1. **Given** un dispositivo Govee está controlado externamente (app Govee), **When** el estado cambia, **Then** Home Assistant refleja el cambio en menos de 5 segundos
2. **Given** govee2mqtt está funcionando, **When** el usuario consulta el estado de un dispositivo, **Then** ve el estado actual real del dispositivo

---

### Edge Cases

- ¿Qué sucede cuando un dispositivo Govee no soporta control LAN? → Se usa fallback a API de nube
- ¿Qué sucede cuando las credenciales API son inválidas? → El servicio reporta error y dispositivos no aparecen
- ¿Qué sucede si el broker MQTT no está disponible? → El servicio se reinicia hasta que MQTT esté disponible
- ¿Qué sucede con dispositivos Govee no soportados? → Se ignoran silenciosamente con log informativo

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Sistema DEBE desplegar govee2mqtt como contenedor en el cluster Kubernetes existente
- **FR-002**: Sistema DEBE conectarse al broker MQTT del cluster para comunicación con Home Assistant
- **FR-003**: Sistema DEBE almacenar credenciales de Govee (API key y/o email/password) de forma segura en Kubernetes Secrets
- **FR-004**: Sistema DEBE intentar control LAN primero antes de usar API de nube para menor latencia
- **FR-005**: Sistema DEBE auto-descubrir dispositivos Govee asociados a las credenciales configuradas
- **FR-006**: Sistema DEBE exponer métricas de funcionamiento para monitoreo (opcional, si govee2mqtt las soporta)
- **FR-007**: Sistema DEBE persistir estado de caché para evitar re-descubrimiento en cada reinicio

### Key Entities

- **Govee Device**: Dispositivo físico Govee (luces, sensores) identificado por SKU y device ID
- **MQTT Broker**: Servicio de mensajería que conecta govee2mqtt con Home Assistant
- **Govee Credentials**: API Key de desarrollador y/o credenciales de cuenta Govee
- **Device State**: Estado actual del dispositivo (on/off, color, brillo, modo)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Dispositivos Govee aparecen automáticamente en Home Assistant en menos de 5 minutos después del despliegue
- **SC-002**: Control de dispositivos responde en menos de 2 segundos para dispositivos con soporte LAN
- **SC-003**: El servicio se recupera automáticamente de reinicios sin pérdida de configuración
- **SC-004**: 100% de los dispositivos Govee compatibles de la cuenta son descubiertos
- **SC-005**: El sistema funciona sin conexión a internet para dispositivos con soporte LAN

## Assumptions

- El cluster ya tiene un broker MQTT desplegado (si no existe, se desplegará como dependencia)
- Home Assistant ya está configurado con la integración MQTT habilitada
- El usuario tiene acceso a su Govee API Key (obtenible desde la app Govee → Perfil → About Us → Apply for API Key)
- Los dispositivos Govee están en la misma red LAN que el cluster para control local
- Se usará la imagen Docker oficial de govee2mqtt (ghcr.io/wez/govee2mqtt)
