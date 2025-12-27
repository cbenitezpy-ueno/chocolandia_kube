# PostgreSQL Groundhog2k - Main Helm Release Configuration
# Deploys PostgreSQL using official Docker images (not Bitnami)
# Chart: https://github.com/groundhog2k/helm-charts/tree/master/charts/postgres

# ==============================================================================
# Namespace
# ==============================================================================

resource "kubernetes_namespace" "postgresql" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "postgresql"
      "app.kubernetes.io/managed-by" = "opentofu"
      "feature"                      = "011-postgresql-cluster"
    }
  }
}

# ==============================================================================
# PostgreSQL Password Secrets
# ==============================================================================

resource "random_password" "postgres_password" {
  length  = 32
  special = false
}

resource "random_password" "app_user_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "postgresql_credentials" {
  metadata {
    name      = "postgresql-credentials"
    namespace = kubernetes_namespace.postgresql.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "postgresql"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "postgres-password" = random_password.postgres_password.result
    "password"          = random_password.app_user_password.result
    "username"          = var.postgres_user
    "database"          = var.postgres_database
  }
}

# ==============================================================================
# Init Scripts ConfigMap (for additional databases)
# ==============================================================================

resource "kubernetes_config_map" "init_scripts" {
  metadata {
    name      = "postgresql-init-scripts"
    namespace = kubernetes_namespace.postgresql.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "postgresql"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  data = {
    "init-databases.sh" = <<-EOT
      #!/bin/bash
      set -e

      # Create app_user if not exists
      psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
          IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${var.postgres_user}') THEN
            CREATE USER ${var.postgres_user} WITH PASSWORD '$APP_USER_PASSWORD';
          END IF;
        END
        \$\$;
      EOSQL

      # Create additional databases
      %{for db in var.additional_databases}
      psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        SELECT 'CREATE DATABASE ${db}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db}')\gexec
        GRANT ALL PRIVILEGES ON DATABASE ${db} TO ${var.postgres_user};
      EOSQL
      %{endfor}

      echo "Database initialization completed!"
    EOT
  }
}

# ==============================================================================
# PostgreSQL Helm Release (Groundhog2k)
# ==============================================================================

resource "helm_release" "postgresql" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = "postgres"
  version    = var.chart_version
  namespace  = kubernetes_namespace.postgresql.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = var.helm_timeout
  atomic        = true

  values = [
    yamlencode({
      # Image configuration - Official PostgreSQL image
      image = {
        registry   = "docker.io"
        repository = "postgres"
        tag        = var.postgres_image_tag
      }

      # Use existing secret for credentials
      settings = {
        superuser = {
          value = "postgres"
        }
        superuserPassword = {
          value = random_password.postgres_password.result
        }
        authMethod = "scram-sha-256"
      }

      # Environment variables for database initialization
      env = [
        {
          name  = "POSTGRES_DB"
          value = var.postgres_database
        },
        {
          name  = "POSTGRES_USER"
          value = "postgres"
        },
        {
          name  = "POSTGRES_PASSWORD"
          value = random_password.postgres_password.result
        },
        {
          name  = "APP_USER_PASSWORD"
          value = random_password.app_user_password.result
        }
      ]

      # Service configuration (ClusterIP, LoadBalancer handled separately)
      service = {
        type = "ClusterIP"
        port = 5432
      }

      # Resource limits
      resources = {
        requests = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      # Storage configuration
      storage = {
        requestedSize = var.storage_size
        className     = var.storage_class
        accessModes   = ["ReadWriteOnce"]
        keepPvc       = true
      }

      # Security context
      podSecurityContext = {
        fsGroup            = 999
        supplementalGroups = [999]
      }

      securityContext = {
        allowPrivilegeEscalation = false
        privileged               = false
        readOnlyRootFilesystem   = true
        runAsNonRoot             = true
        runAsUser                = 999
        runAsGroup               = 999
      }

      # Pod labels (additional, not replacing chart defaults)
      podLabels = {
        "feature" = "011-postgresql-cluster"
      }

      # Pod annotations for Prometheus scraping
      podAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = "9187"
      }

      # Extra volumes for init scripts
      extraVolumes = [
        {
          name = "init-scripts"
          configMap = {
            name        = kubernetes_config_map.init_scripts.metadata[0].name
            defaultMode = 493  # 0755
          }
        }
      ]

      extraVolumeMounts = [
        {
          name      = "init-scripts"
          mountPath = "/docker-entrypoint-initdb.d"
          readOnly  = true
        }
      ]

      # Custom probes using 127.0.0.1 instead of localhost
      # This fixes musl/Alpine DNS resolution issue where "localhost"
      # resolves to IPv6 only via getent, causing pg_isready to fail
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

      customLivenessProbe = {
        exec = {
          command = ["sh", "-c", "pg_isready -h 127.0.0.1 -p 5432 -U postgres"]
        }
        initialDelaySeconds = 10
        timeoutSeconds      = 5
        failureThreshold    = 3
        successThreshold    = 1
        periodSeconds       = 10
      }

      customReadinessProbe = {
        exec = {
          command = ["sh", "-c", "pg_isready -h 127.0.0.1 -p 5432 -U postgres"]
        }
        initialDelaySeconds = 10
        timeoutSeconds      = 5
        failureThreshold    = 3
        successThreshold    = 1
        periodSeconds       = 10
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.postgresql,
    kubernetes_secret.postgresql_credentials,
    kubernetes_config_map.init_scripts
  ]
}

# ==============================================================================
# Prometheus Exporter Sidecar (postgres_exporter)
# ==============================================================================

resource "kubernetes_deployment" "postgres_exporter" {
  count = var.enable_metrics ? 1 : 0

  metadata {
    name      = "${var.release_name}-exporter"
    namespace = kubernetes_namespace.postgresql.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "postgres-exporter"
      "app.kubernetes.io/instance"   = var.release_name
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "postgres-exporter"
        "app.kubernetes.io/instance" = var.release_name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "postgres-exporter"
          "app.kubernetes.io/instance" = var.release_name
        }
      }

      spec {
        container {
          name  = "postgres-exporter"
          image = "quay.io/prometheuscommunity/postgres-exporter:v0.17.1"

          port {
            container_port = 9187
            name           = "metrics"
          }

          env {
            name  = "DATA_SOURCE_NAME"
            value = "postgresql://postgres:${random_password.postgres_password.result}@${var.release_name}.${var.namespace}.svc.cluster.local:5432/postgres?sslmode=disable"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 65534
          }
        }
      }
    }
  }

  depends_on = [helm_release.postgresql]
}

