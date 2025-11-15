# PostgreSQL Cluster Module - Secrets Management
# Feature 011: PostgreSQL Cluster Database Service
#
# Generates random passwords and creates Kubernetes Secrets for PostgreSQL credentials

# ==============================================================================
# Random Password Generation (T013)
# ==============================================================================

# Generate random password for postgres superuser
resource "random_password" "postgres_password" {
  count = var.create_random_passwords ? 1 : 0

  length  = 32
  special = true
  # Avoid characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Generate random password for replication user
resource "random_password" "replication_password" {
  count = var.create_random_passwords ? 1 : 0

  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ==============================================================================
# Kubernetes Secret for PostgreSQL Credentials (T014)
# ==============================================================================

resource "kubernetes_secret" "postgresql_credentials" {
  metadata {
    name      = "${var.release_name}-postgresql-credentials"
    namespace = var.namespace
    labels    = local.common_labels
  }

  data = {
    # Postgres superuser password
    postgres-password = var.create_random_passwords ? random_password.postgres_password[0].result : var.postgres_password
    password          = var.create_random_passwords ? random_password.postgres_password[0].result : var.postgres_password  # Alias for chart compatibility

    # Replication user password
    replication-password = var.create_random_passwords ? random_password.replication_password[0].result : var.replication_password
    repmgr-password      = var.create_random_passwords ? random_password.replication_password[0].result : var.replication_password  # For repmgr
  }

  type = "Opaque"
}

# ==============================================================================
# Outputs for Secret Access
# ==============================================================================

# Note: These are internal to the module and used by postgresql.tf
# External outputs are in outputs.tf
