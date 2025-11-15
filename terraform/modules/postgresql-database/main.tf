# PostgreSQL Database Module
# Creates database, user, and grants privileges for application deployment

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.21"
    }
  }
}

# Create database user/role
resource "postgresql_role" "db_user" {
  name     = var.db_user
  login    = true
  password = var.db_password
}

# Create database
resource "postgresql_database" "db" {
  name              = var.db_name
  owner             = postgresql_role.db_user.name
  encoding          = "UTF8"
  lc_collate        = "en_US.UTF-8"
  lc_ctype          = "en_US.UTF-8"
  template          = "template0"
  connection_limit  = -1  # Unlimited connections
}

# Grant database-level privileges
resource "postgresql_grant" "db_privileges" {
  database    = postgresql_database.db.name
  role        = postgresql_role.db_user.name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE", "TEMPORARY"]
}

# Grant schema-level privileges
resource "postgresql_grant" "schema_privileges" {
  database    = postgresql_database.db.name
  role        = postgresql_role.db_user.name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

# Grant privileges on all current tables
resource "postgresql_grant" "table_privileges" {
  database    = postgresql_database.db.name
  role        = postgresql_role.db_user.name
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}

# Grant privileges on all current sequences
resource "postgresql_grant" "sequence_privileges" {
  database    = postgresql_database.db.name
  role        = postgresql_role.db_user.name
  schema      = "public"
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT", "UPDATE"]
}

# Default privileges for future tables
resource "postgresql_default_privileges" "default_table_privileges" {
  database    = postgresql_database.db.name
  role        = postgresql_role.db_user.name
  schema      = "public"
  owner       = postgresql_role.db_user.name
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}

# Default privileges for future sequences
resource "postgresql_default_privileges" "default_sequence_privileges" {
  database    = postgresql_database.db.name
  role        = postgresql_role.db_user.name
  schema      = "public"
  owner       = postgresql_role.db_user.name
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT", "UPDATE"]
}
