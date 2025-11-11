# Research: cert-manager for SSL/TLS Certificate Management

**Feature**: 006-cert-manager
**Date**: 2025-11-11
**Status**: Complete

## Phase 0: Technical Research

This document captures all technical decisions, best practices, and alternatives considered for implementing automated SSL/TLS certificate management with cert-manager.

---

## Decision 1: Deployment Method - Helm Chart via OpenTofu

**Decision**: Deploy cert-manager using official Helm chart managed by OpenTofu `helm_release` resource.

**Rationale**:
- Official Helm chart is the recommended installation method by cert-manager project
- Helm chart handles CRD installation, webhook configuration, and RBAC setup automatically
- OpenTofu `helm_release` resource provides declarative Helm chart management with version control
- Aligns with project constitution: Infrastructure as Code (Principle I) and GitOps (Principle II)
- Simplifies upgrades and rollbacks via Helm's versioning
- Chart values can be customized via OpenTofu variables

**Alternatives Considered**:
1. **kubectl apply with static manifests**:
   - Rejected: Requires manual CRD management, harder to upgrade, no configuration templating
2. **OpenTofu kubernetes_manifest resources**:
   - Rejected: Too verbose for complex deployments, manual CRD ordering required, no built-in upgrade logic
3. **ArgoCD/FluxCD GitOps**:
   - Rejected: Adds complexity for homelab environment, requires additional tooling, OpenTofu Helm integration sufficient

**Implementation Details**:
- Helm chart: `jetstack/cert-manager` (official chart from cert-manager maintainers)
- Chart version: `v1.13.x` (latest stable as of Nov 2025, supports Kubernetes 1.25+)
- Repository: `https://charts.jetstack.io`
- OpenTofu resource: `helm_release.cert_manager`
- CRD installation: Enabled via `installCRDs: true` in chart values (default behavior)

---

## Decision 2: Certificate Authority - Let's Encrypt with Staging + Production Issuers

**Decision**: Use Let's Encrypt as the Certificate Authority with separate staging and production ClusterIssuers.

**Rationale**:
- Let's Encrypt provides free, automated, trusted SSL/TLS certificates
- Staging environment allows testing without hitting production rate limits (50 certificates/week per domain)
- ClusterIssuer (vs Issuer) allows certificate issuance across all namespaces
- ACME protocol automation eliminates manual certificate management
- Trusted by all major browsers and operating systems
- Aligns with constitution: Security Hardening (Principle V) and Test-Driven Learning (Principle VII)

**Alternatives Considered**:
1. **Self-signed certificates**:
   - Rejected: Not trusted by browsers, requires manual trust store configuration, no automation learning value
2. **Private CA (HashiCorp Vault, step-ca)**:
   - Rejected: Adds complexity, requires CA infrastructure management, certificates not publicly trusted
3. **Commercial CA (DigiCert, Sectigo)**:
   - Rejected: Costs involved, manual processes, no learning value for ACME automation
4. **ZeroSSL (alternative free ACME CA)**:
   - Considered but rejected: Less mature ecosystem, Let's Encrypt is industry standard for learning

**Implementation Details**:
- Staging ClusterIssuer: `letsencrypt-staging`
  - ACME server: `https://acme-staging-v02.api.letsencrypt.org/directory`
  - Rate limit: 30,000 registrations per IP/3hr, no certificate limit
  - Certificate trust: Fake LE intermediate (untrusted by browsers, good for testing)
- Production ClusterIssuer: `letsencrypt-production`
  - ACME server: `https://acme-v02.api.letsencrypt.org/directory`
  - Rate limit: 50 certificates/week per domain, 300 pending authorizations per account
  - Certificate trust: Trusted by all major browsers
- ACME account email: Configurable via OpenTofu variable (required for certificate expiry notifications)

---

## Decision 3: ACME Challenge Method - HTTP-01 for Homelab

**Decision**: Use ACME HTTP-01 challenge as the primary domain validation method.

**Rationale**:
- HTTP-01 works without DNS provider API credentials (simpler for homelab)
- Validation occurs via HTTP endpoint (`/.well-known/acme-challenge/`) served by cert-manager
- Traefik ingress controller automatically routes challenge requests to cert-manager solver pods
- No DNS propagation delays (faster certificate issuance)
- Works with any DNS provider (no API integration required)
- Aligns with constitution: simplicity over complexity (Governance principle)

**Alternatives Considered**:
1. **DNS-01 challenge**:
   - Rejected for initial implementation: Requires DNS provider API credentials, adds external dependency, more complex setup
   - Future enhancement: Consider for wildcard certificates (*.chocolandiadc.com)
2. **TLS-ALPN-01 challenge**:
   - Rejected: Not supported by many ingress controllers, more complex, limited use cases

