# Quick Start: PostgreSQL Cluster Database Service

**Branch**: `011-postgresql-cluster` | **Date**: 2025-11-14
**Purpose**: Get started with the PostgreSQL HA cluster in 5 minutes

## Overview

This guide helps you quickly connect to and use the PostgreSQL high-availability cluster deployed in your K3s homelab. It covers the most common tasks:
- Connecting from Kubernetes applications
- Connecting from the internal network (administrators)
- Creating databases and users
- Verifying cluster health

---

## Prerequisites

- K3s cluster is running (feature 002-k3s-mvp-eero)
- ArgoCD is deployed and synced (feature 008-gitops-argocd)
- PostgreSQL cluster is deployed via ArgoCD
- You have `kubectl` access to the cluster
- (For external access) You have `psql` client installed on your workstation

---

## Quick Reference

### Connection Endpoints

| Access Pattern | Endpoint | Port | Purpose |
|---------------|----------|------|---------|
| **From K8s Pods** | `postgres-ha-postgresql.postgresql.svc.cluster.local` | 5432 | Application database connections |
| **From Internal Network** | `<metallb-ip>` (e.g., `192.168.10.100`) | 5432 | Administrator access via psql/pgAdmin |
| **Read Replicas** | `postgres-ha-postgresql-read.postgresql.svc.cluster.local` | 5432 | Read-only queries (optional) |

### Default Credentials

```bash
# Get the postgres superuser password
kubectl get secret -n postgresql postgres-ha-postgresql-credentials \
  -o jsonpath="{.data.postgres-password}" | base64 -d && echo

# Get the replication password (for PostgreSQL internal use)
kubectl get secret -n postgresql postgres-ha-postgresql-credentials \
  -o jsonpath="{.data.replication-password}" | base64 -d && echo
```

---

## 1. Verify Cluster Health

### Check Pod Status

```bash
# All pods should be Running
kubectl get pods -n postgresql

# Expected output:
# NAME                           READY   STATUS    RESTARTS   AGE
# postgres-ha-postgresql-0       2/2     Running   0          5m
# postgres-ha-postgresql-1       2/2     Running   0          5m
```

### Check Replication Status

```bash
# Connect to primary and check replication
POSTGRES_PASSWORD=$(kubectl get secret -n postgresql postgres-ha-postgresql-credentials \
  -o jsonpath="{.data.postgres-password}" | base64 -d)

kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Expected: 1 row showing replica connection (application_name, state, sync_state, etc.)
```

### Check Service Endpoints

```bash
# ClusterIP service (internal cluster access)
kubectl get svc -n postgresql postgres-ha-postgresql

# LoadBalancer service (external access)
kubectl get svc -n postgresql postgres-ha-postgresql-external

# Get MetalLB IP
export POSTGRES_EXTERNAL_IP=$(kubectl get svc -n postgresql postgres-ha-postgresql-external \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "PostgreSQL External IP: $POSTGRES_EXTERNAL_IP"
```

---

## 2. Connect from Kubernetes Applications

### Method A: Using Environment Variables (Recommended)

**Deployment YAML Example**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: my-app:latest
        env:
        - name: POSTGRES_HOST
          value: "postgres-ha-postgresql.postgresql.svc.cluster.local"
        - name: POSTGRES_PORT
          value: "5432"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: my-app-db-credentials  # Create this secret first
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: my-app-db-credentials
              key: password
        - name: POSTGRES_DB
          value: "my_app_db"
```

**Create Application Database and User**:

```bash
# Get postgres password
POSTGRES_PASSWORD=$(kubectl get secret -n postgresql postgres-ha-postgresql-credentials \
  -o jsonpath="{.data.postgres-password}" | base64 -d)

# Create database and user for your application
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "CREATE DATABASE my_app_db;"

kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "CREATE USER my_app_user WITH PASSWORD 'secure_password_here';"

kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE my_app_db TO my_app_user;"

# Create Kubernetes Secret for application
kubectl create secret generic my-app-db-credentials \
  --from-literal=username=my_app_user \
  --from-literal=password=secure_password_here \
  -n default
```

### Method B: Connection String (for libraries like psycopg2, JDBC)

```python
# Python example (psycopg2)
import psycopg2
import os

conn = psycopg2.connect(
    host=os.getenv("POSTGRES_HOST"),
    port=os.getenv("POSTGRES_PORT", 5432),
    user=os.getenv("POSTGRES_USER"),
    password=os.getenv("POSTGRES_PASSWORD"),
    database=os.getenv("POSTGRES_DB")
)

