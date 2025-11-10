# Feature Specification: Cloudflare Zero Trust VPN Access

**Feature Branch**: `004-cloudflare-zerotrust`
**Created**: 2025-11-09
**Status**: Draft
**Input**: User description: "quiero agregar un cloudflare zerotrust vpn para poder acceder a lo que tengo en mi red. quiero hostear eso en el cluster, me guias con la configuracion y deployar lo que necesito"

## Clarifications

### Session 2025-11-09

- Q: Which domain name will be used for the tunnel hostnames? → A: chocolandiadc.com (newly purchased in Cloudflare)
- Q: Which email addresses should be authorized to access the protected services? → A: Admin + limited family/friends list (2-5 specific emails including cbenitez@gmail.com)
- Q: Which internal services should be exposed through the tunnel in the MVP deployment? → A: Pi-hole + Grafana (monitoring dashboard included from start)
- Q: Should Cloudflare configuration be managed via dashboard or Terraform? → A: All Cloudflare configuration MUST be managed via Terraform (no manual dashboard changes allowed, strict GitOps compliance)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Remote Secure Access to Home Network Services (Priority: P1)

As a network administrator, I want to securely access services running in my home network (K3s cluster, Pi-hole, etc.) from any location without exposing them to the public internet.

**Why this priority**: This is the core value proposition - secure remote access is the primary reason for deploying Cloudflare Zero Trust. Without this, the feature provides no value.

**Independent Test**: Can be fully tested by connecting from an external network (mobile data, coffee shop WiFi) to a service running in the home cluster (e.g., Pi-hole admin interface) and verifying successful authenticated access without direct port forwarding or public IP exposure.

**Acceptance Scenarios**:

1. **Given** Cloudflare Tunnel is running in the cluster and connected to Cloudflare, **When** user navigates to the configured tunnel hostname from any internet location, **Then** user is prompted for Cloudflare Access authentication before reaching the internal service
2. **Given** user has completed Cloudflare Access authentication, **When** user accesses internal services through the tunnel, **Then** traffic is encrypted end-to-end and services respond as if accessed locally
3. **Given** user is accessing services through the tunnel, **When** the tunnel connection is interrupted, **Then** access is immediately blocked until tunnel reconnects

---

### User Story 2 - Centralized Access Control and Authentication (Priority: P2)

As a network administrator, I want to control who can access my internal services using Cloudflare Access policies with email-based authentication, so I can grant temporary access to family members or collaborators without managing VPN client configurations.

**Why this priority**: Enhances security and user management beyond basic connectivity. Provides audit trails and granular access control.

**Independent Test**: Can be tested by creating multiple Cloudflare Access policies with different email domains/addresses, attempting access from authorized and unauthorized accounts, and verifying that only authorized users can reach protected services.

**Acceptance Scenarios**:

1. **Given** Cloudflare Access policies are configured for specific email addresses, **When** unauthorized user attempts to access a protected service, **Then** access is denied with clear error message
2. **Given** multiple services are exposed through different tunnel routes, **When** access policies are configured per service, **Then** users only see and access services they are authorized for
3. **Given** user has been granted temporary access, **When** access policy expires or is revoked, **Then** user can no longer authenticate to protected services

---

### User Story 3 - Tunnel High Availability and Monitoring (Priority: P3)

As a network administrator, I want the Cloudflare Tunnel to automatically recover from failures and provide visibility into connection status, so I can ensure reliable remote access without manual intervention.

**Why this priority**: Operational excellence and reliability. Nice to have for production-grade deployment but not essential for basic functionality.

**Independent Test**: Can be tested by forcefully terminating the tunnel pod, verifying automatic restart and reconnection, checking tunnel status in Cloudflare dashboard, and confirming that access is restored within acceptable timeframe.

**Acceptance Scenarios**:

1. **Given** the tunnel pod crashes or is deleted, **When** Kubernetes restarts the pod, **Then** tunnel automatically reconnects to Cloudflare within 30 seconds
2. **Given** tunnel is running, **When** viewing Cloudflare Zero Trust dashboard, **Then** tunnel status shows as "Healthy" with connection metrics
3. **Given** tunnel loses connectivity to Cloudflare, **When** network connectivity is restored, **Then** tunnel automatically reconnects without manual intervention

