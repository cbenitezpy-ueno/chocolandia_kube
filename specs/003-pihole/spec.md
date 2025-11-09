# Feature Specification: Pi-hole DNS Ad Blocker

**Feature Branch**: `003-pihole`
**Created**: 2025-11-09
**Status**: Draft
**Input**: User description: "quiero instalar Pi-Hole (https://pi-hole.net/) y poder acceder a su interfaz web desde mi notebook"

## Context

Pi-hole is a network-wide ad blocker that acts as a DNS sinkhole, blocking ads and tracking domains at the network level. Installing it on the existing K3s cluster (Feature 002 MVP) will provide ad-blocking capabilities for all devices on the Eero network while leveraging the existing infrastructure.

**Current Infrastructure**: 2-node K3s cluster on Eero network (192.168.4.0/24) with Prometheus + Grafana monitoring already deployed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pi-hole Deployment on K3s Cluster (Priority: P1) 🎯 MVP

As a network administrator, I need to deploy Pi-hole as a containerized workload on the existing K3s cluster, so that I can provide network-wide ad blocking without requiring additional hardware or infrastructure.

**Why this priority**: Core functionality that enables ad blocking. Must be operational before any other features can be used.

**Independent Test**: Deploy Pi-hole to K3s cluster, verify the pod is running, DNS service is accessible within the cluster, and basic DNS queries are resolved correctly.

**Acceptance Scenarios**:

1. **Given** a functional K3s cluster with available compute resources, **When** Pi-hole is deployed via Helm or Kubernetes manifests, **Then** the Pi-hole pod reaches Running state within 2 minutes and passes readiness checks
2. **Given** Pi-hole pod is running, **When** a DNS query is sent to the Pi-hole service ClusterIP, **Then** the query is resolved correctly (legitimate domains return IP addresses, blocked domains return 0.0.0.0 or NXDOMAIN)
3. **Given** Pi-hole is operational, **When** querying Pi-hole service metrics endpoint, **Then** DNS query statistics (total queries, blocked queries, percentage blocked) are available

---

### User Story 2 - Web Admin Interface Access (Priority: P1) 🎯 MVP

As a network administrator, I need to access the Pi-hole web admin interface from my notebook browser, so that I can configure blocklists, view statistics, and manage DNS settings without SSH access to cluster nodes.

**Why this priority**: Essential for Pi-hole management and monitoring. Without web access, the service is not practically usable.

**Independent Test**: Open browser on notebook, navigate to Pi-hole admin URL, and successfully login to view dashboard with DNS statistics.

**Acceptance Scenarios**:

1. **Given** Pi-hole is deployed and running, **When** the web interface is exposed via NodePort service, **Then** the admin interface is accessible at http://[node-ip]:[nodeport] from any device on the Eero network
2. **Given** Pi-hole admin interface is accessible, **When** attempting to login with the admin password, **Then** authentication succeeds and the dashboard displays with current DNS query statistics
3. **Given** user is logged into Pi-hole admin, **When** navigating between dashboard pages (Query Log, Whitelist, Blacklist, Settings), **Then** all pages load successfully and display current data

---

### User Story 3 - Configure Devices to Use Pi-hole DNS (Priority: P2)

As a network user, I need my devices to automatically use Pi-hole for DNS resolution, so that ads are blocked network-wide without manual configuration on each device.

**Why this priority**: Enables actual ad blocking functionality. Can be tested independently by configuring devices manually even if automatic DHCP configuration is not set up.

**Independent Test**: Configure a single device (laptop or phone) to use Pi-hole DNS server IP, browse websites, and verify ads are blocked and Pi-hole query log shows the device's queries.

**Acceptance Scenarios**:

1. **Given** Pi-hole DNS service has a known IP address (service external IP or NodePort on node IP), **When** a device is manually configured to use that IP as DNS server, **Then** all DNS queries from that device appear in Pi-hole query log within 5 seconds
2. **Given** device is using Pi-hole for DNS, **When** browsing websites with known ad domains (e.g., doubleclick.net, googlesyndication.com), **Then** ads do not load and Pi-hole dashboard shows increased blocked query count
3. **Given** device is using Pi-hole for DNS, **When** visiting a website that Pi-hole incorrectly blocks, **Then** user can temporarily disable blocking or whitelist the domain via admin interface and access the site immediately

