# Quickstart: Paperless-ngx Google Drive Backup

**Feature**: 028-paperless-gdrive-backup
**Date**: 2026-01-04

## Prerequisites

- Paperless-ngx desplegado en namespace `paperless`
- Cuenta de Google con espacio suficiente en Google Drive (~50GB recomendado)
- Acceso a una máquina con browser para OAuth (tu laptop)
- kubectl configurado para el cluster

## Setup (One-time)

### 1. Configurar rclone en tu máquina local

```bash
# Instalar rclone (macOS)
brew install rclone

# O descargar desde https://rclone.org/downloads/
```

### 2. Crear configuración de Google Drive

```bash
rclone config
```

Sigue estos pasos en el wizard interactivo:

```
n) New remote
name> gdrive
Storage> drive
client_id> (dejar vacío, usa el de rclone)
client_secret> (dejar vacío)
scope> 1 (Full access)
root_folder_id> (dejar vacío)
service_account_file> (dejar vacío)
Edit advanced config? n
Use auto config? y
```

Se abrirá el browser para autorizar. Una vez autorizado:

```
Configure this as a Shared Drive? n
```

### 3. Verificar que funciona

```bash
# Listar contenido de Google Drive
rclone lsd gdrive:/

# Crear carpeta de prueba
rclone mkdir gdrive:/Paperless-Backup

# Subir archivo de prueba
echo "test" > /tmp/test.txt
rclone copy /tmp/test.txt gdrive:/Paperless-Backup/

# Verificar
rclone ls gdrive:/Paperless-Backup/
```

### 4. Crear Secret en Kubernetes

```bash
# Ver contenido del config (verificar que tiene token válido)
cat ~/.config/rclone/rclone.conf

# Crear secret
kubectl create secret generic rclone-gdrive-config \
  -n paperless \
  --from-file=rclone.conf=$HOME/.config/rclone/rclone.conf

# Verificar
kubectl get secret rclone-gdrive-config -n paperless
```

### 5. Aplicar módulo OpenTofu

```bash
cd terraform/environments/chocolandiadc-mvp

# Cargar credenciales de backend
source ./backend-env.sh

# Plan y apply
tofu plan
tofu apply
```

## Verificación

### Test manual del backup

```bash
# Crear job manual desde el CronJob
kubectl create job --from=cronjob/paperless-backup manual-backup-test -n paperless

# Ver logs
kubectl logs -f job/manual-backup-test -n paperless

# Ver resultado
kubectl get job manual-backup-test -n paperless
```

### Verificar en Google Drive

Después del backup, deberías ver:

```
Google Drive/
└── Paperless-Backup/
    ├── data/
    │   ├── index/
    │   └── ...
    └── media/
        ├── documents/
        │   └── originals/
        │   └── archive/
        └── ...
```

### Verificar notificación

Revisa tu app de ntfy o el topic `homelab-alerts`:
- Éxito: "Paperless Backup OK - Backup completado en Xmin"
- Fallo: "Paperless Backup FAILED - Error: ..."

## Operaciones Comunes

### Ejecutar backup manual

```bash
kubectl create job --from=cronjob/paperless-backup manual-$(date +%Y%m%d%H%M) -n paperless
```

### Ver historial de backups

```bash
kubectl get jobs -n paperless -l app.kubernetes.io/name=paperless-backup
```

### Cambiar horario del backup

Editar `terraform/environments/chocolandiadc-mvp/paperless-backup.tf`:

```hcl
module "paperless_backup" {
  # ...
  backup_schedule = "0 4 * * *"  # 4 AM en lugar de 3 AM
}
```

Aplicar:
```bash
tofu apply
```

### Actualizar token de Google Drive

Si el token expira o necesitas re-autorizar:

```bash
# En tu máquina local
rclone config reconnect gdrive:

# Actualizar secret
kubectl delete secret rclone-gdrive-config -n paperless
kubectl create secret generic rclone-gdrive-config \
  -n paperless \
  --from-file=rclone.conf=$HOME/.config/rclone/rclone.conf
```

## Restauración desde Backup

### Restauración completa

