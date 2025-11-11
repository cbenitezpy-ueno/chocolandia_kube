# Feature Specification: cert-manager for Automated SSL/TLS Certificate Management

**Feature Branch**: `006-cert-manager`
**Created**: 2025-11-11
**Status**: Draft
**Input**: User request: "cert-manager for automated SSL/TLS certificate management with Let's Encrypt"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy cert-manager (Priority: P1)

Deploy cert-manager in the K3s cluster to enable automated SSL/TLS certificate management.

**Why this priority**: Foundation for automated certificate management. All other certificate functionality depends on cert-manager being operational.

**Independent Test**: Can be fully tested by deploying cert-manager, verifying pods are running, and confirming CRDs (Certificate, ClusterIssuer, Issuer) are installed. Delivers immediate value by establishing certificate automation infrastructure.

**Acceptance Scenarios**:

1. **Given** K3s cluster is running, **When** cert-manager is deployed via OpenTofu, **Then** cert-manager pods (controller, webhook, cainjector) are running and healthy
2. **Given** cert-manager is deployed, **When** checking CRDs, **Then** Certificate, CertificateRequest, Issuer, ClusterIssuer, Challenge, Order CRDs are available
3. **Given** cert-manager is running, **When** checking webhook, **Then** ValidatingWebhookConfiguration and MutatingWebhookConfiguration are properly configured

---

### User Story 2 - Configure Let's Encrypt Staging Issuer (Priority: P1, MVP)

Create a ClusterIssuer for Let's Encrypt staging environment to test certificate issuance without rate limits.

**Why this priority**: MVP functionality - allows testing certificate automation without hitting Let's Encrypt production rate limits. Essential validation before production use.

**Independent Test**: Can be tested independently by creating staging ClusterIssuer, requesting a test certificate, and verifying the staging certificate is issued successfully.

**Acceptance Scenarios**:

1. **Given** cert-manager is running, **When** creating Let's Encrypt staging ClusterIssuer with ACME HTTP-01 challenge, **Then** ClusterIssuer is Ready
2. **Given** staging ClusterIssuer exists, **When** creating a Certificate resource for test domain, **Then** cert-manager initiates ACME challenge
3. **Given** ACME challenge is initiated, **When** HTTP-01 validation completes, **Then** staging certificate is issued and stored in Kubernetes Secret

---

### User Story 3 - Configure Let's Encrypt Production Issuer (Priority: P2)

Create a ClusterIssuer for Let's Encrypt production environment to issue trusted certificates.

**Why this priority**: Production-ready certificates for real services. Requires staging validation first to avoid rate limit issues.

**Independent Test**: Can be tested by creating production ClusterIssuer, requesting certificates for production services, and verifying trusted certificates are issued.

**Acceptance Scenarios**:

1. **Given** staging issuer is validated, **When** creating Let's Encrypt production ClusterIssuer, **Then** ClusterIssuer is Ready
2. **Given** production ClusterIssuer exists, **When** creating Certificate for production domain, **Then** trusted certificate is issued
3. **Given** production certificate is issued, **When** checking certificate validity, **Then** certificate is signed by Let's Encrypt and trusted by browsers

---

### User Story 4 - Integrate with Traefik Ingress (Priority: P2)

Configure Traefik IngressRoutes to automatically request and use certificates from cert-manager.

**Why this priority**: Enables automatic HTTPS for services exposed via Traefik. Completes the SSL/TLS automation workflow.

**Independent Test**: Can be tested by creating IngressRoute with cert-manager annotation, verifying certificate is automatically provisioned, and confirming HTTPS works.

**Acceptance Scenarios**:

1. **Given** cert-manager and Traefik are running, **When** creating IngressRoute with cert-manager.io/cluster-issuer annotation, **Then** Certificate resource is automatically created
2. **Given** Certificate is created, **When** ACME challenge completes, **Then** TLS secret is created and referenced by IngressRoute
3. **Given** IngressRoute uses TLS secret, **When** accessing service via HTTPS, **Then** browser shows valid certificate (production) or staging warning (staging)

---

### User Story 5 - Configure Certificate Renewal (Priority: P3)

Verify and monitor automatic certificate renewal before expiration.

**Why this priority**: Ensures certificates remain valid without manual intervention. Important for production stability but handled automatically by cert-manager.

**Independent Test**: Can be tested by checking renewal configuration, simulating certificate expiration, and verifying automatic renewal occurs.

**Acceptance Scenarios**:

1. **Given** certificates are issued, **When** checking Certificate resources, **Then** renewal time is configured (default: 30 days before expiry)
2. **Given** certificate is approaching expiry, **When** renewal time is reached, **Then** cert-manager automatically renews certificate
3. **Given** renewal succeeds, **When** checking TLS secret, **Then** new certificate is stored and services use updated certificate

---

### User Story 6 - Enable Prometheus Metrics (Priority: P3)

Configure cert-manager to export Prometheus metrics for monitoring certificate status and renewals.

**Why this priority**: Enhancement for observability. Allows monitoring certificate expiration, renewal failures, and ACME challenge issues.

**Independent Test**: Can be tested by enabling metrics, checking /metrics endpoint, and verifying certificate-related metrics are exposed.

**Acceptance Scenarios**:

1. **Given** cert-manager with metrics enabled, **When** accessing metrics endpoint, **Then** Prometheus-format metrics are returned
2. **Given** metrics are exposed, **When** certificates are issued/renewed, **Then** cert_manager_certificate_expiration_timestamp_seconds metric updates
3. **Given** Prometheus is deployed, **When** configured to scrape cert-manager, **Then** certificate metrics appear in Grafana dashboards

---

### Edge Cases

- What happens when Let's Encrypt API is unreachable or rate-limited?
- How does cert-manager handle DNS propagation delays for DNS-01 challenges?
- What happens when ACME HTTP-01 challenge fails due to network/firewall issues?
- How does renewal work when certificate is manually deleted from secret?
- What happens when multiple Certificate resources request same domain?
- How does cert-manager handle expired certificates that failed to renew?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy cert-manager using Helm chart via OpenTofu
- **FR-002**: System MUST install cert-manager CRDs (Certificate, Issuer, ClusterIssuer, etc.)
- **FR-003**: System MUST create ClusterIssuer for Let's Encrypt staging environment
- **FR-004**: System MUST create ClusterIssuer for Let's Encrypt production environment
- **FR-005**: System MUST support ACME HTTP-01 challenge for domain validation
- **FR-006**: System MUST automatically issue certificates when Certificate resources are created
- **FR-007**: System MUST store issued certificates in Kubernetes Secrets
- **FR-008**: System MUST automatically renew certificates before expiration (default: 30 days before)
- **FR-009**: System MUST support integration with Traefik via annotations (cert-manager.io/cluster-issuer)
- **FR-010**: System MUST configure resource limits (CPU/memory) for cert-manager pods
- **FR-011**: System MUST configure health checks (liveness/readiness probes) for cert-manager components
- **FR-012**: System MUST enable Prometheus metrics endpoint for monitoring
- **FR-013**: System MUST log certificate issuance, renewal, and errors for debugging
- **FR-014**: System MUST validate webhook configuration to prevent API conflicts

### Key Entities *(include if feature involves data)*

- **cert-manager Deployment**: Kubernetes Deployment running cert-manager controller, webhook, and cainjector pods
- **ClusterIssuer**: cert-manager CRD defining certificate authority (Let's Encrypt staging/production)
- **Certificate**: cert-manager CRD defining certificate request (domain, issuer, secret name)
- **CertificateRequest**: Internal CRD created by cert-manager during issuance process
- **Order**: ACME-specific CRD representing Let's Encrypt order
- **Challenge**: ACME-specific CRD representing HTTP-01 or DNS-01 challenge
- **TLS Secret**: Kubernetes Secret storing issued certificate and private key
- **ValidatingWebhookConfiguration**: Kubernetes webhook validating cert-manager resources
- **ServiceMonitor**: Prometheus operator CRD for metrics scraping (if Prometheus deployed)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: cert-manager pods achieve Running status within 60 seconds of deployment
- **SC-002**: Let's Encrypt staging certificate is issued successfully within 5 minutes of Certificate creation
- **SC-003**: Let's Encrypt production certificate is issued successfully and trusted by browsers
- **SC-004**: Traefik IngressRoute with cert-manager annotation automatically provisions certificate
- **SC-005**: Certificate renewal occurs automatically at least 30 days before expiration
- **SC-006**: Prometheus /metrics endpoint returns cert-manager metrics with 200 status code
- **SC-007**: All cert-manager CRDs are successfully installed and webhook validation works
- **SC-008**: ACME HTTP-01 challenge completes successfully for test domain
- **SC-009**: Certificate issuance logs are visible in cert-manager controller logs
- **SC-010**: Grafana dashboard displays certificate expiration metrics (if Prometheus deployed)
