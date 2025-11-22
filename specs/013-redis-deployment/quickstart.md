# Redis Deployment Quickstart Guide

**Feature**: 013-redis-deployment
**Date**: 2025-11-20
**Status**: Complete

## Overview

This guide provides step-by-step instructions for deploying, testing, and operating the Redis caching service in the chocolandia_kube homelab cluster.

**Deployment Summary**:
- 2 Redis instances (primary + replica)
- Cluster-internal access via ClusterIP service
- Private network access via LoadBalancer (192.168.4.203)
- Persistent storage (10Gi per instance)
- Prometheus monitoring integration

---

## Prerequisites

Before deploying Redis, verify the following:

### 1. Cluster Access

```bash
# Verify kubectl access
kubectl cluster-info

# Verify you're in the correct context
kubectl config current-context
# Expected: chocolandiadc-mvp or similar
```

### 2. MetalLB Availability

```bash
# Check MetalLB is deployed
kubectl get pods -n metallb-system

# Verify IP 192.168.4.203 is available
kubectl get svc -A | grep 192.168.4.203
# Should return no results (IP not in use)
```

### 3. Prometheus/Grafana

```bash
# Verify kube-prometheus-stack is deployed
kubectl get pods -n monitoring | grep prometheus

# Check Prometheus Operator CRDs
kubectl get servicemonitors -A
```

### 4. OpenTofu Configuration

```bash
# Ensure OpenTofu is installed
tofu version
# Expected: OpenTofu v1.6.x or higher

# Initialize OpenTofu (if not already done)
cd terraform/environments/chocolandiadc-mvp
tofu init
```

---

## Deployment Steps

### Phase 1: Create OpenTofu Module

#### 1.1 Create Module Directory Structure

```bash
cd /Users/cbenitez/chocolandia_kube

# Create module directory
mkdir -p terraform/modules/redis

# Create module files
touch terraform/modules/redis/main.tf
touch terraform/modules/redis/variables.tf
touch terraform/modules/redis/outputs.tf
touch terraform/modules/redis/locals.tf
touch terraform/modules/redis/versions.tf
touch terraform/modules/redis/secrets.tf
touch terraform/modules/redis/services.tf
```

#### 1.2 Populate Module Files

Copy the code from `data-model.md` into the respective files:

- `main.tf`: Helm release configuration
- `variables.tf`: Input variables
- `outputs.tf`: Module outputs
- `locals.tf`: Local values (common labels)
- `versions.tf`: Provider requirements
- `secrets.tf`: Kubernetes Secret and random password
- `services.tf`: LoadBalancer service for private network access

**File: `versions.tf`**

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
```

**File: `secrets.tf`**

```hcl
# Auto-generate Redis password
resource "random_password" "redis_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

# Kubernetes Secret for Redis credentials
resource "kubernetes_secret" "redis_credentials" {
  metadata {
    name      = "redis-credentials"
    namespace = var.namespace
    labels    = local.common_labels
  }

  data = {
    redis-password = random_password.redis_password.result
  }
}
```

**File: `services.tf`**

```hcl
# LoadBalancer service for private network access
resource "kubernetes_service" "redis_external" {
  metadata {
    name      = "redis-external"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "master"
    }
    annotations = {
      "metallb.universe.tf/address-pool" = var.metallb_ip_pool
    }
  }

  spec {
    type             = "LoadBalancer"
    load_balancer_ip = var.loadbalancer_ip

    port {
      name        = "tcp-redis"
      port        = 6379
      target_port = "redis"
      protocol    = "TCP"
    }

    selector = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "master"
    }
  }

  depends_on = [helm_release.redis]
}
```

#### 1.3 Create Environment Configuration

**File: `terraform/environments/chocolandiadc-mvp/redis.tf`**

```hcl
# Redis Deployment Module
module "redis" {
  source = "../../modules/redis"

  # Deployment configuration
  release_name      = "redis"
  chart_repository  = "https://charts.bitnami.com/bitnami"
  chart_version     = "23.2.12"
  namespace         = "default"

  # Storage configuration
  storage_class = "local-path"
  storage_size  = "10Gi"

  # HA configuration (1 primary + 1 replica = 2 total)
  replica_count = 1

