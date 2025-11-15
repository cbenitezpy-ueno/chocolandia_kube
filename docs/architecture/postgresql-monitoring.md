# PostgreSQL Cluster Monitoring

**Feature**: 011-postgresql-cluster-db
**Phase**: 7 - Observability & Monitoring
**Last Updated**: 2025-11-15

## Overview

This document describes the monitoring setup for the PostgreSQL HA cluster in the Chocolandia homelab. Monitoring is implemented using the Prometheus Operator stack with Grafana dashboards and alerting rules.

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│ PostgreSQL Pods                                                 │
│  ┌────────────────────┐         ┌────────────────────┐         │
│  │ Primary Pod        │         │ Read Replica Pod   │         │
│  │                    │         │                    │         │
│  │ ┌────────────────┐ │         │ ┌────────────────┐ │         │
│  │ │   PostgreSQL   │ │         │ │   PostgreSQL   │ │         │
│  │ │   (port 5432)  │ │         │ │   (port 5432)  │ │         │
│  │ └────────────────┘ │         │ └────────────────┘ │         │
│  │                    │         │                    │         │
│  │ ┌────────────────┐ │         │ ┌────────────────┐ │         │
│  │ │   Exporter     │ │         │ │   Exporter     │ │         │
│  │ │   (port 9187)  │ │         │ │   (port 9187)  │ │         │
│  │ └────────┬───────┘ │         │ └────────┬───────┘ │         │
│  └──────────│─────────┘         └──────────│─────────┘         │
│             │                               │                   │
└─────────────┼───────────────────────────────┼───────────────────┘
              │                               │
              │   ┌───────────────────────┐   │
              └──>│  ServiceMonitors      │<──┘
                  │  (CRDs)               │
                  └───────────┬───────────┘
                              │
              ┌───────────────▼───────────────┐
              │  Prometheus                   │
              │  - Scrapes metrics every 30s  │
              │  - Evaluates alerting rules   │
              │  - Stores time-series data    │
              └───────────┬───────────────────┘
                          │
              ┌───────────▼───────────────────┐
              │  Grafana                      │
              │  - Visualizes metrics         │
              │  - PostgreSQL HA Dashboard    │
              └───────────────────────────────┘
```

## Components

### PostgreSQL Exporter

**Container**: `metrics` (sidecar container in PostgreSQL pods)
**Image**: `docker.io/bitnami/postgres-exporter:latest`
**Port**: 9187
**Metrics Endpoint**: `http://<pod-ip>:9187/metrics`

The PostgreSQL Exporter collects database metrics including:
- Instance health (`pg_up`)
- Connection statistics (`pg_stat_activity_count`)
- Replication status (`pg_stat_replication_*`)
- Database statistics (`pg_stat_database_*`)
- Table and index statistics
- Lock counts and deadlocks
- Query performance metrics

**Verification**:
```bash
# Check exporter is running
kubectl get pods -n postgresql -o jsonpath='{.items[*].spec.containers[*].name}' | grep metrics

# Port-forward to access metrics
kubectl port-forward -n postgresql postgres-ha-postgresql-primary-0 9187:9187

# Fetch metrics
curl http://localhost:9187/metrics | head -50
```

### ServiceMonitors

**CRDs**: `monitoring.coreos.com/v1/ServiceMonitor`
**Namespace**: postgresql
**Count**: 2 (primary + read replica)

ServiceMonitors tell Prometheus how to discover and scrape PostgreSQL metrics endpoints.

**Configuration**:
- **Scrape Interval**: 30 seconds
- **Scrape Timeout**: 10 seconds
- **Endpoints**:
  - `postgres-ha-postgresql-primary-metrics:9187`
  - `postgres-ha-postgresql-read-metrics:9187`
- **Labels**: Matched by Prometheus selector

**Verification**:
```bash
# List ServiceMonitors
kubectl get servicemonitors -n postgresql

# View ServiceMonitor details
kubectl get servicemonitor -n postgresql postgres-ha-postgresql-primary -o yaml

# Check Prometheus is discovering targets
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus | grep "postgresql"
```

### PrometheusRule

**CRD**: `monitoring.coreos.com/v1/PrometheusRule`
**Name**: `postgres-ha-postgresql-alerts`
**Namespace**: postgresql
**Alert Groups**: 4

#### Alert Groups

**1. postgresql-instance-health** (Interval: 30s)

