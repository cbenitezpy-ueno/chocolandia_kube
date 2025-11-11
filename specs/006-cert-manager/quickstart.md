# Quickstart: cert-manager Deployment

**Feature**: 006-cert-manager
**Date**: 2025-11-11
**Estimated Time**: 30-45 minutes

This guide walks through deploying cert-manager, configuring Let's Encrypt issuers, and issuing your first certificate.

---

## Prerequisites

Before starting, ensure the following are deployed and operational:

1. ✅ **K3s cluster** (Feature 001/002): Running with at least 1 control-plane node
2. ✅ **Traefik ingress** (Feature 005): Deployed and serving HTTP/HTTPS traffic
3. ✅ **Cloudflare Tunnel** (Feature 004): Configured to route traffic to Traefik
4. ✅ **MetalLB** (Feature 002): Providing LoadBalancer IPs for Traefik
5. ✅ **Public domain**: DNS A/AAAA record pointing to homelab (via Cloudflare Tunnel)
6. ✅ **Port 80 accessible**: Cloudflare Tunnel must route HTTP traffic for ACME challenges

### Verification Commands

```bash
# Verify K3s cluster
kubectl get nodes

# Verify Traefik
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Verify Traefik LoadBalancer IP
kubectl get svc -n kube-system traefik

# Verify domain resolution (replace with your domain)
dig +short chocolandiadc.com

# Verify port 80 accessible (replace with your domain)
curl -I http://chocolandiadc.com
```

---

## Step 1: Deploy cert-manager via OpenTofu

### 1.1 Navigate to Environment Directory

```bash
cd terraform/environments/chocolandiadc-mvp
```

### 1.2 Review OpenTofu Configuration

The cert-manager module should already be defined in your environment's OpenTofu configuration:

```hcl
# main.tf or cert-manager.tf
module "cert_manager" {
  source = "../../modules/cert-manager"

  # Helm chart configuration
  cert_manager_version = "v1.13.3"  # Latest stable version
  namespace            = "cert-manager"
  create_namespace     = true

  # Resource limits (homelab configuration)
  controller_resources = {
    requests = {
      cpu    = "10m"
      memory = "32Mi"
    }
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }

  webhook_resources = {
    requests = {
      cpu    = "10m"
      memory = "32Mi"
    }
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }

  cainjector_resources = {
    requests = {
      cpu    = "10m"
      memory = "32Mi"
    }
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }

  # Let's Encrypt configuration
  acme_email                    = "your-email@example.com"  # REQUIRED: Your email for Let's Encrypt
  letsencrypt_staging_enabled   = true
  letsencrypt_production_enabled = true

  # HTTP-01 challenge configuration
  acme_http01_ingress_class = "traefik"

  # Prometheus metrics
  prometheus_enabled = true
}
```

**IMPORTANT**: Replace `your-email@example.com` with your actual email address. This is required by Let's Encrypt for certificate expiry notifications.

### 1.3 Initialize and Apply

```bash
# Initialize OpenTofu (if not already done)
tofu init

# Format configuration
tofu fmt

# Validate configuration
tofu validate

# Preview changes
tofu plan

# Apply (review plan carefully before confirming)
tofu apply
```

### 1.4 Verify Deployment

```bash
# Wait for cert-manager pods to be ready (may take 1-2 minutes)
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=120s

# Check pod status
kubectl get pods -n cert-manager

# Expected output:
# NAME                                      READY   STATUS    RESTARTS   AGE
# cert-manager-5d7f97b46d-xxxxx            1/1     Running   0          2m
# cert-manager-cainjector-69d885bf55-xxxxx 1/1     Running   0          2m
# cert-manager-webhook-54754dcdfd-xxxxx    1/1     Running   0          2m

# Verify CRDs installed
kubectl get crd | grep cert-manager

# Expected CRDs:
# certificaterequests.cert-manager.io
# certificates.cert-manager.io
# challenges.acme.cert-manager.io
# clusterissuers.cert-manager.io
# issuers.cert-manager.io
# orders.acme.cert-manager.io
```

---

## Step 2: Verify ClusterIssuers

The OpenTofu module should have created two ClusterIssuers: staging and production.

### 2.1 Check ClusterIssuers

