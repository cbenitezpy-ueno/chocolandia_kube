# GitHub Wiki Sync Scripts

Automation scripts to synchronize chocolandia_kube documentation from the repository to GitHub Wiki.

## Overview

These scripts maintain the GitHub Wiki as a mirror of the repository's `specs/` directory, making all feature documentation accessible through a user-friendly Wiki interface.

**Single Source of Truth**: The repository `specs/` directory is authoritative. The Wiki is a read-only mirror updated via these scripts.

## Scripts

- **`sync-to-wiki.sh`**: Main orchestration script - syncs all documentation to Wiki
- **`generate-homepage.sh`**: Generates Wiki homepage (Home.md) with feature index
- **`generate-feature-page.sh`**: Consolidates feature docs into single Wiki page
- **`validate-markdown.sh`**: Validates markdown syntax before sync
- **`lib/utils.sh`**: Common utility functions (feature name extraction, etc.)
- **`lib/transform.sh`**: Markdown transformations (links, images)
- **`lib/extract-metadata.sh`**: Feature metadata extraction from spec files

## Usage

### Quick Sync

```bash
# Sync all documentation to Wiki
./scripts/wiki/sync-to-wiki.sh
```

### Dry Run (Validation Only)

```bash
# Generate pages without pushing to Wiki
./scripts/wiki/sync-to-wiki.sh --dry-run
```

### Generate Specific Components

```bash
# Generate homepage only
./scripts/wiki/generate-homepage.sh > Home.md

# Generate specific feature page
./scripts/wiki/generate-feature-page.sh specs/001-k3s-cluster-setup > Feature-001.md
```

## Prerequisites

1. **Git**: For cloning and pushing to Wiki repository
2. **GitHub Authentication**: SSH keys or GitHub CLI configured
3. **Bash**: Scripts tested on macOS/Linux (Bash 4.0+)
4. **GitHub Wiki Enabled**: Repository must have Wiki feature enabled

### Verify Authentication

```bash
# Test Wiki repository access
git ls-remote https://github.com/cbenitezpy-ueno/chocolandia_kube.wiki.git
```

If this fails, configure GitHub authentication:
- **Option 1 (SSH)**: Set up SSH keys at https://github.com/settings/keys
- **Option 2 (GitHub CLI)**: Run `gh auth login`

## How It Works

1. **Clone Wiki Repo**: Clones `chocolandia_kube.wiki.git` to temporary directory
2. **Generate Homepage**: Scans `specs/` directory, creates feature table
3. **Generate Feature Pages**: For each feature, consolidates all documentation files
4. **Transform Content**: Converts relative links to Wiki links, images to raw URLs
5. **Commit & Push**: Commits changes to Wiki repository and pushes

## Page Structure

### Homepage (Home.md)

- **Feature Table**: Lists all features with numbers, names, descriptions, status
- **Documentation Types**: Explains what each documentation type contains
- **Contributing Guide**: How to update documentation (edit repo, not Wiki)

### Feature Pages (Feature-XXX-Name.md)

Consolidated documentation for each feature:
- Quick Start (if available)
- Specification (user scenarios, requirements)
- Implementation Plan (technical context, architecture)
- Data Model (entities, relationships)
- Research (decisions, alternatives)
- Tasks (summary or full task list)

## Workflow

### Making Documentation Changes

1. **Edit files in repository** (NOT in Wiki):
   ```bash
   # Example: Update quickstart for feature 003
   vim specs/003-pihole/quickstart.md
   ```

2. **Commit changes to repository**:
   ```bash
   git add specs/003-pihole/quickstart.md
   git commit -m "docs: Update Pi-hole quickstart"
   git push origin main
   ```

3. **Sync to Wiki**:
   ```bash
   ./scripts/wiki/sync-to-wiki.sh
   ```

### Adding New Features

When creating a new feature (e.g., `011-new-feature`):

