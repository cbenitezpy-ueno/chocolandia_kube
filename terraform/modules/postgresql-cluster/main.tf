# PostgreSQL Cluster Module - Main Configuration
# Feature 011: PostgreSQL Cluster Database Service
#
# Deploys PostgreSQL HA cluster using Bitnami Helm chart with primary-replica topology.
# Configuration optimized for K3s homelab cluster with local-path storage.
#
# Architecture:
# - 1 primary instance (read/write)
# - 1+ replica instances (read-only, asynchronous replication)
# - ClusterIP Service for cluster-internal access
# - LoadBalancer Service for internal network access (via MetalLB)
# - PersistentVolumes for data persistence
# - PostgreSQL Exporter for Prometheus metrics

# ==============================================================================
# Namespace Creation
# ==============================================================================

# Note: Namespace should already exist from Phase 1: Setup (T007)
# This data source validates namespace existence

data "kubernetes_namespace" "postgresql" {
  metadata {
    name = var.namespace
  }
}

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  # Common labels for all resources
  common_labels = {
    "app.kubernetes.io/name"       = "postgresql"
    "app.kubernetes.io/instance"   = var.release_name
    "app.kubernetes.io/component"  = "database"
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "postgresql-cluster"
  }

  # Helm values common configuration
  postgresql_port = 5432
  metrics_port    = 9187
}
