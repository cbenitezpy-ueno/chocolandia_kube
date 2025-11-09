# Security Checklist - Feature 002 MVP

## Overview

This document outlines security considerations and best practices for the Feature 002 MVP K3s cluster deployed on the Eero mesh network. While this is a temporary development environment, proper security hygiene prevents credential leaks and unauthorized access.

**Environment**: chocolandiadc-mvp (Feature 002 - Eero Network)
**Security Posture**: Development/Testing (NOT production-grade)
**Last Updated**: 2025-11-09

## Critical Security Risks

### ⚠️ Eero Flat Network Risks

**Risk Level**: HIGH

The Eero mesh network is a flat Layer 2 network without VLAN segmentation. This means:

- ❌ **No network isolation** between cluster nodes and other home devices
- ❌ **No firewall rules** between cluster and internet (Eero provides NAT only)
- ❌ **No dedicated management network** - all traffic on 192.168.4.0/24
- ❌ **WiFi instability** can affect cluster connectivity
- ❌ **IP address changes** possible if DHCP leases expire

**Mitigations**:
1. ✅ Use SSH key authentication (no passwords)
2. ✅ Disable unnecessary K3s components (Traefik)
3. ✅ Limit exposed services (only Grafana on NodePort 30000)
4. ✅ Run only trusted workloads
5. ⚠️ **DO NOT expose cluster to public internet**

**Future**: Migrate to Feature 001 with FortiGate firewall + VLANs for production.

## Credential Security

### SSH Keys

#### Requirements
- [x] SSH private key permissions: `0600` (read/write for owner only)
- [x] SSH public key permissions: `0644` (readable by all)
- [x] SSH keys NOT committed to Git

#### Verification
```bash
# Check SSH key permissions
ls -l ~/.ssh/id_ed25519_k3s
# Expected: -rw------- (600)

ls -l ~/.ssh/id_ed25519_k3s.pub
# Expected: -rw-r--r-- (644)

# Fix permissions if needed
chmod 600 ~/.ssh/id_ed25519_k3s
chmod 644 ~/.ssh/id_ed25519_k3s.pub
```

#### Key Storage
- ✅ Store private keys in `~/.ssh/` with restrictive permissions
- ✅ Never commit private keys to Git (.gitignore configured)
- ✅ Use separate keys for different clusters/environments
- ⚠️ Back up keys securely (encrypted vault, password manager)

### Kubeconfig

#### Requirements
- [x] Kubeconfig file permissions: `0600`
- [x] Kubeconfig NOT committed to Git
- [x] Kubeconfig contains cluster admin credentials

#### Verification
```bash
# Check kubeconfig permissions
ls -l terraform/environments/chocolandiadc-mvp/kubeconfig
# Expected: -rw------- (600)

# Fix if needed
chmod 600 terraform/environments/chocolandiadc-mvp/kubeconfig

# Verify not tracked by Git
git check-ignore terraform/environments/chocolandiadc-mvp/kubeconfig
# Expected: terraform/environments/chocolandiadc-mvp/kubeconfig
```

#### Access Control
- ✅ Kubeconfig grants cluster-admin privileges (full access)
- ⚠️ Do NOT share kubeconfig with untrusted users
- ⚠️ Rotate kubeconfig if compromised (redeploy cluster)

### K3s Cluster Token

#### Requirements
- [x] Cluster token NOT committed to Git
- [x] Token permissions: `0600` (if stored locally)
- [x] Token only used for joining new nodes

#### Verification
```bash
# Check if token file exists locally (should NOT)
ls -l /tmp/k3s-token.txt 2>/dev/null
# Expected: file not found (cleaned up after deployment)

# Check token on master1 (via SSH)
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 \
  "sudo ls -l /var/lib/rancher/k3s/server/node-token"
# Expected: -rw------- (600) owned by root
```

#### Token Rotation
- ⚠️ K3s does NOT support token rotation
- ⚠️ If token is compromised, redeploy cluster
- ✅ Token is backed up securely by backup-state.sh script

### Grafana Admin Password

#### Requirements
- [x] Default password changed from `prom-operator`
- [x] Strong password (12+ characters, mixed case, numbers, symbols)
- [x] Password stored in Kubernetes Secret

