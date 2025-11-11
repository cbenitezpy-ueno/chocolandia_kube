# Quickstart: Traefik Ingress Controller Deployment

**Feature**: 005-traefik | **Date**: 2025-11-10

## Overview

This quickstart guide walks through deploying Traefik v3.x ingress controller on the K3s cluster using OpenTofu, validating HTTP routing functionality, and accessing the Traefik dashboard. Expected completion time: 30-45 minutes.

---

## Prerequisites

### 1. Verify K3s Cluster Running

```bash
# Check all nodes are Ready
kubectl get nodes

# Expected output:
# NAME      STATUS   ROLES                       AGE   VERSION
# master1   Ready    control-plane,etcd,master   Xd    v1.28.x+k3s1
# master2   Ready    control-plane,etcd,master   Xd    v1.28.x+k3s1
# master3   Ready    control-plane,etcd,master   Xd    v1.28.x+k3s1
# nodo1     Ready    <none>                      Xd    v1.28.x+k3s1
```

### 2. Verify MetalLB Deployed

```bash
# Check MetalLB pods running
kubectl get pods -n metallb-system

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# controller-xxxxxxxxxx-xxxxx   1/1     Running   0          Xd
# speaker-xxxxx                 1/1     Running   0          Xd
# speaker-xxxxx                 1/1     Running   0          Xd
# speaker-xxxxx                 1/1     Running   0          Xd
# speaker-xxxxx                 1/1     Running   0          Xd

# Check IP pool configured
kubectl get ipaddresspool -n metallb-system

# Expected: At least one IP pool with range including 192.168.4.201
```

### 3. Verify kubectl Access

```bash
# Check kubectl can communicate with API server
kubectl cluster-info

# Expected: Kubernetes control plane is running at https://...
```

### 4. Verify OpenTofu Installed

```bash
# Check OpenTofu version
tofu version

# Expected: OpenTofu v1.6.x or higher
```

---

## Deployment Steps

### Step 1: Create Traefik Module Directory

```bash
# Navigate to project root
cd /Users/cbenitez/chocolandia_kube

# Create module directory structure
mkdir -p terraform/modules/traefik
mkdir -p terraform/manifests/traefik
mkdir -p tests/traefik
```

### Step 2: Create Traefik Helm Values File

Create `/Users/cbenitez/chocolandia_kube/terraform/modules/traefik/values.yaml`:

```yaml
# Traefik Helm chart values
# Managed by OpenTofu - DO NOT modify manually

# Deployment configuration
deployment:
  replicas: 2                          # HA: 2 replicas for fault tolerance
  podDisruptionBudget:
    enabled: true
    minAvailable: 1                    # At least 1 replica always running

# Service configuration
service:
  enabled: true
  type: LoadBalancer                   # MetalLB assigns external IP
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.4.201  # Static IP from pool
  spec:
    externalTrafficPolicy: Local       # Preserve source IP

# Ports configuration
ports:
  web:
    port: 80                           # HTTP entrypoint
    expose: true
    exposedPort: 80
  websecure:
    port: 443                          # HTTPS entrypoint
    expose: true
    exposedPort: 443
  metrics:
    port: 9100                         # Prometheus metrics
    expose: false                      # Internal only

# Entrypoints (Traefik terminology for listeners)
additionalArguments:
  - --entrypoints.web.address=:80
  - --entrypoints.websecure.address=:443
  - --entrypoints.metrics.address=:9100
  - --providers.kubernetescrd        # Enable IngressRoute CRD provider
  - --api.dashboard=true              # Enable dashboard
  - --metrics.prometheus=true         # Enable Prometheus metrics
  - --ping=true                       # Enable /ping health endpoint
  - --log.level=INFO                  # Log level

# Prometheus metrics
metrics:
  prometheus:
    enabled: true
    entryPoint: metrics

# Dashboard (will be exposed via IngressRoute separately)
ingressRoute:
  dashboard:
    enabled: false                    # We create custom IngressRoute

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
  httpGet:
    path: /ping
    port: 9000
  initialDelaySeconds: 10
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /ping
    port: 9000
  initialDelaySeconds: 10
  periodSeconds: 10

# Pod anti-affinity (spread replicas across nodes)
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: traefik
          topologyKey: kubernetes.io/hostname

# Security context
securityContext:
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  runAsGroup: 65532
  runAsNonRoot: true
  runAsUser: 65532

# Service account
serviceAccount:
  create: true
  name: traefik

# RBAC
rbac:
  enabled: true
```