| Alert | Expression | Duration | Severity | Description |
|-------|------------|----------|----------|-------------|
| PostgreSQLDown | `pg_up == 0` | 1m | critical | PostgreSQL instance is down |
| PostgreSQLTooManyConnections | `(sum by (pod) (pg_stat_activity_count) / max by (pod) (pg_settings_max_connections) * 100) > 80` | 5m | warning | Connection usage >80% |
| PostgreSQLDeadLocks | `rate(pg_stat_database_deadlocks[5m]) > 0` | 2m | warning | Deadlocks detected |

**2. postgresql-replication** (Interval: 30s)

| Alert | Expression | Duration | Severity | Description |
|-------|------------|----------|----------|-------------|
| PostgreSQLReplicationLagHigh | `pg_replication_lag > 60` | 5m | warning | Replication lag >60 seconds |
| PostgreSQLReplicationLagCritical | `pg_replication_lag > 300` | 2m | critical | Replication lag >5 minutes |
| PostgreSQLReplicationStopped | `pg_stat_replication_pg_current_wal_lsn_bytes - pg_stat_replication_sent_lsn_bytes > 1e9` | 5m | critical | WAL lag >1GB |
| PostgreSQLNoReplicaConnected | `sum by (pod) (pg_stat_replication_pg_current_wal_lsn_bytes) == 0` | 5m | warning | No replica connected |

**3. postgresql-storage-performance** (Interval: 30s)

| Alert | Expression | Duration | Severity | Description |
|-------|------------|----------|----------|-------------|
| PostgreSQLHighDiskUsage | `((capacity - available) / capacity * 100) > 80` | 5m | warning | Disk usage >80% |
| PostgreSQLCriticalDiskUsage | `((capacity - available) / capacity * 100) > 90` | 2m | critical | Disk usage >90% |
| PostgreSQLSlowQueries | `rate(pg_stat_activity_max_tx_duration[5m]) > 300` | 5m | warning | Queries running >5 minutes |
| PostgreSQLCacheHitRatioLow | `((blks_hit) / (blks_hit + blks_read)) * 100 < 90` | 10m | warning | Cache hit ratio <90% |

**4. postgresql-transactions-locks** (Interval: 30s)

| Alert | Expression | Duration | Severity | Description |
|-------|------------|----------|----------|-------------|
| PostgreSQLTooManyLocks | `(locks_count / (max_locks_per_tx * max_conn)) > 0.8` | 5m | warning | Lock usage >80% |
| PostgreSQLRollbackRateHigh | `rate(xact_rollback[5m]) / rate(xact_commit[5m]) > 0.1` | 5m | warning | Rollback rate >10% |

**Verification**:
```bash
# List PrometheusRules
kubectl get prometheusrules -n postgresql

# View alert rules
kubectl get prometheusrule -n postgresql postgres-ha-postgresql-alerts -o yaml

# Check alerts in Prometheus UI
# Forward port to access Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/alerts
```

### Grafana Dashboard

**ConfigMap**: `postgresql-ha-grafana-dashboard`
**Namespace**: monitoring
**Dashboard UID**: `postgresql-ha-chocolandia`
**Auto-Discovery**: Enabled via `grafana_dashboard: "1"` label

#### Dashboard Panels

**Top Row (Statistics)**:
1. **PostgreSQL Status**: Shows UP/DOWN status with color coding
2. **Connection Usage**: Percentage of max connections used
3. **Replication Lag**: Current replication lag in seconds
4. **Cache Hit Ratio**: Percentage of queries served from cache

**Charts**:
1. **Active Connections**: Time series showing connection count per pod
2. **Replication Lag Over Time**: Tracks replication lag with thresholds
3. **Transaction Rate**: Commits and rollbacks per second
4. **Cache Hit Ratio Over Time**: Cache efficiency trend
5. **Storage Usage**: Disk usage percentage for PVCs
6. **Deadlock Rate**: Deadlocks per second per database
7. **Lock Count**: Active locks per pod

**Access**:
```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open http://localhost:3000
# Default credentials: admin / prom-operator
# Navigate to Dashboards → PostgreSQL HA Cluster
```

## Metrics Reference

### Key Metrics

#### Instance Health
- `pg_up`: 1 if PostgreSQL is up, 0 if down
- `pg_settings_max_connections`: Maximum allowed connections
- `pg_stat_activity_count`: Current active connections

