# Beersystem Migration Module

OpenTofu module for migrating beersystem-backend from dedicated Redis to shared redis-shared service.

## Purpose

This module updates the beersystem-backend deployment to:
- Change REDIS_HOST from `redis.beersystem.svc.cluster.local` to `redis-shared-master.redis.svc.cluster.local`
- Add REDIS_PASSWORD authentication using redis-credentials secret
- Maintain all existing configuration (database, JWT, S3, etc.)

## Migration Strategy

**Planned Downtime Approach** (~5-10 minutes):

1. **Scale Down**: Set `replicas = 0` and apply
2. **Wait**: Verify all beersystem pods terminated
3. **Reconfigure**: Apply changes to Redis configuration
4. **Scale Up**: Set `replicas = 1` and apply
5. **Validate**: Run test-beersystem.sh to verify functionality

## Prerequisites

- redis-shared service deployed in `redis` namespace
- redis-credentials secret replicated to `beersystem` namespace
- Backup of original beersystem-backend deployment

## Usage

```hcl
module "beersystem_migration" {
  source = "../../modules/beersystem-migration"

  replicas           = 0  # Set to 0 for migration, then 1 to restore
  redis_host         = "redis-shared-master.redis.svc.cluster.local"
  redis_port         = "6379"
  redis_secret_name  = "redis-credentials"
  backend_image      = "992382722562.dkr.ecr.us-east-1.amazonaws.com/beer-awards-backend:staging"
}
```

## Migration Execution

### Step 1: Scale Down (DOWNTIME BEGINS)
```bash
# Set replicas = 0 in environment config
tofu apply
kubectl get pods -n beersystem -w  # Wait for termination
```

### Step 2: Apply Configuration Changes
```bash
# Configuration already applied when replicas set to 0
# No additional action needed
```

### Step 3: Scale Up (DOWNTIME ENDS)
```bash
# Set replicas = 1 in environment config
tofu apply
kubectl get pods -n beersystem -w  # Wait for Running status
```

### Step 4: Validate
```bash
./scripts/redis-shared/test-beersystem.sh
# Check health endpoint, Redis connection, logs
```

## Rollback Procedure

If migration fails:

```bash
# Scale down current deployment
kubectl scale deployment beersystem-backend -n beersystem --replicas=0

# Restore from backup
kubectl apply -f specs/013-redis-deployment/beersystem-backend-backup-original.yaml

# Verify restoration
kubectl get pods -n beersystem
./scripts/redis-shared/test-beersystem.sh
```

## Validation

After 24+ hours of stable operation:
1. Monitor beersystem logs: `kubectl logs -n beersystem -l component=backend --tail=100`
2. Check Redis connection: Verify REDIS_HOST in deployment
3. Validate functionality: Test beersystem API endpoints
4. Decommission old Redis: `kubectl delete deployment redis -n beersystem`

## Outputs

- `deployment_name`: Deployment being migrated
- `redis_host`: New Redis master DNS
- `current_replicas`: Current replica count
- `migration_label`: Label for tracking migration status
