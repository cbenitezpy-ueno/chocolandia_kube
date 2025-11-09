# [SECURITY HIGH] K3s cluster without audit logging enabled

**Labels:** `security`, `high`, `priority:medium`, `compliance`, `observability`

## ⚠️ Vulnerabilidad Alta: Sin Auditoría de Logs

### Descripción
El cluster K3s no tiene audit logging habilitado, lo que imposibilita el rastreo de accesos administrativos, cambios en el cluster y actividad sospechosa.

### Estado Actual
**Audit logs:** ❌ Deshabilitado
**API Server logs:** ✅ Disponible vía `journalctl -u k3s`
**Event logs:** ✅ `kubectl get events`
**Compliance:** ❌ No cumple estándares (CIS, SOC2, PCI-DSS)

### Riesgo
- **Nivel:** ALTO
- **Impacto:** Alto - Sin trazabilidad de acciones
- **Probabilidad:** Alta - Imposible detectar brechas sin logs

#### ¿Qué NO Podemos Ver Sin Audit Logs?
1. ❌ Quién ejecutó `kubectl delete`
2. ❌ Quién modificó secrets
3. ❌ Intentos de acceso no autorizado
4. ❌ Cambios en RBAC (roles, rolebindings)
5. ❌ Accesos a la API desde IPs sospechosas
6. ❌ Escalación de privilegios
7. ❌ Creación/modificación de recursos críticos

### Impacto
- **Detección tardía de brechas:** Sin logs, no sabemos qué pasó
- **Análisis forense imposible:** No hay evidencia de actividad maliciosa
- **Compliance:** No cumple con regulaciones (GDPR, SOC2, PCI-DSS)
- **Responsabilidad:** No se puede atribuir acciones a usuarios específicos
- **Troubleshooting:** Difícil debuggear problemas de permisos

### Solución: Habilitar Audit Logging

#### Paso 1: Crear Audit Policy
```bash
# En master1
sudo mkdir -p /etc/rancher/k3s

sudo tee /etc/rancher/k3s/audit-policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # No auditar requests de read-only a ciertos recursos
  - level: None
    verbs: ["get", "list", "watch"]
    resources:
      - group: ""
        resources: ["endpoints", "services", "services/status"]

  # No auditar health checks
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: ""
        resources: ["endpoints", "services"]

  # No auditar sistema interno de K8s
  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get"]
    resources:
      - group: ""
        resources: ["nodes", "nodes/status"]

  # Auditar metadata para requests normales
  - level: Metadata
    resources:
      - group: ""
        resources: ["pods/log", "pods/status"]

  # RequestResponse level para secrets (captura todo)
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]

  # RequestResponse para cambios en RBAC
  - level: RequestResponse
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: "rbac.authorization.k8s.io"

  # RequestResponse para recursos críticos
  - level: RequestResponse
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: ""
        resources: ["namespaces", "serviceaccounts"]
      - group: "apps"
        resources: ["deployments", "daemonsets", "statefulsets"]

  # Metadata level para todo lo demás
  - level: Metadata
    omitStages:
      - RequestReceived
EOF

sudo chmod 600 /etc/rancher/k3s/audit-policy.yaml
```

#### Paso 2: Configurar K3s para Usar Audit Policy
```bash
# Opción A: Usar archivo de configuración (RECOMENDADO)
sudo tee /etc/rancher/k3s/config.yaml <<'EOF'
# Audit logging configuration
kube-apiserver-arg:
  - audit-log-path=/var/log/k3s/audit.log
  - audit-policy-file=/etc/rancher/k3s/audit-policy.yaml
  - audit-log-maxage=30      # Retener logs 30 días
  - audit-log-maxbackup=10   # Mantener 10 archivos de backup
  - audit-log-maxsize=100    # Rotar cuando alcance 100MB
  - audit-log-format=json    # Formato JSON para parsing
EOF

# Opción B: Modificar servicio directamente
# (Solo si config.yaml no funciona)
sudo systemctl edit k3s.service
# Agregar en [Service]:
# Environment="K3S_KUBE_APISERVER_ARG=--audit-log-path=/var/log/k3s/audit.log"
# Environment="K3S_KUBE_APISERVER_ARG=--audit-policy-file=/etc/rancher/k3s/audit-policy.yaml"
```

