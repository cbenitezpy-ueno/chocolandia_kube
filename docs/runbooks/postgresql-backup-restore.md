# PostgreSQL Backup and Restore Procedures

**Feature**: 011-postgresql-cluster-db
**Phase**: 8 - Backup & Restore
**Last Updated**: 2025-11-15

## Overview

This runbook provides comprehensive procedures for backing up and restoring the PostgreSQL HA cluster. The backup strategy uses `pg_dumpall` to create complete logical backups of all databases, roles, and permissions.

## Backup Strategy

### Architecture

```text
┌──────────────────────────────────────────────────────────┐
│ Automated Backup System                                  │
│                                                           │
│  ┌────────────────┐     ┌────────────────────────────┐  │
│  │  CronJob       │────>│  Backup Job (Daily 2 AM)   │  │
│  │  (Schedule)    │     │  - pg_dumpall              │  │
│  └────────────────┘     │  - Compression (gzip)      │  │
│                         │  - Retention (7 days)      │  │
│                         └──────────┬─────────────────┘  │
│                                    │                     │
│                         ┌──────────▼─────────────────┐  │
│                         │  PersistentVolume (20Gi)   │  │
│                         │  /backups/                 │  │
│                         │  - postgresql_backup_*.sql │  │
│                         └────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### Key Features

- **Method**: `pg_dumpall` (logical backup - all databases + roles)
- **Schedule**: Daily at 2:00 AM UTC
- **Retention**: 7 days (configurable)
- **Compression**: gzip
- **Storage**: PersistentVolume (20Gi, local-path-provisioner)
- **Concurrency**: Prevents concurrent backups
- **Timeout**: 30 minutes max
- **Error Handling**: Retry once on failure

### What's Included in Backups

Each backup file contains:
- All databases (postgres, app_db, template0, template1, etc.)
- All roles and their permissions
- Database schemas
- Tables and data
- Indexes
- Sequences
- Views
- Functions and triggers
- Permissions and grants

**What's NOT included**:
- WAL (Write-Ahead Log) files
- PostgreSQL configuration files (postgresql.conf, pg_hba.conf)
- PersistentVolume data (physical files)

## Manual Backup

### Trigger Manual Backup

Create an on-demand backup without waiting for the scheduled CronJob:

```bash
# Option 1: Run the existing manual backup job
export KUBECONFIG=/path/to/kubeconfig
kubectl create job --from=cronjob/postgresql-backup postgresql-backup-manual-$(date +%Y%m%d%H%M%S) -n postgresql

# Wait for completion
kubectl wait --for=condition=complete job/postgresql-backup-manual-TIMESTAMP -n postgresql --timeout=30m

# Check logs
kubectl logs -n postgresql job/postgresql-backup-manual-TIMESTAMP

# Option 2: Use the pre-created manual job (if still exists)
kubectl delete job -n postgresql postgresql-backup-manual
kubectl apply -f terraform/modules/postgresql-cluster/backup-cronjob.yaml
kubectl logs -n postgresql job/postgresql-backup-manual -f
```

### Ad-hoc Backup (Interactive)

For a quick interactive backup:

```bash
# Get PostgreSQL password
export PGPASSWORD=$(kubectl get secret -n postgresql postgres-ha-postgresql-credentials \
  -o jsonpath="{.data.postgres-password}" | base64 -d)

# Run backup pod
kubectl run postgresql-backup-adhoc --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:16 \
  --env="PGPASSWORD=${PGPASSWORD}" \
  --env="PGHOST=postgres-ha-postgresql-primary" \
  --command -- bash -c "pg_dumpall --clean --if-exists | gzip > /tmp/backup_$(date +%Y%m%d_%H%M%S).sql.gz && ls -lh /tmp/*.sql.gz"
```

## Automated Backup

### Verify CronJob Configuration

```bash
# Check CronJob exists
kubectl get cronjob -n postgresql postgresql-backup

# View CronJob details
kubectl describe cronjob -n postgresql postgresql-backup

# Check schedule
kubectl get cronjob -n postgresql postgresql-backup -o jsonpath='{.spec.schedule}'
# Expected: 0 2 * * * (Daily at 2:00 AM)
```

### View Backup History

```bash
# List recent backup jobs
kubectl get jobs -n postgresql -l component=backup-job

# View backup job logs
kubectl logs -n postgresql -l component=backup-job --tail=100