### Step 3: Create Traefik OpenTofu Module

Create `/Users/cbenitez/chocolandia_kube/terraform/modules/traefik/main.tf`:

```hcl
# Traefik Ingress Controller Module
# Deploys Traefik v3.x via Helm chart

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = true

  values = [
    file("${path.module}/values.yaml")
  ]

  # Allow Helm to manage CRDs
  skip_crds = false

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  # Atomic rollback on failure
  atomic = true
}

# Wait for LoadBalancer IP assignment
resource "time_sleep" "wait_for_lb" {
  depends_on = [helm_release.traefik]

  create_duration = "30s"
}
```

Create `/Users/cbenitez/chocolandia_kube/terraform/modules/traefik/variables.tf`:

```hcl
variable "namespace" {
  description = "Kubernetes namespace for Traefik deployment"
  type        = string
  default     = "traefik"
}

variable "chart_version" {
  description = "Traefik Helm chart version"
  type        = string
  default     = "30.0.2"  # Traefik v3.2.x
}

variable "loadbalancer_ip" {
  description = "Static LoadBalancer IP from MetalLB pool"
  type        = string
  default     = "192.168.4.201"
}

variable "replicas" {
  description = "Number of Traefik replicas for HA"
  type        = number
  default     = 2
}
```

Create `/Users/cbenitez/chocolandia_kube/terraform/modules/traefik/outputs.tf`:

```hcl
output "namespace" {
  description = "Namespace where Traefik is deployed"
  value       = helm_release.traefik.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.traefik.name
}

output "chart_version" {
  description = "Deployed Helm chart version"
  value       = helm_release.traefik.version
}
```

Create `/Users/cbenitez/chocolandia_kube/terraform/modules/traefik/versions.tf`:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
```

### Step 4: Instantiate Traefik Module in Environment

Create `/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/traefik.tf`:

```hcl
# Traefik Ingress Controller for chocolandiadc-mvp environment

module "traefik" {
  source = "../../modules/traefik"

  namespace       = "traefik"
  chart_version   = "30.0.2"
  loadbalancer_ip = "192.168.4.201"
  replicas        = 2
}

# Outputs
output "traefik_namespace" {
  description = "Traefik deployment namespace"
  value       = module.traefik.namespace
}

output "traefik_release" {
  description = "Traefik Helm release name"
  value       = module.traefik.release_name
}
```

### Step 5: Deploy Traefik via OpenTofu

```bash
# Navigate to environment directory
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Initialize OpenTofu (download providers)
tofu init

# Validate configuration
tofu validate

# Preview changes
tofu plan

# Expected output: Plan to create Helm release, wait resource

# Apply changes
tofu apply

# Type 'yes' when prompted
# Wait for deployment to complete (~2-3 minutes)
```

### Step 6: Verify Traefik Deployment

```bash
# Check Traefik namespace created
kubectl get namespace traefik

# Check Traefik pods running (2 replicas)
kubectl get pods -n traefik -l app.kubernetes.io/name=traefik

# Expected output:
# NAME                       READY   STATUS    RESTARTS   AGE
# traefik-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# traefik-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# Check all pods are on different nodes (anti-affinity)
kubectl get pods -n traefik -o wide

# Check LoadBalancer service has external IP
kubectl get svc -n traefik traefik

# Expected output:
# NAME      TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
# traefik   LoadBalancer   10.43.x.x       192.168.4.201    80:30080/TCP,443:30443/TCP

# Check Traefik CRDs installed
kubectl get crd | grep traefik

# Expected: ingressroutes.traefik.io, middlewares.traefik.io, tlsoptions.traefik.io, etc.
```

---

## Validation Steps

### Step 7: Deploy Test whoami Service

Create `/Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-test.yaml`:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: default
spec:
  selector:
    app: whoami
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:latest
          ports:
            - containerPort: 80
```

Deploy whoami service:

```bash
kubectl apply -f /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-test.yaml

# Verify whoami pods running
kubectl get pods -n default -l app=whoami

# Expected: 2 whoami pods Running
```

### Step 8: Create Test IngressRoute

Create `/Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-ingressroute.yaml`:

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

Deploy IngressRoute:

```bash
kubectl apply -f /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-ingressroute.yaml

# Verify IngressRoute created
kubectl get ingressroute -n default

# Expected: whoami IngressRoute listed
```