#### Paso 3: Crear Directorio de Logs
```bash
sudo mkdir -p /var/log/k3s
sudo chown root:root /var/log/k3s
sudo chmod 755 /var/log/k3s
```

#### Paso 4: Reiniciar K3s
```bash
sudo systemctl restart k3s

# Verificar que inició correctamente
sudo systemctl status k3s

# Verificar que audit logs se están generando
sudo ls -lh /var/log/k3s/audit.log
sudo tail -f /var/log/k3s/audit.log
```

#### Paso 5: Integrar con Terraform
```hcl
# En terraform/modules/k3s-node/scripts/install-k3s-server.sh
# Después de la instalación de K3s (línea ~120)

log "Configuring audit logging..."

# Create audit policy
sudo tee /etc/rancher/k3s/audit-policy.yaml <<'POLICY'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # [Contenido completo de arriba]
POLICY

# Create K3s config
sudo tee /etc/rancher/k3s/config.yaml <<'CONFIG'
kube-apiserver-arg:
  - audit-log-path=/var/log/k3s/audit.log
  - audit-policy-file=/etc/rancher/k3s/audit-policy.yaml
  - audit-log-maxage=30
  - audit-log-maxbackup=10
  - audit-log-maxsize=100
  - audit-log-format=json
CONFIG

# Create log directory
sudo mkdir -p /var/log/k3s
sudo chmod 755 /var/log/k3s

# Restart K3s to apply
sudo systemctl restart k3s

log "Audit logging configured successfully"
```

### Verificación y Testing

#### 1. Verificar que Audit Logs Funcionan
```bash
# Ejecutar acción auditada
kubectl create namespace test-audit
kubectl delete namespace test-audit

# Verificar en audit log
sudo tail /var/log/k3s/audit.log | jq

# Buscar evento específico
sudo cat /var/log/k3s/audit.log | \
  jq 'select(.verb == "delete" and .objectRef.resource == "namespaces")'
```

#### 2. Ejemplo de Audit Log Entry
```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "Metadata",
  "auditID": "8c9e1234-5678-90ab-cdef-1234567890ab",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/test-audit",
  "verb": "create",
  "user": {
    "username": "admin",
    "groups": ["system:masters", "system:authenticated"]
  },
  "sourceIPs": ["192.168.4.200"],
  "userAgent": "kubectl/v1.28.3",
  "objectRef": {
    "resource": "namespaces",
    "name": "test-audit",
    "apiVersion": "v1"
  },
  "responseStatus": {
    "metadata": {},
    "code": 201
  },
  "requestReceivedTimestamp": "2025-01-09T10:30:00.123456Z",
  "stageTimestamp": "2025-01-09T10:30:00.234567Z"
}
```

### Análisis de Audit Logs

#### Queries Útiles con jq
```bash
# Top 10 usuarios más activos
sudo cat /var/log/k3s/audit.log | \
  jq -r '.user.username' | sort | uniq -c | sort -rn | head -10

# Todas las eliminaciones (deletes)
sudo cat /var/log/k3s/audit.log | \
  jq 'select(.verb == "delete")' | \
  jq -r '[.requestReceivedTimestamp, .user.username, .objectRef.resource, .objectRef.name] | @tsv'

# Accesos fallidos (401, 403)
sudo cat /var/log/k3s/audit.log | \
  jq 'select(.responseStatus.code >= 400 and .responseStatus.code < 500)'

# Modificaciones a secrets
sudo cat /var/log/k3s/audit.log | \
  jq 'select(.objectRef.resource == "secrets" and (.verb == "create" or .verb == "update" or .verb == "patch" or .verb == "delete"))'

# Accesos desde IPs externas (no del cluster)
sudo cat /var/log/k3s/audit.log | \
  jq 'select(.sourceIPs[0] | startswith("192.168.4") | not)'
```