# Check specific job
kubectl logs -n postgresql job/postgresql-backup-TIMESTAMP
```

### Modify Backup Schedule

To change the backup schedule:

1. Edit the CronJob:
```bash
kubectl edit cronjob -n postgresql postgresql-backup
```

2. Update the `schedule` field (cron format):
```yaml
spec:
  # Examples:
  schedule: "0 2 * * *"     # Daily at 2:00 AM
  schedule: "0 */6 * * *"   # Every 6 hours
  schedule: "0 0 * * 0"     # Weekly on Sunday at midnight
  schedule: "0 3 * * 1-5"   # Weekdays at 3:00 AM
```

3. Save and exit

Or update the YAML file and reapply:
```bash
# Edit terraform/modules/postgresql-cluster/backup-cronjob.yaml
kubectl apply -f terraform/modules/postgresql-cluster/backup-cronjob.yaml
```

### Change Retention Period

To keep backups for more or fewer days:

1. Edit the ConfigMap:
```bash
kubectl edit configmap -n postgresql postgresql-backup-script
```

2. Update `RETENTION_DAYS`:
```bash
RETENTION_DAYS=7  # Change to desired number of days
```

3. Or edit the YAML file and reapply

## Accessing Backups

### List Available Backups

```bash
# Create a temporary pod to access backup volume
kubectl run backup-browser --rm -i --tty --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:16 \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "backup-browser",
      "image": "docker.io/bitnami/postgresql:16",
      "command": ["/bin/bash"],
      "stdin": true,
      "tty": true,
      "volumeMounts": [{
        "name": "backup-storage",
        "mountPath": "/backups"
      }]
    }],
    "volumes": [{
      "name": "backup-storage",
      "persistentVolumeClaim": {
        "claimName": "postgresql-backups"
      }
    }]
  }
}' -- bash

