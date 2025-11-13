# Feature Specification: Homepage Dashboard

**Feature Branch**: `009-homepage-dashboard`
**Created**: 2025-11-12
**Status**: Draft
**Input**: User description: "quiero instalar Homepage (gethomepage.dev) y configurar los widget para reflejar lo que tengo instalado en el cluster. quiero un lugar donde me muestre las aplicaciones la url interna y la url publica"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Access Centralized Dashboard (Priority: P1)

As a cluster administrator, I need a single web interface where I can see all my deployed applications with their internal and public URLs, so I can quickly access any service without remembering individual addresses.

**Why this priority**: This is the core value proposition - providing a centralized access point. Without this, the feature delivers no value.

**Independent Test**: Can be fully tested by deploying Homepage with basic service discovery and accessing it via a browser. Delivers immediate value by showing the service inventory.

**Acceptance Scenarios**:

1. **Given** Homepage is deployed, **When** I navigate to the dashboard URL, **Then** I see a web interface displaying all deployed applications
2. **Given** I'm viewing the dashboard, **When** I look at any application entry, **Then** I can see both its internal cluster URL and public URL (if available)
3. **Given** I click on an application's URL link, **When** the link is followed, **Then** I'm redirected to that application's interface

---

### User Story 2 - View Real-Time Service Status (Priority: P1)

As a cluster administrator, I want to see the current operational status of each application (running, stopped, error), so I can quickly identify issues without running kubectl commands.

**Why this priority**: Essential for operational awareness - a dashboard that only shows static links has limited value compared to showing actual service health.

**Independent Test**: Can be tested by deploying Homepage with Kubernetes integration enabled. Verify that pod status reflects in the dashboard when pods are stopped/started.

**Acceptance Scenarios**:

1. **Given** Homepage is connected to Kubernetes API, **When** I view the dashboard, **Then** each application shows its current status (healthy, degraded, or failed)
2. **Given** a service pod crashes, **When** I refresh the dashboard, **Then** the service status updates to reflect the error state
3. **Given** all services are running normally, **When** I view the dashboard, **Then** I see green/healthy indicators for all applications

---

### User Story 3 - Monitor Key Infrastructure Widgets (Priority: P2)

As a cluster administrator, I want to see specialized widgets for my core infrastructure services (Pi-hole, Traefik, cert-manager, ArgoCD), so I can monitor their specific metrics without opening each service's individual dashboard.

**Why this priority**: Enhances operational efficiency by surfacing key metrics, but the dashboard is still valuable without it (users can click through to individual services).

**Independent Test**: Can be tested by configuring widgets for each infrastructure service and verifying metrics display correctly. Each widget can be tested independently.

**Acceptance Scenarios**:

1. **Given** Pi-hole widget is configured, **When** I view the dashboard, **Then** I see DNS query statistics (queries blocked, total queries, top blocked domains)
2. **Given** Traefik widget is configured, **When** I view the dashboard, **Then** I see router/service status and request metrics
3. **Given** cert-manager widget is configured, **When** I view the dashboard, **Then** I see certificate expiration dates and renewal status
4. **Given** ArgoCD widget is configured, **When** I view the dashboard, **Then** I see application sync status and health for all ArgoCD apps

---

### User Story 4 - Secure External Access (Priority: P1)

As a cluster administrator, I need Homepage to be accessible from the internet through the existing Cloudflare Zero Trust authentication, so I can access my dashboard securely from anywhere using the same authentication method as my other services.

**Why this priority**: Security is non-negotiable. Without proper authentication, exposing a service inventory externally would be a critical vulnerability.

**Independent Test**: Can be tested by configuring Cloudflare Access for Homepage and verifying that unauthenticated requests are blocked while authenticated requests succeed.

**Acceptance Scenarios**:

1. **Given** Homepage is deployed behind Cloudflare Access, **When** an unauthenticated user tries to access the dashboard URL, **Then** they are redirected to Google OAuth login
2. **Given** I'm authenticated with Google OAuth, **When** I access the dashboard URL, **Then** I can view the Homepage interface without additional login
3. **Given** my session expires, **When** I try to access Homepage, **Then** I'm redirected to re-authenticate before accessing the dashboard

