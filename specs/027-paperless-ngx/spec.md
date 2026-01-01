# Feature Specification: Paperless-ngx Document Management

**Feature Branch**: `027-paperless-ngx`
**Created**: 2026-01-01
**Status**: Draft
**Input**: User description: "quiero tener https://docs.paperless-ngx.com/ instalado, que pueda ser accesible desde internet y monitoreado desde grafana"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Access Document Management from Internet (Priority: P1)

As a user, I want to access my Paperless-ngx instance from anywhere on the internet so I can manage my documents remotely without being on my home network.

**Why this priority**: Internet accessibility is a core requirement explicitly requested by the user. Without this, the system would only be usable from the local network, limiting its value significantly.

**Independent Test**: Can be fully tested by accessing the Paperless-ngx URL from an external network (e.g., mobile data) and successfully logging in and viewing documents.

**Acceptance Scenarios**:

1. **Given** Paperless-ngx is deployed and running, **When** I access the public URL from outside my home network, **Then** I see the login page and can authenticate successfully
2. **Given** I am authenticated, **When** I browse my documents from an external network, **Then** I can view, search, and download documents with acceptable performance
3. **Given** the system is accessible from internet, **When** I attempt to access without authentication, **Then** I am redirected to the login page and cannot access documents

---

### User Story 2 - Upload and Organize Documents (Priority: P2)

As a user, I want to upload physical documents (scanned or photographed) and have them automatically processed with OCR, tagged, and organized so I can find them easily later.

**Why this priority**: Document upload and organization is the core functionality of Paperless-ngx. Once internet access is established (P1), users need to be able to actually use the system for its intended purpose.

**Independent Test**: Can be tested by uploading a scanned document and verifying it appears in the document list with searchable text content.

**Acceptance Scenarios**:

1. **Given** I am logged into Paperless-ngx, **When** I upload a PDF document, **Then** the system processes it with OCR and makes the text searchable
2. **Given** I have uploaded documents, **When** I search for text that appears in a document, **Then** the document appears in search results with highlighted matches
3. **Given** the system has processed documents, **When** I view a document, **Then** I can see assigned tags, correspondent, and document type (if auto-assigned)

---

### User Story 3 - Monitor System Health in Grafana (Priority: P3)

As an administrator, I want to monitor Paperless-ngx health and performance metrics in Grafana so I can proactively identify issues before they affect usability.

**Why this priority**: Monitoring is important for long-term maintainability but the system can function without it initially. This can be added after core functionality is working.

**Independent Test**: Can be tested by viewing the Paperless-ngx dashboard in Grafana and verifying metrics are being collected and displayed.

**Acceptance Scenarios**:

1. **Given** Paperless-ngx is running, **When** I open Grafana and navigate to the Paperless-ngx dashboard, **Then** I see current metrics for system health
2. **Given** I am viewing the Grafana dashboard, **When** Paperless-ngx experiences high resource usage, **Then** I see this reflected in the dashboard metrics
3. **Given** monitoring is configured, **When** a critical metric threshold is exceeded, **Then** an alert is triggered through the existing alerting system

---

### User Story 4 - Secure Access via HTTPS (Priority: P4)

As a user, I want all communication with Paperless-ngx to be encrypted via HTTPS so my documents and credentials are protected when accessing from the internet.

**Why this priority**: Security is essential for internet-accessible services but is largely handled by existing infrastructure (Traefik + cert-manager). This story ensures proper certificate configuration.

**Independent Test**: Can be tested by accessing the URL and verifying the browser shows a valid HTTPS certificate.

**Acceptance Scenarios**:

1. **Given** Paperless-ngx is deployed, **When** I access the URL, **Then** the connection uses HTTPS with a valid certificate
2. **Given** I try to access via HTTP, **When** the request is made, **Then** I am automatically redirected to HTTPS

---

### User Story 5 - Scan Documents Directly from Network Scanner (Priority: P2)

As a user, I want to scan documents directly from my network scanner to Paperless-ngx so I can digitize physical documents without manually uploading files.

**Why this priority**: Scanner integration is essential for the primary use case of digitizing physical documents. It shares P2 priority with document upload as both are core ingestion methods.

**Independent Test**: Can be tested by configuring the scanner to save to the SMB share and verifying the document appears in Paperless-ngx after scanning.

**Acceptance Scenarios**:

1. **Given** the Samba share is configured on my scanner, **When** I scan a document, **Then** the file appears in the consume folder and is automatically processed by Paperless-ngx
2. **Given** a document was scanned and processed, **When** I search for text in that document, **Then** the document appears in search results with OCR text

---

### Edge Cases

- What happens when a very large document (>100MB) is uploaded?
- How does the system handle corrupted or password-protected PDFs?
- What happens if OCR processing fails for a document?
- How does the system behave when storage space is running low?
- What happens when multiple users upload documents simultaneously?

> **Note**: These edge cases are handled by Paperless-ngx's built-in error handling. Failed documents appear in the "failed" folder with error logs. Post-MVP enhancements may include Prometheus alerts for failed processing and storage capacity warnings.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy Paperless-ngx as a containerized application in the K3s cluster
- **FR-002**: System MUST provide persistent storage for uploaded documents and database
- **FR-003**: System MUST expose Paperless-ngx via HTTPS through Cloudflare Zero Trust tunnel for secure internet access
- **FR-004**: System MUST use a valid TLS certificate for the public domain (via cert-manager and Let's Encrypt)
- **FR-005**: System MUST integrate with existing PostgreSQL cluster for database storage
- **FR-006**: System MUST integrate with existing Redis instance for caching and task queue
- **FR-007**: System MUST export metrics in Prometheus format for Grafana monitoring
- **FR-008**: System MUST provide OCR processing capability for uploaded documents
- **FR-009**: System MUST support PDF, image (PNG, JPG), and common office document formats
- **FR-010**: System MUST provide full-text search capability across all processed documents
- **FR-011**: System MUST support user authentication and session management
- **FR-012**: System MUST be accessible via a subdomain of chocolandiadc.com (e.g., paperless.chocolandiadc.com)
- **FR-013**: System MUST be accessible from LAN via a .local domain (e.g., paperless.chocolandiadc.local) using the local CA certificate
- **FR-014**: System MUST provide a consume folder accessible via Samba (SMB) for scanner integration, automatically processing any documents placed in it
- **FR-015**: System MUST deploy a Samba server in the cluster to expose the consume folder to LAN devices (scanners, computers)

### Key Entities

- **Document**: A file uploaded to the system - contains original file, OCR text, metadata (title, correspondent, document type, tags, created date, added date)
- **Correspondent**: Entity that sent or is associated with a document (e.g., company, person, institution)
- **Document Type**: Category of document (e.g., invoice, contract, receipt, letter)
- **Tag**: User-defined label for organizing and filtering documents
- **User**: Person with access to the system - has credentials and permission level

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can access Paperless-ngx from any internet-connected device and authenticate successfully
- **SC-002**: Uploaded documents are processed and searchable within 5 minutes of upload
- **SC-003**: Full-text search returns relevant results in under 3 seconds
- **SC-004**: System health metrics are visible in Grafana dashboard
- **SC-005**: Service maintains 99% uptime during normal operation
- **SC-006**: All connections use HTTPS with valid certificates (no browser warnings)

## Clarifications

### Session 2026-01-01

- Q: ¿Necesitas acceso directo a Paperless-ngx desde tu LAN (sin pasar por Cloudflare)? → A: Sí, Internet + LAN directo (dominio .local adicional)
- Q: ¿Cómo planeas enviar documentos desde tu scanner a Paperless-ngx? → A: Consume folder (scanner guarda a carpeta compartida SMB/NFS)
- Q: ¿Cuánto almacenamiento esperas necesitar para documentos? → A: Mediano (50GB) - miles de documentos
- Q: ¿Cómo quieres exponer el consume folder para que tu scanner pueda escribir en él? → A: Samba (SMB) - servidor Samba en el cluster

## Assumptions

- The existing Cloudflare Zero Trust tunnel infrastructure will be used for internet access (as per feature 004)
- The existing PostgreSQL cluster (192.168.4.204) has capacity for an additional database
- The existing Redis instance (192.168.4.203) can be shared with Paperless-ngx
- The existing kube-prometheus-stack will be used for metrics collection
- User authentication will be handled by Paperless-ngx's built-in authentication (not SSO/OAuth integration)
- A subdomain under chocolandiadc.com will be configured in Cloudflare for public access
- Storage will use existing local-path-provisioner with 50GB PersistentVolume for documents

## Out of Scope

- Email consumption/processing (can be added later)
- Mobile app integration
- Integration with external cloud storage (Google Drive, Dropbox)
- Multi-tenant setup (single user/household use case)
- Automated backup scheduling (relies on existing cluster backup strategy)
