# Research: Headlamp Web UI Deployment

**Feature**: 007-headlamp-web-ui
**Date**: 2025-11-12
**Status**: Research Complete

## Executive Summary

All research tasks completed successfully. Key decisions:
- **Headlamp Chart**: kubernetes-sigs/headlamp v0.38.0 (Helm chart 0.37.0)
- **RBAC**: ClusterRole "view" + long-lived ServiceAccount token
- **Authentication**: Token-based (NOT OIDC) + Cloudflare Access Google OAuth
- **Namespace**: Dedicated `headlamp` namespace
- **Replicas**: 2 (HA across 2-node cluster)
- **Ingress**: Traefik IngressRoute + manual cert-manager Certificate CRD
- **Monitoring**: Health checks only (Headlamp does NOT expose Prometheus metrics)

---

## 1. Headlamp Helm Chart

### Decision
- **Repository**: `https://kubernetes-sigs.github.io/headlamp/`
- **Chart Name**: `headlamp/headlamp`
- **Stable Version**: **v0.38.0** (Helm chart 0.37.0)
- **K3s Compatibility**: Fully compatible with K3s v1.28+ (no special configuration required)

### Configuration

**Add Helm Repository**:
```bash
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update
```

**Critical Helm Values** (values.yaml):
```yaml
# Replicas - for 2-node cluster HA
replicaCount: 2

# Resources - homelab-optimized
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Service type - ClusterIP (Traefik handles ingress)
service:
  type: ClusterIP
  port: 80

# Ingress - DISABLED (using Traefik IngressRoute instead)
ingress:
  enabled: false

# Base URL configuration
config:
  baseURL: ""  # Empty for dedicated domain

# PodDisruptionBudget for HA
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Pod anti-affinity for node distribution
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - headlamp
        topologyKey: kubernetes.io/hostname
```

### Rationale
- **2 replicas**: Leverages 2-node cluster, provides basic HA
- **Limited resources**: Headlamp is lightweight (Node.js), suitable for homelab
- **ClusterIP**: No LoadBalancer/NodePort needed with Traefik
- **Ingress disabled**: Traefik IngressRoute offers better control and cert-manager integration
- **Official chart**: Maintained by kubernetes-sigs, cryptographically signed

---

## 2. RBAC Configuration

### Decision
- **ClusterRole**: Use built-in "view" ClusterRole (read-only access)
- **Token Type**: Long-lived ServiceAccount token (Kubernetes 1.24+ compatible)

### Configuration

**ClusterRole "view" Permissions**:
- **Verbs**: `get`, `list`, `watch` (read-only)
- **Resources Covered**:
  - Workloads: Deployments, StatefulSets, DaemonSets, ReplicaSets, Pods
  - Configuration: ConfigMaps, Services, Endpoints, Ingresses
  - Storage: PersistentVolumes, PersistentVolumeClaims
  - RBAC: Roles, RoleBindings (can view but not modify)
  - Networking: NetworkPolicies, Services
  - Custom Resources (installed CRDs)
- **Resources EXCLUDED**:
  - **Secrets**: NO access (prevents privilege escalation)
  - Write/modify/delete operations

**RBAC Manifest** (rbac.yaml):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: headlamp-admin
  namespace: headlamp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-view-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view  # Built-in read-only ClusterRole
subjects:
- kind: ServiceAccount
  name: headlamp-admin
  namespace: headlamp
---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: headlamp-admin-token
  namespace: headlamp
  annotations:
    kubernetes.io/service-account.name: headlamp-admin
```

**Token Generation** (Kubernetes 1.24+):
```bash
# Apply RBAC manifest
kubectl apply -f rbac.yaml

# Wait for token generation
kubectl wait --for=jsonpath='{.data.token}' \
  secret/headlamp-admin-token -n headlamp --timeout=60s

# Extract token (base64 decoded)
kubectl get secret headlamp-admin-token -n headlamp \
  -o jsonpath='{.data.token}' | base64 -d