  # Resource limits - Master
  master_cpu_request    = "500m"
  master_cpu_limit      = "1000m"
  master_memory_request = "1Gi"
  master_memory_limit   = "2Gi"

  # Resource limits - Replica
  replica_cpu_request    = "250m"
  replica_cpu_limit      = "1000m"
  replica_memory_request = "1Gi"
  replica_memory_limit   = "2Gi"

  # Monitoring
  enable_metrics         = true
  enable_service_monitor = true
  monitoring_namespace   = "monitoring"

  # Network access (private network LoadBalancer)
  loadbalancer_ip = "192.168.4.203"
  metallb_ip_pool = "eero-pool"

  # Redis configuration
  redis_config = <<-EOT
    maxmemory 1536mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly no
    loglevel notice
    slowlog-log-slower-than 10000
    slowlog-max-len 128
  EOT

  # Security - disable dangerous commands
  disable_commands = ["FLUSHDB", "FLUSHALL", "CONFIG", "SHUTDOWN"]

  helm_timeout = 600
}

# Output Redis connection details
output "redis_master_dns" {
  description = "Redis master ClusterIP DNS name"
  value       = module.redis.redis_master_service
}

output "redis_external_ip" {
  description = "Redis LoadBalancer IP (private network)"
  value       = module.redis.redis_external_ip
}

output "redis_password_secret" {
  description = "Kubernetes Secret containing Redis password"
  value       = module.redis.redis_secret_name
}
```

---

### Phase 2: Deploy Redis

#### 2.1 Validate OpenTofu Configuration

```bash
cd terraform/environments/chocolandiadc-mvp

# Format code
tofu fmt -recursive

# Validate configuration
tofu validate

# Expected output: "Success! The configuration is valid."
```

#### 2.2 Plan Deployment

```bash
# Generate plan
tofu plan -out=redis.tfplan

# Review plan output carefully
# Expected changes:
# - random_password.redis_password (create)
# - kubernetes_secret.redis_credentials (create)
# - helm_release.redis (create)
# - kubernetes_service.redis_external (create)
```

#### 2.3 Apply Deployment

```bash
# Apply the plan
tofu apply redis.tfplan

# Wait for deployment to complete (may take 2-5 minutes)
# Expected output: "Apply complete! Resources: 4 added, 0 changed, 0 destroyed."
```

#### 2.4 Verify Deployment

```bash
# Check Helm release
helm list -n default | grep redis

# Check pods
kubectl get pods -n default | grep redis

# Expected pods:
# - redis-master-0 (1/1 Running)
# - redis-replicas-0 (1/1 Running)

# Check services
kubectl get svc -n default | grep redis

# Expected services:
# - redis-master (ClusterIP)
# - redis-replicas (ClusterIP)
# - redis-external (LoadBalancer, 192.168.4.203)

# Check PVCs
kubectl get pvc -n default | grep redis

# Expected PVCs:
# - redis-data-redis-master-0 (10Gi, Bound)
# - redis-data-redis-replicas-0 (10Gi, Bound)
```

---

## Testing & Validation

### Test 1: Cluster-Internal Connectivity

#### 1.1 Deploy Test Pod

```bash
# Create temporary pod with redis-cli
kubectl run redis-client --rm -i --tty --image redis:8.2 -- bash

# Inside the pod, retrieve password from secret
REDIS_PASSWORD=$(kubectl get secret redis-credentials -o jsonpath='{.data.redis-password}' | base64 -d)

# Connect to Redis master (cluster-internal DNS)
redis-cli -h redis-master.default.svc.cluster.local -p 6379 -a $REDIS_PASSWORD

# Test commands
127.0.0.1:6379> PING
PONG

127.0.0.1:6379> SET test-key "Hello from cluster"
OK

127.0.0.1:6379> GET test-key
"Hello from cluster"

127.0.0.1:6379> INFO replication
# Replication
role:master
connected_slaves:1
slave0:ip=<replica-ip>,port=6379,state=online,offset=...,lag=0

127.0.0.1:6379> EXIT

# Exit pod
exit
```

**Expected Results**:
- ✅ PING returns PONG
- ✅ SET/GET operations succeed
- ✅ INFO replication shows 1 connected slave

---

### Test 2: Private Network Connectivity

#### 2.1 Connect from Private Network Host

```bash
# From a host on 192.168.4.0/24 network (e.g., your laptop)

