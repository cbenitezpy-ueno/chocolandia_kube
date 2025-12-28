# Data Model: Documentation Audit and Wiki Sync

**Feature**: 024-docs-wiki-sync
**Date**: 2025-12-28

## Overview

This feature involves documentation entities rather than application data. The "data model" represents the documentation structure and inventory.

## Key Entities

### Feature Directory

A directory in specs/ containing documentation for a single feature.

| Attribute | Type | Description |
|-----------|------|-------------|
| number | String | 3-digit feature number (e.g., "024") |
| name | String | Feature short name (e.g., "docs-wiki-sync") |
| path | Path | Full path (e.g., "specs/024-docs-wiki-sync/") |
| artifacts | List | Documentation files present |
| status | Enum | Draft, Implemented, Deprecated |

**Standard Artifacts**:
- spec.md (required)
- plan.md (required)
- research.md (required)
- data-model.md (required)
- quickstart.md (required)
- tasks.md (required)
- checklists/ (optional)
- contracts/ (optional)

### CLAUDE.md

The project context file read by Claude Code for AI assistance.

| Section | Description | Verification Method |
|---------|-------------|---------------------|
| Active Technologies | Technologies used per feature | Compare to Terraform state |
| Project Structure | Directory layout | ls command |
| Commands | Common commands | N/A (reference) |
| Code Style | Style guidelines | N/A (guidelines) |
| Recent Changes | Last 3-5 features | Compare to git log |
| MetalLB IP Assignments | LoadBalancer IPs | kubectl get svc |
| Local CA | Certificate authority | kubectl get secret |
| Nexus Repository | Artifact repository | kubectl get pods |
| Monitoring Stack | Prometheus/Grafana | helm list |
| K3s Secret Encryption | Encryption status | ssh + k3s command |

### GitHub Wiki

External documentation portal synchronized from repository.

| Page Type | Source | Generator |
|-----------|--------|-----------|
| Home.md | All specs | generate-homepage.sh |
| XXX-Feature-Name.md | specs/XXX-feature-name/ | generate-feature-page.sh |
| _Sidebar.md | All specs | generate-sidebar.sh |

### Audit Finding

A discrepancy found during documentation audit.

| Attribute | Type | Description |
|-----------|------|-------------|
| location | Path | File and line/section |
| type | Enum | Outdated, Missing, Inaccurate, Sensitive |
| current_value | String | What documentation says |
| actual_value | String | What reality shows |
| priority | Enum | High, Medium, Low |
| action | String | Required correction |

## Documentation Inventory

### Feature Count by Status

| Status | Count | Examples |
|--------|-------|----------|
| Implemented | 25 | 001-023 (includes multiple features numbered 001) |
| In Progress | 1 | 024 |
| Deprecated | 0 | - |

### Artifact Coverage

All 25 implemented features have complete artifact sets (6 files each).

Total documentation files: ~150 markdown files

## State Transitions

### Documentation Lifecycle

```
Draft → Implemented → (optionally) Deprecated
```

### Wiki Sync States

```
Not Synced → Dry Run OK → Synced → (on repo change) → Needs Sync
```

## Relationships

```
Repository
├── CLAUDE.md (1)
├── specs/ (26 feature directories)
│   └── XXX-feature/
│       ├── spec.md
│       ├── plan.md
│       ├── research.md
│       ├── data-model.md
│       ├── quickstart.md
│       └── tasks.md
├── scripts/wiki/ (sync scripts)
└── GitHub Wiki (external)
    ├── Home.md
    └── XXX-Feature-Name.md (per feature)
```

## Validation Rules

1. Every feature directory MUST have spec.md
2. CLAUDE.md IP assignments MUST match kubectl output
3. Wiki pages MUST NOT contain credentials or secrets
4. Feature numbers MUST be unique and sequential
5. Recent Changes MUST include last 3-5 features