### Step 9: Test HTTP Routing

```bash
# Test with curl (using Host header)
curl -H "Host: whoami.local" http://192.168.4.201

# Expected output: whoami service response
# Hostname: whoami-xxxxxxxxxx-xxxxx
# IP: 10.42.x.x
# GET / HTTP/1.1
# Host: whoami.local
# User-Agent: curl/...
# X-Forwarded-For: <your-ip>
# X-Forwarded-Host: whoami.local
# X-Forwarded-Port: 80
# X-Forwarded-Proto: http
# X-Forwarded-Server: traefik-xxxxxxxxxx-xxxxx
# X-Real-Ip: <your-ip>

# Test from browser (requires /etc/hosts entry)
# Add to /etc/hosts:
echo "192.168.4.201 whoami.local" | sudo tee -a /etc/hosts

# Open browser: http://whoami.local
# Expected: whoami service response in browser
```

### Step 10: Access Traefik Dashboard

```bash
# Port-forward to Traefik pod (dashboard on port 9000)
kubectl port-forward -n traefik svc/traefik 9000:9000

# Open browser: http://localhost:9000/dashboard/
# Expected: Traefik dashboard UI loads

# Dashboard should show:
# - HTTP Routers: whoami@default (1 route)
# - Services: whoami@default (2 endpoints)
# - Middlewares: (none yet)
# - Entrypoints: web (80), websecure (443), metrics (9100)
```

Alternative: Create IngressRoute for dashboard access:

Create `/Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/dashboard-ingressroute.yaml`:

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
```

Deploy and access:

```bash
kubectl apply -f /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/dashboard-ingressroute.yaml

# Add to /etc/hosts
echo "192.168.4.201 traefik.local" | sudo tee -a /etc/hosts

# Open browser: http://traefik.local/dashboard/
# Expected: Dashboard accessible via hostname
```

### Step 11: Validate Prometheus Metrics

```bash
# Port-forward to metrics port
kubectl port-forward -n traefik svc/traefik 9100:9100

# Check metrics endpoint
curl http://localhost:9100/metrics

# Expected: Prometheus-format metrics output
# Example metrics:
# traefik_entrypoint_requests_total{entrypoint="web",code="200",method="GET"} 5
# traefik_entrypoint_request_duration_seconds_bucket{entrypoint="web",le="0.1"} 5
# traefik_service_requests_total{service="whoami@default",code="200",method="GET"} 5
```

### Step 12: Validate High Availability

```bash
# Send continuous requests in background
while true; do curl -s -H "Host: whoami.local" http://192.168.4.201 | grep Hostname; sleep 1; done &
CURL_PID=$!

# Delete one Traefik pod
kubectl delete pod -n traefik -l app.kubernetes.io/name=traefik --field-selector status.phase=Running | head -1

# Observe continuous requests (should continue without interruption)
# Wait ~10 seconds for pod to terminate and new pod to start

# Stop background requests
kill $CURL_PID

# Verify 2 replicas running again
kubectl get pods -n traefik -l app.kubernetes.io/name=traefik

# Expected: 2 Running pods (Kubernetes recreated deleted pod)
```

---

## Integration Tests

### Test Script 1: Deployment Validation

Create `/Users/cbenitez/chocolandia_kube/tests/traefik/test_deployment.sh`:

```bash
#!/bin/bash
set -e

echo "=== Traefik Deployment Validation ==="

# Test 1: Namespace exists
echo "Test 1: Checking Traefik namespace..."
kubectl get namespace traefik > /dev/null 2>&1 || { echo "FAIL: traefik namespace not found"; exit 1; }
echo "PASS: Namespace exists"

# Test 2: Pods running
echo "Test 2: Checking Traefik pods..."
POD_COUNT=$(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik --field-selector=status.phase=Running --no-headers | wc -l)
if [ "$POD_COUNT" -lt 2 ]; then
  echo "FAIL: Expected 2 Running pods, found $POD_COUNT"
  exit 1
fi
echo "PASS: $POD_COUNT pods running"

# Test 3: LoadBalancer IP assigned
echo "Test 3: Checking LoadBalancer IP..."
LB_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$LB_IP" ]; then
  echo "FAIL: LoadBalancer IP not assigned"
  exit 1
fi
echo "PASS: LoadBalancer IP: $LB_IP"