---

### User Story 4 - Persistent Configuration and Data (Priority: P2)

As a network administrator, I need Pi-hole configuration (blocklists, whitelist, blacklist) and query history to persist across pod restarts and cluster maintenance, so that I don't lose customizations or historical data.

**Why this priority**: Essential for production use. Without persistence, every pod restart requires reconfiguration.

**Independent Test**: Customize Pi-hole configuration (add custom blocklist, whitelist a domain), restart the Pi-hole pod, and verify customizations are retained.

**Acceptance Scenarios**:

1. **Given** Pi-hole is running with default configuration, **When** admin adds a custom blocklist URL and enables it, **Then** the blocklist is downloaded, activated, and persists after pod restart
2. **Given** Pi-hole has query history, **When** the Pi-hole pod is deleted and recreated (simulating pod eviction), **Then** query history from before the restart is still accessible in the admin interface
3. **Given** Pi-hole configuration includes custom DNS upstream servers, **When** Pi-hole pod restarts, **Then** custom upstream DNS servers are still configured (not reverted to defaults)

---

### User Story 5 - Integration with Existing Monitoring (Priority: P3)

As a network administrator, I need Pi-hole metrics integrated into the existing Grafana dashboards, so that I can monitor DNS performance and ad blocking effectiveness alongside cluster metrics.

**Why this priority**: Nice-to-have observability enhancement. Pi-hole has built-in statistics, so Grafana integration is supplementary.

**Independent Test**: Access Grafana dashboard, verify Pi-hole metrics (queries per second, blocked percentage, top domains) are displayed and updating in real-time.

**Acceptance Scenarios**:

1. **Given** Prometheus is already deployed and scraping cluster metrics, **When** Pi-hole exposes metrics in Prometheus format, **Then** Prometheus successfully scrapes Pi-hole metrics endpoint and stores metrics
2. **Given** Pi-hole metrics are in Prometheus, **When** a Grafana dashboard is created for Pi-hole, **Then** dashboard displays key metrics: total queries per minute, percentage blocked, top blocked domains, top allowed domains
3. **Given** Pi-hole metrics dashboard is created, **When** viewing the dashboard over time, **Then** historical trends are visible (daily/weekly query patterns, blocking effectiveness over time)

---

### Edge Cases

- What happens when Pi-hole pod crashes or is evicted while devices are using it for DNS?
  - Expected: Devices experience DNS failures until pod recovers. Consider deploying multiple replicas or fallback DNS servers.
- How does Pi-hole handle DNS queries for domains not in cache during high load?
  - Expected: Upstream DNS queries may be slower. Monitor query latency metrics.
- What happens if PersistentVolume runs out of space?
  - Expected: Pi-hole may fail to write query logs or update blocklists. Monitor disk usage and set alerts.
- How does Pi-hole interact with Eero's built-in DNS settings?
  - Expected: If Eero is configured to use Pi-hole as upstream DNS, all network traffic goes through Pi-hole. Otherwise, only manually configured devices use it.
- What happens when blocklists update and incorrectly block a critical domain?
  - Expected: User can whitelist the domain via admin interface. Consider documenting common false-positive domains.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy Pi-hole as a containerized workload on the existing K3s cluster (master1 + nodo1)
- **FR-002**: System MUST expose Pi-hole DNS service (port 53 UDP/TCP) for DNS query resolution
- **FR-003**: System MUST expose Pi-hole web admin interface (port 80 HTTP) for configuration and monitoring
- **FR-004**: Users MUST be able to access Pi-hole web admin interface from devices on the Eero network (192.168.4.0/24)
- **FR-005**: System MUST authenticate admin interface access with a password
- **FR-006**: System MUST persist Pi-hole configuration (blocklists, whitelist, blacklist, settings) across pod restarts
- **FR-007**: System MUST persist Pi-hole query history and statistics across pod restarts
- **FR-008**: System MUST use PersistentVolume to store Pi-hole data (configuration and database)
- **FR-009**: System MUST provide a way to retrieve the Pi-hole admin password securely (Kubernetes Secret)
- **FR-010**: System MUST allow admin to add custom blocklists via web interface
- **FR-011**: System MUST allow admin to whitelist or blacklist individual domains via web interface
- **FR-012**: System MUST display DNS query statistics in the admin dashboard (total queries, blocked queries, percentage blocked, top domains)
- **FR-013**: System MUST update blocklists automatically on a configurable schedule (default: weekly)
- **FR-014**: System MUST expose metrics for monitoring (queries per second, blocked percentage, upstream DNS latency)
- **FR-015**: System MUST support configurable upstream DNS servers (default: Cloudflare 1.1.1.1, Google 8.8.8.8)

