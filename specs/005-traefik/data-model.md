# Data Model: Traefik Ingress Controller

**Feature**: 005-traefik | **Phase**: 1 (Design) | **Date**: 2025-11-10

## Overview

Traefik ingress controller's data model consists of Kubernetes native resources (Deployment, Service) and Traefik-specific Custom Resource Definitions (IngressRoute, Middleware, TLSOption). These entities work together to route external HTTP/HTTPS traffic to backend services.

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    External Network                              │
│                    (Eero Router, Clients)                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
            ┌───────────────────────────────┐
            │   LoadBalancer IP (MetalLB)   │
            │   192.168.4.240:80,443        │
            └───────────────┬───────────────┘
                            │
                            ▼
            ┌───────────────────────────────┐
            │   Traefik Service             │
            │   (LoadBalancer type)         │
            │   - Ports: 80, 443, 9100      │
            └───────────────┬───────────────┘
                            │
                            ▼
            ┌───────────────────────────────┐
            │   Traefik Deployment          │
            │   - Replicas: 2 (HA)          │
            │   - PodDisruptionBudget       │
            └───────────────┬───────────────┘
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
        ┌──────────────┐        ┌──────────────┐
        │ Traefik Pod  │        │ Traefik Pod  │
        │ (Replica 1)  │        │ (Replica 2)  │
        │ - Ports: 80, │        │ - Ports: 80, │
        │   443, 9100  │        │   443, 9100  │
        └──────┬───────┘        └──────┬───────┘
               │                       │
               └───────────┬───────────┘
                           │ Watches Kubernetes API
                           ▼
        ┌──────────────────────────────────────┐
        │      IngressRoute CRDs               │
        │  (Routing rules, hostname → service) │
        │  - Host matching                     │
        │  - Path matching                     │
        │  - Backend service references        │
        └──────────┬───────────────────────────┘
                   │
                   ├─────────────┬──────────────┬─────────────┐
                   ▼             ▼              ▼             ▼
            ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
            │ Backend  │  │ Backend  │  │ Backend  │  │ Traefik  │
            │ Service  │  │ Service  │  │ Service  │  │ Dashboard│
            │ (whoami) │  │ (pihole) │  │ (grafana)│  │ Service  │
            └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘
                 │             │              │             │
                 ▼             ▼              ▼             ▼
            ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
            │  Pods  │    │  Pods  │    │  Pods  │    │  Pod   │
            └────────┘    └────────┘    └────────┘    └────────┘

        ┌──────────────────────────────────────┐
        │      Middleware CRDs                 │
        │  (Request/Response transformations)  │
        │  - HTTP → HTTPS redirect             │
        │  - Headers manipulation              │
        │  - Basic authentication              │
        └──────────────────────────────────────┘
                   │
                   │ Referenced by IngressRoute
                   ▼

        ┌──────────────────────────────────────┐
        │      TLSOption CRDs                  │
        │  (TLS configuration)                 │
        │  - Cipher suites                     │
        │  - TLS versions                      │
        │  - Client authentication             │
        └──────────────────────────────────────┘
                   │
                   │ Referenced by IngressRoute
                   ▼

        ┌──────────────────────────────────────┐
        │      Certificate Secrets             │
        │  (TLS certificates + private keys)   │
        │  - Type: kubernetes.io/tls           │
        │  - Self-signed (initial)             │
        │  - Let's Encrypt (future)            │
        └──────────────────────────────────────┘
                   │
                   │ Referenced by IngressRoute
                   ▼

        ┌──────────────────────────────────────┐
        │      ServiceMonitor CRD              │
        │  (Prometheus scraping config)        │
        │  - Future: when Prometheus deployed  │
        │  - Scrapes :9100/metrics             │
        └──────────────────────────────────────┘
