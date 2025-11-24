# Feature Specification: GitHub Actions Self-Hosted Runner

**Feature Branch**: `017-github-actions-runner`
**Created**: 2025-11-24
**Status**: Draft
**Input**: User description: "quiero instalar un github self-hosted actions en el homelab"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run CI/CD Workflows on Local Infrastructure (Priority: P1)

As a developer, I want to execute GitHub Actions workflows on my homelab infrastructure so that I can build, test, and deploy applications using my local compute resources without relying on GitHub-hosted runners.

**Why this priority**: This is the core functionality of the feature - without a working runner, no CI/CD workflows can execute locally. This enables cost savings, faster builds with local caching, and access to internal network resources.

**Independent Test**: Can be fully tested by triggering a simple workflow (e.g., echo "Hello from homelab") and verifying it executes on the self-hosted runner.

**Acceptance Scenarios**:

1. **Given** a self-hosted runner is registered and online, **When** a workflow with `runs-on: self-hosted` is triggered, **Then** the job executes on the homelab runner and completes successfully.
2. **Given** a runner is connected, **When** I view the runner status in GitHub repository settings, **Then** the runner appears as "Idle" or "Active" depending on current workload.
3. **Given** a workflow is running, **When** the runner loses connectivity temporarily, **Then** the job can resume or restart gracefully upon reconnection.

---

### User Story 2 - Monitor Runner Health and Status (Priority: P2)

As an operator, I want to monitor the health and status of the self-hosted runner so that I can ensure CI/CD workflows have available compute resources and troubleshoot issues quickly.

**Why this priority**: Monitoring is essential for operational visibility but the runner must be functional first. This enables proactive maintenance and quick issue resolution.

**Independent Test**: Can be tested by checking runner metrics in the monitoring dashboard and verifying status indicators match actual runner state.

**Acceptance Scenarios**:

1. **Given** a runner is deployed, **When** I access the monitoring dashboard, **Then** I can see runner status (online/offline), active jobs count, and resource utilization.
2. **Given** a runner goes offline, **When** the runner is unavailable for more than 5 minutes, **Then** an alert notification is generated.
3. **Given** a runner is under heavy load, **When** CPU or memory usage exceeds thresholds, **Then** this is visible in the monitoring dashboard.

---

### User Story 3 - Scale Runners Based on Demand (Priority: P3)

As an operator, I want to have multiple runner instances available so that concurrent workflows can execute in parallel and the system can handle increased CI/CD demand.

**Why this priority**: Scaling is a nice-to-have after the basic runner is operational and monitored. It enables handling multiple simultaneous workflows.

**Independent Test**: Can be tested by triggering multiple workflows simultaneously and verifying they run in parallel on different runner instances.

**Acceptance Scenarios**:

1. **Given** multiple runner instances are configured, **When** several workflows are triggered simultaneously, **Then** jobs are distributed across available runners.
2. **Given** runner replicas are defined, **When** I scale up or down the number of runners, **Then** the change is reflected in GitHub and new runners become available.

---

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Runner pod crashes during job | ARC restarts pod; GitHub marks job as failed; user can re-run workflow |
| GitHub service unavailable | ARC retries connection with exponential backoff; runner shows offline in GitHub |
| Runner token expires | GitHub App tokens auto-rotate (1hr lifetime); ARC handles renewal automatically |
| Storage full | Job fails with storage error; alert triggered via Prometheus; manual cleanup required |
| Network interruption | ARC reconnects within 5 minutes (SC-003); in-flight job may fail and require re-run |

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST register self-hosted runners with a specified GitHub repository or organization
- **FR-002**: System MUST maintain persistent connection to GitHub Actions service to receive job assignments
- **FR-003**: System MUST execute GitHub Actions workflows that specify `runs-on: self-hosted` label
- **FR-004**: System MUST support custom labels for runner identification and workflow targeting
- **FR-005**: System MUST persist runner configuration and registration state across restarts
- **FR-006**: System MUST automatically reconnect to GitHub after temporary network interruptions
- **FR-007**: System MUST provide health status information accessible by monitoring systems
- **FR-008**: System MUST support running multiple concurrent jobs based on available resources
- **FR-009**: System MUST clean up job artifacts and temporary files after workflow completion
- **FR-010**: System MUST securely store runner registration tokens and credentials

### Key Entities

- **Runner**: A compute instance that executes GitHub Actions jobs. Attributes: name, labels, status (online/offline/busy), registered repository/organization.
- **Job**: A unit of work within a GitHub Actions workflow assigned to a runner. Attributes: workflow ID, job ID, status, start time, duration.
- **Runner Token**: Authentication credential used to register and authenticate the runner with GitHub. Requires secure storage and periodic renewal.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Runner registers successfully with GitHub and appears as online within 2 minutes of deployment
- **SC-002**: Workflows targeting `runs-on: self-hosted` execute on the homelab runner 100% of the time when the runner is available
- **SC-003**: Runner reconnects automatically after network interruption within 5 minutes without manual intervention
- **SC-004**: Runner health status is visible in the homelab monitoring dashboard
- **SC-005**: System supports at least 2 concurrent job executions with proper resource isolation
- **SC-006**: Runner survives pod/container restarts without requiring re-registration (persistent state)

## Assumptions

- The GitHub repository or organization is accessible and the user has admin permissions to register runners
- The homelab Kubernetes cluster (K3s) has sufficient compute resources (CPU, memory) to run CI/CD jobs
- Network connectivity between the homelab and GitHub (github.com) is available
- The existing monitoring infrastructure (Prometheus/Grafana) will be used for runner monitoring
- Docker-in-Docker or rootless container execution is acceptable for building container images in workflows
- Standard runner labels (self-hosted, linux, x64) are sufficient; custom labels can be added as needed
- Runner will be deployed as a Kubernetes Deployment with persistent storage for configuration

## Dependencies

- Existing K3s cluster infrastructure (002-k3s-mvp-eero)
- Persistent storage via local-path-provisioner
- Traefik Ingress (for any web-based management interface, if applicable)
- Monitoring stack - Prometheus/Grafana (014-monitoring-alerts)
- GitHub account with repository/organization admin access

## Out of Scope

- Self-hosted runners for GitLab, Bitbucket, or other CI/CD platforms
- Auto-scaling based on queue depth (can be added in future iteration)
- Integration with external secret management systems (Vault, etc.)
- Custom runner images with pre-installed tools beyond the standard GitHub runner
- Multi-architecture support (ARM runners) - only x64 for initial implementation
