# Feature Specification: Documentation Audit and Wiki Sync

**Feature Branch**: `024-docs-wiki-sync`
**Created**: 2025-12-28
**Status**: Implemented
**Input**: User description: "quiero verificar y actualizar toda la documentacion del proyecto, y reflejar esos cambios en el wiki del proyecto en github"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Audit All Feature Documentation (Priority: P1)

As a project maintainer, I want to review all feature specifications in the repository to identify outdated, incomplete, or inaccurate documentation, so that the documentation accurately reflects the current state of the infrastructure.

**Why this priority**: Documentation accuracy is foundational - all other documentation activities depend on having accurate specs first. Outdated docs lead to confusion and mistakes.

**Independent Test**: Can be fully tested by comparing each feature's spec.md against its current implementation state (Terraform modules, Kubernetes resources) and identifying discrepancies.

**Acceptance Scenarios**:

1. **Given** all feature directories exist in specs/, **When** I audit each feature's documentation, **Then** I can identify which features have outdated information
2. **Given** a feature has been modified since its spec was written, **When** I compare spec vs reality, **Then** the discrepancies are documented for correction
3. **Given** a feature's documentation is complete and accurate, **When** I verify it, **Then** it matches the current implementation without errors

---

### User Story 2 - Update CLAUDE.md Project Guidelines (Priority: P1)

As a developer using Claude Code, I want CLAUDE.md to contain accurate and complete information about the project's current state, so that AI assistance is based on correct context.

**Why this priority**: CLAUDE.md is the primary context file for AI-assisted development. Inaccurate information leads to incorrect suggestions and wasted time.

**Independent Test**: Can be fully tested by verifying each section of CLAUDE.md against actual cluster state (kubectl commands, Terraform state, actual configurations).

**Acceptance Scenarios**:

1. **Given** CLAUDE.md exists with current technologies section, **When** I verify technologies listed, **Then** all technologies match what's actually deployed
2. **Given** CLAUDE.md has MetalLB IP assignments, **When** I compare with `kubectl get svc -A`, **Then** all IP assignments are accurate
3. **Given** CLAUDE.md has recent changes section, **When** I review it, **Then** recent features (020-023) are documented with correct information

---

### User Story 3 - Sync Documentation to GitHub Wiki (Priority: P2)

As a team member or contributor, I want to access project documentation through the GitHub Wiki, so that I don't need to navigate the repository file structure to find documentation.

**Why this priority**: Wiki sync depends on having accurate documentation first (US1, US2). Once docs are accurate, syncing makes them accessible.

**Independent Test**: Can be fully tested by running the wiki sync script and verifying all feature pages appear correctly in the GitHub Wiki.

**Acceptance Scenarios**:

1. **Given** documentation has been audited and updated, **When** I run the wiki sync script, **Then** all 24 features appear in the GitHub Wiki
2. **Given** the Wiki homepage exists, **When** I view it, **Then** I see a table of contents with all features listed
3. **Given** I click on a feature link in the Wiki, **When** the page loads, **Then** I see the consolidated documentation (spec, plan, quickstart, etc.)

---

### User Story 4 - Verify Wiki Script Functionality (Priority: P2)

As a project maintainer, I want to ensure the existing wiki sync scripts work correctly with all current features, so that documentation can be kept in sync reliably.

**Why this priority**: Scripts must work correctly for sustainable documentation maintenance. Without working scripts, sync becomes manual and error-prone.

**Independent Test**: Can be fully tested by running `./scripts/wiki/sync-to-wiki.sh --dry-run` and verifying all outputs are correct.

**Acceptance Scenarios**:

1. **Given** wiki scripts exist in scripts/wiki/, **When** I run sync-to-wiki.sh --dry-run, **Then** it generates pages for all features without errors
2. **Given** a feature has incomplete documentation (missing spec.md), **When** sync runs, **Then** it handles the feature gracefully (skip or indicate pending)
3. **Given** the sync script runs successfully, **When** I examine generated files, **Then** markdown formatting and links are preserved correctly

---

### Edge Cases

- What happens if a feature directory exists but has no spec.md? The audit should flag it as incomplete documentation
- What happens if the GitHub Wiki hasn't been initialized? The sync script should provide clear error message with instructions
- What happens if documentation contains broken internal links? The audit should identify and flag broken links
- What happens if a feature was deleted/deprecated? The documentation should be marked as deprecated or removed
- What happens if specs contain sensitive information (IPs, passwords)? The audit should flag security concerns before wiki sync

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST audit all feature directories (specs/001-* through specs/024-*) for documentation completeness
- **FR-002**: System MUST verify CLAUDE.md accuracy against actual cluster state and recent changes
- **FR-003**: System MUST identify outdated information in specifications (version numbers, IP addresses, configurations)
- **FR-004**: System MUST update documentation to reflect current state of infrastructure
- **FR-005**: System MUST synchronize documentation to GitHub Wiki using existing sync scripts
- **FR-006**: System MUST generate a Wiki homepage listing all features with descriptions
- **FR-007**: System MUST preserve markdown formatting when syncing to Wiki
- **FR-008**: System MUST handle features with incomplete documentation gracefully
- **FR-009**: System MUST validate wiki sync scripts work correctly before full sync
- **FR-010**: System MUST not sync sensitive information (credentials, API keys) to public Wiki

### Key Entities

- **Feature Specification**: Markdown files (spec.md, plan.md, quickstart.md, etc.) in each specs/XXX-feature-name/ directory
- **CLAUDE.md**: Project context file containing guidelines, technologies, IP assignments, and recent changes
- **GitHub Wiki**: External documentation portal synchronized from repository specs
- **Wiki Sync Scripts**: Bash scripts in scripts/wiki/ that generate and publish Wiki pages
- **Documentation Audit Report**: List of findings identifying outdated or missing documentation

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of feature directories (24 features) have been audited for documentation accuracy
- **SC-002**: CLAUDE.md contains accurate information matching current cluster state (verified via kubectl/tofu)
- **SC-003**: GitHub Wiki displays all features with working navigation links
- **SC-004**: Wiki sync script runs without errors on all current features
- **SC-005**: Zero sensitive information (credentials, API keys) exposed in Wiki
- **SC-006**: All documentation reflects changes from recent features (020-023)

## Assumptions

1. GitHub Wiki is enabled for the chocolandia_kube repository
2. Wiki sync scripts (scripts/wiki/) are functional and require no major modifications
3. Documentation updates will be made in the repository specs/, not directly in Wiki
4. Cluster access is available for verification (kubectl, SSH to nodes)
5. No structural changes needed to existing specs - only content updates
6. Recent feature implementations (020-023) have accurate documentation that may need minor updates

## Out of Scope

- Creating new documentation for features that never had documentation
- Restructuring the specs directory organization
- Implementing automated documentation testing/validation
- Creating new wiki scripts or automation
- Translating documentation to other languages
- Adding new sections to CLAUDE.md beyond updating existing ones
- Changing documentation format or templates

## Dependencies

- kubectl access to cluster for verification
- SSH access to nodes for verification (if needed)
- GitHub repository write access
- GitHub Wiki write access
- Existing wiki sync scripts must be functional

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Documentation inconsistencies too numerous to address | Medium | High | Prioritize critical features (active/recent) first |
| Wiki sync script has bugs | Low | Medium | Run --dry-run first, fix issues before real sync |
| Sensitive information accidentally synced | Low | High | Review all content before wiki sync |
| Wiki not initialized | Low | Low | Initialize Wiki manually if needed |
