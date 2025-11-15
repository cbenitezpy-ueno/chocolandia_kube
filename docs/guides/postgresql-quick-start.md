# PostgreSQL HA Cluster - Quick Start Guide

**Feature**: 011-postgresql-cluster-db
**Last Updated**: 2025-11-15

## Overview

This guide provides a quick path to deploying and using the PostgreSQL HA cluster in your homelab. For detailed documentation, see the links at the bottom.

## Prerequisites

✅ K3s cluster running (v1.28+)
✅ MetalLB installed and configured with IP pool
✅ Helm (if installing manually)
✅ `kubectl` configured with cluster access
✅ OpenTofu/Terraform 1.6+ (for IaC deployment)

## 5-Minute Deployment

### Option 1: Terraform (Recommended)

```bash
# 1. Navigate to environment directory
cd terraform/environments/chocolandiadc-mvp

# 2. Review variables (optional)
cat terraform.tfvars

# 3. Deploy PostgreSQL cluster
tofu apply -target=module.postgresql_cluster

# 4. Verify deployment (should show 2/2 Running for each pod)
kubectl get pods -n postgresql

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# postgres-ha-postgresql-primary-0    2/2     Running   0          2m
# postgres-ha-postgresql-read-0       2/2     Running   0          2m
```

**Total time**: ~3-5 minutes

### Option 2: Direct kubectl Apply

```bash
# 1. Create namespace
kubectl create namespace postgresql

# 2. Apply backup configuration
kubectl apply -f terraform/modules/postgresql-cluster/backup-cronjob.yaml

# 3. Install PostgreSQL via Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install postgres-ha bitnami/postgresql \
  --namespace postgresql \
  --set architecture=replication \
  --set auth.enablePostgresUser=true \
  --set primary.service.type=LoadBalancer \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled=true

# 4. Verify
kubectl get pods -n postgresql
```

**Total time**: ~3-5 minutes

## First Connection

### Get Credentials

```bash
# Retrieve PostgreSQL password
export PGPASSWORD=$(kubectl get secret -n postgresql postgres-ha-postgresql-credentials \
  -o jsonpath="{.data.postgres-password}" | base64 -d)

echo $PGPASSWORD  # Save this somewhere secure
```

### Connect from Within Cluster

```bash
# Run psql client
kubectl run postgresql-client --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=${PGPASSWORD}" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres -d app_db

# You should see:
# psql (18.1)
# Type "help" for help.
#
# app_db=#
```

### Connect from Internal Network

```bash
# 1. Get external IP
POSTGRES_IP=$(kubectl get svc -n postgresql postgres-ha-postgresql-primary \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "PostgreSQL is available at: ${POSTGRES_IP}:5432"

# 2. Connect using psql (from any machine on your network)
PGPASSWORD="${PGPASSWORD}" psql -h ${POSTGRES_IP} -p 5432 -U postgres -d app_db
```

**Connection String**:
```
postgresql://postgres:<password>@<external-ip>:5432/app_db
```

## Quick Tasks

### Create a Database

```sql
-- Connect to PostgreSQL first (see above)

-- Create new database
CREATE DATABASE my_app_db;

-- Create user
CREATE USER my_app_user WITH PASSWORD 'secure_password_here';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE my_app_db TO my_app_user;

-- Connect to new database
\c my_app_db

-- Create a table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Verify
\dt
```

### Check Cluster Status

```bash
# Pod status
kubectl get pods -n postgresql

# Service status
kubectl get svc -n postgresql

# Check replication
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"

# Expected:
#  application_name | state     | sync_state
# ------------------+-----------+------------
#  my_application   | streaming | async
```

### Trigger Manual Backup

```bash
# Create backup now
kubectl create job --from=cronjob/postgresql-backup \
  postgresql-backup-manual-$(date +%Y%m%d%H%M%S) -n postgresql

# Watch progress
kubectl logs -n postgresql -l component=backup-job -f

# Verify backup was created
kubectl run backup-check --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "backup-check",
      "image": "registry-1.docker.io/bitnami/postgresql:latest",
      "command": ["ls", "-lh", "/backups/"],
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
}'
```

### Access Grafana Dashboard

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open in browser: http://localhost:3000
# Login: admin / prom-operator
# Navigate to: Dashboards → PostgreSQL HA Cluster
```

### View Prometheus Alerts

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open in browser: http://localhost:9090/alerts
# Look for alerts starting with "PostgreSQL"
```

## Common Connection Strings

### Internal (from Kubernetes)

**Primary (read/write)**:
```
postgres-ha-postgresql-primary.postgresql.svc.cluster.local:5432
```

**Read Replica (read-only)**:
```
postgres-ha-postgresql-read.postgresql.svc.cluster.local:5432
```

### External (from internal network)

Get IP first:
```bash
kubectl get svc -n postgresql postgres-ha-postgresql-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Then use: `<external-ip>:5432`

## Application Integration Examples

### Python (using psycopg2)

```python
import psycopg2

# Connection parameters
conn_params = {
    'host': 'postgres-ha-postgresql-primary.postgresql.svc.cluster.local',
    'port': 5432,
    'database': 'app_db',
    'user': 'my_app_user',
    'password': 'secure_password_here'
}

# Connect
conn = psycopg2.connect(**conn_params)
cursor = conn.cursor()

# Query
cursor.execute("SELECT version();")
print(cursor.fetchone())

# Close
cursor.close()
conn.close()
```

### Node.js (using pg)

```javascript
const { Client } = require('pg');

