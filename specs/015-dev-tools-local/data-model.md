# Data Model: LocalStack and Container Registry

**Feature**: 015-dev-tools-local
**Date**: 2025-11-23

## Overview

This feature deploys infrastructure services, not application data models. The "data model" describes the Kubernetes resources and their relationships.

---

## 1. Registry Component

### Kubernetes Resources

```
┌─────────────────────────────────────────────────────────────┐
│                     Namespace: registry                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Secret    │    │  ConfigMap  │    │     PVC     │     │
│  │ registry-   │    │  registry-  │    │  registry-  │     │
│  │    auth     │    │   config    │    │   storage   │     │
│  │ (htpasswd)  │    │ (config.yml)│    │   (30Gi)    │     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            ▼                                │
│                   ┌─────────────┐                           │
│                   │ Deployment  │                           │
│                   │  registry   │                           │
│                   │ (registry:2)│                           │
│                   └──────┬──────┘                           │
│                          │                                  │
│                          ▼                                  │
│                   ┌─────────────┐                           │
│                   │   Service   │                           │
│                   │  registry   │                           │
│                   │ (ClusterIP) │                           │
│                   │  :5000      │                           │
│                   └──────┬──────┘                           │
│                          │                                  │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │IngressRoute │  │ Middleware  │  │ Certificate │         │
│  │  registry   │  │  basic-auth │  │  registry   │         │
│  │ (Traefik)   │  │  (Traefik)  │  │(cert-manager)│        │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Entity Definitions

#### Secret: registry-auth
| Field | Type | Description |
|-------|------|-------------|
| htpasswd | string | bcrypt-encrypted credentials file |

#### ConfigMap: registry-config
| Field | Type | Description |
|-------|------|-------------|
| config.yml | string | Registry v2 configuration |

#### PersistentVolumeClaim: registry-storage
| Field | Type | Description |
|-------|------|-------------|
| storage | 30Gi | Storage allocation |
| accessModes | ReadWriteOnce | Single node access |
| storageClassName | local-path | K3s local provisioner |

#### Deployment: registry
| Field | Type | Description |
|-------|------|-------------|
| replicas | 1 | Single instance (dev tool) |
| image | registry:2 | Official Docker registry |
| port | 5000 | Registry API port |
| resources.limits.memory | 512Mi | Memory cap |
| resources.limits.cpu | 500m | CPU cap |

---

## 2. LocalStack Component

### Kubernetes Resources

```
┌─────────────────────────────────────────────────────────────┐
│                   Namespace: localstack                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐                   ┌─────────────┐          │
│  │     PVC     │                   │   Secret    │          │
│  │ localstack- │                   │ localstack- │          │
│  │   storage   │                   │   config    │          │
│  │   (20Gi)    │                   │ (optional)  │          │
│  └──────┬──────┘                   └──────┬──────┘          │
│         │                                 │                 │
│         └────────────────┬────────────────┘                 │
│                          ▼                                  │
│                   ┌─────────────┐                           │
│                   │ Deployment  │                           │
│                   │ localstack  │                           │
│                   │(localstack/ │                           │
│                   │ localstack) │                           │
│                   └──────┬──────┘                           │
│                          │                                  │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Service   │  │   Service   │  │IngressRoute │         │
│  │ localstack  │  │ localstack- │  │ localstack  │         │
│  │ (ClusterIP) │  │   edge      │  │ (Traefik)   │         │
│  │  :4566      │  │(LoadBalancer│  └─────────────┘         │
│  └─────────────┘  │  :4566)     │                          │
│                   └─────────────┘                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Entity Definitions

#### PersistentVolumeClaim: localstack-storage
| Field | Type | Description |
|-------|------|-------------|
| storage | 20Gi | Storage allocation |
| accessModes | ReadWriteOnce | Single node access |
| storageClassName | local-path | K3s local provisioner |

#### Deployment: localstack
| Field | Type | Description |
|-------|------|-------------|
| replicas | 1 | Single instance |
| image | localstack/localstack:latest | LocalStack image |
| port | 4566 | Edge port (all services) |
| env.SERVICES | s3,sqs,sns,dynamodb,lambda | Enabled services |
| env.PERSISTENCE | 1 | Enable data persistence |
| env.DATA_DIR | /var/lib/localstack | Persistence directory |
| resources.limits.memory | 2Gi | Memory cap (Lambda needs more) |
| resources.limits.cpu | 1000m | CPU cap |

---

## 3. Registry UI Component (P3)

### Kubernetes Resources

```
┌─────────────────────────────────────────────────────────────┐
│                     Namespace: registry                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐                   ┌─────────────┐          │
│  │ Deployment  │                   │   Service   │          │
│  │ registry-ui │──────────────────▶│ registry-ui │          │
│  │  (joxit/    │                   │ (ClusterIP) │          │
│  │  docker-    │                   │    :80      │          │
│  │registry-ui) │                   └──────┬──────┘          │
│  └─────────────┘                          │                 │
│                                           ▼                 │
│                                    ┌─────────────┐          │
│                                    │IngressRoute │          │
│                                    │ registry-ui │          │
│                                    │ (Traefik)   │          │
│                                    └─────────────┘          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. DNS Records (Pi-hole)

| Hostname | Type | Target | Purpose |
|----------|------|--------|---------|
| registry.homelab.local | CNAME | traefik.homelab.local | Registry API |
| registry-ui.homelab.local | CNAME | traefik.homelab.local | Registry Web UI |
| localstack.homelab.local | CNAME | traefik.homelab.local | LocalStack API |

---

## 5. State Transitions

### Registry Deployment State

```
                    ┌─────────┐
                    │ Initial │
                    └────┬────┘
                         │ tofu apply
                         ▼
                    ┌─────────┐
              ┌────▶│ Pending │
              │     └────┬────┘
              │          │ PVC bound
              │          ▼
              │     ┌─────────┐
              │     │ Running │◀────┐
              │     └────┬────┘     │
              │          │          │ Pod restart
              │          │          │ (data persisted)
              │          ▼          │
              │     ┌─────────┐     │
              │     │  Ready  │─────┘
              │     └────┬────┘
              │          │ tofu destroy
              │          ▼
              │     ┌─────────┐
              │     │Terminated│
              │     └─────────┘
              │
              └── Error (PVC issue, image pull failure)
```

---

## 6. Validation Rules

### Registry
- htpasswd secret MUST exist before deployment
- PVC MUST be bound before registry starts
- Registry MUST be accessible via HTTPS only
- Basic auth MUST be required for all operations

### LocalStack
- SERVICES environment variable MUST include: s3,sqs,sns,dynamodb,lambda
- PERSISTENCE MUST be enabled (value: 1)
- DATA_DIR MUST point to mounted PVC path
- Docker socket access required for Lambda execution
