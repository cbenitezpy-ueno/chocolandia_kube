# Feature Specification: Homepage Dashboard Update

**Feature Branch**: `001-homepage-update`
**Created**: 2025-11-18
**Status**: Draft
**Input**: User description: "Actualizar Homepage con servicios públicos/privados, IPs de nodos y arreglar widgets rotos de ArgoCD"

## Clarifications

### Session 2025-11-18

- Q: How should the dashboard visually distinguish between public and private service links? → A: Icons + text labels (e.g., 🌐 Public / 🏠 Private)
- Q: What domain pattern should be used for public Cloudflare tunnel URLs? → A: Use existing Cloudflare tunnel pattern from infrastructure (e.g., <service>.<domain>)
- Q: What should the widget refresh interval be for ArgoCD and Kubernetes widgets? → A: 30 seconds
- Q: Should widgets automatically retry when API calls fail? → A: Single retry after 10 seconds, then show error
- Q: How should services be ordered within each category on the dashboard? → A: Alphabetically within each category

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Cluster Infrastructure Information (Priority: P1)

As a cluster administrator, I need to quickly see the IP addresses and status of all nodes in my private network so that I can monitor infrastructure health and troubleshoot connectivity issues.

**Why this priority**: Infrastructure visibility is critical for daily operations and troubleshooting. Without this information readily available, administrators waste time SSH-ing into nodes or running kubectl commands repeatedly.

**Independent Test**: Can be fully tested by opening the Homepage dashboard and verifying that all four nodes (master1, nodo1, nodo03, nodo04) are displayed with their correct private IP addresses (192.168.4.101, 192.168.4.102, 192.168.4.103, 192.168.4.104) and status information.

**Acceptance Scenarios**:

1. **Given** the Homepage dashboard is accessible, **When** I navigate to the infrastructure section, **Then** I see all cluster nodes listed with their private IP addresses
2. **Given** the Homepage is displaying node information, **When** I check the node details, **Then** I see the role of each node (control-plane, worker, etc.) and their current status
3. **Given** multiple nodes are in the cluster, **When** viewing the node list, **Then** nodes are organized in a clear, scannable format

---

### User Story 2 - Access All Services via Links (Priority: P1)

As a cluster user, I need to see and access all deployed services through both their public URLs (internet-accessible) and private URLs (local network) so that I can quickly navigate to the services I need without memorizing URLs or port numbers.

**Why this priority**: Quick access to services is the primary purpose of a dashboard. Users should be able to click and go rather than remember URLs or hunt through documentation.

**Independent Test**: Can be fully tested by verifying that clicking on each service link opens the correct service interface, and that both public and private access methods are clearly labeled and functional.

**Acceptance Scenarios**:

1. **Given** services are deployed with public ingress URLs, **When** I view the Homepage dashboard, **Then** I see public HTTPS URLs for services like Grafana, Pi-hole, ArgoCD, Longhorn, and MinIO
2. **Given** services are accessible on the private network, **When** I view the Homepage dashboard, **Then** I see private access URLs with IP addresses and ports (e.g., NodePort, LoadBalancer IPs)
3. **Given** I click on a service link, **When** the service opens, **Then** I am taken directly to the service interface without additional authentication prompts (if SSO is configured)
4. **Given** services have multiple access methods, **When** viewing the dashboard, **Then** public links show 🌐 Public icon/label and private links show 🏠 Private icon/label

---

### User Story 3 - Monitor Service Status with Working Widgets (Priority: P2)

As a cluster administrator, I need to see real-time status information from integrated widgets (especially ArgoCD and Kubernetes cluster stats) so that I can quickly identify issues without opening multiple applications.

**Why this priority**: Widgets provide at-a-glance health monitoring, reducing the need to open individual services. However, this is secondary to basic link access (P1) since users can still manually check services if widgets are unavailable.

**Independent Test**: Can be fully tested by verifying that the ArgoCD widget displays current application sync status, and that the Kubernetes widget shows cluster resource usage without errors.

**Acceptance Scenarios**:

1. **Given** ArgoCD is deployed and Homepage has API access, **When** I view the Homepage dashboard, **Then** the ArgoCD widget displays application sync status without authentication errors
2. **Given** the Kubernetes cluster is running, **When** I view the Homepage dashboard, **Then** the Kubernetes widget displays node count, pod count, and resource usage
3. **Given** a widget encounters an API error, **When** viewing the dashboard, **Then** I see a helpful error message rather than a broken widget or blank space
4. **Given** widgets are updating, **When** I refresh the page, **Then** widget data refreshes to show current status

---

### Edge Cases