# Or using connection string
conn_string = f"postgresql://{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}@{os.getenv('POSTGRES_HOST')}:5432/my_app_db"
conn = psycopg2.connect(conn_string)
```

```java
// Java example (JDBC)
String url = "jdbc:postgresql://" + System.getenv("POSTGRES_HOST") + ":5432/my_app_db";
Connection conn = DriverManager.getConnection(
    url,
    System.getenv("POSTGRES_USER"),
    System.getenv("POSTGRES_PASSWORD")
);
```

---

## 3. Connect from Internal Network (Administrators)

### Using psql CLI

```bash
# Get the external IP and password
POSTGRES_EXTERNAL_IP=$(kubectl get svc -n postgresql postgres-ha-postgresql-external \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

POSTGRES_PASSWORD=$(kubectl get secret -n postgresql postgres-ha-postgresql-credentials \
  -o jsonpath="{.data.postgres-password}" | base64 -d)

# Connect to PostgreSQL
psql -h $POSTGRES_EXTERNAL_IP -p 5432 -U postgres -d postgres

# Enter password when prompted
```

### Using pgAdmin (GUI)

1. Open pgAdmin
2. Add New Server:
   - **Name**: Homelab PostgreSQL HA
   - **Host**: `<metallb-ip>` (e.g., `192.168.10.100`)
   - **Port**: `5432`
   - **Username**: `postgres`
   - **Password**: `<from-kubectl-command-above>`
3. Click Save

### Using DBeaver (GUI)

1. Create New Database Connection → PostgreSQL
2. Connection Settings:
   - **Host**: `<metallb-ip>` (e.g., `192.168.10.100`)
   - **Port**: `5432`
   - **Database**: `postgres`
   - **Username**: `postgres`
   - **Password**: `<from-kubectl-command-above>`
3. Test Connection → Finish

---

## 4. Common Database Operations

### Create a Database

```bash
# Via kubectl
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "CREATE DATABASE new_database OWNER postgres;"

# Via psql (connected to external endpoint)
CREATE DATABASE new_database OWNER postgres;
```

### Create a User with Limited Privileges

```bash
# Create user
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "CREATE USER app_user WITH PASSWORD 'secure_password';"

# Grant connect privilege
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "GRANT CONNECT ON DATABASE new_database TO app_user;"

# Grant table privileges (run AFTER connecting to the specific database)
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -d new_database -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;"
```

### List Databases and Users

```bash
# List databases
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "\l"

# List users/roles
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "\du"
```

### Check Database Size

```bash
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database ORDER BY pg_database_size(pg_database.datname) DESC;"
```

---

## 5. Monitoring and Troubleshooting

### View Cluster Metrics (Prometheus)

1. Access Grafana (deployed in feature 008 or similar)
2. Navigate to **PostgreSQL Overview** dashboard
3. Key metrics to monitor:
   - Active connections
   - Replication lag (should be < 1 second)
   - Query execution time
   - Storage utilization

### Check Logs

```bash
# Primary instance logs
kubectl logs -n postgresql postgres-ha-postgresql-0 -c postgresql

# Replica instance logs
kubectl logs -n postgresql postgres-ha-postgresql-1 -c postgresql

# PostgreSQL Exporter logs (metrics)
kubectl logs -n postgresql postgres-ha-postgresql-0 -c metrics
```

### Troubleshoot Connection Issues

**Symptom**: Cannot connect from application pod

```bash
# 1. Verify service DNS resolution
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup postgres-ha-postgresql.postgresql.svc.cluster.local

# 2. Test TCP connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nc -zv postgres-ha-postgresql.postgresql.svc.cluster.local 5432

# 3. Check pod readiness
kubectl get pods -n postgresql -o wide

# 4. Verify credentials
kubectl get secret -n postgresql postgres-ha-postgresql-credentials -o yaml
```

**Symptom**: Cannot connect from internal network

```bash
# 1. Verify LoadBalancer IP is assigned
kubectl get svc -n postgresql postgres-ha-postgresql-external

# 2. Test connectivity from internal network
ping <metallb-ip>
nc -zv <metallb-ip> 5432

# 3. Check FortiGate firewall rules (ensure port 5432 allowed from management VLAN)
# (Access FortiGate GUI or CLI to verify)

# 4. Verify MetalLB is running
kubectl get pods -n metallb-system
```

### Replication Lag Check

```bash
# Check replication lag (should be < 1 second)
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "SELECT application_name, state, sync_state, replay_lag FROM pg_stat_replication;"

# If lag is high, check network connectivity and replica logs
```

---

## 6. Backup and Restore

### Manual Backup (pg_dump)

```bash
# Backup a specific database
kubectl exec -n postgresql postgres-ha-postgresql-0 -- \
  pg_dump -U postgres -d my_app_db > backup_$(date +%Y%m%d).sql

# Backup all databases (cluster-wide)
kubectl exec -n postgresql postgres-ha-postgresql-0 -- \
  pg_dumpall -U postgres > backup_all_$(date +%Y%m%d).sql
```

### Restore from Backup

```bash
# Copy backup file to pod
kubectl cp backup_20251114.sql postgresql/postgres-ha-postgresql-0:/tmp/

# Restore database
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -d my_app_db -f /tmp/backup_20251114.sql

# Verify restore
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -d my_app_db -c "SELECT COUNT(*) FROM <table>;"
```

### Automated Backups (CronJob)

Automated backups are configured via CronJob (if enabled):

```bash
# Check backup CronJob status
kubectl get cronjob -n postgresql

# View backup job history
kubectl get jobs -n postgresql

# View backup logs
kubectl logs -n postgresql job/<backup-job-name>
```

---

## 7. Testing Failover (HA Verification)

### Simulate Primary Failure

```bash
# Delete primary pod (Kubernetes will restart it)
kubectl delete pod -n postgresql postgres-ha-postgresql-0

# Monitor pod recovery
kubectl get pods -n postgresql -w

# Verify connections still work (may have brief interruption)
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "SELECT 1;"
```

**Note**: Bitnami chart does NOT support automatic replica promotion. If primary is permanently lost, manual promotion is required. See runbook for full failover procedure.

---

## 8. Scaling and Performance

### Add Read Replicas (Horizontal Scaling)

```bash
# Edit Helm values to increase replica count
# (This requires updating ArgoCD Application or Helm values file)

# Example: Increase from 1 replica to 2 replicas
# Update values in kubernetes/applications/postgresql/values/postgresql-values.yaml:
#   replicaCount: 3  # (1 primary + 2 replicas)

# ArgoCD will detect change and sync automatically
# Or manually trigger sync:
argocd app sync postgresql-cluster
```

### Increase Resources (Vertical Scaling)

```bash
# Edit Helm values to increase CPU/memory limits
# Update values in kubernetes/applications/postgresql/values/postgresql-values.yaml:
#   resources:
#     limits:
#       cpu: 4        # Increase from 2 to 4 cores
#       memory: 8Gi   # Increase from 4Gi to 8Gi

# Trigger ArgoCD sync
argocd app sync postgresql-cluster

# Kubernetes will rolling-restart pods with new resource limits
```

---

## 9. Security Best Practices

### Rotate Passwords

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update Kubernetes Secret
kubectl patch secret -n postgresql postgres-ha-postgresql-credentials \
  --type merge \
  -p "{\"data\":{\"postgres-password\":\"$(echo -n $NEW_PASSWORD | base64)\"}}"

# Update PostgreSQL user password
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$NEW_PASSWORD';"

# Update application secrets accordingly
```

### Review User Privileges

```bash
# List all users and their privileges
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "\du"

# Review database access for specific user
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE grantee = 'app_user';"
```

### Enable TLS/SSL (Optional for Production)

TLS is not enabled by default for homelab simplicity. To enable:

1. Generate TLS certificates (self-signed or cert-manager)
2. Update Helm values to enable SSL:
   ```yaml
   tls:
     enabled: true
     certificatesSecret: postgres-tls-certs
   ```
3. Update client connection strings to use `sslmode=require`

---

## 10. Useful Commands Cheat Sheet

```bash
# Get postgres password
kubectl get secret -n postgresql postgres-ha-postgresql-credentials \
  -o jsonpath="{.data.postgres-password}" | base64 -d && echo

# Get external IP
kubectl get svc -n postgresql postgres-ha-postgresql-external \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Connect to primary via kubectl
kubectl exec -it -n postgresql postgres-ha-postgresql-0 -- psql -U postgres

# Port-forward to access via localhost (alternative to LoadBalancer)
kubectl port-forward -n postgresql svc/postgres-ha-postgresql 5432:5432
# Then: psql -h localhost -p 5432 -U postgres

# Check pod resource usage
kubectl top pods -n postgresql

# View replication status
kubectl exec -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check cluster health via ArgoCD
argocd app get postgresql-cluster

# Force ArgoCD sync
argocd app sync postgresql-cluster --prune

# View PostgreSQL configuration
kubectl exec -n postgresql postgres-ha-postgresql-0 -- \
  psql -U postgres -c "SHOW ALL;"
```

---

## Troubleshooting Quick Reference

| Problem | Diagnosis | Solution |
|---------|-----------|----------|
| Pods not starting | `kubectl describe pod -n postgresql postgres-ha-postgresql-0` | Check image pull, resource limits, PVC binding |
| High replication lag | `SELECT * FROM pg_stat_replication;` | Check network latency, disk I/O, replica load |
| Connection refused | `nc -zv <host> 5432` | Verify service, firewall rules, pod health |
| Out of disk space | `kubectl exec ... df -h /bitnami/postgresql` | Expand PVC or cleanup old data |
| Authentication failed | `kubectl get secret ... -o yaml` | Verify credentials match Secret, check pg_hba.conf |

---

## Next Steps

- **Configure Backups**: Set up automated backups via CronJob (see runbook)
- **Set Up Monitoring**: Configure Grafana alerts for replication lag, storage, connections
- **Deploy Application**: Connect your first application to the database
- **Test Failover**: Practice manual failover procedure (see runbook)
- **Review Security**: Rotate default passwords, create application-specific users

---

## References

- Full runbook: `docs/runbooks/postgresql-ha.md` (to be created)
- Architecture: `specs/011-postgresql-cluster/data-model.md`
- Service contracts: `specs/011-postgresql-cluster/contracts/postgresql-service.yaml`
- Bitnami PostgreSQL HA Chart: https://github.com/bitnami/charts/tree/main/bitnami/postgresql-ha
- PostgreSQL Documentation: https://www.postgresql.org/docs/16/

---

**Need Help?**
- Check logs: `kubectl logs -n postgresql postgres-ha-postgresql-0`
- Review metrics: Grafana PostgreSQL dashboard
- Consult runbook for detailed procedures
