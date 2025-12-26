# Migrating PostgreSQL from Bitnami to Official Docker Images

**Date:** December 26, 2025
**Author:** Carlos Benitez
**Category:** Homelab, Kubernetes, Database, Migration

## Summary

After Bitnami's licensing changes in August 2025 rendered their PostgreSQL Helm charts unusable, we successfully migrated our PostgreSQL HA cluster to groundhog2k/postgres using official Docker images. This article documents the migration process, challenges encountered, and lessons learned.

## The Problem

Bitnami has been a popular source for Helm charts and Docker images in the Kubernetes ecosystem. However, in August 2025, licensing changes made their newer images unavailable on Docker Hub. When attempting to deploy or upgrade PostgreSQL using the Bitnami chart, we encountered:

```
Error: release postgres-ha failed: invalid_reference: invalid tag
```

This error indicated that the Docker images referenced by the chart were no longer accessible.

## Evaluating Alternatives

We evaluated several alternatives for PostgreSQL on Kubernetes:

| Option | Pros | Cons |
|--------|------|------|
| CloudNativePG | Native K8s operator, HA, auto-failover | Complex, heavy for homelab |
| Zalando Postgres Operator | Enterprise-grade, WAL archiving | Overkill for small deployments |
| CrunchyData PGO | Full-featured, production-ready | Significant resource overhead |
| groundhog2k/postgres | Simple, uses official images | Single instance (no HA) |
| Raw official postgres | Full control | Manual configuration |

For our homelab environment, we chose **groundhog2k/postgres** because:
1. Uses official Docker images (`docker.io/postgres:17-alpine`)
2. Simple Helm chart with sensible defaults
3. Good Prometheus metrics support
4. No vendor lock-in
5. Lightweight and fast deployment

## The Migration Process

### Step 1: Backup Existing Data

Before any migration, we created a full backup:

```bash
# Get current postgres pod
kubectl exec -n postgresql postgres-ha-postgresql-0 -- \
  pg_dumpall -U postgres > postgres-backup-migration-20251226.sql
```

This backup captured all databases, roles, and permissions.

### Step 2: Create New Terraform Module

We created a new module at `terraform/modules/postgresql-groundhog2k/` with:

- **main.tf**: Helm release configuration with custom values
- **variables.tf**: Configurable parameters (image tag, resources, storage)
- **outputs.tf**: Service endpoints, credentials, verification commands

Key configuration highlights:

```hcl
# Use official PostgreSQL image
image = {
  registry   = "docker.io"
  repository = "postgres"
  tag        = "17-alpine"
}

# Custom probes using 127.0.0.1 instead of localhost
# (fixes musl/Alpine DNS resolution issue)
customStartupProbe = {
  exec = {
    command = ["sh", "-c", "pg_isready -h 127.0.0.1 -p 5432 -U postgres"]
  }
  initialDelaySeconds = 10
  timeoutSeconds      = 5
  failureThreshold    = 30
  successThreshold    = 1
  periodSeconds       = 10
}
```

### Step 3: Handle Terraform State

Since we were replacing the module, we needed to manage Terraform state carefully:

```bash
# Remove old module from state (preserves existing PVCs)
tofu state rm 'module.postgresql_cluster'

# Import existing namespace
tofu import 'module.postgresql.kubernetes_namespace.postgresql' postgresql
```

### Step 4: Deploy New PostgreSQL

```bash
tofu apply -target='module.postgresql'
```

### Step 5: Restore Databases

The new installation came with fresh databases, so we needed to recreate our structure:

```bash
# Create additional database
kubectl exec -n postgresql postgres-ha-0 -- \
  psql -U postgres -c "CREATE DATABASE beersystem_stage;"

# Create application user with new password
kubectl exec -n postgresql postgres-ha-0 -- \
  psql -U postgres -c "CREATE USER app_user WITH PASSWORD '...';
                       GRANT ALL PRIVILEGES ON DATABASE app_db TO app_user;
                       GRANT ALL PRIVILEGES ON DATABASE beersystem_stage TO app_user;"
```

## Technical Challenges

### Challenge 1: Alpine DNS Resolution

The groundhog2k chart uses Alpine-based images. Alpine uses musl libc, which has different DNS resolution behavior than glibc. The default health probes using `pg_isready -h localhost` failed because:

```
localhost:5432 - no attempt
```

**Root cause:** `getent hosts localhost` in Alpine returns only `::1` (IPv6), and `pg_isready` was failing to connect.

**Solution:** Override the probes to use `127.0.0.1` explicitly instead of `localhost`.

### Challenge 2: MetalLB IP Conflicts

Our original PostgreSQL IP (192.168.4.200) was already claimed by another service (Pi-hole). MetalLB error:

```
Failed to allocate IP for "postgresql/postgres-ha-external":
can't change sharing key, address also in use by default/pihole-dns
```

**Solution:** Assigned PostgreSQL a new IP (192.168.4.204) from the available pool.

### Challenge 3: Helm Chart Value Structure

The groundhog2k chart expected nested objects for certain values:

```hcl
# Wrong (causes template error)
superuserPassword = "password"

# Correct
superuserPassword = {
  value = "password"
}
```

## Final Configuration

Our final PostgreSQL deployment:

| Attribute | Value |
|-----------|-------|
| Chart | groundhog2k/postgres v1.6.1 |
| Image | docker.io/postgres:17-alpine |
| ClusterIP Service | postgres-ha.postgresql.svc.cluster.local:5432 |
| LoadBalancer IP | 192.168.4.204 |
| Storage | 50Gi (local-path) |
| Metrics | postgres-exporter on port 9187 |

## Verification Commands

```bash
# Check pods
kubectl get pods -n postgresql

# Check services
kubectl get svc -n postgresql

# Test connection
kubectl run pg-test --rm -it --image=postgres:17-alpine -- \
  psql -h postgres-ha.postgresql.svc.cluster.local -U postgres -c '\l'

# Get superuser password
kubectl get secret -n postgresql postgresql-credentials \
  -o jsonpath='{.data.postgres-password}' | base64 -d
```

## Lessons Learned

1. **Always backup first** - Even for seemingly simple migrations, have a full backup ready.

2. **Test probe commands inside containers** - Different base images (Alpine vs Debian) behave differently. What works in one may not work in another.

3. **Document IP assignments** - MetalLB IP conflicts are easy to avoid with proper documentation.

4. **Use official images when possible** - Vendor-managed images can become unavailable without warning. Official images have better long-term support.

5. **Terraform state management is critical** - Understanding `tofu state rm` and `tofu import` prevents data loss during module replacements.

## Conclusion

The migration from Bitnami to groundhog2k/postgres was successful, providing us with:

- **Stability**: Official Docker images with long-term support
- **Simplicity**: Straightforward Helm chart without complex HA features we didn't need
- **Portability**: No vendor lock-in
- **Observability**: Full Prometheus metrics integration

For homelab environments that don't require complex HA features, groundhog2k charts with official images are an excellent alternative to Bitnami.

## Related Articles

- [Migrating Redis from Bitnami to Official Images](/docs/blog/redis-migration-bitnami-to-official-images.md)
- [ChocolandiaDC Cluster Overview](/docs/blog/chocolandiadc-cluster-overview-es.md)
