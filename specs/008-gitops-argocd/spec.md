# Feature Specification: GitOps Continuous Deployment with ArgoCD

**Feature Branch**: `008-gitops-argocd`
**Created**: 2025-11-12
**Status**: Draft
**Input**: User request: "Quiero que al aprobar el PR en github para este proyecto los cambios se bajen y se apliquen automaticamente en el cluster. Adicionalmente quiero dejar todo desplegado para que pueda hacer lo mismo en proyectos de desarrollo web que tengo"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy ArgoCD in K3s Cluster (Priority: P1)

Deploy ArgoCD using Helm chart managed through OpenTofu, establishing the GitOps foundation for automated continuous deployment in the K3s cluster.

**Why this priority**: Foundation for all GitOps automation. Without ArgoCD deployed, no automated synchronization is possible. This is the core infrastructure that enables all other user stories.

**Independent Test**: Can be fully tested by deploying ArgoCD via OpenTofu, verifying all ArgoCD pods are running (argocd-server, argocd-repo-server, argocd-application-controller, argocd-redis), and accessing the ArgoCD web UI. Delivers immediate value by providing a GitOps platform ready for application configuration.

**Acceptance Scenarios**:

1. **Given** K3s cluster is running with Traefik and cert-manager, **When** deploying ArgoCD module via `tofu apply`, **Then** ArgoCD namespace is created and all ArgoCD components reach Running status within 2 minutes
2. **Given** ArgoCD is deployed, **When** checking services, **Then** argocd-server service is created and listening on port 443 for web UI and gRPC
3. **Given** ArgoCD is deployed, **When** retrieving initial admin password, **Then** password is stored in Kubernetes Secret and can be extracted for first login
4. **Given** ArgoCD server is running, **When** port-forwarding to argocd-server service, **Then** ArgoCD web UI is accessible and shows empty applications list

---

### User Story 2 - Configure ArgoCD Application for chocolandia_kube (Priority: P1, MVP)

Create ArgoCD Application resource that monitors the chocolandia_kube GitHub repository and automatically synchronizes infrastructure changes to the K3s cluster when PRs are merged to main.

**Why this priority**: MVP functionality for infrastructure GitOps. This enables the primary user request: "al aprobar el PR en github... los cambios se bajen y se apliquen automaticamente". Without this, ArgoCD is just deployed infrastructure with no automation.

**Independent Test**: Can be tested by creating the ArgoCD Application manifest, committing it, and verifying that ArgoCD detects the repository, shows sync status, and reports any drift between Git and cluster state. Delivers value by enabling automated infrastructure deployment without manual `tofu apply`.

**Acceptance Scenarios**:

1. **Given** ArgoCD is deployed and chocolandia_kube Application is created, **When** checking ArgoCD UI, **Then** Application appears with repository URL, target path (terraform/environments/chocolandiadc-mvp), and sync status
2. **Given** Application is configured with auto-sync disabled (manual mode), **When** changes are pushed to main branch, **Then** ArgoCD detects drift and marks Application as "OutOfSync" without applying changes
3. **Given** Application shows OutOfSync status, **When** user manually triggers sync via ArgoCD UI or CLI, **Then** ArgoCD applies OpenTofu changes to cluster and Application status changes to "Synced"
4. **Given** Application is synced, **When** checking cluster resources, **Then** changes from GitHub are reflected in deployed resources (e.g., new service, updated ConfigMap)

---

### User Story 3 - Enable Auto-Sync for Automatic PR Deployment (Priority: P1, MVP)

Configure ArgoCD Application with auto-sync enabled and self-heal to automatically apply approved GitHub PR changes to the cluster without manual intervention.

**Why this priority**: Core MVP requirement completing the user's request. This is what the user specifically asked for: automatic deployment on PR approval. Without auto-sync, deployment still requires manual sync button clicks.

**Independent Test**: Can be tested by enabling auto-sync on the Application, merging a PR with infrastructure changes (e.g., update replica count), and verifying that ArgoCD automatically applies the changes within the configured sync interval (default 3 minutes). Delivers value by eliminating manual deployment steps.

**Acceptance Scenarios**:

1. **Given** ArgoCD Application has auto-sync enabled, **When** PR is merged to main branch with infrastructure changes, **Then** ArgoCD detects changes within 3 minutes and automatically initiates sync
2. **Given** auto-sync is triggered, **When** sync completes successfully, **Then** Application status shows "Synced" and "Healthy", and cluster resources reflect the new state from Git
3. **Given** auto-sync is enabled with self-heal, **When** manual changes are made to cluster resources (e.g., kubectl edit), **Then** ArgoCD detects drift and automatically reverts changes to match Git state
4. **Given** auto-sync fails due to validation error, **When** checking Application status, **Then** ArgoCD shows "OutOfSync" with error message, and does not continuously retry (protects cluster from bad manifests)

---

### User Story 4 - Expose ArgoCD via Traefik with HTTPS and Cloudflare Access (Priority: P2)

Create Traefik IngressRoute to expose ArgoCD web UI securely with HTTPS certificate from cert-manager and protect with Cloudflare Access authentication.

**Why this priority**: Enables secure remote access to GitOps dashboard. Once ArgoCD is deployed and automation is working, exposing it securely allows monitoring and manual intervention from any location. Not MVP since ArgoCD can operate without web UI access.

**Independent Test**: Can be tested by creating IngressRoute, configuring Cloudflare Access policy, and accessing ArgoCD via HTTPS URL with Google OAuth authentication. Delivers value by providing visibility into GitOps sync status and health without kubectl/port-forwarding.

**Acceptance Scenarios**:

1. **Given** ArgoCD is deployed and IngressRoute is created, **When** configuring Cloudflare Access for argocd.chocolandiadc.com, **Then** Access application is created with Google OAuth identity provider
2. **Given** IngressRoute has cert-manager annotation, **When** cert-manager processes request, **Then** TLS certificate is issued for argocd.chocolandiadc.com and stored in Secret
3. **Given** HTTPS is configured with Cloudflare Access, **When** unauthenticated user accesses ArgoCD URL, **Then** user is redirected to Cloudflare Access login page
4. **Given** authorized user authenticates via Google OAuth, **When** accessing ArgoCD UI, **Then** user sees applications list, sync status, and can manually trigger sync if needed

---

### User Story 5 - Integrate ArgoCD with Prometheus for GitOps Metrics (Priority: P3)

Configure ArgoCD to expose Prometheus metrics and create ServiceMonitor for automatic scraping, enabling observability of GitOps sync operations and health.

**Why this priority**: Enhancement for observability. While useful for tracking sync failures and performance, monitoring ArgoCD itself is less critical than having automated deployment working. Helpful for identifying sync delays or repository connection issues.

**Independent Test**: Can be tested by verifying /metrics endpoint on ArgoCD components, creating ServiceMonitor, and checking that Prometheus scrapes ArgoCD metrics (argocd_app_sync_total, argocd_app_health_status). Delivers value by providing visibility into GitOps platform health.

**Acceptance Scenarios**:

1. **Given** ArgoCD is deployed with metrics enabled, **When** accessing argocd-server /metrics endpoint, **Then** Prometheus-format metrics are returned including sync counts, health status, and repository connection status
2. **Given** ServiceMonitor is created for ArgoCD, **When** Prometheus operator processes it, **Then** ArgoCD targets appear in Prometheus with "UP" status
3. **Given** Prometheus is scraping ArgoCD, **When** Application syncs automatically, **Then** argocd_app_sync_total counter increments and sync duration histogram is updated
4. **Given** sync fails due to error, **When** checking Prometheus metrics, **Then** argocd_app_sync_status shows failed state and error message is available in logs

---

### User Story 6 - Create ArgoCD Project Template for Web Applications (Priority: P2)

Create reusable ArgoCD Application manifest template that can be easily adapted for future web development projects, establishing a pattern for deploying web apps to the cluster.

**Why this priority**: Addresses user's secondary requirement: "dejar todo desplegado para que pueda hacer lo mismo en proyectos de desarrollo web que tengo". This provides a blueprint for onboarding new applications with GitOps automation.

**Independent Test**: Can be tested by creating a sample web application repository, applying the template Application manifest with repository-specific values, and verifying that ArgoCD syncs the web app to cluster. Delivers value by reducing time-to-production for new web projects.

**Acceptance Scenarios**:

1. **Given** ArgoCD is deployed, **When** creating Application manifest from template for web project, **Then** manifest requires only 4 values: app-name, repository-url, target-path, namespace
2. **Given** template Application is deployed, **When** web project repository contains Kubernetes manifests (deployment, service, ingress), **Then** ArgoCD syncs manifests and deploys web application to specified namespace
3. **Given** web application is synced, **When** checking cluster, **Then** web app pods are running, service is created, and ingress route exposes application on subdomain
4. **Given** web app is deployed via ArgoCD, **When** pushing updates to web project repository, **Then** ArgoCD automatically syncs changes (rolling update for deployment, config reload for ConfigMap)