1. Create feature using SpecKit: `/speckit.specify "description"`
2. Complete planning: `/speckit.plan` and `/speckit.tasks`
3. Sync to Wiki: `./scripts/wiki/sync-to-wiki.sh`

The new feature will automatically appear in the Wiki.

### Automated Sync via GitHub Actions

The repository includes a GitHub Actions workflow that automatically syncs documentation to the Wiki when changes are pushed to the `main` branch.

**Workflow File**: `.github/workflows/wiki-sync.yml`

**Triggers**:
- Push to `main` branch with changes to:
  - `specs/**/*.md` (any documentation files)
  - `scripts/wiki/**` (sync scripts)
  - `.github/workflows/wiki-sync.yml` (workflow file itself)
- Manual trigger via workflow_dispatch

**What it does**:
1. Checks out the repository
2. Configures Git with bot credentials
3. Makes wiki sync scripts executable
4. Runs `sync-to-wiki.sh --with-sidebar`
5. Pushes changes to Wiki repository

**View workflow runs**:
```bash
# Via GitHub CLI
gh run list --workflow=wiki-sync.yml

# Or visit
https://github.com/cbenitezpy-ueno/chocolandia_kube/actions/workflows/wiki-sync.yml
```

**Manual trigger**:
```bash
# Trigger workflow manually via GitHub CLI
gh workflow run wiki-sync.yml

# Or use the GitHub Actions UI
```

With this automation, you only need to:
1. Edit files in `specs/` directory
2. Commit and push to `main` branch
3. GitHub Actions automatically syncs to Wiki

No manual sync script execution required!

## Troubleshooting

### "Permission denied" when pushing

**Cause**: GitHub authentication not configured

**Solution**:
```bash
# Verify SSH access
ssh -T git@github.com

# Or use GitHub CLI
gh auth login
```

### "Wiki repository not found"

**Cause**: GitHub Wiki not initialized

**Solution**:
1. Go to https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki
2. Click "Create the first page" to initialize
3. Re-run sync script

### Links broken on Wiki pages

**Cause**: Link transformation failed or images not accessible

**Solution**:
```bash
# Run dry-run to see transformation output
./scripts/wiki/sync-to-wiki.sh --dry-run | grep -i "link\|image"

# Check generated pages
cat /tmp/chocolandia_kube.wiki/Feature-XXX-Name.md
```

### Sync shows "no changes detected"

**Cause**: Documentation hasn't changed since last sync (expected behavior)

**Solution**: This is normal. If you made changes but script doesn't detect them:
```bash
# Force regeneration
rm -rf /tmp/chocolandia_kube.wiki
./scripts/wiki/sync-to-wiki.sh
```

## Maintenance

### Change Detection

The sync script only commits if Wiki content actually changed, avoiding empty commits.

### Validation

Markdown syntax is validated before pushing. Invalid markdown will be reported but not block sync (Wiki renders best-effort).

### Security

- Scripts check for credentials/secrets before pushing (credentials, API keys, internal IPs)
- Access control inherited from repository permissions (public repo = public Wiki)

## Future Enhancements

- **GitHub Actions**: Automatic sync on push to main branch (P3 priority)
- **Sidebar Navigation**: Optional `_Sidebar.md` generation for easier navigation
- **Incremental Sync**: Only regenerate pages for changed features
- **Image Upload**: Automatic upload of images to Wiki instead of raw URLs

## References

- [GitHub Wiki Documentation](https://docs.github.com/en/communities/documenting-your-project-with-wikis)
- [Feature Specification](../../specs/010-github-wiki-docs/spec.md)
- [Implementation Plan](../../specs/010-github-wiki-docs/plan.md)
- [Quick Start Guide](../../specs/010-github-wiki-docs/quickstart.md)

---

**Remember**: Always edit documentation in the repository (`specs/` directory), never directly in Wiki. Wiki changes will be overwritten on next sync.
