# Feature Specification: LocalStack and Container Registry for Local Development

**Feature Branch**: `015-dev-tools-local`
**Created**: 2025-11-23
**Status**: Draft
**Input**: User description: "quiero deployar localstack para poder usar en desarrollo y tambien quiero un image registry para no usar aws ecr desde mi homelab para mis desarrollos"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Push and Pull Container Images Locally (Priority: P1)

As a developer, I want to push container images to a local registry so that I can develop and test my applications without depending on AWS ECR or external registries.

**Why this priority**: This is the most fundamental capability - without a working registry, developers cannot store or retrieve container images locally, blocking all containerized development workflows.

**Independent Test**: Can be fully tested by building a simple Docker image, pushing it to the local registry, and pulling it from another machine/pod in the cluster. Delivers immediate value for container development.

**Acceptance Scenarios**:

1. **Given** the registry is deployed and running, **When** a developer runs `docker push registry.homelab.local/myapp:v1`, **Then** the image is stored in the registry and a success message is displayed
2. **Given** an image exists in the registry, **When** a developer runs `docker pull registry.homelab.local/myapp:v1`, **Then** the image is downloaded successfully
3. **Given** Kubernetes is configured with the registry, **When** a pod references an image from the local registry, **Then** the image is pulled successfully and the pod starts

---

### User Story 2 - Emulate AWS S3 Service Locally (Priority: P1)

As a developer, I want to use LocalStack to emulate AWS S3 so that I can develop and test S3-dependent applications without incurring AWS costs or requiring internet connectivity.

**Why this priority**: S3 is the most commonly used AWS service. Having a local S3 emulation enables offline development and testing of file storage operations.

**Independent Test**: Can be tested by configuring an application to point to LocalStack S3 endpoint and performing bucket creation, file upload, and file download operations.

**Acceptance Scenarios**:

1. **Given** LocalStack is running, **When** I create an S3 bucket using AWS CLI pointing to LocalStack, **Then** the bucket is created successfully
2. **Given** a bucket exists in LocalStack, **When** I upload a file using `aws s3 cp`, **Then** the file is stored and can be listed
3. **Given** a file exists in LocalStack S3, **When** I download it, **Then** the file content matches the original

---

### User Story 3 - Emulate AWS SQS/SNS for Message Queue Testing (Priority: P2)

As a developer, I want to use LocalStack to emulate AWS SQS and SNS so that I can test message-driven architectures locally.

**Why this priority**: Message queues are critical for microservices but not as universally used as S3. This enables testing async workflows without AWS dependency.

**Independent Test**: Can be tested by creating queues, sending messages, and receiving them using AWS SDK pointing to LocalStack.

**Acceptance Scenarios**:

1. **Given** LocalStack is running, **When** I create an SQS queue, **Then** the queue is available for sending/receiving messages
2. **Given** a queue exists, **When** I send a message to it, **Then** the message can be received by a consumer
3. **Given** an SNS topic exists, **When** I publish a message, **Then** subscribers receive the notification

---

### User Story 4 - Emulate AWS DynamoDB for NoSQL Development (Priority: P2)

As a developer, I want to use LocalStack to emulate DynamoDB so that I can develop and test NoSQL database operations locally.

**Why this priority**: DynamoDB is commonly used in serverless architectures. Local emulation allows testing without AWS costs.

**Independent Test**: Can be tested by creating tables, inserting items, and querying data using AWS SDK.

**Acceptance Scenarios**:

1. **Given** LocalStack is running, **When** I create a DynamoDB table, **Then** the table is available for operations
2. **Given** a table exists, **When** I insert and query items, **Then** the data is persisted and retrievable

---

### User Story 5 - Access Registry Web UI (Priority: P3)

As a developer, I want a web interface to browse images in my local registry so that I can easily see what images are available and manage them visually.

**Why this priority**: While not essential for core functionality, a UI improves developer experience and simplifies image management.

**Independent Test**: Can be tested by accessing the web interface through a browser and verifying image listing.

**Acceptance Scenarios**:

1. **Given** the registry is running with a UI, **When** I access the web interface, **Then** I can see a list of all repositories
2. **Given** images exist in the registry, **When** I browse a repository, **Then** I can see all tags/versions available

---

### Edge Cases

- What happens when the registry storage is full? System should return clear error messages indicating storage limits
- How does LocalStack handle unsupported AWS API operations? Should return appropriate error responses matching AWS behavior
- What happens when pulling an image that doesn't exist? Standard 404/not found response should be returned
- How is data persisted across container restarts? Both LocalStack and Registry must use persistent storage

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy a container image registry accessible from all nodes in the K3s cluster
- **FR-002**: System MUST deploy LocalStack with S3, SQS, SNS, DynamoDB, and Lambda services enabled
- **FR-003**: Registry MUST persist images across pod restarts using cluster storage
- **FR-004**: LocalStack MUST persist data across pod restarts using cluster storage
- **FR-005**: Registry MUST be accessible via a consistent hostname (registry.homelab.local or similar)
- **FR-006**: LocalStack MUST be accessible via a consistent hostname (localstack.homelab.local or similar)
- **FR-007**: System MUST provide a web UI for browsing registry contents
- **FR-008**: Registry MUST support standard Docker registry API v2
- **FR-009**: LocalStack MUST expose AWS-compatible API endpoints for configured services
- **FR-010**: System MUST configure Kubernetes nodes to trust the local registry for image pulls
- **FR-011**: Registry MUST require basic authentication (username/password) for push and pull operations, similar to production ECR behavior
- **FR-012**: Registry storage MUST be limited to 30GB maximum
- **FR-013**: LocalStack storage MUST be limited to 20GB maximum
- **FR-014**: Registry MUST be served over HTTPS using Let's Encrypt certificates via existing cert-manager infrastructure
- **FR-015**: System MUST document manual garbage collection procedure for registry cleanup (no automatic deletion)

### Key Entities

- **Container Image**: Docker/OCI-compatible container images with tags, layers, and manifests
- **Registry Repository**: Named collection of related images (e.g., myapp, nginx-custom)
- **LocalStack Service**: Emulated AWS service instance (S3, SQS, SNS, DynamoDB)
- **S3 Bucket**: Virtual storage container in LocalStack for file/object storage
- **SQS Queue**: Message queue for async communication in LocalStack
- **DynamoDB Table**: NoSQL table for structured data in LocalStack
- **Lambda Function**: Serverless function execution unit in LocalStack for event-driven workflows

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can push and pull container images to/from the local registry within 30 seconds for images up to 500MB
- **SC-002**: Applications can perform S3 operations (create bucket, upload, download) against LocalStack without code changes from production AWS SDK usage
- **SC-003**: System maintains data persistence - images and LocalStack data survive pod restarts and cluster reboots
- **SC-004**: All services are accessible via DNS names from any machine on the home network
- **SC-005**: Registry web UI loads within 5 seconds and displays all stored images
- **SC-006**: Development workflow eliminates AWS costs for S3, SQS, SNS, and DynamoDB during local development

## Clarifications

### Session 2025-11-23

- Q: Registry authentication requirement? → A: Basic authentication (usuario/contraseña) - similar to production ECR behavior
- Q: Storage allocation limits? → A: 50GB total (30GB registry + 20GB LocalStack)
- Q: TLS/HTTPS for registry? → A: HTTPS with Let's Encrypt (using existing cert-manager)
- Q: Include Lambda emulation? → A: Yes, include Lambda for complete serverless testing
- Q: Registry garbage collection? → A: Manual only (document cleanup command when needed)

## Assumptions

- The K3s cluster has local-path-provisioner for persistent storage (documented in CLAUDE.md)
- MetalLB is configured for LoadBalancer IP assignment (documented in CLAUDE.md)
- Traefik ingress is available for exposing services via hostnames
- Developers have Docker CLI installed on their workstations
- AWS CLI is installed on developer machines for LocalStack testing
- Home network DNS (Pi-hole) can be configured for custom hostnames