#### Replication
- `pg_replication_lag`: Replication lag in seconds
- `pg_stat_replication_pg_current_wal_lsn_bytes`: Current WAL position
- `pg_stat_replication_sent_lsn_bytes`: WAL sent to replica
- `pg_stat_replication_replay_lag`: Time between write and replay

#### Database Statistics
- `pg_stat_database_xact_commit`: Committed transactions
- `pg_stat_database_xact_rollback`: Rolled back transactions
- `pg_stat_database_blks_hit`: Blocks served from cache
- `pg_stat_database_blks_read`: Blocks read from disk
- `pg_stat_database_deadlocks`: Number of deadlocks detected

#### Performance
- `pg_stat_activity_max_tx_duration`: Longest running transaction
- `pg_locks_count`: Current lock count
- `pg_settings_max_locks_per_transaction`: Maximum locks per transaction

#### Storage
- `kubelet_volume_stats_capacity_bytes`: PVC total capacity
- `kubelet_volume_stats_available_bytes`: PVC available space

### Metric Labels

All PostgreSQL metrics include these labels:
- `namespace`: Kubernetes namespace (postgresql)
- `pod`: Pod name
- `service`: Service name
- `datname`: Database name (for database-specific metrics)
- `application_name`: Replication client name

## Monitoring Workflows

### Daily Health Check

```bash
# 1. Check pod status
kubectl get pods -n postgresql

# 2. Check ServiceMonitors are discovered
kubectl get servicemonitors -n postgresql

# 3. Check for active alerts
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/alerts

# 4. View Grafana dashboard
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Visit http://localhost:3000 → Dashboards → PostgreSQL HA Cluster
```

### Investigating High Connection Usage

1. **Check alert in Prometheus** (if firing)
2. **View Grafana dashboard** → Active Connections panel
3. **Identify spike pattern** (time-based, sudden, gradual)
4. **Query active connections**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT datname, usename, application_name, state, query FROM pg_stat_activity WHERE state != 'idle';"
```
5. **Check for connection leaks** in application logs
6. **Review application connection pooling** configuration

### Investigating Replication Lag

1. **Check alert** → PostgreSQLReplicationLagHigh or PostgreSQLReplicationLagCritical
2. **View Grafana** → Replication Lag panel
3. **Check replication status**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT application_name, state, sync_state, write_lag, flush_lag, replay_lag FROM pg_stat_replication;"
```
4. **Check WAL lag**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) as pending_bytes FROM pg_stat_replication;"
```
5. **Review resource usage** (CPU, memory, disk I/O) on replica pod
6. **Check network connectivity** between primary and replica

### Investigating Storage Issues

1. **Check alert** → PostgreSQLHighDiskUsage or PostgreSQLCriticalDiskUsage
2. **View Grafana** → Storage Usage panel
3. **Check PVC status**:
```bash
kubectl get pvc -n postgresql
```
4. **Check disk usage**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -c postgresql -- df -h /bitnami/postgresql/data
```
5. **Identify large tables/indexes**:
```bash
kubectl exec -n postgresql postgres-ha-postgresql-primary-0 -- \
  psql -U postgres -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"
```
6. **Consider** vacuum, WAL archiving, or storage expansion

### Testing Alert Rules

#### Test PostgreSQLDown Alert

```bash
# Simulate PostgreSQL down by scaling StatefulSet to 0
kubectl scale statefulset -n postgresql postgres-ha-postgresql-primary --replicas=0

# Wait 1-2 minutes, check Prometheus alerts
# Alert should fire: PostgreSQLDown

# Restore
kubectl scale statefulset -n postgresql postgres-ha-postgresql-primary --replicas=1
```

#### Test Replication Lag Alert

```bash
# Create high write load to increase lag
kubectl run postgresql-load --rm -i --restart='Never' --namespace postgresql \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=$(kubectl get secret --namespace postgresql postgres-ha-postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)" \
  --command -- bash -c "
    for i in {1..10000}; do
      psql --host postgres-ha-postgresql-primary -U postgres -d app_db \
        -c \"INSERT INTO test_table (data) VALUES ('load_test_$i');\"
    done
  "

# Monitor lag in Grafana
# Alert should fire if lag exceeds 60 seconds
```

## Troubleshooting

### Problem: Metrics not appearing in Prometheus

**Diagnosis**:
```bash
# 1. Check exporter pods are running
kubectl get pods -n postgresql -o jsonpath='{.items[*].spec.containers[*].name}' | grep metrics

# 2. Test metrics endpoint
kubectl port-forward -n postgresql postgres-ha-postgresql-primary-0 9187:9187
curl http://localhost:9187/metrics

# 3. Check ServiceMonitor exists
kubectl get servicemonitors -n postgresql

# 4. Check Prometheus logs for errors
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus | grep postgresql
```

