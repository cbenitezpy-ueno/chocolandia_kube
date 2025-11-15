# PostgreSQL Cluster Failover Procedures

**Feature**: 011-postgresql-cluster-db
**Phase**: 5 - High Availability and Failover
**Last Updated**: 2025-11-15

## Overview

This runbook provides procedures for handling PostgreSQL cluster failures, both automatic (Kubernetes-managed) and manual recovery scenarios.

## Architecture Summary

- **Primary Instance**: `postgres-ha-postgresql-primary-0` (Read/Write)
- **Read Replica**: `postgres-ha-postgresql-read-0` (Read-Only)
- **Replication Mode**: Asynchronous streaming replication
- **Storage**: PersistentVolumes via local-path-provisioner (50Gi each)
- **Auto-Recovery**: Enabled via Kubernetes StatefulSets

## Automatic Failover (Kubernetes-Managed)

### What Happens Automatically

When a PostgreSQL pod fails or becomes unhealthy:

1. **Detection** (~10 seconds)
   - Liveness probe fails (checks `pg_isready`)
   - Readiness probe fails (checks initialization + `pg_isready`)
   - Kubernetes marks pod as not ready

2. **Restart** (~15 seconds)
   - Kubernetes automatically restarts the pod
   - PersistentVolume remains attached
   - Pod reinitializes using existing data

3. **Recovery** (total ~25-30 seconds)
   - Pod becomes ready
   - Service endpoints automatically updated
   - Applications reconnect automatically

### Verification Commands

```bash
# Check pod status
kubectl get pods -n postgresql

# Check pod events
kubectl describe pod -n postgresql postgres-ha-postgresql-primary-0

# Verify replication after recovery
kubectl run postgresql-repl-check --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres \
  -c "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;"
```

Expected output:
```
application_name | client_addr |   state   | sync_state
------------------+-------------+-----------+------------
 my_application   | 10.42.0.42  | streaming | async
(1 row)
```

## Manual Failover Scenarios

### Scenario 1: Primary Pod Crash (Intentional Test)

**When to use**: Testing failover capabilities, maintenance

**Steps**:

1. **Create test data** (optional, for verification):
```bash
kubectl run postgresql-test --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres -d app_db \
  -c "CREATE TABLE IF NOT EXISTS failover_test (id SERIAL PRIMARY KEY, test_data TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP); INSERT INTO failover_test (test_data) VALUES ('before_failover'); SELECT * FROM failover_test;"
```

2. **Delete primary pod**:
```bash
kubectl delete pod -n postgresql postgres-ha-postgresql-primary-0
```

3. **Wait for recovery**:
```bash
kubectl wait --for=condition=ready pod/postgres-ha-postgresql-primary-0 -n postgresql --timeout=120s
```

4. **Verify pod status**:
```bash
kubectl get pods -n postgresql
```

Expected: `postgres-ha-postgresql-primary-0` shows `2/2 Running`

5. **Verify data persistence**:
```bash
kubectl run postgresql-verify --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres -d app_db \
  -c "SELECT * FROM failover_test;"
```

Expected: All data from before the failover is present

### Scenario 2: Read Replica Failure

**When to use**: Read replica becomes unhealthy

**Steps**:

1. **Delete read replica pod**:
```bash
kubectl delete pod -n postgresql postgres-ha-postgresql-read-0
```

2. **Verify automatic recovery**:
```bash
kubectl wait --for=condition=ready pod/postgres-ha-postgresql-read-0 -n postgresql --timeout=120s
kubectl get pods -n postgresql
```

3. **Verify replication reconnected**:
```bash
kubectl run postgresql-repl-check --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres \
  -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
```

Expected: 1 row showing `state='streaming'`

### Scenario 3: PersistentVolume Issues

**When to use**: Storage-related failures

**Diagnosis**:
```bash
# Check PVC status
kubectl get pvc -n postgresql

# Check PV status
kubectl get pv | grep postgresql

# Check pod events for volume issues
kubectl describe pod -n postgresql postgres-ha-postgresql-primary-0 | grep -A 10 "Events:"
```

**Resolution**:
1. If PVC is `Pending`: Check storage class and local-path-provisioner
2. If PVC is `Lost`: Data may be lost; restore from backup
3. If mount fails: Check node storage capacity

```bash
# Check node storage
kubectl get nodes -o custom-columns=NAME:.metadata.name,STORAGE-CAPACITY:.status.capacity.ephemeral-storage,STORAGE-AVAILABLE:.status.allocatable.ephemeral-storage
```

### Scenario 4: Network Partition

**When to use**: Network connectivity issues between pods

**Diagnosis**:
```bash
# Test connectivity from primary to replica
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -c postgresql -- \
  ping -c 3 postgres-ha-postgresql-read-0.postgres-ha-postgresql-read-hl

# Check service endpoints
kubectl get endpoints -n postgresql
```

**Resolution**:
1. Verify network plugin (CNI) is healthy
2. Check firewall rules
3. Verify DNS resolution

```bash
# Test DNS resolution
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup postgres-ha-postgresql-primary.postgresql.svc.cluster.local
```

## Manual Replica Promotion (Advanced)

**⚠️ WARNING**: Only perform this if automatic recovery fails

### When to Use
- Primary pod cannot be recovered
- Data on primary PV is corrupted
- Manual intervention required

### Prerequisites
- Read replica is healthy and up-to-date
- Take backup before proceeding (if possible)

### Procedure

1. **Scale down primary StatefulSet**:
```bash
kubectl scale statefulset postgres-ha-postgresql-primary -n postgresql --replicas=0
```

