# Feature Specification: Traefik Ingress Controller

**Feature Branch**: `005-traefik`
**Created**: 2025-11-10
**Status**: Draft
**Input**: User request: "vamos con Traefik"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Traefik Ingress Controller (Priority: P1)

Deploy Traefik as the primary ingress controller in the K3s cluster to enable HTTP/HTTPS routing to cluster services.

**Why this priority**: Core infrastructure component needed before any web services can be properly exposed. All future features depend on having a working ingress controller.

**Independent Test**: Can be fully tested by deploying Traefik, verifying pods are running, and confirming the ingress controller is ready to accept Ingress resources. Delivers immediate value by establishing the routing foundation.

**Acceptance Scenarios**:

1. **Given** K3s cluster is running, **When** Traefik Helm chart is deployed via OpenTofu, **Then** Traefik pods are running and healthy
2. **Given** Traefik is deployed, **When** checking service endpoints, **Then** Traefik LoadBalancer service has external IP assigned by MetalLB
3. **Given** Traefik is running, **When** checking CRDs, **Then** IngressRoute, Middleware, and TLSOption CRDs are available

---

### User Story 2 - Configure Basic HTTP Routing (Priority: P1, MVP)

Create a test HTTP service with Ingress to validate basic routing functionality.

**Why this priority**: MVP functionality - proves that Traefik can route HTTP traffic to backend services. Essential validation before production use.

**Independent Test**: Can be tested independently by deploying a simple whoami service, creating an IngressRoute, and confirming HTTP requests reach the service.

**Acceptance Scenarios**:

1. **Given** Traefik is running and test service deployed, **When** creating IngressRoute with host rule, **Then** HTTP requests to that host are routed to the service
2. **Given** IngressRoute is configured, **When** sending curl request to service hostname, **Then** service responds with correct content
3. **Given** multiple services with different hostnames, **When** routing requests, **Then** each hostname routes to its correct service

---

### User Story 3 - Enable Dashboard Access (Priority: P2)

Enable and expose Traefik's web dashboard for monitoring routing rules and traffic.

**Why this priority**: Important for visibility and debugging, but not required for basic functionality. Enhances operational capabilities.

**Independent Test**: Can be tested by enabling dashboard via Helm values, creating IngressRoute for dashboard, and accessing web UI. Validates that Traefik's monitoring capabilities are accessible.

**Acceptance Scenarios**:

1. **Given** Traefik is deployed with dashboard enabled, **When** accessing dashboard URL, **Then** web UI loads showing routers and services
2. **Given** dashboard is accessible, **When** IngressRoutes exist, **Then** dashboard displays all configured routes
3. **Given** traffic is flowing, **When** viewing dashboard, **Then** request metrics and health status are visible

---

### User Story 4 - Configure SSL/TLS Termination (Priority: P2)

Configure Traefik to handle SSL/TLS termination for HTTPS traffic (preparation for cert-manager integration).

**Why this priority**: Important for production readiness but can initially use self-signed certs. Sets foundation for cert-manager (Feature 006).

**Independent Test**: Can be tested by configuring TLS with self-signed certificates, creating HTTPS IngressRoute, and confirming SSL termination works.

**Acceptance Scenarios**:

1. **Given** Traefik with TLS configuration, **When** creating IngressRoute with TLS enabled, **Then** HTTPS requests are accepted (with self-signed cert warning)
2. **Given** TLS is configured, **When** checking certificate, **Then** Traefik presents the configured certificate
3. **Given** both HTTP and HTTPS configured, **When** sending requests, **Then** both protocols route correctly to services

---

### User Story 5 - Integrate Prometheus Metrics (Priority: P3)

Configure Traefik to export Prometheus metrics for monitoring integration.

**Why this priority**: Enhancement for observability. Requires existing Prometheus stack (future feature). Nice-to-have for complete monitoring.

**Independent Test**: Can be tested by enabling metrics endpoint, verifying /metrics endpoint responds, and validating metric format is Prometheus-compatible.

**Acceptance Scenarios**:

1. **Given** Traefik with metrics enabled, **When** accessing /metrics endpoint, **Then** Prometheus-format metrics are returned
2. **Given** metrics are exposed, **When** traffic flows through Traefik, **Then** request counters and latency histograms update
3. **Given** Prometheus is deployed (future), **When** configured to scrape Traefik, **Then** metrics appear in Prometheus

---

### Edge Cases

- What happens when MetalLB pool is exhausted and LoadBalancer service cannot get IP?
- How does Traefik handle requests to undefined hostnames (default backend)?
- What happens when backend service is unavailable (502/503 behavior)?
- How does Traefik handle very long request headers or malformed HTTP requests?
- What happens during Traefik pod restart (connection draining, graceful shutdown)?
- How does routing work when multiple IngressRoutes match the same hostname?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy Traefik ingress controller using Helm chart via OpenTofu
- **FR-002**: System MUST configure Traefik to use MetalLB LoadBalancer for external access
- **FR-003**: System MUST support HTTP (port 80) and HTTPS (port 443) ingress traffic
- **FR-004**: System MUST support Traefik IngressRoute CRDs for routing configuration
- **FR-005**: System MUST enable Traefik dashboard for operational visibility
- **FR-006**: System MUST configure resource limits (CPU/memory) for Traefik pods
- **FR-007**: System MUST configure health checks (liveness/readiness probes) for Traefik
- **FR-008**: System MUST enable Prometheus metrics endpoint for monitoring integration
- **FR-009**: System MUST support TLS termination with configurable certificates
- **FR-010**: System MUST log access logs and error logs for debugging
- **FR-011**: System MUST support HTTP to HTTPS redirect middleware
- **FR-012**: System MUST persist Traefik configuration via Kubernetes resources (no file-based config)

### Key Entities *(include if feature involves data)*

- **Traefik Deployment**: Kubernetes Deployment running Traefik ingress controller pods (2+ replicas for HA)
- **Traefik Service**: LoadBalancer service exposing Traefik on ports 80/443
- **IngressRoute**: Traefik CRD defining routing rules (hostname, path, backend service)
- **Middleware**: Traefik CRD for request/response transformations (redirects, headers, auth)
- **TLSOption**: Traefik CRD for TLS configuration (cipher suites, protocols)
- **Certificate Secret**: Kubernetes Secret storing TLS certificates (self-signed initially, Let's Encrypt later)
- **Dashboard IngressRoute**: IngressRoute exposing Traefik dashboard web UI
- **ServiceMonitor**: Prometheus operator CRD for metrics scraping (if Prometheus deployed)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Traefik pods achieve Running status within 60 seconds of deployment
- **SC-002**: HTTP requests to test service via IngressRoute complete successfully (<100ms p95 latency)
- **SC-003**: HTTPS requests with self-signed cert complete successfully (ignoring cert validation)
- **SC-004**: Traefik dashboard is accessible via web browser and displays routing configuration
- **SC-005**: Traefik survives single pod failure without request interruption (HA validation)
- **SC-006**: Prometheus /metrics endpoint returns valid metrics with 200 status code
- **SC-007**: Traefik handles 100 concurrent requests without errors or degradation
- **SC-008**: All Traefik CRDs (IngressRoute, Middleware, TLSOption) are successfully installed and usable
