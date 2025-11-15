# Output values from PostgreSQL database module

output "database_name" {
  description = "Name of the created database"
  value       = postgresql_database.db.name
}

output "database_owner" {
  description = "Owner/user of the database"
  value       = postgresql_role.db_user.name
}

output "db_user" {
  description = "Database user name"
  value       = postgresql_role.db_user.name
}
