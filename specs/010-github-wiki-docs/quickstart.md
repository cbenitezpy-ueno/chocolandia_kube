# Quick Start: GitHub Wiki Documentation Sync

**Feature**: 010-github-wiki-docs
**Purpose**: Step-by-step guide to sync documentation from repository to GitHub Wiki

## Prerequisites

Before you begin, ensure you have:

1. **Git installed** (v2.30+)
   ```bash
   git --version
   ```

2. **Write access to GitHub Wiki**
   - Repository owner or collaborator permissions
   - GitHub Wiki enabled for `chocolandia_kube` repository

3. **GitHub authentication configured**
   ```bash
   # Test GitHub access
   git ls-remote https://github.com/cbenitezpy-ueno/chocolandia_kube.wiki.git
   ```
   If prompted for credentials, configure SSH keys or use GitHub CLI (`gh auth login`)

4. **Repository cloned locally**
   ```bash
   cd /Users/cbenitez/chocolandia_kube
   git status  # Should show you're in the repo
   ```

## Step 1: Verify Documentation Structure

Check that your feature documentation is properly structured:

```bash
# List all feature directories
ls -d specs/[0-9]*

# Expected output:
# specs/001-k3s-cluster-setup
# specs/002-k3s-mvp-eero
# specs/003-pihole
# ... etc
```

Each feature directory should contain at least `spec.md`:
```bash
# Verify a feature has required files
ls specs/001-k3s-cluster-setup/
# Should see: spec.md (required), plus optional: quickstart.md, plan.md, etc.
```

## Step 2: Run Sync Script (Manual)

### First-Time Setup

1. **Navigate to repository root**:
   ```bash
   cd /Users/cbenitez/chocolandia_kube
   ```

2. **Run sync script in dry-run mode** (validates without pushing):
   ```bash
   ./scripts/wiki/sync-to-wiki.sh --dry-run
   ```

   This will:
   - Clone Wiki repo to `/tmp/chocolandia_kube.wiki`
   - Generate Wiki pages
   - Show what would be committed (without actually pushing)
   - Display validation results

3. **Review generated pages**:
   ```bash
   # View generated homepage
   cat /tmp/chocolandia_kube.wiki/Home.md

   # View a feature page
   cat /tmp/chocolandia_kube.wiki/Feature-001-K3s-Cluster-Setup.md

   # Check for any warnings or errors in script output
   ```

### Actual Sync

Once dry-run validation passes:

```bash
./scripts/wiki/sync-to-wiki.sh
```

**What happens**:
1. Script clones Wiki repository to temporary directory
2. Generates `Home.md` (index of all features)
3. For each feature in `specs/`, generates consolidated Wiki page
4. Transforms markdown links (relative → Wiki links)
5. Converts image paths to raw GitHub URLs
6. Commits changes to Wiki repo
7. Pushes to `origin/master` (Wiki branch)
8. Cleans up temporary directory

**Expected output**:
```
[INFO] Cloning Wiki repository...
[INFO] Scanning feature directories...
[INFO] Found 9 features
[INFO] Generating Home page...
[INFO] Generating Feature-001-K3s-Cluster-Setup...
[INFO] Generating Feature-002-K3s-MVP-Eero...
...
[INFO] Committing changes...
[INFO] Pushing to Wiki...
[SUCCESS] Wiki synchronized successfully!
[INFO] View at: https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki
```

## Step 3: Verify Wiki Pages

1. **Open GitHub Wiki** in browser:
   ```bash
   open https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki
   # Or: gh repo view --web --wiki
   ```

2. **Check homepage**:
   - Should show table of all features
   - Feature numbers in order (001-009, etc.)
   - Links to feature pages work

3. **Verify a feature page**:
   - Click on a feature (e.g., "Feature 001: K3s Cluster Setup")
   - Check sections are present (Quick Start, Specification, etc.)
   - Verify links work (navigation back to Home, cross-references)
   - Confirm images display correctly

4. **Test search** (optional):
   - Use GitHub Wiki search bar
   - Search for technical terms (e.g., "OpenTofu", "Pi-hole")
   - Verify results point to correct feature pages

## Step 4: Update Documentation Workflow

After initial setup, use this workflow when updating documentation:

### Making Documentation Changes

