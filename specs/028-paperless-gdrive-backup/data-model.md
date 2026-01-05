# Data Model: Paperless-ngx Google Drive Backup

**Feature**: 028-paperless-gdrive-backup
**Date**: 2026-01-04

## Kubernetes Resources

### 1. CronJob: paperless-backup

**Purpose**: Ejecutar backup diario de Paperless a Google Drive

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: paperless-backup
  namespace: paperless
  labels:
    app.kubernetes.io/name: paperless-backup
    app.kubernetes.io/component: backup
    app.kubernetes.io/managed-by: opentofu
    feature: 028-paperless-gdrive-backup
spec:
  schedule: "0 3 * * *"              # 3:00 AM daily (configurable)
  concurrencyPolicy: Forbid          # No concurrent backups
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      activeDeadlineSeconds: 7200    # 2 hour timeout
      backoffLimit: 2                # Retry twice on failure
      template:
        spec:
          affinity:
            podAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
              - labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: paperless-ngx
                topologyKey: kubernetes.io/hostname
          restartPolicy: OnFailure
          containers:
          - name: rclone
            image: rclone/rclone:latest
            resources:
              requests:
                cpu: "500m"
                memory: "256Mi"
              limits:
                cpu: "1000m"
                memory: "512Mi"
            volumeMounts:
            - name: data
              mountPath: /data
              readOnly: true
            - name: media
              mountPath: /media
              readOnly: true
            - name: rclone-config
              mountPath: /config/rclone
              readOnly: true
            - name: backup-script
              mountPath: /scripts
              readOnly: true
            - name: ntfy-password
              mountPath: /secrets/ntfy
              readOnly: true
            command: ["/bin/sh", "/scripts/backup.sh"]
          volumes:
          - name: data
            persistentVolumeClaim:
              claimName: paperless-ngx-data
          - name: media
            persistentVolumeClaim:
              claimName: paperless-ngx-media
          - name: rclone-config
            secret:
              secretName: rclone-gdrive-config
          - name: backup-script
            configMap:
              name: paperless-backup-script
              defaultMode: 0755
          - name: ntfy-password
            secret:
              secretName: ntfy-alertmanager-password
```

**Fields**:

| Field | Value | Description |
|-------|-------|-------------|
| schedule | `0 3 * * *` | Cron expression (3 AM daily) |
| concurrencyPolicy | Forbid | Prevent overlapping jobs |
| activeDeadlineSeconds | 7200 | 2 hour timeout |
| backoffLimit | 2 | Retry failed jobs twice |

---

### 2. Secret: rclone-gdrive-config

**Purpose**: Almacenar configuración de rclone con tokens OAuth

**Creación manual** (no gestionado por OpenTofu):
```bash
kubectl create secret generic rclone-gdrive-config \
  -n paperless \
  --from-file=rclone.conf=/path/to/rclone.conf
```

**Estructura del rclone.conf**:
```ini
[gdrive]
type = drive
scope = drive
token = {"access_token":"...","token_type":"Bearer","refresh_token":"...","expiry":"..."}
root_folder_id =
```

**Validación**: El Secret DEBE existir antes de aplicar el módulo. OpenTofu verificará su existencia con `data.kubernetes_secret`.

---

### 3. ConfigMap: paperless-backup-script

**Purpose**: Script de backup con lógica de sincronización y notificaciones

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: paperless-backup-script
  namespace: paperless
data:
  backup.sh: |
    #!/bin/sh
    set -e

    # Configuration
    RCLONE_CONFIG=/config/rclone/rclone.conf
    GDRIVE_REMOTE="gdrive:/Paperless-Backup"
    NTFY_URL="http://ntfy.ntfy.svc.cluster.local/homelab-alerts"
    NTFY_USER="alertmanager"
    NTFY_PASS=$(cat /secrets/ntfy/password)

    # Timestamp for backup-dir
    DATE=$(date +%Y%m%d)
    START_TIME=$(date +%s)

    echo "Starting Paperless backup at $(date)"

    # Install curl for notifications (Alpine-based image)
    apk add --no-cache curl > /dev/null 2>&1 || true

    # Copy rclone config to writable location (for token refresh)
    cp $RCLONE_CONFIG /tmp/rclone.conf
    export RCLONE_CONFIG=/tmp/rclone.conf

    # Sync data directory
    echo "Syncing data directory..."
    rclone sync /data $GDRIVE_REMOTE/data \
      --backup-dir "$GDRIVE_REMOTE/.deleted/data-$DATE" \
      --checksum \
      --verbose \
      2>&1 | tee /tmp/data-sync.log
    DATA_RESULT=$?

    # Sync media directory
    echo "Syncing media directory..."
    rclone sync /media $GDRIVE_REMOTE/media \
      --backup-dir "$GDRIVE_REMOTE/.deleted/media-$DATE" \
      --checksum \
      --verbose \
      2>&1 | tee /tmp/media-sync.log
    MEDIA_RESULT=$?

    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_MIN=$((DURATION / 60))

    # Count transferred files
    DATA_FILES=$(grep -c "Transferred:" /tmp/data-sync.log 2>/dev/null || echo "0")
    MEDIA_FILES=$(grep -c "Transferred:" /tmp/media-sync.log 2>/dev/null || echo "0")
    TOTAL_FILES=$((DATA_FILES + MEDIA_FILES))

    # Send notification
    if [ $DATA_RESULT -eq 0 ] && [ $MEDIA_RESULT -eq 0 ]; then
      echo "Backup completed successfully in ${DURATION_MIN} minutes"
      curl -u "$NTFY_USER:$NTFY_PASS" \
        -H "Title: Paperless Backup OK" \
        -H "Tags: white_check_mark" \
        -d "Backup completado en ${DURATION_MIN}min. Archivos sincronizados: $TOTAL_FILES" \
        "$NTFY_URL" || true
      exit 0
    else
      echo "Backup failed!"
      ERROR_MSG="Data: $DATA_RESULT, Media: $MEDIA_RESULT"
      curl -u "$NTFY_USER:$NTFY_PASS" \
        -H "Title: Paperless Backup FAILED" \
        -H "Tags: x" \
        -H "Priority: high" \
        -d "Backup fallido después de ${DURATION_MIN}min. Error: $ERROR_MSG" \
        "$NTFY_URL" || true
      exit 1
    fi
```