#### Verification
```bash
export KUBECONFIG=terraform/environments/chocolandiadc-mvp/kubeconfig

# Check Grafana secret exists
kubectl get secret -n monitoring kube-prometheus-stack-grafana

# Retrieve current password
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

#### Password Management
- ✅ Password changed via Grafana UI (user confirmed)
- ⚠️ Password NOT stored in OpenTofu code (was default `prom-operator`)
- ⚠️ If password forgotten, reset via kubectl:

```bash
kubectl create secret generic kube-prometheus-stack-grafana \
  -n monitoring \
  --from-literal=admin-password=NEW_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/kube-prometheus-stack-grafana -n monitoring
```

## Terraform/OpenTofu State Security

### State Files

#### Requirements
- [x] `*.tfstate` files NOT committed to Git
- [x] `*.tfstate.backup` files NOT committed to Git
- [x] `terraform.tfvars` NOT committed to Git (contains IPs, paths)
- [x] State files contain sensitive data (cluster token, kubeconfig)

#### Verification
```bash
# Verify .gitignore excludes state files
git check-ignore terraform/environments/chocolandiadc-mvp/terraform.tfstate
# Expected: terraform/environments/chocolandiadc-mvp/terraform.tfstate

git check-ignore terraform/environments/chocolandiadc-mvp/terraform.tfvars
# Expected: terraform/environments/chocolandiadc-mvp/terraform.tfvars

# Check no state files committed
git ls-files | grep -E '\.tfstate|\.tfvars$'
# Expected: no output (or only *.tfvars.example)
```

#### State Backup
- ✅ backup-state.sh script backs up state to local directory
- ⚠️ Backup directory (`backups/`) excluded from Git
- ⚠️ Store backups in encrypted location (not in repo)

### Variable Files

#### Requirements
- [x] `terraform.tfvars` contains actual node IPs and SSH key paths
- [x] `terraform.tfvars.example` is safe template (no real values)
- [x] `.tfvars` files excluded from Git

#### Current Values (terraform.tfvars)
```hcl
master1_ip       = "192.168.4.101"  # Real IP, do not commit
nodo1_ip         = "192.168.4.102"  # Real IP, do not commit
ssh_private_key_path = "~/.ssh/id_ed25519_k3s"  # Real path, do not commit
```

## Network Security

### Exposed Services

| Service    | Type      | Port  | External Access | Risk Level |
|------------|-----------|-------|-----------------|------------|
| Kubernetes API | NodePort  | 6443  | ❌ Not exposed  | LOW        |
| Grafana    | NodePort  | 30000 | ⚠️ On LAN only  | MEDIUM     |
| Prometheus | ClusterIP | 9090  | ❌ Port-forward only | LOW    |
| Alertmanager | ClusterIP | 9093 | ❌ Port-forward only | LOW    |

#### Grafana Exposure (NodePort 30000)
- ⚠️ Accessible from any device on 192.168.4.0/24 network
- ⚠️ Protected by username/password only
- ⚠️ No TLS/HTTPS (plain HTTP)
- ⚠️ No IP whitelisting (Eero doesn't support firewall rules)

**Recommendations**:
1. Change Grafana admin password (done ✅)
2. Create non-admin users for viewing dashboards
3. Enable anonymous read-only access if needed
4. Consider adding nginx-ingress with basic auth

### Kubernetes API Security

#### Requirements
- [x] API server on port 6443 (default K3s)
- [x] TLS enabled (K3s default)
- [x] Certificate-based authentication (kubeconfig)
- [x] RBAC enabled (K3s default)

#### Verification
```bash
# Test API access requires valid kubeconfig
curl -k https://192.168.4.101:6443/api/v1/namespaces
# Expected: 403 Forbidden (no credentials)

# Test with kubeconfig
kubectl --kubeconfig=terraform/environments/chocolandiadc-mvp/kubeconfig get nodes
# Expected: node list (authenticated)
```

### Node-to-Node Communication

- ✅ K3s uses Flannel CNI with VXLAN (encrypted overlay)
- ✅ Nodes communicate over 192.168.4.0/24 (Eero network)
- ⚠️ No additional encryption between nodes (WiFi network)
- ⚠️ Eero WiFi security relies on WPA2/WPA3

## Backup Security

### Backup Files

#### Requirements
- [x] Backups contain sensitive data (SQLite DB, secrets, tokens)
- [x] Backup directory excluded from Git
- [x] Backup scripts create timestamped archives

#### Sensitive Data in Backups
- ❌ **SQLite database**: Contains cluster state, secrets
- ❌ **Kubeconfig**: Contains cluster admin credentials
- ❌ **Cluster token**: Used for joining nodes
- ❌ **ConfigMaps/Secrets**: May contain passwords, API keys
- ❌ **Grafana dashboards**: May contain API tokens

#### Backup Storage Recommendations
1. ⚠️ Encrypt backups at rest (use VeraCrypt, LUKS, or similar)
2. ⚠️ Store backups on separate device (not on cluster nodes)
3. ⚠️ Limit backup access to authorized users only
4. ⚠️ Test backup restoration regularly
5. ⚠️ Delete old backups securely (shred files)

```bash
# Encrypt backup archive (example with gpg)
gpg --symmetric --cipher-algo AES256 backups/terraform-state-20251109-120000.tar.gz

