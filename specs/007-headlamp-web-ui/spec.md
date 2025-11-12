# Feature Specification: Headlamp Web UI for K3s Cluster Management

**Feature Branch**: `007-headlamp-web-ui`
**Created**: 2025-11-12
**Status**: Draft
**Input**: User request: "Desplegar Headlamp completo con OpenTofu (Traefik + cert-manager + Cloudflare Access)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Headlamp with Helm via OpenTofu (Priority: P1)

Deploy Headlamp Kubernetes dashboard in the K3s cluster using Helm chart managed through OpenTofu, providing a web-based UI for cluster management.

**Why this priority**: Foundation for cluster visibility. Without Headlamp deployed, users cannot access the web UI. This is the core functionality that all other features depend on.

**Independent Test**: Can be fully tested by deploying Headlamp via OpenTofu, verifying pods are running, and accessing the ClusterIP service internally. Delivers immediate value by providing a web UI for cluster inspection.

**Acceptance Scenarios**:

1. **Given** K3s cluster is running and OpenTofu is configured, **When** deploying Headlamp module via `tofu apply`, **Then** Headlamp deployment is created with 1 replica and pod reaches Running status
2. **Given** Headlamp is deployed, **When** checking the service, **Then** ClusterIP service is created on port 80 exposing the web UI
3. **Given** Headlamp pod is running, **When** checking resource consumption, **Then** pod uses less than 128Mi memory and 200m CPU
4. **Given** Headlamp is deployed, **When** port-forwarding to the service, **Then** web UI is accessible at http://localhost:port and shows cluster overview

---

### User Story 2 - Configure RBAC for Read-Only Access (Priority: P1, MVP)

Create a ServiceAccount with read-only ClusterRole binding to provide secure, non-destructive access to cluster resources via Headlamp.

**Why this priority**: MVP security requirement. Without proper RBAC, Headlamp would have excessive permissions or no access at all. Read-only access is safe for learning and troubleshooting while preventing accidental changes.

**Independent Test**: Can be tested by creating the ServiceAccount, generating a token, and verifying that Headlamp can view resources but cannot modify or delete them. Delivers value by enabling safe cluster exploration.

**Acceptance Scenarios**:

1. **Given** Headlamp is deployed, **When** creating a ServiceAccount with ClusterRole "view", **Then** ServiceAccount and ClusterRoleBinding are created successfully
2. **Given** ServiceAccount exists, **When** generating a bearer token, **Then** token is created and can be used to authenticate to Headlamp
3. **Given** Headlamp is authenticated with read-only token, **When** attempting to view pods, services, and deployments, **Then** all resources are visible in the UI
4. **Given** Headlamp has read-only access, **When** attempting to delete a pod or modify a deployment, **Then** operation is denied with permission error

---

### User Story 3 - Expose Headlamp via Traefik with HTTPS (Priority: P2)

Create a Traefik IngressRoute to expose Headlamp externally with automatic HTTPS certificate from cert-manager, enabling secure remote access.

**Why this priority**: Enables remote access to cluster management UI. Once Headlamp is deployed and secured with RBAC, exposing it securely allows users to manage the cluster from any location.

**Independent Test**: Can be tested by creating IngressRoute, verifying DNS resolution, and accessing Headlamp via HTTPS URL. Delivers value by enabling remote cluster management without port-forwarding or VPN.

**Acceptance Scenarios**:

1. **Given** Headlamp service exists and Traefik is deployed, **When** creating IngressRoute with TLS configuration, **Then** IngressRoute is created and references Headlamp service
2. **Given** IngressRoute has cert-manager annotation, **When** cert-manager processes the request, **Then** TLS certificate is issued and stored in Kubernetes Secret
3. **Given** IngressRoute is configured with HTTPS, **When** accessing Headlamp via domain (e.g., https://headlamp.chocolandiadc.com), **Then** browser shows valid certificate and Headlamp UI loads
4. **Given** HTTPS is configured, **When** attempting to access via HTTP, **Then** traffic is redirected to HTTPS automatically

---

### User Story 4 - Integrate with Cloudflare Access for Authentication (Priority: P2)

Configure Cloudflare Access policy to protect Headlamp with Google OAuth authentication, ensuring only authorized users can access the cluster management UI.

**Why this priority**: Adds authentication layer to prevent unauthorized access. While HTTPS provides encryption, Cloudflare Access adds identity verification before users can reach Headlamp.

**Independent Test**: Can be tested by configuring Cloudflare Access policy, attempting to access Headlamp without authentication (should be blocked), and successfully authenticating with Google OAuth. Delivers value by adding zero-trust security to cluster management.

**Acceptance Scenarios**:

1. **Given** Headlamp is exposed via Traefik, **When** configuring Cloudflare Access application for headlamp.chocolandiadc.com, **Then** Access application is created with Google OAuth identity provider
2. **Given** Access policy requires Google OAuth, **When** unauthenticated user accesses Headlamp URL, **Then** user is redirected to Cloudflare Access login page
3. **Given** user provides valid Google credentials (authorized email), **When** authentication succeeds, **Then** user is redirected to Headlamp UI and can view cluster resources
4. **Given** user provides invalid credentials or unauthorized email, **When** attempting to authenticate, **Then** access is denied and user cannot reach Headlamp

---

### User Story 5 - Enable Prometheus Metrics for Headlamp Monitoring (Priority: P3)

Configure Headlamp to expose Prometheus metrics and create ServiceMonitor for automatic scraping, enabling observability of the web UI itself.

**Why this priority**: Enhancement for observability. While nice to have, monitoring Headlamp's own health is less critical than deploying and securing it. Useful for tracking UI performance and errors.

**Independent Test**: Can be tested by enabling metrics in Headlamp configuration, checking /metrics endpoint, and verifying that Prometheus scrapes the metrics. Delivers value by providing insights into UI performance and potential issues.

**Acceptance Scenarios**:

1. **Given** Headlamp is deployed with metrics enabled, **When** accessing /metrics endpoint, **Then** Prometheus-format metrics are returned including HTTP request counts and durations
2. **Given** ServiceMonitor is created, **When** Prometheus operator processes it, **Then** Headlamp target appears in Prometheus targets list with "UP" status
3. **Given** Prometheus is scraping Headlamp, **When** accessing Grafana, **Then** Headlamp metrics are available for dashboard creation (HTTP requests, response times, errors)
4. **Given** metrics are exposed, **When** user accesses Headlamp UI repeatedly, **Then** HTTP request count metrics increment accordingly

---

### Edge Cases

- What happens when Headlamp pod crashes or is killed?
- How does system handle invalid or expired ServiceAccount tokens?
- What happens when cert-manager fails to issue certificate for IngressRoute?
- How does Cloudflare Access behave when Google OAuth is temporarily unavailable?
- What happens when user's Google account is authorized but then removed from Access policy?
- How does Headlamp handle CRDs that are too large to render (e.g., massive ConfigMaps)?
- What happens when RBAC permissions change while user is actively using Headlamp?
- How does system handle concurrent deployments with conflicting IngressRoute hostnames?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy Headlamp using Helm chart via OpenTofu
- **FR-002**: System MUST configure Headlamp with single replica deployment (HA not required for homelab)
- **FR-003**: System MUST create ServiceAccount with read-only ClusterRole binding (ClusterRole "view")
- **FR-004**: System MUST configure resource limits for Headlamp pod (CPU: 200m, Memory: 128Mi)
- **FR-005**: System MUST create ClusterIP service for Headlamp on port 80
- **FR-006**: System MUST create Traefik IngressRoute exposing Headlamp on subdomain (e.g., headlamp.chocolandiadc.com)
- **FR-007**: System MUST configure IngressRoute with cert-manager annotation for automatic TLS certificate issuance
- **FR-008**: System MUST enable HTTPS redirect middleware to force secure connections
- **FR-009**: System MUST configure Cloudflare Access application with Google OAuth identity provider
- **FR-010**: System MUST define Cloudflare Access policy restricting access to authorized email addresses
- **FR-011**: System MUST enable Prometheus metrics endpoint in Headlamp configuration
- **FR-012**: System MUST create ServiceMonitor for Prometheus operator to scrape Headlamp metrics
- **FR-013**: System MUST configure health checks (liveness/readiness probes) for Headlamp pod
- **FR-014**: System MUST support viewing custom CRDs (Traefik IngressRoutes, cert-manager Certificates, etc.)
- **FR-015**: System MUST provide log streaming capability for pods via web UI
- **FR-016**: System MUST allow YAML editing of Kubernetes resources via web UI (respecting RBAC permissions)

### Key Entities

- **Headlamp Deployment**: Kubernetes Deployment running Headlamp web UI container (single replica for homelab)
- **ServiceAccount**: Kubernetes ServiceAccount with read-only permissions for safe cluster access
- **ClusterRoleBinding**: Binds ServiceAccount to "view" ClusterRole (built-in read-only role)
- **Service**: ClusterIP service exposing Headlamp web UI on port 80
- **IngressRoute**: Traefik CRD defining HTTP/HTTPS routing to Headlamp service
- **Certificate**: cert-manager CRD managing TLS certificate lifecycle for Headlamp domain
- **Cloudflare Access Application**: Zero Trust application protecting Headlamp with OAuth
- **Access Policy**: Cloudflare policy defining who can access Headlamp (authorized emails)
- **ServiceMonitor**: Prometheus operator CRD for automatic metrics scraping
- **Bearer Token**: Authentication token generated from ServiceAccount for Headlamp login

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Headlamp pod achieves Running status within 60 seconds of deployment
- **SC-002**: Web UI loads completely in under 3 seconds after authentication
- **SC-003**: Users can view all cluster resources (pods, services, deployments, CRDs) within 2 clicks from dashboard
- **SC-004**: HTTPS certificate is issued automatically within 5 minutes of IngressRoute creation
- **SC-005**: Unauthorized users are blocked from accessing Headlamp (100% of unauthenticated requests denied)
- **SC-006**: Authorized users can authenticate via Google OAuth in under 30 seconds
- **SC-007**: Pod resource consumption stays under configured limits (128Mi memory, 200m CPU) during normal operation
- **SC-008**: Log streaming for any pod starts within 2 seconds of request
- **SC-009**: Prometheus successfully scrapes Headlamp metrics every 30 seconds with no errors
- **SC-010**: Custom CRDs (IngressRoute, Certificate, etc.) are visible and editable via Headlamp UI
- **SC-011**: Read-only RBAC prevents any destructive operations (0% of delete/update attempts succeed)
- **SC-012**: Users can access Headlamp from any device with browser and internet connection
