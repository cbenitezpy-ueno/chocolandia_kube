# Beersystem Migration - Redis Configuration Update
# Updates beersystem-backend deployment to use redis-shared

locals {
  namespace = "beersystem"
  deployment_name = "beersystem-backend"
}

# Patch beersystem-backend deployment to use new Redis configuration
resource "kubernetes_manifest" "beersystem_backend_patch" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = local.deployment_name
      namespace = local.namespace
      labels = {
        app                                = "beersystem"
        component                          = "backend"
        "argocd.argoproj.io/instance"      = "beersystem-staging"
        "migrated-to-redis-shared"         = "true"
      }
    }
    spec = {
      replicas = var.replicas
      selector = {
        matchLabels = {
          app       = "beersystem"
          component = "backend"
        }
      }
      template = {
        metadata = {
          labels = {
            app       = "beersystem"
            component = "backend"
          }
        }
        spec = {
          securityContext = {
            fsGroup      = 1000
            runAsNonRoot = true
            runAsUser    = 1000
          }
          imagePullSecrets = [
            {
              name = "ecr-registry-secret"
            }
          ]
          containers = [
            {
              name  = "backend"
              image = var.backend_image
              imagePullPolicy = "Always"
              ports = [
                {
                  containerPort = 3001
                  name          = "http"
                  protocol      = "TCP"
                }
              ]
              env = concat(
                # Database configuration (unchanged)
                [
                  {
                    name = "DATABASE_URL"
                    valueFrom = {
                      secretKeyRef = {
                        name = "beersystem-db-credentials"
                        key  = "DATABASE_URL"
                      }
                    }
                  },
                  {
                    name = "DB_HOST"
                    valueFrom = {
                      secretKeyRef = {
                        name = "beersystem-db-credentials"
                        key  = "DB_HOST"
                      }
                    }
                  },
                  {
                    name = "DB_PORT"
                    valueFrom = {
                      secretKeyRef = {
                        name = "beersystem-db-credentials"
                        key  = "DB_PORT"
                      }
                    }
                  },
                  {
                    name = "DB_NAME"
                    valueFrom = {
                      secretKeyRef = {
                        name = "beersystem-db-credentials"
                        key  = "DB_NAME"
                      }
                    }
                  },
                  {
                    name = "DB_USER"
                    valueFrom = {
                      secretKeyRef = {
                        name = "beersystem-db-credentials"
                        key  = "DB_USER"
                      }
                    }
                  },
                  {
                    name = "DB_PASSWORD"
                    valueFrom = {
                      secretKeyRef = {
                        name = "beersystem-db-credentials"
                        key  = "DB_PASSWORD"
                      }
                    }
                  },
                  {
                    name = "DB_PASS"
                    valueFrom = {
                      secretKeyRef = {
                        name = "beersystem-db-credentials"
                        key  = "DB_PASSWORD"
                      }
                    }
                  },
                  {
                    name = "JWT_SECRET"
                    valueFrom = {
                      secretKeyRef = {
                        name = "beersystem-db-credentials"
                        key  = "JWT_SECRET"
                      }
                    }
                  },
                  {
                    name = "NODE_ENV"
                    valueFrom = {
                      configMapKeyRef = {
                        name = "beersystem-config"
                        key  = "NODE_ENV"
                      }
                    }
                  },
                  {
                    name = "LOG_LEVEL"
                    valueFrom = {
                      configMapKeyRef = {
                        name = "beersystem-config"
                        key  = "LOG_LEVEL"
                      }
                    }
                  },
                  {
                    name  = "PORT"
                    value = "3001"
                  },
                  {
                    name  = "AWS_S3_BUCKET_NAME"
                    value = "beersystem-files-staging"
                  },
                  {
                    name  = "AWS_REGION"
                    value = "us-east-1"
                  },
                  {
                    name  = "DB_SSL"
                    value = "false"
                  },
                  {
                    name  = "GOOGLE_CLIENT_ID"
                    value = "dummy-client-id-for-staging"
                  },
                  {
                    name  = "GOOGLE_CLIENT_SECRET"
                    value = "dummy-client-secret-for-staging"
                  }
                ],
                # NEW: Redis configuration pointing to redis-shared
                [
                  {
                    name  = "REDIS_HOST"
                    value = var.redis_host
                  },
                  {
                    name  = "REDIS_PORT"
                    value = var.redis_port
                  },
                  {
                    name = "REDIS_PASSWORD"
                    valueFrom = {
                      secretKeyRef = {
                        name = var.redis_secret_name
                        key  = "redis-password"
                      }
                    }
                  }
                ]
              )
              resources = {
                requests = {
                  cpu    = "100m"
                  memory = "256Mi"
                }
                limits = {
                  cpu    = "500m"
                  memory = "512Mi"
                }
              }
              livenessProbe = {
                httpGet = {
                  path = "/api/v1/health"
                  port = "http"
                }
                initialDelaySeconds = 30
                periodSeconds       = 10
                timeoutSeconds      = 5
                failureThreshold    = 3
              }
              readinessProbe = {
                httpGet = {
                  path = "/api/v1/health"
                  port = "http"
                }
                initialDelaySeconds = 10
                periodSeconds       = 5
                timeoutSeconds      = 3
                failureThreshold    = 2
              }
            }
          ]
        }
      }
    }
  }
}