**Implementation Details**:
- Challenge solver: HTTP-01 with Traefik ingress class
- Solver configuration in ClusterIssuer:
  ```yaml
  solvers:
  - http01:
      ingress:
        class: traefik
  ```
- Automatic solver pod creation: cert-manager creates temporary pods/services for each challenge
- Challenge path: `http://<domain>/.well-known/acme-challenge/<token>`
- Firewall requirement: Port 80 must be accessible from internet for Let's Encrypt validation servers

**Prerequisites**:
- Traefik ingress controller must be deployed (Feature 005 dependency)
- Domain must be publicly resolvable (DNS A/AAAA record pointing to homelab external IP)
- Cloudflare Tunnel must route port 80 traffic to Traefik (Feature 004 integration)

---

## Decision 4: Resource Configuration - Conservative Limits for Homelab

**Decision**: Configure conservative resource requests/limits for cert-manager components suitable for homelab environment.

**Rationale**:
- cert-manager has low resource usage in homelab (few certificates, infrequent renewals)
- Conservative limits prevent resource exhaustion on mini PCs
- Aligns with constitution: Security Hardening (Principle V - resource limits mandatory)
- Sufficient for typical homelab workload (10-50 certificates)

**Implementation Details**:
- **Controller pod**:
  - Requests: CPU 10m, Memory 32Mi
  - Limits: CPU 100m, Memory 128Mi
  - Purpose: Main controller managing certificate lifecycle
- **Webhook pod**:
  - Requests: CPU 10m, Memory 32Mi
  - Limits: CPU 100m, Memory 128Mi
  - Purpose: Admission webhook for validating/mutating cert-manager resources
- **CAInjector pod**:
  - Requests: CPU 10m, Memory 32Mi
  - Limits: CPU 100m, Memory 128Mi
  - Purpose: Injects CA bundles into ValidatingWebhookConfiguration and APIService resources
- Replicas: 1 per component (sufficient for homelab, not HA)

**Alternatives Considered**:
1. **Default Helm chart values (no limits)**:
   - Rejected: Violates constitution requirement for resource limits
2. **Higher limits (500m CPU, 512Mi memory)**:
   - Rejected: Wasteful for homelab workload, mini PC resources are limited
3. **Multiple replicas for HA**:
   - Rejected: Unnecessary for homelab learning environment, adds complexity

---

## Decision 5: Prometheus Metrics Integration

**Decision**: Enable Prometheus metrics endpoints for cert-manager components.

**Rationale**:
- Aligns with constitution: Observability & Monitoring (Principle IV - NON-NEGOTIABLE)
- Provides visibility into certificate expiration, renewal status, ACME challenge failures
- Enables alerting on certificate issues before they cause outages
- Metrics are lightweight and always-on (no performance impact)

**Implementation Details**:
- Metrics endpoint: `/metrics` on port 9402 for all components
- Helm chart configuration: `prometheus.enabled: true`
- ServiceMonitor: Optional (only if Prometheus Operator is deployed)
- Key metrics:
  - `certmanager_certificate_expiration_timestamp_seconds`: Certificate expiry time
  - `certmanager_certificate_ready_status`: Certificate readiness (0=not ready, 1=ready)
  - `certmanager_http_acme_client_request_count`: ACME API request count
  - `certmanager_http_acme_client_request_duration_seconds`: ACME API latency

**Alternatives Considered**:
1. **Disable metrics to save resources**:
   - Rejected: Violates constitution, metrics overhead is negligible
2. **Custom metrics exporter**:
   - Rejected: Unnecessary, built-in metrics are comprehensive

---

## Decision 6: Certificate Storage - Kubernetes Secrets

**Decision**: Store issued certificates and private keys in Kubernetes Secrets (default cert-manager behavior).

**Rationale**:
- Native Kubernetes secret management (encrypted at rest via etcd)
- Automatic secret mounting in pods via volume mounts
- No additional infrastructure required
- Aligns with constitution: Security Hardening (Principle V - use Kubernetes Secrets)
- Traefik and other ingress controllers natively consume TLS secrets

**Implementation Details**:
- Secret type: `kubernetes.io/tls` (standard TLS secret format)
- Secret contents:
  - `tls.crt`: PEM-encoded certificate (including intermediate chain)
  - `tls.key`: PEM-encoded private key (RSA 2048-bit by default)
- Secret namespace: Same as Certificate resource (typically ingress namespace or default)
- Secret name: Defined in Certificate spec (`spec.secretName`)

**Alternatives Considered**:
1. **HashiCorp Vault**:
   - Rejected: Over-engineering for homelab, adds external dependency, requires Vault deployment
