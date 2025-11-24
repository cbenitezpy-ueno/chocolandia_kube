# Quickstart: GitHub Actions Self-Hosted Runner

**Feature**: 017-github-actions-runner
**Date**: 2025-11-24

## Prerequisites

Before deploying, ensure you have:

- [ ] K3s cluster running (verify with `kubectl get nodes`)
- [ ] OpenTofu 1.6+ installed
- [ ] Helm 3.x installed
- [ ] GitHub repository or organization admin access
- [ ] kubectl configured with cluster access

## Step 1: Create GitHub App

1. Go to your GitHub repository Settings > Developer settings > GitHub Apps
2. Click "New GitHub App"
3. Configure the app:
   - **Name**: `homelab-runner-controller`
   - **Homepage URL**: `https://github.com/your-org/your-repo`
   - **Webhook**: Uncheck "Active" (not needed for ARC)
4. Set permissions:
   - Repository permissions:
     - **Actions**: Read-only
     - **Administration**: Read & write (for runner registration)
     - **Checks**: Read-only
     - **Metadata**: Read-only
5. Click "Create GitHub App"
6. Note the **App ID** displayed on the app page
7. Generate a private key (scroll down, click "Generate a private key")
8. Save the downloaded `.pem` file securely
9. Install the app to your repository:
   - Click "Install App" in sidebar
   - Select the repository
   - Note the **Installation ID** from the URL after installation

## Step 2: Store Credentials in Kubernetes

```bash
# Create namespace
kubectl create namespace github-actions

# Create secret with GitHub App credentials
kubectl create secret generic github-app-secret \
  --namespace github-actions \
  --from-literal=github_app_id="YOUR_APP_ID" \
  --from-literal=github_app_installation_id="YOUR_INSTALLATION_ID" \
  --from-file=github_app_private_key=/path/to/your-app.pem
```

## Step 3: Deploy ARC Controller

```bash
# Add Helm repository (OCI-based)
helm install arc \
  --namespace github-actions \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --version 0.9.3
```

Verify controller is running:
```bash
kubectl get pods -n github-actions -l app.kubernetes.io/name=gha-runner-scale-set-controller
```

## Step 4: Deploy Runner Scale Set

```bash
# Deploy runners for your repository
helm install homelab-runner \
  --namespace github-actions \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version 0.9.3 \
  --set githubConfigUrl="https://github.com/YOUR_ORG/YOUR_REPO" \
  --set githubConfigSecret="github-app-secret" \
  --set minRunners=1 \
  --set maxRunners=4 \
  --set runnerScaleSetName="homelab-runner"
```

## Step 5: Verify Deployment

```bash
# Check runner pods
kubectl get pods -n github-actions

# Check runner registration in GitHub
# Go to: Repository > Settings > Actions > Runners
# You should see "homelab-runner" listed as Online
```

## Step 6: Test with a Workflow

Create `.github/workflows/test-runner.yaml` in your repository:

```yaml
name: Test Self-Hosted Runner

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: [self-hosted, linux, x64]
    steps:
      - name: Test runner
        run: |
          echo "Hello from homelab runner!"
          echo "Hostname: $(hostname)"
          echo "Working directory: $(pwd)"
          uname -a
```

Trigger the workflow manually from GitHub Actions tab and verify it runs on your homelab runner.

## Validation Checklist

- [ ] ARC controller pod is running
- [ ] Runner pod(s) are running
- [ ] Runner appears as "Online" in GitHub repository settings
- [ ] Test workflow executes successfully on self-hosted runner
- [ ] Prometheus can scrape ARC metrics (if monitoring enabled)

## Troubleshooting

### Runner not appearing in GitHub

```bash
# Check controller logs
kubectl logs -n github-actions -l app.kubernetes.io/name=gha-runner-scale-set-controller

# Check runner pod logs
kubectl logs -n github-actions -l app.kubernetes.io/name=homelab-runner
```

### Authentication errors

```bash
# Verify secret exists and has correct keys
kubectl get secret github-app-secret -n github-actions -o yaml

# Check App ID and Installation ID are correct
# Re-download private key if needed
```

### Runner goes offline after restart

```bash
# Check if minRunners > 0
helm get values homelab-runner -n github-actions

# Ensure persistent volume is working
kubectl get pvc -n github-actions
```

## Quick Commands Reference

```bash
# Scale runners manually
kubectl scale deployment homelab-runner -n github-actions --replicas=2

# View runner status
kubectl get autoscalingrunnersets -n github-actions

# Delete and redeploy runner
helm uninstall homelab-runner -n github-actions
# Then re-run helm install command

# Upgrade ARC
helm upgrade arc \
  --namespace github-actions \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --version NEW_VERSION
```

## Next Steps

After successful deployment:

1. Configure Grafana dashboard for runner monitoring
2. Set up alerts for runner offline status
3. Consider increasing `maxRunners` for parallel workflows
4. Explore organization-level runners for multiple repositories
