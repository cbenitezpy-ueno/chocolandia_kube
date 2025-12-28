# Implementation Plan: Documentation Audit and Wiki Sync

**Branch**: `024-docs-wiki-sync` | **Date**: 2025-12-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/024-docs-wiki-sync/spec.md`

## Summary

Audit all 24 feature specifications to identify outdated or incomplete documentation, update CLAUDE.md to reflect current cluster state, and synchronize all documentation to the GitHub Wiki using existing scripts. This is a documentation maintenance feature with no new code development.

## Technical Context

**Language/Version**: Bash scripting (wiki sync scripts), Markdown (documentation)
**Primary Dependencies**: Git, gh CLI, kubectl, existing wiki scripts in scripts/wiki/
**Storage**: N/A (documentation only)
**Testing**: Manual verification, wiki sync --dry-run validation
**Target Platform**: GitHub Wiki, local repository
**Project Type**: Documentation/Operations (no application code)
**Performance Goals**: N/A (documentation task)
**Constraints**: Must not expose sensitive information in public Wiki
**Scale/Scope**: 24 feature directories, 1 CLAUDE.md file, 1 GitHub Wiki

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code | N/A | Documentation only, no infrastructure changes |
| II. GitOps Workflow | ✅ PASS | Feature branch workflow followed |
| VIII. Documentation-First | ✅ PASS | Core objective of this feature |
| V. Security Hardening | ✅ PASS | Audit will verify no secrets in wiki |

**Post-Phase 1 Re-check**: All gates pass. Documentation audit aligns with Documentation-First principle.

## Project Structure

### Documentation (this feature)

```text
specs/024-docs-wiki-sync/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: Documentation state analysis
├── data-model.md        # Phase 1: Documentation inventory
├── quickstart.md        # Phase 1: Step-by-step audit and sync guide
├── contracts/           # Phase 1: Audit checklist template
│   └── audit-checklist.yaml
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Existing Wiki Infrastructure

```text
scripts/wiki/
├── sync-to-wiki.sh          # Main sync orchestrator
├── generate-homepage.sh     # Wiki homepage generator
├── generate-feature-page.sh # Individual feature page generator
├── generate-sidebar.sh      # Sidebar navigation generator
├── validate-markdown.sh     # Markdown validation
├── lib/
│   └── utils.sh             # Shared utilities
└── README.md                # Script documentation
```

**Structure Decision**: This feature uses existing wiki scripts in scripts/wiki/. No new source code required. Documentation updates will be made directly to specs/ and CLAUDE.md.

## Implementation Phases

### Phase 1: Documentation Audit

1. List all 24 feature directories
2. For each feature, verify spec.md exists and is complete
3. Cross-reference with current Terraform state and kubectl output
4. Identify outdated information (versions, IPs, configurations)

### Phase 2: CLAUDE.md Verification

1. Verify MetalLB IP assignments against actual LoadBalancer services
2. Verify technology versions against deployed components
3. Verify recent changes section includes features 020-024
4. Update any outdated or missing information

### Phase 3: Wiki Script Validation

1. Run `./scripts/wiki/sync-to-wiki.sh --dry-run`
2. Verify all features generate pages correctly
3. Fix any script issues discovered
4. Test markdown rendering

### Phase 4: Wiki Sync

1. Initialize GitHub Wiki if not already done
2. Run full wiki sync
3. Verify all pages accessible
4. Verify navigation links work

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Audit approach | Manual review with kubectl/tofu verification | Most accurate for complex infrastructure state |
| Wiki sync method | Existing scripts | Already developed in feature 010, functional |
| Scope limit | Active features only | Deprecated features marked but not detailed |

## Complexity Tracking

No complexity violations. This is a documentation maintenance task using existing infrastructure.

## Dependencies

- kubectl access to cluster
- GitHub Wiki enabled on repository
- Existing wiki sync scripts functional
- ssh access to nodes (for verification if needed)

## Risks

| Risk | Mitigation |
|------|------------|
| Sensitive info in docs | Manual review before wiki sync |
| Wiki scripts broken | Run --dry-run first, fix issues |
| Too many outdated items | Prioritize active/recent features |

## Artifacts Generated

- [x] `plan.md` - This implementation plan
- [x] `research.md` - Documentation state analysis
- [x] `data-model.md` - Documentation inventory
- [x] `quickstart.md` - Step-by-step guide
- [x] `contracts/audit-checklist.yaml` - Audit template
- [x] `tasks.md` - Task breakdown (42 tasks across 7 phases)