```bash
# List ClusterIssuers
kubectl get clusterissuer

# Expected output:
# NAME                     READY   AGE
# letsencrypt-staging      True    2m
# letsencrypt-production   True    2m

# Verify staging issuer details
kubectl describe clusterissuer letsencrypt-staging

# Verify production issuer details
kubectl describe clusterissuer letsencrypt-production
```

### 2.2 Troubleshoot if Not Ready

If ClusterIssuer shows `Ready: False`, check the reason:

```bash
# Check status conditions
kubectl get clusterissuer letsencrypt-staging -o yaml | grep -A 10 status

# Common issues:
# - Invalid ACME email format
# - Network connectivity to Let's Encrypt API
# - ACME account registration failure

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager -f
```

---

## Step 3: Request Staging Certificate (Testing)

**IMPORTANT**: Always test with staging issuer first to avoid production rate limits!

### 3.1 Create Test Certificate

Create a file `test-certificate-staging.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert-staging
  namespace: default
spec:
  secretName: test-cert-staging-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  commonName: test.chocolandiadc.com  # Replace with your subdomain
  dnsNames:
    - test.chocolandiadc.com
```

Apply the certificate:

```bash
kubectl apply -f test-certificate-staging.yaml
```

### 3.2 Monitor Certificate Issuance

```bash
# Watch certificate status
kubectl get certificate test-cert-staging -w

# Expected progression:
# NAME                 READY   SECRET                   AGE
# test-cert-staging    False   test-cert-staging-tls    5s
# test-cert-staging    False   test-cert-staging-tls    10s   # Issuing
# test-cert-staging    True    test-cert-staging-tls    2m    # Ready

# Check certificate details
kubectl describe certificate test-cert-staging

# Check CertificateRequest (created automatically)
kubectl get certificaterequest

# Check Order (ACME workflow)
kubectl get order

# Check Challenge (HTTP-01 validation)
kubectl get challenge
```

### 3.3 Verify Certificate Issued

```bash
# Check if secret was created
kubectl get secret test-cert-staging-tls

# Inspect certificate details
kubectl get secret test-cert-staging-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text

# Verify issuer (should show "Fake LE Intermediate X1" for staging)
kubectl get secret test-cert-staging-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer

# Expected output:
# issuer=C = US, O = (STAGING) Let's Encrypt, CN = (STAGING) Artificial Apricot R3
```

### 3.4 Troubleshoot if Certificate Not Ready

```bash
# Check certificate events
kubectl describe certificate test-cert-staging

# Common issues and solutions:
# - "Waiting for CertificateRequest": Check certificaterequest status
# - "Challenge failed": Check challenge details and logs

# Check CertificateRequest failure reason
kubectl describe certificaterequest $(kubectl get certificaterequest -l cert-manager.io/certificate-name=test-cert-staging -o name)

# Check Challenge failure reason
kubectl describe challenge

# Check solver pod logs (if challenge failed)
kubectl logs $(kubectl get pods -l acme.cert-manager.io/http01-solver=true -o name)

# Check cert-manager controller logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=100

# Verify HTTP-01 challenge endpoint is reachable
# (Replace with your domain and token from Challenge resource)
curl http://test.chocolandiadc.com/.well-known/acme-challenge/<TOKEN>
```

---

## Step 4: Request Production Certificate

Once staging works, proceed to production.

### 4.1 Create Production Certificate

Create a file `test-certificate-production.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert-production
  namespace: default
spec:
  secretName: test-cert-production-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: test.chocolandiadc.com  # Same domain as staging test
  dnsNames:
    - test.chocolandiadc.com
```

Apply the certificate:

```bash
kubectl apply -f test-certificate-production.yaml
```

### 4.2 Monitor and Verify

```bash
# Watch certificate status
kubectl get certificate test-cert-production -w

# Verify certificate is trusted (should show "R3" issuer, not staging)
kubectl get secret test-cert-production-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer

# Expected output:
# issuer=C = US, O = Let's Encrypt, CN = R3

# Test HTTPS (if you have IngressRoute configured)
curl -v https://test.chocolandiadc.com

# Verify certificate trust in browser
open https://test.chocolandiadc.com
```

---

## Step 5: Integrate with Traefik IngressRoute

Now that cert-manager is working, integrate with Traefik for automatic certificate provisioning.

