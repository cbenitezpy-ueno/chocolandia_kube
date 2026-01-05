# Research: Paperless-ngx Google Drive Backup

**Feature**: 028-paperless-gdrive-backup
**Date**: 2026-01-04

## Research Questions

### 1. PVC Access Strategy (CRITICAL)

**Problem**: Los PVCs de Paperless son ReadWriteOnce (RWO) y están montados por el Deployment. ¿Cómo puede un CronJob acceder a los datos?

**Decision**: Mount read-only con pod affinity

**Rationale**: Kubernetes permite que múltiples pods monten el mismo PVC RWO si:
- Están en el mismo nodo (same `kubernetes.io/hostname`)
- Al menos uno monta como `readOnly: true`

El CronJob usará `podAffinity` para schedulear en el mismo nodo que Paperless, y montará los PVCs con `readOnly: true`.

**Alternatives considered**:

| Alternativa | Pros | Cons | Rechazada porque |
|-------------|------|------|------------------|
| Scale deployment a 0 | Acceso exclusivo garantizado | Downtime de Paperless | Inaceptable para servicio 24/7 |
| hostPath directo | Simple | Acoplado al nodo específico, no portable | Rompe abstracción de PVC |
| Sidecar en Deployment | Sin conflictos de acceso | Aumenta complejidad del Deployment, siempre consume recursos | Over-engineering |
| Snapshots de Longhorn | Point-in-time consistency | No tenemos Longhorn, usamos local-path | No disponible |

**Implementation**:
```yaml
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: paperless-ngx
        topologyKey: kubernetes.io/hostname
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: paperless-ngx-data
  - name: media
    persistentVolumeClaim:
      claimName: paperless-ngx-media
  containers:
  - volumeMounts:
    - name: data
      mountPath: /data
      readOnly: true
    - name: media
      mountPath: /media
      readOnly: true
```

---

### 2. rclone OAuth Configuration

**Problem**: ¿Cómo configurar rclone para Google Drive en un ambiente headless (sin browser)?

**Decision**: Pre-configurar rclone.conf localmente, almacenar en Kubernetes Secret

**Rationale**:
- El flujo OAuth de Google Drive requiere browser para autorización inicial
- No es práctico usar `rclone authorize` dentro del cluster
- La configuración se genera una vez en la máquina local y se copia al Secret

**Proceso de setup** (documentado en quickstart.md):

1. En máquina local con browser:
   ```bash
   rclone config
   # Crear remote llamado "gdrive" tipo "drive"
   # Completar OAuth flow en browser
   ```

2. Extraer contenido de `~/.config/rclone/rclone.conf`

3. Crear Secret en Kubernetes:
   ```bash
   kubectl create secret generic rclone-config \
     -n paperless \
     --from-file=rclone.conf=$HOME/.config/rclone/rclone.conf
   ```

**Formato del rclone.conf**:
```ini
[gdrive]
type = drive
scope = drive
token = {"access_token":"...","token_type":"Bearer","refresh_token":"...","expiry":"..."}
root_folder_id =
```

**Nota sobre tokens**: rclone auto-renueva tokens expirados usando el `refresh_token`. El archivo debe ser **writable** para que rclone pueda actualizarlo. Solución: copiar Secret a `/tmp/rclone.conf` al inicio del job.

---

### 3. rclone sync vs copy

**Problem**: ¿Usar `rclone sync` (mirror exacto) o `rclone copy` (solo agregar)?

**Decision**: `rclone sync` con `--backup-dir` para archivos eliminados

**Rationale**:
- `sync` mantiene el destino igual al origen (limpia archivos huérfanos)
- `--backup-dir` mueve archivos eliminados en lugar de borrarlos permanentemente
- Combina eficiencia de espacio con seguridad de retención

**Comando final**:
```bash
rclone sync /data gdrive:/Paperless-Backup/data \
  --backup-dir gdrive:/Paperless-Backup/.deleted/data-$(date +%Y%m%d) \
  --checksum \
  --verbose

rclone sync /media gdrive:/Paperless-Backup/media \
  --backup-dir gdrive:/Paperless-Backup/.deleted/media-$(date +%Y%m%d) \
  --checksum \
  --verbose
```