# Securely delete unencrypted backup
shred -u backups/terraform-state-20251109-120000.tar.gz
```

## Secrets Management

### Kubernetes Secrets

- ⚠️ Kubernetes Secrets are base64-encoded, NOT encrypted at rest
- ⚠️ SQLite database stores secrets in plaintext
- ⚠️ Anyone with cluster-admin access can read all secrets

#### Current Secrets
```bash
export KUBECONFIG=terraform/environments/chocolandiadc-mvp/kubeconfig

# List all secrets
kubectl get secrets -A

# Critical secrets:
# - grafana-admin-password (monitoring namespace)
# - prometheus credentials (if configured)
# - k3s-serving cert (kube-system)
```

#### Best Practices
1. ✅ Use Kubernetes RBAC to limit secret access
2. ⚠️ Consider using sealed-secrets or external secret managers (e.g., Vault)
3. ⚠️ Rotate secrets regularly
4. ⚠️ Never log secrets or print to console

## Compliance Checklist

### Pre-Deployment Security

- [x] SSH keys generated with strong algorithm (ed25519)
- [x] SSH keys have correct permissions (600)
- [x] Passwordless sudo configured on nodes
- [x] .gitignore configured to exclude sensitive files
- [x] terraform.tfvars not committed to Git

### Post-Deployment Security

- [x] Grafana admin password changed from default
- [x] Kubeconfig permissions set to 600
- [x] Cluster token not exposed publicly
- [x] Only necessary services exposed (Grafana NodePort)
- [x] Monitoring stack deployed for visibility

### Ongoing Security

- [ ] Review Grafana access logs monthly
- [ ] Update K3s to latest patch version quarterly
- [ ] Rotate Grafana admin password every 90 days
- [ ] Review RBAC policies for least privilege
- [ ] Monitor cluster for unauthorized pods/services

## Incident Response

### Suspected Credential Compromise

If you suspect SSH keys, kubeconfig, or cluster token are compromised:

1. **Immediate Actions**:
   - Revoke access immediately (redeploy cluster if needed)
   - Review cluster audit logs for suspicious activity
   - Check for unauthorized pods/services

2. **Investigation**:
   - Identify scope of compromise (what was accessed)
   - Review Git history for accidental commits
   - Check backup storage for unauthorized access

3. **Remediation**:
   - Rotate all credentials
   - Redeploy cluster with new tokens
   - Update SSH keys on all nodes
   - Change Grafana admin password

4. **Prevention**:
   - Review .gitignore configuration
   - Audit file permissions
   - Enable git-secrets or similar tools

### Security Contact

For security concerns:
- **Project Owner**: cbenitez@gmail.com
- **Repository**: https://github.com/cbenitezpy-ueno/chocolandia_kube

## Future Security Enhancements (Feature 001)

When migrating to Feature 001 (FortiGate + HA cluster):

1. **Network Segmentation**:
   - VLAN 10 (Management): 10.10.10.0/24
   - VLAN 20 (Cluster): 10.20.20.0/24
   - VLAN 30 (Storage): 10.30.30.0/24
   - VLAN 40 (Services): 10.40.40.0/24

2. **Firewall Rules**:
   - FortiGate firewall between VLANs
   - Deny all by default, allow specific ports
   - No direct internet access to cluster nodes

3. **Storage Security**:
   - Longhorn encrypted volumes
   - Dedicated storage network (VLAN 30)
   - Replicated storage for HA

4. **Secrets Management**:
   - Consider HashiCorp Vault integration
   - Encrypted etcd datastore (K3s HA mode)
   - Automated secret rotation

5. **Access Control**:
   - VPN access for management network
   - MFA for administrative access
   - RBAC policies for least privilege

---

**Remember**: Feature 002 is a **temporary development environment**. For production workloads, migrate to Feature 001 with proper network segmentation and security controls.
