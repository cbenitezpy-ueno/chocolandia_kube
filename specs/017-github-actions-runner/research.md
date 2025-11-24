# Research: GitHub Actions Self-Hosted Runner

**Feature**: 017-github-actions-runner
**Date**: 2025-11-24
**Status**: Complete

## Research Questions

### 1. Runner Deployment Approach: ARC vs Direct Runner Installation

**Decision**: Use Actions Runner Controller (ARC) with runner-scale-set mode

**Rationale**:
- **Kubernetes-native**: ARC manages runners as Kubernetes resources (CRDs), enabling declarative management via OpenTofu
- **Auto-scaling**: ARC can automatically scale runners based on workflow queue depth (future enhancement)
- **Lifecycle management**: ARC handles runner registration, deregistration, and pod lifecycle automatically
- **GitHub official**: ARC is the official GitHub-supported Kubernetes solution for self-hosted runners
- **Persistent state**: ARC maintains runner state in Kubernetes, surviving pod restarts without re-registration

**Alternatives Considered**:

| Alternative | Why Rejected |
|-------------|--------------|
| Direct runner installation on VM | Not Kubernetes-native, manual lifecycle management, doesn't leverage existing K3s infrastructure |
| summerwind/actions-runner-controller (legacy) | Deprecated in favor of official GitHub ARC |
| Docker Compose runner | Not Kubernetes-integrated, separate management plane |

### 2. ARC Architecture Mode: Runner Scale Set vs Controller-Only

**Decision**: Use Runner Scale Set (runner-scale-set) mode

**Rationale**:
- **Simplified architecture**: Single component (gha-runner-scale-set) manages both controller and runners
- **Better scaling**: Native autoscaling based on workflow demand
- **Newer design**: GitHub's recommended architecture for new deployments (post 2023)
- **Resource efficiency**: Runners scale to zero when idle, saving cluster resources

**Alternatives Considered**:

| Alternative | Why Rejected |
|-------------|--------------|
| Controller + RunnerDeployment (legacy mode) | Older architecture, more complex setup, being phased out |
| Static runner count | Wastes resources when idle, doesn't handle demand spikes |

### 3. Runner Scope: Repository vs Organization Level

**Decision**: Start with repository-level runner, document path to organization-level

**Rationale**:
- **Simpler setup**: Repository-level requires only repo admin permissions
- **Isolated testing**: Can test with single repo before expanding
- **Token management**: Repository tokens are easier to manage and rotate
- **Lower risk**: Issues affect only one repository, not entire organization

**Alternatives Considered**:

| Alternative | Why Rejected |
|-------------|--------------|
| Organization-level from start | Requires org admin permissions, broader blast radius, more complex initial setup |
| Enterprise-level | Not applicable for personal/small org use |

### 4. Container Execution Mode: DinD vs Kubernetes Mode

**Decision**: Use Kubernetes mode (container actions run as separate pods)

**Rationale**:
- **Security**: No privileged containers required (DinD requires privileged mode)
- **Isolation**: Each job step runs in isolated container
- **Resource control**: Better resource limiting per job via Kubernetes
- **K3s compatible**: Works well with containerd runtime in K3s

**Alternatives Considered**:

| Alternative | Why Rejected |
|-------------|--------------|
| Docker-in-Docker (DinD) | Requires privileged containers, security concern, complex storage management |
| Rootless DinD | More complex setup, potential compatibility issues |

### 5. Helm Chart Source

**Decision**: Use official GitHub ARC Helm charts from `ghcr.io/actions/actions-runner-controller-charts`

**Rationale**:
- **Official support**: Maintained by GitHub, guaranteed compatibility
- **Regular updates**: Security patches and new features
- **Documentation**: Well-documented with examples
- **OCI registry**: Modern Helm chart distribution via ghcr.io

**Chart Components**:
1. `gha-runner-scale-set-controller` - Cluster-wide controller (one per cluster)
2. `gha-runner-scale-set` - Runner deployment per repository/organization

### 6. Authentication Method: PAT vs GitHub App

**Decision**: Use GitHub App authentication

**Rationale**:
- **Security**: Fine-grained permissions, can limit to specific repos
- **Token rotation**: App tokens auto-rotate (1 hour lifetime), no manual renewal
- **Rate limits**: Higher API rate limits than PAT
- **Audit trail**: Better visibility into API usage per app

**Alternatives Considered**:

| Alternative | Why Rejected |
|-------------|--------------|
| Personal Access Token (PAT) | Broader permissions than needed, manual rotation required, tied to user account |
| Fine-grained PAT | Better than classic PAT but still tied to user account |

**GitHub App Setup Requirements**:
- Create GitHub App in repository/organization settings
- Permissions needed: `actions:read`, `checks:read`, `metadata:read`
- For organization runners: `organization_self_hosted_runners:write`
- Generate and store private key as Kubernetes Secret

### 7. Monitoring Integration

**Decision**: Use Prometheus metrics from ARC controller + custom ServiceMonitor

**Rationale**:
- **Built-in metrics**: ARC exposes Prometheus metrics out of the box
- **Existing stack**: Integrates with homelab's kube-prometheus-stack
- **Grafana dashboards**: Community dashboards available

**Metrics Available**:
- `github_runner_busy` - Runner busy status
- `github_runner_job_started_total` - Jobs started counter
- `github_runner_job_completed_total` - Jobs completed counter
- `github_runner_organization` - Runner organization
- `github_runner_repository` - Runner repository

### 8. Storage Requirements

**Decision**: Ephemeral storage for job workspace, persistent for runner configuration only

**Rationale**:
- **Job isolation**: Each job starts with clean workspace (GitHub Actions expectation)
- **Storage efficiency**: No need to persist job artifacts between runs
- **Cache via Actions cache**: Use GitHub Actions cache for dependency caching, not local storage
- **Config persistence**: Only runner registration state needs persistence

**Storage Configuration**:
- Runner work directory: emptyDir (ephemeral)
- Tool cache: emptyDir or PVC (optional, for faster startup)
- ARC controller: PVC for state (managed by Helm)

## Technology Stack Summary

| Component | Technology | Version |
|-----------|-----------|---------|
| IaC | OpenTofu | 1.6+ |
| Container Orchestration | K3s | 1.28+ |
| Runner Controller | Actions Runner Controller (ARC) | 0.9.x |
| Helm Charts | gha-runner-scale-set-controller, gha-runner-scale-set | Latest |
| Monitoring | Prometheus + Grafana | Existing stack |
| Storage | local-path-provisioner | Existing |
| Authentication | GitHub App | N/A |

## Open Items / Future Enhancements

1. **Auto-scaling configuration**: Currently using fixed replica count; can enable autoscaling based on queue depth
2. **Organization-level expansion**: After successful repo-level deployment, document upgrade path
3. **Custom runner image**: If specific tools needed, create custom runner image
4. **Caching optimization**: Evaluate GitHub Actions cache vs local PVC for dependency caching
