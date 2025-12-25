# Data Model: Cluster Version Audit

**Branch**: `020-cluster-version-audit` | **Date**: 2025-12-25 (Post-Upgrade)

## Entity Model

Este documento define el modelo de datos para el inventario de componentes y el tracking de actualizaciones.

---

## Entities

### 1. ClusterNode

Representa un nodo físico del cluster K3s.

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| name | string | Hostname del nodo | Required, unique |
| ip | string | IP interna del nodo | Required, IPv4 format |
| role | enum | control-plane, worker | Required |
| ubuntu_version | string | Versión de Ubuntu | semver format |
| kernel_version | string | Versión del kernel | x.x.x-xx-generic |
| k3s_version | string | Versión de K3s | semver+k3s format |
| status | enum | ready, updating, failed | Required |
| last_updated | datetime | Última actualización | ISO 8601 |

**Current State** (POST-UPGRADE 2025-12-25):
```yaml
nodes:
  - name: master1
    ip: 192.168.4.101
    role: control-plane
    ubuntu_version: "24.04.3"
    kernel_version: "6.8.0-90-generic"  # UPGRADED from 6.8.0-88
    k3s_version: "v1.33.7+k3s1"         # UPGRADED from v1.28.3+k3s1

  - name: nodo03
    ip: 192.168.4.103
    role: control-plane
    ubuntu_version: "24.04.3"
    kernel_version: "6.8.0-90-generic"  # UPGRADED from 6.8.0-88
    k3s_version: "v1.33.7+k3s1"         # UPGRADED from v1.28.3+k3s1

  - name: nodo1
    ip: 192.168.4.102
    role: worker
    ubuntu_version: "24.04.3"
    kernel_version: "6.8.0-90-generic"  # UPGRADED from 6.8.0-87
    k3s_version: "v1.33.7+k3s1"         # UPGRADED from v1.28.3+k3s1

  - name: nodo04
    ip: 192.168.4.104
    role: worker
    ubuntu_version: "24.04.3"
    kernel_version: "6.8.0-90-generic"  # UPGRADED from 6.8.0-88
    k3s_version: "v1.33.7+k3s1"         # UPGRADED from v1.28.3+k3s1
```

---

### 2. HelmRelease

Representa un release de Helm instalado en el cluster.

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| name | string | Nombre del release | Required, unique per namespace |
| namespace | string | Namespace de Kubernetes | Required |
| chart_name | string | Nombre del chart | Required |
| chart_version | string | Versión del chart | semver |
| app_version | string | Versión de la aplicación | semver |
| target_version | string | Versión objetivo | semver, nullable |
| priority | enum | critical, high, medium, low | Required |
| status | enum | current, outdated, updating | Required |

**Current State** (POST-UPGRADE 2025-12-25):
```yaml
helm_releases:
  - name: kube-prometheus-stack
    namespace: monitoring
    chart_version: "55.5.0"
    app_version: "v0.70.0"
    target_version: "80.6.0"
    priority: high
    status: deferred  # Complex upgrade deferred to future feature

  - name: longhorn
    namespace: longhorn-system
    chart_version: "1.10.1"         # UPGRADED from 1.5.5
    app_version: "v1.10.1"
    target_version: null
    priority: critical
    status: current

  - name: argocd
    namespace: argocd
    chart_version: "7.9.0"          # UPGRADED from 5.51.0
    app_version: "v2.14.11"
    target_version: null
    priority: high
    status: current

  - name: cert-manager
    namespace: cert-manager
    chart_version: "v1.19.2"        # UPGRADED from v1.13.3
    app_version: "v1.19.2"
    target_version: null
    priority: medium
    status: current

  - name: traefik
    namespace: traefik
    chart_version: "38.0.1"         # UPGRADED from 30.0.2
    app_version: "v3.6.5"
    target_version: null
    priority: medium
    status: current

  - name: redis-shared
    namespace: redis
    chart_version: "23.2.12"
    app_version: "8.2.3"
    target_version: "24.1.0"
    priority: medium
    status: deferred  # Low priority, stable

  - name: postgres-ha
    namespace: postgresql
    chart_version: "18.1.9"
    app_version: "18.1.0"
    target_version: "18.2.0"
    priority: low
    status: deferred  # Low priority, stable

  - name: headlamp
    namespace: headlamp
    chart_version: "0.38.0"
    app_version: "0.38.0"
    target_version: null
    priority: low
    status: current

  - name: arc-controller
    namespace: github-actions
    chart_version: "0.13.0"
    app_version: "0.13.0"
    target_version: "0.13.1"
    priority: low
    status: deferred  # Minor version, stable
```

---

### 3. ContainerImage

