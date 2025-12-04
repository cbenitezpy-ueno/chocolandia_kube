# Research: Govee2MQTT Integration

**Feature**: 019-govee2mqtt
**Date**: 2025-12-04

## Research Topics

### 1. MQTT Broker Selection

**Decision**: Eclipse Mosquitto

**Rationale**:
- Broker MQTT más popular y probado en producción
- Imagen Docker oficial liviana (~12MB)
- Soporta MQTT v3.1, v3.1.1 y v5.0
- Configuración simple via archivo mosquitto.conf
- Amplia documentación y comunidad
- Compatible con Home Assistant MQTT integration

**Alternatives Considered**:

| Broker | Pros | Cons | Decision |
|--------|------|------|----------|
| Mosquitto | Ligero, estándar, probado | Single instance (no HA nativo) | **Selected** |
| EMQX | HA nativo, dashboard | Más complejo, overkill para homelab | Rejected |
| HiveMQ | Enterprise features | Licencia comercial para features avanzados | Rejected |
| VerneMQ | Clustering nativo | Menos documentación, comunidad pequeña | Rejected |

### 2. Govee2MQTT Configuration

**Decision**: Deployment con hostNetwork + credenciales en Secret

**Rationale**:
- `hostNetwork: true` es **requerido** para descubrimiento LAN de dispositivos Govee
- govee2mqtt usa multicast/broadcast para encontrar dispositivos en la red local
- Sin hostNetwork, el pod está aislado y no puede descubrir dispositivos

**Configuration Requirements**:

| Variable | Required | Description |
|----------|----------|-------------|
| GOVEE_API_KEY | Yes | API key para acceso a Govee Platform API |
| GOVEE_EMAIL | Recommended | Email de cuenta Govee para IoT features |
| GOVEE_PASSWORD | Recommended | Password de cuenta Govee |
| GOVEE_MQTT_HOST | Yes | Hostname del broker MQTT |
| GOVEE_MQTT_PORT | Yes | Puerto MQTT (default: 1883) |
| TZ | Yes | Timezone (America/Asuncion) |

### 3. Network Architecture

**Decision**: Colocación en namespace `home-assistant`

**Rationale**:
- Home Assistant ya existe en namespace `home-assistant`
- Mosquitto y govee2mqtt se despliegan en el mismo namespace
- Comunicación MQTT intra-namespace via ClusterIP (mosquitto.home-assistant.svc.cluster.local)
- govee2mqtt con hostNetwork para descubrimiento LAN

**Network Flow**:
```
[Govee Devices] <-- LAN --> [govee2mqtt (hostNetwork)] <-- MQTT --> [Mosquitto] <-- MQTT --> [Home Assistant]
```

### 4. Storage Requirements

**Decision**: PVC opcional para govee2mqtt, PVC recomendado para Mosquitto

**Rationale**:
- govee2mqtt: Caché de dispositivos se reconstruye rápidamente, PVC opcional
- Mosquitto: Persistencia de mensajes QoS 1/2 y suscripciones, PVC recomendado para estabilidad

| Component | Storage | Size | Reason |
|-----------|---------|------|--------|
| Mosquitto | PVC | 1Gi | Persistencia de mensajes y state |
| govee2mqtt | None (emptyDir) | N/A | Cache reconstruible, no crítico |

### 5. Home Assistant MQTT Integration

**Decision**: Configuración manual post-despliegue

**Rationale**:
- Home Assistant MQTT integration se configura via UI
- govee2mqtt usa MQTT discovery (auto-configuración de dispositivos)
- Una vez MQTT integration está configurada, dispositivos Govee aparecen automáticamente

**Setup Steps**:
1. Desplegar Mosquitto
2. Desplegar govee2mqtt
3. En Home Assistant UI: Settings → Devices & Services → Add Integration → MQTT
4. Configurar broker: `mosquitto.home-assistant.svc.cluster.local:1883`
5. Dispositivos Govee aparecen automáticamente via MQTT discovery

### 6. Security Considerations

**Decision**: Mosquitto sin autenticación (internal cluster), Secrets para Govee credentials

**Rationale**:
- Mosquitto expuesto solo internamente (ClusterIP, no LoadBalancer)
- Autenticación MQTT añade complejidad innecesaria para comunicación intra-cluster
- Credenciales Govee en Kubernetes Secret (no hardcoded)

**Security Measures**:
- Mosquitto: ClusterIP only, no external exposure
- Govee credentials: Kubernetes Secret
- govee2mqtt: hostNetwork limitado al pod específico
- Namespace isolation: Solo home-assistant namespace

## Dependencies

| Dependency | Version | Source |
|------------|---------|--------|
| Eclipse Mosquitto | 2.0.x | eclipse-mosquitto:latest |
| govee2mqtt | latest | ghcr.io/wez/govee2mqtt:latest |
| Home Assistant | existing | Already deployed in cluster |

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| hostNetwork security exposure | Medium | Pod runs in dedicated namespace, minimal privileges |
| Govee API rate limiting | Low | govee2mqtt handles rate limiting internally |
| MQTT broker single point of failure | Low | Simple restart, no HA needed for homelab |
| Device discovery failure | Medium | Verify network connectivity, check Govee LAN API enabled on devices |

## References

- [govee2mqtt GitHub](https://github.com/wez/govee2mqtt)
- [govee2mqtt Docker docs](https://github.com/wez/govee2mqtt/blob/main/docs/DOCKER.md)
- [Eclipse Mosquitto](https://mosquitto.org/)
- [Home Assistant MQTT Integration](https://www.home-assistant.io/integrations/mqtt/)
- [Mosquitto Helm Charts](https://artifacthub.io/packages/helm/t3n/mosquitto)