---

### User Story 5 - Automatic Service Discovery (Priority: P2)

As a cluster administrator, when I deploy new applications to the cluster, I want Homepage to automatically detect and display them, so I don't have to manually update configuration files each time.

**Why this priority**: Reduces operational overhead and ensures the dashboard stays current, but manual configuration is acceptable for MVP.

**Independent Test**: Can be tested by deploying a new application to the cluster and verifying it appears in Homepage without configuration changes.

**Acceptance Scenarios**:

1. **Given** Homepage has Kubernetes RBAC permissions, **When** a new service is deployed with proper annotations/labels, **Then** it automatically appears on the dashboard within 30 seconds
2. **Given** a service is deleted from the cluster, **When** Homepage refreshes, **Then** the service is removed from the dashboard
3. **Given** a service's ingress URL changes, **When** Homepage detects the change, **Then** the dashboard updates to show the new URL

---

### Edge Cases

- What happens when a service has multiple ports/URLs (internal, external, admin)?
- How does the dashboard handle services that are temporarily unavailable during deployments?
- What happens if Homepage loses connection to the Kubernetes API?
- How are services without public URLs displayed (internal-only services)?
- What happens when a certificate for a public URL is expired or invalid?
- How does the dashboard handle widgets when the target service API is unreachable?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a web-based dashboard listing all deployed applications in the cluster
- **FR-002**: System MUST show both internal cluster URLs (ClusterIP/NodePort) and external public URLs (via Cloudflare Tunnel) for each application
- **FR-003**: System MUST integrate with Kubernetes API to discover services and their current operational status
- **FR-004**: System MUST provide specialized widgets for Pi-hole (DNS statistics), Traefik (routing metrics), cert-manager (certificate status), and ArgoCD (sync status)
- **FR-005**: System MUST authenticate users through Cloudflare Zero Trust using existing Google OAuth integration
- **FR-006**: System MUST automatically refresh service status and widget data at configurable intervals (default: 30 seconds)
- **FR-007**: System MUST persist dashboard configuration (widget layouts, service organization) across restarts
- **FR-008**: System MUST be accessible via HTTPS with a valid TLS certificate
- **FR-009**: System MUST provide clickable links to access each displayed application
- **FR-010**: System MUST visually distinguish between healthy, degraded, and failed service states

### Key Entities

- **Dashboard Configuration**: Represents the overall layout, theme, and organization of services on the Homepage interface. Includes widget positions, service groupings, and display preferences.
- **Service Entry**: Represents a discovered application/service with attributes: name, namespace, internal URL, external URL (if exposed), status (healthy/degraded/failed), icon, description, associated ingress.
- **Widget Instance**: Represents a monitoring component for infrastructure services. Attributes: widget type (Pi-hole, Traefik, cert-manager, ArgoCD), API endpoint, refresh interval, displayed metrics, authentication credentials.
- **Kubernetes Service Discovery**: Represents the mechanism for finding services. Attributes: service annotations/labels used for filtering, RBAC permissions required, namespaces monitored.
- **Authentication Session**: Represents a user's access session through Cloudflare Access. Attributes: user email, OAuth token, session expiration, access level.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrators can access the dashboard and view all deployed applications within 3 seconds of page load
- **SC-002**: Dashboard displays accurate service status with no more than 30 seconds delay between actual state change and dashboard update
- **SC-003**: All infrastructure widgets (Pi-hole, Traefik, cert-manager, ArgoCD) display current metrics successfully for 99% of page loads
- **SC-004**: Administrators can successfully access any listed service by clicking its URL link with 100% success rate for valid services
- **SC-005**: Dashboard is accessible externally via Cloudflare Zero Trust with successful authentication for all authorized users
- **SC-006**: New services deployed to the cluster appear on the dashboard automatically within 60 seconds (when using auto-discovery)
- **SC-007**: Dashboard remains available and functional during cluster maintenance windows with graceful degradation when services are temporarily unavailable
- **SC-008**: Administrators report a 75% reduction in time spent locating and accessing cluster services compared to manual kubectl/browser bookmark methods