# Retrieve password from cluster
export KUBECONFIG=/path/to/kubeconfig
REDIS_PASSWORD=$(kubectl get secret redis-credentials -n default -o jsonpath='{.data.redis-password}' | base64 -d)

# Connect to Redis via LoadBalancer IP
redis-cli -h 192.168.4.203 -p 6379 -a $REDIS_PASSWORD

# Test commands
192.168.4.203:6379> PING
PONG

192.168.4.203:6379> GET test-key
"Hello from cluster"

192.168.4.203:6379> EXIT
```

**Expected Results**:
- ✅ Connection succeeds from private network
- ✅ Data written in Test 1 is accessible
- ✅ Authentication works

#### 2.2 Test Authentication Rejection

```bash
# Attempt connection without password
redis-cli -h 192.168.4.203 -p 6379

192.168.4.203:6379> PING
(error) NOAUTH Authentication required.
```

**Expected Result**: ✅ Connection rejected without valid password

---

### Test 3: Replication Validation

#### 3.1 Test Primary-Replica Data Sync

```bash
# Connect to Redis master
kubectl run redis-client --rm -i --tty --image redis:8.2 -- bash

REDIS_PASSWORD=$(kubectl get secret redis-credentials -n default -o jsonpath='{.data.redis-password}' | base64 -d)

# Write data to master
redis-cli -h redis-master.default.svc.cluster.local -p 6379 -a $REDIS_PASSWORD SET repl-test "data-from-master"

# Read data from replica
redis-cli -h redis-replicas.default.svc.cluster.local -p 6379 -a $REDIS_PASSWORD GET repl-test
# Expected: "data-from-master"

# Check replication lag
redis-cli -h redis-master.default.svc.cluster.local -p 6379 -a $REDIS_PASSWORD INFO replication | grep lag
# Expected: lag=0 or lag=1 (minimal lag)

exit
```

**Expected Results**:
- ✅ Data written to master appears on replica
- ✅ Replication lag is minimal (<1 second)

---

### Test 4: Performance Validation

#### 4.1 Run redis-benchmark

```bash
# Retrieve password
REDIS_PASSWORD=$(kubectl get secret redis-credentials -n default -o jsonpath='{.data.redis-password}' | base64 -d)

# Run benchmark from within cluster
kubectl run redis-benchmark --rm -i --tty --image redis:8.2 -- redis-benchmark \
  -h redis-master.default.svc.cluster.local \
  -p 6379 \
  -a "$REDIS_PASSWORD" \
  -t set,get \
  -n 100000 \
  -c 50 \
  -q

# Expected output (example):
# SET: 15000.00 requests per second
# GET: 18000.00 requests per second
```

**Expected Results**:
- ✅ SET operations: >10,000 ops/sec (meets SC-006)
- ✅ GET operations: >10,000 ops/sec (meets SC-006)
- ✅ p95 latency: <10ms (meets SC-001)

---

### Test 5: Monitoring Validation

#### 5.1 Verify Prometheus Metrics

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser: http://localhost:9090

# Query Redis metrics:
# - redis_memory_used_bytes{service="redis-metrics"}
# - redis_connected_clients{service="redis-metrics"}
# - redis_commands_processed_total{service="redis-metrics"}
# - redis_connected_slaves{service="redis-metrics"}

# Verify metrics exist for both instances (master + replica)
```

**Expected Results**:
- ✅ Metrics appear in Prometheus within 30 seconds
- ✅ Both master and replica instances report metrics
- ✅ ServiceMonitor is auto-discovered

#### 5.2 Create Grafana Dashboard (Optional)

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open browser: http://localhost:3000
# Login: admin / (retrieve password from secret)
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d

# Import dashboard:
# 1. Click "+" → Import
# 2. Enter dashboard ID: 11835 (Redis Dashboard for Prometheus Redis Exporter)
# 3. Select Prometheus datasource
# 4. Click "Import"
```

**Expected Results**:
- ✅ Grafana dashboard displays Redis metrics
- ✅ Memory usage, connections, and ops/sec visible

---

## Operational Procedures

### Retrieve Redis Password

```bash
# From kubectl
kubectl get secret redis-credentials -n default -o jsonpath='{.data.redis-password}' | base64 -d

