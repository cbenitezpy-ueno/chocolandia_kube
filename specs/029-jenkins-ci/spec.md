# Feature Specification: Jenkins CI Deployment

**Feature Branch**: `029-jenkins-ci`
**Created**: 2026-01-07
**Status**: Draft
**Input**: User description: "GitHub Actions se va a comenzar a cobrar, entonces quiero reemplazar con Jenkins, me haces un deploy de Jenkins con los plugins necesarios para generar imagenes en Nexus de los frameworks que uso: Java/Maven, Node.js, Python, Go"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build and Push Docker Image (Priority: P1)

As a developer, I want to build a Docker image from my project source code and push it to the private Nexus registry so that I can deploy my applications to the K3s cluster.

**Why this priority**: This is the core functionality that replaces GitHub Actions - without the ability to build and push images, the CI system has no value.

**Independent Test**: Can be fully tested by creating a simple Dockerfile project, triggering a build in Jenkins, and verifying the image appears in Nexus at `docker.nexus.chocolandiadc.local`.

**Acceptance Scenarios**:

1. **Given** a project with a Dockerfile in a Git repository, **When** I trigger a Jenkins build, **Then** Jenkins builds the Docker image and pushes it to Nexus with the correct tag
2. **Given** a successful build, **When** I check Nexus docker-hosted repository, **Then** the image is available and can be pulled
3. **Given** invalid Dockerfile syntax, **When** the build runs, **Then** the build fails with a clear error message

---

### User Story 2 - Java/Maven Project Build (Priority: P2)

As a developer, I want Jenkins to compile my Java/Maven projects before building the Docker image so that I can ensure code compiles correctly.

**Why this priority**: Java/Maven is a common framework that requires compilation before containerization.

**Independent Test**: Can be tested by creating a simple Maven project with unit tests, triggering build, and verifying compilation and test results.

**Acceptance Scenarios**:

1. **Given** a Maven project with pom.xml, **When** Jenkins builds the project, **Then** Maven compiles the code and runs tests
2. **Given** Maven tests fail, **When** the build runs, **Then** the build is marked as failed and Docker image is not pushed

---

### User Story 3 - Node.js Project Build (Priority: P2)

As a developer, I want Jenkins to install dependencies and run tests for my Node.js projects before building Docker images.

**Why this priority**: Node.js projects require npm/yarn dependency installation and often have test suites.

**Independent Test**: Can be tested with a simple Node.js project with package.json and test scripts.

**Acceptance Scenarios**:

1. **Given** a Node.js project with package.json, **When** Jenkins builds the project, **Then** npm install runs and tests execute
2. **Given** npm tests fail, **When** the build runs, **Then** the build is marked as failed

---

### User Story 4 - Python Project Build (Priority: P2)

As a developer, I want Jenkins to set up Python virtual environments and run tests for my Python projects.

**Why this priority**: Python projects need dependency management and testing before containerization.

**Independent Test**: Can be tested with a simple Python project with requirements.txt and pytest tests.

**Acceptance Scenarios**:

1. **Given** a Python project with requirements.txt, **When** Jenkins builds, **Then** dependencies are installed and tests run
2. **Given** pytest tests fail, **When** the build runs, **Then** the build is marked as failed

---

### User Story 5 - Go Project Build (Priority: P2)

As a developer, I want Jenkins to compile and test my Go projects before building Docker images.

**Why this priority**: Go projects require compilation and testing.

**Independent Test**: Can be tested with a simple Go module with go.mod and unit tests.

**Acceptance Scenarios**:

1. **Given** a Go project with go.mod, **When** Jenkins builds, **Then** go build and go test execute successfully
2. **Given** Go tests fail, **When** the build runs, **Then** the build is marked as failed

---

### User Story 6 - Access Jenkins Web UI (Priority: P3)

As an administrator, I want to access the Jenkins web interface to configure jobs and monitor builds.

**Why this priority**: Administrative access is needed but builds can be triggered via webhooks or CLI.

**Independent Test**: Can be tested by accessing the Jenkins URL and logging in with admin credentials.

**Acceptance Scenarios**:

1. **Given** Jenkins is deployed, **When** I access the Jenkins URL, **Then** I see the login page
2. **Given** valid admin credentials, **When** I login, **Then** I can access the Jenkins dashboard and configure jobs

---

### Edge Cases

- What happens when Nexus registry is unavailable during push? Build should fail with clear error and retry guidance.
- What happens when a build takes longer than expected? Configurable timeout with graceful termination.
- How does the system handle concurrent builds? Single controller with 2 executors; builds queue if all executors busy. Agent scaling out of scope for MVP.
- What happens when disk space is low on Jenkins? Alert generated and old builds cleaned up.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy Jenkins controller in the K3s cluster
- **FR-002**: System MUST include plugins for Docker image building and pushing
- **FR-003**: System MUST include Maven plugin for Java project builds
- **FR-004**: System MUST include NodeJS plugin for Node.js project builds
- **FR-005**: System MUST include pyenv-pipeline plugin for Python project builds
- **FR-006**: System MUST include Go plugin for Go project builds
- **FR-007**: System MUST be able to authenticate with Nexus docker registry (docker.nexus.chocolandiadc.local)
- **FR-008**: System MUST persist Jenkins configuration and job data across pod restarts
- **FR-009**: System MUST expose Jenkins UI via Traefik ingress with TLS (jenkins.chocolandiadc.local)
- **FR-010**: System MUST be accessible via Cloudflare Zero Trust (jenkins.chocolandiadc.com)
- **FR-011**: System MUST integrate with existing monitoring stack (Prometheus metrics endpoint)
- **FR-012**: System MUST send build notifications via ntfy (homelab-alerts topic)

### Key Entities

- **Jenkins Controller**: Main Jenkins server managing jobs, plugins, and configuration
- **Build Job**: Definition of how to build a specific project (pipeline or freestyle)
- **Build Artifact**: Output of a build process (Docker image, compiled binaries)
- **Credentials**: Stored secrets for accessing Nexus, Git repositories

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can trigger a build and have a Docker image pushed to Nexus within 10 minutes for a typical project
- **SC-002**: Jenkins UI is accessible from both LAN (jenkins.chocolandiadc.local) and remotely via Cloudflare Zero Trust (jenkins.chocolandiadc.com)
- **SC-003**: Build metrics are visible in Grafana dashboard
- **SC-004**: Build failures generate ntfy notifications within 1 minute of failure
- **SC-005**: Jenkins survives pod restarts without losing configuration or job history
- **SC-006**: All four language toolchains (Java/Maven, Node.js, Python, Go) are available and functional for building projects

## Assumptions

- Nexus is already deployed and accessible at nexus.chocolandiadc.local with docker-hosted repository configured
- Traefik ingress controller is available for routing
- Cloudflare Zero Trust tunnel is configured and can add new applications
- cert-manager with local-ca issuer is available for TLS certificates
- Prometheus/Grafana monitoring stack is deployed
- ntfy is deployed for notifications
- Persistent storage via local-path-provisioner is available

## Out of Scope

- GitHub/GitLab webhook integration (can be added later)
- Jenkins agents/slaves for distributed builds (single controller for MVP)
- Backup/restore automation for Jenkins data
- SSO/OIDC integration (will use Jenkins native authentication)
