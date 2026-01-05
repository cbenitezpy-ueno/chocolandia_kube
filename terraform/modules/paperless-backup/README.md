# Paperless Backup Module

Módulo de OpenTofu para backup automatizado de Paperless-ngx a Google Drive usando rclone.

## Features

- Backup diario automático via CronJob
- Sincronización incremental (solo archivos nuevos/modificados)
- Archivos eliminados van a carpeta `.deleted/` en Google Drive (no se borran permanentemente)
- Notificaciones a ntfy en éxito o fallo
- Alerta de Prometheus si backup no se ejecuta en 48 horas

## Prerequisites

### 1. Configurar rclone con Google Drive

Ejecutar en tu máquina local (requiere browser):

```bash
# Instalar rclone
brew install rclone

# Configurar Google Drive
rclone config
# Seleccionar: n (new remote)
# Nombre: gdrive
# Storage: drive
# client_id: (dejar vacío)
# client_secret: (dejar vacío)
# scope: 1 (Full access)
# root_folder_id: (dejar vacío)
# service_account_file: (dejar vacío)
# Edit advanced config: n
# Use auto config: y
# (Completar OAuth en browser)
# Configure as Shared Drive: n
```

### 2. Crear Secret con credenciales

```bash
kubectl create secret generic rclone-gdrive-config \
  -n paperless \
  --from-file=rclone.conf=$HOME/.config/rclone/rclone.conf
```

### 3. Verificar Secret

```bash
kubectl get secret rclone-gdrive-config -n paperless
```

## Usage

```hcl
module "paperless_backup" {
  source = "../modules/paperless-backup"

  namespace        = "paperless"
  backup_schedule  = "0 3 * * *"  # 3 AM daily

  # PVC names (must match existing Paperless PVCs)
  data_pvc_name  = "paperless-ngx-data"
  media_pvc_name = "paperless-ngx-media"

  # Google Drive destination
  gdrive_remote_path = "gdrive:/Paperless-Backup"

  # Notifications
  ntfy_enabled = true
  ntfy_url     = "http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| namespace | Kubernetes namespace | string | "paperless" |
| backup_schedule | Cron schedule | string | "0 3 * * *" |
| backup_timeout_seconds | Job timeout | number | 7200 |
| rclone_secret_name | Secret name for rclone config | string | "rclone-gdrive-config" |
| gdrive_remote_path | Google Drive path | string | "gdrive:/Paperless-Backup" |
| ntfy_enabled | Enable notifications | bool | true |
| ntfy_url | ntfy server URL | string | "http://ntfy.ntfy.svc.cluster.local/homelab-alerts" |

## Outputs

| Name | Description |
|------|-------------|
| cronjob_name | Name of the CronJob |
| manual_job_command | Command to trigger manual backup |
| view_logs_command | Command to view logs |

## Manual Operations

### Ejecutar backup manual

```bash
kubectl create job --from=cronjob/paperless-backup manual-backup-$(date +%Y%m%d%H%M) -n paperless
```

### Ver logs del último backup

```bash
kubectl logs -l app.kubernetes.io/name=paperless-backup -n paperless --tail=100
```

### Ver historial de jobs

```bash
kubectl get jobs -n paperless -l app.kubernetes.io/name=paperless-backup
```

## Restore Procedure

### Restauración completa

```bash
# 1. Escalar Paperless a 0
kubectl scale deployment paperless-ngx -n paperless --replicas=0

# 2. Esperar a que termine
kubectl wait --for=delete pod -l app.kubernetes.io/name=paperless-ngx -n paperless --timeout=120s

# 3. Crear pod de restauración
kubectl run restore-pod --image=rclone/rclone:latest -n paperless \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "restore",
        "image": "rclone/rclone:latest",
        "command": ["sleep", "3600"],
        "volumeMounts": [
          {"name": "data", "mountPath": "/data"},
          {"name": "media", "mountPath": "/media"},
          {"name": "config", "mountPath": "/config/rclone", "readOnly": true}
        ]
      }],
      "volumes": [
        {"name": "data", "persistentVolumeClaim": {"claimName": "paperless-ngx-data"}},
        {"name": "media", "persistentVolumeClaim": {"claimName": "paperless-ngx-media"}},
        {"name": "config", "secret": {"secretName": "rclone-gdrive-config"}}
      ]
    }
  }' -- sleep 3600

# 4. Restaurar
kubectl exec -it restore-pod -n paperless -- sh -c '
  cp /config/rclone/rclone.conf /tmp/
  export RCLONE_CONFIG=/tmp/rclone.conf
  rclone sync gdrive:/Paperless-Backup/data /data --verbose
  rclone sync gdrive:/Paperless-Backup/media /media --verbose
'

# 5. Limpiar
kubectl delete pod restore-pod -n paperless

# 6. Restaurar Paperless
kubectl scale deployment paperless-ngx -n paperless --replicas=1
```

### Restaurar archivo específico

```bash
kubectl exec -it restore-pod -n paperless -- rclone copy \
  "gdrive:/Paperless-Backup/media/documents/originals/0000001.pdf" \
  /media/documents/originals/
```

### Restaurar de versión anterior

```bash
# Ver fechas disponibles en .deleted
kubectl exec -it restore-pod -n paperless -- rclone lsd gdrive:/Paperless-Backup/.deleted/

# Restaurar de fecha específica
kubectl exec -it restore-pod -n paperless -- rclone copy \
  "gdrive:/Paperless-Backup/.deleted/media-20260103/" /media/
```

## Troubleshooting

### Error de autenticación

Si el token OAuth expira:

```bash
# En tu máquina local
rclone config reconnect gdrive:

# Actualizar secret
kubectl delete secret rclone-gdrive-config -n paperless
kubectl create secret generic rclone-gdrive-config \
  -n paperless \
  --from-file=rclone.conf=$HOME/.config/rclone/rclone.conf
```

### CronJob no se ejecuta

```bash
# Verificar que Paperless está corriendo (requerido por pod affinity)
kubectl get pods -n paperless -l app.kubernetes.io/name=paperless-ngx

# Ver eventos del CronJob
kubectl describe cronjob paperless-backup -n paperless
```

### Backup toma demasiado tiempo

```bash
# Ver tamaño de datos
kubectl exec deployment/paperless-ngx -n paperless -- du -sh /usr/src/paperless/media

# Ajustar timeout en variables.tf
backup_timeout_seconds = 14400  # 4 horas
```