# From OpenTofu output (sensitive)
cd terraform/environments/chocolandiadc-mvp
tofu output -raw redis_password
```

### Scale Redis (Not Recommended)

Scaling to more than 1 replica violates spec requirement (FR-001: exactly 2 instances).

If scaling is needed in the future:

```bash
# Edit redis.tf
# Change: replica_count = 1 → replica_count = 2

# Apply changes
tofu apply
```

### Restart Redis Instances

```bash
# Restart master
kubectl rollout restart statefulset redis-master -n default

# Restart replicas
kubectl rollout restart statefulset redis-replicas -n default

# Check status
kubectl rollout status statefulset redis-master -n default
kubectl rollout status statefulset redis-replicas -n default
```

### Rotate Password

```bash
# 1. Update secret in OpenTofu (or manually)
# Option 1: Taint random_password to regenerate
tofu taint 'module.redis.random_password.redis_password'
tofu apply

# 2. Restart Redis pods to pick up new password
kubectl rollout restart statefulset redis-master -n default
kubectl rollout restart statefulset redis-replicas -n default

# 3. Update applications to use new password
```

### View Redis Logs

```bash
# Master logs
kubectl logs redis-master-0 -n default -c redis

# Replica logs
kubectl logs redis-replicas-0 -n default -c redis

# Follow logs
kubectl logs -f redis-master-0 -n default -c redis
```

### Access Redis CLI (Admin Tasks)

```bash
# Port-forward to local machine
kubectl port-forward redis-master-0 6379:6379 -n default

# In another terminal, connect locally
REDIS_PASSWORD=$(kubectl get secret redis-credentials -n default -o jsonpath='{.data.redis-password}' | base64 -d)
redis-cli -h localhost -p 6379 -a "$REDIS_PASSWORD"

# Run admin commands
127.0.0.1:6379> INFO stats
127.0.0.1:6379> SLOWLOG GET 10
127.0.0.1:6379> CLIENT LIST
```

---

## Beersystem Migration Rollback Procedure

This section documents the rollback procedure if the beersystem migration to redis-shared fails or causes issues.

### When to Rollback

Initiate rollback if any of these conditions occur:

1. **Health Checks Failing**: `/api/v1/health` endpoint returns errors after migration
2. **High Error Rate**: Backend logs show connection errors to Redis
3. **Authentication Failures**: NOAUTH or WRONGPASS errors in logs
4. **Application Not Starting**: Beersystem backend pods in CrashLoopBackOff
5. **Functional Testing Fails**: Core beersystem features not working after migration

### Rollback Decision Window

- **Immediate Rollback** (0-30 minutes): If migration causes immediate failures
- **Quick Rollback** (30 minutes - 4 hours): If issues discovered during validation
- **Considered Rollback** (4-24 hours): If performance degradation or intermittent issues detected
- **Full Analysis Required** (>24 hours): Requires investigation before rollback decision

---

### Method 1: Kubectl Restore (Fastest - 2-3 minutes)

Use this method for immediate rollback when speed is critical.

#### Step 1: Scale Down Current Deployment

```bash
# Scale down the migrated deployment
kubectl scale deployment beersystem-backend -n beersystem --replicas=0

# Wait for pods to terminate
kubectl get pods -n beersystem -w
# Press Ctrl+C when no backend pods remain
```

#### Step 2: Verify Old Redis is Still Running

```bash
# Check if original Redis deployment exists
kubectl get deployment redis -n beersystem

# Expected output:
# NAME    READY   UP-TO-DATE   AVAILABLE   AGE
# redis   1/1     1            1           XXd

# If Redis was already deleted, you need to restore it first:
kubectl apply -f specs/013-redis-deployment/beersystem-redis-backup-original.yaml
kubectl wait --for=condition=available deployment/redis -n beersystem --timeout=60s
```

#### Step 3: Restore Original Deployment

```bash
# Apply the backup deployment manifest
kubectl apply -f specs/013-redis-deployment/beersystem-backend-backup-original.yaml

# Wait for deployment to become available
kubectl rollout status deployment/beersystem-backend -n beersystem --timeout=120s

# Verify pod is running
kubectl get pods -n beersystem -l component=backend
```

#### Step 4: Validate Restoration

```bash
# Run beersystem validation tests
./scripts/redis-shared/test-beersystem.sh