### 5.1 Create IngressRoute with cert-manager Annotation

Create a file `test-ingress-with-cert.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: default
spec:
  selector:
    app: whoami
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: default
spec:
  replicas: 1
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
          image: traefik/whoami:v1.8.0
          ports:
            - containerPort: 80
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: whoami-https
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production  # Automatic cert!
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`whoami.chocolandiadc.com`)  # Replace with your domain
      kind: Rule
      services:
        - name: whoami
          port: 80
  tls:
    secretName: whoami-tls  # cert-manager will create this automatically
```

Apply the resources:

```bash
kubectl apply -f test-ingress-with-cert.yaml
```

### 5.2 Verify Automatic Certificate Creation

```bash
# Check if Certificate was created automatically
kubectl get certificate whoami-tls

# Expected output:
# NAME         READY   SECRET       AGE
# whoami-tls   True    whoami-tls   2m

# Test HTTPS endpoint
curl https://whoami.chocolandiadc.com

# Verify certificate in browser
open https://whoami.chocolandiadc.com
```

**Magic!** Traefik automatically created a Certificate resource because of the `cert-manager.io/cluster-issuer` annotation. cert-manager issued the certificate, and Traefik uses it for TLS termination.

---

## Step 6: Verify Automatic Renewal Configuration

### 6.1 Check Renewal Settings

```bash
# Check certificate renewal configuration
kubectl get certificate test-cert-production -o yaml | grep -A 5 renewBefore

# Expected output:
# renewBefore: 720h0m0s  # 30 days before expiry
# duration: 2160h0m0s    # 90 days total validity
```

### 6.2 Verify Renewal Time

```bash
# Check when certificate will be renewed
kubectl describe certificate test-cert-production | grep "Renewal Time"

# Expected output:
# Renewal Time: 2025-12-11T10:00:00Z  # 60 days from issuance (30 days before expiry)
```

### 6.3 Test Manual Renewal (Optional)

```bash
# Install cmctl (cert-manager kubectl plugin)
# macOS:
brew install cmctl

# Linux:
curl -sSL https://github.com/cert-manager/cmctl/releases/latest/download/cmctl-linux-amd64.tar.gz | tar xz
sudo mv cmctl /usr/local/bin/

# Manually trigger renewal (for testing)
cmctl renew test-cert-production

# Verify new CertificateRequest created
kubectl get certificaterequest
```

---

## Step 7: Enable Prometheus Metrics (Optional)

If you have Prometheus deployed (future feature), verify metrics are exposed.

### 7.1 Check Metrics Endpoint

```bash
# Port-forward to cert-manager metrics endpoint
kubectl port-forward -n cert-manager svc/cert-manager 9402:9402

# In another terminal, fetch metrics
curl http://localhost:9402/metrics | grep certmanager

# Key metrics to look for:
# certmanager_certificate_expiration_timestamp_seconds
# certmanager_certificate_ready_status
# certmanager_http_acme_client_request_count
```

### 7.2 Create ServiceMonitor (if Prometheus Operator installed)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: cert-manager
  endpoints:
    - port: tcp-prometheus-servicemonitor
      interval: 60s
```

---

## Step 8: Clean Up Test Resources

After validating everything works, clean up test resources:

```bash
# Delete test certificates
kubectl delete certificate test-cert-staging test-cert-production

# Delete test secrets
kubectl delete secret test-cert-staging-tls test-cert-production-tls

# Delete test IngressRoute and service (optional)
kubectl delete -f test-ingress-with-cert.yaml
```

---

## Troubleshooting

### Issue: Certificate Stuck in "Issuing" State

**Symptoms**: Certificate shows `Ready: False` and stays in "Issuing" state.

**Diagnosis**:
```bash
# Check certificate events
kubectl describe certificate <cert-name>

# Check CertificateRequest
kubectl get certificaterequest -l cert-manager.io/certificate-name=<cert-name>
kubectl describe certificaterequest <request-name>

# Check Order
kubectl get order
kubectl describe order <order-name>

# Check Challenge
kubectl get challenge
kubectl describe challenge <challenge-name>
```

**Common Causes**:
1. **HTTP-01 endpoint unreachable**: Verify port 80 is accessible from internet
   ```bash
   curl http://<your-domain>/.well-known/acme-challenge/test
   ```
2. **Traefik not routing challenges**: Check Traefik logs
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
   ```