## Scope *(mandatory)*

### In Scope

- Installation of Homepage application on K3s cluster
- Configuration of Kubernetes service discovery with RBAC permissions
- Integration of specialized widgets for existing infrastructure (Pi-hole, Traefik, cert-manager, ArgoCD)
- Display of internal cluster URLs and external public URLs for all services
- Authentication integration with existing Cloudflare Zero Trust + Google OAuth
- TLS certificate configuration using existing cert-manager setup
- Basic service status monitoring (healthy/unhealthy)
- Configuration as code (YAML) for GitOps deployment via ArgoCD
- Documentation for adding new services and widgets

### Out of Scope

- Custom widget development for services beyond the four core infrastructure components
- Advanced monitoring/alerting capabilities (use existing monitoring stack)
- User access control beyond cluster-level authentication (no per-service permissions)
- Mobile application or responsive mobile optimization
- Historical metrics or time-series data visualization
- Service health check customization (uses Kubernetes liveness/readiness probes)
- Multi-cluster dashboard (single K3s cluster only)
- Service deployment/management capabilities (read-only dashboard)

## Assumptions

- K3s cluster is operational with existing services (Pi-hole, Traefik, cert-manager, ArgoCD, Headlamp) already deployed
- Cloudflare Zero Trust infrastructure is configured and operational
- Services expose standard Kubernetes service resources with ingress configurations
- cert-manager can issue TLS certificates for Homepage's domain
- ArgoCD is available for GitOps-based deployment
- Homepage will use the existing local-path-provisioner for persistent storage
- Services follow standard naming conventions and labeling practices
- Administrators have cluster-admin level access for initial setup
- External access requires existing Cloudflare Tunnel infrastructure

## Dependencies

- **K3s Cluster**: Homepage requires a functioning Kubernetes cluster (v1.28+)
- **Cloudflare Zero Trust**: Required for secure external access and Google OAuth authentication
- **cert-manager**: Required for automatic TLS certificate provisioning
- **Traefik**: May be used for internal ingress routing (optional if using Cloudflare Tunnel exclusively)
- **ArgoCD**: Required for GitOps deployment of Homepage configuration
- **Infrastructure Service APIs**: Pi-hole, Traefik, cert-manager, and ArgoCD must expose metrics/status APIs for widgets to function
- **Persistent Storage**: local-path-provisioner required for storing Homepage configuration

## Risks & Mitigations

- **Risk**: Homepage becomes a security risk by exposing service inventory to unauthorized users
  - **Mitigation**: Deploy behind Cloudflare Access with mandatory authentication; ensure RBAC permissions are read-only

- **Risk**: Widget configurations may expose sensitive API credentials or tokens
  - **Mitigation**: Store credentials in Kubernetes Secrets; use service accounts with minimal required permissions

- **Risk**: Automated service discovery could display internal/sensitive services not intended for dashboard
  - **Mitigation**: Use label/annotation selectors to explicitly include/exclude services; default to opt-in model

- **Risk**: Dashboard becomes single point of failure for accessing services
  - **Mitigation**: Dashboard is convenience layer only - all services remain independently accessible; document fallback access methods

- **Risk**: Widget API calls could impact performance of monitored services
  - **Mitigation**: Configure reasonable refresh intervals (default 30s); implement rate limiting; use read-only API endpoints

- **Risk**: Dashboard configuration drift if manually edited outside GitOps
  - **Mitigation**: Deploy via ArgoCD with auto-sync; document that all changes must go through Git repository

## Future Enhancements

- Integration with Prometheus/Grafana for embedded metric visualizations
- Custom widget development for user-deployed applications
- Service health alerting (email/Slack notifications)
- Multi-cluster support for viewing services across multiple K3s clusters
- Service dependency visualization (show relationships between services)
- Dark/light theme toggle with custom branding
- Mobile-responsive design optimization
- Search and filtering capabilities for large service inventories
- Bookmarking/favorites for frequently accessed services
- Service uptime statistics and availability tracking
