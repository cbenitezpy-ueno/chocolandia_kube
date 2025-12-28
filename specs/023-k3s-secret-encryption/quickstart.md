# Quickstart: K3s Secret Encryption at Rest

**Feature**: 023-k3s-secret-encryption
**Estimated Time**: 15-20 minutes
**Risk Level**: Medium (requires K3s restart)

## Prerequisites

- [ ] SSH access to server nodes (master1: 192.168.4.101, nodo03: 192.168.4.103)
- [ ] Root/sudo access on server nodes
- [ ] kubectl access to cluster
- [ ] Backup of cluster state (recommended)

## Quick Implementation

### Step 1: Backup Current State (5 min)

```bash
# From local machine
# Create backup directory
mkdir -p ~/k3s-encryption-backup-$(date +%Y%m%d)
cd ~/k3s-encryption-backup-$(date +%Y%m%d)

# Backup all secrets
kubectl get secrets -A -o yaml > all-secrets-backup.yaml

# Record current secret count
kubectl get secrets -A --no-headers | wc -l > secret-count.txt
echo "Current secrets: $(cat secret-count.txt)"
```

### Step 2: Enable Encryption on Primary Server (5 min)

```bash
# SSH to master1
ssh user@192.168.4.101

# Become root
sudo -i

# Re-run K3s install with encryption flag
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_DOWNLOAD=true sh -s - server \
  --secrets-encryption

# Note: K3s will restart. Wait for it to be ready
systemctl status k3s

# Verify encryption is enabled
k3s secrets-encrypt status
# Expected: "Encryption Status: Enabled"
```

### Step 3: Sync Secondary Server (2 min)

```bash
# SSH to nodo03
ssh user@192.168.4.103

# Restart K3s to sync encryption config
sudo systemctl restart k3s

# Wait for ready state
sudo systemctl status k3s

# Verify same encryption hash
sudo k3s secrets-encrypt status
# Expected: Hash should match master1
```

### Step 4: Re-encrypt Existing Secrets (3 min)

```bash
# On master1 (primary server)
ssh user@192.168.4.101

sudo k3s secrets-encrypt rotate-keys

# Monitor progress (112 secrets ≈ 22 seconds)
sudo k3s secrets-encrypt status
# Wait for "Current Rotation Stage: reencrypt_finished"
```

### Step 5: Verify Encryption (3 min)

```bash
# Still on master1 as root
# Check encryption status
k3s secrets-encrypt status
# Expected:
# Encryption Status: Enabled
# Current Rotation Stage: reencrypt_finished

# Create test secret
kubectl create secret generic encryption-test --from-literal=key=testvalue

# Verify it works
kubectl get secret encryption-test -o jsonpath='{.data.key}' | base64 -d
# Expected: "testvalue"

# Cleanup
kubectl delete secret encryption-test
```

### Step 6: Backup Encryption Config (2 min)

```bash
# On master1 as root
# Copy encryption config to backup location
cp /var/lib/rancher/k3s/server/cred/encryption-config.json \
   /root/encryption-config-backup-$(date +%Y%m%d).json

# CRITICAL: Copy this file to secure external storage
# If lost, encrypted secrets cannot be recovered!
```

## Post-Implementation Checklist

- [ ] Encryption status shows "Enabled" on both servers
- [ ] Rotation stage shows "reencrypt_finished"
- [ ] Server encryption hashes match on both servers
- [ ] Applications can still access their secrets
- [ ] Encryption config is backed up securely
- [ ] CLAUDE.md updated with encryption documentation

## Troubleshooting

### K3s fails to start after enabling encryption

```bash
# Check K3s logs
journalctl -u k3s -n 100 --no-pager

# If encryption config is corrupted, restore from backup
sudo cp /root/encryption-config-backup.json \
   /var/lib/rancher/k3s/server/cred/encryption-config.json
sudo systemctl restart k3s
```

### Re-encryption stuck

```bash
# Force re-encryption
sudo k3s secrets-encrypt reencrypt --force

# Check status
sudo k3s secrets-encrypt status
```

### Pods failing to start

```bash
# Check if secret access is the issue
kubectl describe pod <pod-name>
# Look for: "secrets not found" or "unable to decrypt"

# Verify API server is responsive
kubectl get secrets
```

## Rollback Procedure

**WARNING**: Disabling encryption after enabling requires re-encryption in plaintext.

```bash
# On master1
sudo k3s secrets-encrypt disable

# Wait for status change
sudo k3s secrets-encrypt status

# Re-encrypt to plaintext
sudo k3s secrets-encrypt rotate-keys

# Restart servers
sudo systemctl restart k3s
# Repeat on nodo03
```

## Next Steps

After successful implementation:

1. Update CLAUDE.md with encryption key location
2. Add encryption config to backup rotation
3. Document recovery procedures in runbooks
4. Close GitHub Issue #22