```

## Core Entities

### 1. Traefik Deployment

**Purpose**: Kubernetes Deployment resource that manages Traefik ingress controller pods.

**Attributes**:
- `replicas`: Number of Traefik pods (2 for HA)
- `image`: Container image (traefik:v3.x)
- `resources`: CPU/memory requests and limits
- `livenessProbe`: Health check for pod liveness (GET /ping)
- `readinessProbe`: Health check for pod readiness (GET /ping)
- `args`: Traefik CLI arguments (providers, entrypoints, API, metrics)
- `volumeMounts`: Configuration files (if any)
- `env`: Environment variables
- `securityContext`: Security settings (non-root user)

**Relationships**:
- Managed by: Helm chart (via OpenTofu helm_release)
- Selects: Traefik pods (via label selector)
- Referenced by: Traefik Service (via selector)
- Watches: IngressRoute, Middleware, TLSOption CRDs (via Kubernetes API)

**Lifecycle**:
- Created by: `tofu apply` (Helm chart deployment)
- Updated by: Helm chart upgrade (version bump, values change)
- Deleted by: `tofu destroy` or manual deletion
- Rolled out: Rolling update strategy (maxSurge: 1, maxUnavailable: 0)

**Example**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: traefik
  namespace: traefik
  labels:
    app.kubernetes.io/name: traefik
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
  template:
    metadata:
      labels:
        app.kubernetes.io/name: traefik
    spec:
      containers:
      - name: traefik
        image: traefik:v3.2.0
        args:
          - --entrypoints.web.address=:80
          - --entrypoints.websecure.address=:443
          - --entrypoints.metrics.address=:9100
          - --providers.kubernetescrd
          - --api.dashboard=true
          - --metrics.prometheus=true
        ports:
          - name: web
            containerPort: 80
          - name: websecure
            containerPort: 443
          - name: metrics
            containerPort: 9100
        livenessProbe:
          httpGet:
            path: /ping
            port: 9000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ping
            port: 9000
          initialDelaySeconds: 10
          periodSeconds: 10
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
```

---

### 2. Traefik Service

**Purpose**: LoadBalancer Service exposing Traefik pods to external network via MetalLB.

**Attributes**:
- `type`: LoadBalancer (triggers MetalLB IP assignment)
- `selector`: Label selector for Traefik pods
- `ports`: Exposed ports (80/web, 443/websecure, 9100/metrics)
- `annotations`: MetalLB configuration (loadBalancerIPs)
- `externalTrafficPolicy`: Cluster or Local (Local preserves source IP)
- `sessionAffinity`: ClientIP or None (for sticky sessions)

**Relationships**:
- Selects: Traefik pods (label selector)
- Exposed by: MetalLB (LoadBalancer IP assignment)
- Accessed by: External clients (HTTP/HTTPS requests)

**Lifecycle**:
- Created by: Helm chart deployment
- Updated by: Service spec changes (ports, annotations)
- Deleted by: Helm chart removal
- IP assignment: MetalLB controller watches Service, allocates IP from pool

**Example**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: traefik
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.4.240
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: traefik
  ports:
    - name: web
      port: 80
      targetPort: web
      protocol: TCP
    - name: websecure
      port: 443
      targetPort: websecure
      protocol: TCP
    - name: metrics
      port: 9100
      targetPort: metrics
      protocol: TCP
  externalTrafficPolicy: Local  # Preserve source IP
```

---

### 3. IngressRoute (Traefik CRD)

**Purpose**: Defines HTTP/HTTPS routing rules from hostname/path to backend Kubernetes Service.

**Attributes**:
- `entryPoints`: Which Traefik entrypoints to listen on (web=80, websecure=443)
- `routes`: Array of routing rules
  - `match`: Routing rule expression (e.g., `Host(\`example.com\`)`)
  - `kind`: Rule type (always "Rule")
  - `services`: Backend services to route to
    - `name`: Kubernetes Service name
    - `port`: Service port
    - `weight`: Traffic split percentage (for canary deployments)
  - `middlewares`: Middleware chain to apply (optional)
- `tls`: TLS configuration (optional)
  - `secretName`: Kubernetes Secret with TLS cert
  - `options`: TLSOption CRD reference

**Relationships**:
- Watched by: Traefik pods (Kubernetes API watch)
- References: Backend Kubernetes Services (routes.services.name)
- References: Middleware CRDs (routes.middlewares)
- References: TLSOption CRDs (tls.options)
- References: Certificate Secrets (tls.secretName)

**Lifecycle**:
- Created by: kubectl apply or OpenTofu kubernetes_manifest
- Updated by: kubectl apply (Traefik auto-updates routing config)
- Deleted by: kubectl delete (Traefik removes routing rules)
- Validation: CRD schema validation on creation

**Example (HTTP)**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: whoami
  namespace: default
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`whoami.local`)
      kind: Rule
      services:
        - name: whoami
          port: 80
