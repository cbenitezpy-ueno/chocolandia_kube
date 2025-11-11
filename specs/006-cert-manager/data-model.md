# Data Model: cert-manager Certificate Management

**Feature**: 006-cert-manager
**Date**: 2025-11-11

This document defines all entities, their attributes, relationships, and state transitions for the cert-manager certificate management system.

---

## Entity Diagram

```
┌─────────────────────────┐
│   ClusterIssuer         │
│  (letsencrypt-staging)  │
│  (letsencrypt-prod)     │
└───────────┬─────────────┘
            │
            │ references
            │
┌───────────▼─────────────┐         ┌─────────────────────────┐
│   Certificate           │────────>│   TLS Secret            │
│  (domain cert request)  │ creates │  (tls.crt + tls.key)    │
└───────────┬─────────────┘         └─────────────────────────┘
            │                                     │
            │ creates                             │ mounted by
            │                                     │
┌───────────▼─────────────┐                      │
│  CertificateRequest     │                      │
│  (internal workflow)    │                      │
└───────────┬─────────────┘                      │
            │                                     │
            │ creates                             │
            │                       ┌─────────────▼─────────────┐
┌───────────▼─────────────┐         │   Traefik IngressRoute   │
│   Order (ACME)          │         │  (uses TLS secret)       │
│  (Let's Encrypt order)  │         └───────────────────────────┘
└───────────┬─────────────┘
            │
            │ creates
            │
┌───────────▼─────────────┐
│   Challenge (HTTP-01)   │
│  (domain validation)    │
└───────────┬─────────────┘
            │
            │ creates
            │
┌───────────▼─────────────┐
│  Solver Pod/Service     │
│  (temp HTTP server)     │
└─────────────────────────┘
```

---

## Entity 1: cert-manager Deployment

**Description**: Kubernetes Deployment running cert-manager components (controller, webhook, cainjector).

**Attributes**:
- `namespace`: string - Kubernetes namespace (default: `cert-manager`)
- `controller_replicas`: integer - Number of controller replicas (default: 1)
- `webhook_replicas`: integer - Number of webhook replicas (default: 1)
- `cainjector_replicas`: integer - Number of cainjector replicas (default: 1)
- `image_version`: string - cert-manager version (e.g., `v1.13.3`)
- `controller_resources`: object - CPU/memory requests and limits for controller
  - `requests.cpu`: string (e.g., `10m`)
  - `requests.memory`: string (e.g., `32Mi`)
  - `limits.cpu`: string (e.g., `100m`)
  - `limits.memory`: string (e.g., `128Mi`)
- `webhook_resources`: object - CPU/memory requests and limits for webhook
- `cainjector_resources`: object - CPU/memory requests and limits for cainjector
- `metrics_enabled`: boolean - Prometheus metrics enabled (default: true)
- `metrics_port`: integer - Metrics endpoint port (default: 9402)

**State**:
- `Pending`: Deployment created, pods not yet running
- `Running`: All pods running and passing health checks
- `Degraded`: Some pods running, others failing
- `Failed`: All pods failing or crashing

**Relationships**:
- Creates: CRDs (Certificate, Issuer, ClusterIssuer, Challenge, Order, CertificateRequest)
- Manages: Certificate lifecycle (issuance, renewal)
- Validates: Certificate resources via ValidatingWebhookConfiguration

**Validation Rules**:
- At least 1 replica per component
- Resource limits must be defined (constitution requirement)
- Image version must be v1.11+ (Kubernetes 1.25+ compatibility)

---

## Entity 2: ClusterIssuer

**Description**: cert-manager CRD defining a certificate authority that can issue certificates cluster-wide (across all namespaces).

**Attributes**:
- `name`: string - Issuer name (e.g., `letsencrypt-staging`, `letsencrypt-production`)
- `acme_server`: string - ACME directory URL
  - Staging: `https://acme-staging-v02.api.letsencrypt.org/directory`
  - Production: `https://acme-v02.api.letsencrypt.org/directory`