```

**Token Consumption by Headlamp**:
1. **UI Input** (recommended for homelab): Paste token into Headlamp login form on first access
2. Token stored in browser localStorage (persists across sessions)
3. **Not permanently stored in cluster**: Refresh requires re-entering token

### Rationale
- **ClusterRole "view"**: Perfect balance between security and functionality for read-only dashboard
- **No Secret access**: Prevents accidental exposure of sensitive credentials
- **Long-lived token via Secret**: Since K8s 1.24+, `kubectl create token` only generates temporary tokens; Secret method required for permanent tokens
- **Cluster-wide scope**: ClusterRoleBinding allows viewing resources across all namespaces (appropriate for dashboard)
- **Alternative considered**: Custom ClusterRole with Secret read access (rejected - increases security risk)

---

## 3. Traefik IngressRoute

### Decision
- Two separate IngressRoutes: HTTP redirect + HTTPS service
- Middleware for HTTP→HTTPS redirect
- Manual cert-manager Certificate CRD (IngressRoute does NOT auto-provision)

### Configuration

**Middleware** (middleware.yaml):
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: https-redirect
  namespace: headlamp
spec:
  redirectScheme:
    scheme: https
    permanent: true
```

**HTTP IngressRoute** (ingressroute-http.yaml):
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: headlamp-http
  namespace: headlamp
spec:
  entryPoints:
    - web  # Port 80
  routes:
    - match: Host(`headlamp.chocolandiadc.com`)
      kind: Rule
      services:
        - kind: TraefikService
          name: noop@internal  # Traefik internal service (does nothing)
      middlewares:
        - name: https-redirect
```

**HTTPS IngressRoute** (ingressroute-https.yaml):
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: headlamp-https
  namespace: headlamp
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production  # Documentation only
spec:
  entryPoints:
    - websecure  # Port 443
  routes:
    - match: Host(`headlamp.chocolandiadc.com`)
      kind: Rule
      services:
        - name: headlamp
          port: 80
  tls:
    secretName: headlamp-tls  # Certificate generated by cert-manager
```

### Rationale
- **Two IngressRoutes**: Standard Traefik v3 pattern (one for HTTP redirect, one for HTTPS)
- **Middleware redirectScheme**: Cleaner than complex regex rules
- **noop@internal**: Special Traefik service that does nothing (ideal for redirects)
- **cert-manager annotation**: Preserved for documentation (IngressRoute does NOT trigger cert-manager automation)
- **secretName**: Reference to Secret where cert-manager stores certificate
- **Alternative considered**: Standard Kubernetes Ingress (rejected - IngressRoute offers more Traefik v3 features)

---

## 4. cert-manager Integration

### Decision
- **Manual Certificate CRD** (IngressRoute does NOT auto-provision certificates)
- ClusterIssuer: `letsencrypt-production` (existing from Feature 006)
- Challenge type: DNS-01 with Cloudflare (already configured)

### Configuration

**Certificate CRD** (certificate.yaml):
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: headlamp-cert
  namespace: headlamp
spec:
  secretName: headlamp-tls
  duration: 2160h    # 90 days (Let's Encrypt maximum)
  renewBefore: 720h  # Renew 30 days before expiration
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
    group: cert-manager.io
  commonName: headlamp.chocolandiadc.com
  dnsNames:
    - headlamp.chocolandiadc.com
  usages:
    - digital signature
    - key encipherment
```

**ClusterIssuer** (existing from Feature 006):
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: cbenitez@gmail.com
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - dns01:
        cloudflare:
          email: cbenitez@gmail.com
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

**Validation Commands**:
```bash
# Check certificate status
kubectl describe certificate headlamp-cert -n headlamp

# Verify CertificateRequest
kubectl get certificaterequest -n headlamp

# Inspect generated Secret
kubectl get secret headlamp-tls -n headlamp -o yaml

# Decode certificate
kubectl get secret headlamp-tls -n headlamp \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### Rationale
- **Manual Certificate CRD**: IngressRoute lacks automatic cert-manager integration (unlike standard Ingress)
- **DNS-01 challenge**: Already configured in stack, more flexible than HTTP-01
- **renewBefore 30 days**: Safe margin to resolve issues before expiration
- **Alternative considered**: Standard Ingress with auto-provisioning (rejected for consistency with Traefik v3 stack)

---

## 5. Cloudflare Access Configuration

### Decision
- Cloudflare Zero Trust Access Application with Google OAuth
- Email-based access policy
- 24-hour session duration

### Configuration (Terraform)