# Check backend logs for errors
kubectl logs -n beersystem -l component=backend --tail=50

# Verify health endpoint
kubectl run curl-test \
  --namespace=beersystem \
  --image=curlimages/curl:latest \
  --restart=Never \
  --command -- curl -s http://beersystem-backend:3001/api/v1/health

# Expected response should contain: "status":"ok" or "status":"healthy"

# Cleanup test pod
kubectl delete pod curl-test -n beersystem
```

**Expected Recovery Time**: 2-3 minutes from Step 1 to operational backend

---

### Method 2: OpenTofu Rollback (Clean State - 5-10 minutes)

Use this method when you need to ensure Terraform state is consistent.

#### Step 1: Comment Out Migration Module

```bash
# Edit environment configuration
cd terraform/environments/chocolandiadc-mvp

# Edit beersystem-migration.tf
# Comment out the entire module block:
# module "beersystem_migration" {
#   source = "../../modules/beersystem-migration"
#   ...
# }
```

#### Step 2: Apply to Remove Migration

```bash
# Plan the removal
tofu plan -out=rollback.tfplan

# Review plan - should show destruction of beersystem-backend manifest
# Apply the plan
tofu apply rollback.tfplan
```

#### Step 3: Restore Original Deployment

```bash
# Verify old Redis is running
kubectl get deployment redis -n beersystem

# Restore original beersystem-backend
kubectl apply -f specs/013-redis-deployment/beersystem-backend-backup-original.yaml

# Wait for rollout
kubectl rollout status deployment/beersystem-backend -n beersystem
```

#### Step 4: Validate and Clean Up

```bash
# Run validation
./scripts/redis-shared/test-beersystem.sh

# Remove commented migration module from beersystem-migration.tf
# Or delete the file entirely if migration is permanently abandoned
```

**Expected Recovery Time**: 5-10 minutes from Step 1 to operational backend

---

### Method 3: Partial Rollback (Keep redis-shared Running)

Use this if other services are already using redis-shared successfully.

This method only rolls back beersystem while keeping redis-shared operational for future migrations.

#### Step 1: Scale Down Beersystem

```bash
# Scale down migrated beersystem
kubectl scale deployment beersystem-backend -n beersystem --replicas=0
kubectl get pods -n beersystem -w
```

#### Step 2: Update Deployment to Point Back to Old Redis

```bash
# Edit beersystem-migration.tf
cd terraform/environments/chocolandiadc-mvp

# Change replicas temporarily to 0
# module "beersystem_migration" {
#   ...
#   replicas = 0
# }

# Apply to ensure state is synchronized
tofu apply -auto-approve

# Now restore original deployment
kubectl apply -f specs/013-redis-deployment/beersystem-backend-backup-original.yaml
```

#### Step 3: Remove Migration Module from State

```bash
# Remove the migration module from Terraform state
tofu state rm module.beersystem_migration.kubernetes_manifest.beersystem_backend_patch

# Comment out or delete beersystem-migration.tf
```

#### Step 4: Keep redis-shared for Future Use

```bash
# Verify redis-shared is still operational
kubectl get pods -n redis
helm list -n redis | grep redis-shared

# redis-shared remains available for other applications or future retry
```

**Expected Recovery Time**: 5-7 minutes

---

### Post-Rollback Actions

After successful rollback, perform these actions:

#### 1. Incident Documentation

```bash
# Create incident report
cat > specs/013-redis-deployment/rollback-$(date +%Y%m%d-%H%M).md <<EOF
# Beersystem Migration Rollback Report

**Date**: $(date)
**Rollback Reason**: [Describe why rollback was needed]
**Rollback Method Used**: [Method 1, 2, or 3]
**Recovery Time**: [Actual time from detection to operational]

## Timeline
- [HH:MM] Migration executed
- [HH:MM] Issue detected: [Description]
- [HH:MM] Rollback initiated
- [HH:MM] Service restored

## Root Cause
[Describe what went wrong]

## Lessons Learned
[What to do differently next time]

## Next Steps
[How to prevent this issue in future migration attempts]
EOF
```

#### 2. Verify Beersystem Functionality

```bash
# Extended validation (5-10 minutes)
./scripts/redis-shared/test-beersystem.sh