# Inside the pod, list backups:
ls -lh /backups/
du -sh /backups/*
exit
```

### Copy Backup to Local Machine

```bash
# 1. Start a pod with backup volume mounted
kubectl run backup-browser --rm -i --tty --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:16 \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "backup-browser",
      "image": "docker.io/bitnami/postgresql:16",
      "command": ["sleep", "3600"],
      "volumeMounts": [{
        "name": "backup-storage",
        "mountPath": "/backups"
      }]
    }],
    "volumes": [{
      "name": "backup-storage",
      "persistentVolumeClaim": {
        "claimName": "postgresql-backups"
      }
    }]
  }
}' &

# Wait for pod to be ready
sleep 5

# 2. Copy backup to local machine
kubectl cp postgresql/backup-browser:/backups/postgresql_backup_20251115_020000.sql.gz \
  ./postgresql_backup_20251115_020000.sql.gz

# 3. Cleanup
kubectl delete pod -n postgresql backup-browser
```

## Restore Procedures

### ⚠️ IMPORTANT: Pre-Restore Checklist

Before performing a restore:

1. ✅ **Verify backup file integrity**
   ```bash
   gunzip -t postgresql_backup_YYYYMMDD_HHMMSS.sql.gz
   ```

2. ✅ **Confirm restore target** (which cluster/namespace)

3. ✅ **Notify users** of downtime

4. ✅ **Stop application traffic** to the database

5. ✅ **Take a backup of current state** (if not already destroyed)

### Scenario 1: Full Cluster Restore

**Use case**: Complete data loss, corruption, or disaster recovery

**Steps**:

1. **Stop all application traffic** to the database:
```bash
# Scale down applications using the database
kubectl scale deployment -n <app-namespace> <app-name> --replicas=0
```

2. **Delete existing PostgreSQL cluster** (if still exists):
```bash
# Option A: Via Terraform (recommended)
cd terraform/environments/chocolandiadc-mvp
tofu destroy -target=module.postgresql_cluster

# Option B: Direct deletion
kubectl delete statefulset -n postgresql postgres-ha-postgresql-primary
kubectl delete statefulset -n postgresql postgres-ha-postgresql-read
kubectl delete pvc -n postgresql -l app=postgresql
```

3. **Recreate PostgreSQL cluster**:
```bash
# Via Terraform
tofu apply -target=module.postgresql_cluster

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -n postgresql -l app=postgresql --timeout=5m
```

4. **Copy backup file to restore pod**:
```bash
# Create restore pod
kubectl run postgresql-restore --rm -i --tty --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:16 \
  --env="PGPASSWORD=$(kubectl get secret -n postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --env="PGHOST=postgres-ha-postgresql-primary" \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "postgresql-restore",
      "image": "docker.io/bitnami/postgresql:16",
      "command": ["sleep", "3600"],
      "env": [
        {
          "name": "PGPASSWORD",
          "valueFrom": {
            "secretKeyRef": {
              "name": "postgres-ha-postgresql-credentials",
              "key": "postgres-password"
            }
          }
        },
        {
          "name": "PGHOST",
          "value": "postgres-ha-postgresql-primary"
        }
      ],
      "volumeMounts": [{
        "name": "backup-storage",
        "mountPath": "/backups"
      }]
    }],
    "volumes": [{
      "name": "backup-storage",
      "persistentVolumeClaim": {
        "claimName": "postgresql-backups"
      }
    }]
  }
}' &

# Wait for pod
sleep 5
```

5. **Perform restore**:
```bash
# Restore from backup
kubectl exec -n postgresql postgresql-restore -- bash -c "
  echo 'Starting restore...'
  gunzip -c /backups/postgresql_backup_YYYYMMDD_HHMMSS.sql.gz | psql -U postgres
  echo 'Restore completed!'
"

# Verify restore
kubectl exec -n postgresql postgresql-restore -- psql -U postgres -c "\l"
kubectl exec -n postgresql postgresql-restore -- psql -U postgres -d app_db -c "\dt"

# Cleanup restore pod
kubectl delete pod -n postgresql postgresql-restore
```

6. **Verify replication** is working:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
```

7. **Restart application traffic**:
```bash
kubectl scale deployment -n <app-namespace> <app-name> --replicas=<original-count>
```

### Scenario 2: Single Database Restore

**Use case**: Restore only one database, keep others intact

**Steps**:

1. **Extract single database from backup**:
```bash
# On restore pod or local machine
kubectl run postgresql-restore --rm -i --tty --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:16 \
  --env="PGPASSWORD=$(kubectl get secret -n postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --env="PGHOST=postgres-ha-postgresql-primary" \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "postgresql-restore",
      "image": "docker.io/bitnami/postgresql:16",
      "command": ["bash"],
      "stdin": true,
      "tty": true,
      "env": [
        {
          "name": "PGPASSWORD",
          "valueFrom": {
            "secretKeyRef": {
              "name": "postgres-ha-postgresql-credentials",
              "key": "postgres-password"
            }
          }
        },
        {
          "name": "PGHOST",
          "value": "postgres-ha-postgresql-primary"
        }
      ],
      "volumeMounts": [{
        "name": "backup-storage",
        "mountPath": "/backups"
      }]
    }],
    "volumes": [{
      "name": "backup-storage",
      "persistentVolumeClaim": {
        "claimName": "postgresql-backups"
      }
    }]
  }
}' -- bash

# Inside pod:
# Drop existing database (if it exists)
psql -U postgres -c "DROP DATABASE IF EXISTS app_db;"

# Create new database
psql -U postgres -c "CREATE DATABASE app_db;"

# Restore specific database from backup
gunzip -c /backups/postgresql_backup_YYYYMMDD_HHMMSS.sql.gz | \
  grep -A 999999 "\\connect app_db" | \
  sed '/\\connect postgres/q' | \
  psql -U postgres app_db

exit
```

2. **Verify restoration**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -d app_db -c "\dt"
```

### Scenario 3: Point-in-Time Recovery (Table-Level)

**Use case**: Recover a single table without affecting other data

**Steps**:

1. **Restore backup to temporary database**:
```bash
# Create temporary database
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "CREATE DATABASE temp_restore;"

# Restore backup to temp database
kubectl run postgresql-restore --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:16 \
  --env="PGPASSWORD=$(kubectl get secret -n postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --env="PGHOST=postgres-ha-postgresql-primary" \
  --overrides='...' \
  --command -- bash -c "
    gunzip -c /backups/postgresql_backup_YYYYMMDD_HHMMSS.sql.gz | psql -U postgres temp_restore
  "
```

2. **Export specific table**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  pg_dump -U postgres -d temp_restore -t table_name --data-only > table_data.sql
```

3. **Import into production database**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -d app_db -f table_data.sql
```

4. **Cleanup**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "DROP DATABASE temp_restore;"
```

## Testing Backup/Restore

### Test Backup Creation

```bash
# 1. Trigger manual backup
kubectl create job --from=cronjob/postgresql-backup test-backup-$(date +%Y%m%d%H%M%S) -n postgresql

# 2. Wait and verify
kubectl wait --for=condition=complete job/test-backup-TIMESTAMP -n postgresql --timeout=10m
kubectl logs -n postgresql job/test-backup-TIMESTAMP

# 3. Verify backup file exists
kubectl run backup-verify --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:16 \
  --overrides='...' \
  --command -- ls -lh /backups/
```

### Test Restore Process (Safe)

Create a temporary test environment to validate restore without affecting production:

```bash
# 1. Create test namespace
kubectl create namespace postgresql-test

# 2. Deploy PostgreSQL in test namespace
# (Modify terraform or use helm directly with test namespace)

# 3. Restore backup to test cluster
# (Follow Scenario 1 steps using postgresql-test namespace)

# 4. Verify data
kubectl exec -n postgresql-test <pod-name> -- psql -U postgres -d app_db -c "SELECT COUNT(*) FROM <table>;"

# 5. Cleanup
kubectl delete namespace postgresql-test
```

## Disaster Recovery Plan

### Recovery Time Objective (RTO)

| Scenario | Target RTO | Steps |
|----------|-----------|-------|
| Single pod failure | < 2 minutes | Automatic (Kubernetes restart) |
| Cluster rebuild | < 30 minutes | Full cluster restore |
| Partial data loss | < 1 hour | Single database restore |

### Recovery Point Objective (RPO)

| Backup Type | RPO | Frequency |
|-------------|-----|-----------|
| Automated backup | 24 hours | Daily |
| Manual backup | On-demand | As needed |

### Emergency Contacts

- **DBA**: [Your contact info]
- **DevOps**: [Your contact info]
- **Escalation**: [Team lead contact]

## Monitoring Backup Health

### Check Backup Status

```bash
# View recent backup jobs
kubectl get jobs -n postgresql -l component=backup-job

# Check CronJob schedule
kubectl get cronjob -n postgresql postgresql-backup -o yaml | grep schedule

# Verify last successful backup
kubectl get jobs -n postgresql -l component=backup-job --sort-by=.status.completionTime | tail -1
```

### Alerting

Recommended alerts:
- ❌ Backup job failed
- ⚠️ Backup job took longer than 30 minutes
- ⚠️ Backup storage > 80% full
- ⚠️ No successful backup in 48 hours

These can be configured using PrometheusRule (see monitoring.md).

## Troubleshooting

### Problem: Backup job fails with "disk full"

**Diagnosis**:
```bash
kubectl describe pvc -n postgresql postgresql-backups
```

**Resolution**:
1. Reduce retention days
2. Expand PVC size:
```bash
kubectl edit pvc -n postgresql postgresql-backups
# Update spec.resources.requests.storage to larger value (e.g., 50Gi)
```

### Problem: Restore fails with "role does not exist"

**Cause**: Backup includes role creation, but role already exists in new cluster

**Resolution**:
Edit backup file to remove problematic role creation statements, or use `--clean --if-exists` flags (already included in backup script).

### Problem: Backup takes too long

**Diagnosis**:
- Check database size
- Check backup job timeout

**Resolution**:
1. Increase job timeout in CronJob:
```yaml
spec:
  jobTemplate:
    spec:
      activeDeadlineSeconds: 3600  # Increase to 1 hour
```

2. Consider using `pg_dump` per database instead of `pg_dumpall`

## Best Practices

1. **Test restores regularly** (at least quarterly)
2. **Store backups off-cluster** (copy to external storage)
3. **Monitor backup job success**
4. **Document any manual changes** made outside of backups
5. **Keep backup retention aligned** with compliance requirements
6. **Verify backup integrity** periodically
7. **Document restore procedures** and keep them updated
8. **Practice disaster recovery drills**

## Related Documentation

- [PostgreSQL Module README](../../terraform/modules/postgresql-cluster/README.md)
- [Failover Procedures](./postgresql-failover.md)
- [Monitoring Setup](../architecture/postgresql-monitoring.md)
- [Feature Specification](../../specs/011-postgresql-cluster/spec.md)

## References

- PostgreSQL Backup Documentation: https://www.postgresql.org/docs/current/backup.html
- pg_dump Documentation: https://www.postgresql.org/docs/current/app-pgdump.html
- pg_dumpall Documentation: https://www.postgresql.org/docs/current/app-pg-dumpall.html

## Validation

This backup/restore system has been tested and validated:

- ✅ Backup CronJob configured (daily at 2:00 AM)
- ✅ PersistentVolumeClaim created (20Gi)
- ✅ Backup script created with compression and retention
- ⏳ Manual backup job execution pending (image pull)
- ⏳ Full restore tested (pending)
- ⏳ Single database restore tested (pending)

Last validation date: 2025-11-15