- `acme_email`: string - Account email for Let's Encrypt notifications (required)
- `private_key_secret`: string - Secret storing ACME account private key
- `solvers`: array - ACME challenge solvers configuration
  - `http01.ingress.class`: string - Ingress class for HTTP-01 challenges (e.g., `traefik`)
- `preferred_chain`: string (optional) - Preferred certificate chain (e.g., ISRG Root X1)

**State**:
- `Pending`: ClusterIssuer created, not yet registered with ACME server
- `Ready`: ACME account registered, ready to issue certificates
- `Error`: ACME registration failed (invalid email, network error, API error)

**Relationships**:
- Referenced by: Certificate resources (`spec.issuerRef.name`)
- Creates: ACME account on Let's Encrypt
- Stores: ACME account private key in Kubernetes Secret

**Validation Rules**:
- ACME email must be valid email format
- ACME server URL must be HTTPS
- At least one solver must be defined
- HTTP-01 solver requires ingress class

**State Transitions**:
```
Pending → Ready: ACME account registration succeeds
Pending → Error: ACME registration fails (invalid config, network error)
Error → Ready: Configuration corrected, registration retried
Ready → Error: ACME account key lost or invalidated
```

---

## Entity 3: Certificate

**Description**: cert-manager CRD defining a certificate request for one or more domains.

**Attributes**:
- `name`: string - Certificate resource name
- `namespace`: string - Kubernetes namespace
- `secret_name`: string - Name of Secret to store issued certificate
- `issuer_ref`: object - Reference to ClusterIssuer or Issuer
  - `name`: string - Issuer name (e.g., `letsencrypt-production`)
  - `kind`: string - Issuer or ClusterIssuer (default: Issuer)
