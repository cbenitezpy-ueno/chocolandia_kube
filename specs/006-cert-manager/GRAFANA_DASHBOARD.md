# cert-manager Grafana Dashboard Setup

**Dashboard ID**: 11001 (Official cert-manager dashboard from Grafana.com)
**Status**: ✅ ServiceMonitor configured and active

---

## Prerequisites

✅ Prometheus Operator deployed (kube-prometheus-stack)
✅ Grafana deployed and accessible
✅ cert-manager ServiceMonitor created (`kubectl get servicemonitor -n cert-manager`)

---

## Option 1: Import via Grafana UI (Recommended)

### Step 1: Access Grafana

```bash
# Get Grafana URL from terraform output
echo "https://grafana.chocolandiadc.com"

# Or use port-forward if Cloudflare Tunnel not working
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Then access: http://localhost:3000
```

### Step 2: Login to Grafana

- **Default credentials** (if not changed):
  - Username: `admin`
  - Password: Get from secret:
    ```bash
    kubectl get secret kube-prometheus-stack-grafana -n monitoring \
      -o jsonpath='{.data.admin-password}' | base64 -d && echo
    ```

### Step 3: Import Dashboard

1. **Navigate**: Click "+" icon (top left) → "Import dashboard"
2. **Enter Dashboard ID**: `11001`
3. **Click "Load"**
4. **Configure**:
   - **Name**: cert-manager (or keep default)
   - **Folder**: Select folder (e.g., "Kubernetes" or "cert-manager")
   - **Prometheus Data Source**: Select `Prometheus` (kube-prometheus-stack)
5. **Click "Import"**

✅ **Done!** Dashboard will load with cert-manager metrics.

---

## Option 2: Import via kubectl ConfigMap

### Step 1: Create Dashboard ConfigMap

```bash
# Download dashboard JSON
curl -s https://grafana.com/api/dashboards/11001/revisions/1/download \
  -o /tmp/cert-manager-dashboard.json

# Create ConfigMap
kubectl create configmap cert-manager-dashboard \
  --from-file=/tmp/cert-manager-dashboard.json \
  -n monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# Add Grafana sidecar labels
kubectl label configmap cert-manager-dashboard \
  -n monitoring \
  grafana_dashboard=1
```

### Step 2: Wait for Grafana Sidecar to Pick Up

Grafana sidecar automatically discovers ConfigMaps with `grafana_dashboard=1` label:

```bash
# Watch Grafana logs for dashboard import
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard --tail=20 -f
```

You should see log line:
```
INFO  Importing dashboard cert-manager from ConfigMap cert-manager-dashboard
```

✅ **Done!** Dashboard will appear in Grafana UI under "Dashboards" → "Manage".

---

## Dashboard Panels

The cert-manager dashboard includes:

### Certificate Metrics
- **Certificate Expiry Timeline**: Visual timeline showing when certificates expire
- **Certificates Expiring Soon**: Count of certificates expiring in next 7/14/30 days
- **Certificate Renewal Failures**: Failed renewal attempts
- **Certificate Status**: Ready vs Not Ready certificates

### ACME Metrics
- **ACME API Requests**: Rate of requests to Let's Encrypt API
- **ACME Request Duration**: Latency of ACME API calls
- **ACME Request Errors**: Failed ACME requests

### Component Health
- **cert-manager Controller**: CPU/Memory usage, restarts
- **cert-manager Webhook**: CPU/Memory usage, restarts
- **cert-manager CAInjector**: CPU/Memory usage, restarts

---

## Verifying Metrics in Prometheus

Before importing dashboard, verify Prometheus is scraping cert-manager metrics:

### Check ServiceMonitor

```bash
kubectl get servicemonitor -n cert-manager
# Should show: cert-manager   <age>
```

### Check Prometheus Targets

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Then open browser: http://localhost:9090/targets

Search for "cert-manager" - should show:
- `serviceMonitor/cert-manager/cert-manager/0 (UP)` ✅

### Query Metrics Directly

In Prometheus UI (http://localhost:9090), try these queries:

```promql
# Certificate expiration timestamp
certmanager_certificate_expiration_timestamp_seconds

# Certificate ready status (1=ready, 0=not ready)
certmanager_certificate_ready_status

# ACME request count
rate(certmanager_http_acme_client_request_count[5m])

# ACME request duration (seconds)
certmanager_http_acme_client_request_duration_seconds
```

If metrics return data ✅ → Prometheus is scraping correctly.

---

## Key Metrics to Monitor

### Critical Alerts to Configure

1. **Certificate Expiring Soon**
   ```promql
   # Alert if certificate expires in < 7 days
   (certmanager_certificate_expiration_timestamp_seconds - time()) / 86400 < 7
   ```

2. **Certificate Not Ready**
   ```promql
   # Alert if certificate is not ready for > 1 hour
   certmanager_certificate_ready_status == 0
   ```

3. **ACME Request Failures**
   ```promql
   # Alert if ACME requests failing
   rate(certmanager_http_acme_client_request_count{status!~"2.."}[5m]) > 0
   ```

### Dashboard Variables

The official dashboard includes these variables:
- **datasource**: Prometheus data source selection
- **namespace**: Filter by certificate namespace
- **issuer**: Filter by ClusterIssuer (staging/production)

---

## Troubleshooting

### Dashboard Shows "No Data"

**Check 1: Verify ServiceMonitor exists**
```bash
kubectl get servicemonitor cert-manager -n cert-manager
```

**Check 2: Verify Prometheus target is UP**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets
# Search for "cert-manager"
```

**Check 3: Verify metrics endpoint is working**
```bash
# Get cert-manager controller pod
CONTROLLER_POD=$(kubectl get pod -n cert-manager -l app=cert-manager -o jsonpath='{.items[0].metadata.name}')

# Check metrics endpoint
kubectl exec -n cert-manager $CONTROLLER_POD -- wget -qO- http://localhost:9402/metrics | head -20
```

Should show metrics like:
```
certmanager_certificate_expiration_timestamp_seconds{...} 1234567890
certmanager_certificate_ready_status{...} 1
```

### Prometheus Not Scraping

**Check ServiceMonitor labels**
```bash
kubectl get servicemonitor cert-manager -n cert-manager -o yaml | grep -A 5 labels
```

Must have: `release: kube-prometheus-stack`

**Check Prometheus ServiceMonitor selector**
```bash
kubectl get prometheus kube-prometheus-stack-prometheus -n monitoring -o yaml | grep -A 10 serviceMonitorSelector
```

Should match ServiceMonitor labels.

---

## Manual Dashboard JSON Import

If auto-import fails, manually import the dashboard:

```bash
# Download dashboard JSON
curl -s https://grafana.com/api/dashboards/11001/revisions/1/download \
  -o cert-manager-dashboard.json

# Upload via Grafana UI:
# Dashboards → Import → Upload JSON file → Select cert-manager-dashboard.json
```

---

## References

- [Official Dashboard](https://grafana.com/grafana/dashboards/11001)
- [cert-manager Prometheus Metrics](https://cert-manager.io/docs/usage/prometheus-metrics/)
- [Grafana Dashboard Import](https://grafana.com/docs/grafana/latest/dashboards/manage-dashboards/#import-a-dashboard)