Representa una imagen de contenedor desplegada directamente (sin Helm).

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| name | string | Nombre de la imagen | Required |
| namespace | string | Namespace de Kubernetes | Required |
| current_tag | string | Tag actual | Required |
| target_tag | string | Tag objetivo | nullable |
| uses_latest | boolean | Si usa tag "latest" | Required |
| priority | enum | high, medium, low | Required |

**Current State** (POST-UPGRADE 2025-12-25):
```yaml
container_images:
  - name: pihole
    namespace: default
    current_tag: "2025.11.1"        # PINNED from "latest"
    target_tag: null
    uses_latest: false
    priority: medium

  - name: home-assistant
    namespace: home-assistant
    current_tag: "2025.12.4"        # PINNED from "stable"
    target_tag: null
    uses_latest: false
    priority: medium

  - name: homepage
    namespace: homepage
    current_tag: "v1.4.6"           # PINNED from "latest"
    target_tag: null
    uses_latest: false
    priority: low

  - name: ntfy
    namespace: ntfy
    current_tag: "v2.8.0"
    target_tag: "v2.15.0"
    uses_latest: false
    priority: medium
    status: deferred  # Low priority

  - name: minio
    namespace: minio
    current_tag: "RELEASE.2024-01-01T16-36-33Z"
    target_tag: "RELEASE.2025-10-15T17-29-55Z"
    uses_latest: false
    priority: medium
    status: deferred  # Low priority

  - name: nexus
    namespace: nexus
    current_tag: "3.87.1"           # PINNED from "latest"
    target_tag: null
    uses_latest: false
    priority: medium

  - name: cloudflared
    namespace: cloudflare-tunnel
    current_tag: "2025.11.1"        # PINNED from "latest"
    target_tag: null
    uses_latest: false
    priority: low

  - name: localstack
    namespace: localstack
    current_tag: "4.10.0"           # PINNED from "latest"
    target_tag: null
    uses_latest: false
    priority: low

  - name: metallb
    namespace: metallb-system
    current_tag: "v0.14.8"
    target_tag: "v0.15.3"
    uses_latest: false
    priority: medium
    status: deferred  # Deployed via kubectl manifests, not Helm
```

---

### 4. UpdatePhase

Representa una fase del plan de actualización.

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| id | string | Identificador de fase | Required, unique |
| name | string | Nombre descriptivo | Required |
| priority | enum | critical, high, medium, low | Required |
| risk_level | enum | high, medium, low | Required |
| estimated_downtime | string | Tiempo estimado | duration format |
| dependencies | list[string] | Fases que deben completarse antes | list of phase ids |
| components | list[string] | Componentes incluidos | list of component names |
| status | enum | pending, in_progress, completed, failed | Required |

**Update Phases** (POST-UPGRADE 2025-12-25):
```yaml
phases:
  - id: "phase-0"
    name: "Preparación y Backups"
    priority: critical
    risk_level: low
    estimated_downtime: "0"
    dependencies: []
    components:
      - etcd-backup
      - pv-backup
      - image-tag-pinning
    status: completed  # 2025-12-25

  - id: "phase-0.5"
    name: "Ubuntu Security Patches"
    priority: high
    risk_level: low
    estimated_downtime: "2-5m per node"
    dependencies: ["phase-0"]
    components:
      - nodo1
      - nodo04
      - nodo03
      - master1
    status: completed  # kernel 6.8.0-90-generic

  - id: "phase-1"
    name: "K3s Upgrade"
    priority: critical
    risk_level: high
    estimated_downtime: "5-10m per node"
    dependencies: ["phase-0.5"]
    components:
      - k3s
    status: completed  # v1.28.3+k3s1 → v1.33.7+k3s1

  - id: "phase-2"
    name: "Storage & Data"
    priority: high
    risk_level: high
    estimated_downtime: "15-30m"
    dependencies: ["phase-1"]
    components:
      - longhorn      # UPGRADED 1.5.5 → 1.10.1
      - postgres-ha   # DEFERRED (stable)
      - redis-shared  # DEFERRED (stable)
    status: completed

  - id: "phase-3"
    name: "Observability & Security"
    priority: medium
    risk_level: medium
    estimated_downtime: "5-10m"
    dependencies: ["phase-2"]
    components:
      - kube-prometheus-stack  # DEFERRED (complex upgrade)
      - cert-manager           # UPGRADED v1.13.3 → v1.19.2
      - ntfy                   # DEFERRED
    status: completed

  - id: "phase-4"
    name: "Ingress & GitOps"
    priority: medium
    risk_level: medium
    estimated_downtime: "5-10m"
    dependencies: ["phase-3"]
    components:
      - traefik  # UPGRADED 30.0.2 → 38.0.1 (v3.6.5)
      - argocd   # UPGRADED 5.51.0 → 7.9.0 (v2.14.11)
      - metallb  # SKIPPED (kubectl manifests, current)
    status: completed

  - id: "phase-5"
    name: "Applications (Tag Pinning)"
    priority: low
    risk_level: low
    estimated_downtime: "2-5m"
    dependencies: ["phase-4"]
    components:
      - pihole         # PINNED 2025.11.1
      - homepage       # PINNED v1.4.6
      - nexus          # PINNED 3.87.1
      - cloudflared    # PINNED 2025.11.1
      - localstack     # PINNED 4.10.0
      - home-assistant # PINNED 2025.12.4
    status: completed

  - id: "phase-6"
    name: "Documentation & Validation"
    priority: low
    risk_level: low
    estimated_downtime: "0"
    dependencies: ["phase-5"]
    components:
      - data-model.md
      - CLAUDE.md
      - validation-report
    status: completed  # 2025-12-25
```

