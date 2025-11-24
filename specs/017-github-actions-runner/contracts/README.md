# Contracts: GitHub Actions Self-Hosted Runner

**Feature**: 017-github-actions-runner
**Date**: 2025-11-24

## Overview

This feature is an infrastructure deployment that does not expose custom APIs. The runner communicates with GitHub Actions via the official GitHub API.

## External Dependencies

### GitHub Actions API

The Actions Runner Controller (ARC) communicates with GitHub's API for:

| Endpoint | Purpose | Auth Required |
|----------|---------|---------------|
| `api.github.com/repos/{owner}/{repo}/actions/runners` | Runner registration | GitHub App |
| `api.github.com/repos/{owner}/{repo}/actions/runs` | Workflow run status | GitHub App |
| Long-polling webhook connection | Job assignment | GitHub App |

**Documentation**: https://docs.github.com/en/rest/actions/self-hosted-runners

### Prometheus Metrics Endpoint

ARC controller exposes metrics at:

```
http://arc-gha-rs-controller.github-actions.svc:8080/metrics
```

**Metrics Format**: Prometheus exposition format

**Key Metrics**:
- `github_runner_organization_runners` - Total runners per org
- `github_runner_repository_runners` - Total runners per repo
- `github_runner_busy` - Busy runner count
- `github_runner_job_started_total` - Jobs started counter
- `github_runner_job_completed_total` - Jobs completed counter

## No Custom APIs

This deployment does not create custom APIs or services. All communication flows are:

1. **ARC Controller -> GitHub API**: Registration, job polling
2. **Runner Pods -> GitHub API**: Job execution, status updates
3. **Prometheus -> ARC Controller**: Metrics scraping

For integration with workflows, use standard GitHub Actions `runs-on` labels:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64, homelab]
```