---

### Edge Cases

- What happens when ArgoCD loses connection to GitHub repository (e.g., GitHub outage, API rate limit)?
- How does ArgoCD handle OpenTofu state conflicts when multiple applications modify overlapping resources?
- What happens when auto-sync tries to apply invalid manifests (e.g., YAML syntax error, missing required field)?
- How does system handle ArgoCD pod restarts during active sync operation?
- What happens when GitHub PR is merged but contains breaking changes that cause cluster instability?
- How does ArgoCD behave when target namespace doesn't exist or has insufficient RBAC permissions?
- What happens when Cloudflare Access is unavailable but ArgoCD sync needs to continue?
- How does system handle multiple simultaneous PRs merged to main branch (sync queue)?
- What happens when Git repository structure changes (e.g., target-path renamed or moved)?
- How does ArgoCD handle secrets management (sensitive values in terraform.tfvars)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy ArgoCD using Helm chart via OpenTofu (version 2.8+)
- **FR-002**: System MUST configure ArgoCD with high availability (multiple replicas for repo-server and application-controller)
- **FR-003**: System MUST create argocd namespace with appropriate RBAC permissions for managing cluster resources
- **FR-004**: System MUST generate initial admin password and store in Kubernetes Secret during deployment
- **FR-005**: System MUST create ArgoCD Application resource monitoring chocolandia_kube repository on main branch
- **FR-006**: System MUST configure Application with target path (terraform/environments/chocolandiadc-mvp)
- **FR-007**: System MUST enable auto-sync with self-heal for automatic deployment of approved PRs
- **FR-008**: System MUST configure sync policy with prune enabled to remove deleted resources from cluster
- **FR-009**: System MUST set sync retry limit (default 5 retries) to prevent infinite loops on failing syncs
- **FR-010**: System MUST create Traefik IngressRoute exposing ArgoCD server on subdomain (argocd.chocolandiadc.com)
- **FR-011**: System MUST configure IngressRoute with cert-manager annotation for automatic TLS certificate issuance
- **FR-012**: System MUST enable HTTPS redirect middleware to force secure connections to ArgoCD UI
- **FR-013**: System MUST configure Cloudflare Access application with Google OAuth identity provider for ArgoCD access
- **FR-014**: System MUST define Cloudflare Access policy restricting ArgoCD access to authorized email addresses
- **FR-015**: System MUST enable Prometheus metrics endpoint in ArgoCD server and application controller
- **FR-016**: System MUST create ServiceMonitor for Prometheus operator to scrape ArgoCD metrics
- **FR-017**: System MUST configure resource limits for ArgoCD components (server: 256Mi memory, repo-server: 128Mi, controller: 512Mi)
- **FR-018**: System MUST support Git repository polling with configurable interval (default 3 minutes)
- **FR-019**: System MUST provide ArgoCD CLI access via kubectl port-forward for debugging and manual operations
- **FR-020**: System MUST create reusable Application manifest template for web projects with parameterized values
- **FR-021**: System MUST support multiple ArgoCD Applications (one per web project) without resource conflicts
- **FR-022**: System MUST configure health assessment for custom CRDs (Traefik IngressRoute, Certificate)
- **FR-023**: [NEEDS CLARIFICATION: How should ArgoCD handle terraform.tfvars secrets? Use sealed-secrets, external-secrets, or commit encrypted values?]
- **FR-024**: [NEEDS CLARIFICATION: Should ArgoCD auto-sync be initially enabled or require manual enablement after validation?]

### Key Entities