```

**Example (HTTPS with TLS)**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: whoami-tls
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`whoami.local`)
      kind: Rule
      services:
        - name: whoami
          port: 80
  tls:
    secretName: whoami-tls-cert
```

---

### 4. Middleware (Traefik CRD)

**Purpose**: Request/response transformation applied to IngressRoute (redirect, headers, auth, etc.)

**Attributes**:
- `redirectScheme`: HTTP → HTTPS redirect
  - `scheme`: Target scheme (https)
  - `permanent`: 301 (permanent) or 302 (temporary)
- `headers`: Add/remove HTTP headers
  - `customRequestHeaders`: Add headers to request
  - `customResponseHeaders`: Add headers to response
  - `sslRedirect`: Force HTTPS
  - `stsSeconds`: HSTS max-age
- `basicAuth`: Basic authentication
  - `secret`: Kubernetes Secret with htpasswd credentials
- `stripPrefix`: Remove path prefix before forwarding
- `addPrefix`: Add path prefix
- `rateLimit`: Request rate limiting

**Relationships**:
- Referenced by: IngressRoute (routes.middlewares)
- References: Secrets (basicAuth.secret)
- Watched by: Traefik pods (Kubernetes API watch)

**Lifecycle**:
- Created by: kubectl apply or OpenTofu kubernetes_manifest
- Updated by: kubectl apply (Traefik auto-updates)
- Deleted by: kubectl delete (removed from routing chain)
- Chained: Multiple middlewares can be applied in order

**Example (HTTPS Redirect)**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: https-redirect
  namespace: default
spec:
  redirectScheme:
    scheme: https
    permanent: true
```

**Example (Security Headers)**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: default
spec:
  headers:
    customResponseHeaders:
      X-Frame-Options: DENY
      X-Content-Type-Options: nosniff
      X-XSS-Protection: "1; mode=block"
      Strict-Transport-Security: "max-age=31536000; includeSubDomains"
```

**Example (Basic Auth)**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-auth
  namespace: traefik
spec:
  basicAuth:
    secret: traefik-dashboard-auth  # htpasswd credentials
```

---

### 5. TLSOption (Traefik CRD)

**Purpose**: TLS configuration (cipher suites, protocols, client auth) applied to IngressRoute.

**Attributes**:
- `minVersion`: Minimum TLS version (VersionTLS12, VersionTLS13)
- `maxVersion`: Maximum TLS version
- `cipherSuites`: Allowed cipher suites (array)
- `curvePreferences`: Elliptic curves for ECDHE
- `sniStrict`: Strict SNI validation (reject mismatched SNI)
- `clientAuth`: Client certificate authentication
  - `secretNames`: Kubernetes Secrets with CA certs
  - `clientAuthType`: RequestClientCert, RequireAnyClientCert, VerifyClientCertIfGiven

**Relationships**:
- Referenced by: IngressRoute (tls.options)
- Watched by: Traefik pods (Kubernetes API watch)

**Lifecycle**:
- Created by: kubectl apply or OpenTofu kubernetes_manifest
- Updated by: kubectl apply (Traefik auto-updates TLS config)
- Deleted by: kubectl delete (IngressRoute falls back to default TLS)

**Example**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: TLSOption
metadata:
  name: modern-tls
  namespace: default
spec:
  minVersion: VersionTLS12
  cipherSuites:
    - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
    - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
  curvePreferences:
    - CurveP521
    - CurveP384
  sniStrict: true
```

---

### 6. Certificate Secret

**Purpose**: Kubernetes Secret storing TLS certificate and private key for HTTPS termination.

**Attributes**:
- `type`: kubernetes.io/tls (standard TLS secret type)
- `data.tls.crt`: Base64-encoded certificate (PEM format)
- `data.tls.key`: Base64-encoded private key (PEM format)
- `metadata.annotations`: cert-manager annotations (future)

**Relationships**:
- Referenced by: IngressRoute (tls.secretName)
- Created by: Manual (openssl), cert-manager (future)
- Watched by: Traefik pods (automatic certificate discovery)

**Lifecycle**:
- Created by: kubectl create secret tls or cert-manager
- Updated by: cert-manager (automatic renewal)
- Deleted by: kubectl delete secret
- Mounted: Traefik reads from Kubernetes API (not volume mount)