### Key Entities *(include if feature involves data)*

- **Pi-hole Instance**: Containerized Pi-hole application running as a Kubernetes pod
  - Attributes: admin password, upstream DNS servers, web interface port, DNS service port
  - State: running, stopped, updating blocklists

- **DNS Service**: Kubernetes Service exposing Pi-hole DNS resolver (port 53)
  - Type: LoadBalancer or NodePort (depending on cluster capabilities)
  - Attributes: ClusterIP, external IP or NodePort

- **Web Admin Service**: Kubernetes Service exposing Pi-hole web interface (port 80)
  - Type: NodePort (accessible at http://node-ip:nodeport)
  - Attributes: NodePort number, ClusterIP

- **Blocklist**: List of domains to block (ads, trackers, malware)
  - Attributes: list name, URL source, number of domains, last updated timestamp
  - Default lists: StevenBlack's unified hosts file, EasyList, etc.

- **Whitelist**: List of domains to never block (user-defined exceptions)
  - Attributes: domain name, added date, reason (optional comment)

- **Blacklist**: List of domains to always block (user-defined additions)
  - Attributes: domain name, added date, reason (optional comment)

- **DNS Query**: Individual DNS lookup request from a client device
  - Attributes: timestamp, client IP, requested domain, query type (A, AAAA, etc.), status (allowed/blocked), response time

- **PersistentVolume**: Storage for Pi-hole data
  - Paths: /etc/pihole (configuration), /etc/dnsmasq.d (DNS config)
  - Size: 5Gi (sufficient for query history and blocklists)

- **Kubernetes Secret**: Stores Pi-hole admin password
  - Name: pihole-admin-password
  - Field: password (base64 encoded)

## Success Criteria *(mandatory)*

Success is measured by these outcomes:

1. **DNS Query Performance**: Pi-hole resolves DNS queries in under 100ms (95th percentile) for cached queries
2. **Ad Blocking Effectiveness**: At least 15% of DNS queries are blocked (indicating active ad blocking)
3. **Service Availability**: Pi-hole DNS service has 99% uptime measured over 7 days
4. **Admin Interface Accessibility**: Web admin interface is accessible from notebook within 2 seconds of page load
5. **Configuration Persistence**: Pi-hole customizations (blocklists, whitelist, blacklist) survive pod restarts with 100% retention
6. **Query History Retention**: Pi-hole query log retains at least 24 hours of history (or 100,000 queries, whichever is reached first)
7. **User Satisfaction**: Network users report fewer ads visible on websites after Pi-hole deployment (qualitative measure via user survey)

## Scope *(mandatory)*

### In Scope

- Deploy Pi-hole on existing K3s cluster (Feature 002 MVP) as a containerized workload
- Expose Pi-hole DNS service for use by network devices
- Expose Pi-hole web admin interface via NodePort for management from notebook
- Configure persistent storage for Pi-hole data (configuration and query history)
- Provide secure access to admin password via Kubernetes Secret
- Integration with existing Prometheus monitoring (optional, P3)
- Document how to configure devices (manual DNS configuration) to use Pi-hole

### Out of Scope

- Automatic DHCP configuration to force all Eero devices to use Pi-hole (requires Eero router configuration, not controllable from K3s)
- High availability setup with multiple Pi-hole replicas (single instance is sufficient for home network)
- Custom Pi-hole blocklist curation (use existing community blocklists)
- DNS-over-HTTPS (DoH) or DNS-over-TLS (DoT) configuration (can be added later if needed)
- Integration with external DNS providers beyond upstream DNS configuration
- Mobile app for Pi-hole management (web interface is sufficient)

## Assumptions *(mandatory)*

1. **Existing Infrastructure**: K3s cluster from Feature 002 is operational with nodes master1 (192.168.4.101) and nodo1 (192.168.4.102)
2. **Network Access**: All devices on Eero network (192.168.4.0/24) can reach NodePort services on cluster nodes
3. **Storage**: K3s local-path-provisioner (already deployed) can provide PersistentVolumes for Pi-hole data storage
4. **Pi-hole Version**: Use the latest stable Pi-hole Docker image from Docker Hub (pihole/pihole)
5. **Default Blocklists**: Pi-hole will use default community-maintained blocklists (StevenBlack's unified hosts, EasyList, etc.)
6. **Admin Access**: User has kubectl access to the K3s cluster for deployment and troubleshooting
7. **DNS Port Availability**: Port 53 UDP/TCP is available for use by Pi-hole DNS service (not already used by another service)
8. **NodePort Range**: K3s default NodePort range (30000-32767) allows assigning a NodePort for web admin interface
9. **Upstream DNS**: Pi-hole will forward unblocked queries to Cloudflare (1.1.1.1) and Google (8.8.8.8) by default
10. **Single Instance**: One Pi-hole pod is sufficient for home network DNS load (no need for multiple replicas initially)

## Dependencies *(mandatory)*

**Critical Path**:
- Feature 002 (K3s MVP on Eero) MUST be operational and healthy before deploying Pi-hole

**External Dependencies**:
- Pi-hole Docker image availability from Docker Hub
- Upstream DNS servers (Cloudflare 1.1.1.1, Google 8.8.8.8) must be reachable from cluster
- Blocklist URLs must be accessible from cluster for initial download and updates

**Internal Dependencies**:
- K3s local-path-provisioner for PersistentVolume creation
- K3s CoreDNS must not conflict with Pi-hole DNS service (Pi-hole uses service port, CoreDNS uses ClusterIP)
- Sufficient cluster resources: ~512Mi memory, ~0.5 CPU core for Pi-hole pod

## Non-Functional Requirements *(optional)*

### Performance

- DNS query resolution latency: < 100ms (95th percentile) for cached queries
- DNS query resolution latency: < 500ms (95th percentile) for uncached queries requiring upstream DNS lookup
- Web admin interface page load time: < 2 seconds for dashboard
- Support at least 100 DNS queries per second (sufficient for home network with ~10-20 devices)

### Reliability

- Pi-hole pod should automatically restart if it crashes (Kubernetes default behavior)
- DNS service should remain accessible if Pi-hole pod is rescheduled to different node
- PersistentVolume should survive node restarts and pod evictions

### Security

- Admin interface MUST require password authentication (no anonymous access)
- Admin password MUST be stored in Kubernetes Secret (not in plaintext ConfigMap or environment variable)
- Web admin interface accessible only from Eero network (192.168.4.0/24), not exposed to public internet
- DNS service accessible only from Eero network (no port forwarding to public internet)

### Usability

- Admin interface should be accessible via memorable URL (e.g., http://192.168.4.101:30001)
- Query log should display client device names or IPs for easy identification
- Blocklist updates should not disrupt DNS resolution (queries continue during update)

## Migration Strategy *(optional)*

This feature does not require migration from an existing system. Pi-hole is a new deployment on the existing K3s cluster.

**Post-Deployment Migration**:
- Users will need to manually configure their devices to use Pi-hole DNS server IP (or configure Eero router to use Pi-hole as upstream DNS)
- Gradual rollout recommended: Test with 1-2 devices first, then expand to all network devices

**Future Migration** (when moving from Feature 002 MVP to Feature 001 HA cluster):
- Export Pi-hole configuration (blocklists, whitelist, blacklist, settings) via Teleporter backup feature
- Redeploy Pi-hole on new HA cluster with same configuration
- Update device DNS settings to point to new Pi-hole IP address

---

**Version**: 1.0
**Status**: Draft - Ready for Clarification and Planning
