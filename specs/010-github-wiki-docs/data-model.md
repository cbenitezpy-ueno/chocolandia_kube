# Data Model: GitHub Wiki Documentation Hub

**Feature**: 010-github-wiki-docs
**Date**: 2025-11-13
**Purpose**: Define the structure of Wiki pages, metadata, and relationships

## Entities

### 1. Wiki Homepage

The main entry point for all documentation, listing all features.

**Attributes**:
- **filename**: `Home.md` (GitHub Wiki convention)
- **title**: "Chocolandia Kube Documentation"
- **content sections**:
  - Welcome/introduction text
  - Feature table (list of all features)
  - Documentation types explanation
  - Contributing guidelines
- **feature_table**: Array of Feature Summary entries
- **last_updated**: Timestamp of last sync
- **sync_script_reference**: Link to sync script in repository

**Relationships**:
- Contains references to → Feature Wiki Page (many)

**State**: Generated dynamically on each sync (no persistent state)

---

### 2. Feature Wiki Page

Consolidated documentation for a single feature.

**Attributes**:
- **filename**: `Feature-{number}-{name}.md` (e.g., `Feature-001-K3s-Cluster-Setup.md`)
- **feature_number**: String (e.g., "001", "010")
- **feature_name**: String (e.g., "K3s Cluster Setup", "Pi-hole")
- **source_directory**: Path in repository (e.g., `specs/001-k3s-cluster-setup/`)
- **sections**: Array of Documentation Section
- **last_synced**: Timestamp of last sync
- **source_link**: URL to repository specs directory

**Sections** (ordered):
1. Header (feature title, navigation link back to Home)
2. Quick Start (from quickstart.md if exists)
3. Specification (from spec.md)
4. Implementation Plan (from plan.md if exists)
5. Data Model (from data-model.md if exists)
6. Research & Decisions (from research.md if exists)
7. Tasks Summary (from tasks.md if exists, may be abbreviated)
8. Footer (source attribution, last synced timestamp)

**Relationships**:
- Derived from → Feature Documentation Directory (one)
- Referenced by → Wiki Homepage (one)
- Contains → Documentation Section (many)

**State Transitions**:
```
[Not Exists] --sync script creates--> [Created]
[Created] --content changes--> [Updated]
[Updated] --feature deleted--> [Marked Obsolete] (with deprecation notice)
```

---

### 3. Feature Documentation Directory

Source of truth in repository for a single feature's documentation.

**Attributes**:
- **path**: `specs/{number}-{name}/` (e.g., `specs/001-k3s-cluster-setup/`)
- **feature_number**: Extracted from directory name (e.g., "001")
- **feature_name**: Extracted from directory name (e.g., "k3s-cluster-setup")
- **available_docs**: Array of available documentation files
  - `spec.md` (required)
  - `plan.md` (optional)
  - `quickstart.md` (optional)
  - `research.md` (optional)
  - `data-model.md` (optional)
  - `tasks.md` (optional)
- **status**: Enum: "planning", "in_progress", "complete"
  - Logic: "complete" if tasks.md exists, "planning" if only spec.md, else "in_progress"

**Relationships**:
- Generates → Feature Wiki Page (one)
- Contains → Documentation File (many)

**Validation Rules**:
- MUST have `spec.md`
- Directory name MUST match pattern `{3-digit-number}-{kebab-case-name}`
- All markdown files MUST be valid GFM syntax

---

### 4. Documentation Section

A logical section within a Feature Wiki Page, sourced from one documentation file.

**Attributes**:
- **section_type**: Enum: "quickstart", "spec", "plan", "data_model", "research", "tasks"
- **heading**: Section title (e.g., "## Quick Start", "## Specification")
- **content**: Markdown content (transformed from source file)
- **source_file**: Origin file (e.g., `quickstart.md`, `spec.md`)
- **transformed**: Boolean - whether content needed transformations (link rewriting, etc.)

**Relationships**:
- Belongs to → Feature Wiki Page (one)
- Sourced from → Documentation File (one)

**Content Transformations**:
1. **Internal links**: `./other-file.md` → `#section-heading` (Wiki section link)
2. **Cross-feature links**: `../001-k3s/spec.md` → `[[Feature-001-K3s-Cluster-Setup#specification]]`
3. **Images**: `./images/diagram.png` → `https://raw.githubusercontent.com/cbenitezpy-ueno/chocolandia_kube/main/specs/{number}-{name}/images/diagram.png`
4. **Headers**: Promoted by one level if needed (to nest under feature page main heading)

---

### 5. Feature Summary

Metadata about a feature displayed in the Wiki Homepage table.

**Attributes**:
- **feature_number**: String (e.g., "001")
- **feature_name**: String (e.g., "K3s Cluster Setup")
- **status**: Enum: "✅ Complete", "🚧 In Progress", "📝 Planning"
- **description**: Brief one-line description (extracted from spec.md first paragraph)
- **wiki_page_link**: Wiki link to feature page (e.g., `[[Feature-001-K3s-Cluster-Setup]]`)
- **quickstart_available**: Boolean
- **quickstart_link**: Wiki section link if available (e.g., `[[Feature-001-K3s-Cluster-Setup#quick-start]]`)

**Relationships**:
- Represents → Feature Documentation Directory (one)
- Displayed in → Wiki Homepage (one table row)

**Extraction Logic**:
- **feature_number/name**: Parse from directory name `specs/001-k3s-cluster-setup/`
- **status**: Check file existence (tasks.md → Complete, spec.md only → Planning, else In Progress)
- **description**: Extract from `spec.md`:
  - Try first paragraph after feature title
  - Fallback to "User description" input field
  - Fallback to first User Story summary
  - Limit to ~100 characters
