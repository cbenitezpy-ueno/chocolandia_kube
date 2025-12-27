# Feature Specification: K3s Secret Encryption at Rest

**Feature Branch**: `023-k3s-secret-encryption`
**Created**: 2025-12-27
**Status**: Implemented (2025-12-27)
**Input**: User description: "Enable K3s secret encryption at rest for security compliance (GitHub Issue #22)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Secure Secrets Storage (Priority: P1)

As a cluster administrator, I need Kubernetes secrets stored in the SQLite database to be encrypted at rest, so that unauthorized filesystem access to the master node does not expose sensitive credentials.

**Why this priority**: This is the core security requirement. Without encryption at rest, anyone with filesystem access can read all secrets in plaintext (base64 is just encoding, not encryption).

**Independent Test**: Can be fully tested by creating a test secret, then attempting to read the raw SQLite database to verify the secret value is not readable in plaintext.

**Acceptance Scenarios**:

1. **Given** secret encryption is enabled, **When** a new secret is created, **Then** it is stored encrypted in the SQLite database
2. **Given** secret encryption is enabled, **When** someone reads the SQLite database file directly, **Then** secret values are not readable in plaintext
3. **Given** secret encryption is enabled, **When** an application requests a secret via the Kubernetes API, **Then** the secret is decrypted and returned correctly

---

### User Story 2 - Encrypted Backups (Priority: P1)

As a cluster administrator, I need database backups to contain only encrypted secrets, so that backup storage does not become a security vulnerability.

**Why this priority**: Backups are often stored in less secure locations. If secrets are encrypted before backup, the backup chain is also secure.

**Independent Test**: Can be fully tested by creating a database backup and examining it for plaintext secret values.

**Acceptance Scenarios**:

1. **Given** secret encryption is enabled and a backup is created, **When** the backup file is examined, **Then** no secret values are readable in plaintext
2. **Given** a backup is restored to a cluster with the same encryption key, **When** applications request secrets, **Then** they receive decrypted values correctly

---

### User Story 3 - Existing Secrets Migration (Priority: P1)

As a cluster administrator, I need all existing secrets (created before encryption was enabled) to be re-encrypted with the new encryption configuration, so that historical secrets are also protected.

**Why this priority**: Enabling encryption only for new secrets would leave existing secrets vulnerable. All secrets must be migrated.

**Independent Test**: Can be tested by verifying that secrets created before encryption enablement are also encrypted in storage after the migration process completes.

**Acceptance Scenarios**:

1. **Given** encryption is newly enabled and existing secrets exist, **When** the re-encryption process runs, **Then** all secrets are encrypted
2. **Given** re-encryption has completed, **When** any application requests any existing secret, **Then** the secret is decrypted and returned correctly
3. **Given** re-encryption has completed, **When** the SQLite database is examined, **Then** no secret values (old or new) are readable in plaintext

---

### User Story 4 - Operational Continuity (Priority: P1)

As a cluster administrator, I need the encryption enablement process to have zero downtime and not break any running applications that depend on secrets.

**Why this priority**: Production workloads cannot be disrupted. The migration must be transparent to applications.

**Independent Test**: Can be tested by monitoring application health during the encryption enablement process and verifying no pods restart or fail due to secret access issues.

**Acceptance Scenarios**:

1. **Given** applications are running with secrets, **When** encryption is enabled and K3s restarts, **Then** all applications continue running without interruption
2. **Given** encryption is being enabled, **When** the process completes, **Then** no pods are in error state due to secret issues

---

### User Story 5 - Recovery Documentation (Priority: P2)

As a cluster administrator, I need documented recovery procedures so that if the encryption key is lost or corrupted, I understand the implications and have a recovery path.

**Why this priority**: Encryption introduces key management risk. Administrators need to understand disaster recovery scenarios.

**Independent Test**: Can be tested by reviewing documentation and validating that recovery steps are clear and complete.

**Acceptance Scenarios**:

