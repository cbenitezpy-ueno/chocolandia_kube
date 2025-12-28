# Quickstart: Homepage Dashboard Redesign

**Feature**: 025-homepage-redesign
**Time to implement**: ~2 hours
**Prerequisites**: Access to K3s cluster, OpenTofu configured

## Overview

This guide walks through implementing the Homepage dashboard redesign. The redesign transforms the basic Homepage into a visually appealing, organized dashboard with cluster health visibility, service organization, and quick reference information.

## Prerequisites Checklist

- [ ] OpenTofu installed and configured
- [ ] kubectl access to the cluster
- [ ] Git access to chocolandia_kube repository
- [ ] Pi-hole API key (Settings → API → Show API Token)
- [ ] Grafana credentials (from monitoring.tf)

## Step 1: Obtain Required Credentials

### Pi-hole API Key

```bash
# Access Pi-hole web UI
open https://pihole.chocolandiadc.com/admin

# Navigate to: Settings → API → Show API Token
# Copy the token value
```

### Verify Existing ArgoCD Token

```bash
# Check if ArgoCD token is already configured
kubectl get secret -n homepage homepage-widgets -o yaml | grep ARGOCD
```

## Step 2: Update OpenTofu Variables

Add new variables to the Homepage module:

```hcl
# In terraform/modules/homepage/variables.tf

variable "pihole_api_key" {
  description = "Pi-hole API key for Homepage widget"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_username" {
  description = "Grafana username for Homepage widget"
  type        = string
  default     = "admin"
}

variable "grafana_password" {
  description = "Grafana password for Homepage widget"
  type        = string
  sensitive   = true
  default     = ""
}
```

Update the secret in main.tf:

```hcl
# In terraform/modules/homepage/main.tf

resource "kubernetes_secret" "homepage_widgets" {
  metadata {
    name      = "homepage-widgets"
    namespace = kubernetes_namespace.homepage.metadata[0].name
  }

  data = {
    HOMEPAGE_VAR_ARGOCD_TOKEN     = var.argocd_token
    HOMEPAGE_VAR_PIHOLE_API_KEY   = var.pihole_api_key
    HOMEPAGE_VAR_GRAFANA_USER     = var.grafana_username
    HOMEPAGE_VAR_GRAFANA_PASSWORD = var.grafana_password
  }

  type = "Opaque"
}
```

## Step 3: Update Configuration Files

Copy the contract files to the module:

```bash
# From repository root
cp specs/025-homepage-redesign/contracts/settings.yaml terraform/modules/homepage/configs/settings.yaml
cp specs/025-homepage-redesign/contracts/widgets.yaml terraform/modules/homepage/configs/widgets.yaml
cp specs/025-homepage-redesign/contracts/services.yaml terraform/modules/homepage/configs/services.yaml
```

## Step 4: Apply Changes

```bash
cd terraform/environments/chocolandiadc-mvp

# Set credentials (use your actual values)
export TF_VAR_pihole_api_key="your-pihole-api-key"
export TF_VAR_grafana_password="your-grafana-password"

# Validate configuration
tofu validate

# Review changes
tofu plan

# Apply changes
tofu apply
```

## Step 5: Verify Deployment

### Check ConfigMap Updates

```bash
# Verify ConfigMaps are updated
kubectl get configmap -n homepage

# Check settings content
kubectl get configmap homepage-settings -n homepage -o yaml

# Check services content
kubectl get configmap homepage-services -n homepage -o yaml
```

### Verify Pod Status

```bash
# Check Homepage pod is running
kubectl get pods -n homepage

# Watch logs for errors
kubectl logs -n homepage -l app=homepage -f
```

### Access Dashboard

```bash
# Open in browser
open https://homepage.chocolandiadc.com
```

## Step 6: Validate Features

### Visual Verification Checklist

- [ ] Sky blue color theme applied
- [ ] 6 service categories visible
- [ ] Cluster Health section at top
- [ ] Quick Reference section at bottom
- [ ] Search widget functional
- [ ] Kubernetes widget showing node metrics

### Widget Verification

- [ ] Pi-hole widget shows queries/blocked count
- [ ] ArgoCD widget shows sync status
- [ ] Traefik widget shows routes
- [ ] Grafana widget shows dashboard count

### Performance Check

```bash
# Measure page load time
time curl -s https://homepage.chocolandiadc.com > /dev/null
# Should be < 5 seconds
```

## Troubleshooting

### Widget Shows Error

```bash
# Check pod logs for widget errors
kubectl logs -n homepage -l app=homepage --tail=50 | grep -i error

# Verify secret values
kubectl get secret homepage-widgets -n homepage -o yaml
```

### ConfigMap Not Applied

```bash
# Force pod restart to pick up ConfigMap changes
kubectl rollout restart deployment/homepage -n homepage

# Wait for rollout
kubectl rollout status deployment/homepage -n homepage
```

### Pi-hole Widget Not Working

```bash
# Verify Pi-hole is accessible from Homepage pod
kubectl exec -n homepage -it $(kubectl get pods -n homepage -o name | head -1) -- \
  curl -s http://pihole.default.svc.cluster.local/admin/api.php
```

## Rollback

If needed, restore previous configuration:

```bash
# Git checkout previous version
git checkout HEAD~1 -- terraform/modules/homepage/configs/

# Apply rollback
cd terraform/environments/chocolandiadc-mvp
tofu apply
```

## Next Steps

After successful deployment:

1. Take screenshots for blog article
2. Fine-tune colors/layout if needed
3. Add additional widgets as desired
4. Consider adding background image (optional)

## Files Modified

| File | Change Type | Description |
|------|-------------|-------------|
| terraform/modules/homepage/configs/settings.yaml | Updated | Theme, layout, color scheme |
| terraform/modules/homepage/configs/widgets.yaml | Updated | Header widgets configuration |
| terraform/modules/homepage/configs/services.yaml | Updated | Service categories and widgets |
| terraform/modules/homepage/variables.tf | Updated | New credential variables |
| terraform/modules/homepage/main.tf | Updated | New secrets for widgets |