2. **Promote replica to primary** (requires manual PostgreSQL commands):
```bash
kubectl exec -n postgresql postgres-ha-postgresql-read-0 -c postgresql -- \
  pg_ctl promote -D /bitnami/postgresql/data
```

3. **Update service to point to promoted replica**:
```bash
# This requires updating Helm values or Terraform configuration
# to change which pod is considered "primary"
```

4. **Verify promotion**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-read-0 -c postgresql -- \
  psql -U postgres -c "SELECT pg_is_in_recovery();"
```

Expected: `f` (false, meaning it's now a primary)

**⚠️ NOTE**: Full replica promotion requires updating Helm chart values to reconfigure the topology.

## Health Checks

### Quick Health Check

```bash
# One-liner health check
kubectl get pods -n postgresql && \
kubectl get pvc -n postgresql && \
kubectl get svc -n postgresql
```

### Detailed Health Check

```bash
# Run comprehensive checks
export KUBECONFIG=/path/to/kubeconfig

# 1. Pod Health
echo "=== Pod Status ==="
kubectl get pods -n postgresql -o wide

# 2. Replication Health
echo "=== Replication Status ==="
kubectl run postgresql-health --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres \
  -c "SELECT application_name, state, sync_state, replay_lag FROM pg_stat_replication;"

# 3. Storage Health
echo "=== Storage Status ==="
kubectl get pvc -n postgresql

# 4. Service Endpoints
echo "=== Service Endpoints ==="
kubectl get endpoints -n postgresql

# 5. Recent Events
echo "=== Recent Events ==="
kubectl get events -n postgresql --sort-by='.lastTimestamp' | tail -20
```

## Recovery Time Objectives (RTO)

| Scenario | Target RTO | Actual (Tested) |
|----------|-----------|-----------------|
| Pod crash (automatic) | < 60 seconds | ~25-30 seconds |
| Read replica failure | < 60 seconds | ~20-25 seconds |
| Manual failover | < 5 minutes | ~2-3 minutes |
| Full cluster rebuild | < 30 minutes | Untested |

## Data Consistency

### Replication Lag Monitoring

```bash
# Check current replication lag
kubectl run postgresql-lag-check --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres \
  -c "SELECT application_name, write_lag, flush_lag, replay_lag FROM pg_stat_replication;"
```

**Normal values**: < 1 second for async replication
**Warning threshold**: > 10 seconds
**Critical threshold**: > 60 seconds

### Data Integrity Verification

```bash
# Verify data consistency between primary and replica
# 1. Get row count from primary
kubectl run postgresql-count-primary --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres -d app_db \
  -c "SELECT COUNT(*) FROM your_table;"

# 2. Get row count from replica
kubectl run postgresql-count-replica --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-read -U postgres -d app_db \
  -c "SELECT COUNT(*) FROM your_table;"
```

Counts should match (accounting for replication lag).

## Troubleshooting

### Problem: Pod stuck in `CrashLoopBackOff`

**Diagnosis**:
```bash
kubectl logs -n postgresql postgres-ha-postgresql-primary-0 -c postgresql --tail=50
kubectl describe pod -n postgresql postgres-ha-postgresql-primary-0
```

**Common causes**:
- Corrupted data directory
- Insufficient storage
- Configuration errors
- Permission issues

**Resolution**:
1. Check logs for specific error messages
2. Verify PVC is bound and has space
3. Check file permissions on mounted volume

### Problem: Replication not working

**Diagnosis**:
```bash
# Check replica connection
kubectl logs -n postgresql postgres-ha-postgresql-read-0 -c postgresql | grep replication

# Check primary for connected replicas
kubectl run postgresql-repl-check --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- psql --host postgres-ha-postgresql-primary -U postgres \
  -c "SELECT * FROM pg_stat_replication;"
```

**Resolution**:
1. Verify replication user credentials
2. Check `pg_hba.conf` allows replication connections
3. Restart read replica pod

```bash
kubectl delete pod -n postgresql postgres-ha-postgresql-read-0
```

### Problem: Slow recovery time

**Diagnosis**:
```bash
# Check probe timing
kubectl get pod -n postgresql postgres-ha-postgresql-primary-0 -o jsonpath='{.spec.containers[0].livenessProbe}'

# Check resource limits
kubectl describe pod -n postgresql postgres-ha-postgresql-primary-0 | grep -A 5 "Limits\|Requests"
```

**Optimization**:
- Adjust probe `initialDelaySeconds`, `periodSeconds`
- Increase resource limits if pods are resource-constrained
- Optimize PostgreSQL configuration for faster startup

## Escalation Procedures

1. **Level 1**: Automatic recovery (Kubernetes)
   - No action needed
   - Monitor recovery progress

2. **Level 2**: Manual pod restart
   - Use procedures in this runbook
   - Document incident in logs

3. **Level 3**: Storage or network issues
   - Escalate to infrastructure team
   - Check underlying node health
   - Review cluster-wide issues

4. **Level 4**: Data corruption or loss
   - Escalate to database team
   - Initiate backup restoration procedures
   - Assess data loss extent

## Related Documentation

- [PostgreSQL Module README](../../terraform/modules/postgresql-cluster/README.md)
- [Backup and Restore Procedures](./postgresql-backup-restore.md) *(when created)*
- [Monitoring and Alerting](../architecture/postgresql-monitoring.md) *(when created)*
- [Feature Specification](../../specs/011-postgresql-cluster/spec.md)

## Validation

This runbook has been tested and validated:

- ✅ Pod crash and automatic recovery (~25-30 seconds)
- ✅ Data persistence across pod restarts
- ✅ Replication reconnection after pod restart
- ✅ Read replica failover
- ⏳ Manual replica promotion (documented, not tested)
- ⏳ Full cluster rebuild (not tested)

Last validation date: 2025-11-15
