# Data Model: BeerSystem Database

**Feature**: 012-beersystem-deployment
**Date**: 2025-11-15
**Database**: beersystem_stage (PostgreSQL)

## Overview

This document defines the database provisioning requirements for the BeerSystem application deployment. The focus is on creating the database infrastructure (database, user, privileges) rather than application schema, as the application schema already exists in the beersystem codebase.

## Database Infrastructure Requirements

### Database Instance

**Name**: `beersystem_stage`
**Owner**: `beersystem_admin` (database administrator user)
**Character Encoding**: UTF-8
**Collation**: en_US.UTF-8 (or cluster default)
**Template**: template0 (clean template)

**Purpose**: Dedicated database for beersystem staging environment, isolated from other applications.

### Database Users and Roles

#### 1. beersystem_admin (Administrative User)

**Username**: `beersystem_admin`
**Purpose**: Database administrator with full DDL/DML privileges for schema management
**Authentication**: Password-based (password stored in Kubernetes Secret)

**Privileges**:
- `CONNECT` on database `beersystem_stage`
- `CREATE` on schema `public` (create tables, indexes, views, etc.)
- `ALL PRIVILEGES` on all tables in schema `public` (current and future)
- `ALL PRIVILEGES` on all sequences in schema `public` (current and future)
- `USAGE` on schema `public`

**Justification**: Required per FR-004 - "System MUST create a database user with privileges to perform schema modifications (CREATE, ALTER, DROP operations)"

**Usage**:
- Application database migrations (schema changes, table alterations)
- Development and staging operations (schema evolution during feature development)
- Data model updates (adding columns, indexes, constraints)

**Security Note**:
- Not a SUPERUSER (no cluster-wide privileges)
- Limited to beersystem_stage database only
- Cannot create/drop databases or modify other databases
- Cannot create roles or manage replication

#### 2. beersystem_app (Application Runtime User - Future Enhancement)

*Not in scope for MVP but documented for future implementation:*

**Username**: `beersystem_app`
**Purpose**: Limited runtime user for application queries (least privilege principle)
**Privileges**: `SELECT`, `INSERT`, `UPDATE`, `DELETE` on application tables (no DDL)

**Rationale for deferral**: For staging environment MVP, using `beersystem_admin` for both schema management and application runtime is acceptable. For production, should create separate runtime user with read/write only (no DDL).

## Connection Details

**Host**: PostgreSQL cluster service endpoint from feature 011
- Kubernetes service: `postgres-rw.postgres.svc.cluster.local` (assuming CloudNativePG naming)
- Port: `5432` (default PostgreSQL)

**Connection String Format**:
```
postgresql://beersystem_admin:<password>@postgres-rw.postgres.svc.cluster.local:5432/beersystem_stage
```

**SSL Mode**: `require` (enforce encrypted connections if PostgreSQL cluster supports TLS)

## Application Schema

**Note**: Application schema (tables, relationships, constraints) is managed by the beersystem application itself (likely via ORM migrations or SQL scripts). This data model focuses only on database infrastructure provisioning.

**Assumption**: BeerSystem application includes migration tooling (e.g., Alembic, Django migrations, Liquibase) that will create/update tables when application starts or via separate migration job.

**Expected Schema Components** (based on application name, not specified in feature requirements):
- Tables for beer inventory, orders, customers, etc. (application-specific)
- Indexes for query performance
- Foreign key constraints for data integrity
- Sequences for auto-increment IDs

**Migration Strategy**:
1. OpenTofu provisions database and user (infrastructure)
2. Application deployment includes init container or startup script that runs migrations
3. Migrations executed using `beersystem_admin` credentials (has DDL privileges)

## OpenTofu Resources

**Module**: `terraform/modules/postgresql-database/`

**Resource Definitions**:

```hcl
# Database
resource "postgresql_database" "beersystem_stage" {
  name              = "beersystem_stage"
  owner             = postgresql_role.beersystem_admin.name
  encoding          = "UTF8"
  lc_collate        = "en_US.UTF-8"
  lc_ctype          = "en_US.UTF-8"
  template          = "template0"
  connection_limit  = -1  # Unlimited connections
}

# Admin user
resource "postgresql_role" "beersystem_admin" {
  name     = "beersystem_admin"
  login    = true
  password = var.admin_password  # From variable, not hardcoded
}

# Grant privileges
resource "postgresql_grant" "beersystem_admin_database" {
  database    = postgresql_database.beersystem_stage.name
  role        = postgresql_role.beersystem_admin.name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE", "TEMPORARY"]
}

resource "postgresql_grant" "beersystem_admin_schema" {
  database    = postgresql_database.beersystem_stage.name
  role        = postgresql_role.beersystem_admin.name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

resource "postgresql_grant" "beersystem_admin_tables" {
  database    = postgresql_database.beersystem_stage.name
  role        = postgresql_role.beersystem_admin.name
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}

resource "postgresql_grant" "beersystem_admin_sequences" {
  database    = postgresql_database.beersystem_stage.name
  role        = postgresql_role.beersystem_admin.name
  schema      = "public"
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT", "UPDATE"]
}

# Default privileges for future objects
resource "postgresql_default_privileges" "beersystem_admin_tables" {
  database    = postgresql_database.beersystem_stage.name
  role        = postgresql_role.beersystem_admin.name
  schema      = "public"
  owner       = postgresql_role.beersystem_admin.name
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}
```

