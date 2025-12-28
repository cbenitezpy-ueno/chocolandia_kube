# Research: Documentation Audit and Wiki Sync

**Feature**: 024-docs-wiki-sync
**Date**: 2025-12-28
**Status**: Complete

## Executive Summary

The chocolandia_kube repository has comprehensive documentation across 24 feature directories (specs/001-* through specs/024-*). All features have complete spec artifacts (spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md). The existing wiki sync scripts (scripts/wiki/) are ready to use. CLAUDE.md needs verification against current cluster state.

## Current Documentation State

### Feature Directory Inventory

| Range | Features | Doc Files | Status |
|-------|----------|-----------|--------|
| 001-009 | 9 features | 6 each | Complete (original features) |
| 010-014 | 5 features | 6-7 each | Complete |
| 015-019 | 5 features | 6 each | Complete |
| 020-023 | 4 features | 6-7 each | Complete (recent) |
| 024 | 1 feature | 2 (in progress) | This feature |

**Total**: 24 feature directories, ~150 markdown files

### Documentation Completeness by Feature

All features 001-023 have the standard artifact set:
- spec.md (feature specification)
- plan.md (implementation plan)
- research.md (technical research)
- data-model.md (entity documentation)
- quickstart.md (implementation guide)
- tasks.md (task breakdown)

Some features have additional files:
- 006-cert-manager: DEPLOYMENT.md, GRAFANA_DASHBOARD.md
- 008-gitops-argocd: requirements-checklist.md
- 014-monitoring-alerts: edge-cases.md
- 021-monitoring-stack-upgrade: rollback-procedure.md

## Research Questions & Findings

### RQ-001: What documentation needs updating?

**Decision**: Focus on CLAUDE.md and recent features (020-023)

**Rationale**:
- CLAUDE.md is read by Claude Code on every interaction - accuracy is critical
- Recent features (020-023) are most likely to have accurate documentation
- Older features (001-019) were likely accurate when created but may have drifted

**Analysis**:
- CLAUDE.md last major update: Feature 023 (K3s secret encryption)
- Recent Changes section shows 021-023, needs 024
- MetalLB IPs need verification
- Monitoring stack version needs verification (upgraded to 68.4.0)

### RQ-002: What is the state of wiki sync scripts?

**Decision**: Scripts are functional but need testing

**Rationale**: Scripts were created in feature 010-github-wiki-docs and haven't been run recently.

**Scripts Available**:
| Script | Purpose | Status |
|--------|---------|--------|
| sync-to-wiki.sh | Main orchestrator | Functional |
| generate-homepage.sh | Wiki home page | Functional |
| generate-feature-page.sh | Individual feature pages | Functional |
| generate-sidebar.sh | Navigation sidebar | Functional |
| validate-markdown.sh | Markdown validation | Functional |

**Test Plan**:
1. Run `./scripts/wiki/sync-to-wiki.sh --dry-run`
2. Verify all 24 features generate pages
3. Check for any errors or warnings

### RQ-003: Is GitHub Wiki initialized?

**Decision**: Need to verify and initialize if not

**Rationale**: Wiki must exist before sync can push content.

**Verification Steps**:
1. Check if wiki repository exists: `git ls-remote https://github.com/cbenitezpy-ueno/chocolandia_kube.wiki.git`
2. If not initialized, create first page manually via GitHub UI
3. Then sync script can clone and update

### RQ-004: What sensitive information might be in documentation?

**Decision**: Review before wiki sync

**Potential Concerns**:
- IP addresses (192.168.4.x) - Acceptable for homelab documentation
- SSH usernames (chocolim) - Acceptable
- Node names (master1, nodo03) - Acceptable
- API endpoints - Verify no tokens/keys

**NOT acceptable for wiki**:
- Passwords (Grafana admin password in CLAUDE.md - reference only, not value)
- API keys
- SSH private keys
- Secrets content

**Mitigation**: All specs reference secrets by location, not content. Safe for wiki.

### RQ-005: CLAUDE.md sections needing verification

**Sections to Verify**:

1. **MetalLB IP Assignments**
   - 192.168.4.200: pihole-dns (verify)
   - 192.168.4.202: traefik (verify)
   - 192.168.4.203: redis-shared-external (verify)
   - 192.168.4.204: postgres-ha-external (verify)

2. **Monitoring Stack**
   - Current version: 68.4.0 (upgraded in 021)
   - Components versions (verify)

3. **K3s Secret Encryption**
   - Section added in 023 (verify accuracy)

4. **Recent Changes**
   - Add 024-docs-wiki-sync entry

## Technical Details

### Wiki Sync Process

```text
1. Clone wiki repository to /tmp/chocolandia_kube.wiki
2. Generate Home.md (homepage with feature table)
3. Generate individual feature pages (XXX-Feature-Name.md)
4. Optionally generate _Sidebar.md (navigation)
5. Commit and push to wiki repository
```

### Feature Page Structure

Each wiki page consolidates:
- Feature header with metadata
- Spec summary
- Plan summary
- Quickstart guide
- Links to full documentation in repo

## Implementation Order

1. **Verify cluster state** (kubectl commands)
   - Get LoadBalancer services and IPs
   - Get monitoring stack version
   - Verify encryption status

2. **Update CLAUDE.md** (if needed)
   - Correct any outdated information
   - Add recent changes entry

3. **Test wiki sync**
   - Run --dry-run
   - Verify output
   - Fix any issues

4. **Execute wiki sync**
   - Initialize wiki if needed
   - Run full sync
   - Verify wiki accessible

## Sources

- specs/010-github-wiki-docs/spec.md - Wiki documentation feature
- scripts/wiki/README.md - Wiki scripts documentation
- CLAUDE.md - Current project guidelines