- `common_name`: string - Primary domain (CN in certificate)
- `dns_names`: array of strings - Subject Alternative Names (SANs)
- `duration`: string - Certificate validity period (default: `2160h` = 90 days for Let's Encrypt)
- `renew_before`: string - Renewal time before expiry (default: `720h` = 30 days)
- `usages`: array of strings - Key usages (default: `["digital signature", "key encipherment"]`)
- `private_key`: object - Private key configuration
  - `algorithm`: string - RSA or ECDSA (default: RSA)
  - `size`: integer - Key size in bits (default: 2048 for RSA)

**Status** (observed state):
- `conditions`: array - Certificate status conditions
  - `Ready`: boolean - Certificate is valid and ready
  - `Issuing`: boolean - Certificate issuance in progress
- `not_before`: timestamp - Certificate validity start time
- `not_after`: timestamp - Certificate expiry time
- `renewal_time`: timestamp - When renewal will be attempted

**State**:
- `Pending`: Certificate created, issuance not started
- `Issuing`: CertificateRequest created, ACME challenge in progress
- `Ready`: Certificate issued successfully, stored in Secret
- `Error`: Issuance failed (ACME challenge failed, rate limit, validation error)
- `Expired`: Certificate expired, renewal failed

**Relationships**:
- References: ClusterIssuer (via `issuerRef`)
- Creates: CertificateRequest (internal workflow resource)
- Creates: TLS Secret (stores issued certificate)
- Referenced by: Traefik IngressRoute (via TLS secret name)

**Validation Rules**:
- At least one DNS name or common name required
- All DNS names must be valid domain format
- IssuerRef must reference existing ClusterIssuer or Issuer
- SecretName must be valid Kubernetes resource name
- RenewBefore must be less than Duration

**State Transitions**:
```
Pending → Issuing: cert-manager creates CertificateRequest
Issuing → Ready: ACME challenge succeeds, certificate stored in Secret
Issuing → Error: ACME challenge fails (HTTP-01 unreachable, rate limit, validation error)
Ready → Issuing: Renewal time reached, new CertificateRequest created
Ready → Expired: Certificate expired, renewal failed
Error → Issuing: User corrects configuration, cert-manager retries
Expired → Issuing: Manual renewal triggered via `cmctl renew`
```

---

## Entity 4: CertificateRequest

**Description**: Internal cert-manager CRD representing a single certificate issuance or renewal attempt. Automatically created by Certificate controller.

**Attributes**:
- `name`: string - Auto-generated name (e.g., `mycert-abcde-12345`)
- `namespace`: string - Same as parent Certificate
- `issuer_ref`: object - Reference to ClusterIssuer (copied from Certificate)
- `request`: string - Base64-encoded PKCS#10 Certificate Signing Request (CSR)
- `usages`: array - Key usages (copied from Certificate)
- `duration`: string - Requested certificate duration

**Status**:
- `conditions`: array - Request status
  - `Ready`: boolean - Certificate issued
  - `Approved`: boolean - Request approved by approver
  - `Denied`: boolean - Request denied
- `certificate`: string - Base64-encoded issued certificate (PEM format)
- `ca`: string - Base64-encoded CA certificate chain
- `failure_time`: timestamp - When issuance failed

**State**:
- `Pending`: CertificateRequest created, waiting for approval
- `Approved`: Request approved, sent to issuer (ClusterIssuer)
- `Issued`: Certificate issued by ACME CA, ready to store in Secret
- `Failed`: Issuance failed (ACME error, rate limit, validation failure)
- `Denied`: Request denied (webhook validation failure, policy violation)

**Relationships**:
- Created by: Certificate controller
- References: ClusterIssuer (via `issuerRef`)
- Creates: Order (ACME-specific resource)

**State Transitions**:
```
Pending → Approved: Auto-approved by cert-manager (default approver)
Approved → Issued: ACME CA issues certificate
Approved → Failed: ACME challenge fails or issuer error
Pending → Denied: Webhook validation rejects request
```

---

## Entity 5: Order

**Description**: ACME-specific cert-manager CRD representing a Let's Encrypt certificate order. Automatically created when using ACME issuer.

**Attributes**:
- `name`: string - Auto-generated name
- `namespace`: string - Same as CertificateRequest
- `issuer_ref`: object - Reference to ClusterIssuer
- `request`: string - Base64-encoded CSR (copied from CertificateRequest)
- `dns_names`: array - Domains to validate
- `url`: string - ACME order URL on Let's Encrypt server

**Status**:
- `state`: string - ACME order state (pending, ready, valid, invalid, processing)
- `finalize_url`: string - URL to finalize order after challenges complete
- `certificate_url`: string - URL to download issued certificate
- `authorizations`: array - List of authorization URLs (one per domain)

**State**:
- `Pending`: Order created, challenges not yet issued
- `Processing`: Challenges issued, waiting for validation
- `Valid`: All challenges passed, order ready to finalize
- `Invalid`: One or more challenges failed
- `Expired`: Order expired before completion (Let's Encrypt timeout)

**Relationships**:
- Created by: CertificateRequest controller (ACME issuer only)
- Creates: Challenge resources (one per domain)
- Interacts with: Let's Encrypt ACME API

**State Transitions**:
```
Pending → Processing: Challenges created, domain validation in progress
Processing → Valid: All challenges passed
Processing → Invalid: Any challenge fails
Valid → Order finalized: CSR sent to Let's Encrypt, certificate issued
```

---

## Entity 6: Challenge

**Description**: cert-manager CRD representing a single ACME domain validation challenge (HTTP-01, DNS-01, or TLS-ALPN-01).

**Attributes**:
- `name`: string - Auto-generated name
- `namespace`: string - Same as Order
- `type`: string - Challenge type (http-01, dns-01, tls-alpn-01)
- `url`: string - ACME challenge URL on Let's Encrypt server
- `token`: string - ACME challenge token (random string)
- `key`: string - ACME challenge key (for validation)
- `dns_name`: string - Domain being validated
- `issuer_ref`: object - Reference to ClusterIssuer
- `solver`: object - Solver configuration (copied from ClusterIssuer)

**Status**:
- `state`: string - Challenge state (pending, processing, valid, invalid, expired)
- `reason`: string - Failure reason if invalid (e.g., "Connection refused", "Incorrect token")
- `presented`: boolean - Challenge presented (solver pod/service created)

**State** (HTTP-01 specific):
- `Pending`: Challenge created, solver not yet deployed
- `Presented`: Solver pod/service created, challenge endpoint reachable
- `Processing`: Let's Encrypt validation in progress
- `Valid`: Validation succeeded
- `Invalid`: Validation failed (endpoint unreachable, incorrect token, timeout)

**Relationships**:
- Created by: Order controller
- Creates: Solver Pod and Service (for HTTP-01 challenges)
- Validates with: Let's Encrypt validation servers

**Validation Rules**:
- DNS name must be valid domain format
- Token and key must match ACME specification
- Solver configuration must match ClusterIssuer

**State Transitions** (HTTP-01):
```
Pending → Presented: Solver pod/service created, challenge endpoint available
Presented → Processing: cert-manager notifies Let's Encrypt to validate
Processing → Valid: Let's Encrypt validation succeeds (token match)
Processing → Invalid: Validation fails (unreachable, token mismatch, timeout)
Valid → Challenge deleted: Challenge no longer needed after order completes
```

---

## Entity 7: Solver Pod/Service (HTTP-01)

**Description**: Temporary Kubernetes Pod and Service created by cert-manager to serve ACME HTTP-01 challenge responses.

**Pod Attributes**:
- `name`: string - Auto-generated name (e.g., `cm-acme-http-solver-xyz`)
- `namespace`: string - Same as Challenge
- `image`: string - cert-manager ACME solver image (e.g., `quay.io/jetstack/cert-manager-acme-http01-solver:v1.13.3`)
- `port`: integer - HTTP port (default: 8089)
- `command`: array - Serves challenge token at `/.well-known/acme-challenge/<token>`
- `labels`: object
  - `acme.cert-manager.io/http01-solver: "true"`
  - `acme.cert-manager.io/token: "<token>"`

**Service Attributes**:
- `name`: string - Same as pod name
- `namespace`: string - Same as pod
- `type`: string - ClusterIP (internal service)
- `port`: integer - 8089
- `selector`: object - Matches solver pod labels

**State**:
- `Creating`: Pod/service created, not yet running
- `Running`: Pod running, challenge endpoint reachable
- `Succeeded`: Challenge validated, pod/service no longer needed
- `Deleting`: Challenge complete, resources being cleaned up

**Relationships**:
- Created by: Challenge controller (HTTP-01 only)
- Routed by: Traefik Ingress (temporary Ingress created for challenge path)
- Accessed by: Let's Encrypt validation servers

**Lifecycle**:
1. Challenge controller creates Pod and Service
2. Traefik creates temporary Ingress for `/.well-known/acme-challenge/<token>`
3. Let's Encrypt validation server accesses endpoint
4. On validation success/failure, Challenge controller deletes Pod, Service, and Ingress

---

## Entity 8: TLS Secret

**Description**: Kubernetes Secret storing issued SSL/TLS certificate and private key.

**Attributes**:
- `name`: string - Secret name (defined in Certificate `spec.secretName`)
- `namespace`: string - Same as Certificate
- `type`: string - `kubernetes.io/tls` (standard TLS secret type)
- `data`: object - Base64-encoded secret data
  - `tls.crt`: string - PEM-encoded certificate (includes intermediate chain)
  - `tls.key`: string - PEM-encoded private key (RSA 2048-bit)
  - `ca.crt`: string (optional) - PEM-encoded CA certificate chain
- `annotations`: object
  - `cert-manager.io/certificate-name`: string - Name of Certificate that created this secret
  - `cert-manager.io/issuer-name`: string - Name of issuer
  - `cert-manager.io/common-name`: string - Certificate CN
  - `cert-manager.io/alt-names`: string - Certificate SANs (comma-separated)

**State**:
- `Pending`: Secret created, certificate not yet stored
- `Ready`: Valid certificate stored
- `Expired`: Certificate in secret is expired
- `Renewing`: Certificate is being renewed, secret will be updated

**Relationships**:
- Created by: Certificate controller (after successful issuance)
- Updated by: Certificate controller (during renewal)
- Consumed by: Traefik IngressRoute (mounted as TLS configuration)
- Consumed by: Pods (via volume mount or environment variables)

**Validation Rules**:
- Must contain both `tls.crt` and `tls.key`
- Certificate and key must be valid PEM format
- Certificate and key must be cryptographically paired
- Certificate must not be expired

**Lifecycle**:
1. Certificate controller creates empty Secret (or uses existing)
2. After successful issuance, controller populates `tls.crt` and `tls.key`
3. During renewal, controller updates secret with new certificate (atomic operation)
4. Old certificate remains valid during renewal (no downtime)
5. Pods/services automatically use new certificate after secret update (via Kubernetes secret projection)

---

## Entity 9: ValidatingWebhookConfiguration

**Description**: Kubernetes webhook configuration that validates cert-manager resources (Certificate, Issuer, ClusterIssuer) before they are created or updated.

**Attributes**:
- `name`: string - `cert-manager-webhook` (created by Helm chart)
- `webhooks`: array - Webhook rules
  - `name`: string - Validation rule name
  - `rules`: array - API resources to validate (e.g., `certificates.cert-manager.io`)
  - `clientConfig.service`: object - Webhook service reference
    - `name`: `cert-manager-webhook`
    - `namespace`: `cert-manager`
    - `path`: `/validate`
    - `port`: 10250
  - `failurePolicy`: string - `Fail` (reject invalid resources)
  - `sideEffects`: string - `None`
  - `admissionReviewVersions`: array - `["v1"]`

**State**:
- `Pending`: Webhook configuration created, webhook service not ready
- `Ready`: Webhook service ready, validation active
- `Error`: Webhook service unreachable, validation failing

**Relationships**:
- Points to: cert-manager-webhook Service (in-cluster)
- Validates: Certificate, Issuer, ClusterIssuer, CertificateRequest resources
- Uses: Self-signed TLS certificate (generated by cert-manager)

**Validation Performed**:
- ACME email format (must be valid email)
- DNS names format (must be valid domains)
- IssuerRef exists (referenced issuer must exist)
- Secret name valid (must be valid Kubernetes name)
- Solver configuration valid (ingress class exists, DNS provider configured)

---

## Entity 10: ServiceMonitor (Optional - Prometheus Integration)

**Description**: Prometheus Operator CRD that configures Prometheus to scrape cert-manager metrics.

**Attributes**:
- `name`: string - `cert-manager` (or custom name)
- `namespace`: string - `cert-manager` (or monitoring namespace)
- `selector`: object - Matches cert-manager service labels
  - `app.kubernetes.io/name: cert-manager`
- `endpoints`: array - Metrics endpoints
  - `port`: string - `tcp-prometheus-servicemonitor` (port 9402)
  - `path`: string - `/metrics`
  - `interval`: string - Scrape interval (e.g., `60s`)

**State**:
- `Pending`: ServiceMonitor created, Prometheus not yet scraping
- `Active`: Prometheus scraping metrics successfully
- `Error`: Prometheus cannot reach metrics endpoint

**Relationships**:
- Selects: cert-manager Service (metrics port 9402)
- Consumed by: Prometheus Operator
- Enables: Grafana dashboards for certificate monitoring

**Key Metrics Exposed**:
- `certmanager_certificate_expiration_timestamp_seconds`: Certificate expiry timestamp (Unix epoch)
- `certmanager_certificate_ready_status`: Certificate readiness (0=not ready, 1=ready)
- `certmanager_http_acme_client_request_count`: ACME API request count (by method, path, status)
- `certmanager_http_acme_client_request_duration_seconds`: ACME API latency histogram
- `certmanager_controller_sync_call_count`: Controller reconciliation loop count

---

## Data Flow: Certificate Issuance (Happy Path)

```
1. User creates Certificate resource
   ↓
2. cert-manager controller detects Certificate
   ↓
3. Controller creates CertificateRequest
   ↓
4. CertificateRequest controller creates Order (ACME)
   ↓
5. Order controller creates Challenge (HTTP-01)
   ↓
6. Challenge controller creates Solver Pod/Service
   ↓
7. Challenge controller creates temporary Ingress (Traefik)
   ↓
8. Let's Encrypt validation server accesses challenge endpoint
   ↓
9. Challenge validates successfully → Order becomes Valid
   ↓
10. Order controller finalizes order (sends CSR to Let's Encrypt)
    ↓
11. Let's Encrypt issues certificate
    ↓
12. Order controller stores certificate in CertificateRequest
    ↓
13. Certificate controller creates/updates TLS Secret
    ↓
14. Certificate status → Ready
    ↓
15. Challenge controller deletes Solver Pod/Service/Ingress
    ↓
16. Traefik IngressRoute uses TLS Secret for HTTPS
```

---

## Data Flow: Certificate Renewal

```
1. cert-manager controller checks Certificate expiry daily
   ↓
2. When renewBefore time reached (30 days before expiry)
   ↓
3. Controller creates new CertificateRequest
   ↓
4. [Same flow as initial issuance: Order → Challenge → Solver]
   ↓
5. New certificate issued by Let's Encrypt
   ↓
6. Certificate controller updates TLS Secret (atomic operation)
   ↓
7. Pods using Secret automatically get new certificate
   ↓
8. Old certificate remains valid until expiry (no downtime)
```

---

## Error Handling

### ACME Challenge Failure

**Scenario**: Let's Encrypt cannot reach HTTP-01 challenge endpoint.

**State Transitions**:
- Challenge: `Presented` → `Invalid`
- Order: `Processing` → `Invalid`
- CertificateRequest: `Approved` → `Failed`
- Certificate: `Issuing` → `Error`

**Recovery**:
- cert-manager automatically retries with exponential backoff
- User investigates: check firewall, Traefik routing, Cloudflare Tunnel
- After fix, cert-manager retries automatically
- Or manual retry: `kubectl delete certificaterequest <name>` triggers new attempt

### Rate Limit Exceeded

**Scenario**: Let's Encrypt production rate limit hit (50 certs/week per domain).

**State Transitions**:
- Order: `Processing` → `Invalid`
- CertificateRequest: `Approved` → `Failed`
- Certificate: `Issuing` → `Error`

**Recovery**:
- Wait for rate limit window to reset (1 week)
- Or switch to staging issuer for testing
- Or use wildcard certificate (requires DNS-01, future enhancement)

### Certificate Expiration

**Scenario**: Certificate expired because renewal failed repeatedly.

**State Transitions**:
- Certificate: `Ready` → `Expired`
- TLS Secret: Still contains expired certificate

**Recovery**:
- Fix underlying issue (network, firewall, rate limit)
- Manual renewal: `cmctl renew <certificate-name>`
- Or delete Certificate and recreate

---

## Conclusion

This data model defines all entities, their attributes, relationships, and state transitions for cert-manager certificate management. The model aligns with cert-manager architecture and Kubernetes best practices.

**Key Design Principles**:
1. **Declarative**: User defines desired state (Certificate), cert-manager reconciles to that state
2. **Automated**: Issuance and renewal happen automatically without user intervention
3. **Observable**: Metrics and logs provide visibility into certificate lifecycle
4. **Resilient**: Automatic retries with backoff on failures
5. **Kubernetes-native**: Uses standard Kubernetes resources (Secrets, CRDs, webhooks)