---

### Edge Cases

- What happens when Cloudflare Zero Trust service experiences an outage? (Services become inaccessible remotely but remain accessible within local network)
- How does the system handle DNS resolution conflicts if tunnel hostname overlaps with local network hostnames?
- What happens if the tunnel token/credentials are compromised or revoked?
- How does the system behave when accessing services that require persistent connections (WebSockets, SSH)?
- What happens when multiple replicas of the tunnel connector are running simultaneously?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST run Cloudflare Tunnel connector (cloudflared) as a Kubernetes deployment in the K3s cluster
- **FR-002**: System MUST authenticate to Cloudflare using a tunnel token stored as a Kubernetes Secret
- **FR-003**: System MUST route HTTP/HTTPS traffic from public Cloudflare hostnames to internal K3s services
- **FR-004**: System MUST integrate with Cloudflare Access to enforce authentication before allowing traffic to internal services
- **FR-005**: System MUST support routing multiple internal services through different paths or hostnames on the same tunnel
- **FR-006**: System MUST automatically restart and reconnect the tunnel if the pod fails or loses connectivity
- **FR-007**: System MUST preserve tunnel configuration across pod restarts using ConfigMap or tunnel configuration file
- **FR-008**: Configuration MUST support defining ingress rules that map public hostnames to internal service addresses (e.g., pihole.chocolandiadc.com → http://pihole-web.default.svc.cluster.local:80)
- **FR-009**: System MUST allow authentication via Google OAuth for accessing protected services through Cloudflare Access
- **FR-010**: All Cloudflare infrastructure (tunnel creation, ingress routes, Access policies, DNS records) MUST be managed via Terraform provider with zero manual dashboard configuration (strict GitOps enforcement)

### Key Entities

- **Cloudflare Tunnel**: Represents the secure outbound connection from the K3s cluster to Cloudflare's edge network. Managed via Terraform `cloudflare_tunnel` resource. Key attributes include tunnel ID, tunnel token (secret), connection status, and ingress routing rules
- **Tunnel Token**: Sensitive credential that authenticates the tunnel connector to Cloudflare. Generated by Terraform tunnel resource, stored as a Kubernetes Secret, and mounted to the cloudflared pod
- **Ingress Rules**: Mapping configuration that defines which public hostnames/paths route to which internal services. Managed via Terraform `cloudflare_tunnel_config` resource (not dashboard). Includes source hostname, destination service URL, and optional HTTP headers
- **Cloudflare Access Policy**: Authorization rules managed via Terraform `cloudflare_access_application` and `cloudflare_access_policy` resources that specify which users/email domains can access which tunnel hostnames. Includes authentication method, allowed identities, and session duration
- **DNS Records**: CNAME records managed via Terraform `cloudflare_record` resource pointing public hostnames to tunnel CNAME target (auto-generated by Cloudflare for tunnel)
- **Tunnel Connector Pod**: Kubernetes deployment running the cloudflared container, responsible for maintaining the tunnel connection and routing traffic. Deployed via OpenTofu Kubernetes provider

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User can access internal services (e.g., Pi-hole admin interface) from any internet-connected device within 5 seconds of opening the tunnel URL
- **SC-002**: Unauthorized users are blocked from accessing internal services, with authentication challenge presented within 2 seconds
- **SC-003**: Tunnel automatically recovers from pod failures within 30 seconds without manual intervention
- **SC-004**: Zero public ports are exposed on the home router - all inbound traffic flows through Cloudflare's network
- **SC-005**: User can access at least 2 different internal services (Pi-hole admin dashboard and Grafana monitoring) through distinct tunnel routes (pihole.chocolandiadc.com and grafana.chocolandiadc.com)
- **SC-006**: All Cloudflare infrastructure (tunnel, ingress rules, Access policies, DNS records) is defined in Terraform code and can be recreated from scratch via `terraform apply` without any manual dashboard configuration