- **quickstart_available**: Check if `quickstart.md` exists and is non-empty

---

### 6. Wiki Sidebar (Optional)

Navigation menu displayed on all Wiki pages.

**Attributes**:
- **filename**: `_Sidebar.md` (GitHub Wiki convention)
- **content**: Markdown list of navigation links
- **feature_groups**: Features grouped by category (if needed)

**Example Structure**:
```markdown
### 📚 Documentation

- [🏠 Home](Home)

### 🚀 Features

#### Infrastructure (001-002)
- [001: K3s Cluster Setup](Feature-001-K3s-Cluster-Setup)
- [002: K3s MVP Eero](Feature-002-K3s-MVP-Eero)

#### Services (003-009)
- [003: Pi-hole](Feature-003-Pihole)
- [004: Cloudflare Zero Trust](Feature-004-Cloudflare-Zerotrust)
- [005: Traefik](Feature-005-Traefik)
- [006: Cert Manager](Feature-006-Cert-Manager)
- [007: Headlamp](Feature-007-Headlamp-Web-UI)
- [008: GitOps ArgoCD](Feature-008-Gitops-Argocd)
- [009: Homepage Dashboard](Feature-009-Homepage-Dashboard)

#### Documentation (010+)
- [010: Wiki Docs](Feature-010-Github-Wiki-Docs)
```

**Relationships**:
- References → Feature Wiki Page (many)

**State**: Generated dynamically on each sync, included in Wiki repo commit

---

### 7. Sync State

Metadata tracking the synchronization process (transient, not persisted in Wiki).

**Attributes**:
- **sync_timestamp**: When sync started
- **features_processed**: Count of features synced
- **features_total**: Total features in specs/
- **changes_detected**: Boolean - whether Wiki content changed
- **errors**: Array of errors encountered (file missing, validation failed, etc.)
- **dry_run**: Boolean - whether this is a validation-only run

**Relationships**:
- N/A (transient state during sync execution)

**State Transitions**:
```
[Start] --initialize--> [Scanning specs/]
[Scanning specs/] --found features--> [Generating Pages]
[Generating Pages] --all generated--> [Validating]
[Validating] --valid--> [Committing to Wiki]
[Validating] --invalid--> [Error State]
[Committing to Wiki] --pushed--> [Complete]
[Error State] --logged--> [Complete]
```

---

## Entity Relationships Diagram

```
Wiki Homepage
  │
  ├──> Feature Summary (001) ──> Feature Wiki Page (001) ──┐
  ├──> Feature Summary (002) ──> Feature Wiki Page (002)   │
  ├──> Feature Summary (003) ──> Feature Wiki Page (003)   │
  └──> Feature Summary (...)                               │
                                                            │
                        ┌───────────────────────────────────┘
                        │
                        ▼
               Feature Wiki Page
                        │
                        ├──> Documentation Section (Quick Start)
                        ├──> Documentation Section (Spec)
                        ├──> Documentation Section (Plan)
                        ├──> Documentation Section (Data Model)
                        ├──> Documentation Section (Research)
                        └──> Documentation Section (Tasks)
                                      │
                                      ▼
                        Feature Documentation Directory
                                      │
                                      ├──> spec.md
                                      ├──> quickstart.md
                                      ├──> plan.md
                                      ├──> data-model.md
                                      ├──> research.md
                                      └──> tasks.md

Wiki Sidebar
  └──> References all Feature Wiki Pages (navigation links)
```

## Validation Rules

### Feature Documentation Directory
1. Directory name MUST match pattern: `[0-9]{3}-[a-z0-9-]+`
2. MUST contain `spec.md`
3. All `.md` files MUST be valid markdown (no syntax errors)
4. Feature numbers MUST be unique across specs/

### Feature Wiki Page
1. Filename MUST match pattern: `Feature-[0-9]{3}-[A-Za-z0-9-]+\.md`
2. MUST include navigation link back to Home
3. MUST include source attribution footer
4. MUST include at least "Specification" section (from spec.md)

### Wiki Homepage
1. Filename MUST be `Home.md`
2. Feature table MUST list all features from specs/ directory
3. Feature numbers MUST be in ascending order
4. All Wiki links MUST be valid (point to existing pages)

### Documentation Section
1. Content MUST be valid GitHub Flavored Markdown
2. Internal links MUST be transformed to Wiki link syntax
3. Images MUST use absolute URLs (raw GitHub or external)
4. No YAML frontmatter (if present in source, must be stripped)

## Sample Data

### Feature Summary Example
```json
{
  "feature_number": "003",
  "feature_name": "Pi-hole",
  "status": "✅ Complete",
  "description": "DNS ad blocker deployment via Kubernetes manifests",
  "wiki_page_link": "[[Feature-003-Pihole]]",
  "quickstart_available": true,
  "quickstart_link": "[[Feature-003-Pihole#quick-start]]"
}
```

### Sync State Example
```json
{
  "sync_timestamp": "2025-11-13T10:30:00Z",
  "features_processed": 9,
  "features_total": 9,
  "changes_detected": true,
  "errors": [],
  "dry_run": false
}
```

## Edge Cases

1. **Missing quickstart.md**: Skip "Quick Start" section in Feature Wiki Page, mark as unavailable in Homepage table
2. **Empty spec.md**: ERROR - spec is mandatory, abort sync for that feature
3. **Malformed markdown**: Log warning, include content as-is (GitHub Wiki will render best-effort)
4. **Broken internal links**: Transform to text (not clickable) rather than broken Wiki link
5. **Feature directory without number prefix**: Skip (not a valid feature directory)
6. **Duplicate feature numbers**: ERROR - abort sync, require resolution
7. **Very large tasks.md (>1000 lines)**: Summarize with collapsible `<details>` tag, link to full file in repo
