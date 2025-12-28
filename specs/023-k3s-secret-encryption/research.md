# Research: K3s Secret Encryption at Rest

**Feature**: 023-k3s-secret-encryption
**Date**: 2025-12-27
**Status**: Complete

## Executive Summary

K3s v1.33.6 (current cluster version) fully supports secrets encryption at rest. The critical finding is that **encryption cannot be enabled on an existing cluster without reinstalling K3s with the `--secrets-encryption` flag**. This requires a cluster restart but running pods are not affected.

## Current Cluster State

| Metric | Value |
|--------|-------|
| K3s Version | v1.33.6+k3s1 |
| Control Plane Nodes | 2 (master1: 192.168.4.101, nodo03: 192.168.4.103) |
| Worker Nodes | 2 (nodo1: 192.168.4.102, nodo04: 192.168.4.104) |
| Total Secrets | 112 (across all namespaces) |
| Current Encryption | None (base64 encoding only) |
| Datastore | Embedded SQLite on server nodes |

## Research Questions & Findings

### RQ-001: How to enable encryption on an existing cluster?

**Decision**: Reinstall K3s with `--secrets-encryption` flag on server nodes

**Rationale**: K3s documentation explicitly states "Starting K3s without encryption and enabling it at a later time is currently not supported." The only option is to restart K3s servers with the flag enabled.

**Alternatives Considered**:
- Manual encryption config via `--kube-apiserver-arg='encryption-provider-config=...'` - Rejected because K3s loses control/insight into encryption state
- External KMS integration - Out of scope per feature spec

**Implementation Approach**:
1. Create backup of current state
2. Stop K3s on server nodes
3. Re-run K3s install script with `--secrets-encryption` flag
4. Restart K3s
5. Re-encrypt existing secrets

### RQ-002: Encryption provider selection

**Decision**: Use `aescbc` (default)

**Rationale**: AES-CBC is the default and most widely tested provider. The `secretbox` provider (XSalsa20 + Poly1305) is available in v1.30.12+ but `aescbc` is production-proven and sufficient for homelab security requirements.

**Alternatives Considered**:

| Provider | Algorithm | Availability | Status |
|----------|-----------|--------------|--------|
| aescbc | AES-CBC with PKCS#7 | All versions | **Selected** |
| secretbox | XSalsa20 + Poly1305 | v1.30.12+ | Available but newer |

### RQ-003: Re-encryption process for existing secrets

**Decision**: Use `k3s secrets-encrypt rotate-keys` after enabling encryption (v1.33+)

**Rationale**: K3s includes built-in tooling for re-encryption. The process handles approximately 5 secrets/second, so 112 secrets will take ~22 seconds. Note: K3s v1.33+ uses `rotate-keys` instead of the legacy `reencrypt` command.

**Process**:
1. Enable encryption via server restart
2. Run `k3s secrets-encrypt status` to verify encryption is active
3. Run `k3s secrets-encrypt rotate-keys` on one server node
4. Monitor with `k3s secrets-encrypt status` until stage shows `reencrypt_finished`

### RQ-004: HA cluster coordination

**Decision**: Coordinate encryption across both server nodes

**Rationale**: In HA clusters, encryption configuration must be synchronized. K3s handles this automatically but servers should be restarted sequentially.

**Workflow for HA**:
1. Run encryption enable on primary server (master1)
2. Restart secondary server (nodo03) - it will sync encryption config
3. Verify both servers show same "Server Encryption Hash" via status command
4. Run re-encryption from one server only

### RQ-005: Impact on running workloads

**Decision**: Minimal impact - brief API unavailability during K3s restart

**Rationale**: K3s restart causes temporary API server unavailability (~30 seconds). Running pods continue executing during this time. Pods only fail if they attempt secret access during the brief window.

**Mitigation**:
- Schedule during low-traffic window
- Workloads with mounted secrets continue running (secrets are already in memory)
- New pod starts may fail briefly during restart

### RQ-006: Encryption key storage and backup

**Decision**: Store encryption config backup securely outside cluster

**Key Locations**:
- `/var/lib/rancher/k3s/server/cred/encryption-config.json` - Encryption configuration
- `/var/lib/rancher/k3s/server/token` - Cluster token (different from encryption key)

**Backup Strategy**:
1. Export encryption-config.json to secure local storage
2. Include in disaster recovery documentation
3. **WARNING**: If encryption key is lost, secrets cannot be decrypted

### RQ-007: Verification method

**Decision**: Multiple verification approaches

1. **CLI verification**: `k3s secrets-encrypt status` shows "Enabled" status
2. **Database verification**: SQLite database inspection should show encrypted values
3. **Functional verification**: Create test secret, verify it works via kubectl

## Technical Details

### Encryption Configuration File Format

Location: `/var/lib/rancher/k3s/server/cred/encryption-config.json`

```json
{
  "kind": "EncryptionConfiguration",
  "apiVersion": "apiserver.config.k8s.io/v1",
  "resources": [
    {
      "resources": ["secrets"],
      "providers": [
        {
          "aescbc": {
            "keys": [
              {
                "name": "aescbckey",
                "secret": "<base64-encoded-32-byte-key>"
              }
            ]
          }
        },
        {
          "identity": {}
        }
      ]
    }
  ]
}
```

### K3s Secrets-Encrypt CLI Commands

| Command | Purpose |
|---------|---------|
| `k3s secrets-encrypt status` | Show encryption status and rotation stage |
| `k3s secrets-encrypt rotate-keys` | Re-encrypt all secrets with new key (v1.33+) |
| `k3s secrets-encrypt reencrypt` | Legacy command (pre-v1.33) |

### Rotation Stages (for reference)

1. `start` - Initial state
2. `prepare` - Preparing for rotation
3. `rotate` - Rotating keys
4. `reencrypt_request` - Re-encryption requested
5. `reencrypt_active` - Re-encryption in progress
6. `reencrypt_finished` - Complete

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Key loss after encryption | Low | Critical | Backup encryption-config.json immediately after enabling |
| K3s fails to start | Low | High | Test on staging/backup before production |
| Secrets temporarily inaccessible | Low | Medium | Schedule during maintenance window |
| HA sync issues | Low | Medium | Verify encryption hash matches on both servers |

## Implementation Order

1. **Pre-flight** (validation)
   - Backup cluster state
   - Document current secrets count
   - Verify SSH access to server nodes

2. **Enable encryption** (server-side)
   - Reinstall K3s with `--secrets-encryption` on master1
   - Restart nodo03 to sync configuration

3. **Re-encrypt** (one-time operation)
   - Run `k3s secrets-encrypt rotate-keys`
   - Monitor status until complete

4. **Verify** (validation)
   - Check encryption status
   - Verify applications work
   - Backup encryption config

5. **Document** (recovery procedures)
   - Update CLAUDE.md with encryption details
   - Create recovery runbook

## Sources

- [K3s Secrets Encryption Documentation](https://docs.k3s.io/security/secrets-encryption)
- [K3s secrets-encrypt CLI Reference](https://docs.k3s.io/cli/secrets-encrypt)
- [Rancher K3s Security Documentation](https://documentation.suse.com/cloudnative/k3s/latest/en/security/secrets-encryption.html)
