# Research: Traefik Ingress Controller

**Feature**: 005-traefik | **Phase**: 0 (Research) | **Date**: 2025-11-10

## Decision Summary

**Primary Decision**: Deploy Traefik v3.x as the ingress controller using the official Helm chart (traefik/traefik) managed via OpenTofu helm_release resource.

**Deployment Method**: Helm chart with custom values.yaml for configuration (HA, metrics, dashboard, LoadBalancer)

**Integration Strategy**: MetalLB for LoadBalancer service, IngressRoute CRDs for routing, prepare for cert-manager TLS integration

## Architecture Decision Record: Traefik vs NGINX Ingress

### Context

K3s cluster requires an ingress controller to route external HTTP/HTTPS traffic to internal services. Two primary options for cloud-native Kubernetes ingress: Traefik and NGINX Ingress Controller.

### Decision

**Selected**: Traefik v3.x

**Rejected**: NGINX Ingress Controller

### Rationale

#### Why Traefik?

1. **Modern CRD-based configuration**
   - IngressRoute CRD provides native Traefik routing syntax (cleaner than Ingress + annotations)
   - Middleware CRD for transformations (redirect, headers, auth)
   - TLSOption CRD for TLS configuration
   - Dynamic configuration via Kubernetes API (no file reloads)

2. **Built-in dashboard**
   - Real-time visualization of routes, services, middleware
   - Essential learning tool for understanding ingress behavior
   - No additional tooling required (NGINX Ingress has no equivalent)

3. **Automatic service discovery**
   - Watches Kubernetes API for IngressRoute changes
   - Instant configuration updates (no reload)
   - Provider model simplifies multi-environment config

4. **Native Prometheus metrics**
   - /metrics endpoint built-in
   - Request counters, latency histograms, backend health
   - Prepared for future Prometheus/Grafana integration (Feature observability)

5. **Better learning value**
   - CRDs teach Kubernetes extension patterns
   - Dashboard visualizes routing concepts
   - Middleware composition teaches HTTP transformation patterns
   - Modern cloud-native ingress approach (vs traditional proxy config)

6. **Certificate automation preparation**
   - Native integration with cert-manager (future Feature 006)
   - Automatic certificate discovery from Kubernetes Secrets
   - TLS passthrough and termination modes

7. **Lightweight and fast**
   - Single binary (Go-based, like K3s)
   - Low memory footprint (~100MB per replica)
   - Sub-millisecond routing overhead

#### Why NOT NGINX Ingress?