**Alternatives considered**:

| Estrategia | Espacio usado | Retención | Rechazada porque |
|------------|---------------|-----------|------------------|
| `rclone copy` simple | Crece indefinidamente | Todo siempre | Sin cleanup, llena Drive |
| `rclone sync` sin backup-dir | Mínimo | Nada | Pérdida de archivos borrados accidentalmente |
| Snapshots por fecha | Alto (duplicados) | Explícito | Ineficiente para 40GB de media |

---

### 4. Estructura de carpetas en Google Drive

**Decision**: Estructura plana con subcarpeta para deleted

```
Google Drive/
└── Paperless-Backup/
    ├── data/                    # Sync actual de /data
    │   ├── db.sqlite3
    │   └── ...
    ├── media/                   # Sync actual de /media
    │   ├── documents/
    │   └── ...
    └── .deleted/                # Archivos borrados (retención)
        ├── data-20260104/
        └── media-20260104/
```

**Rationale**:
- Navegación simple en Google Drive UI
- `.deleted` agrupa archivos borrados por fecha
- Fácil cleanup manual de backups antiguos

---

### 5. Notificaciones a ntfy

**Decision**: Usar curl en el script de backup

**Implementación**:
```bash
# Al final del backup (éxito)
curl -d "Paperless backup completed: $FILES_SYNCED files, $DURATION" \
  http://ntfy.ntfy.svc.cluster.local/homelab-alerts

# En caso de error
curl -d "Paperless backup FAILED: $ERROR_MESSAGE" \
  -H "Priority: high" \
  -H "Tags: warning" \
  http://ntfy.ntfy.svc.cluster.local/homelab-alerts
```

**Nota**: ntfy requiere autenticación. Reusar patrón de 026-ntfy-homepage-alerts:
- User: alertmanager (ya existe)
- Password: Secret `ntfy-alertmanager-password` en namespace monitoring

---

### 6. Imagen de container

**Decision**: `rclone/rclone:latest` con curl instalado

**Problem**: La imagen oficial de rclone no incluye curl para notificaciones.

**Solución**: Usar imagen base y agregar curl en runtime:
```bash
# En el script de backup
apk add --no-cache curl  # Alpine-based image
```

O crear imagen personalizada (over-engineering para este caso).

---

### 7. Timeout y recursos

**Decision**:
- Timeout: 2 horas (7200 segundos)
- CPU: 500m request, 1000m limit
- Memory: 256Mi request, 512Mi limit

**Rationale**:
- rclone es CPU-intensive durante checksums
- 40GB media puede tomar tiempo en conexiones lentas
- 2 horas es generoso pero evita jobs colgados

**OpenTofu**:
```hcl
resource "kubernetes_cron_job_v1" "backup" {
  spec {
    job_template {
      spec {
        active_deadline_seconds = 7200  # 2 hour timeout

        template {
          spec {
            container {
              resources {
                requests = {
                  cpu    = "500m"
                  memory = "256Mi"
                }
                limits = {
                  cpu    = "1000m"
                  memory = "512Mi"
                }
              }
            }
          }
        }
      }
    }
  }
}
```

---

## Summary of Decisions

| Topic | Decision | Key Reason |
|-------|----------|------------|
| PVC Access | Read-only mount + pod affinity | No downtime, Kubernetes-native |
| OAuth Setup | Pre-configure locally, store in Secret | Headless cluster |
| Sync Strategy | `rclone sync --backup-dir` | Balance espacio vs retención |
| Drive Structure | `/Paperless-Backup/{data,media,.deleted}` | Simple, navegable |
| Notifications | curl a ntfy con auth existente | Reutilizar infra |
| Container | rclone/rclone + apk curl | Minimal, official image |
| Resources | 500m-1000m CPU, 256-512Mi RAM, 2h timeout | Conservador pero seguro |
