# Feature Specification: Nexus Repository Manager

**Feature Branch**: `016-nexus-repository`
**Created**: 2025-11-24
**Status**: Draft
**Input**: User description: "Reemplazar Docker Registry con Nexus Repository, habilitando repositorios para docker, helm, npm, maven y apt"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Docker Images Management (Priority: P1)

As a developer, I need to push and pull Docker container images to/from a private repository so that I can store and distribute my application containers within the homelab cluster.

**Why this priority**: Docker images are the primary artifact type for Kubernetes deployments. Without Docker repository support, no containerized applications can be stored or deployed from the private registry.

**Independent Test**: Can be fully tested by pushing a test Docker image (`docker push nexus.chocolandiadc.local/test-image:latest`) and pulling it back (`docker pull nexus.chocolandiadc.local/test-image:latest`), then verifying the image runs correctly.

**Acceptance Scenarios**:

1. **Given** a developer has built a Docker image locally, **When** they push the image to Nexus using standard Docker commands, **Then** the image is stored and visible in the Nexus web interface
2. **Given** a Docker image exists in Nexus, **When** a developer or Kubernetes pulls the image, **Then** the image downloads successfully and can be used
3. **Given** a user attempts to push/pull without authentication, **When** the operation is executed, **Then** the system denies access with a clear error message

---

### User Story 2 - Helm Charts Repository (Priority: P2)

As a DevOps engineer, I need to store and retrieve Helm charts from a private repository so that I can manage Kubernetes application deployments using versioned chart packages.

**Why this priority**: Helm charts are the standard way to package and deploy applications in Kubernetes. Having a private Helm repository enables consistent application deployments.

**Independent Test**: Can be tested by pushing a Helm chart (`helm push mychart.tgz nexus-helm`), adding the repo (`helm repo add nexus https://nexus.chocolandiadc.local/repository/helm-hosted/`), and installing the chart (`helm install myapp nexus/mychart`).

**Acceptance Scenarios**:

1. **Given** a DevOps engineer has a packaged Helm chart, **When** they push the chart to Nexus, **Then** the chart is stored and indexed for retrieval
2. **Given** a Helm chart exists in Nexus, **When** a user searches or downloads the chart, **Then** the chart is available through standard Helm commands
3. **Given** multiple versions of a chart exist, **When** a user requests a specific version, **Then** the correct version is served

---

### User Story 3 - NPM Package Repository (Priority: P3)

As a frontend developer, I need to publish and install NPM packages from a private repository so that I can share JavaScript/TypeScript libraries within the organization.

**Why this priority**: NPM support enables sharing private JavaScript packages and caching public packages for faster builds and offline access.

**Independent Test**: Can be tested by publishing a test package (`npm publish --registry https://nexus.chocolandiadc.local/repository/npm-hosted/`) and installing it in another project (`npm install mypackage --registry https://nexus.chocolandiadc.local/repository/npm-group/`).

**Acceptance Scenarios**:

1. **Given** a developer has an NPM package, **When** they publish to Nexus, **Then** the package is stored and available for installation
2. **Given** a package exists in Nexus, **When** another project requests the package, **Then** it installs correctly with all dependencies resolved

---

### User Story 4 - Maven Artifacts Repository (Priority: P3)

As a Java developer, I need to publish and retrieve Maven artifacts from a private repository so that I can share Java libraries and manage dependencies within the organization.

**Why this priority**: Maven support enables Java development workflows with private artifact sharing and proxy caching of public dependencies.

**Independent Test**: Can be tested by deploying a JAR (`mvn deploy`) and depending on it from another project (`mvn install` with Nexus configured in settings.xml).

**Acceptance Scenarios**:

1. **Given** a developer has a Maven artifact, **When** they deploy to Nexus, **Then** the artifact is stored with correct metadata
2. **Given** a Maven artifact exists in Nexus, **When** another project declares it as a dependency, **Then** Maven resolves and downloads the artifact

---

### User Story 5 - APT Package Repository (Priority: P4)

As a system administrator, I need to host and distribute Debian/APT packages from a private repository so that I can manage custom software packages for Debian-based systems.

**Why this priority**: APT support enables distribution of custom Debian packages for infrastructure components and internal tools.

