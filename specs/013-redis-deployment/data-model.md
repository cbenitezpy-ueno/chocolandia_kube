# Data Model & Configuration Schema: Redis Deployment

**Feature**: 013-redis-deployment
**Date**: 2025-11-20
**Status**: Complete

## Overview

This document defines the Redis configuration schema, Kubernetes resources, and OpenTofu module structure for the Redis deployment. Redis is a key-value store; this document focuses on deployment configuration rather than application data structures.

---

## Redis Configuration Schema

### Helm Chart Values Structure

The Bitnami Redis Helm chart is configured via YAML values. Below is the schema for this deployment:

```yaml
# ==============================================================================
# Architecture Configuration
# ==============================================================================
architecture: "replication"  # Options: standalone | replication
# Rationale: replication mode provides 1 primary + N replicas for HA

# ==============================================================================
# Authentication Configuration
# ==============================================================================
auth:
  enabled: true
  existingSecret: "redis-credentials"  # Kubernetes Secret name
  password: ""  # Empty; uses existingSecret
  # Secret must contain key "redis-password"

# ==============================================================================
# Primary Instance Configuration
# ==============================================================================
master:
  # Replica count (always 1 for primary in replication mode)
  count: 1

  # Persistence configuration (FR-006)
  persistence:
    enabled: true
    storageClass: "local-path"
    size: "10Gi"
    # PVC name pattern: redis-data-redis-master-0

  # Resource allocation (FR-012)
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "1000m"
      memory: "2Gi"

  # Service configuration for cluster-internal access (FR-002)
  service:
    type: "ClusterIP"
    ports:
      redis: 6379
    # DNS: redis-master.default.svc.cluster.local

  # Additional service for private network access (FR-003)
  # Note: Requires custom service definition (see Kubernetes resources below)

  # Health checks (FR-009)
  livenessProbe:
    enabled: true
    initialDelaySeconds: 20
    periodSeconds: 5
    timeoutSeconds: 5
    failureThreshold: 5
    successThreshold: 1

  readinessProbe:
    enabled: true
    initialDelaySeconds: 20
    periodSeconds: 5
    timeoutSeconds: 1
    failureThreshold: 5
    successThreshold: 1

  # Pod labels for monitoring
  podLabels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: master
    app.kubernetes.io/part-of: redis-deployment
    feature: "013-redis-deployment"

# ==============================================================================
# Replica Configuration
# ==============================================================================
replica:
  # Replica count (FR-001: 2 instances total = 1 primary + 1 replica)
  replicaCount: 1

  # Persistence configuration
  persistence:
    enabled: true
    storageClass: "local-path"
    size: "10Gi"
    # PVC name pattern: redis-data-redis-replicas-0

  # Resource allocation (lower CPU request for read-only replica)
  resources:
    requests:
      cpu: "250m"
      memory: "1Gi"
    limits:
      cpu: "1000m"
      memory: "2Gi"

  # Service configuration
  service:
    type: "ClusterIP"
    ports:
      redis: 6379
    # DNS: redis-replicas.default.svc.cluster.local

  # Health checks
  livenessProbe:
    enabled: true
    initialDelaySeconds: 20
    periodSeconds: 5
    timeoutSeconds: 5
    failureThreshold: 5
    successThreshold: 1

  readinessProbe:
    enabled: true
    initialDelaySeconds: 20
    periodSeconds: 5
    timeoutSeconds: 1
    failureThreshold: 5
    successThreshold: 1

  # Pod labels
  podLabels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: replica
    app.kubernetes.io/part-of: redis-deployment
    feature: "013-redis-deployment"

# ==============================================================================
# Metrics Configuration (FR-007, FR-008)
# ==============================================================================
metrics:
  enabled: true

  # Prometheus redis_exporter resources
  resources:
    requests:
      cpu: "50m"
      memory: "64Mi"
    limits:
      cpu: "100m"
      memory: "128Mi"

  # ServiceMonitor for Prometheus Operator
  serviceMonitor:
    enabled: true
    namespace: "monitoring"
    interval: "30s"
    scrapeTimeout: "10s"
    labels:
      release: kube-prometheus-stack  # Matches Prometheus Operator selector

# ==============================================================================
# Redis Configuration (redis.conf overrides)
# ==============================================================================
commonConfiguration: |-
  # Memory management
  maxmemory 1536mb  # 75% of 2GB limit (leaves headroom for overhead)
  maxmemory-policy allkeys-lru  # Evict least recently used keys when memory full

  # Persistence (RDB snapshots)
  save 900 1       # Save if 1 key changed in 15 minutes
  save 300 10      # Save if 10 keys changed in 5 minutes
  save 60 10000    # Save if 10000 keys changed in 1 minute

  # AOF (Append-Only File) - disabled for cache workload
  appendonly no

  # Logging
  loglevel notice

  # Slow log (queries taking >10ms)
  slowlog-log-slower-than 10000
  slowlog-max-len 128

# ==============================================================================
# Security Configuration
# ==============================================================================
# Disable insecure commands (security hardening)
disableCommands:
  - FLUSHDB
  - FLUSHALL
  - CONFIG
  - SHUTDOWN

# ==============================================================================
# Volume Permissions (disabled for local-path)
# ==============================================================================
volumePermissions:
  enabled: false  # local-path-provisioner handles permissions automatically
```

