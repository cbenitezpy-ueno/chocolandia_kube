# Data Model: GitHub Actions Self-Hosted Runner

**Feature**: 017-github-actions-runner
**Date**: 2025-11-24

## Overview

This document defines the Kubernetes resources and configuration entities for the GitHub Actions self-hosted runner deployment using Actions Runner Controller (ARC).

## Kubernetes Resources

### 1. Namespace

```yaml
Entity: Namespace
Name: github-actions
Purpose: Isolate all runner-related resources
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | `github-actions` |
| labels | map | Yes | Standard labels for identification |

### 2. GitHub App Secret

```yaml
Entity: Secret
Name: github-app-secret
Purpose: Store GitHub App credentials for ARC authentication
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| github_app_id | string | Yes | GitHub App ID |
| github_app_installation_id | string | Yes | App installation ID for repo/org |
| github_app_private_key | string | Yes | PEM-encoded private key |

**Security Notes**:
- Secret must be created before ARC deployment
- Private key must be base64 encoded in Secret
- Consider external-secrets-operator for production

### 3. RunnerScaleSet (ARC CRD)

```yaml
Entity: AutoscalingRunnerSet (CRD)
Name: homelab-runner
Purpose: Define runner pool configuration
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| githubConfigUrl | string | Yes | Repository or org URL (e.g., `https://github.com/owner/repo`) |
| githubConfigSecret | string | Yes | Reference to github-app-secret |
| minRunners | integer | No | Minimum runner count (default: 0) |
| maxRunners | integer | Yes | Maximum runner count |
| runnerGroup | string | No | Runner group name (org-level only) |
| template | PodTemplateSpec | Yes | Runner pod specification |

**Template.Spec Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| containers[0].image | string | Yes | Runner image (default: `ghcr.io/actions/actions-runner:latest`) |
| containers[0].resources.requests.cpu | string | Yes | CPU request (e.g., `500m`) |
| containers[0].resources.requests.memory | string | Yes | Memory request (e.g., `1Gi`) |
| containers[0].resources.limits.cpu | string | Yes | CPU limit (e.g., `2`) |
| containers[0].resources.limits.memory | string | Yes | Memory limit (e.g., `4Gi`) |
| serviceAccountName | string | Yes | Service account for runner pod |

### 4. ServiceAccount

```yaml
Entity: ServiceAccount
Name: github-runner-sa
Purpose: Identity for runner pods with minimal permissions
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | `github-runner-sa` |
| namespace | string | Yes | `github-actions` |

### 5. Role and RoleBinding

```yaml
Entity: Role
Name: github-runner-role
Purpose: Define minimal permissions for runner operations
```

| Permission | API Group | Resources | Verbs |
|------------|-----------|-----------|-------|
| Pod management | "" | pods | get, list, create, delete |
| Pod logs | "" | pods/log | get |
| Secrets access | "" | secrets | get (specific secrets only) |

### 6. ServiceMonitor (Prometheus)

```yaml
Entity: ServiceMonitor
Name: arc-metrics
Purpose: Enable Prometheus scraping of ARC controller metrics
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| selector.matchLabels | map | Yes | Labels to match ARC controller service |
| endpoints[0].port | string | Yes | Metrics port name |
| endpoints[0].interval | string | Yes | Scrape interval (e.g., `30s`) |

## Configuration Variables (OpenTofu)

### Required Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| github_config_url | string | Repository or org URL | `https://github.com/cbenitez/chocolandia_kube` |
| github_app_id | string | GitHub App ID | `123456` |
| github_app_installation_id | string | Installation ID | `12345678` |
| github_app_private_key | string | PEM private key (sensitive) | `-----BEGIN RSA PRIVATE KEY-----...` |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| namespace | string | `github-actions` | Kubernetes namespace |
| runner_name_prefix | string | `homelab` | Prefix for runner names |
| min_runners | number | `0` | Minimum idle runners |
| max_runners | number | `4` | Maximum concurrent runners |
| runner_labels | list(string) | `["self-hosted", "linux", "x64", "homelab"]` | Runner labels |
| cpu_request | string | `500m` | CPU request per runner |
| memory_request | string | `1Gi` | Memory request per runner |
| cpu_limit | string | `2` | CPU limit per runner |
| memory_limit | string | `4Gi` | Memory limit per runner |

## State Transitions

### Runner Lifecycle

```
                                    ┌─────────────┐
                                    │   Pending   │
                                    └──────┬──────┘
                                           │
                                           ▼
┌──────────┐    job assigned    ┌─────────────────┐    job complete    ┌───────────┐
│   Idle   │◄──────────────────►│     Running     │──────────────────►│   Idle    │
└────┬─────┘                    └────────┬────────┘                    └─────┬─────┘
     │                                   │                                   │
     │ scale down                        │ error/timeout                     │ scale down
     ▼                                   ▼                                   ▼
┌──────────┐                    ┌─────────────────┐                    ┌───────────┐
│ Removed  │                    │     Failed      │                    │  Removed  │
└──────────┘                    └─────────────────┘                    └───────────┘
```

### Runner States

| State | Description | GitHub Status |
|-------|-------------|---------------|
| Pending | Pod starting, runner registering | Offline |
| Idle | Ready for jobs, waiting for assignment | Idle |
| Running | Executing workflow job | Active |
| Failed | Job failed or runner crashed | Offline |
| Removed | Scaled down or deregistered | Not shown |

## Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                        Namespace: github-actions                 │
│                                                                   │
│  ┌─────────────────┐         ┌─────────────────────────────┐    │
│  │ Secret          │◄────────│ AutoscalingRunnerSet        │    │
│  │ github-app-     │ refs    │ homelab-runner               │    │
│  │ secret          │         │                               │    │
│  └─────────────────┘         │ - githubConfigUrl            │    │
│                               │ - minRunners: 0              │    │
│  ┌─────────────────┐         │ - maxRunners: 4              │    │
│  │ ServiceAccount  │◄────────│ - template (pod spec)        │    │
│  │ github-runner-  │ refs    └──────────────┬───────────────┘    │
│  │ sa              │                        │                     │
│  └────────┬────────┘                        │ creates             │
│           │                                 ▼                     │
│           │         ┌──────────────────────────────────────┐     │
│           │ bound   │           Runner Pods                 │     │
│           └────────►│  homelab-runner-xxxxx-xxxxx           │     │
│                     │  (1 to maxRunners instances)          │     │
│                     └──────────────────────────────────────┘     │
│                                                                   │
│  ┌─────────────────┐                                             │
│  │ ServiceMonitor  │─────────► Prometheus scrape target          │
│  │ arc-metrics     │                                             │
│  └─────────────────┘                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Validation Rules

### Secret Validation
- `github_app_id` must be numeric string
- `github_app_installation_id` must be numeric string
- `github_app_private_key` must be valid PEM format starting with `-----BEGIN`

### Runner Configuration Validation
- `minRunners` must be >= 0
- `maxRunners` must be > 0 and >= `minRunners`
- `cpu_request` must be less than or equal to `cpu_limit`
- `memory_request` must be less than or equal to `memory_limit`
- `runner_labels` must include at least `self-hosted`

### Resource Limits
- CPU limit should not exceed 4 cores (K3s node capacity)
- Memory limit should not exceed 8Gi (K3s node capacity)
- Total runner resources (maxRunners * limits) should not exceed 50% of cluster capacity
