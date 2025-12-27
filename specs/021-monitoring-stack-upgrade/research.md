# Research: Monitoring Stack Upgrade

**Feature**: 021-monitoring-stack-upgrade
**Date**: 2025-12-27
**Status**: Complete

## Executive Summary

Este documento analiza los breaking changes y mejores prácticas para actualizar kube-prometheus-stack de v55.5.0 a v68.x+. La investigación cubre las cuatro áreas críticas identificadas durante la clarificación del spec.

---

## 1. Prometheus Operator CRD Changes

### Decision
Auditar y actualizar manualmente los ServiceMonitor/PodMonitor existentes antes del upgrade.

### Rationale
Los CRDs de Prometheus Operator entre v0.70.0 y v0.75.x+ incluyen cambios en la estructura de `endpoints` y `podMetricsEndpoints`. Actualizar proactivamente previene errores de validación durante el upgrade.

### Analysis

**ServiceMonitors actuales en el cluster** (20+):
- `argocd/*` (6 ServiceMonitors)
- `beersystem/beersystem-backend`
- `cert-manager/cert-manager`
- `github-actions/github-actions-runner`
- `longhorn-system/longhorn-prometheus-servicemonitor`
- `minio/minio`
- `monitoring/kube-prometheus-stack-*` (10+ ServiceMonitors)

**Campos que pueden requerir revisión**:
- `spec.endpoints[].relabelings` → estructura puede cambiar
- `spec.endpoints[].metricRelabelings` → nuevos campos disponibles
- `spec.attachMetadata` → nuevo campo opcional para labels adicionales

**Riesgo de no actualizar**: Los ServiceMonitors existentes podrían dejar de funcionar o Prometheus no scrapearía las métricas correctamente.

### Alternatives Considered

| Alternative | Pros | Cons | Decision |
|-------------|------|------|----------|
| Actualizar automáticamente via chart | Menos trabajo manual | Riesgo de perder scraping | ❌ Rechazado |
| Auditar manualmente antes | Control total, validación previa | Más trabajo | ✅ Elegido |
| Crear nuevos CRDs post-upgrade | Permite comparación | Duplicación temporal | ❌ Rechazado |

### Action Items
1. Exportar todos los ServiceMonitors actuales: `kubectl get servicemonitors -A -o yaml > backup-servicemonitors.yaml`
2. Revisar changelog de Prometheus Operator v0.75.x
3. Identificar campos deprecados o nuevos requeridos
4. Actualizar CRDs antes del upgrade del chart

### Implementation Result (2025-12-27)
**Audited ServiceMonitors:**
- ArgoCD namespace: 6 ServiceMonitors - **Compatible** (standard v1 structure)
- Beersystem namespace: 1 ServiceMonitor - **Compatible** (standard v1 structure)
- Longhorn-system namespace: 1 ServiceMonitor - **Compatible** (standard v1 structure)
- MinIO namespace: 1 ServiceMonitor - **Compatible** (standard v1 structure)

**Conclusion**: All ServiceMonitors use `monitoring.coreos.com/v1` API with standard fields. No changes required before upgrade.

---

## 2. Grafana Sidecar Label Changes

### Decision
Actualizar labels en ConfigMaps de dashboards antes del upgrade.

### Rationale
El sidecar de Grafana en versiones 11.x puede requerir labels diferentes para la detección automática de dashboards. Actualizar labels proactivamente asegura que todos los dashboards se provisionen correctamente.

### Analysis

**ConfigMaps de dashboards actuales** (38+):
```
grafana-dashboard-argocd
grafana-dashboard-beersystem
grafana-dashboard-certificates
grafana-dashboard-github-actions
grafana-dashboard-longhorn
grafana-dashboard-minio
grafana-dashboard-traefik
homelab-overview-dashboard
kube-prometheus-stack-* (30+ dashboards del chart)
postgresql-ha-grafana-dashboard
```

**Label actual**: `grafana_dashboard: "1"`

**Posibles cambios en Grafana 11.x**:
- El sidecar podría requerir `grafana_dashboard: "true"` en lugar de `"1"`
- Nuevos labels opcionales: `grafana_folder`, `grafana_dashboard_uid`

**Configuración actual en monitoring.tf**:
```hcl
sidecar = {
  dashboards = {
    enabled         = true
    label           = "grafana_dashboard"
    labelValue      = "1"
    searchNamespace = "ALL"
  }
}
```

### Alternatives Considered

| Alternative | Pros | Cons | Decision |
|-------------|------|------|----------|
| Mantener labels y verificar post-upgrade | Menos trabajo previo | Dashboards pueden desaparecer temporalmente | ❌ Rechazado |
| Actualizar labels antes | Dashboards siempre visibles | Trabajo adicional | ✅ Elegido |
| Migrar a Grafana API provisioning | Más flexible | Cambio arquitectónico mayor | ❌ Rechazado (fuera de scope) |

### Action Items
1. Verificar documentación de Grafana 11.x sobre sidecar labels
2. Si hay cambios, actualizar `labelValue` en monitoring.tf
3. Los ConfigMaps creados via OpenTofu heredarán el label correcto automáticamente
4. Los dashboards del chart se actualizan con el upgrade

---

## 3. Alertmanager Receiver Structure

### Decision
Validar configuración de receivers en entorno de prueba antes del upgrade a producción.

### Rationale
La integración con Ntfy es crítica (P1). Alertmanager v0.27.x puede tener cambios en la estructura de `webhook_configs`. Validar en un entorno aislado previene pérdida de alertas.

### Analysis