1. **Given** encryption is enabled, **When** documentation is reviewed, **Then** the location of the encryption key is clearly documented
2. **Given** encryption is enabled, **When** documentation is reviewed, **Then** backup procedures for the encryption key are clearly documented
3. **Given** encryption is enabled, **When** documentation is reviewed, **Then** recovery procedures for key loss scenarios are clearly documented

---

### Edge Cases

- What happens if K3s restarts during the re-encryption process?
  - Re-encryption is idempotent and can be rerun safely
- What happens if the encryption configuration file is corrupted?
  - K3s will fail to start; recovery requires restoring the encryption config from backup
- What happens if someone tries to restore a backup without the encryption key?
  - Secrets will be unreadable; applications will fail to access secrets
- How does encryption affect cluster join for new nodes?
  - Encryption configuration is only needed on the server node; agent nodes are not affected

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST encrypt all Kubernetes secrets at rest using a secure encryption algorithm
- **FR-002**: System MUST use a cryptographically secure encryption key (minimum 256-bit)
- **FR-003**: System MUST create a backup of the current state before enabling encryption
- **FR-004**: System MUST re-encrypt all existing secrets after encryption is enabled
- **FR-005**: System MUST maintain application access to secrets transparently (no application changes required)
- **FR-006**: System MUST allow secrets to be decrypted through the normal Kubernetes API
- **FR-007**: System MUST document the encryption key location and backup procedures
- **FR-008**: System MUST document recovery procedures for encryption-related failures

### Non-Functional Requirements

- **NFR-001**: Encryption enablement MUST NOT cause application downtime
- **NFR-002**: Secret read/write operations MUST NOT have noticeable latency increase (< 10ms additional latency)
- **NFR-003**: The encryption key MUST be stored with restricted file permissions (readable only by root)

### Key Entities

- **Encryption Configuration**: The configuration file specifying the encryption provider and key
- **Encryption Key**: The 256-bit secret key used for AES encryption of secrets
- **SQLite Database**: K3s embedded datastore where all Kubernetes resources (including secrets) are persisted

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of secrets (new and existing) are encrypted in the SQLite database after migration
- **SC-002**: Zero application downtime during encryption enablement process
- **SC-003**: All existing applications continue functioning with secrets after encryption is enabled
- **SC-004**: Raw SQLite database inspection reveals no plaintext secret values
- **SC-005**: Database backups contain only encrypted secret data
- **SC-006**: Recovery documentation is complete and covers all identified failure scenarios

## Assumptions

1. K3s is running with the embedded SQLite datastore (not external etcd)
2. The administrator has root/sudo access to the master node (192.168.4.101)
3. The current K3s version (v1.28+) supports secrets encryption configuration
4. A brief K3s service restart is acceptable (pods continue running during API server restart)
5. AES-CBC encryption provider will be used (standard K3s encryption method)
6. The encryption key will be generated and stored securely on the master node filesystem

## Out of Scope

- External key management systems (HashiCorp Vault, AWS KMS, etc.)
- Encryption of other Kubernetes resources (ConfigMaps, etc.)
- Multi-key rotation strategies
- Hardware Security Module (HSM) integration
- Migration to external etcd datastore

## Dependencies

- SSH access to master node (192.168.4.101)
- Root/sudo privileges on master node
- Current K3s installation in working state
- Feature 020-cluster-version-audit (K3s version verified as compatible)

## Risks

| Risk                                    | Likelihood | Impact   | Mitigation                                           |
|-----------------------------------------|------------|----------|------------------------------------------------------|
| Encryption key loss                     | Low        | Critical | Document key backup procedure; store backup securely |
| K3s fails to start after config change  | Low        | High     | Create full cluster backup before changes            |
| Re-encryption fails midway              | Low        | Medium   | Encryption is idempotent; can be rerun               |
| Performance degradation                 | Very Low   | Low      | AES encryption is very fast; impact negligible       |