---

### 4. PrometheusRule: paperless-backup-alerts (opcional)

**Purpose**: Alertar si el backup no se ejecutó en 48 horas

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: paperless-backup-alerts
  namespace: paperless
  labels:
    release: kube-prometheus-stack
spec:
  groups:
  - name: paperless-backup.rules
    rules:
    - alert: PaperlessBackupMissing
      expr: |
        time() - kube_cronjob_status_last_successful_time{
          cronjob="paperless-backup",
          namespace="paperless"
        } > 172800
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Paperless backup no ejecutado en 48+ horas"
        description: "El backup de Paperless no ha completado exitosamente en más de 48 horas."
```

---

## Entity Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                     Namespace: paperless                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐       ┌──────────────────────────┐    │
│  │    CronJob       │       │      Deployment          │    │
│  │ paperless-backup │       │    paperless-ngx         │    │
│  └────────┬─────────┘       └──────────┬───────────────┘    │
│           │                            │                     │
│           │ mounts (RO)                │ mounts (RW)         │
│           │                            │                     │
│           ▼                            ▼                     │
│  ┌────────────────────────────────────────────────────┐     │
│  │                   PVCs                              │     │
│  │  ┌─────────────────┐  ┌─────────────────────────┐  │     │
│  │  │ paperless-ngx-  │  │ paperless-ngx-media     │  │     │
│  │  │ data (5Gi)      │  │ (40Gi)                  │  │     │
│  │  └─────────────────┘  └─────────────────────────┘  │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌──────────────────┐       ┌──────────────────────────┐    │
│  │     Secret       │       │       ConfigMap          │    │
│  │ rclone-gdrive-   │       │  paperless-backup-script │    │
│  │ config           │       │                          │    │
│  │ (manual)         │       │  (managed by OpenTofu)   │    │
│  └──────────────────┘       └──────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ rclone sync
                           ▼
                ┌──────────────────────┐
                │    Google Drive      │
                │                      │
                │  /Paperless-Backup/  │
                │    ├── data/         │
                │    ├── media/        │
                │    └── .deleted/     │
                └──────────────────────┘
```

---

## State Transitions

### CronJob Lifecycle

```
                              ┌─────────────┐
                              │   Pending   │
                              │  (scheduled)│
                              └──────┬──────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │   Running   │
                              │  (backing   │
                              │    up)      │
                              └──────┬──────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
                    ▼                                 ▼
            ┌─────────────┐                   ┌─────────────┐
            │  Succeeded  │                   │   Failed    │
            │ (ntfy OK)   │                   │(ntfy error) │
            └─────────────┘                   └──────┬──────┘
                                                     │
                                                     │ backoffLimit
                                                     ▼
                                              ┌─────────────┐
                                              │   Retry     │
                                              │ (up to 2x)  │
                                              └─────────────┘
```

---

## Validation Rules

| Resource | Validation | Error Handling |
|----------|------------|----------------|
| Secret rclone-gdrive-config | MUST exist before apply | OpenTofu fails with helpful error |
| PVCs | MUST be bound | CronJob pod stays Pending |
| Pod affinity | Paperless pod MUST be running | CronJob pod stays Pending |
| rclone.conf | MUST have valid token | Job fails, ntfy alert sent |
| Google Drive access | MUST have write permission | Job fails, ntfy alert sent |
