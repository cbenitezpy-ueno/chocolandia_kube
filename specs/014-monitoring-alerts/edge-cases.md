# Edge Cases: Monitoring & Alerting System

**Feature**: 014-monitoring-alerts
**Date**: 2025-11-22

Este documento responde a los edge cases identificados en spec.md con decisiones de diseño concretas.

---

## 1. ¿Qué sucede si Ntfy está caído cuando ocurre una alerta?

**Decisión**: Alertmanager tiene retry con backoff exponencial (default 10s, max 5m).
Las alertas se encolan y se envían cuando Ntfy vuelve.

**Mitigación adicional**:
- Alert rule `NtfyDown` en `contracts/alert-rules.yaml` dispara si Ntfy no responde por 2 minutos
- Esta alerta se mostraría en Grafana aunque no llegue al móvil
- El administrador puede verificar visualmente el estado en el dashboard

**Configuración relevante**:
```yaml
- alert: NtfyDown
  expr: up{job="ntfy"} == 0
  for: 2m
  labels:
    severity: critical
```

---

## 2. ¿Cómo se manejan alertas durante mantenimiento planificado?

**Decisión**: Usar Alertmanager silences antes del mantenimiento.

**Procedimiento**:
1. Acceder a https://alertmanager.chocolandia.com/#/silences
2. Click "New Silence"
3. Agregar matcher: `node=nodo04` (o el nodo en mantenimiento)
4. Configurar duración del mantenimiento
5. Agregar comentario explicativo

**Ejemplo de silence via API**:
```bash
curl -X POST https://alertmanager.chocolandia.com/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [{"name": "node", "value": "nodo04", "isRegex": false}],
    "startsAt": "2025-11-22T10:00:00Z",
    "endsAt": "2025-11-22T12:00:00Z",
    "createdBy": "admin",
    "comment": "Mantenimiento planificado nodo04"
  }'
```

---

## 3. ¿Qué pasa si el sistema de monitoreo mismo falla?

**Decisión**: Aceptar riesgo parcial dado que es un homelab.

**Mitigaciones implementadas**:
- Prometheus tiene PVC persistente - sobrevive reinicios de pod
- kube-prometheus-stack despliega Alertmanager con configuración persistente
- Si todo el monitoring namespace falla, las alertas no funcionan

**Detección manual**:
- Si no hay actividad de alertas por >1h, verificar manualmente:
  ```bash
  kubectl get pods -n monitoring
  kubectl logs -n monitoring -l app=prometheus --tail=50
  ```

**Mejora futura (no en scope)**:
- Agregar healthcheck externo desde fuera del cluster (e.g., UptimeRobot, Healthchecks.io)

---

## 4. ¿Cómo se evita la fatiga de alertas por alertas repetitivas?

**Decisión**: Configuración de agrupación e inhibición en Alertmanager.

**Configuración aplicada** (en `contracts/alertmanager-config.yaml`):

### Agrupación (reduce spam):
```yaml
route:
  group_wait: 30s       # Esperar antes de enviar primera notificación
  group_interval: 5m    # Agrupar alertas similares
  repeat_interval: 4h   # No repetir la misma alerta antes de 4h
  group_by: ['alertname', 'namespace', 'severity']
```

### Inhibición (supresión inteligente):
```yaml
inhibit_rules:
  # Si NodeDown dispara, suprimir alertas de recursos del mismo nodo
  - source_matchers:
      - alertname = "NodeDown"
    target_matchers:
      - alertname =~ "NodeHigh.*"
    equal: ['instance']
```

**Resultado esperado**:
- Si `nodo04` cae, solo llega 1 alerta `NodeDown`
- No llegan alertas de `NodeHighCPU`, `NodeHighMemory` para ese nodo
- Alertas similares se agrupan en 1 notificación

---

## Resumen de Decisiones

| Edge Case | Decisión | Tarea Relacionada |
|-----------|----------|-------------------|
| Ntfy caído | Retry automático + alerta NtfyDown | T042 |
| Mantenimiento | Silences manuales en Alertmanager | T054 (runbook) |
| Monitoring falla | Aceptar riesgo, verificación manual | N/A |
| Fatiga de alertas | Grouping + inhibition rules | T051, T052 |