**Example (Manual Creation)**:
```bash
# Generate self-signed cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=whoami.local"

# Create Secret
kubectl create secret tls whoami-tls-cert \
  --cert=tls.crt --key=tls.key -n default
```

**Example (YAML)**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: whoami-tls-cert
  namespace: default
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
  tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t...
```

---

### 7. Dashboard IngressRoute

**Purpose**: IngressRoute exposing Traefik dashboard for operational visibility.

**Attributes**:
- `entryPoints`: web or websecure (dashboard port is internal 9000)
- `routes.match`: Host-based routing (e.g., `Host(\`traefik.local\`)`)
- `routes.services`: Special service `api@internal` (Traefik internal API)
- `routes.middlewares`: Basic auth middleware (dashboard-auth)

**Relationships**:
- References: api@internal service (Traefik built-in)
- References: Middleware for authentication
- Watched by: Traefik pods (like any IngressRoute)

**Lifecycle**:
- Created by: kubectl apply (after Traefik deployment)
- Updated by: kubectl apply (change hostname, add auth)
- Deleted by: kubectl delete (dashboard becomes inaccessible via ingress)
- Fallback: Dashboard still accessible via port-forward to pod

**Example**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: dashboard
  namespace: traefik
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`traefik.local`)
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
      middlewares:
        - name: dashboard-auth  # Require basic auth
```

---

### 8. ServiceMonitor (Prometheus Operator CRD)

**Purpose**: Prometheus Operator resource defining how to scrape Traefik metrics.

**Attributes** (Future):
- `selector`: Label selector for Traefik Service
- `endpoints`: Scraping configuration
  - `port`: Metrics port name (metrics)
  - `interval`: Scrape interval (30s)
  - `path`: Metrics endpoint (/metrics)
- `namespaceSelector`: Target namespace (traefik)

**Relationships**:
- Selects: Traefik Service (label selector)
- Managed by: Prometheus Operator (watches ServiceMonitor CRDs)
- Scraped by: Prometheus pods

**Lifecycle** (Future):
- Created by: When Prometheus Operator deployed
- Updated by: kubectl apply (change scrape interval, add relabeling)
- Deleted by: kubectl delete (Prometheus stops scraping Traefik)

**Example** (Future):
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: traefik
  namespace: traefik
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

---

### 9. PodDisruptionBudget

**Purpose**: Ensures minimum number of Traefik replicas remain available during disruptions (node drain, upgrades).

**Attributes**:
- `minAvailable`: Minimum replicas that must remain available (1)
- `maxUnavailable`: Maximum replicas that can be unavailable
- `selector`: Label selector for Traefik pods

**Relationships**:
- Selects: Traefik pods (label selector)
- Enforced by: Kubernetes API server (blocks disruptive operations)

**Lifecycle**:
- Created by: Helm chart (via values.yaml setting)
- Updated by: Helm upgrade
- Deleted by: Helm uninstall
- Validation: Kubernetes rejects pod eviction if violates budget

**Example**:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: traefik
  namespace: traefik
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
```

---

## Data Flow

### 1. HTTP Request Flow

```
External Client
  → DNS resolution (whoami.local → 192.168.4.240)
  → HTTP GET http://192.168.4.240/ with Host: whoami.local
  → Eero router (ARP, forwards to MetalLB IP)
  → MetalLB (L4 load balance to Traefik pod)
  → Traefik pod receives request
  → IngressRoute matching (Host(`whoami.local`))
  → Middleware chain execution (if any)
  → Backend Service lookup (whoami:80)
  → Kubernetes Service load balance to pod IP
  → whoami pod receives request
  → Response flows back through chain
  → Client receives response
```

### 2. IngressRoute Configuration Flow

```
User creates IngressRoute YAML
  → kubectl apply -f ingressroute.yaml
  → Kubernetes API server validates CRD schema
  → Kubernetes stores IngressRoute in etcd
  → Traefik pod watches Kubernetes API (informer)
  → Traefik detects new IngressRoute
  → Traefik parses routing rules
  → Traefik updates internal routing table (in-memory)
  → Traefik ready to route traffic for new hostname
  → No restart/reload required (dynamic config)
```

### 3. TLS Certificate Flow (Future)