## Backup and Recovery

**Backup Strategy** (future enhancement, not in MVP scope):
- PostgreSQL cluster (feature 011) should handle database backups
- Logical backup: `pg_dump beersystem_stage` for schema + data export
- Point-in-time recovery via WAL archiving (if enabled on cluster)

**Recovery Testing**: Should periodically test restore from backup to validate recovery procedures (learning exercise).

## Performance Considerations

**Connection Pooling**: Application should use connection pooling (e.g., PgBouncer, SQLAlchemy pool) to minimize connection overhead.

**Indexes**: Application schema should include appropriate indexes for query performance (managed by application migrations).

**Resource Limits**: PostgreSQL cluster resource limits defined in feature 011; no specific limits for beersystem_stage database (shares cluster resources).

## Security Hardening

**Password Management**:
- `beersystem_admin` password generated via `openssl rand -base64 32` or similar
- Password stored in OpenTofu sensitive variable (not in Git)
- Password rotated periodically (manual rotation for MVP, automated for production)

**Network Access**:
- Database only accessible from within Kubernetes cluster (ClusterIP service)
- No external exposure (no LoadBalancer or NodePort)
- Application pods connect via internal DNS (postgres-rw.postgres.svc.cluster.local)

**Audit Logging** (future enhancement):
- Enable PostgreSQL audit logging for DDL statements (CREATE, ALTER, DROP)
- Track who executed schema changes and when

## Testing and Validation

**OpenTofu Validation**:
```bash
cd terraform/environments/chocolandiadc-mvp/beersystem-db
tofu validate
tofu plan
```

**Database Connectivity Test** (manual):
```bash
# From within cluster (exec into any pod with psql client)
kubectl run -it --rm psql-test --image=postgres:15 --restart=Never -- \
  psql "postgresql://beersystem_admin:<password>@postgres-rw.postgres.svc.cluster.local:5432/beersystem_stage"

# Test commands:
\conninfo  # Verify connection details
\l         # List databases (beersystem_stage should appear)
\du        # List roles (beersystem_admin should appear)
CREATE TABLE test_ddl (id SERIAL PRIMARY KEY, name VARCHAR(50));  # Test DDL privilege
INSERT INTO test_ddl (name) VALUES ('test');  # Test DML privilege
DROP TABLE test_ddl;  # Cleanup test
\q         # Exit
```

**Application Integration Test**:
- Deploy application with database connection
- Verify application can connect and execute migrations
- Verify application can perform CRUD operations

## Dependencies

**External Dependencies**:
- Feature 011: PostgreSQL cluster must be operational
- PostgreSQL service endpoint must be accessible from Kubernetes pods
- PostgreSQL cluster must support remote connections (not just localhost)

**OpenTofu Provider**:
- `cyrilgdn/postgresql` provider configured with cluster admin credentials
- Provider configured to connect to PostgreSQL cluster endpoint

## Rollback Strategy

**Database Deletion** (caution):
```bash
tofu destroy  # Deletes database and user (data loss!)
```

**Safe Rollback**:
- Do not delete database if contains production data
- If rollback needed, disable application access (scale deployment to 0 replicas)
- Export data with `pg_dump` before deletion
- Store backup before destroying infrastructure

## Future Enhancements

1. **Read Replica User**: Separate read-only user for reporting/analytics
2. **Application Runtime User**: Least privilege user with no DDL (SELECT/INSERT/UPDATE/DELETE only)
3. **Database Extensions**: Enable PostgreSQL extensions as needed (e.g., `uuid-ossp`, `pgcrypto`)
4. **Performance Monitoring**: Track query performance, connection usage, table size growth
5. **Automated Backups**: Schedule periodic backups with retention policy
6. **Schema Versioning**: Document schema version in database (e.g., via `migrations` table)