1. **Edit files in repository** (NOT in Wiki):
   ```bash
   # Example: Update quickstart for feature 003
   code specs/003-pihole/quickstart.md
   # Make your changes...
   ```

2. **Commit changes to repository**:
   ```bash
   git add specs/003-pihole/quickstart.md
   git commit -m "docs: Update Pi-hole quickstart with new DNS configuration"
   git push origin main
   ```

3. **Sync to Wiki**:
   ```bash
   ./scripts/wiki/sync-to-wiki.sh
   ```

4. **Verify Wiki updated**:
   ```bash
   open https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki/Feature-003-Pihole
   # Check your changes are reflected
   ```

### Adding New Features

When creating a new feature (e.g., `011-new-feature`):

1. **Create feature using SpecKit**:
   ```bash
   /speckit.specify "Your feature description"
   # This creates specs/011-new-feature/ with spec.md
   ```

2. **Complete feature planning**:
   ```bash
   /speckit.plan
   /speckit.tasks
   # This generates plan.md, data-model.md, quickstart.md, tasks.md
   ```

3. **Sync to Wiki**:
   ```bash
   ./scripts/wiki/sync-to-wiki.sh
   ```
   The new feature will automatically appear in the Wiki homepage table and have its own page.

## Troubleshooting

### Issue: "Permission denied" when pushing to Wiki

**Cause**: GitHub authentication not configured

**Solution**:
```bash
# Option 1: Use SSH (recommended)
ssh -T git@github.com
# If fails, set up SSH key: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

# Option 2: Use GitHub CLI
gh auth login
gh auth status
```

### Issue: "Wiki repository not found"

**Cause**: GitHub Wiki not initialized for repository

**Solution**:
1. Go to https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki
2. Click "Create the first page" to initialize Wiki
3. Re-run sync script

### Issue: Links are broken on Wiki pages

**Cause**: Link transformation failed or images not accessible

**Solution**:
```bash
# Run sync in dry-run mode to see transformation output
./scripts/wiki/sync-to-wiki.sh --dry-run | grep -i "link\|image"

# Check generated pages before pushing
cat /tmp/chocolandia_kube.wiki/Feature-XXX-Name.md | grep -i "http\|\[\["
```

### Issue: Sync script shows "no changes detected"

**Cause**: Documentation hasn't changed since last sync

**Solution**: This is expected behavior. If you made changes but script doesn't detect them:
```bash
# Force regeneration by deleting Wiki temp dir
rm -rf /tmp/chocolandia_kube.wiki
./scripts/wiki/sync-to-wiki.sh
```

### Issue: Feature page is missing sections

**Cause**: Optional documentation files (quickstart.md, plan.md, etc.) don't exist

**Solution**: This is expected. Only create pages if the feature has documentation:
- `spec.md` - Required (Specification section)
- `quickstart.md` - Optional (Quick Start section)
- `plan.md` - Optional (Implementation Plan section)
- Other files - Optional

Missing sections are normal for features in early planning stages.

## Advanced Usage

### Sync Specific Features Only

```bash
# Edit sync script to process only certain features (future enhancement)
# For now, the script syncs all features in one operation
```

### Schedule Automated Sync (Future)

When GitHub Actions workflow is implemented:

```yaml
# .github/workflows/wiki-sync.yml
on:
  push:
    branches: [main]
    paths:
      - 'specs/**/*.md'

# This will auto-sync Wiki on every docs change (P3 priority)
```

## Quick Reference

| Task | Command |
|------|---------|
| Dry-run sync (validation only) | `./scripts/wiki/sync-to-wiki.sh --dry-run` |
| Actual sync | `./scripts/wiki/sync-to-wiki.sh` |
| View Wiki | `open https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki` |
| Check auth | `git ls-remote https://github.com/cbenitezpy-ueno/chocolandia_kube.wiki.git` |
| View sync logs | (stdout from script, or redirect to file) |

## Next Steps

After successful sync:

1. **Bookmark Wiki URL**: https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki
2. **Share with team**: Send Wiki link for easy documentation access
3. **Establish routine**: Sync Wiki after major documentation updates or feature completions
4. **Consider automation** (P3): Set up GitHub Actions for automatic sync on merge to main

---

**Remember**: Always edit documentation in the repository (`specs/` directory), never directly in Wiki. Wiki changes will be overwritten on next sync.
