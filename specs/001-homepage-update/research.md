# Homepage Dashboard Configuration Research
**Feature**: 001-homepage-update
**Date**: 2025-11-18
**Author**: Claude Code

## Table of Contents
1. [ArgoCD API Token Generation](#argocd-api-token-generation)
2. [Homepage Widget Documentation](#homepage-widget-documentation)
3. [Service Inventory](#service-inventory)
4. [Decisions and Rationale](#decisions-and-rationale)

---

## 1. ArgoCD API Token Generation

### Overview
ArgoCD supports local user accounts with API token capabilities for automation and integration purposes. Homepage requires a read-only API token to display application sync status.

### Token Generation Process

#### Step 1: Create Local User Account
Edit the `argocd-cm` ConfigMap to create a new local user with the `apiKey` capability:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  accounts.homepage: apiKey
```

**Note**:
- The `apiKey` capability allows generating authentication tokens for API access
- Maximum username length is 32 characters
- The account name `homepage` clearly identifies its purpose

#### Step 2: Configure RBAC Permissions
Edit the `argocd-rbac-cm` ConfigMap to grant read-only permissions:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    g, homepage, role:readonly
```

**Explanation**:
- `role:readonly` is a built-in ArgoCD role providing read-only access to all resources
- This grants the `homepage` account minimal permissions needed for status monitoring
- No write, delete, or sync capabilities

#### Step 3: Generate API Token
Use the ArgoCD CLI to generate the token:

```bash
# Login to ArgoCD first
argocd login argocd.chocolandiadc.com

# Generate token for homepage account
argocd account generate-token --account homepage
```

**Output**: A JWT token that doesn't expire (unless configured otherwise)

#### Alternative: Generate Token via API
If CLI access is not available:

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login and get session token
curl -k https://argocd.chocolandiadc.com/api/v1/session -d '{"username":"admin","password":"<PASSWORD>"}'

# Generate account token
curl -k -H "Authorization: Bearer <SESSION_TOKEN>" \
  https://argocd.chocolandiadc.com/api/v1/account/homepage/token -X POST
```

### Security Considerations

**CVE-2025-55190 Warning**:
- Project-level API tokens can potentially expose repository credentials
- Recommendation: Use account-level tokens (as documented above) rather than project-level tokens
- Ensure token is stored securely in Kubernetes secrets, not in plain text

### Token Permissions
The read-only token can:
- List applications and their sync status
- View application health and deployment details
- Read project information
- Access metrics and logs (read-only)

The read-only token CANNOT:
- Create, update, or delete applications
- Trigger syncs or rollbacks
- Modify RBAC policies
- Access repository credentials

---

## 2. Homepage Widget Documentation

### ArgoCD Widget Configuration

#### Required Parameters
```yaml
widget:
  type: argocd
  url: http://argocd-server.argocd.svc.cluster.local:80
  key: <API_TOKEN>
```

#### Display Metrics
The ArgoCD widget can display up to 4 metrics from:
- `apps` - Total number of applications
- `synced` - Applications in sync with Git
- `outOfSync` - Applications not in sync
- `healthy` - Applications in healthy state
- `progressing` - Applications currently deploying
- `degraded` - Applications in degraded state
- `suspended` - Applications that are suspended
- `missing` - Applications with missing resources

#### Configuration Example
```yaml
services:
  - ArgoCD:
      href: https://argocd.chocolandiadc.com
      description: GitOps Continuous Deployment
      widget:
        type: argocd
        url: http://argocd-server.argocd.svc.cluster.local:80
        key: {{HOMEPAGE_VAR_ARGOCD_TOKEN}}
```

### Kubernetes Widget Configuration

#### Overview
Homepage supports automatic Kubernetes integration for displaying pod statistics and resource usage.

#### Configuration Mode
Set in `kubernetes.yaml`:
```yaml
mode: cluster
```

**Note**: `cluster` mode uses in-cluster ServiceAccount credentials (recommended for pod deployment)

#### Service Discovery
Homepage supports automatic service discovery via annotations on Ingress/IngressRoute resources:

```yaml
annotations:
  gethomepage.dev/enabled: "true"
  gethomepage.dev/name: "Service Name"
  gethomepage.dev/description: "Service description"
  gethomepage.dev/group: "Category"
  gethomepage.dev/icon: "icon-name"
  gethomepage.dev/widget.type: "widget-type"
  gethomepage.dev/widget.url: "http://service:port"
  gethomepage.dev/pod-selector: "app=service-name"
```

#### Resource Metrics
- Displays CPU and memory usage for pods
- Requires `metrics-server` to be running (already deployed in cluster)
- Shows pod health status (Running/Pending/Failed)

#### RBAC Requirements
Homepage requires a ServiceAccount with permissions to:
- Read pods, services, ingresses across namespaces
- Access metrics API
- Read configmaps (for configuration)

### Widget Refresh and Error Handling

#### Refresh Intervals
- Default refresh interval: Not explicitly documented (appears to be ~60 seconds based on community feedback)
- Configurable per widget (not documented in official sources)
- Recommendation: Use default intervals to avoid API rate limiting

#### Error Handling
- Widgets display error states when API calls fail
- No automatic retry mechanism documented
- Errors typically resolve on next refresh cycle
- Common errors:
  - Authentication failures (invalid token)
  - Network connectivity issues
  - API endpoint unavailable
  - Rate limiting (if polling too frequently)

---

## 3. Service Inventory

### Service Access Summary

| Service | Namespace | Type | Internal Access | External Access | Public URL |
|---------|-----------|------|----------------|-----------------|------------|
| ArgoCD | argocd | ClusterIP | 10.43.168.60:80/443 | Via Ingress | https://argocd.chocolandiadc.com |
| Beersystem Frontend | beersystem | ClusterIP | 10.43.78.231:80 | Via Cloudflare | https://beer.chocolandiadc.com |
| Beersystem Backend | beersystem | ClusterIP | 10.43.17.218:3001 | Internal only | N/A |
| Redis (Beersystem) | beersystem | ClusterIP | 10.43.244.134:6379 | Internal only | N/A |
| Grafana | monitoring | NodePort | 10.43.88.111:80 | NodePort 30000 | https://grafana.chocolandiadc.com |
| Headlamp | headlamp | ClusterIP | 10.43.58.76:80 | Via Ingress | https://headlamp.chocolandiadc.com |
| Homepage | homepage | ClusterIP | 10.43.14.245:3000 | Via Ingress | https://homepage.chocolandiadc.com |
| Longhorn UI | longhorn-system | ClusterIP | 10.43.6.147:80 | Via Ingress | https://longhorn.chocolandiadc.com |
| MinIO Console | minio | ClusterIP | 10.43.92.164:9001 | Via Ingress | https://minio.chocolandiadc.com |
| MinIO S3 API | minio | ClusterIP | 10.43.2.206:9000 | Via Ingress | https://s3.chocolandiadc.com |
| Pi-hole DNS | default | LoadBalancer | 10.43.141.23:53 | 192.168.4.201:53 | N/A (DNS only) |
| Pi-hole Web | default | NodePort | 10.43.48.13:80 | NodePort 30001 | https://pihole.chocolandiadc.com |
| PostgreSQL Primary | postgresql | LoadBalancer | 10.43.196.210:5432 | 192.168.4.200:5432 | N/A (Database) |
| Prometheus | monitoring | ClusterIP | 10.43.144.55:9090 | Internal only | N/A |
| Alertmanager | monitoring | ClusterIP | 10.43.42.93:9093 | Internal only | N/A |

### Detailed Service Information

#### 1. ArgoCD
- **Namespace**: argocd
- **Service Type**: ClusterIP
- **Internal URL**: http://argocd-server.argocd.svc.cluster.local:80
- **Public URL**: https://argocd.chocolandiadc.com
- **Access Method**:
  - Public: Cloudflare Zero Trust with Google OAuth
  - Private: Traefik IngressRoute with TLS
- **Purpose**: GitOps continuous deployment platform
- **Widget Available**: Yes (ArgoCD widget)

#### 2. Beersystem Application
- **Frontend**:
  - Namespace: beersystem
  - Service Type: ClusterIP
  - Internal URL: http://beersystem-frontend.beersystem.svc.cluster.local:80
  - Public URL: https://beer.chocolandiadc.com
  - Access: Cloudflare Zero Trust

- **Backend**:
  - Service Type: ClusterIP
  - Internal URL: http://beersystem-backend.beersystem.svc.cluster.local:3001
  - Access: Internal only (frontend communicates with backend)

- **Redis Cache**:
  - Service Type: ClusterIP
  - Internal URL: redis.beersystem.svc.cluster.local:6379
  - Access: Internal only

#### 3. Grafana
- **Namespace**: monitoring
- **Service Type**: NodePort
- **Internal URL**: http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80
- **NodePort**: 30000 (accessible on any node IP)
- **Public URL**: https://grafana.chocolandiadc.com
- **Access Method**:
  - Public: Cloudflare Zero Trust
  - Private: Direct NodePort access on 192.168.4.101-104:30000
- **Purpose**: Metrics visualization and dashboards
- **Widget Available**: Yes (Grafana widget)

#### 4. Headlamp
- **Namespace**: headlamp
- **Service Type**: ClusterIP
- **Internal URL**: http://headlamp.headlamp.svc.cluster.local:80
- **Public URL**: https://headlamp.chocolandiadc.com
- **Access Method**: Traefik IngressRoute with TLS, Cloudflare Access
- **Purpose**: Kubernetes web UI dashboard
- **Widget Available**: No native widget, use link

#### 5. Homepage (Self)
- **Namespace**: homepage
- **Service Type**: ClusterIP
- **Internal URL**: http://homepage.homepage.svc.cluster.local:3000
- **Public URL**: https://homepage.chocolandiadc.com
- **Access Method**: Traefik IngressRoute with TLS, Cloudflare Access
- **Purpose**: Centralized service dashboard
- **Managed by**: ArgoCD

#### 6. Longhorn
- **Namespace**: longhorn-system
- **Service Type**: ClusterIP
- **Internal URL**: http://longhorn-frontend.longhorn-system.svc.cluster.local:80
- **Public URL**: https://longhorn.chocolandiadc.com
- **Access Method**: Traefik IngressRoute with TLS
- **Purpose**: Distributed block storage for Kubernetes
- **Widget Available**: No native widget

#### 7. MinIO
- **Console**:
  - Namespace: minio
  - Service Type: ClusterIP
  - Internal URL: http://minio-console.minio.svc.cluster.local:9001
  - Public URL: https://minio.chocolandiadc.com
  - Purpose: S3-compatible object storage UI

- **S3 API**:
  - Internal URL: http://minio-api.minio.svc.cluster.local:9000
  - Public URL: https://s3.chocolandiadc.com
  - Purpose: S3 API endpoint
  - Widget Available: No native widget

#### 8. Pi-hole
- **DNS Service**:
  - Namespace: default
  - Service Type: LoadBalancer
  - Internal IP: 10.43.141.23
  - External IP: 192.168.4.201
  - Ports: 53/TCP, 53/UDP
  - Purpose: Network-wide DNS and ad blocking

- **Web Admin**:
  - Service Type: NodePort
  - NodePort: 30001
  - Public URL: https://pihole.chocolandiadc.com
  - Access: Cloudflare Zero Trust
  - Widget Available: Yes (Pi-hole widget)

#### 9. PostgreSQL HA Cluster
- **Primary**:
  - Namespace: postgresql
  - Service Type: LoadBalancer
  - Internal IP: 10.43.196.210
  - External IP: 192.168.4.200
  - Port: 5432
  - Access: Direct database access from nodes
  - Purpose: High-availability PostgreSQL cluster

- **Read Replicas**:
  - Service Type: ClusterIP
  - Internal URL: postgres-ha-postgresql-read.postgresql.svc.cluster.local:5432
  - Purpose: Load-balanced read queries

#### 10. Prometheus Stack
- **Prometheus**:
  - Namespace: monitoring
  - Service Type: ClusterIP
  - Internal URL: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
  - Purpose: Metrics collection and storage
  - Widget Available: Yes (Prometheus widget)

- **Alertmanager**:
  - Service Type: ClusterIP
  - Internal URL: http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093
  - Purpose: Alert routing and management

### Network Architecture

#### MetalLB LoadBalancer Pool
- **Pool Name**: eero-pool
- **IP Range**: 192.168.4.200-192.168.4.210
- **Advertisement**: L2 (Layer 2)
- **Active Assignments**:
  - 192.168.4.200: PostgreSQL Primary
  - 192.168.4.201: Pi-hole DNS
  - 192.168.4.202-210: Available

**Note**: Traefik LoadBalancer shows `<pending>` status - needs investigation

#### Cloudflare Zero Trust Tunnel
All public HTTPS services are routed through Cloudflare Zero Trust:
- **Tunnel Name**: chocolandiadc-tunnel
- **Authentication**: Google OAuth (cbenitez@gmail.com authorized)
- **Protected Services**:
  - pihole.chocolandiadc.com
  - grafana.chocolandiadc.com
  - headlamp.chocolandiadc.com
  - argocd.chocolandiadc.com
  - homepage.chocolandiadc.com
  - beer.chocolandiadc.com
  - longhorn.chocolandiadc.com
  - minio.chocolandiadc.com
  - s3.chocolandiadc.com

#### Private Network Access
Services accessible on the private 192.168.4.0/24 network:
- **PostgreSQL**: 192.168.4.200:5432 (database connections)
- **Pi-hole DNS**: 192.168.4.201:53 (DNS queries)
- **Grafana**: Any node IP:30000 (NodePort)
- **Pi-hole Web**: Any node IP:30001 (NodePort)
- **Kubernetes API**: 192.168.4.101:6443, 192.168.4.103:6443

### Services Missing Public Ingress

The following services are deployed but lack IngressRoute/public access:
1. **Prometheus** - Internal metrics only
2. **Alertmanager** - Internal alerting only
3. **Beersystem Backend** - Internal API only (accessed by frontend)
4. **Redis** - Internal cache only

### Netdata Status
- **Status**: Not currently deployed
- **Terraform Module**: Exists at `/Users/cbenitez/chocolandia_kube/terraform/modules/netdata/main.tf`
- **Planned Configuration**:
  - Service Type: NodePort 32303
  - Namespace: netdata
  - Purpose: Real-time hardware and performance monitoring
- **Recommendation**: Deploy if hardware monitoring is needed

---

## 4. Decisions and Rationale

### Decision 1: Use Account-Level API Token for ArgoCD
**Rationale**:
- Account-level tokens are more secure than project-level tokens (CVE-2025-55190)
- Read-only role provides exactly the permissions needed for Homepage
- Easier to manage and rotate compared to project tokens
- Clear separation of concerns (homepage account only for monitoring)

### Decision 2: Use In-Cluster Service URLs for Widgets
**Rationale**:
- Homepage pod runs inside the cluster (namespace: homepage)
- Using ClusterIP service URLs (e.g., `http://argocd-server.argocd.svc.cluster.local:80`) avoids:
  - External DNS lookups
  - Cloudflare authentication challenges
  - TLS certificate validation issues
  - Additional network hops
- Faster response times and more reliable connectivity
- Follows Kubernetes best practices for service-to-service communication

### Decision 3: Configure Kubernetes Mode as "cluster"
**Rationale**:
- Homepage is deployed as a pod in the cluster
- "cluster" mode automatically uses the pod's ServiceAccount credentials
- Eliminates need for kubeconfig management
- More secure than exposing kubeconfig file
- Aligns with Kubernetes RBAC best practices

### Decision 4: Enable Automatic Service Discovery
**Rationale**:
- Reduces manual configuration maintenance
- Services can self-register via IngressRoute annotations
- Consistent with GitOps principles (configuration in manifests)
- Easier to add/remove services without modifying Homepage config
- Clear documentation via annotations

### Decision 5: Focus on Active Services Only
**Rationale**:
- Netdata is not currently deployed (no namespace exists)
- Including only active services provides accurate current state
- Netdata can be added to Homepage configuration when/if deployed
- Prevents confusion from documenting non-existent services

### Decision 6: Prioritize Widget Coverage
**Services with native Homepage widgets**:
- ArgoCD (deployment status)
- Grafana (dashboards)
- Pi-hole (blocking statistics)
- Prometheus (metrics)
- Kubernetes (cluster resources)

**Services without widgets**:
- Headlamp (link only)
- Longhorn (link only)
- MinIO (link only)
- Beersystem (link only)

**Rationale**: Prioritize configuring widgets for services with native support to provide rich, real-time information. Other services can be added as links with basic metadata.

### Decision 7: Store ArgoCD Token in Kubernetes Secret
**Rationale**:
- Follows security best practices
- Already configured in terraform.tfvars (line 199)
- Homepage can reference secret via environment variable
- Enables token rotation without modifying ConfigMap
- Prevents token exposure in ArgoCD-managed manifests

### Configuration Approach
```yaml
# In Homepage deployment
env:
  - name: HOMEPAGE_VAR_ARGOCD_TOKEN
    valueFrom:
      secretKeyRef:
        name: homepage-secrets
        key: argocd-token
```

### Decision 8: Group Services Logically
**Proposed Groups**:
1. **Infrastructure**: Kubernetes, ArgoCD, Headlamp
2. **Storage**: PostgreSQL, MinIO, Longhorn
3. **Monitoring**: Grafana, Prometheus, Pi-hole
4. **Applications**: Beersystem

**Rationale**: Logical grouping improves dashboard usability and helps users quickly locate services by function.

---

## Next Steps

1. **Create ArgoCD Read-Only Account**:
   - Edit `argocd-cm` ConfigMap to add `accounts.homepage: apiKey`
   - Edit `argocd-rbac-cm` ConfigMap to add `g, homepage, role:readonly`
   - Apply changes and restart ArgoCD pods if needed

2. **Generate and Store API Token**:
   - Use `argocd account generate-token --account homepage`
   - Create/update Kubernetes secret `homepage-secrets` with token
   - Update Homepage deployment to reference secret

3. **Configure Homepage Widgets**:
   - Update `services.yaml` to include ArgoCD widget
   - Add other service widgets (Grafana, Pi-hole, Prometheus)
   - Configure service links for non-widget services

4. **Test Widget Functionality**:
   - Verify ArgoCD widget displays application status
   - Check Kubernetes widget shows cluster resources
   - Ensure all public URLs are accessible
   - Validate error handling for unreachable services

5. **Document Configuration**:
   - Add comments to Homepage configuration files
   - Update CLAUDE.md with Homepage widget patterns
   - Document token rotation procedure

6. **Consider Future Enhancements**:
   - Deploy Netdata if hardware monitoring is needed
   - Add public IngressRoutes for Prometheus/Alertmanager if desired
   - Investigate Traefik LoadBalancer pending status
   - Implement Homepage bookmarks/links section

---

## References

- Homepage Official Documentation: https://gethomepage.dev/
- ArgoCD Widget Documentation: https://gethomepage.dev/widgets/services/argocd/
- Kubernetes Integration: https://gethomepage.dev/configs/kubernetes/
- ArgoCD User Management: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/
- ArgoCD RBAC: https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/
- CVE-2025-55190 Advisory: https://www.upwind.io/feed/cve-2025-55190

---

**Document Version**: 1.0
**Last Updated**: 2025-11-18
**Status**: Complete