**cloudflare.tf**:
```hcl
# Access Application for Headlamp
resource "cloudflare_zero_trust_access_application" "headlamp" {
  account_id = var.cloudflare_account_id

  name                  = "Headlamp Kubernetes Dashboard"
  domain                = "headlamp.chocolandiadc.com"
  type                  = "self_hosted"
  session_duration      = "24h"

  auto_redirect_to_identity = true
  enable_binding_cookie     = false
  app_launcher_visible      = true

  cors_headers {
    allowed_methods = ["GET", "POST", "OPTIONS"]
    allowed_origins = ["https://headlamp.chocolandiadc.com"]
    allow_all_headers = true
    max_age           = 86400
  }
}

# Access Policy - Email-based authentication
resource "cloudflare_zero_trust_access_policy" "headlamp_allow" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.headlamp.id

  name       = "Allow Homelab Admins"
  precedence = 1
  decision   = "allow"

  include {
    email = [
      "cbenitez@gmail.com",
      # Add more authorized emails here
    ]
  }

  require {
    login_method = [var.google_oauth_idp_id]
  }

  session_duration = "24h"
}
```

**Google OAuth Setup** (Google Cloud Console):
1. Navigate to: https://console.cloud.google.com/apis/credentials
2. Create "OAuth 2.0 Client ID":
   - Application type: Web application
   - Authorized redirect URIs: `https://chocolandiadc.cloudflareaccess.com/cdn-cgi/access/callback`
   - Authorized JavaScript origins: `https://headlamp.chocolandiadc.com`
3. Copy Client ID and Client Secret for Terraform variables

### Rationale
- **Zero Trust model**: Additional security layer before reaching Headlamp
- **Google OAuth**: Familiar authentication, integrated with existing Google services
- **Email-based policy**: Simple and effective for homelab (easy to add/remove users)
- **24h session**: Balance between security and convenience
- **auto_redirect_to_identity**: Improved UX (no Cloudflare splash page)
- **Alternative considered**: Token-only without Cloudflare Access (rejected - less secure for external access)

---

## 6. Prometheus Metrics

### Decision
**Headlamp does NOT expose Prometheus metrics natively**

Headlamp is a **metrics consumer** (displays metrics from Prometheus in UI), not a **metrics exporter**.

### Configuration

**Headlamp Prometheus Integration** (values.yaml):
```yaml
config:
  # Prometheus URL for displaying metrics in Headlamp UI
  prometheusUrl: "http://prometheus-kube-prometheus-prometheus.monitoring:9090"
```

**Optional: Pod Monitoring** (if needed):
```yaml
# ServiceMonitor for basic pod health (not Prometheus metrics)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: headlamp
  namespace: headlamp
  labels:
    app.kubernetes.io/name: headlamp
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: headlamp
  endpoints:
  - port: http
    interval: 30s
    path: /healthz  # Health check endpoint, NOT Prometheus metrics
    scheme: http
```

### Rationale
- **Headlamp is consumer, not exporter**: Integrates with Prometheus to show workload metrics in UI
- **No native /metrics endpoint**: Does not expose Prometheus-format metrics
- **Alternative monitoring**: Use `/healthz` and `/readyz` for health checks
- **kube-state-metrics**: Already installed, exposes metrics for all pods including Headlamp
- **Prometheus plugin**: Headlamp includes built-in plugin that queries Prometheus for charts

---

## 7. Headlamp Configuration

### Decision
- **Authentication**: Token-based (ServiceAccount) - NOT OIDC
- **Base URL**: Dedicated domain (`headlamp.chocolandiadc.com`) - NOT subdirectory
- **Prometheus**: Internal cluster URL for metrics visualization

### Configuration (values.yaml)

```yaml
config:
  # Base URL - dedicated domain (empty = full domain)
  baseURL: ""

  # Prometheus URL for UI charts
  prometheusUrl: "http://prometheus-kube-prometheus-prometheus.monitoring:9090"

  # Disable OIDC (using token-based auth)
  oidc:
    enabled: false

# Health checks adjusted for reverse proxy
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

# Additional environment variables
env:
  # Disable telemetry (privacy)
  - name: HEADLAMP_DISABLE_ANALYTICS
    value: "true"
```

### Token vs OIDC Comparison

| Aspect | Token (ServiceAccount) | OIDC |
|--------|------------------------|------|
| Setup Complexity | Low (5 min) | High (30+ min, API server config) |
| External Dependencies | None | Identity Provider (Dex, Keycloak) |
| MFA Support | No native | Yes (via IdP) |
| User Management | Manual (K8s tokens) | Centralized (IdP) |
| Homelab Suitability | **Excellent** | Overkill (unless IdP exists) |
| Cloudflare Access | Compatible | Compatible |