resource "kubernetes_service" "postgres_exporter" {
  count = var.enable_metrics ? 1 : 0

  metadata {
    name      = "${var.release_name}-exporter"
    namespace = kubernetes_namespace.postgresql.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "postgres-exporter"
      "app.kubernetes.io/instance"   = var.release_name
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name"     = "postgres-exporter"
      "app.kubernetes.io/instance" = var.release_name
    }

    port {
      name        = "metrics"
      port        = 9187
      target_port = 9187
    }
  }
}

# ==============================================================================
# ServiceMonitor for Prometheus Operator
# ==============================================================================

resource "kubernetes_manifest" "service_monitor" {
  count = var.enable_service_monitor ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "${var.release_name}-monitor"
      namespace = kubernetes_namespace.postgresql.metadata[0].name
      labels = {
        "app.kubernetes.io/name"       = "postgresql"
        "app.kubernetes.io/instance"   = var.release_name
        "app.kubernetes.io/managed-by" = "opentofu"
        "release"                      = "kube-prometheus-stack"
      }
    }
    spec = {
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
      selector = {
        matchLabels = {
          "app.kubernetes.io/name"     = "postgres-exporter"
          "app.kubernetes.io/instance" = var.release_name
        }
      }
    }
  }

  depends_on = [kubernetes_service.postgres_exporter]
}

# ==============================================================================
# External LoadBalancer Service (MetalLB)
# ==============================================================================

resource "kubernetes_service" "postgresql_external" {
  count = var.loadbalancer_ip != "" ? 1 : 0

  metadata {
    name      = "${var.release_name}-external"
    namespace = kubernetes_namespace.postgresql.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "postgresql"
      "app.kubernetes.io/instance"   = var.release_name
      "app.kubernetes.io/managed-by" = "opentofu"
    }
    annotations = {
      # MetalLB 0.13+ uses metallb.io namespace (not metallb.universe.tf)
      "metallb.io/address-pool"     = var.metallb_ip_pool
      "metallb.io/loadBalancerIPs"  = var.loadbalancer_ip
      # Disable K3s ServiceLB for MetalLB-managed service
      "svccontroller.k3s.cattle.io/enablelb" = "false"
    }
  }

  spec {
    type                    = "LoadBalancer"
    # Note: Do NOT use load_balancer_ip here - MetalLB 0.15+ conflicts with annotation
    # IP is specified via metallb.io/loadBalancerIPs annotation only
    external_traffic_policy = "Local"

    selector = {
      "app.kubernetes.io/name"     = "postgres"
      "app.kubernetes.io/instance" = var.release_name
    }

    port {
      name        = "postgresql"
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
  }

  depends_on = [helm_release.postgresql]
}
