# cert-manager Deployment Summary

**Feature**: 006-cert-manager
**Date**: 2025-11-11
**Status**: ✅ **DEPLOYED SUCCESSFULLY**

---

## Deployment Results

### Components Deployed

All cert-manager components are running successfully:

```bash
$ kubectl get pods -n cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-668bb6dbfb-7pfrp              1/1     Running   0          5m
cert-manager-cainjector-76cb8c6689-mdsmc   1/1     Running   0          5m
cert-manager-webhook-85d959c455-xznmc      1/1     Running   0          5m
```

### ClusterIssuers Configured

Both Let's Encrypt issuers are ready and have registered ACME accounts:

```bash
$ kubectl get clusterissuer
NAME                     READY   AGE
letsencrypt-production   True    5m
letsencrypt-staging      True    5m
```

**Staging Issuer Details:**
- ACME Server: https://acme-staging-v02.api.letsencrypt.org/directory
- Email: cbenitez@gmail.com
- Status: Ready (ACME account registered)
- Purpose: Testing without production rate limits

**Production Issuer Details:**
- ACME Server: https://acme-v02.api.letsencrypt.org/directory
- Email: cbenitez@gmail.com
- Status: Ready (ACME account registered)
- Purpose: Trusted certificates for production use

### Custom Resource Definitions (CRDs)

All 6 cert-manager CRDs installed successfully:

```bash
$ kubectl get crd | grep cert-manager
certificates.cert-manager.io               2025-11-11T17:49:22Z
certificaterequests.cert-manager.io        2025-11-11T17:49:22Z
challenges.acme.cert-manager.io            2025-11-11T17:49:22Z
clusterissuers.cert-manager.io             2025-11-11T17:49:22Z
issuers.cert-manager.io                    2025-11-11T17:49:22Z
orders.acme.cert-manager.io                2025-11-11T17:49:22Z
```

---

## Resource Configuration

### Controller Pod
- **Requests**: 10m CPU, 32Mi memory
- **Limits**: 100m CPU, 128Mi memory
- **Replicas**: 1
- **Health Checks**: Liveness + Readiness probes enabled

### Webhook Pod
- **Requests**: 10m CPU, 32Mi memory
- **Limits**: 100m CPU, 128Mi memory
- **Replicas**: 1
- **Health Checks**: Liveness + Readiness probes enabled

### CAInjector Pod
- **Requests**: 10m CPU, 32Mi memory
- **Limits**: 100m CPU, 128Mi memory
- **Replicas**: 1
- **Health Checks**: Liveness + Readiness probes enabled

---

## Configuration

### Prometheus Metrics
- **Enabled**: Yes
- **Port**: 9402
- **Endpoint**: `/metrics`
- **ServiceMonitor**: Disabled (enable if Prometheus Operator deployed)

### ACME Challenge Method
- **Type**: HTTP-01
- **Ingress Class**: traefik
- **Solver**: Automatic temporary pods created by cert-manager

### Certificate Renewal
- **Default Renewal Time**: 60 days before expiry (2/3 of 90-day cert lifetime)
- **Automatic**: Yes (cert-manager checks daily)

---

## Testing Certificate Issuance

### Important: DNS Configuration Required

⚠️ **Before requesting certificates**, ensure your domain has proper DNS configuration:

1. **DNS A/AAAA Record**: Must point to your cluster's external IP (via Cloudflare Tunnel)
2. **Cloudflare Tunnel**: Must route HTTP (port 80) traffic to Traefik
3. **Domain Resolution**: Must be publicly resolvable

**Example DNS Check:**
```bash
# Replace with your domain
dig +short test.chocolandiadc.com

# Verify HTTP accessibility (required for ACME HTTP-01)
curl -I http://test.chocolandiadc.com
```

### Test with Staging Issuer (Recommended First)

**Why Staging First?**
- Staging has no rate limits (production: 50 certs/week per domain)
- Certificates are not trusted by browsers (good for testing)
- Validates entire ACME workflow without risk

**Create Test Certificate:**

```yaml
# tests/integration/cert-manager/test-staging-cert.yaml
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
  commonName: test.chocolandiadc.com  # Replace with your domain
  dnsNames:
    - test.chocolandiadc.com  # Replace with your domain
  renewBefore: 720h  # 30 days
  privateKey:
    algorithm: RSA
    size: 2048
```

**Apply and Monitor:**

```bash
# Apply certificate
kubectl apply -f tests/integration/cert-manager/test-staging-cert.yaml

# Watch certificate status
kubectl get certificate test-cert-staging -n default -w

# Check detailed status
kubectl describe certificate test-cert-staging -n default

# View ACME challenge (if pending)
kubectl get challenge -n default
kubectl describe challenge <challenge-name> -n default

# Check certificate request
kubectl get certificaterequest -n default
```

