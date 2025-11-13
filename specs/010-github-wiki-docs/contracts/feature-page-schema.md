# Feature Wiki Page Schema

**File**: `Feature-{number}-{name}.md`
**Purpose**: Consolidated documentation for a single feature

## Structure

```markdown
# Feature {number}: {Feature Name}

[🏠 Back to Documentation Index](Home)

---

## Quick Start

[Content from quickstart.md if exists, otherwise omit this section]

---

## Specification

[Content from spec.md - REQUIRED]

---

## Implementation Plan

[Content from plan.md if exists, otherwise omit this section]

---

## Data Model

[Content from data-model.md if exists, otherwise omit this section]

---

## Research & Decisions

[Content from research.md if exists, otherwise omit this section]

---

## Tasks

[Content from tasks.md if exists, may be summarized if very long, otherwise omit this section]

---

**Source**: This documentation is auto-generated from the [chocolandia_kube repository](https://github.com/cbenitezpy-ueno/chocolandia_kube/tree/main/specs/{number}-{name}).

**Last Synced**: {ISO 8601 timestamp}

**Edit**: Changes should be made in the repository and synced to Wiki.
```

## Field Specifications

### Feature Title
- **Type**: String
- **Pattern**: `Feature {3-digit-number}: {Capitalized Feature Name}`
- **Example**: "Feature 003: Pi-hole", "Feature 010: GitHub Wiki Docs"
- **Required**: Yes
- **Extraction**:
  - Number: from directory name `specs/003-pihole/`
  - Name: from spec.md title or directory name (kebab-case → Title Case)

### Navigation Link
- **Type**: Wiki link to homepage
- **Pattern**: `[🏠 Back to Documentation Index](Home)` or `[[Home|🏠 Back to Documentation Index]]`
- **Required**: Yes
- **Purpose**: Allow users to return to main index from any feature page

### Section: Quick Start
- **Source**: `quickstart.md` file
- **Required**: No (only if file exists and non-empty)
- **Heading**: `## Quick Start`
- **Content Transformations**:
  - Preserve all markdown formatting
  - Transform relative links: `./other.md` → `#other-section`
  - Transform images: `./images/x.png` → `https://raw.githubusercontent.com/.../x.png`

### Section: Specification
- **Source**: `spec.md` file
- **Required**: Yes (abort sync if missing)
- **Heading**: `## Specification`
- **Content Transformations**:
  - Include all content from spec.md
  - May strip YAML frontmatter if present (---...---)
  - Preserve all sections: User Scenarios, Requirements, Success Criteria, etc.
  - Transform links as described above

### Section: Implementation Plan
- **Source**: `plan.md` file
- **Required**: No (only if file exists)
- **Heading**: `## Implementation Plan`
- **Content Transformations**:
  - Include Summary, Technical Context, Constitution Check, Project Structure
  - May omit internal workflow notes if present
  - Transform links

### Section: Data Model
- **Source**: `data-model.md` file
- **Required**: No (only if file exists)
- **Heading**: `## Data Model`
- **Content**: Full data-model.md content with transformations

### Section: Research & Decisions
- **Source**: `research.md` file
- **Required**: No (only if file exists)
- **Heading**: `## Research & Decisions`
- **Content**: Full research.md content with transformations

### Section: Tasks
- **Source**: `tasks.md` file
- **Required**: No (only if file exists)
- **Heading**: `## Tasks`
- **Content**:
  - If file < 500 lines: Include full content
  - If file > 500 lines: Include summary + link to full file in repository
  - Summary format:
    ```markdown
    ## Tasks

    This feature has {count} implementation tasks. [View full task list](https://github.com/.../tasks.md).

    ### Task Summary
    - Phase 1: Setup ({count} tasks)
    - Phase 2: Implementation ({count} tasks)
    - Phase 3: Testing ({count} tasks)
    ...
    ```

### Footer
- **Type**: Markdown text block with source attribution
- **Required**: Yes
- **Fields**:
  - **Source**: Link to repository specs directory
  - **Last Synced**: ISO 8601 timestamp
  - **Edit**: Warning about not editing Wiki directly

## Filename Conventions

### Pattern
- `Feature-{number}-{name}.md`
- **number**: 3 digits with leading zeros (001, 010, 025)
- **name**: Feature name in Title-Kebab-Case (capitalized words, hyphens between)

### Examples
- `Feature-001-K3s-Cluster-Setup.md`
- `Feature-003-Pihole.md`
- `Feature-010-Github-Wiki-Docs.md`