**Independent Test**: Can be tested by uploading a .deb package, configuring a client machine to use the repository, and installing the package with `apt install`.

**Acceptance Scenarios**:

1. **Given** an administrator has a Debian package, **When** they upload to Nexus, **Then** the package is stored and indexed
2. **Given** an APT repository is configured on a client, **When** the user runs apt update and apt install, **Then** packages install correctly from Nexus

---

### Edge Cases

- What happens when storage capacity is exceeded? System should alert administrators and reject new uploads gracefully
- How does the system handle concurrent uploads of the same artifact version? System should handle conflicts appropriately (reject duplicate or allow based on repository policy)
- What happens when Nexus is unavailable? Kubernetes should fail gracefully with clear error messages, and cached images (if any) should continue working
- How does the system handle malformed artifacts? Validation should reject invalid packages with descriptive error messages

## Clarifications

### Session 2025-11-24

- Q: Observability integration level? → A: Agregar métricas de Nexus al Grafana existente del homelab
- Q: Homepage documentation level? → A: Enlaces + instrucciones básicas de uso por tipo de repo

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Docker registry compatible with Docker v2 API for pushing and pulling container images
- **FR-002**: System MUST provide a Helm repository for storing and serving Helm charts
- **FR-003**: System MUST provide an NPM registry for publishing and retrieving JavaScript packages
- **FR-004**: System MUST provide a Maven repository for deploying and resolving Java artifacts
- **FR-005**: System MUST provide an APT repository for hosting Debian packages
- **FR-006**: System MUST require authentication for all write operations (push/publish/deploy)
- **FR-007**: System MUST provide a web-based administration interface for repository management
- **FR-008**: System MUST persist all data across restarts using persistent storage
- **FR-009**: System MUST be accessible via HTTPS with valid TLS certificates
- **FR-010**: System MUST expose repositories through the cluster ingress controller
- **FR-011**: System MUST integrate with cluster DNS for internal and external access
- **FR-012**: System MUST support proxy/cache repositories for upstream public registries (Docker Hub, npmjs.org, Maven Central)
- **FR-013**: System MUST replace the existing Docker Registry deployment (removal of current registry module)
- **FR-014**: System MUST expose Prometheus metrics for integration with cluster Grafana dashboard
- **FR-015**: System MUST be added to Homepage dashboard with service links and documentation

### Key Entities

- **Repository**: A storage location for artifacts of a specific format (Docker, Helm, NPM, Maven, APT). Types include hosted (local storage), proxy (cache from upstream), and group (aggregation of multiple repositories)
- **Artifact**: A versioned package stored in a repository (Docker image, Helm chart, NPM package, Maven JAR, Debian package)
- **User/Credentials**: Authentication identity for accessing repositories with defined permissions
- **Blob Store**: Physical storage location where artifact binaries are persisted

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can push and pull Docker images within 30 seconds for typical image sizes (under 500MB)
- **SC-002**: All five repository types (Docker, Helm, NPM, Maven, APT) are operational and accessible
- **SC-003**: System maintains 99% availability during normal cluster operations
- **SC-004**: Web administration interface is accessible and functional for repository management
- **SC-005**: Authentication prevents all unauthorized write access (100% of unauthenticated push attempts rejected)
- **SC-006**: Data persists correctly across pod restarts and cluster reboots
- **SC-007**: Existing Docker Registry is fully replaced without data loss for any images currently stored

## Assumptions

- Nexus Repository OSS (open source version) provides sufficient functionality for all repository types
- The existing Docker Registry has minimal critical images that need migration (or can be rebuilt)
- Storage requirements are similar to current registry (30Gi or adjustable as needed)
- Single replica deployment is acceptable for homelab use (no high availability requirement)
- Users will manage credentials through Nexus web interface or configured admin automation
- Proxy repositories for public registries are optional and can be configured post-deployment

## Out of Scope

- High availability / multi-node Nexus deployment
- LDAP/Active Directory integration for user management
- Automated image vulnerability scanning
- Backup and disaster recovery automation (manual procedures acceptable)
- PyPI (Python) repository support (can be added later if needed)
- Raw/generic file repository support (can be added later if needed)