# Monitor logs for 5 minutes
kubectl logs -n beersystem -l component=backend -f
# Press Ctrl+C after 5 minutes of clean logs

# Check metrics in Grafana (if available)
# - Request rate back to normal
# - Error rate returned to baseline
# - Response time within SLA
```

#### 3. Clean Up Migration Artifacts (Optional)

```bash
# If migration is permanently abandoned:

# Delete beersystem-migration.tf
rm terraform/environments/chocolandiadc-mvp/beersystem-migration.tf

# Remove migration module
rm -rf terraform/modules/beersystem-migration/

# Update tasks.md to mark migration as abandoned
# Document reason in specs/013-redis-deployment/spec.md
```

#### 4. Retain for Future Retry (Recommended)

```bash
# Keep migration artifacts for investigation and future retry:

# Keep backups
ls -lh specs/013-redis-deployment/*backup*.yaml

# Keep migration module for analysis
ls -lh terraform/modules/beersystem-migration/

# Keep validation scripts
ls -lh scripts/redis-shared/test-beersystem.sh

# Document issues found for next attempt
vim specs/013-redis-deployment/migration-issues.md
```

---

### Rollback Validation Checklist

After rollback, verify all items before considering rollback complete:

- [ ] **Backend Pods Running**: `kubectl get pods -n beersystem -l component=backend` shows 1/1 Ready
- [ ] **Health Endpoint Responding**: `/api/v1/health` returns 200 OK
- [ ] **Redis Connection Working**: Backend logs show successful Redis connection
- [ ] **No Errors in Logs**: Last 100 log lines show no ERROR or FATAL messages
- [ ] **Original Redis Running**: `kubectl get deployment redis -n beersystem` shows 1/1 Ready
- [ ] **Environment Variables Correct**: `REDIS_HOST=redis.beersystem.svc.cluster.local`
- [ ] **Database Connection Working**: Backend can query PostgreSQL successfully
- [ ] **Frontend Accessible**: Beersystem frontend loads and can communicate with backend
- [ ] **Core Features Working**: Login, data retrieval, basic operations functional
- [ ] **5-Minute Stability**: No crashes or restarts for 5 continuous minutes

**All items must be checked before declaring rollback successful.**

---

### Prevention for Next Migration Attempt

Before retrying migration, address these items:

1. **Test in Staging First**: If production, deploy to staging environment first
2. **Gradual Traffic Shift**: Consider using multiple replicas with gradual cutover
3. **Extended Monitoring**: Set up alerts before migration (error rate, latency)
4. **Dry Run**: Test migration module with `replicas=0` first to verify config
5. **Backup Verification**: Ensure backups are restorable before starting
6. **Communication Plan**: Notify users of maintenance window
7. **Rollback Rehearsal**: Practice rollback procedure before actual migration

---

## Troubleshooting

### Issue 1: Pod Not Starting

**Symptoms**: Redis pod stuck in `Pending` or `CrashLoopBackOff`

**Diagnosis**:

```bash
# Check pod events
kubectl describe pod redis-master-0 -n default

# Check logs
kubectl logs redis-master-0 -n default -c redis
```

**Common Causes**:
1. **PVC not bound**: Check `kubectl get pvc` - ensure local-path-provisioner is working
2. **Resource limits**: Check node capacity - may need to reduce CPU/memory limits
3. **Secret missing**: Ensure `redis-credentials` secret exists

**Resolution**:

```bash
# Delete pod to force restart
kubectl delete pod redis-master-0 -n default

# If PVC issue, check local-path-provisioner
kubectl get pods -n kube-system | grep local-path
```

---

### Issue 2: Cannot Connect from Cluster

**Symptoms**: `redis-cli` fails with connection timeout

**Diagnosis**:

```bash
# Check service
kubectl get svc redis-master -n default

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup redis-master.default.svc.cluster.local
```

**Resolution**:
- Ensure service exists and has endpoints: `kubectl get endpoints redis-master -n default`
- Verify pod is running: `kubectl get pods -n default | grep redis`

---

### Issue 3: LoadBalancer IP Not Assigned

**Symptoms**: `redis-external` service shows `<pending>` for EXTERNAL-IP

**Diagnosis**:

```bash
# Check MetalLB
kubectl get pods -n metallb-system

# Check service events
kubectl describe svc redis-external -n default
```

**Resolution**:

```bash
# Verify MetalLB speaker pods are running
kubectl get pods -n metallb-system

# Check IP pool configuration
kubectl get ipaddresspool -n metallb-system

# Manually assign IP if needed
kubectl patch svc redis-external -n default -p '{"spec":{"loadBalancerIP":"192.168.4.203"}}'
```

---

### Issue 4: Metrics Not Appearing in Prometheus

**Symptoms**: No Redis metrics in Prometheus

**Diagnosis**:

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n monitoring | grep redis

# Check metrics endpoint
kubectl get svc -n default | grep metrics
kubectl port-forward redis-master-0 9121:9121 -n default
curl http://localhost:9121/metrics
```

**Resolution**:

```bash
# Verify ServiceMonitor has correct labels
kubectl get servicemonitor redis-metrics -n monitoring -o yaml

# Ensure Prometheus can scrape (check Prometheus targets)
# Open Prometheus UI → Status → Targets
# Look for "redis-metrics" target
```

---

### Issue 5: Replication Not Working

**Symptoms**: Replica shows `master_link_status:down` in INFO replication

**Diagnosis**:

```bash
# Check replica logs
kubectl logs redis-replicas-0 -n default -c redis

# Check replication status from master
kubectl exec redis-master-0 -n default -- redis-cli -a "$REDIS_PASSWORD" INFO replication
```

**Common Causes**:
1. Network policy blocking traffic
2. Password mismatch
3. Master not accessible from replica

**Resolution**:

```bash
# Restart replica pod
kubectl delete pod redis-replicas-0 -n default

# Verify network connectivity
kubectl exec redis-replicas-0 -n default -- ping redis-master.default.svc.cluster.local
```

---

## Cleanup (Uninstall)

### Remove Redis Deployment

```bash
cd terraform/environments/chocolandiadc-mvp

# Destroy resources
tofu destroy -target=module.redis

# Confirm destruction
# Type "yes" when prompted

# Verify removal
kubectl get all -n default | grep redis
# Should return no results

# PVCs may need manual cleanup
kubectl delete pvc redis-data-redis-master-0 -n default
kubectl delete pvc redis-data-redis-replicas-0 -n default
```

---

## Connection Examples (Applications)

### Python (redis-py)

```python
import redis

# Connect to Redis (cluster-internal)
r = redis.Redis(
    host='redis-master.default.svc.cluster.local',
    port=6379,
    password='<password-from-secret>',
    decode_responses=True
)

# Test connection
r.ping()  # Returns True

# Set/Get example
r.set('mykey', 'myvalue')
value = r.get('mykey')  # Returns 'myvalue'
```

### Node.js (ioredis)

```javascript
const Redis = require('ioredis');

const redis = new Redis({
  host: 'redis-master.default.svc.cluster.local',
  port: 6379,
  password: '<password-from-secret>',
});

// Test connection
await redis.ping();  // Returns 'PONG'

// Set/Get example
await redis.set('mykey', 'myvalue');
const value = await redis.get('mykey');  // Returns 'myvalue'
```

### Kubernetes Environment Variable Injection

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: my-app:latest
    env:
    - name: REDIS_HOST
      value: "redis-master.default.svc.cluster.local"
    - name: REDIS_PORT
      value: "6379"
    - name: REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: redis-credentials
          key: redis-password
```

---

## Summary

This quickstart guide covers:

1. ✅ **Prerequisites verification** (cluster, MetalLB, Prometheus)
2. ✅ **Deployment steps** (OpenTofu module creation, planning, applying)
3. ✅ **Testing & validation** (connectivity, replication, performance, monitoring)
4. ✅ **Operational procedures** (password retrieval, scaling, restart, rotation)
5. ✅ **Troubleshooting** (common issues and resolutions)
6. ✅ **Application integration** (connection examples)

**Next Steps**:
- Run `/speckit.tasks` to generate implementation tasks (tasks.md)
- Execute deployment following Phase 1 and Phase 2 steps above
- Validate all success criteria (SC-001 to SC-008) via Test 1-5

**Support**:
- Refer to `research.md` for technology decisions
- Refer to `data-model.md` for configuration schema
- Refer to Bitnami Redis chart docs: https://github.com/bitnami/charts/tree/main/bitnami/redis
