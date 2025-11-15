# BeerSystem Database Provisioning
# Creates beersystem_stage database and beersystem_admin user

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.21"
    }
  }
}

# Configure PostgreSQL provider to connect to cluster
provider "postgresql" {
  host            = var.postgres_host
  port            = var.postgres_port
  username        = var.postgres_admin_user
  password        = var.postgres_admin_password
  sslmode         = "require"
  connect_timeout = 15
  superuser       = false
}

# Use the postgresql-database module
module "beersystem_db" {
  source = "../../../modules/postgresql-database"

  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
}