2. **External Secrets Operator**:
   - Rejected: Unnecessary abstraction, Kubernetes Secrets sufficient for homelab
3. **File-based storage**:
   - Rejected: Not Kubernetes-native, manual distribution to pods, no encryption

---

## Decision 7: Certificate Renewal Strategy - Automatic Renewal at 2/3 Lifetime

**Decision**: Use cert-manager's default automatic renewal at 2/3 of certificate lifetime (60 days for 90-day Let's Encrypt certs).

**Rationale**:
- Provides 30-day buffer before expiration (sufficient for troubleshooting renewal failures)
- Automatic renewal eliminates manual intervention
- Renewal failures have time for retry before certificate expires
- Industry best practice (recommended by Let's Encrypt)
- Aligns with constitution: Test-Driven Learning (automatic renewal teaches automation)

**Implementation Details**:
- Renewal time: Configurable via `spec.renewBefore` in Certificate resource (default: 2h360h0m0s = 60 days)
- Renewal process:
  1. cert-manager checks certificate expiry daily
  2. When renewal time reached, creates new CertificateRequest
  3. Initiates ACME challenge with Let's Encrypt
  4. On success, updates Secret with new certificate
  5. Pods using Secret automatically get new certificate (via Kubernetes secret projection)
- Manual renewal: Possible via `cmctl renew` command for testing

**Alternatives Considered**:
1. **Aggressive renewal (30 days before expiry)**:
   - Rejected: Wastes Let's Encrypt resources, increases rate limit risk
2. **Late renewal (7 days before expiry)**:
   - Rejected: Insufficient buffer for troubleshooting, high risk of expiration
3. **Manual renewal**:
   - Rejected: Violates automation principles, error-prone

---

## Decision 8: Webhook Configuration - ValidatingWebhookConfiguration for Resource Validation

**Decision**: Deploy cert-manager webhook to validate Certificate, Issuer, and ClusterIssuer resources before creation.

**Rationale**:
- Prevents invalid configurations from being created (fail-fast principle)
- Validates ACME account email format, domain syntax, issuer references
- Catches configuration errors at apply time (not runtime)
- Required for production-grade cert-manager deployment
- Aligns with constitution: Test-Driven Learning (validation teaches correct configuration)

**Implementation Details**:
- Webhook service: `cert-manager-webhook.cert-manager.svc` (in-cluster service)
- Webhook port: 10250 (HTTPS)
- Webhook TLS: Self-signed certificate generated by cert-manager during installation
- ValidatingWebhookConfiguration rules:
  - `certificates.cert-manager.io`: Validates Certificate resources
  - `issuers.cert-manager.io`: Validates Issuer resources
  - `clusterissuers.cert-manager.io`: Validates ClusterIssuer resources
- Failure policy: `Fail` (reject invalid resources)

**Alternatives Considered**:
1. **Disable webhook to simplify deployment**:
   - Rejected: Increases risk of runtime errors, loses validation safety net
2. **Failure policy: Ignore**:
   - Rejected: Allows invalid resources to be created, defeats purpose of validation

---

## Known Issues & Mitigations

### Issue 1: Let's Encrypt Rate Limits

**Problem**: Production Let's Encrypt has rate limits (50 certs/week per domain).

**Mitigation**:
- Always test with staging issuer first
- Document rate limits in quickstart guide
- Monitor rate limit errors in cert-manager logs
- Use wildcard certificates for multiple subdomains (requires DNS-01, future enhancement)

### Issue 2: ACME HTTP-01 Challenge Requires Port 80

**Problem**: Let's Encrypt validation servers must reach port 80 on domain.

**Mitigation**:
- Ensure Cloudflare Tunnel routes port 80 to Traefik (Feature 004 dependency)
- Document port 80 requirement in quickstart
- Firewall rules must allow HTTP traffic (temporary for challenges)
- Consider HTTP-to-HTTPS redirect after certificate issuance

### Issue 3: Certificate Renewal Failures

**Problem**: Renewal can fail due to ACME API issues, network problems, or rate limits.

**Mitigation**:
- 30-day renewal buffer provides time for retries
- cert-manager automatically retries failed renewals with exponential backoff
- Prometheus alerts for certificate expiration (if monitoring deployed)
- Document manual renewal procedure using `cmctl renew`

### Issue 4: Webhook Startup Race Condition

**Problem**: Webhook may not be ready when CRDs are first created, causing temporary failures.

**Mitigation**:
- Helm chart handles this with proper resource ordering
- cert-manager controller waits for webhook readiness
- If encountered, retry resource creation after webhook is ready

---

## Best Practices from cert-manager Documentation

1. **Use staging issuer first**: Always validate with staging before production to avoid rate limits
2. **Configure prometheus metrics**: Essential for monitoring certificate health
3. **Set resource limits**: Prevents cert-manager from consuming excessive resources
4. **Use ClusterIssuer for multi-namespace**: Simplifies certificate management across namespaces
5. **Configure ACME account email**: Required for Let's Encrypt expiry notifications
6. **Test renewal process**: Manually trigger renewal to validate automation works
7. **Monitor certificate expiration**: Set alerts for certificates expiring in <30 days
8. **Use cert-manager kubectl plugin (cmctl)**: Useful for troubleshooting and manual operations

---

## Integration with Existing Features

### Feature 004: Cloudflare Zero Trust Tunnel

**Integration**: Cloudflare Tunnel must route HTTP (port 80) traffic to Traefik for ACME HTTP-01 challenges.

**Configuration**:
- Public hostname: `*.chocolandiadc.com` → Traefik LoadBalancer service
- Ensure HTTP (port 80) is not redirected to HTTPS until after certificate issuance
- Cloudflare Tunnel provides external connectivity for Let's Encrypt validation

### Feature 005: Traefik Ingress Controller

**Integration**: Traefik serves as the ingress controller for ACME HTTP-01 challenges and consumes TLS secrets.

**Configuration**:
- IngressRoute annotation: `cert-manager.io/cluster-issuer: letsencrypt-production`
- Traefik automatically creates Certificate resource when annotation is present
- TLS configuration in IngressRoute references secret created by cert-manager
- Traefik reloads certificates automatically when secrets are updated

---

## Dependencies

1. **K3s Cluster** (Feature 001/002): Kubernetes 1.25+ required for cert-manager v1.13
2. **Traefik Ingress** (Feature 005): Required for HTTP-01 challenge routing
3. **Cloudflare Tunnel** (Feature 004): Provides external connectivity for Let's Encrypt validation
4. **MetalLB** (Feature 002): Provides LoadBalancer IP for Traefik (indirect dependency)
5. **Prometheus** (Optional): For metrics collection and alerting on certificate issues

---

## Testing Strategy

### Unit Tests (OpenTofu)

- `tofu validate`: Syntax and resource validation
- `tofu plan`: Preview infrastructure changes
- `tofu fmt -check`: Code formatting verification

### Integration Tests

1. **cert-manager deployment**: Verify all pods running and healthy
2. **CRD installation**: Verify all cert-manager CRDs exist
3. **Webhook validation**: Test webhook rejects invalid Certificate resource
4. **Staging certificate**: Request certificate from staging issuer, verify issuance
5. **Production certificate**: Request certificate from production issuer, verify trusted
6. **Traefik integration**: Create IngressRoute with annotation, verify automatic certificate
7. **Certificate renewal**: Manually trigger renewal, verify new certificate issued
8. **Metrics endpoint**: Verify Prometheus metrics are exposed

### Failure Injection Tests

1. **ACME API unreachable**: Simulate network failure, verify retry behavior
2. **HTTP-01 challenge failure**: Block port 80, verify challenge fails gracefully
3. **Invalid domain**: Request certificate for non-existent domain, verify error handling
4. **Rate limit**: Simulate rate limit error, verify backoff and logging

---

## Documentation Requirements

1. **Quickstart guide**: Step-by-step deployment and certificate request
2. **Troubleshooting guide**: Common issues and solutions
3. **Runbook**: Operational procedures (manual renewal, issuer updates)
4. **Architecture diagram**: Visual representation of cert-manager components and flow
5. **ADR**: Decision record for Let's Encrypt + HTTP-01 choice

---

## Future Enhancements (Out of Scope)

1. **DNS-01 challenge**: For wildcard certificates (requires DNS provider API integration)
2. **Private CA**: For internal-only services not requiring public trust
3. **Certificate monitoring dashboard**: Grafana dashboard for certificate expiration visualization
4. **Automated alerting**: Prometheus alerts for certificate expiration and renewal failures
5. **Multi-CA support**: Additional issuers (ZeroSSL, BuyPass) for redundancy
6. **ACME External Account Binding**: For enterprise Let's Encrypt accounts

---

## Conclusion

All technical decisions are resolved and documented. The feature is ready for Phase 1 (data model and design) and Phase 2 (task generation).

**Key Decisions Summary**:
- Deployment: Helm chart via OpenTofu ✓
- CA: Let's Encrypt (staging + production) ✓
- Challenge: HTTP-01 via Traefik ✓
- Resources: Conservative limits for homelab ✓
- Metrics: Enabled for Prometheus ✓
- Storage: Kubernetes Secrets ✓
- Renewal: Automatic at 60 days (2/3 lifetime) ✓
- Webhook: Enabled for validation ✓

No NEEDS CLARIFICATION items remain. Proceeding to Phase 1.