- What happens when a node goes offline? (The dashboard should still display the node with an indicator that it's unreachable)
- How does the system handle services that are temporarily unavailable? (Links should remain visible but may show status indicators)
- What happens if the ArgoCD API token expires or becomes invalid? (Widget should display a clear error message prompting token renewal)
- How are services with multiple replicas or endpoints displayed? (Show the primary LoadBalancer IP or ingress URL)
- What happens when viewing the dashboard from outside the private network? (Private IP links may not work, but public URLs should be accessible)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Dashboard MUST display all four cluster nodes with their private IP addresses (192.168.4.101, 192.168.4.102, 192.168.4.103, 192.168.4.104)
- **FR-002**: Dashboard MUST show node roles (control-plane, etcd, master, worker) and current status for each node
- **FR-003**: Dashboard MUST provide clickable links to all deployed services with both public and private access methods clearly labeled
- **FR-004**: Dashboard MUST include public HTTPS URLs for services exposed via Cloudflare tunnels following the pattern <service>.<domain> (e.g., grafana.<domain>, pihole.<domain>, argocd.<domain>, longhorn.<domain>, minio.<domain>, homepage.<domain>)
- **FR-005**: Dashboard MUST include private network access information for services using LoadBalancer IPs (Pi-hole DNS: 192.168.4.201, PostgreSQL: 192.168.4.200) and NodePort services (Grafana: port 30000, Pi-hole web: port 30001)
- **FR-006**: ArgoCD widget MUST display application sync status without requiring additional authentication, with data refreshing every 30 seconds
- **FR-007**: ArgoCD widget MUST use a valid API token that has read-only access to ArgoCD applications
- **FR-008**: Kubernetes cluster widget MUST display current cluster statistics (node count, pod count, resource usage) with data refreshing every 30 seconds
- **FR-009**: Dashboard MUST organize services into logical categories (Infrastructure, Monitoring, Storage, Applications, GitOps) with services sorted alphabetically within each category
- **FR-010**: Dashboard MUST clearly distinguish between public URLs (accessible from internet) and private URLs (accessible only from local network) using icons and text labels (🌐 Public for internet-accessible, 🏠 Private for local network-only)
- **FR-011**: System MUST persist widget configurations so they survive pod restarts
- **FR-012**: Dashboard MUST handle API errors gracefully by attempting a single retry after 10 seconds; if retry fails, display user-friendly error messages for broken widgets

### Key Entities

- **Cluster Node**: Represents a physical or virtual machine in the K3s cluster, with attributes: hostname, private IP address, role (control-plane/worker), status (Ready/NotReady)
- **Service Link**: Represents an accessible service endpoint, with attributes: service name, category, public URL (optional), private URL (IP:port), description
- **Widget Configuration**: Represents integration settings for external services, with attributes: widget type (ArgoCD, Kubernetes, etc.), API endpoint, authentication credentials, refresh interval (30 seconds)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrators can access any deployed service in under 5 seconds (from opening Homepage to service interface loading)
- **SC-002**: All four cluster nodes are visible with accurate IP addresses and status information that updates within 30 seconds of actual status changes
- **SC-003**: ArgoCD widget displays application sync status without authentication errors in 100% of page loads
- **SC-004**: Users can distinguish between public and private access methods without confusion (validated through user testing or feedback)
- **SC-005**: Dashboard loads completely in under 3 seconds on the local network
- **SC-006**: 100% of deployed services have at least one working access link (public or private)
- **SC-007**: Widget errors trigger a single retry after 10 seconds; if unresolved, clear error messages are displayed within 40 seconds total (initial failure + 10s wait + retry + 10s for error display)

## Assumptions

- Cloudflare Zero Trust tunnels are already configured for public access to services
- All services requiring public access have corresponding tunnel configurations
- The ArgoCD API is accessible from within the cluster on the argocd-server service
- Users accessing the dashboard have network connectivity to the cluster (either via VPN, local network, or Cloudflare tunnel)
- Services using ClusterIP can be accessed via Cloudflare tunnels configured externally
- Node status information is available via the Kubernetes API (which Homepage already has access to via ServiceAccount)

## Dependencies

- Kubernetes ServiceAccount with permissions to read nodes, services, and pods
- Valid ArgoCD API token with read-only access to applications
- Cloudflare tunnel configurations for public access (already in place)
- Existing services must remain accessible on their current ports and IPs
- Homepage Docker image must support Kubernetes and ArgoCD widget integrations

## Out of Scope

- Creating new public ingress routes (assumes existing tunnel configuration)
- Modifying service networking configuration (LoadBalancer IPs, NodePorts)
- Adding authentication to services (assumes existing auth mechanisms)
- Real-time alerting or notifications (dashboard is for viewing only)
- Historical data or metrics graphs (Grafana handles this)
- Mobile-optimized responsive design (desktop browser assumed)