- **ArgoCD Deployment**: Kubernetes Deployments running ArgoCD components (server, repo-server, application-controller, redis, dex)
- **ArgoCD Application**: Custom resource defining Git repository to sync, target cluster, and sync policies
- **ArgoCD Project**: Organizational grouping of Applications with RBAC and resource restrictions (default: chocolandia_kube project)
- **Sync Policy**: Configuration defining auto-sync behavior, self-heal, prune, and retry limits
- **Repository Secret**: Kubernetes Secret storing GitHub credentials for private repository access (if needed)
- **IngressRoute**: Traefik CRD exposing ArgoCD server with HTTPS and routing rules
- **Certificate**: cert-manager CRD managing TLS certificate lifecycle for ArgoCD domain
- **Cloudflare Access Application**: Zero Trust application protecting ArgoCD with OAuth authentication
- **ServiceMonitor**: Prometheus operator CRD for automatic ArgoCD metrics scraping
- **Application Health Status**: Runtime state tracking whether synced resources are healthy (Running, Degraded, Progressing, Unknown)
- **Sync Status**: Runtime state tracking whether cluster matches Git (Synced, OutOfSync, Unknown)
- **Application Template**: Reusable manifest pattern for creating ArgoCD Applications for web projects

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: ArgoCD installation completes within 3 minutes and all components reach Running status
- **SC-002**: ArgoCD detects changes in GitHub repository within 3 minutes of PR merge to main branch
- **SC-003**: Automatic sync completes successfully within 5 minutes of detection (for infrastructure changes under 10 resources)
- **SC-004**: Self-heal reverts manual cluster changes within 3 minutes of drift detection
- **SC-005**: ArgoCD web UI loads completely in under 3 seconds after authentication
- **SC-006**: HTTPS certificate for ArgoCD domain is issued automatically within 5 minutes
- **SC-007**: Unauthorized users are blocked from accessing ArgoCD (100% of unauthenticated requests denied)
- **SC-008**: Authorized users can authenticate via Google OAuth and access ArgoCD UI in under 30 seconds
- **SC-009**: Failed syncs generate clear error messages in Application status (no cryptic errors)
- **SC-010**: ArgoCD components stay under configured resource limits during normal operation (no OOM kills)
- **SC-011**: Prometheus successfully scrapes ArgoCD metrics with no gaps (100% scrape success rate)
- **SC-012**: Web application template enables deployment of new project in under 10 minutes (from template to running pods)
- **SC-013**: System handles 5 concurrent Applications syncing without performance degradation
- **SC-014**: Sync history retains last 10 sync operations per Application for troubleshooting

## Dependencies

### Internal Dependencies
- **Feature 001**: K3s cluster must be running (master1 + nodo1)
- **Feature 005**: Traefik ingress controller required for IngressRoute
- **Feature 006**: cert-manager required for TLS certificate automation
- **Feature 004**: Cloudflare Zero Trust tunnel required for secure external access

### External Dependencies
- **GitHub Repository**: chocolandia_kube repository must be accessible (public or ArgoCD configured with GitHub credentials)
- **OpenTofu State**: Local OpenTofu state file must be consistent (ArgoCD will apply manifests, not manage Terraform state)
- **Git Branch Protection**: Recommend enabling branch protection on main to prevent accidental direct pushes
- **GitHub Actions** (Future): Optional integration for pre-merge validation (linting, `tofu plan`)

## Out of Scope

### Explicitly Not Included
- **GitHub Actions CI Pipeline**: Feature focuses on CD (deployment), not CI (build/test). Validation/linting can be added in future feature.
- **Multi-Cluster Support**: ArgoCD will only manage the single K3s cluster. Multi-cluster management is not needed for homelab.
- **Image Registry Integration**: ArgoCD will sync Kubernetes manifests only. Container image builds and registry pushes are out of scope.
- **Secrets Management Solution**: Feature will document secrets handling approach but not implement sealed-secrets or external-secrets-operator.
- **ArgoCD Notifications**: Slack/email notifications for sync events are out of scope. Can be added as enhancement.
- **ApplicationSet Controller**: Advanced templating for multiple similar applications is not needed. Manual Application creation per web project is acceptable.
- **Argo Rollouts**: Progressive delivery (canary, blue-green) is not required for homelab. Standard Kubernetes rolling updates are sufficient.
- **ArgoCD Image Updater**: Automatic image tag updates in Git are not needed. Manual PR process for image updates is acceptable.

## Open Questions for User

### Clarification Needed
1. **Secrets Management Strategy**: How should ArgoCD handle sensitive values in terraform.tfvars (Cloudflare API token, Google OAuth secrets)? Options:
   - Commit encrypted values with SOPS/sealed-secrets
   - Use external-secrets-operator to pull from vault
   - Keep secrets in cluster and reference via existing Secrets (current approach)

2. **Initial Auto-Sync Setting**: Should ArgoCD auto-sync be enabled from the start, or should it start with manual sync for validation? Recommendation: Start manual, enable auto-sync after confirming first successful sync.

3. **GitHub Repository Access**: Is chocolandia_kube repository public or private? If private, we need to create GitHub personal access token for ArgoCD repository access.