**Common Causes**:
- Exporter container not running
- ServiceMonitor not created
- Prometheus not configured to discover ServiceMonitors in `postgresql` namespace
- Network policy blocking access

### Problem: Dashboard not appearing in Grafana

**Diagnosis**:
```bash
# 1. Check ConfigMap exists
kubectl get configmap -n monitoring postgresql-ha-grafana-dashboard

# 2. Check ConfigMap has correct label
kubectl get configmap -n monitoring postgresql-ha-grafana-dashboard -o jsonpath='{.metadata.labels}'

# 3. Check Grafana sidecar is configured to load dashboards
kubectl get deployment -n monitoring kube-prometheus-stack-grafana -o yaml | grep -A 10 sidecar
```

**Resolution**:
1. Verify ConfigMap has label `grafana_dashboard: "1"`
2. Restart Grafana pod to reload dashboards:
```bash
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-grafana
```

### Problem: Alerts not firing

**Diagnosis**:
```bash
# 1. Check PrometheusRule exists
kubectl get prometheusrules -n postgresql

# 2. Check rule status in Prometheus UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/rules

# 3. Manually trigger alert condition and verify
```

**Common Causes**:
- Alert expression doesn't match actual metrics
- Alert duration (`for`) too long
- Prometheus not discovering PrometheusRule
- AlertManager not configured

## Maintenance

### Updating Alert Rules

1. Edit monitoring.tf or prometheus-rules.yaml
2. Apply changes:
```bash
# Via kubectl
kubectl apply -f /tmp/postgresql-prometheus-rules.yaml

# Or via Terraform (if dependency issue is fixed)
tofu apply -target=module.postgresql_cluster.kubernetes_manifest.postgresql_prometheus_rules
```
3. Verify rules loaded:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Check http://localhost:9090/rules
```

### Updating Grafana Dashboard

1. Edit grafana-dashboard.json or grafana-dashboard-configmap.yaml
2. Update ConfigMap:
```bash
kubectl apply -f terraform/modules/postgresql-cluster/grafana-dashboard-configmap.yaml
```
3. Restart Grafana to reload:
```bash
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-grafana
```

## Performance Considerations

### Metrics Cardinality

Current configuration generates metrics with these dimensions:
- **Pods**: 2 (primary + read replica)
- **Databases**: ~3-5 (postgres, app_db, template0, template1)
- **Metrics per pod**: ~200-300 time series

**Total cardinality**: ~500-1000 time series

This is well within acceptable limits for Prometheus (<10,000 recommended).

### Scrape Interval

**Current**: 30 seconds
**Rationale**: Balances freshness vs. load
- Database metrics don't change rapidly
- Alerts have 1-5 minute durations, 30s granularity is sufficient
- Lower interval (e.g., 15s) would double storage requirements

### Retention

Prometheus retention is configured in kube-prometheus-stack:
- **Default**: 10 days
- **Storage**: PVC-backed, sized appropriately

For long-term storage, consider:
- Thanos
- Cortex
- Victoria Metrics

## Related Documentation

- [PostgreSQL Module README](../../terraform/modules/postgresql-cluster/README.md)
- [Failover Procedures Runbook](../runbooks/postgresql-failover.md)
- [Feature Specification](../../specs/011-postgresql-cluster/spec.md)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [PostgreSQL Exporter Metrics](https://github.com/prometheus-community/postgres_exporter)

## References

- PostgreSQL Monitoring Best Practices: https://www.postgresql.org/docs/current/monitoring.html
- Prometheus Alerting Best Practices: https://prometheus.io/docs/practices/alerting/
- Grafana Dashboard Best Practices: https://grafana.com/docs/grafana/latest/best-practices/

## Validation

This monitoring setup has been tested and validated:

- ✅ PostgreSQL Exporter running on both primary and read replica
- ✅ ServiceMonitors created and discovered by Prometheus
- ✅ Prometheus successfully scraping metrics every 30 seconds
- ✅ PrometheusRule for alerts applied and loaded
- ✅ Grafana dashboard ConfigMap created
- ⏳ Dashboard visible in Grafana UI (pending Grafana sidecar reload)
- ⏳ Alert firing tested (pending simulation)

Last validation date: 2025-11-15
