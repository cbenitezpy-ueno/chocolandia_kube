# Data Model: K3s Secret Encryption at Rest

**Feature**: 023-k3s-secret-encryption
**Date**: 2025-12-27

## Overview

This feature operates on K3s server configuration and does not introduce new application data models. The relevant entities are K3s/Kubernetes system objects.

## Key Entities

### 1. Encryption Configuration

**Description**: K3s-managed configuration file that defines encryption providers and keys.

**Location**: `/var/lib/rancher/k3s/server/cred/encryption-config.json`

**Attributes**:

| Field | Type | Description |
|-------|------|-------------|
| kind | string | Always "EncryptionConfiguration" |
| apiVersion | string | API version (apiserver.config.k8s.io/v1) |
| resources | array | List of resource types and their encryption providers |

**Lifecycle**:
- Created automatically when K3s starts with `--secrets-encryption`
- Updated during key rotation
- Must be preserved for disaster recovery

### 2. Encryption Key

**Description**: The AES-256 key used for encrypting secrets.

**Storage**: Embedded in encryption-config.json, base64-encoded

**Attributes**:

| Field | Type | Description |
|-------|------|-------------|
| name | string | Key identifier (e.g., "aescbckey-<timestamp>") |
| secret | string | Base64-encoded 32-byte key |

**Security Requirements**:
- File permissions: 600 (root only)
- Location: Server node filesystem only
- Backup: Required for disaster recovery

### 3. Kubernetes Secret (existing)

**Description**: Standard Kubernetes Secret object, now encrypted at rest.

**Changes**:

| Aspect | Before Encryption | After Encryption |
|--------|-------------------|------------------|
| Storage format | Base64 encoded (plaintext) | AES-CBC encrypted |
| API access | No change | No change |
| Pod mounts | No change | No change |

### 4. Encryption Status

**Description**: Runtime state of encryption subsystem.

**Access**: `k3s secrets-encrypt status`

**Attributes**:

| Field | Type | Values |
|-------|------|--------|
| Encryption Status | enum | Enabled, Disabled |
| Current Rotation Stage | enum | start, prepare, rotate, reencrypt_request, reencrypt_active, reencrypt_finished |
| Server Encryption Hash | string | Hash for HA sync verification |
| Active Key | object | Type and name of current key |

## State Transitions

### Encryption Enablement

```
[Unencrypted Cluster]
       |
       | (reinstall with --secrets-encryption)
       v
[Encryption Enabled, Existing Secrets Unencrypted]
       |
       | (k3s secrets-encrypt reencrypt)
       v
[Encryption Enabled, All Secrets Encrypted]
```

### Rotation Stages

```
start -> prepare -> rotate -> reencrypt_request -> reencrypt_active -> reencrypt_finished
```

## File System Layout

```
/var/lib/rancher/k3s/
├── server/
│   ├── cred/
│   │   └── encryption-config.json   # Encryption configuration (created after enable)
│   ├── db/
│   │   └── state.db                 # SQLite database with encrypted secrets
│   └── token                        # Cluster join token (separate from encryption)
└── agent/                           # Agent config (no encryption files)
```

## Validation Rules

1. **Encryption Config**:
   - Must exist after enabling encryption
   - Must have at least one encryption key
   - Must have identity provider as fallback (for backward compatibility during rotation)

2. **Key Format**:
   - Must be exactly 32 bytes (256 bits)
   - Must be base64 encoded
   - Must have unique name per key

3. **HA Consistency**:
   - Server Encryption Hash must match across all server nodes
   - Mismatch indicates config drift (requires restart)

## Integration Points

| System | Integration | Direction |
|--------|-------------|-----------|
| K3s API Server | Encryption at write, decryption at read | Automatic |
| kubectl | No change - uses K8s API | Read/Write |
| Applications | No change - mount secrets via API | Read |
| Backups | Database contains encrypted data | Backup |
