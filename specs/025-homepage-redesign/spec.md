# Feature Specification: Homepage Dashboard Redesign

**Feature Branch**: `025-homepage-redesign`
**Created**: 2025-12-28
**Status**: Draft
**Input**: Redesign the Homepage dashboard to be visually appealing and useful, with cluster information, service addresses, quick actions, and reference documentation. Inspired by the Grafana homelab-overview dashboard.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cluster Health at a Glance (Priority: P1)

As a homelab operator, I want to see the overall cluster health status immediately when I open Homepage, so I can quickly determine if any services need attention without clicking through multiple pages.

**Why this priority**: Instant health visibility is the primary purpose of a dashboard. If users can't see if the cluster is healthy within 5 seconds, the dashboard fails its core mission.

**Independent Test**: Can be fully tested by opening Homepage and visually confirming that cluster CPU/memory usage, node status, and running pod count are visible in the header widgets.

**Acceptance Scenarios**:

1. **Given** the Homepage is loaded, **When** I view the header area, **Then** I see cluster-wide CPU and memory utilization percentages.
2. **Given** the Homepage is loaded, **When** I view the header area, **Then** I see the number of healthy nodes and total nodes in the cluster.
3. **Given** a node goes down, **When** I view Homepage, **Then** the node count reflects the reduced healthy node count with a visual warning indicator.

---

### User Story 2 - Service Status and Access (Priority: P1)

As a homelab operator, I want to see all my services organized by category with their status and access URLs, so I can quickly access any service and know if it's running properly.

**Why this priority**: Knowing which services are available and how to access them is essential for daily operations.

**Independent Test**: Can be fully tested by verifying each service card shows: status indicator (healthy/unhealthy), primary access URL (clickable), and both public and private access methods in the description.

**Acceptance Scenarios**:

1. **Given** a service is running normally, **When** I view its card, **Then** I see a green status indicator.
2. **Given** a service has a public URL via Cloudflare, **When** I view its card, **Then** I see the public URL as the primary clickable link.
3. **Given** a service has a LoadBalancer IP, **When** I view its card, **Then** the IP address is visible in the description.
4. **Given** a service only has internal access, **When** I view its card, **Then** port-forward or NodePort instructions are visible.

---

### User Story 3 - Quick Reference Information (Priority: P2)

As a homelab operator, I want quick access to common commands, IP assignments, and access patterns without leaving the dashboard, so I can perform routine operations efficiently.

**Why this priority**: Reduces context-switching and lookup time for common operations, making the dashboard a single source of truth.

**Independent Test**: Can be fully tested by verifying the Quick Reference section contains: SSH commands, kubectl common commands, LoadBalancer IP assignments, and certificate information.

**Acceptance Scenarios**:

1. **Given** I need to SSH into a node, **When** I view the Quick Reference section, **Then** I see the SSH command with the correct key path and username.
2. **Given** I need to know which IP is assigned to PostgreSQL, **When** I view the IP Assignments, **Then** I see 192.168.4.204 listed for PostgreSQL.
3. **Given** I need to port-forward to Prometheus, **When** I view the Quick Reference section, **Then** I see the complete port-forward command.

---

### User Story 4 - Visual Design and Aesthetics (Priority: P2)

As a homelab operator, I want the dashboard to look professional and visually appealing, so I can proudly show it to others and enjoy using it daily.

**Why this priority**: A well-designed interface improves user experience and makes monitoring less tedious, encouraging regular use.

**Independent Test**: Can be fully tested by visual inspection confirming: consistent color scheme, proper section organization, readable text contrast, and modern card styling.

**Acceptance Scenarios**:

1. **Given** the Homepage is loaded, **When** I view the overall design, **Then** I see a consistent color theme throughout.
2. **Given** the Homepage is loaded, **When** I view service cards, **Then** they have modern styling with clear visual separation.
3. **Given** the Homepage is loaded on a dark-themed monitor, **When** I view the dashboard, **Then** all text is easily readable with good contrast.

---

### User Story 5 - Native Service Widgets (Priority: P3)

As a homelab operator, I want services with native Homepage widgets (Grafana, ArgoCD, Traefik, Pi-hole) to show live metrics, so I get more detailed status information without clicking through.

**Why this priority**: Adds depth to monitoring but not essential for basic dashboard functionality.

**Independent Test**: Can be fully tested by verifying that services with native widgets display real-time metrics (e.g., Pi-hole shows blocked queries, ArgoCD shows sync status).

**Acceptance Scenarios**:

1. **Given** Pi-hole is running, **When** I view its widget, **Then** I see queries today and blocked percentage.
2. **Given** ArgoCD is running, **When** I view its widget, **Then** I see application sync status (synced/out-of-sync count).
3. **Given** Grafana is running, **When** I view its widget, **Then** I see alert status or dashboard count.

---

### User Story 6 - Mobile Responsiveness (Priority: P3)

As a homelab operator using a mobile device, I want the dashboard to be usable on smaller screens, so I can check cluster status when away from my desk.

**Why this priority**: Nice to have for occasional mobile access, but primary use is on desktop.

**Independent Test**: Can be fully tested by viewing Homepage on a mobile device (or responsive design mode) and confirming services are visible and clickable.

**Acceptance Scenarios**:

1. **Given** I access Homepage on a mobile device, **When** I scroll through the page, **Then** service cards stack vertically and remain readable.
2. **Given** I access Homepage on a tablet, **When** I view the layout, **Then** essential sections (Cluster Health, Services) are visible without excessive scrolling.

---

### Edge Cases

- What happens when Homepage cannot reach the Kubernetes API? Display a clear error message indicating cluster connectivity issues.
- How does the system handle when a native widget API (e.g., Grafana) is unavailable? Show the service card with a "Widget unavailable" indicator but maintain the link functionality.
- What happens if Prometheus metrics are stale or unavailable? Display "N/A" or last known value with a timestamp indicator.
- How does the dashboard handle services that are intentionally stopped? Show them with an appropriate status (not running) vs. unhealthy (crash loop).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Dashboard MUST display cluster-wide CPU and memory utilization in the header widgets.
- **FR-002**: Dashboard MUST display the count of healthy nodes vs total nodes in the cluster.
- **FR-003**: Dashboard MUST organize services into logical categories: Critical Infrastructure, Platform Services, Applications, Network & DNS, Storage & Data, and Cluster Info.
- **FR-004**: Each service card MUST display a status indicator showing service health (running/not running).
- **FR-005**: Each service card with external access MUST include a clickable URL as the primary action.
- **FR-006**: Service descriptions MUST include both public URLs (*.chocolandiadc.com) and private access methods (LoadBalancer IPs, NodePorts).
- **FR-007**: Dashboard MUST include a Quick Reference section with common kubectl commands, SSH access commands, and IP assignments.
- **FR-008**: Dashboard MUST use a consistent dark theme with a professional color palette.
- **FR-009**: Dashboard MUST maintain the existing Homepage infrastructure (Kubernetes deployment in homepage namespace).
- **FR-010**: Services with native Homepage widgets (Pi-hole, Grafana, ArgoCD, Traefik) MUST display live metrics from those services.
- **FR-011**: Dashboard MUST be usable on mobile devices with responsive column stacking.
- **FR-012**: Dashboard MUST load within 5 seconds on a typical connection.
- **FR-013**: Dashboard MUST support search functionality to quickly find services.
- **FR-014**: Dashboard MUST document MetalLB LoadBalancer IP assignments (192.168.4.200-210 range).

### Key Entities

- **Service Card**: Represents a deployed service with: name, icon, description, href (primary URL), status indicator, widget (optional live metrics).
- **Service Category**: A logical grouping of related services with: name, icon, layout style, display order.
- **Info Widget**: Header-level widgets showing: cluster resources, Kubernetes stats, date/time, search.
- **Quick Reference**: Static information sections showing: commands, IP assignments, access patterns.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can determine overall cluster health status (healthy/unhealthy) within 5 seconds of page load.
- **SC-002**: Users can find and click to access any deployed service within 10 seconds of page load.
- **SC-003**: Users can locate the LoadBalancer IP for any MetalLB-exposed service within 15 seconds.
- **SC-004**: Users can find and copy a common kubectl command within 20 seconds.
- **SC-005**: All service categories and their services are visible without horizontal scrolling on desktop (1920x1080 resolution).
- **SC-006**: Dashboard visual design receives positive feedback in blog article context (subjective, but documented).
- **SC-007**: Native widgets display live data for at least 4 services (Pi-hole, Grafana, ArgoCD, Traefik).
- **SC-008**: Page is fully interactive within 5 seconds on desktop and 8 seconds on mobile.

## Assumptions

- The existing Homepage Helm deployment in the `homepage` namespace will be retained and only configuration updated.
- All services listed in the current services.yaml are still deployed and accessible.
- Native widget integrations may require API credentials to be configured as environment variables (HOMEPAGE_VAR_*).
- The Pi-hole API key, ArgoCD credentials, and Grafana credentials will be provided securely for widget configuration.
- Background images, if used, will be sourced from free/public image sources or hosted locally.
- The Kubernetes RBAC configuration already in place for Homepage is sufficient for the new widgets.