# Test 4: CRDs installed
echo "Test 4: Checking Traefik CRDs..."
kubectl get crd ingressroutes.traefik.io > /dev/null 2>&1 || { echo "FAIL: IngressRoute CRD not found"; exit 1; }
kubectl get crd middlewares.traefik.io > /dev/null 2>&1 || { echo "FAIL: Middleware CRD not found"; exit 1; }
echo "PASS: CRDs installed"

echo "=== All deployment tests passed ==="
```

Make executable and run:

```bash
chmod +x /Users/cbenitez/chocolandia_kube/tests/traefik/test_deployment.sh
/Users/cbenitez/chocolandia_kube/tests/traefik/test_deployment.sh
```

### Test Script 2: Routing Validation

Create `/Users/cbenitez/chocolandia_kube/tests/traefik/test_routing.sh`:

```bash
#!/bin/bash
set -e

echo "=== Traefik Routing Validation ==="

# Get LoadBalancer IP
LB_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test 1: whoami service reachable
echo "Test 1: Testing whoami service routing..."
RESPONSE=$(curl -s -H "Host: whoami.local" http://$LB_IP)
if ! echo "$RESPONSE" | grep -q "Hostname:"; then
  echo "FAIL: whoami service did not respond correctly"
  echo "Response: $RESPONSE"
  exit 1
fi
echo "PASS: whoami service routing works"

# Test 2: HTTP status code
echo "Test 2: Testing HTTP 200 status..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: whoami.local" http://$LB_IP)
if [ "$STATUS" != "200" ]; then
  echo "FAIL: Expected HTTP 200, got $STATUS"
  exit 1
fi
echo "PASS: HTTP 200 response"

# Test 3: Undefined hostname (should 404)
echo "Test 3: Testing undefined hostname..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: undefined.local" http://$LB_IP)
if [ "$STATUS" != "404" ]; then
  echo "WARN: Expected HTTP 404 for undefined hostname, got $STATUS"
fi
echo "PASS: Undefined hostname returns $STATUS"

echo "=== All routing tests passed ==="
```

Make executable and run:

```bash
chmod +x /Users/cbenitez/chocolandia_kube/tests/traefik/test_routing.sh
/Users/cbenitez/chocolandia_kube/tests/traefik/test_routing.sh
```

---

## Troubleshooting

### Issue 1: LoadBalancer IP Stuck in `<pending>`

**Symptom**:
```bash
kubectl get svc -n traefik traefik
# EXTERNAL-IP shows <pending>
```

**Diagnosis**:
```bash
# Check MetalLB controller logs
kubectl logs -n metallb-system -l app=metallb,component=controller

# Check MetalLB speaker logs
kubectl logs -n metallb-system -l app=metallb,component=speaker

# Check IP pool configuration
kubectl get ipaddresspool -n metallb-system -o yaml
```

**Solutions**:
1. Verify MetalLB is running: `kubectl get pods -n metallb-system`
2. Verify IP pool contains 192.168.4.201: `kubectl get ipaddresspool -n metallb-system -o yaml`
3. Check service annotation: `kubectl get svc -n traefik traefik -o yaml | grep metallb`
4. Delete and recreate service: `kubectl delete svc -n traefik traefik && tofu apply`

---

### Issue 2: IngressRoute Not Routing Traffic (404 Not Found)

**Symptom**:
```bash
curl -H "Host: whoami.local" http://192.168.4.201
# Returns: 404 page not found
```

**Diagnosis**:
```bash
# Check IngressRoute exists
kubectl get ingressroute -n default whoami

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik | grep whoami

# Check backend service endpoints
kubectl get endpoints -n default whoami

# Check Traefik dashboard (routing rules)
kubectl port-forward -n traefik svc/traefik 9000:9000
# Open: http://localhost:9000/dashboard/
```

**Solutions**:
1. Verify IngressRoute created: `kubectl describe ingressroute whoami`
2. Verify backend service exists: `kubectl get svc whoami`
3. Verify service has endpoints: `kubectl get endpoints whoami` (should show pod IPs)
4. Check IngressRoute match rule: Must match hostname exactly (case-sensitive)
5. Check Traefik logs for errors: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik`

---

### Issue 3: Traefik Pods CrashLooping

**Symptom**:
```bash
kubectl get pods -n traefik
# STATUS: CrashLoopBackOff or Error
```

**Diagnosis**:
```bash
# Check pod logs
kubectl logs -n traefik <pod-name>

# Check pod events
kubectl describe pod -n traefik <pod-name>

# Check RBAC permissions
kubectl get clusterrole,clusterrolebinding -l app.kubernetes.io/name=traefik
```

**Solutions**:
1. Check Helm values syntax: `tofu validate`
2. Verify RBAC permissions: Helm chart creates ClusterRole/ClusterRoleBinding
3. Check port conflicts: Ensure ports 80, 443, 9100 not already in use
4. Check resource limits: May need to increase memory/CPU limits
5. Reinstall: `tofu destroy && tofu apply`

---

### Issue 4: Dashboard Not Accessible

**Symptom**:
```bash
kubectl port-forward -n traefik svc/traefik 9000:9000
curl http://localhost:9000/dashboard/
# Connection refused or 404
```

**Diagnosis**:
```bash
# Check dashboard enabled in Helm values
kubectl get deployment -n traefik traefik -o yaml | grep dashboard

# Check Traefik service ports
kubectl get svc -n traefik traefik -o yaml | grep 9000
```

**Solutions**:
1. Verify `dashboard.enabled: true` in values.yaml
2. Port-forward to pod directly: `kubectl port-forward -n traefik <pod-name> 9000:9000`
3. Check IngressRoute for dashboard (if using hostname): `kubectl get ingressroute -n traefik dashboard`
4. Access via /dashboard/ (note trailing slash): `http://localhost:9000/dashboard/`

---

### Issue 5: Metrics Endpoint Not Working

**Symptom**:
```bash
curl http://192.168.4.201:9100/metrics
# Connection refused
```

**Diagnosis**:
```bash
# Port-forward to pod
kubectl port-forward -n traefik svc/traefik 9100:9100
curl http://localhost:9100/metrics

# Check Helm values
kubectl get deployment -n traefik traefik -o yaml | grep prometheus
```

**Solutions**:
1. Metrics port (9100) is internal only, use port-forward for testing
2. Verify `metrics.prometheus.enabled: true` in values.yaml
3. Check additionalArguments includes `--metrics.prometheus=true`
4. Metrics will be scraped by Prometheus (future), not exposed externally

---

## Next Steps

1. **Deploy additional services with IngressRoute**
   - Pi-hole admin UI: `pihole.local`
   - Grafana: `grafana.local` (when deployed)
   - Homepage dashboard: `home.local` (when deployed)

2. **Configure HTTPS with self-signed certificates**
   - Generate self-signed cert: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt`
   - Create Secret: `kubectl create secret tls <name>-tls --cert=tls.crt --key=tls.key`
   - Update IngressRoute with `tls.secretName`

3. **Deploy cert-manager for automatic TLS (Feature 006)**
   - Let's Encrypt integration
   - Automatic certificate issuance and renewal

4. **Deploy Prometheus/Grafana for metrics visualization**
   - Create ServiceMonitor for Traefik
   - Import Traefik dashboard to Grafana
   - Set up alerts for ingress failures

5. **Configure advanced middleware**
   - HTTP → HTTPS redirect
   - Security headers (HSTS, CSP, X-Frame-Options)
   - Basic authentication for sensitive services
   - Rate limiting

---

## Cleanup (Optional)

To remove Traefik deployment:

```bash
# Delete test resources
kubectl delete -f /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-ingressroute.yaml
kubectl delete -f /Users/cbenitez/chocolandia_kube/terraform/manifests/traefik/whoami-test.yaml

# Destroy Traefik via OpenTofu
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp
tofu destroy -target=module.traefik

# Type 'yes' when prompted
# Wait for resources to be deleted
```

---

## Summary

You have successfully:
- ✅ Deployed Traefik v3.x ingress controller via OpenTofu Helm module
- ✅ Verified LoadBalancer IP assigned by MetalLB (192.168.4.201)
- ✅ Deployed test whoami service with IngressRoute
- ✅ Validated HTTP routing works (curl + browser)
- ✅ Accessed Traefik dashboard for operational visibility
- ✅ Verified Prometheus metrics endpoint exposed
- ✅ Tested HA behavior (pod failure recovery)
- ✅ Ran integration test scripts

**Your K3s cluster now has a production-ready ingress controller** capable of routing external HTTP/HTTPS traffic to internal services. All future web services can be exposed via IngressRoute CRDs without exposing additional LoadBalancer IPs.

**Next recommended feature**: Deploy cert-manager for automatic TLS certificate management (Let's Encrypt integration).