### Derivation
From directory name `specs/003-pihole/`:
1. Extract number: `003`
2. Extract name: `pihole`
3. Convert to Title Case: `Pihole` → `Pihole` (single word) or `k3s-cluster-setup` → `K3s-Cluster-Setup`
4. Combine: `Feature-003-Pihole.md`

## Content Transformations

### Relative Links → Wiki Links

| Original (in repo) | Transformed (in Wiki) | Notes |
|--------------------|----------------------|-------|
| `./quickstart.md` | `#quick-start` | Same-feature section link |
| `../001-k3s/spec.md` | `[[Feature-001-K3s-Cluster-Setup#specification]]` | Cross-feature link |
| `[link](./plan.md#section)` | `[link](#implementation-plan)` | Section anchor within page |

### Image Links → Raw GitHub URLs

| Original (in repo) | Transformed (in Wiki) |
|--------------------|----------------------|
| `./images/diagram.png` | `https://raw.githubusercontent.com/cbenitezpy-ueno/chocolandia_kube/main/specs/003-pihole/images/diagram.png` |
| `![alt](../shared/logo.png)` | `![alt](https://raw.githubusercontent.com/cbenitezpy-ueno/chocolandia_kube/main/specs/shared/logo.png)` |

### Headers

- Preserve header levels from source files
- Ensure main sections use `##` (level 2) since page title uses `#` (level 1)
- If source file uses `#` for main sections, promote to `##`

### Code Blocks

- Preserve all code blocks as-is
- Maintain language hints: ` ```bash`, ` ```yaml`, etc.
- No transformations needed (GFM compatible)

## Validation Rules

1. **Filename**: MUST match pattern `Feature-[0-9]{3}-[A-Za-z0-9-]+\.md`
2. **Title**: MUST be `# Feature {number}: {name}`
3. **Navigation link**: MUST be present at top
4. **Specification section**: MUST be present (abort if spec.md missing)
5. **Footer**: MUST include source link and timestamp
6. **Links**: All Wiki links MUST point to valid pages/sections
7. **Images**: All image URLs MUST be absolute (no relative paths)
8. **Markdown**: MUST be valid GFM syntax

## Sample Output

```markdown
# Feature 003: Pi-hole

[🏠 Back to Documentation Index](Home)

---

## Quick Start

Follow these steps to deploy Pi-hole DNS ad blocker to your K3s cluster:

### Prerequisites

- K3s cluster running (Feature 001)
- kubectl configured
- OpenTofu installed

### Deployment

1. Navigate to the terraform module:
   ```bash
   cd terraform/modules/pihole
   ```

2. Apply the configuration:
   ```bash
   tofu apply
   ```

...

---

## Specification

### User Scenarios & Testing

#### User Story 1 - Deploy Pi-hole (Priority: P1)

As a homelab administrator, I want to deploy Pi-hole as a DNS ad blocker...

...

---

## Implementation Plan

### Summary

This feature deploys Pi-hole DNS ad blocker via Kubernetes manifests managed by OpenTofu...

### Technical Context

**Language/Version**: YAML (Kubernetes manifests) / HCL (OpenTofu) 1.6+
**Primary Dependencies**: Pi-hole Docker image, K3s local-path provisioner
...

---

## Data Model

### Entities

#### 1. Pi-hole Instance

The main Pi-hole application running as a Kubernetes Deployment...

...

---

## Research & Decisions

### 1. Deployment Approach

**Decision**: Use Kubernetes manifests via OpenTofu

**Alternatives Considered**:
- Helm chart
- Docker Compose
- Manual YAML apply

...

---

## Tasks

This feature has 111 implementation tasks. [View full task list](https://github.com/cbenitezpy-ueno/chocolandia_kube/blob/main/specs/003-pihole/tasks.md).

### Task Summary
- Phase 1: Setup (4 tasks)
- Phase 2: Foundational (6 tasks)
- Phase 3: User Story 1 - Pi-hole Deployment (26 tasks)
...

---

**Source**: This documentation is auto-generated from the [chocolandia_kube repository](https://github.com/cbenitezpy-ueno/chocolandia_kube/tree/main/specs/003-pihole).

**Last Synced**: 2025-11-13T10:30:00Z

**Edit**: Changes should be made in the repository and synced to Wiki.
```

## Error Handling

| Error Condition | Handling |
|-----------------|----------|
| Missing spec.md | Error: "No spec.md for feature {number}" - skip feature |
| Malformed markdown | Warning: Include as-is, let GitHub Wiki render best-effort |
| Broken image link | Warning: Keep link as-is (will show broken image icon) |
| Invalid header structure | Warning: Preserve original headers |
| Empty documentation file | Skip that section (don't create heading for empty content) |