---

## Kubernetes Resources

### 1. Namespace (Optional)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: default  # Using default namespace initially
  labels:
    name: default
```

**Decision**: Deploy to `default` namespace initially (matches Pi-hole pattern). Future migration to dedicated `redis` namespace if needed.

---

### 2. Kubernetes Secret - Redis Credentials

Created by OpenTofu (not Helm chart):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-credentials
  namespace: default
type: Opaque
data:
  redis-password: <base64-encoded-password>  # Auto-generated by OpenTofu random_password
```

**Schema**:
- **Name**: `redis-credentials`
- **Type**: `Opaque`
- **Keys**:
  - `redis-password`: Redis authentication password (32 characters, auto-generated)

**OpenTofu Definition**:

```hcl
resource "random_password" "redis_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>?"  # Avoid backticks and quotes
}

resource "kubernetes_secret" "redis_credentials" {
  metadata {
    name      = "redis-credentials"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "redis"
      "app.kubernetes.io/managed-by" = "opentofu"
      "feature"                      = "013-redis-deployment"
    }
  }

  data = {
    redis-password = random_password.redis_password.result
  }
}
```

---

### 3. Service - ClusterIP (Internal Access)

Created by Helm chart automatically:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-master
  namespace: default
  labels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: master
spec:
  type: ClusterIP
  ports:
    - name: tcp-redis
      port: 6379
      targetPort: redis
      protocol: TCP
  selector:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: master
```

**DNS Name**: `redis-master.default.svc.cluster.local`
**Purpose**: Cluster-internal access (FR-002)

---

### 4. Service - LoadBalancer (Private Network Access)

Custom service created by OpenTofu (Kubernetes provider):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-external
  namespace: default
  labels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: master
  annotations:
    metallb.universe.tf/address-pool: eero-pool
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.4.203
  ports:
    - name: tcp-redis
      port: 6379
      targetPort: redis
      protocol: TCP
  selector:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: master
```

**External IP**: `192.168.4.203` (MetalLB)
**Purpose**: Private network (192.168.4.0/24) access (FR-003)

**OpenTofu Definition**:

```hcl
resource "kubernetes_service" "redis_external" {
  metadata {
    name      = "redis-external"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "master"
    }
    annotations = {
      "metallb.universe.tf/address-pool" = var.metallb_ip_pool
    }
  }

  spec {
    type             = "LoadBalancer"
    load_balancer_ip = var.loadbalancer_ip

    port {
      name        = "tcp-redis"
      port        = 6379
      target_port = "redis"
      protocol    = "TCP"
    }

    selector = {
      "app.kubernetes.io/name"      = "redis"
      "app.kubernetes.io/component" = "master"
    }
  }

  depends_on = [helm_release.redis]
}
```

---

### 5. ServiceMonitor - Prometheus Metrics

Created by Helm chart (when `metrics.serviceMonitor.enabled: true`):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: redis-metrics
  namespace: monitoring
  labels:
    app.kubernetes.io/name: redis
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: redis
  namespaceSelector:
    matchNames:
      - default
  endpoints:
    - port: http-metrics
      interval: 30s
      scrapeTimeout: 10s