```bash
# 1. Escalar Paperless a 0 (IMPORTANTE: detener el servicio)
kubectl scale deployment paperless-ngx -n paperless --replicas=0

# 2. Esperar a que el pod termine
kubectl wait --for=delete pod -l app.kubernetes.io/name=paperless-ngx -n paperless --timeout=120s

# 3. Crear pod temporal para restaurar
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

# 4. Ejecutar restauración
kubectl exec -it restore-pod -n paperless -- sh -c '
  cp /config/rclone/rclone.conf /tmp/
  export RCLONE_CONFIG=/tmp/rclone.conf

  echo "Restaurando data..."
  rclone sync gdrive:/Paperless-Backup/data /data --verbose

  echo "Restaurando media..."
  rclone sync gdrive:/Paperless-Backup/media /media --verbose

  echo "Restauración completada!"
'

# 5. Limpiar pod temporal
kubectl delete pod restore-pod -n paperless

# 6. Escalar Paperless de vuelta
kubectl scale deployment paperless-ngx -n paperless --replicas=1

# 7. Verificar que Paperless inicia correctamente
kubectl logs -f deployment/paperless-ngx -n paperless
```

### Restaurar archivo específico

```bash
# Listar archivos en backup
kubectl exec -it restore-pod -n paperless -- rclone ls gdrive:/Paperless-Backup/media/documents/originals/

# Restaurar archivo específico
kubectl exec -it restore-pod -n paperless -- rclone copy \
  "gdrive:/Paperless-Backup/media/documents/originals/0000001.pdf" \
  /media/documents/originals/
```

### Restaurar versión anterior (de .deleted)

```bash
# Ver fechas disponibles
kubectl exec -it restore-pod -n paperless -- rclone lsd gdrive:/Paperless-Backup/.deleted/

# Restaurar de una fecha específica
kubectl exec -it restore-pod -n paperless -- rclone copy \
  "gdrive:/Paperless-Backup/.deleted/media-20260103/" \
  /media/
```

## Troubleshooting

### El CronJob no se ejecuta

```bash
# Verificar que el CronJob existe
kubectl get cronjob paperless-backup -n paperless

# Ver eventos
kubectl describe cronjob paperless-backup -n paperless

# Verificar que Paperless está corriendo (requerido por pod affinity)
kubectl get pods -n paperless -l app.kubernetes.io/name=paperless-ngx
```

### Error de autenticación con Google Drive

```bash
# Ver logs del job
kubectl logs -l job-name=paperless-backup-XXXXX -n paperless

# Si dice "token expired" o similar, regenerar token:
# (en tu máquina local)
rclone config reconnect gdrive:

# Actualizar secret
kubectl delete secret rclone-gdrive-config -n paperless
kubectl create secret generic rclone-gdrive-config \
  -n paperless \
  --from-file=rclone.conf=$HOME/.config/rclone/rclone.conf
```

### Backup toma demasiado tiempo

Si el backup excede 2 horas:

1. Verificar tamaño de datos:
   ```bash
   kubectl exec deployment/paperless-ngx -n paperless -- du -sh /usr/src/paperless/media
   ```

2. Verificar velocidad de internet del cluster

3. Ajustar timeout si es necesario:
   ```hcl
   # En paperless-backup.tf
   backup_timeout_seconds = 14400  # 4 horas
   ```

### No llegan notificaciones a ntfy

```bash
# Verificar que el secret de ntfy existe
kubectl get secret ntfy-alertmanager-password -n monitoring

# Probar conectividad desde el cluster
kubectl run curl-test --image=curlimages/curl --rm -it -- \
  curl -v http://ntfy.ntfy.svc.cluster.local/homelab-alerts
```

## Monitoreo

### Dashboard de Grafana

El job de backup genera métricas que puedes visualizar en Grafana:

- `kube_cronjob_status_last_successful_time` - Timestamp del último backup exitoso
- `kube_job_status_succeeded` - Contador de jobs exitosos
- `kube_job_status_failed` - Contador de jobs fallidos

### Alerta de backup faltante

Si configuraste el PrometheusRule, recibirás alerta si el backup no se ejecuta en 48+ horas.
