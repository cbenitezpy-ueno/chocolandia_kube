# Quickstart: Documentation Audit and Wiki Sync

**Feature**: 024-docs-wiki-sync
**Estimated Time**: 30-45 minutes
**Risk Level**: Low (documentation only)

## Prerequisites

- [ ] kubectl access to cluster
- [ ] GitHub repository write access
- [ ] SSH access to nodes (for verification)
- [ ] gh CLI authenticated

## Quick Implementation

### Step 1: Verify Cluster State (10 min)

```bash
# Get LoadBalancer services and IPs
kubectl get svc -A -o wide | grep LoadBalancer

# Expected output should match CLAUDE.md:
# pihole-dns      192.168.4.200
# traefik         192.168.4.202
# redis           192.168.4.203
# postgresql      192.168.4.204

# Verify monitoring stack version
helm list -n monitoring

# Verify K3s encryption status (via SSH)
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 "sudo k3s secrets-encrypt status"
```

### Step 2: Audit CLAUDE.md (10 min)

```bash
# Open CLAUDE.md and verify each section
# Compare MetalLB IP Assignments with kubectl output
# Verify Monitoring Stack version (68.4.0)
# Verify K3s Secret Encryption section
# Check Recent Changes includes 020-023
```

**Update if needed**:
- Correct any outdated IP addresses
- Update version numbers if changed
- Add any missing features to Recent Changes

### Step 3: Test Wiki Sync (5 min)

```bash
# Navigate to repo root
cd /Users/cbenitez/chocolandia_kube

# Run dry-run to test without pushing
./scripts/wiki/sync-to-wiki.sh --dry-run

# Check output for:
# - All 24 features listed
# - No errors during generation
# - Generated files in /tmp/chocolandia_kube.wiki/
```

### Step 4: Initialize Wiki if Needed (2 min)

```bash
# Check if wiki exists
git ls-remote https://github.com/cbenitezpy-ueno/chocolandia_kube.wiki.git

# If "Repository not found" error:
# 1. Go to https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki
# 2. Click "Create the first page"
# 3. Add any content and save
# 4. Now wiki repo exists for sync script
```

### Step 5: Execute Full Wiki Sync (5 min)

```bash
# Run full sync (will push to wiki)
./scripts/wiki/sync-to-wiki.sh

# Or with sidebar navigation
./scripts/wiki/sync-to-wiki.sh --with-sidebar
```

### Step 6: Verify Wiki (5 min)

```bash
# Open wiki in browser
open https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki

# Verify:
# - Homepage shows all features
# - Click 3-4 feature links to verify they work
# - Check formatting is correct
# - Verify no sensitive information visible
```

## Post-Implementation Checklist

- [ ] All LoadBalancer IPs in CLAUDE.md match kubectl output
- [ ] Monitoring stack version in CLAUDE.md is current
- [ ] K3s encryption section is accurate
- [ ] Recent Changes includes features 020-024
- [ ] Wiki sync --dry-run completes without errors
- [ ] Wiki homepage lists all 24 features
- [ ] Wiki feature pages load correctly
- [ ] No credentials or secrets visible in wiki

## Troubleshooting

### Wiki sync fails to clone

```bash
# Verify wiki is initialized
gh repo view cbenitezpy-ueno/chocolandia_kube --web
# Click Wiki tab, create first page if needed
```

### Script permission denied

```bash
chmod +x scripts/wiki/*.sh
```

### Markdown rendering issues

```bash
# Validate markdown files
./scripts/wiki/validate-markdown.sh specs/
```

### Wiki push fails

```bash
# Check git credentials
gh auth status

# Verify wiki access
git clone https://github.com/cbenitezpy-ueno/chocolandia_kube.wiki.git /tmp/wiki-test
```

## CLAUDE.md Update Template

If updates are needed, add to Recent Changes section:

```markdown
## Recent Changes
- 024-docs-wiki-sync: Documentation audit and GitHub Wiki synchronization
- 023-k3s-secret-encryption: Added Bash scripting for validation, K3s encryption configuration
- 022-metallb-refactor: Added HCL (OpenTofu 1.6+) + hashicorp/kubernetes ~> 2.23, hashicorp/helm ~> 2.11, hashicorp/time ~> 0.11
```

## Next Steps

After successful implementation:

1. Commit any CLAUDE.md updates
2. Commit this feature's documentation
3. Create PR for review
4. Merge to main
5. Close GitHub Issue (if applicable)
