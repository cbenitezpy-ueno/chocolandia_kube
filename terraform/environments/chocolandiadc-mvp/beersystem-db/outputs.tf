# Outputs from BeerSystem database provisioning

output "database_name" {
  description = "Name of the created database"
  value       = module.beersystem_db.database_name
}

output "database_owner" {
  description = "Owner of the database"
  value       = module.beersystem_db.database_owner
}

output "connection_string" {
  description = "PostgreSQL connection string for beersystem application (without password)"
  value       = "postgresql://${module.beersystem_db.db_user}@${var.postgres_host}:${var.postgres_port}/${module.beersystem_db.database_name}"
  sensitive   = true
}

output "db_host" {
  description = "Database host"
  value       = var.postgres_host
}

output "db_port" {
  description = "Database port"
  value       = var.postgres_port
}

output "db_user" {
  description = "Database user"
  value       = module.beersystem_db.db_user
}