1. **Annotation-heavy configuration**
   - Configuration via Ingress resource annotations is verbose and error-prone
   - nginx.ingress.kubernetes.io/* annotations less intuitive than CRDs
   - Harder to validate configuration (no CRD schema validation)

2. **No built-in dashboard**
   - Requires external tools (Prometheus + Grafana) just to see routing rules
   - Less visibility during learning/debugging

3. **Reload overhead**
   - Configuration changes trigger nginx reload (brief traffic interruption)
   - Traefik updates dynamically without reload

4. **Less modern**
   - Based on traditional NGINX proxy (file-based config heritage)
   - Ingress resource is older Kubernetes API (less flexible)

5. **Redundant with K3s default**
   - K3s ships with Traefik v1 by default (though we'll deploy v3 separately)
   - NGINX would introduce different patterns vs K3s conventions

### Alignment with Constitution

- **I. OpenTofu First**: Helm chart via helm_release resource (IaC) ✅
- **III. Container-First**: Traefik runs as containerized deployment ✅
- **IV. Observability**: Built-in metrics endpoint for Prometheus ✅
- **VII. Test-Driven Learning**: Dashboard visualizes configuration, easier to validate routing ✅
- **VIII. Documentation-First**: CRDs provide self-documenting API schemas ✅

### Trade-offs Accepted

1. **Learning curve**: IngressRoute CRD is Traefik-specific (not portable to NGINX)
   - **Mitigation**: Learning modern CRD patterns is valuable for cloud-native career
   - Standard Ingress resource still supported if portability needed later

2. **Ecosystem maturity**: NGINX Ingress has larger user base
   - **Mitigation**: Traefik is well-maintained, active community, production-proven
   - Homelab scale doesn't require battle-tested at scale

3. **Advanced features**: NGINX has more plugins/modules for niche use cases
   - **Mitigation**: Traefik's core feature set covers 99% of homelab needs
   - Middleware system extensible for custom transformations

## Deployment Strategy

### Helm Chart via OpenTofu

**Method**: Use OpenTofu helm_release resource to deploy Traefik chart

**Advantages**:
- Infrastructure as Code (Constitution I)
- Version pinning (chart version explicit in terraform.tfvars)
- Reproducible deployments (idempotent apply)
- Git-tracked configuration changes (values.yaml in Git)

**Alternative Rejected**: Manual `helm install` command
- **Why rejected**: Violates IaC principle, no version control, no plan preview

### Key Helm Values Configuration

```yaml
# values.yaml (managed in Git at terraform/modules/traefik/values.yaml)

# Deployment configuration
deployment:
  replicas: 2                          # HA: 2 replicas for fault tolerance
  podDisruptionBudget:
    enabled: true
    minAvailable: 1                    # At least 1 replica always running

# Service configuration
service:
  type: LoadBalancer                   # MetalLB assigns external IP
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.4.201  # Static IP from MetalLB pool

# Ports configuration
ports:
  web:
    port: 80                           # HTTP entrypoint
    expose: true
  websecure:
    port: 443                          # HTTPS entrypoint (future TLS)
    expose: true
  metrics:
    port: 9100                         # Prometheus metrics
    expose: false                      # Internal only

# Prometheus metrics
metrics:
  prometheus:
    enabled: true
    entryPoint: metrics

# Dashboard
dashboard:
  enabled: true
  ingressRoute:
    enabled: false                     # We'll create custom IngressRoute for dashboard

# Resource limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

# Health checks
readinessProbe:
  enabled: true
  path: /ping
  port: 9000

livenessProbe:
  enabled: true
  path: /ping
  port: 9000

# Logs
logs:
  general:
    level: INFO
  access:
    enabled: true
```

### HA Configuration Details

**High Availability Requirements**:
1. **Multiple replicas**: 2+ Traefik pods running simultaneously
2. **Pod anti-affinity**: Spread replicas across different nodes
3. **PodDisruptionBudget**: Ensures at least 1 replica during node maintenance
4. **LoadBalancer service**: MetalLB distributes traffic across healthy replicas
5. **Graceful shutdown**: Connection draining on pod termination

**Failure Scenarios**:
- **Single pod failure**: LoadBalancer routes to remaining replica, zero downtime
- **Node failure**: Kubernetes reschedules pods to healthy nodes, brief interruption (~30s)
- **Rolling update**: PodDisruptionBudget ensures gradual rollout, continuous availability

## Integration Points

### 1. MetalLB LoadBalancer Integration

**How it works**:
- Traefik Service type=LoadBalancer triggers MetalLB IP assignment
- MetalLB allocates IP from pool (e.g., 192.168.4.201)
- MetalLB announces IP via ARP (L2 mode) to network
- External clients send HTTP/HTTPS traffic to LoadBalancer IP
- MetalLB forwards to Traefik pods (round-robin L4 load balancing)

**Configuration**:
```yaml
service:
  type: LoadBalancer
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.4.201  # Request specific IP
```

**Validation**:
```bash
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# Should return: 192.168.4.201
```

### 2. IngressRoute CRD Routing

**How it works**:
- IngressRoute defines routing rules (hostname, path → backend service)
- Traefik watches IngressRoute resources via Kubernetes API
- Dynamic configuration update (no restart/reload)
- HTTP requests matched against rules, forwarded to backend

**Example IngressRoute** (test whoami service):
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: whoami
  namespace: default
spec:
  entryPoints:
    - web                              # HTTP (port 80)
  routes:
    - match: Host(`whoami.local`)      # Hostname matching
      kind: Rule
      services:
        - name: whoami                 # Backend service name
          port: 80
```

**Validation**:
```bash
curl -H "Host: whoami.local" http://192.168.4.201
# Should return: whoami service response
```

### 3. Middleware for HTTP Transformations

**Use Cases**:
- HTTP → HTTPS redirect
- Add security headers
- Basic authentication (dashboard access)
- Path stripping/rewriting

**Example Middleware** (HTTPS redirect):
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

**Attaching to IngressRoute**:
```yaml
spec:
  routes:
    - match: Host(`example.local`)
      kind: Rule
      middlewares:
        - name: https-redirect          # Apply middleware
      services:
        - name: example
          port: 80
```

### 4. Dashboard Access

**Purpose**: Operational visibility (view routes, services, middleware, health)

**Deployment**:
- Enabled via Helm values (dashboard.enabled: true)
- Exposed via custom IngressRoute (not Helm default)
- Accessible at http://192.168.4.201:9000/dashboard/ (internal port)
- Future: IngressRoute with hostname (e.g., traefik.local) + basic auth

**Security**:
- Dashboard port (9000) not exposed via LoadBalancer (internal only)
- IngressRoute with Middleware for basic auth (future)
- No public internet access (homelab internal only)

### 5. Prometheus Metrics Preparation

**Metrics Endpoint**: http://traefik-pod:9100/metrics

**Available Metrics**:
- `traefik_entrypoint_requests_total` (request counter by entrypoint)
- `traefik_entrypoint_request_duration_seconds` (latency histogram)
- `traefik_service_requests_total` (requests per backend service)
- `traefik_service_request_duration_seconds` (per-service latency)
- `traefik_backend_connections_total` (active connections)

**Future Integration** (when Prometheus deployed):
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
```

### 6. TLS Strategy (Preparation for cert-manager)

**Phase 1 (MVP)**: Self-signed certificates
- Manual cert generation via openssl
- Store in Kubernetes Secret (type: kubernetes.io/tls)
- Reference in IngressRoute tls.secretName

**Phase 2 (Feature 006)**: cert-manager integration
- cert-manager watches IngressRoute with tls annotation
- Automatically requests Let's Encrypt certificate
- Stores in Kubernetes Secret
- Traefik automatically discovers and uses cert

**Example TLS IngressRoute** (self-signed):
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: whoami-tls
  namespace: default
spec:
  entryPoints:
    - websecure                        # HTTPS (port 443)
  routes:
    - match: Host(`whoami.local`)
      kind: Rule
      services:
        - name: whoami
          port: 80
  tls:
    secretName: whoami-tls-cert        # Kubernetes Secret with cert
```

## Network Traffic Flow

```
┌─────────────────┐
│ External Client │
│ (Browser/curl)  │
└────────┬────────┘
         │ HTTP request to 192.168.4.201:80
         │ Host: whoami.local
         ▼
┌─────────────────────────────────────┐
│         Eero Network Router         │
│   (ARP resolution, forwards to      │
│    MetalLB-announced IP)            │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│           MetalLB (L2 mode)         │
│  - Listens for LoadBalancer IP      │
│  - Round-robin to Traefik pods      │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│      Traefik Pod (replica 1 or 2)   │
│  - Receives HTTP request            │
│  - Matches IngressRoute rules       │
│    (Host: whoami.local)             │
│  - Selects backend service          │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│    Kubernetes Service (whoami)      │
│  - ClusterIP load balancing         │
│  - Forwards to Pod IP               │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│      whoami Pod                     │
│  - Processes HTTP request           │
│  - Returns response                 │
└─────────────────────────────────────┘
```

**Key Points**:
1. **L4 Load Balancing**: MetalLB (distributes TCP connections to Traefik pods)
2. **L7 Routing**: Traefik (HTTP hostname/path matching to backend services)
3. **Service Discovery**: Traefik watches Kubernetes API for IngressRoute changes
4. **HA**: Multiple Traefik replicas, MetalLB distributes traffic
5. **Zero SPOF**: LoadBalancer IP survives Traefik pod failure (MetalLB redirects to healthy replica)

## Testing Strategy

### 1. Deployment Validation
```bash
# Check Traefik pods running
kubectl get pods -n traefik -l app.kubernetes.io/name=traefik

# Expected: 2 Running pods (HA replicas)
# NAME                       READY   STATUS    RESTARTS   AGE
# traefik-5d6f8b9c4d-abc12   1/1     Running   0          2m
# traefik-5d6f8b9c4d-def34   1/1     Running   0          2m
```

### 2. LoadBalancer IP Validation
```bash
# Check LoadBalancer service has external IP
kubectl get svc -n traefik traefik

# Expected: EXTERNAL-IP = 192.168.4.201 (from MetalLB)
# NAME      TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
# traefik   LoadBalancer   10.43.100.123   192.168.4.201    80:30080/TCP,443:30443/TCP
```

### 3. HTTP Routing Validation
```bash
# Deploy test whoami service
kubectl apply -f terraform/manifests/traefik/whoami-test.yaml

# Create IngressRoute
kubectl apply -f terraform/manifests/traefik/whoami-ingressroute.yaml

# Test HTTP request
curl -H "Host: whoami.local" http://192.168.4.201

# Expected: whoami response with hostname, IP, headers
```

### 4. HA Validation
```bash
# Delete one Traefik pod
kubectl delete pod -n traefik -l app.kubernetes.io/name=traefik --field-selector metadata.name=traefik-5d6f8b9c4d-abc12

# Test routing still works (traffic goes to replica 2)
curl -H "Host: whoami.local" http://192.168.4.201

# Expected: No downtime, successful response
```

### 5. Dashboard Validation
```bash
# Access dashboard (port-forward for testing)
kubectl port-forward -n traefik svc/traefik 9000:9000

# Open browser: http://localhost:9000/dashboard/
# Expected: Traefik dashboard UI loads, shows IngressRoutes
```

### 6. Metrics Validation
```bash
# Check metrics endpoint
kubectl port-forward -n traefik svc/traefik 9100:9100
curl http://localhost:9100/metrics

# Expected: Prometheus-format metrics output
# traefik_entrypoint_requests_total{...} 42
# traefik_entrypoint_request_duration_seconds_bucket{...} 0.012
```

## Risk Mitigation

### Risk 1: LoadBalancer IP Not Assigned (MetalLB Issue)
**Symptom**: Service stuck in `<pending>` state
**Mitigation**:
- Verify MetalLB is running: `kubectl get pods -n metallb-system`
- Check MetalLB IP pool: `kubectl get ipaddresspools -n metallb-system`
- Ensure requested IP is in pool range
- Check MetalLB logs: `kubectl logs -n metallb-system -l app=metallb`

### Risk 2: IngressRoute Not Routing Traffic
**Symptom**: curl returns 404 Not Found
**Mitigation**:
- Verify IngressRoute created: `kubectl get ingressroute`
- Check Traefik logs: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik`
- Verify backend service exists: `kubectl get svc whoami`
- Check service has endpoints: `kubectl get endpoints whoami`
- Use Traefik dashboard to inspect routing rules

### Risk 3: Traefik Pods CrashLooping
**Symptom**: Pods in CrashLoopBackOff state
**Mitigation**:
- Check pod logs: `kubectl logs -n traefik <pod-name>`
- Common issues: RBAC permissions, port conflicts, invalid Helm values
- Verify RBAC: `kubectl get clusterrole,clusterrolebinding -l app.kubernetes.io/name=traefik`
- Check events: `kubectl describe pod -n traefik <pod-name>`

### Risk 4: Dashboard Not Accessible
**Symptom**: Dashboard URL returns 404 or connection refused
**Mitigation**:
- Verify dashboard enabled in Helm values: `dashboard.enabled: true`
- Check Traefik service ports: `kubectl get svc -n traefik traefik -o yaml`
- Port-forward to pod directly: `kubectl port-forward -n traefik <pod-name> 9000:9000`
- Check IngressRoute for dashboard (if using hostname routing)

### Risk 5: Helm Chart Version Compatibility
**Symptom**: CRDs not installed, features missing
**Mitigation**:
- Pin Traefik chart version in terraform: `version = "~> 30.0"`
- Review chart release notes: https://github.com/traefik/traefik-helm-chart/releases
- Verify CRDs installed: `kubectl get crd | grep traefik`
- Test in non-production namespace first

## Learning Outcomes

By deploying Traefik, you will learn:

1. **Kubernetes Ingress Concepts**
   - Difference between Service (L4) and Ingress (L7)
   - How hostname-based routing works
   - Path-based routing patterns
   - TLS termination strategies

2. **CRD Extension Patterns**
   - How Custom Resource Definitions extend Kubernetes API
   - Operator pattern (Traefik watches CRDs, reconciles state)
   - Schema validation benefits

3. **Cloud-Native Load Balancing**
   - L4 (MetalLB) vs L7 (Traefik) load balancing
   - LoadBalancer Service type mechanics
   - HA ingress architecture

4. **Helm Chart Management**
   - Helm values customization
   - Chart version pinning
   - Infrastructure as Code for Helm via OpenTofu

5. **Observability Foundations**
   - Prometheus metrics format
   - Application instrumentation (/metrics endpoint)
   - Dashboard-driven operational visibility

6. **HTTP Traffic Engineering**
   - Middleware transformations (redirect, headers)
   - Request routing rules (match conditions)
   - Backend health checking

## Next Steps (Future Features)

1. **Feature 006: cert-manager Integration**
   - Automatic Let's Encrypt certificate issuance
   - TLS for all IngressRoutes
   - Certificate renewal automation

2. **Feature 00X: Prometheus + Grafana Monitoring**
   - Deploy Prometheus Operator
   - Create ServiceMonitor for Traefik
   - Grafana dashboards for ingress metrics

3. **Feature 00X: Advanced Middleware**
   - Rate limiting
   - Circuit breaking
   - Request authentication (OAuth2 proxy)

4. **Feature 00X: Multi-Service Ingress**
   - Pi-hole admin UI via IngressRoute
   - Grafana via IngressRoute
   - Homepage dashboard via IngressRoute
   - Unified ingress for all homelab services

## References

- **Traefik Documentation**: https://doc.traefik.io/traefik/
- **Helm Chart**: https://github.com/traefik/traefik-helm-chart
- **IngressRoute CRD**: https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/
- **Kubernetes Ingress**: https://kubernetes.io/docs/concepts/services-networking/ingress/
- **MetalLB Integration**: https://metallb.universe.tf/
- **Prometheus Metrics**: https://doc.traefik.io/traefik/observability/metrics/prometheus/
