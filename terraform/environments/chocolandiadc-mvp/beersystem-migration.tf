# Beersystem Migration Configuration
# Migrates beersystem-backend from dedicated Redis to redis-shared
#
# MIGRATION INSTRUCTIONS:
# 1. Set replicas = 0 and apply (DOWNTIME BEGINS ~5-10 min)
# 2. Wait for pods to terminate: kubectl get pods -n beersystem -w
# 3. Set replicas = 1 and apply (DOWNTIME ENDS)
# 4. Validate: ./scripts/redis-shared/test-beersystem.sh
# 5. Monitor for 24+ hours before decommissioning old Redis

module "beersystem_migration" {
  source = "../../modules/beersystem-migration"

  # MIGRATION CONTROL: Set to 0 for downtime, then 1 to restore
  replicas = 0  # MIGRATION STEP 1: Scale down for reconfiguration

  # Redis shared service configuration
  redis_host        = "redis-shared-master.redis.svc.cluster.local"
  redis_port        = "6379"
  redis_secret_name = "redis-credentials"

  # Backend image (from original deployment backup)
  backend_image = "992382722562.dkr.ecr.us-east-1.amazonaws.com/beer-awards-backend:staging"
}

# Output migration status
output "beersystem_migration_status" {
  description = "Current status of beersystem migration to redis-shared"
  value = {
    deployment      = module.beersystem_migration.deployment_name
    namespace       = module.beersystem_migration.namespace
    replicas        = module.beersystem_migration.current_replicas
    redis_endpoint  = "${module.beersystem_migration.redis_host}:${module.beersystem_migration.redis_port}"
    migration_label = module.beersystem_migration.migration_label
  }
}
