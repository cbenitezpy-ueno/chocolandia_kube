# Feature Specification: Fix Ntfy Notifications and Add Alerts to Homepage

**Feature Branch**: `026-ntfy-homepage-alerts`
**Created**: 2025-12-31
**Status**: Draft
**Input**: User description: "no me estan llegando las notificaciones via ntfy, adicionalmente quiero ver las alertas en homepage"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Receive Alert Notifications on Mobile (Priority: P1)

As a homelab administrator, I want to receive push notifications on my mobile device when Prometheus alerts fire, so that I can respond to infrastructure issues promptly even when I'm not at my computer.

**Why this priority**: This is the core functionality that is currently broken. Without notifications, critical alerts go unnoticed, which defeats the purpose of the monitoring system.

**Independent Test**: Can be fully tested by triggering a test alert and verifying the notification arrives on the ntfy mobile app within 60 seconds.

**Acceptance Scenarios**:

1. **Given** Alertmanager is configured to send to ntfy, **When** a Prometheus alert fires (e.g., NodeDown), **Then** a push notification appears on devices subscribed to the homelab-alerts topic within 60 seconds
2. **Given** an alert is firing, **When** the alert resolves, **Then** a "resolved" notification is sent to the ntfy topic
3. **Given** the ntfy service is healthy, **When** I manually send a test message via curl to ntfy internal endpoint, **Then** the message appears on subscribed devices

---

### User Story 2 - View Active Alerts on Homepage Dashboard (Priority: P2)

As a homelab administrator, I want to see a summary of active Prometheus alerts on my Homepage dashboard, so that I have a quick visual overview of cluster health without opening Grafana or Alertmanager.

**Why this priority**: This provides convenience and visibility, but is not critical since alerts can still be viewed in Grafana/Alertmanager directly.

**Independent Test**: Can be fully tested by viewing Homepage and verifying the alerts widget displays current firing alerts with severity indicators.

**Acceptance Scenarios**:

1. **Given** Homepage is configured with an alerts widget, **When** I open the Homepage dashboard, **Then** I see a widget showing the count of firing alerts grouped by severity (critical, warning)
2. **Given** there are active critical alerts, **When** I view the Homepage dashboard, **Then** critical alerts are visually distinguished (e.g., red indicator)
3. **Given** there are no firing alerts, **When** I view the Homepage dashboard, **Then** the widget shows a healthy status indicator (e.g., green checkmark, "All systems operational")

---

### User Story 3 - Verify Notification Delivery Status (Priority: P3)

As a homelab administrator, I want to verify that the ntfy notification pipeline is working correctly, so that I can trust that alerts will reach me.

**Why this priority**: This is a diagnostic/validation capability, useful for troubleshooting but not essential for day-to-day operations.

**Independent Test**: Can be tested by running a diagnostic command that confirms end-to-end notification delivery.

**Acceptance Scenarios**:

1. **Given** I want to test the notification pipeline, **When** I trigger a test alert from Alertmanager, **Then** I can confirm the notification was received and log successful delivery
2. **Given** ntfy is receiving messages, **When** I check ntfy logs, **Then** I see incoming webhook requests from Alertmanager with proper payload format

---

### Edge Cases

- What happens when ntfy is unreachable? Alertmanager should queue/retry notifications.
- What happens when there are many alerts firing simultaneously? Notifications should be grouped to avoid spam.
- How does Homepage handle Prometheus/Alertmanager being temporarily unavailable? Widget should show "unavailable" status gracefully.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deliver Prometheus alert notifications to ntfy within 60 seconds of alert firing
- **FR-002**: System MUST include alert name, severity, and description in ntfy notifications
- **FR-003**: System MUST send "resolved" notifications when alerts clear
- **FR-004**: Homepage MUST display a widget showing count of active alerts by severity
- **FR-005**: Homepage alerts widget MUST update automatically (without page refresh)
- **FR-006**: System MUST support subscribing to ntfy topic from mobile app or web browser
- **FR-007**: Notification format MUST be readable on mobile devices (concise title, meaningful description)

### Key Entities

- **Alert**: A Prometheus alert with name, severity (critical/warning/info), status (firing/resolved), description, and timestamp
- **Notification**: A push message sent to ntfy topic containing alert information
- **Widget**: A Homepage component that queries Prometheus/Alertmanager API and displays alert summary

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of critical alerts result in push notification delivery within 60 seconds
- **SC-002**: Homepage alerts widget loads and displays data within 3 seconds
- **SC-003**: Zero missed notifications for alerts with duration greater than 5 minutes
- **SC-004**: Alert resolution notifications delivered for all resolved alerts
- **SC-005**: Homepage dashboard provides at-a-glance cluster health status (green/yellow/red indicator based on alert severity)

## Assumptions

- ntfy is deployed and accessible within the cluster at the internal service endpoint
- Alertmanager is configured with webhook receivers pointing to ntfy (already in place per current config)
- Homepage supports Prometheus/Alertmanager widgets (to be verified during implementation)
- Mobile devices have the ntfy app installed and subscribed to the homelab-alerts topic via external URL
- The current issue may be related to message format (Alertmanager sends JSON that ntfy may not parse correctly as user-friendly notifications without a proper template)
