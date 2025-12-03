# Feature Specification: Home Assistant with Prometheus Temperature Monitoring

**Feature Branch**: `018-home-assistant`
**Created**: 2025-12-02
**Status**: Draft
**Scope**: Phase 1 - Base Installation + Prometheus Integration (Govee integration deferred to Phase 2)
**Input**: User description: "quiero instalar Home Assistant e integrar con Prometheus para monitorear temperatura. La integración con Govee será manual vía Alexa en una fase posterior."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Prometheus Temperature Visualization (Priority: P1) 🎯 MVP

As a homelab administrator, I want to view CPU temperature from Prometheus in my Home Assistant dashboard, so that I have a centralized view of my homelab metrics alongside future smart home devices.

**Why this priority**: This establishes the base Home Assistant installation and Prometheus integration, which is the foundation for any future automations.

**Independent Test**: Can be fully tested by accessing Home Assistant dashboard and verifying the temperature sensor shows current CPU temperature from Prometheus.

**Acceptance Scenarios**:

1. **Given** Home Assistant is running on the cluster, **When** I access the dashboard, **Then** I see a temperature sensor card showing CPU temperature from Prometheus
2. **Given** the Prometheus sensor is configured, **When** the CPU temperature changes, **Then** the Home Assistant dashboard reflects the updated value within 60 seconds
3. **Given** Prometheus is temporarily unavailable, **When** connection is restored, **Then** the sensor resumes updating without manual intervention

---

### User Story 2 - Home Assistant Dashboard Access (Priority: P2)

As a homelab administrator, I want to access Home Assistant's web dashboard securely from my local network and through Cloudflare Zero Trust, so that I can monitor my homelab from anywhere.

**Why this priority**: Provides secure access to the Home Assistant platform from both local and remote locations.

**Independent Test**: Can be fully tested by accessing the Home Assistant dashboard via both configured URLs and verifying TLS certificates are valid.

**Acceptance Scenarios**:

1. **Given** Home Assistant is deployed on the cluster, **When** I navigate to homeassistant.chocolandiadc.local, **Then** I see the login page with valid local-ca TLS certificate
2. **Given** Home Assistant is deployed on the cluster, **When** I navigate to homeassistant.chocolandiadc.com, **Then** I see the login page with valid Let's Encrypt TLS certificate
3. **Given** I am authenticated to Home Assistant, **When** I view the dashboard, **Then** I see the temperature sensor from Prometheus

---

### Edge Cases

- What happens if Prometheus is unavailable for an extended period? (Sensor shows "unavailable" state, logs the issue)
- How does the system behave during Home Assistant restarts? (Configuration is persisted and restored from PVC)
- What happens if the temperature metric is not available in Prometheus? (Sensor shows "unknown" state with error in logs)

---

## Deferred to Phase 2 (Manual Implementation)

The following items are explicitly OUT OF SCOPE for this feature and will be implemented manually by the user after Phase 1 is complete:

- **Govee Smart Plug Integration**: User will configure Govee integration manually, potentially via Alexa skill
- **Temperature-Based Automation**: Automation to control smart plug based on temperature thresholds
- **Ntfy Notifications**: Push notifications for temperature events
- **Hysteresis Logic**: ON at 50°C, OFF at 45°C cycling prevention

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy Home Assistant as a containerized application on the existing K3s cluster
- **FR-002**: System MUST expose Home Assistant through Traefik ingress at both homeassistant.chocolandiadc.local (local-ca certificate) and homeassistant.chocolandiadc.com (Let's Encrypt certificate via Cloudflare)
- **FR-003**: System MUST receive CPU temperature data from node_exporter metrics in the existing Prometheus monitoring stack via ha-prometheus-sensor integration
- **FR-004**: System MUST display temperature sensor value on the Home Assistant dashboard
- **FR-005**: System MUST persist Home Assistant configuration across pod restarts using a PersistentVolume
- **FR-006**: System MUST install HACS (Home Assistant Community Store) to enable custom integrations
- **FR-007**: System MUST poll Prometheus temperature metric every 30 seconds

### Key Entities

- **Home Assistant Instance**: The core home automation platform running in the cluster
- **Temperature Sensor**: CPU temperature metric from node_exporter (e.g., `node_hwmon_temp_celsius`) displayed as a Home Assistant sensor entity
- **HACS**: Home Assistant Community Store for installing the ha-prometheus-sensor custom integration

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Home Assistant dashboard is accessible within 3 seconds of page load
- **SC-002**: Temperature sensor updates within 60 seconds of Prometheus metric change
- **SC-003**: Home Assistant maintains 99% uptime during normal cluster operations
- **SC-004**: Configuration persists across 100% of pod restarts without data loss
- **SC-005**: Both local and external domains serve valid TLS certificates

## Clarifications

### Session 2025-12-02

- Q: What domain/URL should Home Assistant use? → A: Both domains (homeassistant.chocolandiadc.local with local-ca + homeassistant.chocolandiadc.com with Let's Encrypt via Cloudflare)
- Q: What scope for Phase 1? → A: Only visualize temperature from Prometheus in HA dashboard (no automation, no Govee)

## Assumptions

- CPU temperature metrics from node_exporter are already being collected and available in Prometheus/Grafana
- The existing Cloudflare Zero Trust setup will be extended to include Home Assistant access
- User will manually configure Govee integration (via Alexa or native) after Phase 1 is complete