```
cert-manager watches IngressRoute with TLS annotation
  → cert-manager requests certificate from Let's Encrypt
  → ACME HTTP-01 challenge (or DNS-01)
  → Let's Encrypt validates domain ownership
  → cert-manager receives certificate
  → cert-manager creates Kubernetes Secret (type: tls)
  → Traefik watches Kubernetes API
  → Traefik detects new Secret
  → Traefik loads certificate into memory
  → Traefik ready to terminate TLS for hostname
  → HTTPS requests use new certificate
  → cert-manager renews before expiration (automatic)
```

### 4. Metrics Collection Flow (Future)

```
Prometheus ServiceMonitor created
  → Prometheus Operator detects ServiceMonitor
  → Prometheus Operator updates Prometheus config
  → Prometheus scrapes Traefik :9100/metrics
  → Traefik returns Prometheus-format metrics
  → Prometheus stores time-series data
  → Grafana queries Prometheus for visualization
  → Dashboard displays ingress metrics (requests, latency, errors)
```

---

## Validation Queries

### Check Traefik Deployment Status
```bash
kubectl get deployment -n traefik traefik -o wide
# Expected: 2/2 replicas ready, recent creation timestamp
```

### Check IngressRoute Exists
```bash
kubectl get ingressroute -A
# Expected: List of IngressRoute resources with namespaces
```

### Check Backend Service Endpoints
```bash
kubectl get endpoints whoami -n default
# Expected: IP addresses of whoami pods (backend targets)
```

### Check TLS Secret
```bash
kubectl get secret whoami-tls-cert -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
# Expected: Certificate details (CN, expiration, issuer)
```

### Check Metrics Endpoint
```bash
kubectl port-forward -n traefik svc/traefik 9100:9100 &
curl http://localhost:9100/metrics | grep traefik_entrypoint
# Expected: Prometheus metrics output
```

---

## Constraints and Invariants

### Invariants (Must Always Be True)

1. **At least 1 Traefik replica must be Running**
   - Enforced by: PodDisruptionBudget (minAvailable: 1)
   - Validated by: Kubernetes API server (blocks disruptive operations)

2. **LoadBalancer Service must have external IP**
   - Enforced by: MetalLB controller
   - Validated by: `kubectl get svc traefik` shows EXTERNAL-IP (not <pending>)

3. **IngressRoute must reference existing Service**
   - Enforced by: Traefik runtime (logs warning if service not found)
   - Validated by: Check Traefik logs for "service not found" errors

4. **TLS Secret must contain tls.crt and tls.key**
   - Enforced by: Kubernetes Secret type validation (kubernetes.io/tls)
   - Validated by: kubectl describe secret (shows keys present)

5. **Middleware must exist before IngressRoute references it**
   - Enforced by: Traefik runtime (ignores unknown middlewares)
   - Validated by: Check Traefik logs for "middleware not found" warnings

### Constraints

1. **Traefik replicas ≥ 2** (HA requirement)
2. **LoadBalancer IP must be in MetalLB pool range**
3. **IngressRoute hostname must be DNS-resolvable** (or /etc/hosts entry)
4. **Backend Service port must match IngressRoute services[].port**
5. **TLS certificate CN must match IngressRoute hostname** (for HTTPS)
6. **Prometheus metrics port (9100) must not conflict with other services**

---

## Evolution and Future Extensions

### Phase 1 (MVP): Current Design
- HTTP routing via IngressRoute
- Self-signed TLS certificates (manual)
- Dashboard access via IngressRoute
- Metrics endpoint exposed (not consumed)

### Phase 2 (cert-manager Integration)
- Add cert-manager deployment
- IngressRoute annotations for automatic certificate issuance
- Let's Encrypt production certificates
- Automatic certificate renewal

### Phase 3 (Monitoring Integration)
- Deploy Prometheus Operator
- Create ServiceMonitor for Traefik
- Grafana dashboards for ingress metrics
- Alerting rules for ingress failures

### Phase 4 (Advanced Middleware)
- Rate limiting middleware
- OAuth2 authentication (oauth2-proxy)
- Request/response body manipulation
- Circuit breaking and retry logic

### Phase 5 (Multi-Cluster)
- Traefik mesh for service mesh capabilities
- Cross-cluster routing (if multi-cluster deployed)
- Distributed tracing integration (Jaeger/Zipkin)
