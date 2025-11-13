# Research: GitHub Wiki Documentation Hub

**Feature**: 010-github-wiki-docs
**Date**: 2025-11-13
**Purpose**: Research GitHub Wiki synchronization approaches, best practices, and implementation strategies

## Research Questions

1. How can we programmatically sync content to GitHub Wiki?
2. What are the constraints and limitations of GitHub Wiki?
3. What's the best approach for consolidating multiple documentation files into Wiki pages?
4. How do we handle markdown compatibility between repository and Wiki?
5. What naming conventions work best for Wiki page URLs?

## Findings

### 1. GitHub Wiki Synchronization Approaches

**Decision**: Use Git-based Wiki synchronization (clone Wiki repo, commit changes, push)

**Approaches Evaluated**:

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Git-based sync** (clone Wiki.git, commit, push) | Full control, works with standard Git tools, supports batch operations, reliable | Requires Git operations, slightly more complex than API | ✅ **SELECTED** |
| **GitHub CLI (`gh`)** | Simple commands, official tool, handles authentication | Limited Wiki support (gh doesn't have native Wiki commands) | ❌ Not sufficient alone |
| **GitHub API** | Programmatic access | No direct Wiki API - Wiki is a separate Git repo | ❌ Not applicable |
| **Manual edits** | Simple for small changes | Not scalable, error-prone, no automation | ❌ Rejected |

**Rationale**:
- GitHub Wiki is backed by a separate Git repository at `https://github.com/user/repo.wiki.git`
- We can clone this repo, generate/update pages as markdown files, commit, and push
- This approach allows batch processing of all features in a single operation
- Standard Git operations are well-understood and testable

**Implementation Pattern**:
```bash
# Clone Wiki repo
git clone https://github.com/cbenitezpy-ueno/chocolandia_kube.wiki.git /tmp/wiki

# Generate/update Wiki pages
./scripts/wiki/generate-homepage.sh > /tmp/wiki/Home.md
for feature in specs/*/; do
  ./scripts/wiki/generate-feature-page.sh "$feature" > "/tmp/wiki/Feature-XXX.md"
done

# Commit and push
cd /tmp/wiki
git add .
git commit -m "Sync documentation from repository"
git push origin master
```

### 2. GitHub Wiki Constraints and Limitations

**Key Constraints Identified**:

- **File naming**: Wiki page filenames become URLs (Home.md → /Home, Feature-001.md → /Feature-001)
  - Spaces in filenames become hyphens in URLs
  - Special characters are URL-encoded
  - Best practice: Use `Feature-001-K3s-Cluster-Setup.md` for readable URLs

- **Markdown rendering**: GitHub Wiki uses GitHub Flavored Markdown (GFM)
  - Same as repository README files
  - Supports tables, code blocks, task lists, etc.
  - Internal wiki links: `[[Page Name]]` or `[[Link Text|Page Name]]`
  - External links: Standard markdown `[text](url)`

- **File size**: No documented hard limit, but practical limit around 1-2MB per page
  - Our largest docs are ~50KB, well within limits

- **Images**: Must be uploaded to Wiki or linked externally
  - Wiki upload: Drag-drop in web UI or commit to Wiki repo
  - External: Link to repository raw files or external hosting
  - Recommendation: Use repository raw URLs for diagrams (single source of truth)

- **Sidebar**: Optional `_Sidebar.md` file for navigation
  - Displayed on all Wiki pages
  - Useful for quick navigation between features

- **Footer**: Optional `_Footer.md` file
  - Displayed on all pages
  - Can include "Last updated" timestamp or contribution guidelines

### 3. Documentation Consolidation Strategy

**Decision**: One Wiki page per feature, consolidating all documentation files into sections

**Alternatives Considered**:

| Strategy | Pros | Cons | Verdict |
|----------|------|------|---------|
| **One page per feature** (consolidate spec, plan, quickstart, etc.) | Easy navigation (single page per feature), fewer Wiki pages, mirrors user mental model | Potentially long pages | ✅ **SELECTED** |
| **One page per doc type** (Feature-001-Spec, Feature-001-Plan, etc.) | Granular access, shorter pages | More pages to manage, harder navigation (5-6 pages per feature = 50+ pages) | ❌ Too fragmented |
| **Hierarchical pages** (Feature-001 with subpages) | Logical organization | GitHub Wiki doesn't support true hierarchy, only naming conventions | ❌ Not natively supported |

**Page Structure** (per feature):
```markdown
# Feature XXX: Feature Name

[🏠 Back to Documentation Index](Home)

---

## Quick Start

[Content from quickstart.md]

---

## Specification

[Content from spec.md - User Scenarios, Requirements, Success Criteria]

---

## Implementation Plan

[Content from plan.md - Technical Context, Architecture, Constitution Check]

---

## Data Model

[Content from data-model.md]

---

## Research & Decisions

[Content from research.md]

---

## Tasks

[Summary from tasks.md - link to full file in repo if too long]

---

**Source**: This documentation is auto-generated from the [chocolandia_kube repository](https://github.com/cbenitezpy-ueno/chocolandia_kube/tree/main/specs/XXX-feature-name).
**Last Synced**: [timestamp]
**Edit**: Changes should be made in the repository and synced to Wiki.
```

**Handling Large Files**:
- If consolidated page exceeds ~500 lines, consider summarizing tasks.md with link to full file
- Collapsible sections using `<details>` tags for long content (GFM supports HTML)

### 4. Markdown Compatibility

**Decision**: Minimal transformations needed; most repository markdown works as-is on Wiki

**Compatibility Analysis**:

| Markdown Feature | Repository | Wiki | Transformation Needed |
|------------------|------------|------|----------------------|
| Headers | ✅ Supported | ✅ Supported | None |
| Code blocks | ✅ Supported | ✅ Supported | None |
| Tables | ✅ Supported | ✅ Supported | None |
| Task lists | ✅ Supported | ✅ Supported | None |
| Internal links | Relative paths (`./spec.md`) | Wiki links (`[[Home]]`) | ✅ **Convert relative links to Wiki links** |
| Images | Relative paths (`./images/diagram.png`) | Wiki uploads or raw URLs | ✅ **Convert to raw GitHub URLs** |
| Footnotes | ✅ Supported | ✅ Supported | None |
| Frontmatter | ❌ Displayed as text | ❌ Displayed as text | ✅ **Strip YAML frontmatter if present** |

**Required Transformations**:
1. **Internal links**: `./quickstart.md` → `[[Feature-XXX-Name#quick-start]]` (section link within Wiki page)
2. **External links to other features**: `../001-k3s/spec.md` → `[[Feature-001-K3s-Cluster-Setup#specification]]`
3. **Images**: `./images/diagram.png` → `https://raw.githubusercontent.com/cbenitezpy-ueno/chocolandia_kube/main/specs/XXX-feature/images/diagram.png`
4. **Remove frontmatter**: Strip any YAML front matter blocks (currently none in our docs)

**Implementation**: Use `sed` or simple text processing in sync scripts to handle transformations

### 5. Wiki Page Naming Conventions

**Decision**: Use pattern `Feature-XXX-Short-Name.md` for readability and consistency

**Naming Pattern**:
- **Homepage**: `Home.md` (GitHub Wiki convention for main page)
- **Features**: `Feature-001-K3s-Cluster-Setup.md`, `Feature-002-K3s-MVP-Eero.md`, etc.
  - Mirrors directory names from `specs/001-k3s-cluster-setup/`
  - URL becomes `/Feature-001-K3s-Cluster-Setup` (readable, bookmarkable)
- **Sidebar** (optional): `_Sidebar.md` (navigation menu)
- **Footer** (optional): `_Footer.md` (common footer for all pages)

**Alternatives Rejected**:
- `001-K3s-Cluster-Setup.md` - Less clear it's a feature page
- `K3s-Cluster-Setup.md` - Loses feature numbering
- `Specs/001-K3s.md` - GitHub Wiki doesn't support directories in URLs

### 6. Homepage/Index Generation

**Decision**: Generate dynamic table of contents with feature metadata extracted from spec files

**Homepage Structure**:
```markdown
# Chocolandia Kube Documentation

Welcome to the chocolandia_kube homelab documentation! This Wiki provides comprehensive guides for all infrastructure features.

## Features

| # | Feature | Status | Description | Quick Start |
|---|---------|--------|-------------|-------------|
| 001 | [K3s Cluster Setup](Feature-001-K3s-Cluster-Setup) | ✅ Complete | Initial K3s cluster provisioning on Lenovo nodes | [[Quick Start]](Feature-001-K3s-Cluster-Setup#quick-start) |
| 002 | [K3s MVP Eero](Feature-002-K3s-MVP-Eero) | ✅ Complete | K3s deployment on Eero network | [[Quick Start]](Feature-002-K3s-MVP-Eero#quick-start) |
| 003 | [Pi-hole](Feature-003-Pihole) | ✅ Complete | DNS ad blocker deployment | [[Quick Start]](Feature-003-Pihole#quick-start) |
| ... | ... | ... | ... | ... |

## Documentation Types

Each feature includes:
- **Quick Start**: Step-by-step deployment guide
- **Specification**: User scenarios, requirements, success criteria
- **Implementation Plan**: Technical context, architecture decisions
- **Data Model**: Entities, relationships, state transitions
- **Research**: Technology decisions and rationale
- **Tasks**: Detailed implementation task breakdown

## Contributing

Documentation is maintained in the [chocolandia_kube repository](https://github.com/cbenitezpy-ueno/chocolandia_kube).

To update documentation:
1. Edit files in `specs/XXX-feature-name/` directory
2. Run `./scripts/wiki/sync-to-wiki.sh` to sync to Wiki
3. Or wait for automated sync (runs on every merge to main - future)

**Do not edit Wiki pages directly** - changes will be overwritten on next sync.

---

*Last updated: [timestamp] | Generated by [sync-to-wiki.sh](https://github.com/cbenitezpy-ueno/chocolandia_kube/blob/main/scripts/wiki/sync-to-wiki.sh)*
```

**Metadata Extraction**:
- Feature number, name: from directory name `specs/001-k3s-cluster-setup/`
- Description: extract from `spec.md` first paragraph or summary section
- Status: check for existence of `tasks.md` (Complete) vs. only `spec.md` (In Progress)
- Quick Start availability: check if `quickstart.md` exists

### 7. Sync Automation Strategy

**Decision**: Start with manual sync script, plan for GitHub Actions automation later

**Phase 1 (MVP)**: Manual sync script
- Run `./scripts/wiki/sync-to-wiki.sh` manually when documentation changes
- Script checks for changes before pushing (avoid empty commits)
- Dry-run mode for validation: `./scripts/wiki/sync-to-wiki.sh --dry-run`

**Phase 2 (Future)**: GitHub Actions automation
- Trigger on push to main branch that modifies `specs/**/*.md`
- Runs sync script automatically
- Comments on PR with "Wiki will be updated on merge"
- Requires: GitHub Actions workflow, Wiki write permissions via GitHub token

**Why Manual First**:
- Simpler to implement and test
- Allows learning how Wiki sync works before automating
- Easier to iterate on page structure and formatting
- GitHub Actions can be added incrementally (P3 priority)

## Best Practices

1. **Single Source of Truth**: Repository specs/ directory is authoritative; Wiki is read-only mirror
2. **Atomic Updates**: Sync all features in one operation to maintain consistency
3. **Change Detection**: Only commit to Wiki if content actually changed (avoid spam commits)
4. **Validation**: Check markdown syntax and links before pushing to Wiki
5. **Timestamping**: Include sync timestamp in Wiki pages for transparency
6. **Graceful Degradation**: If a feature lacks certain docs (e.g., no quickstart.md), skip that section rather than failing

## Tools Required

- **Git**: For cloning and pushing to Wiki repository
- **Bash**: For sync scripts (macOS/Linux compatible)
- **sed/awk**: For markdown transformations (link rewriting)
- **GitHub CLI (`gh`)**: For authentication and repository metadata (optional, Git credentials work too)
- **markdown-link-check** (optional): For validating links before sync

## Known Issues & Mitigations

| Issue | Impact | Mitigation |
|-------|--------|------------|
| Large consolidated pages | Slow to load, harder to navigate | Use `<details>` tags for collapsible sections; summarize tasks.md |
| Link transformations break | Links 404 on Wiki | Test link rewriting logic thoroughly; dry-run validation |
| Wiki conflicts if edited manually | Sync overwrites manual changes | Clear documentation: "Do not edit Wiki directly" |
| Sync script fails mid-operation | Partial/inconsistent Wiki state | Wrap in transaction (clone to temp dir, push only if all pages generated successfully) |
| Images not accessible | Broken image links | Convert to raw GitHub URLs; test all image links after sync |

## Implementation Priorities

**P1 (MVP)**:
- Git-based sync script (clone, generate, commit, push)
- Homepage generation with feature table
- Feature page consolidation (spec + quickstart + plan)
- Link transformation (relative → Wiki links)

**P2 (Enhanced)**:
- Sidebar navigation (`_Sidebar.md`)
- Image handling (raw GitHub URLs)
- Markdown validation before sync
- Change detection (skip sync if no changes)

**P3 (Nice to Have)**:
- GitHub Actions automation
- Footer with contribution guidelines
- Full tasks.md inclusion (not just summary)
- Collapsible sections for long content

## References

- [GitHub Wiki Documentation](https://docs.github.com/en/communities/documenting-your-project-with-wikis)
- [GitHub Flavored Markdown Spec](https://github.github.com/gfm/)
- [Git Workflows for Wiki Management](https://git-scm.com/book/en/v2/Git-on-the-Server-GitWeb)