```

**Purpose**: Prometheus Operator auto-discovery (FR-008)

---

## OpenTofu Module Structure

### Module: `terraform/modules/redis`

#### File: `main.tf`

```hcl
# ==============================================================================
# Redis Helm Release
# ==============================================================================

resource "helm_release" "redis" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = "redis"
  version    = var.chart_version
  namespace  = var.namespace

  wait    = true
  timeout = var.helm_timeout

  values = [
    yamlencode({
      architecture = "replication"

      auth = {
        enabled        = true
        existingSecret = kubernetes_secret.redis_credentials.metadata[0].name
        password       = ""
      }

      master = {
        count = 1
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }
        resources = {
          requests = {
            cpu    = var.master_cpu_request
            memory = var.master_memory_request
          }
          limits = {
            cpu    = var.master_cpu_limit
            memory = var.master_memory_limit
          }
        }
        service = {
          type = "ClusterIP"
        }
        podLabels = local.common_labels
      }

      replica = {
        replicaCount = var.replica_count
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }
        resources = {
          requests = {
            cpu    = var.replica_cpu_request
            memory = var.replica_memory_request
          }
          limits = {
            cpu    = var.replica_cpu_limit
            memory = var.replica_memory_limit
          }
        }
        podLabels = local.common_labels
      }

      metrics = {
        enabled = var.enable_metrics
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
        serviceMonitor = {
          enabled   = var.enable_service_monitor
          namespace = var.monitoring_namespace
          interval  = "30s"
          labels = {
            release = "kube-prometheus-stack"
          }
        }
      }

      commonConfiguration = var.redis_config

      disableCommands = var.disable_commands

      volumePermissions = {
        enabled = false
      }
    })
  ]

  depends_on = [
    kubernetes_secret.redis_credentials
  ]
}
```

#### File: `variables.tf`

```hcl
variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "redis"
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://charts.bitnami.com/bitnami"
}

variable "chart_version" {
  description = "Redis Helm chart version"
  type        = string
  default     = "23.2.12"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}

variable "storage_class" {
  description = "Storage class for PersistentVolumes"
  type        = string
  default     = "local-path"
}

variable "storage_size" {
  description = "Storage size per instance"
  type        = string
  default     = "10Gi"
}

variable "replica_count" {
  description = "Number of Redis replicas (not including primary)"
  type        = number
  default     = 1
}

variable "master_cpu_request" {
  description = "Master CPU request"
  type        = string
  default     = "500m"
}

variable "master_cpu_limit" {
  description = "Master CPU limit"
  type        = string
  default     = "1000m"
}

variable "master_memory_request" {
  description = "Master memory request"
  type        = string
  default     = "1Gi"
}

variable "master_memory_limit" {
  description = "Master memory limit"
  type        = string
  default     = "2Gi"
}

variable "replica_cpu_request" {
  description = "Replica CPU request"
  type        = string
  default     = "250m"
}

variable "replica_cpu_limit" {
  description = "Replica CPU limit"
  type        = string
  default     = "1000m"
}

variable "replica_memory_request" {
  description = "Replica memory request"
  type        = string
  default     = "1Gi"
}

variable "replica_memory_limit" {
  description = "Replica memory limit"
  type        = string
  default     = "2Gi"
}

variable "enable_metrics" {
  description = "Enable Prometheus metrics exporter"
  type        = bool
  default     = true
}

variable "enable_service_monitor" {
  description = "Enable ServiceMonitor for Prometheus Operator"
  type        = bool
  default     = true
}

variable "monitoring_namespace" {
  description = "Namespace where Prometheus is deployed"
  type        = string
  default     = "monitoring"
}

variable "loadbalancer_ip" {
  description = "MetalLB LoadBalancer IP for private network access"
  type        = string
  default     = "192.168.4.203"
}

variable "metallb_ip_pool" {
  description = "MetalLB IP pool name"
  type        = string
  default     = "eero-pool"
}

variable "redis_config" {
  description = "Redis configuration (redis.conf overrides)"
  type        = string
  default     = <<-EOT
    maxmemory 1536mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly no
    loglevel notice
    slowlog-log-slower-than 10000
    slowlog-max-len 128
  EOT
}