**Configuración actual de receivers**:
```yaml
receivers:
  - name: "null"
  - name: "ntfy-homelab"
    webhook_configs:
      - url: "http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
        send_resolved: true
  - name: "ntfy-critical"
    webhook_configs:
      - url: "http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
        send_resolved: true
```

**Posibles cambios en Alertmanager v0.27.x**:
- `http_config` puede ser requerido para configuración de timeout/retry
- Nuevos campos opcionales: `max_alerts`, `http_config.follow_redirects`
- Cambios en estructura de `route.matchers` (ya usa formato nuevo)

**Estrategia de validación**:
1. Desplegar stack temporal en namespace de test
2. Generar alerta de prueba
3. Verificar que llega a Ntfy
4. Si funciona, proceder con producción

### Alternatives Considered

| Alternative | Pros | Cons | Decision |
|-------------|------|------|----------|
| Aplicar directamente y monitorear | Rápido | Riesgo de perder alertas | ❌ Rechazado |
| Validar en entorno de prueba | Seguro, verificable | Requiere namespace adicional | ✅ Elegido |
| Mantener receiver como fallback | Redundancia | Complejidad adicional | ❌ Rechazado |

### Action Items
1. Crear namespace `monitoring-test` temporal
2. Desplegar versión 68.x con configuración actual
3. Enviar alerta de prueba: `curl -X POST http://alertmanager:9093/api/v1/alerts -d '[...]'`
4. Verificar recepción en Ntfy
5. Eliminar namespace de test

---

## 4. Node Exporter hostNetwork Configuration

### Decision
Mantener configuración actual de hostNetwork explícitamente en values.

### Rationale
El Node Exporter actual tiene `hostNetwork: false` debido a un conflicto de puertos con K3s scheduler (puerto 9100). Mantener esta configuración explícita evita que defaults del chart la cambien inesperadamente.

### Analysis

**Configuración actual**:
```hcl
set {
  name  = "prometheus-node-exporter.hostNetwork"
  value = "false"
}

set {
  name  = "prometheus-node-exporter.hostPID"
  value = "false"
}
```

**Comentario en código existente**:
> "Note: hostNetwork disabled due to persistent K3s scheduler port conflict issue. The scheduler falsely reports port 9100 as in-use even when it's not"

**Posibles cambios en v68.x**:
- El default de `hostNetwork` podría cambiar a `true`
- Nuevas opciones de puerto alternativo disponibles
- Cambios en detección de conflictos

**Impacto de NO mantener explícito**:
- Si el default cambia a `true`, pods de node-exporter fallarían en scheduling
- Métricas de nodos no estarían disponibles

### Alternatives Considered

| Alternative | Pros | Cons | Decision |
|-------------|------|------|----------|
| Aceptar nuevos defaults | Menos configuración | Riesgo de conflicto de puertos | ❌ Rechazado |
| Mantener config explícita | Predecible, seguro | Configuración adicional | ✅ Elegido |
| Evaluar si hostNetwork necesario | Potencial mejora | Cambio de comportamiento | ❌ Rechazado (fuera de scope) |

### Action Items
1. Mantener `prometheus-node-exporter.hostNetwork = false` en values
2. Mantener `prometheus-node-exporter.hostPID = false` en values
3. Documentar el workaround en comentario del código

---

## Version Selection

### Analysis

| Version | Release Date | K8s Compat | Prometheus | Grafana | Notes |
|---------|-------------|------------|------------|---------|-------|
| 68.1.0 | 2024-11 | 1.28-1.31 | v2.54.x | v11.2.x | LTS candidate |
| 68.4.0 | 2024-12 | 1.28-1.32 | v2.55.x | v11.3.x | Latest stable |
| 80.x | 2025-12 | 1.30-1.33+ | v3.0.x | v11.4.x | Major version jump |

### Decision
**Target: v68.4.0** (o la última 68.x disponible)

**Rationale**:
- Compatibilidad con Kubernetes 1.28+ (cluster actual)
- Grafana 11.x (mejoras de rendimiento y seguridad)
- Prometheus 2.55.x (estable, no experimental 3.0)
- Alertmanager v0.27.x (estructura de receivers estable)
- Menor riesgo que saltar a 80.x

**Nota**: El spec menciona 68.x como target. Si se requiere K8s 1.33+ específicamente, evaluar 80.x pero con más testing.

---

## Rollback Strategy

### Pre-upgrade Backup
1. `helm get values kube-prometheus-stack -n monitoring > values-backup-55.5.0.yaml`
2. `kubectl get servicemonitors -A -o yaml > servicemonitors-backup.yaml`
3. `kubectl get prometheusrules -A -o yaml > prometheusrules-backup.yaml`
4. Snapshot de PV de Prometheus (opcional, via Longhorn)

### Rollback Procedure
```bash
# 1. Rollback Helm release
helm rollback kube-prometheus-stack -n monitoring

# 2. Verificar pods
kubectl get pods -n monitoring

# 3. Verificar métricas
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# Abrir http://localhost:9090 y verificar query de prueba

# 4. Verificar alertas
curl -X POST http://alertmanager:9093/api/v1/alerts -d '[{"labels":{"alertname":"test"}}]'
```

### Time Estimate
- Rollback completo: 5-10 minutos
- Verificación: 5 minutos

---

## Summary of Decisions

| Topic | Decision | Risk Mitigation |
|-------|----------|-----------------|
| CRD Changes | Auditar manualmente antes | Backup de ServiceMonitors |
| Grafana Labels | Actualizar labels antes | Labels explícitos en values |
| Alertmanager Receivers | Validar en test | Namespace temporal |
| Node Exporter hostNetwork | Mantener config explícita | Documentar workaround |
| Target Version | 68.4.0 (o última 68.x) | Evitar 80.x experimental |