### Integración con Prometheus/Grafana

#### Usar promtail para enviar logs a Loki
```yaml
# Deploy promtail para scraping de audit logs
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: monitoring
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    clients:
      - url: http://loki:3100/loki/api/v1/push

    scrape_configs:
      - job_name: k3s-audit
        static_configs:
          - targets:
              - localhost
            labels:
              job: k3s-audit
              __path__: /var/log/k3s/audit.log
        pipeline_stages:
          - json:
              expressions:
                verb: verb
                user: user.username
                resource: objectRef.resource
          - labels:
              verb:
              user:
              resource:
```

### Rotación de Logs

Los parámetros configurados ya incluyen rotación automática:
- `audit-log-maxage=30`: Retiene 30 días
- `audit-log-maxbackup=10`: Mantiene 10 archivos de backup
- `audit-log-maxsize=100`: Rota al alcanzar 100MB

**Archivos generados:**
```
/var/log/k3s/audit.log           # Actual
/var/log/k3s/audit.log.1         # Backup 1
/var/log/k3s/audit.log.2         # Backup 2
...
/var/log/k3s/audit.log.10        # Backup 10
```

### Backups de Audit Logs
```bash
# Agregar a backup-cluster.sh
log "Backing up audit logs..."
AUDIT_BACKUP_DIR="$BACKUP_DIR/audit-logs-$TIMESTAMP"
mkdir -p "$AUDIT_BACKUP_DIR"

ssh -o StrictHostKeyChecking=accept-new -i "$SSH_KEY" \
  "$SSH_USER@$MASTER_IP" \
  "sudo tar -czf /tmp/audit-logs.tar.gz -C /var/log/k3s ."

scp -o StrictHostKeyChecking=accept-new -i "$SSH_KEY" \
  "$SSH_USER@$MASTER_IP:/tmp/audit-logs.tar.gz" \
  "$AUDIT_BACKUP_DIR/"

ssh -o StrictHostKeyChecking=accept-new -i "$SSH_KEY" \
  "$SSH_USER@$MASTER_IP" \
  "sudo rm -f /tmp/audit-logs.tar.gz"

success "Audit logs backed up to: $AUDIT_BACKUP_DIR"
```

### Referencias
- [Kubernetes Auditing](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [K3s Server Configuration](https://docs.k3s.io/reference/server-config)
- CIS Benchmark: 1.2.19 - Ensure that the --audit-log-path argument is set
- CIS Benchmark: 1.2.20 - Ensure that the --audit-log-maxage argument is set to 30 or as appropriate

### Prioridad
- [x] Fase 2: Corto Plazo (1-2 semanas)
- [ ] Compliance requirement para producción
- [ ] Esencial para detección de intrusiones

### Checklist
- [ ] Crear audit-policy.yaml
- [ ] Modificar install-k3s-server.sh para configurar audit logging
- [ ] Crear directorio /var/log/k3s
- [ ] Testing en cluster de desarrollo
- [ ] Verificar que logs se generan correctamente
- [ ] Documentar queries útiles de análisis
- [ ] Agregar backup de audit logs a backup-cluster.sh
- [ ] (Opcional) Integrar con Loki/Promtail para visualización en Grafana
- [ ] Crear alertas para eventos críticos (deletes de secrets, etc.)

### Alertas Recomendadas
```yaml
# Prometheus alerting rules para audit events
- alert: SecretDeleted
  expr: increase(apiserver_audit_event_total{verb="delete",objectRef_resource="secrets"}[5m]) > 0
  annotations:
    summary: "Secret was deleted"

- alert: UnauthorizedAccess
  expr: increase(apiserver_audit_event_total{responseStatus_code=~"403|401"}[5m]) > 10
  annotations:
    summary: "Multiple unauthorized access attempts"
```

### Relacionado
- Issue #9 - Sin RBAC granular (dificil auditar sin roles específicos)
- Monitoring stack (Prometheus/Grafana) - Ya desplegado
- Docs: Security monitoring and incident response
