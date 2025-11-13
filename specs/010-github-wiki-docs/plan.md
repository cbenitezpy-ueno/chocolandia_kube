# Implementation Plan: GitHub Wiki Documentation Hub

**Branch**: `010-github-wiki-docs` | **Date**: 2025-11-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/010-github-wiki-docs/spec.md`

## Summary

This feature creates a GitHub Wiki documentation portal that makes all chocolandia_kube feature documentation easily accessible and navigable. The solution syncs markdown documentation from the repository's `specs/` directory to GitHub Wiki pages, maintaining the repository as the single source of truth while providing a user-friendly documentation interface.

## Technical Context

**Language/Version**: Bash scripting / Python 3.11+ (for sync automation)
**Primary Dependencies**: GitHub CLI (`gh`), Git, GitHub Wiki API (via gh or git)
**Storage**: GitHub Wiki git repository (separate from main repo), local specs/ directory as source
**Testing**: Bash/shell script testing, markdown validation, link checking
**Target Platform**: GitHub.com hosted Wiki, execution on macOS/Linux development environment
**Project Type**: Documentation infrastructure (automation scripts + Wiki content)
**Performance Goals**: Wiki sync completes in <5 minutes for all 9+ features, homepage generation in <10 seconds
**Constraints**: GitHub Wiki API limitations (file size, naming conventions), markdown compatibility between repo and Wiki rendering
**Scale/Scope**: 9 existing features (001-009), ~50-60 documentation files, expected growth to 20+ features

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Infrastructure as Code - OpenTofu First
**Status**: ✅ PASS (Modified scope - documentation only)
- **Requirement**: All infrastructure MUST be defined in OpenTofu
- **Application**: This feature focuses on documentation infrastructure (Wiki sync) rather than Kubernetes/network infrastructure
- **Compliance**: Wiki sync scripts will be version-controlled in Git. No OpenTofu applicable for GitHub Wiki (SaaS platform)
- **Justification**: GitHub Wiki is a hosted SaaS service; sync automation scripts follow IaC principles (declarative, version-controlled)

### II. GitOps Workflow
**Status**: ✅ PASS
- **Requirement**: Git as single source of truth, changes via Git commits
- **Application**: Repository `specs/` directory is the single source of truth; Wiki is synchronized from Git
- **Compliance**: All documentation changes must be made in repository, then synced to Wiki via automation
- **Enforcement**: Documentation clearly states "do not edit Wiki directly - changes will be overwritten"

### III. Container-First Development
**Status**: ✅ PASS (Not applicable)
- **Requirement**: Application components MUST be containerized
- **Application**: This feature is documentation tooling, not a running application
- **Compliance**: N/A - sync scripts run locally or via GitHub Actions (future), no long-running containers needed

### IV. Observability & Monitoring - Prometheus + Grafana Stack
**Status**: ✅ PASS (Not applicable)
- **Requirement**: Prometheus/Grafana monitoring for infrastructure
- **Application**: Documentation tooling doesn't require observability infrastructure
- **Compliance**: N/A - sync script logs will be captured in shell output or GitHub Actions logs

### V. Security Hardening
**Status**: ✅ PASS
- **Requirement**: Security at network, runtime, and access control layers
- **Application**: Documentation must not leak sensitive information
- **Compliance**:
  - Documentation will be reviewed to ensure no credentials, internal IPs, or API keys before Wiki sync
  - Access control inherited from GitHub repository permissions (public repo = public Wiki)
  - Sync scripts will handle GitHub credentials via environment variables (never committed)

### VI. High Availability (HA) Architecture
**Status**: ✅ PASS (Not applicable)
- **Requirement**: HA infrastructure across dedicated hardware
- **Application**: GitHub Wiki is a hosted service with GitHub's HA guarantees
- **Compliance**: N/A - documentation availability depends on GitHub's SLA

### VII. Test-Driven Learning
**Status**: ✅ PASS
- **Requirement**: Comprehensive testing validates all infrastructure
- **Application**: Sync scripts and Wiki content must be validated
- **Compliance**:
  - Markdown validation before sync (linting, link checking)
  - Sync script testing (dry-run mode, validation of generated Wiki pages)
  - Manual verification after initial sync (all features present, links work, formatting correct)
- **Learning Value**: Tests document expected Wiki structure and teach markdown compatibility

### VIII. Documentation-First
**Status**: ✅ PASS (Core feature purpose)
- **Requirement**: Every decision and component MUST be documented
- **Application**: This feature IS the documentation infrastructure
- **Compliance**:
  - Quickstart guide for using the Wiki sync process
  - Runbook for updating Wiki when documentation changes
  - README documenting sync script usage
  - Comments in sync scripts explaining logic and edge cases

### IX. Network-First Security
**Status**: ✅ PASS (Not applicable)
- **Requirement**: FortiGate/VLAN network security foundation
- **Application**: Documentation tooling doesn't interact with homelab network infrastructure
- **Compliance**: N/A - GitHub Wiki access is over HTTPS from any network

### Constitution Summary

**Overall Status**: ✅ READY TO PROCEED

All applicable principles pass. Non-applicable principles (Container-First, Observability, HA, Network-First) are appropriately scoped out as this is documentation infrastructure rather than runtime services. The feature strongly aligns with GitOps Workflow and Documentation-First principles.

## Project Structure

### Documentation (this feature)

```text
specs/010-github-wiki-docs/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - Wiki API research, sync strategies
├── data-model.md        # Phase 1 output - Wiki page structure, metadata
├── quickstart.md        # Phase 1 output - How to sync docs to Wiki
├── contracts/           # Phase 1 output - Wiki page schemas
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created yet)
```

### Source Code (repository root)

```text
scripts/
├── wiki/
│   ├── sync-to-wiki.sh         # Main sync script (specs/ → Wiki)
│   ├── generate-homepage.sh    # Generate Wiki homepage/index
│   ├── generate-feature-page.sh # Consolidate feature docs into single page
│   ├── validate-markdown.sh    # Pre-sync validation (links, formatting)
│   └── README.md               # Sync script documentation
└── README.md                   # Updated to reference Wiki sync

.github/
└── workflows/
    └── wiki-sync.yml           # (Future) GitHub Action for automated sync

specs/
└── [existing feature directories - source of truth for Wiki content]
```

**Structure Decision**: Single project structure with scripts in `scripts/wiki/`. This follows the existing repository pattern where automation scripts live in `scripts/` (similar to `.specify/scripts/`). GitHub Actions workflow is optional for future automation.

## Complexity Tracking

> **No violations to justify - all constitution gates pass with appropriate scoping.**