### Rationale
- **Token-based for homelab**: Already have Cloudflare Access with Google OAuth (first authentication layer), K8s token as second layer (authorization/RBAC)
- **No OIDC needed**: Avoids complexity of configuring OIDC in K3s API server
- **Dedicated domain**: Avoids path rewriting complexity, better for SPAs
- **Internal Prometheus URL**: Headlamp accesses directly from cluster (faster)
- **Disable analytics**: Privacy in homelab environment
- **Alternative considered**: OIDC with Dex (rejected - unnecessary complexity for 1-2 users)

---

## 8. Namespace Decision

### Decision
**Dedicated `headlamp` namespace**

### Configuration

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: headlamp
  labels:
    name: headlamp
    app.kubernetes.io/name: headlamp
    app.kubernetes.io/component: dashboard
```

### Rationale

**Why Dedicated Namespace:**

1. **Separation of Concerns**:
   - `kube-system`: Core K3s components (Traefik, CoreDNS)
   - `monitoring`: Prometheus/Grafana
   - `cert-manager`: Certificate management
   - `headlamp`: Dashboard UI (new functional domain)

2. **RBAC Management**:
   - ServiceAccount in dedicated namespace avoids mixing permissions
   - Easier audit of Headlamp access

3. **Network Policies**:
   - Can apply NetworkPolicies specific to Headlamp
   - Example: only allow traffic from Traefik IngressController

4. **Resource Limits**:
   - Isolated ResourceQuotas and LimitRanges
   - Does not compete with `kube-system` resources

5. **Troubleshooting**:
   - `kubectl logs -n headlamp` cleaner
   - Does not mix logs with critical system components

6. **Upgrade/Rollback**:
   - Helm upgrade/rollback does not affect other components
   - Can delete entire namespace for clean reinstallation

**Alternative Considered**: `kube-system` (suggested by some tutorials)
- **Rejected**: Mixes application components with core infrastructure
- Complicates troubleshooting and limits granular security policies

**Optional NetworkPolicy**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: headlamp-network-policy
  namespace: headlamp
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: headlamp
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Only allow traffic from Traefik
  - from:
    - namespaceSelector:
        matchLabels:
          name: kube-system
      podSelector:
        matchLabels:
          app.kubernetes.io/name: traefik
    ports:
    - protocol: TCP
      port: 80
  egress:
  # Allow Kubernetes API access
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
  # Allow Prometheus access
  - to:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
  # DNS resolution
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

---

## Summary of Key Decisions

| Aspect | Decision | Alternative Rejected | Reason |
|--------|----------|----------------------|--------|
| **Namespace** | Dedicated `headlamp` | `kube-system` | Better separation, RBAC, troubleshooting |
| **Authentication** | Token ServiceAccount | OIDC | Lower complexity, sufficient with Cloudflare Access |
| **Ingress** | Traefik IngressRoute | Standard Ingress | Better Traefik v3 integration, more features |
| **Certificates** | Manual Certificate CRD | Auto with Ingress annotation | IngressRoute does not support auto-provisioning |
| **Replicas** | 2 (HA) | 1 | Leverages 2 nodes, basic HA |
| **Base URL** | Dedicated domain | Subdirectory | Avoids path rewriting complexity in SPA |
| **RBAC** | ClusterRole "view" | Admin / custom role | Security-functionality balance |
| **Monitoring** | Basic health checks | ServiceMonitor | Headlamp does not expose Prometheus metrics |

---

## Post-Deployment Validation Commands

```bash
# 1. Verify Headlamp deployment
kubectl get pods -n headlamp
kubectl get svc -n headlamp
kubectl describe deployment headlamp -n headlamp

# 2. Verify certificate
kubectl get certificate headlamp-cert -n headlamp
kubectl describe certificate headlamp-cert -n headlamp

# 3. Verify IngressRoute
kubectl get ingressroute -n headlamp
kubectl describe ingressroute headlamp-https -n headlamp

# 4. Verify RBAC
kubectl get sa headlamp-admin -n headlamp
kubectl get clusterrolebinding headlamp-view-binding
kubectl describe clusterrole view

# 5. Get token for login
kubectl get secret headlamp-admin-token -n headlamp \
  -o jsonpath='{.data.token}' | base64 -d

# 6. Test connectivity
curl -k https://headlamp.chocolandiadc.com/
```

---

## Next Steps

All research complete. Ready for Phase 1 (Design):
1. Generate data-model.md (Kubernetes resource relationships)
2. Generate quickstart.md (deployment procedure)
3. Update agent context (CLAUDE.md)
