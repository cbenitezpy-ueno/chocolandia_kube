# ArgoCD Module

Feature 008: GitOps Continuous Deployment with ArgoCD

This module deploys ArgoCD to a Kubernetes cluster for GitOps-based continuous deployment from GitHub.

## Features

- **ArgoCD Helm Deployment**: Single-replica configuration optimized for homelab scale
- **GitHub Repository Authentication**: Private repository access via Personal Access Token
- **Traefik IngressRoute**: HTTPS access via Traefik ingress controller
- **TLS Certificate**: Automated certificate issuance via cert-manager (Let's Encrypt)
- **Cloudflare Access**: Google OAuth authentication protection
- **Prometheus Integration**: Metrics exposure via ServiceMonitor resources
- **Custom Health Checks**: Support for Traefik IngressRoute and cert-manager Certificate CRDs

## Architecture

```
GitHub Repository (main branch)
        ↓ (poll every 3 minutes)
    ArgoCD Application
        ↓ (auto-sync: prune, selfHeal)
    Kubernetes Cluster
```

## Components

### ArgoCD Server
- **Purpose**: Web UI and gRPC API
- **Replicas**: 1 (homelab scale)
- **Resources**: 100m CPU / 128Mi RAM (request), 200m CPU / 256Mi RAM (limit)
- **Metrics Port**: 8084

### ArgoCD Repository Server
- **Purpose**: Git repository operations
- **Replicas**: 1 (homelab scale)
- **Resources**: 100m CPU / 64Mi RAM (request), 200m CPU / 128Mi RAM (limit)
- **Metrics Port**: 8084

### ArgoCD Application Controller
- **Purpose**: Application sync engine
- **Replicas**: 1 (homelab scale)
- **Resources**: 250m CPU / 256Mi RAM (request), 500m CPU / 512Mi RAM (limit)
- **Metrics Port**: 8082

### Redis
- **Purpose**: Caching layer
- **Resources**: 50m CPU / 64Mi RAM (request), 100m CPU / 128Mi RAM (limit)

## Usage

```hcl
module "argocd" {
  source = "../../modules/argocd"

  # Core Configuration
  argocd_domain        = "argocd.chocolandiadc.com"
  argocd_namespace     = "argocd"
  argocd_chart_version = "5.51.0"  # ArgoCD v2.9.x

  # GitHub Repository Authentication
  github_token    = var.github_token
  github_username = "your-github-username"
  github_repo_url = "https://github.com/your-org/your-repo"

  # TLS Certificate Configuration
  cluster_issuer           = "letsencrypt-production"
  certificate_duration     = "2160h0m0s"  # 90 days
  certificate_renew_before = "720h0m0s"   # 30 days

  # Cloudflare Access Configuration
  cloudflare_account_id      = var.cloudflare_account_id
  authorized_emails          = ["user@example.com"]
  google_oauth_idp_id        = var.google_oauth_idp_id
  access_session_duration    = "24h"
  access_auto_redirect       = true
  access_app_launcher_visible = true

  # Prometheus Metrics
  enable_prometheus_metrics = true

  # ArgoCD Component Resources
  server_replicas           = 1
  server_cpu_limit          = "200m"
  server_memory_limit       = "256Mi"
  repo_server_replicas      = 1
  repo_server_cpu_limit     = "200m"
  repo_server_memory_limit  = "128Mi"
  controller_replicas       = 1
  controller_cpu_limit      = "500m"
  controller_memory_limit   = "512Mi"

  # Repository Polling Interval
  repository_polling_interval = "180s"  # 3 minutes
}
```

## Prometheus Integration

### ServiceMonitor Resources

This module creates three ServiceMonitor resources for Prometheus Operator:

1. **argocd-metrics** (ArgoCD Server)
   - Port: `metrics` (8084)
   - Path: `/metrics`
   - Interval: `30s`

2. **argocd-repo-server-metrics** (Repository Server)
   - Port: `metrics` (8084)
   - Path: `/metrics`
   - Interval: `30s`

3. **argocd-application-controller-metrics** (Application Controller)
   - Port: `metrics` (8082)
   - Path: `/metrics`
   - Interval: `30s`

### Available Metrics

#### Application Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `argocd_app_info` | Gauge | Application metadata (name, namespace, health_status, sync_status) |
| `argocd_app_sync_total` | Counter | Total number of application sync operations |
| `argocd_app_health_status` | Gauge | Application health status (0=Unknown, 1=Progressing, 2=Healthy, 3=Suspended, 4=Degraded, 5=Missing) |
| `argocd_app_sync_status` | Gauge | Application sync status (0=Unknown, 1=Synced, 2=OutOfSync) |

#### Repository Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `argocd_git_request_total` | Counter | Total number of Git requests |
| `argocd_git_request_duration_seconds` | Histogram | Git request duration in seconds |
| `argocd_repo_pending_request_total` | Gauge | Number of pending repository requests |

#### Controller Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `argocd_app_reconcile_count` | Counter | Application reconciliation count |
| `argocd_app_k8s_request_total` | Counter | Number of Kubernetes API requests |
| `argocd_cluster_api_resource_objects` | Gauge | Number of monitored Kubernetes API resources |
| `argocd_kubectl_exec_pending` | Gauge | Number of pending kubectl executions |

### Querying Metrics

#### Check Application Status
```promql
argocd_app_info{name="chocolandia-kube"}
```

#### Count Applications by Health Status
```promql
count by (health_status) (argocd_app_info)
```

#### Count Applications by Sync Status
```promql
count by (sync_status) (argocd_app_info)
```

#### Application Sync Rate (last 5 minutes)
```promql
rate(argocd_app_sync_total[5m])
```

#### Git Request Duration (p95)
```promql
histogram_quantile(0.95, sum(rate(argocd_git_request_duration_seconds_bucket[5m])) by (le))
```

#### Application Reconciliation Rate
```promql
rate(argocd_app_reconcile_count[5m])
```

### Grafana Dashboards

ArgoCD provides official Grafana dashboards:

- **Dashboard ID 14584**: ArgoCD Application Overview
- **Dashboard ID 14585**: ArgoCD Repository Server
- **Dashboard ID 14586**: ArgoCD Notifications

Import via Grafana UI: Dashboards → Import → Enter ID

### Accessing Prometheus

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Access Prometheus UI
open http://localhost:9090

# Check ArgoCD targets
# Navigate to: Status → Targets → Search "argocd"
```

### Verifying Metrics Collection

```bash
# Check ServiceMonitor resources
kubectl get servicemonitor -n argocd

# Query metrics from Prometheus
curl -s 'http://localhost:9090/api/v1/query?query=argocd_app_info' | jq
```

## Outputs

| Output | Description |
|--------|-------------|
| `namespace` | Kubernetes namespace where ArgoCD is deployed |
| `service_name` | ArgoCD server service name |
| `argocd_url` | ArgoCD web UI URL (HTTPS) |
| `admin_password_retrieval_command` | Command to retrieve initial admin password |
| `cli_login_command` | ArgoCD CLI login command |
| `certificate_name` | cert-manager Certificate resource name |
| `github_credentials_secret` | GitHub repository credentials Secret name |
| `servicemonitor_name` | Prometheus ServiceMonitor name (if enabled) |
| `metrics_endpoints` | ArgoCD metrics endpoints for Prometheus |

## Access

### Web UI

URL: `https://argocd.chocolandiadc.com`

**Credentials:**
- Username: `admin`
- Password: Retrieve using output command

```bash
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

**Note:** Change the password after first login via UI: User Info → Update Password

### CLI

```bash
# Install ArgoCD CLI
brew install argocd  # macOS
# or
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Login
argocd login argocd.chocolandiadc.com --grpc-web
# Enter credentials when prompted

# List applications
argocd app list

# Get application details
argocd app get chocolandia-kube

# Sync application manually
argocd app sync chocolandia-kube

# Watch sync status
argocd app wait chocolandia-kube --sync
```

## Troubleshooting

### Application OutOfSync

```bash
# Check Application status
kubectl get application -n argocd chocolandia-kube

# Describe Application for events
kubectl describe application -n argocd chocolandia-kube

# View sync operation details
argocd app get chocolandia-kube
```

### Certificate Issues

```bash
# Check Certificate status
kubectl get certificate -n argocd argocd-tls

# Describe Certificate for events
kubectl describe certificate -n argocd argocd-tls

# Check CertificateRequest
kubectl get certificaterequest -n argocd
```

### Metrics Not Appearing

```bash
# Verify ServiceMonitor created
kubectl get servicemonitor -n argocd

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090/targets (search "argocd")

# Check ArgoCD pods exposing metrics
kubectl get pods -n argocd -o wide
kubectl port-forward -n argocd svc/argocd-server 8084:8084
curl http://localhost:8084/metrics
```

### Repository Connection Issues

```bash
# Check GitHub credentials Secret
kubectl get secret -n argocd chocolandia-kube-repo

# Test repository connection from ArgoCD
argocd repo list
argocd repo get https://github.com/your-org/your-repo
```

## Security Considerations

1. **GitHub Token**: Store as Terraform sensitive variable or environment variable (`TF_VAR_github_token`)
2. **Admin Password**: Change immediately after first login
3. **RBAC**: Configure ArgoCD Projects and Roles for team access
4. **Cloudflare Access**: Restrict authorized_emails to team members only
5. **TLS Certificates**: Automatically renewed by cert-manager 30 days before expiration
6. **Network Policies**: Consider implementing Kubernetes NetworkPolicies for pod-to-pod communication

## Maintenance

### Upgrade ArgoCD

Update the `argocd_chart_version` variable and apply:

```bash
tofu apply -target=module.argocd
```

### Backup Configuration

ArgoCD configuration is stored in Kubernetes ConfigMaps and Secrets:

```bash
# Backup ArgoCD ConfigMaps
kubectl get configmap -n argocd -o yaml > argocd-configmaps-backup.yaml

# Backup ArgoCD Secrets
kubectl get secret -n argocd -o yaml > argocd-secrets-backup.yaml
```

### Disaster Recovery

ArgoCD state is stored in Kubernetes. For disaster recovery:

1. Backup etcd or use Velero for cluster-wide backups
2. Store GitHub repository credentials securely (e.g., HashiCorp Vault)
3. Document Cloudflare Access configuration
4. Keep Terraform state backed up (S3, Terraform Cloud, etc.)

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [ArgoCD Metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
