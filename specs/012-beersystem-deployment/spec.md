# Feature Specification: BeerSystem Cluster Deployment

**Feature Branch**: `012-beersystem-deployment`
**Created**: 2025-11-15
**Status**: Draft
**Input**: User description: "tengo la aplicacion /Users/cbenitez/beersystem que ahora tiene el ambiente de dev local y el de pruebas en aws. quiero deployar la app en el cluster, que tenga un endpoing en chocolandiadc.com, una base de datos pg, con un usuario que pueda hacer cambios de estructura y que desde argocd se sincronice."

## Clarifications

### Session 2025-11-15

- Q: What type of application is beersystem and is it ready for Kubernetes deployment? → A: Web application already containerized with Dockerfile, ready for direct Kubernetes deployment without major modifications
- Q: Where should Kubernetes manifests be stored for ArgoCD to monitor? → A: In beersystem repo under k8s/ directory
- Q: What should be the name of the PostgreSQL database for beersystem? → A: beersystem_stage
- Q: Should the application use the root domain or a subdomain? → A: Subdomain beer.chocolandiadc.com
- Q: Does the existing PostgreSQL cluster support creating new databases with users having schema modification privileges? → A: Yes, supports multiple databases and users with DDL privileges (standard PostgreSQL functionality)
- Q: Should the system use cert-manager + Traefik ingress OR Cloudflare Tunnel for public access with TLS? → A: Use Cloudflare Tunnel (no cert-manager, no Traefik Ingress needed - TLS handled by Cloudflare)
- Q: What does "response within 2 seconds" mean in SC-001 (TTFB, full page load, or time to interactive)? → A: Time to First Byte (TTFB) < 2 seconds
- Q: Does beersystem application expose /health and /health/ready endpoints for Kubernetes probes? → A: Endpoints being implemented now in both backend and frontend (will be available before cluster deployment)
- Q: Should SC-002 (99.5% uptime) and SC-007 (100 concurrent users) be hard MVP requirements for homelab staging? → A: Mark as aspirational/future enhancement (not MVP requirements for staging environment)
- Q: Should there be an explicit test that validates database data persistence across pod restarts (FR-007)? → A: Yes, add explicit persistence test (insert data, restart PostgreSQL pod, verify data survives)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Application Accessible via Domain (Priority: P1)

End users need to access the beersystem application through a public URL at beer.chocolandiadc.com so they can use the system from any browser without needing to know internal cluster details.

**Why this priority**: This is the minimum viable deployment - users must be able to reach the application. Without this, no other features matter.

**Independent Test**: Can be fully tested by navigating to beer.chocolandiadc.com in a browser and verifying the application loads. Delivers immediate value by making the application publicly accessible.

**Acceptance Scenarios**:

1. **Given** the application is deployed to the cluster, **When** a user navigates to beer.chocolandiadc.com, **Then** the application homepage loads successfully with valid TLS certificate
2. **Given** the domain is configured, **When** a user accesses the application via HTTP, **Then** they are automatically redirected to HTTPS
3. **Given** the application is running, **When** a user performs basic application operations through the web interface, **Then** all features respond correctly

---

### User Story 2 - Database Schema Management (Priority: P2)

Developers and database administrators need the ability to modify the database structure (create tables, add columns, create indexes, etc.) so they can evolve the application schema as requirements change.

**Why this priority**: Essential for ongoing development and maintenance. The application cannot evolve without the ability to modify its data structure.

**Independent Test**: Can be tested by connecting to the database with the designated user credentials and executing DDL operations (CREATE TABLE, ALTER TABLE, DROP TABLE). Delivers value by enabling schema evolution.

**Acceptance Scenarios**:

1. **Given** a database user with schema modification privileges, **When** the user executes CREATE TABLE statements, **Then** new tables are created successfully
2. **Given** existing database tables, **When** the authorized user executes ALTER TABLE statements, **Then** schema changes are applied successfully
3. **Given** the authorized user credentials, **When** attempting to connect from the application, **Then** connection succeeds and schema operations can be performed
4. **Given** unauthorized credentials, **When** attempting schema modifications, **Then** operations are rejected with appropriate error messages

---

### User Story 3 - Automated GitOps Deployment (Priority: P3)

The operations team needs ArgoCD to automatically synchronize application changes from the git repository to the cluster so that deployments are consistent, auditable, and require minimal manual intervention.

**Why this priority**: Improves operational efficiency and reduces deployment errors. While valuable, the application can function without automated sync initially using manual deployments.

**Independent Test**: Can be tested by making a change to the application manifests in git, committing the change, and verifying ArgoCD detects and applies the change automatically. Delivers value by automating deployment workflows.

**Acceptance Scenarios**:

1. **Given** ArgoCD is configured to monitor the application repository, **When** a new commit is pushed to the tracked branch, **Then** ArgoCD detects the change within the configured polling interval
2. **Given** ArgoCD detects a configuration change, **When** auto-sync is enabled, **Then** the changes are automatically applied to the cluster
3. **Given** the application is deployed via ArgoCD, **When** viewing the ArgoCD dashboard, **Then** the application status shows as "Healthy" and "Synced"
4. **Given** a synchronization fails, **When** viewing ArgoCD, **Then** error details are clearly displayed with actionable information

---

### Edge Cases

