# GitHub Actions Self-Hosted Runner Module

OpenTofu module for deploying GitHub Actions self-hosted runners on Kubernetes using Actions Runner Controller (ARC).

## Overview

This module deploys:
- ARC controller (gha-runner-scale-set-controller) - cluster-wide controller
- Runner scale set (gha-runner-scale-set) - repository/organization runners
- ServiceMonitor for Prometheus metrics
- PrometheusRule for alerting

## Prerequisites

1. K3s cluster with Helm support
2. GitHub App created with required permissions
3. Prometheus/Grafana monitoring stack (for US2)

## Usage

```hcl
module "github_actions_runner" {
  source = "../../modules/github-actions-runner"

  github_config_url            = "https://github.com/your-org/your-repo"
  github_app_id                = var.github_app_id
  github_app_installation_id   = var.github_app_installation_id
  github_app_private_key       = var.github_app_private_key

  # Optional
  namespace         = "github-actions"
  runner_name       = "homelab-runner"
  min_runners       = 1
  max_runners       = 4
  runner_labels     = ["self-hosted", "linux", "x64", "homelab"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| github_config_url | Repository or organization URL | string | - | yes |
| github_app_id | GitHub App ID | string | - | yes |
| github_app_installation_id | GitHub App Installation ID | string | - | yes |
| github_app_private_key | GitHub App private key (PEM) | string | - | yes |
| namespace | Kubernetes namespace | string | "github-actions" | no |
| runner_name | Runner scale set name | string | "homelab-runner" | no |
| min_runners | Minimum runners | number | 0 | no |
| max_runners | Maximum runners | number | 4 | no |
| runner_labels | Runner labels | list(string) | ["self-hosted", "linux", "x64", "homelab"] | no |
| cpu_request | CPU request per runner | string | "500m" | no |
| memory_request | Memory request per runner | string | "1Gi" | no |
| cpu_limit | CPU limit per runner | string | "2" | no |
| memory_limit | Memory limit per runner | string | "4Gi" | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Namespace where runners are deployed |
| runner_name | Runner scale set name |
| controller_status | ARC controller deployment status |

## GitHub App Setup

See [quickstart.md](../../../specs/017-github-actions-runner/quickstart.md) for detailed GitHub App setup instructions.

Required permissions:
- Repository permissions: Actions (Read), Administration (Read & Write), Checks (Read), Metadata (Read)

## Architecture

```
ARC Controller (cluster-wide)
    |
    +-- Runner Scale Set (per repo/org)
            |
            +-- Runner Pod 1
            +-- Runner Pod 2
            +-- Runner Pod N (up to max_runners)
```

## Workflow Usage

Once deployed, use the self-hosted runner in your GitHub Actions workflows:

```yaml
name: CI
on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, linux, x64, homelab]
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: make build
```

Or use the runner name directly:

```yaml
jobs:
  build:
    runs-on: homelab-runner
    steps:
      - uses: actions/checkout@v4
```

## Deployment

1. **Create GitHub App** (see quickstart.md)

2. **Set environment variables**:
   ```bash
   export TF_VAR_github_app_id="123456"
   export TF_VAR_github_app_installation_id="12345678"
   export TF_VAR_github_app_private_key="$(cat your-app.pem)"
   ```

3. **Deploy with OpenTofu**:
   ```bash
   cd terraform/environments/chocolandiadc-mvp
   tofu init
   tofu plan
   tofu apply
   ```

4. **Validate deployment**:
   ```bash
   ./scripts/github-actions-runner/validate-runner.sh
   ```

5. **Test with workflow**:
   ```bash
   ./scripts/github-actions-runner/test-workflow.sh
   ```

## Monitoring

When `enable_monitoring = true`:
- ServiceMonitor for Prometheus scraping
- PrometheusRule for alerting (runner offline)
- Grafana dashboard available at `terraform/dashboards/github-actions-runner.json`

### Alerts

| Alert | Severity | Description |
|-------|----------|-------------|
| GitHubRunnerOffline | warning | No runner metrics for 5+ minutes |
| GitHubRunnerHighUtilization | warning | Runner busy for 30+ minutes |

## Troubleshooting

### Runner not registering

1. Check GitHub App credentials:
   ```bash
   kubectl get secret -n github-actions github-app-secret -o yaml
   ```

2. Check ARC controller logs:
   ```bash
   kubectl logs -n github-actions -l app.kubernetes.io/name=gha-runner-scale-set-controller
   ```

3. Verify runner scale set:
   ```bash
   kubectl get autoscalingrunnersets -n github-actions
   ```

### Jobs stuck in queued state

1. Check runner pods:
   ```bash
   kubectl get pods -n github-actions -l actions.github.com/scale-set-name=homelab-runner
   ```

2. Check runner logs:
   ```bash
   kubectl logs -n github-actions -l actions.github.com/scale-set-name=homelab-runner
   ```

## Related Documentation

- [ARC Documentation](https://github.com/actions/actions-runner-controller)
- [GitHub Apps](https://docs.github.com/en/apps)
- [Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners)