---

## Relationships

```text
ClusterNode 1──────* HelmRelease (runs on)
ClusterNode 1──────* ContainerImage (runs on)
UpdatePhase *──────* UpdatePhase (depends on)
UpdatePhase 1──────* HelmRelease (includes)
UpdatePhase 1──────* ContainerImage (includes)
UpdatePhase 1──────* ClusterNode (targets)
```

## State Transitions

### UpdatePhase States
```text
pending ──▶ in_progress ──▶ completed
                │
                └──▶ failed ──▶ pending (after rollback)
```

### ClusterNode Update States
```text
ready ──▶ updating ──▶ ready
              │
              └──▶ failed ──▶ ready (after recovery)
```

---

## 5. OpenTofuModule

Representa un módulo OpenTofu que gestiona componentes del cluster (per Constitution Principle I).

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| name | string | Nombre del módulo | Required, unique |
| path | string | Ruta relativa al módulo | Required |
| version_variable | string | Variable que controla versión | Required |
| current_version | string | Versión actual configurada | semver |
| target_version | string | Versión objetivo | semver, nullable |
| status | enum | ready, needs_update, todo | Required |

**Current State** (POST-UPGRADE 2025-12-25):
```yaml
opentofu_modules:
  - name: longhorn
    path: "terraform/modules/longhorn"
    version_variable: "chart_version"
    current_version: "1.10.1"  # UPGRADED from 1.5.5
    target_version: null
    status: current

  - name: metallb
    path: "terraform/modules/metallb"
    version_variable: "chart_version"
    current_version: "0.14.8"
    target_version: "0.15.3"
    status: deferred  # kubectl manifests, not Helm

  - name: cert-manager
    path: "terraform/modules/cert-manager"
    version_variable: "chart_version"
    current_version: "v1.19.2"  # UPGRADED from v1.13.3
    target_version: null
    status: current

  - name: traefik
    path: "terraform/modules/traefik"
    version_variable: "chart_version"
    current_version: "38.0.1"  # UPGRADED from 30.0.2
    target_version: null
    status: current

  - name: argocd
    path: "terraform/modules/argocd"
    version_variable: "argocd_chart_version"
    current_version: "7.9.0"  # UPGRADED from 5.51.0
    target_version: null
    status: current

  - name: kube-prometheus-stack
    path: "terraform/environments/chocolandiadc-mvp/monitoring.tf"
    version_variable: "local.prometheus_stack_version"
    current_version: "55.5.0"
    target_version: "80.6.0"
    status: deferred  # Complex upgrade, separate feature

  - name: redis-shared
    path: "terraform/modules/redis-shared"
    version_variable: "chart_version"
    current_version: "23.2.12"
    target_version: "24.1.0"
    status: deferred  # Stable, low priority

  - name: postgres-ha
    path: "terraform/modules/postgresql-cluster"
    version_variable: "chart_version"
    current_version: "18.1.9"
    target_version: "18.2.0"
    status: deferred  # Stable, low priority
```

---

## Upgrade Commands by Entity Type

### ClusterNode (K3s)
```bash
# SSH to node and upgrade K3s
ssh cbenitez@<node_ip> 'curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION=<target_version> sh -s - <role_flags>'
```

### HelmRelease via OpenTofu (PREFERRED)
```bash
# Update version variable in module
# Then apply via OpenTofu
tofu plan -target=module.<module_name>
tofu apply -target=module.<module_name>
```

### ContainerImage via OpenTofu
```bash
# Update image tag in module's main.tf
# Then apply via OpenTofu
tofu plan -target=module.<module_name>
tofu apply -target=module.<module_name>
```

---

## Validation Queries

### Check all outdated components
```bash
# HelmReleases
helm list -A -o json | jq '.[] | select(.status != "deployed")'

# K3s version across nodes
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'

# Longhorn version
kubectl -n longhorn-system get deploy -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
```

### Check OpenTofu module versions
```bash
tofu output -json | jq '.[] | select(.value | type == "string") | select(.value | contains("version"))'
```