3. **Cloudflare Tunnel not forwarding port 80**: Check Cloudflare Tunnel configuration
4. **Firewall blocking**: Verify firewall rules allow HTTP traffic

### Issue: "too many certificates already issued" Error

**Symptoms**: Certificate fails with rate limit error.

**Solution**:
- Let's Encrypt production has strict rate limits (50 certs/week per domain)
- Wait 7 days for rate limit window to reset
- Use staging issuer for testing
- Consider wildcard certificates (requires DNS-01 challenge, future enhancement)

### Issue: Webhook Validation Fails

**Symptoms**: Certificate creation rejected with validation error.

**Diagnosis**:
```bash
# Check webhook logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager-webhook

# Check webhook service
kubectl get svc -n cert-manager cert-manager-webhook

# Check ValidatingWebhookConfiguration
kubectl get validatingwebhookconfiguration cert-manager-webhook
```

**Solution**:
- Verify webhook pod is running and healthy
- Check webhook TLS certificate is valid
- Retry after webhook is ready

### Issue: Certificate Renewal Fails

**Symptoms**: Certificate not renewed before expiration.

**Diagnosis**:
```bash
# Check certificate status
kubectl describe certificate <cert-name>

# Check cert-manager logs for renewal attempts
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager | grep "renewal"
```

**Solution**:
- Fix underlying issue (same troubleshooting as initial issuance)
- Manually trigger renewal: `cmctl renew <cert-name>`
- If expired, delete and recreate Certificate resource

---

## Next Steps

1. **Deploy production services with HTTPS**: Use cert-manager annotations on IngressRoutes
2. **Monitor certificate expiration**: Set up Grafana dashboards (future feature)
3. **Configure DNS-01 for wildcards**: For `*.chocolandiadc.com` certificates (future enhancement)
4. **Automate cert-manager upgrades**: Keep cert-manager up to date via OpenTofu

---

## Success Criteria Verification

Verify all success criteria from spec.md are met:

- ✅ **SC-001**: cert-manager pods running within 60 seconds
- ✅ **SC-002**: Staging certificate issued within 5 minutes
- ✅ **SC-003**: Production certificate issued and trusted by browsers
- ✅ **SC-004**: IngressRoute with annotation automatically provisions certificate
- ✅ **SC-005**: Certificate renewal configured (30 days before expiry)
- ✅ **SC-006**: Prometheus metrics endpoint returns 200
- ✅ **SC-007**: All CRDs installed, webhook validation works
- ✅ **SC-008**: HTTP-01 challenge completes successfully
- ✅ **SC-009**: Certificate logs visible in controller logs
- ✅ **SC-010**: Grafana dashboard displays metrics (if Prometheus deployed)

---

## Estimated Time Breakdown

- **Step 1**: Deploy cert-manager (5 minutes)
- **Step 2**: Verify ClusterIssuers (2 minutes)
- **Step 3**: Staging certificate (5-10 minutes)
- **Step 4**: Production certificate (5-10 minutes)
- **Step 5**: Traefik integration (5 minutes)
- **Step 6**: Renewal configuration (3 minutes)
- **Step 7**: Prometheus metrics (3 minutes, optional)
- **Step 8**: Cleanup (2 minutes)

**Total**: ~30-45 minutes (first time), ~15 minutes (subsequent deployments)

---

## Conclusion

You now have cert-manager deployed and configured with Let's Encrypt! All services exposed via Traefik can automatically get trusted SSL/TLS certificates by adding the `cert-manager.io/cluster-issuer` annotation to IngressRoutes.

**Key Takeaways**:
- Always test with staging issuer first to avoid rate limits
- cert-manager automates the entire certificate lifecycle (issuance, renewal)
- HTTP-01 challenges require port 80 to be accessible from internet
- Automatic renewal happens 30 days before expiration (configurable)
- Traefik integration makes HTTPS effortless (just add an annotation)

For production use, remember to:
- Monitor certificate expiration via Prometheus/Grafana
- Backup ACME account keys (stored in Kubernetes Secrets)
- Keep cert-manager updated to latest stable version
- Document any custom configurations in CLAUDE.md