const client = new Client({
  host: 'postgres-ha-postgresql-primary.postgresql.svc.cluster.local',
  port: 5432,
  database: 'app_db',
  user: 'my_app_user',
  password: 'secure_password_here'
});

client.connect()
  .then(() => client.query('SELECT version()'))
  .then(result => console.log(result.rows[0]))
  .finally(() => client.end());
```

### Go (using pgx)

```go
package main

import (
    "context"
    "fmt"
    "github.com/jackc/pgx/v5"
)

func main() {
    ctx := context.Background()

    connString := "postgres://my_app_user:secure_password_here@postgres-ha-postgresql-primary.postgresql.svc.cluster.local:5432/app_db"

    conn, err := pgx.Connect(ctx, connString)
    if err != nil {
        panic(err)
    }
    defer conn.Close(ctx)

    var version string
    err = conn.QueryRow(ctx, "SELECT version()").Scan(&version)
    if err != nil {
        panic(err)
    }

    fmt.Println(version)
}
```

### Kubernetes Deployment Environment Variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: my-app
        image: my-app:latest
        env:
        - name: DATABASE_HOST
          value: "postgres-ha-postgresql-primary.postgresql.svc.cluster.local"
        - name: DATABASE_PORT
          value: "5432"
        - name: DATABASE_NAME
          value: "app_db"
        - name: DATABASE_USER
          value: "my_app_user"
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: my-app-database-secret
              key: password
```

## Troubleshooting

### Can't connect to database

**Check 1**: Pod running?
```bash
kubectl get pods -n postgresql
# Both pods should be 2/2 Running
```

**Check 2**: Service exists?
```bash
kubectl get svc -n postgresql
# Should see postgres-ha-postgresql-primary with EXTERNAL-IP
```

**Check 3**: Test connectivity from within cluster
```bash
kubectl run test-connection --rm -i --restart='Never' --namespace postgresql \
  --image nicolaka/netshoot \
  --command -- nc -zv postgres-ha-postgresql-primary 5432
```

**Check 4**: Check PostgreSQL logs
```bash
kubectl logs -n postgresql postgres-ha-postgresql-primary-0 -c postgresql --tail=50
```

### Replication not working

```bash
# Check replication status on primary
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Should show 1 row with state='streaming'
# If empty, check read replica logs:
kubectl logs -n postgresql postgres-ha-postgresql-read-0 -c postgresql --tail=50
```

### External IP not assigned

```bash
# Check MetalLB is running
kubectl get pods -n metallb-system

# Check service events
kubectl describe svc -n postgresql postgres-ha-postgresql-primary

# Verify IP pool exists
kubectl get ipaddresspool -n metallb-system
```

### Backup job failed

```bash
# View recent backup jobs
kubectl get jobs -n postgresql -l component=backup-job

# Check failed job logs
kubectl logs -n postgresql job/<job-name>

# Common issues:
# - Disk full (check PVC usage)
# - Connection timeout (check network/credentials)
# - Permissions (check PostgreSQL user has sufficient privileges)
```

## Next Steps

- **Configure application**: Use connection strings above
- **Set up monitoring**: Access Grafana dashboard
- **Schedule backups**: Already configured (daily at 2:00 AM)
- **Test failover**: See [Failover Runbook](../runbooks/postgresql-failover.md)
- **Read documentation**: See links below

## Key Configuration Files

| File | Purpose |
|------|---------|
| `terraform/modules/postgresql-cluster/postgresql.tf` | Main module configuration |
| `terraform/modules/postgresql-cluster/backup-cronjob.yaml` | Backup automation |
| `terraform/modules/postgresql-cluster/monitoring.tf` | Prometheus alerts |
| `terraform/modules/postgresql-cluster/grafana-dashboard.json` | Grafana dashboard |

## Useful Commands Reference

```bash
# Get password
kubectl get secret -n postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d

# Connect via psql
kubectl run postgresql-client --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=<password>" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres -d app_db

# List databases
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- psql -U postgres -c "\l"

# Check replication
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"

# Trigger backup
kubectl create job --from=cronjob/postgresql-backup postgresql-backup-manual-$(date +%Y%m%d) -n postgresql

# View backup logs
kubectl logs -n postgresql -l component=backup-job --tail=50

# Port-forward for Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Port-forward for Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

## Documentation Links

- [PostgreSQL Module README](../../terraform/modules/postgresql-cluster/README.md) - Detailed module documentation
- [Failover Procedures](../runbooks/postgresql-failover.md) - HA and disaster recovery
- [Backup & Restore](../runbooks/postgresql-backup-restore.md) - Complete backup/restore procedures
- [Monitoring Setup](../architecture/postgresql-monitoring.md) - Grafana dashboards and alerts
- [Feature Specification](../../specs/011-postgresql-cluster/spec.md) - Original design spec

## Support

For issues or questions:
1. Check logs: `kubectl logs -n postgresql <pod-name> -c postgresql`
2. Review documentation linked above
3. Check Prometheus alerts: http://localhost:9090/alerts (after port-forward)
4. Consult runbooks in `docs/runbooks/`

## Summary

**Deployment time**: 3-5 minutes
**High availability**: ✅ Primary + Read Replica
**Automatic backups**: ✅ Daily at 2:00 AM
**Monitoring**: ✅ Grafana + Prometheus
**External access**: ✅ Via MetalLB LoadBalancer
**Documented runbooks**: ✅ Failover, Backup/Restore, Monitoring

You now have a production-ready PostgreSQL HA cluster! 🎉