variable "disable_commands" {
  description = "List of Redis commands to disable"
  type        = list(string)
  default     = ["FLUSHDB", "FLUSHALL", "CONFIG", "SHUTDOWN"]
}

variable "helm_timeout" {
  description = "Helm release timeout (seconds)"
  type        = number
  default     = 600
}
```

#### File: `outputs.tf`

```hcl
output "redis_master_service" {
  description = "Redis master ClusterIP service name"
  value       = "${var.release_name}-master.${var.namespace}.svc.cluster.local"
}

output "redis_replicas_service" {
  description = "Redis replicas ClusterIP service name"
  value       = "${var.release_name}-replicas.${var.namespace}.svc.cluster.local"
}

output "redis_external_service" {
  description = "Redis LoadBalancer service name"
  value       = kubernetes_service.redis_external.metadata[0].name
}

output "redis_external_ip" {
  description = "Redis LoadBalancer external IP"
  value       = var.loadbalancer_ip
}

output "redis_secret_name" {
  description = "Kubernetes Secret containing Redis password"
  value       = kubernetes_secret.redis_credentials.metadata[0].name
}

output "redis_password" {
  description = "Redis authentication password (sensitive)"
  value       = random_password.redis_password.result
  sensitive   = true
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}
```

#### File: `locals.tf`

```hcl
locals {
  common_labels = {
    "app.kubernetes.io/name"       = "redis"
    "app.kubernetes.io/managed-by" = "opentofu"
    "app.kubernetes.io/part-of"    = "redis-deployment"
    "feature"                      = "013-redis-deployment"
  }
}
```

---

## Configuration Validation Rules

### Storage

- **Size**: Must be ≥ 1Gi, recommended ≥ 10Gi
- **Storage class**: Must exist in cluster (`local-path` confirmed)

### Resources

- **CPU request**: Must be > 0, recommended ≥ 250m
- **CPU limit**: Must be ≥ CPU request, recommended ≥ 500m
- **Memory request**: Must be > 0, recommended ≥ 512Mi
- **Memory limit**: Must be ≥ memory request, recommended ≥ 1Gi

### Replica Count

- **Minimum**: 1 (primary + 1 replica)
- **Maximum**: N/A (constrained by cluster capacity and spec requirement of 2 instances)

### LoadBalancer IP

- **Range**: Must be within MetalLB pool (192.168.4.200-192.168.4.210)
- **Availability**: Must not conflict with existing LoadBalancers
- **Format**: Valid IPv4 address

---

## Data Structures (Application Layer)

Redis supports multiple data structures. Applications using this Redis deployment can leverage:

### Supported Data Types

| Type | Use Case | Example Commands |
|------|----------|------------------|
| String | Session storage, caching, counters | SET, GET, INCR, DECR |
| Hash | User profiles, object storage | HSET, HGET, HGETALL |
| List | Message queues, activity logs | LPUSH, RPUSH, LPOP, RPOP |
| Set | Unique items, tags, relationships | SADD, SMEMBERS, SINTER |
| Sorted Set | Leaderboards, time-series data | ZADD, ZRANGE, ZRANK |

### Example Application Data Models

#### Session Storage

```
Key: session:<user-id>
Type: Hash
Fields:
  - username: "user123"
  - email: "user@example.com"
  - login_time: "2025-11-20T10:00:00Z"
  - ip_address: "192.168.4.50"
TTL: 3600 seconds (1 hour)
```

#### Application Cache

```
Key: cache:api:users:<user-id>
Type: String (JSON-encoded)
Value: {"id": 123, "name": "John Doe", "role": "admin"}
TTL: 300 seconds (5 minutes)
```

#### Rate Limiting

```
Key: ratelimit:<api-endpoint>:<ip-address>
Type: String (counter)
Value: Number of requests
TTL: 60 seconds (1 minute window)
```

---

## Summary

This data model defines:

1. **Helm chart values schema** for Redis deployment configuration
2. **Kubernetes resources** created by OpenTofu and Helm
3. **OpenTofu module structure** with variables, outputs, and locals
4. **Configuration validation rules** for safe deployment
5. **Application data structures** supported by Redis

All configurations align with functional requirements (FR-001 to FR-013) and success criteria (SC-001 to SC-008).

**Next**: Generate `quickstart.md` for operational procedures.