- What happens when the database connection is lost during application operation?
- How does the system handle DNS propagation delays for the beer.chocolandiadc.com domain?
- What occurs if ArgoCD loses connectivity to the git repository?
- How does the application behave when database schema changes are in progress?
- What happens if multiple database users attempt conflicting schema modifications simultaneously?
- What occurs if Cloudflare Tunnel connection drops or cloudflared pod restarts?
- What occurs when the cluster runs out of resources (CPU, memory, storage)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy the beersystem application to the Kubernetes cluster
- **FR-002**: System MUST provide a publicly accessible endpoint at beer.chocolandiadc.com with valid TLS encryption
- **FR-003**: System MUST provision a PostgreSQL database named "beersystem_stage" for the application
- **FR-004**: System MUST create a database user with privileges to perform schema modifications (CREATE, ALTER, DROP operations on tables, indexes, and other database objects)
- **FR-005**: System MUST configure ArgoCD to monitor the beersystem git repository (k8s/ directory) and synchronize changes to the cluster
- **FR-006**: Application MUST be able to connect to the PostgreSQL database using provided credentials
- **FR-007**: System MUST ensure the database persists data across pod restarts and failures (validated by explicit test: insert data, restart PostgreSQL pod, verify data survives)
- **FR-008**: System MUST route traffic from beer.chocolandiadc.com to the correct application pods within the cluster
- **FR-009**: System MUST provide health checks to verify application availability (liveness probe on /health endpoint, readiness probe on /health/ready endpoint)
- **FR-010**: ArgoCD MUST display the sync status and health of the deployed application

### Key Entities

- **Application Instance**: The beersystem application deployed as containers in the cluster, handling user requests and business logic
- **Database Instance**: PostgreSQL database named "beersystem_stage" storing application data, with persistent storage
- **Database User**: Privileged user account with permissions to modify database schema structure in beersystem_stage database
- **DNS Endpoint**: beer.chocolandiadc.com subdomain (CNAME to Cloudflare Tunnel)
- **Cloudflare Tunnel Route**: Ingress rule routing beer.chocolandiadc.com to beersystem service
- **ArgoCD Application**: GitOps resource tracking the desired state of the deployment in git
- **TLS Certificate**: SSL/TLS certificate managed by Cloudflare Universal SSL for beer.chocolandiadc.com

## Success Criteria *(mandatory)*

### Measurable Outcomes

**MVP Requirements:**
- **SC-001**: Users can access the application at beer.chocolandiadc.com and receive Time to First Byte (TTFB) within 2 seconds
- **SC-003**: Database schema changes can be applied within 5 minutes of execution
- **SC-004**: Code changes committed to the repository are deployed to the cluster within 10 minutes via ArgoCD
- **SC-005**: Zero manual intervention required for standard application deployments after initial setup
- **SC-006**: Database data persists through application restarts with zero data loss

**Aspirational (Future Enhancement):**
- **SC-002**: Application maintains 99.5% uptime measured over a 30-day period *(requires HA configuration: multiple replicas, pod disruption budgets)*
- **SC-007**: Application handles at least 100 concurrent users without performance degradation *(requires load testing and performance tuning)*

## Scope *(mandatory)*

### In Scope

- Deploying the existing beersystem application to the Kubernetes cluster
- Configuring DNS and Cloudflare Tunnel routing for beer.chocolandiadc.com subdomain
- Provisioning PostgreSQL database with persistent storage
- Creating database user with schema modification privileges
- Configuring ArgoCD for GitOps-based deployment
- TLS/SSL encryption provided by Cloudflare (automatic certificate management)
- Application health monitoring integration

### Out of Scope

- Modifying the beersystem application code itself
- Creating new application features or functionality
- Migrating existing data from AWS or local environments to the new database
- Setting up monitoring and alerting dashboards (beyond basic health checks)
- Backup and disaster recovery procedures
- Performance tuning or optimization of the application code
- User authentication or authorization systems (unless already part of beersystem)
- Multi-region or high-availability configurations beyond single cluster deployment

## Dependencies *(mandatory)*

### External Dependencies

- Existing Kubernetes cluster (chocolandiadc) must be operational
- DNS provider access to configure chocolandiadc.com domain
- ArgoCD must be installed and configured in the cluster (from feature 008-gitops-argocd)
- PostgreSQL cluster with support for multiple databases and user privilege management (from feature 011-postgresql-cluster)
- Cloudflare Tunnel for public access with TLS termination at Cloudflare edge (from feature 004-cloudflare-zerotrust)
- Beersystem git repository with Kubernetes manifests in k8s/ directory

### Internal Dependencies

- Feature 002-k3s-mvp-eero: Kubernetes cluster infrastructure
- Feature 004-cloudflare-zerotrust: Cloudflare Tunnel for secure public access
- Feature 008-gitops-argocd: ArgoCD GitOps deployment
- Feature 011-postgresql-cluster: PostgreSQL database platform

## Assumptions *(mandatory)*

- The beersystem application source code is accessible at /Users/cbenitez/beersystem
- The beersystem application is already containerized with an existing Dockerfile and is ready for Kubernetes deployment
- The application will expose /health and /health/ready endpoints on port 8000 for Kubernetes liveness and readiness probes (implementation in progress)
- The application uses standard PostgreSQL connection methods (connection string, environment variables, or config file)
- The chocolandiadc.com domain is owned and managed via Cloudflare
- The cluster has sufficient resources (CPU, memory, storage) for the application and database
- Cloudflare Tunnel is already configured and operational in the cluster (from feature 004)
- Kubernetes manifests will be stored in the beersystem repository under a k8s/ directory
- ArgoCD has necessary permissions to access the beersystem git repository
- The database user will use password-based authentication
- Application configuration can be managed via Kubernetes ConfigMaps and Secrets
- The existing AWS and local dev environments can remain operational during and after cluster deployment