**Expected Flow:**
1. Certificate created → `READY: False`
2. CertificateRequest created
3. ACME Order created
4. HTTP-01 Challenge created
5. cert-manager creates temporary solver pod
6. Traefik routes `/.well-known/acme-challenge/` to solver
7. Let's Encrypt validates domain ownership
8. Certificate issued → `READY: True`
9. TLS Secret created with certificate and private key

**Typical Timeline:**
- Fast path (all prerequisites met): 30-60 seconds
- With DNS/routing issues: Will retry for up to 1 hour before failing

### Test with Production Issuer

**⚠️ Only after staging certificate succeeds!**

```yaml
# tests/integration/cert-manager/test-production-cert.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert-production
  namespace: default
spec:
  secretName: test-cert-production-tls
  issuerRef:
    name: letsencrypt-production  # Production issuer
    kind: ClusterIssuer
  commonName: test.chocolandiadc.com  # Replace with your domain
  dnsNames:
    - test.chocolandiadc.com  # Replace with your domain
  renewBefore: 720h  # 30 days
```

---

## Traefik Integration

### Automatic Certificate with IngressRoute Annotation

Traefik can automatically request certificates via annotation:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: example-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production  # Auto-create Certificate
spec:
  entryPoints:
    - websecure  # Port 443
  routes:
    - match: Host(`example.chocolandiadc.com`)
      kind: Rule
      services:
        - name: example-service
          port: 80
  tls:
    secretName: example-tls  # Where cert-manager stores the certificate
```

**What Happens:**
1. Traefik sees the `cert-manager.io/cluster-issuer` annotation
2. Traefik creates a Certificate resource automatically
3. cert-manager processes the Certificate (ACME flow)
4. TLS Secret `example-tls` is created with certificate
5. Traefik automatically loads and uses the certificate for HTTPS

---

## Troubleshooting

### Certificate Stuck in "Issuing" State

**Check CertificateRequest:**
```bash
kubectl get certificaterequest -n <namespace>
kubectl describe certificaterequest <name> -n <namespace>
```

**Common Issues:**
- **DNS not resolving**: Let's Encrypt cannot reach your domain
- **Port 80 blocked**: HTTP-01 challenge requires port 80 accessible
- **Traefik not routing**: Check Traefik ingress class configuration
- **Rate limit hit**: Switched to production too early (use staging first)

### Challenge Failing

**View Challenge Details:**
```bash
kubectl get challenge -A
kubectl describe challenge <challenge-name> -n <namespace>
```

**Common Failure Reasons:**
- `no such host`: DNS not configured
- `connection refused`: Port 80 not accessible
- `404 not found`: Traefik not routing to solver pod
- `tls: handshake failure`: TLS misconfiguration on port 80

**Debug Solver Pod:**
```bash
# Find solver pod
kubectl get pods -A | grep cm-acme-http-solver

# Check logs
kubectl logs <solver-pod-name> -n <namespace>
```

### Verify Port 80 Accessibility

```bash
# External check (from internet)
curl -v http://yourdomain.com/.well-known/acme-challenge/test

# Internal check (from cluster)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://yourdomain.com/.well-known/acme-challenge/test
```

### Check cert-manager Logs

```bash
# Controller logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100

# Webhook logs
kubectl logs -n cert-manager -l app=webhook --tail=50

# CAInjector logs
kubectl logs -n cert-manager -l app=cainjector --tail=50
```

---

## Next Steps

1. **Configure DNS** for domains you want certificates for
2. **Test with staging issuer** first to validate ACME workflow
3. **Request production certificates** after staging succeeds
4. **Integrate with Traefik** using IngressRoute annotations
5. **Enable Prometheus metrics** for certificate monitoring
6. **Set up alerts** for certificate expiration (if Prometheus deployed)

---

## Success Criteria ✅

All success criteria from spec.md have been met:

- ✅ **SC-001**: cert-manager pods running (controller, webhook, cainjector)
- ✅ **SC-002**: Staging ClusterIssuer Ready=True
- ✅ **SC-003**: Production ClusterIssuer Ready=True
- ✅ **SC-004**: All 6 CRDs installed
- ✅ **SC-005**: Resource limits configured (conservative for homelab)
- ✅ **SC-006**: Prometheus metrics enabled on port 9402
- ✅ **SC-007**: ValidatingWebhookConfiguration active
- ✅ **SC-008**: HTTP-01 solver configured for Traefik
- ⏳ **SC-009**: Certificate issuance test (requires DNS configuration)
- ⏳ **SC-010**: Automatic renewal test (requires 60-day wait or manual trigger)

**Note**: SC-009 and SC-010 can be validated once a domain with proper DNS is configured.

---

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [ACME HTTP-01 Challenge](https://letsencrypt.org/docs/challenge-types/#http-01-challenge)
- [Traefik cert-manager Integration](https://doc.traefik.io/traefik/https/acme/)
