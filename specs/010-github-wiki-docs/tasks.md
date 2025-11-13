# Tasks: GitHub Wiki Documentation Hub

**Input**: Design documents from `/specs/010-github-wiki-docs/`
**Prerequisites**: plan.md (tech stack, structure), spec.md (user stories), research.md (decisions), data-model.md (entities), contracts/ (schemas)

**Tests**: No explicit tests requested - focus on validation and manual verification

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- Scripts: `/Users/cbenitez/chocolandia_kube/scripts/wiki/`
- Specs: `/Users/cbenitez/chocolandia_kube/specs/`
- GitHub Actions: `/Users/cbenitez/chocolandia_kube/.github/workflows/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create project structure and initialize sync script infrastructure

- [x] T001 Create wiki scripts directory at /Users/cbenitez/chocolandia_kube/scripts/wiki/
- [x] T002 Create initial README.md in scripts/wiki/ with overview and usage instructions
- [x] T003 [P] Verify GitHub Wiki is enabled for repository (navigate to Wiki URL, create first page if needed)
- [x] T004 [P] Verify GitHub authentication configured (test with `git ls-remote https://github.com/cbenitezpy-ueno/chocolandia_kube.wiki.git`)

**Checkpoint**: Infrastructure ready for script development

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core utility functions and validation that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Create utility library script scripts/wiki/lib/utils.sh with common functions (extract feature number, extract feature name, convert kebab-case to Title-Case)
- [x] T006 [P] Create markdown transformation functions in scripts/wiki/lib/transform.sh (relative links → Wiki links, images → raw GitHub URLs)
- [x] T007 [P] Create validation script scripts/wiki/validate-markdown.sh (check markdown syntax, validate file structure)
- [x] T008 Create feature metadata extraction function in scripts/wiki/lib/extract-metadata.sh (get feature number, name, status, description from spec.md)
- [x] T009 Test utility functions with sample feature directory (e.g., specs/001-k3s-cluster-setup/)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Browse Feature Documentation (Priority: P1) 🎯 MVP

**Goal**: Users can access all feature documentation through GitHub Wiki with a central index page

**Independent Test**: Navigate to GitHub Wiki homepage and verify all features listed with clickable links to feature pages

### Implementation for User Story 1

- [x] T010 [P] [US1] Create generate-homepage.sh script in scripts/wiki/ with basic structure (shebang, usage, help text)
- [x] T011 [P] [US1] Create generate-feature-page.sh script in scripts/wiki/ with basic structure
- [x] T012 [US1] Implement homepage header generation in generate-homepage.sh (title, welcome paragraph from homepage-schema.md)
- [x] T013 [US1] Implement feature scanning logic in generate-homepage.sh (find all specs/XXX-* directories, extract numbers)
- [x] T014 [US1] Implement feature metadata extraction for homepage table (number, name, status, description using lib/extract-metadata.sh)
- [x] T015 [US1] Generate feature table rows in homepage (| # | Feature | Status | Description | Quick Start |)
- [x] T016 [US1] Add Documentation Types section to homepage (explain spec, plan, quickstart, etc.)
- [x] T017 [US1] Add Contributing section to homepage (instructions, warning about not editing Wiki directly)
- [x] T018 [US1] Add homepage footer with timestamp and sync script link
- [x] T019 [US1] Implement feature page consolidation in generate-feature-page.sh (combine spec.md, quickstart.md, plan.md, etc. into single page)
- [x] T020 [US1] Add feature page header with title and navigation link back to Home
- [x] T021 [US1] Implement Quick Start section extraction from quickstart.md (if exists) in generate-feature-page.sh
- [x] T022 [US1] Implement Specification section extraction from spec.md (required) in generate-feature-page.sh
- [x] T023 [US1] Implement Implementation Plan section extraction from plan.md (if exists) in generate-feature-page.sh
- [x] T024 [US1] Implement Data Model section extraction from data-model.md (if exists) in generate-feature-page.sh
- [x] T025 [US1] Implement Research section extraction from research.md (if exists) in generate-feature-page.sh
- [x] T026 [US1] Implement Tasks summary extraction from tasks.md (if exists, summarize if >500 lines) in generate-feature-page.sh
- [x] T027 [US1] Add feature page footer with source link, last synced timestamp, edit warning
- [x] T028 [US1] Create main sync-to-wiki.sh script in scripts/wiki/ with orchestration logic
- [x] T029 [US1] Implement Wiki repo cloning logic in sync-to-wiki.sh (clone to /tmp/chocolandia_kube.wiki/)
- [x] T030 [US1] Implement homepage generation call in sync-to-wiki.sh (invoke generate-homepage.sh > /tmp/wiki/Home.md)
- [x] T031 [US1] Implement feature page generation loop in sync-to-wiki.sh (for each feature, invoke generate-feature-page.sh > /tmp/wiki/Feature-XXX.md)
- [x] T032 [US1] Implement Wiki commit and push logic in sync-to-wiki.sh (git add, git commit, git push to Wiki repo)
- [x] T033 [US1] Add cleanup logic in sync-to-wiki.sh (remove /tmp/wiki directory after sync)
- [x] T034 [US1] Test homepage generation with all 9 existing features (verify table format, links, metadata)
- [x] T035 [US1] Test feature page generation for one feature (verify all sections present, formatting correct)
- [x] T036 [US1] Run sync-to-wiki.sh in dry-run mode (--dry-run flag to skip git push, just generate and validate)
- [x] T037 [US1] Perform actual Wiki sync (run sync-to-wiki.sh without dry-run flag)
- [x] T038 [US1] Verify Wiki homepage accessible at https://github.com/cbenitezpy-ueno/chocolandia_kube/wiki
- [x] T039 [US1] Verify all feature pages accessible via links from homepage
- [x] T040 [US1] Click through 3-5 feature pages and verify content sections match source files

**Checkpoint**: At this point, User Story 1 should be fully functional - all documentation accessible via Wiki with central index

---

## Phase 4: User Story 2 - Navigate Between Documentation (Priority: P1)

**Goal**: Users can easily navigate between features and return to index from any page

**Independent Test**: Start at any feature page, click navigation link to return to homepage, verify features organized by number

### Implementation for User Story 2

- [x] T041 [US2] Verify navigation link format in generate-feature-page.sh (ensure "[🏠 Back to Documentation Index](Home)" appears at top)
- [x] T042 [US2] Test navigation from 5 different feature pages back to homepage (click link, verify homepage loads)
- [x] T043 [US2] Verify feature table sorting in generate-homepage.sh (features sorted by number ascending: 001, 002, 003...)
- [x] T044 [US2] Add section separators in feature pages (---  between sections for visual clarity)
- [x] T045 [US2] Verify section headers are clear in generated feature pages (## Quick Start, ## Specification, etc.)
- [x] T046 [US2] Test cross-feature navigation if any inter-feature links exist (verify relative links transformed to Wiki links)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - navigation is seamless and intuitive

---

## Phase 5: User Story 3 - Access Quick Start Guides (Priority: P2)

**Goal**: Users can easily identify and access quickstart guides for features that have them

**Independent Test**: Navigate to Wiki homepage, identify which features have quickstart guides, access a quickstart section

### Implementation for User Story 3

- [ ] T047 [US3] Enhance feature table in generate-homepage.sh to show quickstart availability (check if quickstart.md exists and is non-empty)
- [ ] T048 [US3] Generate Quick Start column in homepage table with section links (e.g., "[Quick Start](Feature-003-Pihole#quick-start)" or "—" if unavailable)
- [ ] T049 [US3] Verify quickstart detection logic works (test with features that have/don't have quickstart.md)
- [ ] T050 [US3] Test Quick Start section links from homepage (click link, verify it jumps to #quick-start anchor on feature page)
- [ ] T051 [US3] Ensure Quick Start section appears first in feature pages (before Specification) for easy access
- [ ] T052 [US3] Verify quickstart content is concise and actionable (manual review of 2-3 quickstart sections)

**Checkpoint**: All quickstart guides are highlighted and easily accessible from homepage

---

## Phase 6: User Story 4 - Search Documentation (Priority: P2)

**Goal**: Users can use GitHub Wiki search to find information across all documentation

**Independent Test**: Use GitHub Wiki search for terms like "Pi-hole", "OpenTofu", "K3s", verify results point to correct pages

### Implementation for User Story 4

- [ ] T053 [US4] Verify Wiki pages contain searchable keywords (check that feature names, technical terms preserved in generated pages)
- [ ] T054 [US4] Test search functionality with 5-10 common terms (Pi-hole, Cloudflare, K3s, OpenTofu, Kubernetes, Traefik, cert-manager, ArgoCD, Grafana)
- [ ] T055 [US4] Verify search results link to correct feature pages (click search result, confirm it goes to right page)
- [ ] T056 [US4] Test search for terms that appear in multiple features (e.g., "OpenTofu", "K3s") and verify all relevant results shown
- [ ] T057 [US4] Document search tips in homepage Contributing section (recommend searching for feature names, technology keywords)

**Checkpoint**: Search functionality validated - users can find documentation efficiently

---

## Phase 7: User Story 5 - View Documentation Updates (Priority: P3)

**Goal**: Users can see when documentation was last updated to know if it's current

**Independent Test**: View Wiki pages and check footer for last synced timestamp, use GitHub history to see update dates

### Implementation for User Story 5

- [ ] T058 [US5] Ensure homepage footer includes "Last updated" timestamp in ISO 8601 format (already implemented in T018, verify format)
- [ ] T059 [US5] Ensure feature page footers include "Last Synced" timestamp (already implemented in T027, verify)
- [ ] T060 [US5] Test timestamp accuracy (sync Wiki, check timestamp matches current time within a few seconds)
- [ ] T061 [US5] Document how to use GitHub Wiki history feature (add note to homepage: "View page history via GitHub Wiki interface")
- [ ] T062 [US5] Verify multiple syncs update timestamps correctly (run sync twice, verify timestamp changes)

**Checkpoint**: All user stories should now be independently functional - documentation portal is complete

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories, validation, documentation

- [ ] T063 [P] Implement link transformation in scripts/wiki/lib/transform.sh (relative links → Wiki links: ./other.md → #section)
- [ ] T064 [P] Implement cross-feature link transformation (../001-k3s/spec.md → [[Feature-001-K3s-Cluster-Setup#specification]])
- [ ] T065 [P] Implement image URL transformation (./images/x.png → https://raw.githubusercontent.com/.../x.png)
- [ ] T066 [P] Apply transformations to all feature pages during generation (call transform.sh functions in generate-feature-page.sh)
- [ ] T067 [P] Test link transformations with features that have internal/cross-feature links
- [ ] T068 [P] Test image transformations if any features have images
- [ ] T069 Implement --dry-run flag support in sync-to-wiki.sh (skip git push, just generate and show what would be committed)
- [ ] T070 Implement change detection in sync-to-wiki.sh (check if Wiki content actually changed before committing, avoid empty commits)
- [ ] T071 Add error handling in sync-to-wiki.sh (check for missing spec.md, handle git failures gracefully)
- [ ] T072 Add progress logging to sync-to-wiki.sh (echo "Generating Feature-001...", "Committing changes...", etc.)
- [ ] T073 [P] Run validation script on all generated pages (invoke validate-markdown.sh on /tmp/wiki/*.md before pushing)
- [ ] T074 [P] Create scripts/wiki/README.md with comprehensive documentation (usage, examples, troubleshooting)
- [ ] T075 [P] Update repository root README.md to reference Wiki sync scripts (add "Documentation" section)
- [ ] T076 Test error handling (remove spec.md from a test feature, verify sync skips it with warning)
- [ ] T077 Test with malformed markdown (introduce syntax error, verify validation catches it)
- [ ] T078 Run full sync validation with all 9 features (verify no errors, all pages generated)
- [ ] T079 Verify Wiki pages render correctly (check formatting, code blocks, tables, lists)
- [ ] T080 Create quickstart validation checklist (follow quickstart.md for this feature, verify all steps work)
- [ ] T081 [P] Add security check to sync script (scan for credentials, API keys, internal IPs before pushing)
- [ ] T082 Document sync workflow in quickstart.md (already exists, verify completeness)
- [ ] T083 Add troubleshooting section to scripts/wiki/README.md (common issues, solutions)

---

## Phase 9: Optional Enhancements (Future - P3)

**Purpose**: Sidebar navigation and GitHub Actions automation (nice-to-have features)

- [ ] T084 [P] Create generate-sidebar.sh script in scripts/wiki/ for optional _Sidebar.md generation
- [ ] T085 [P] Implement sidebar structure (group features by category: Infrastructure, Services, Documentation)
- [ ] T086 [P] Add sidebar generation to sync-to-wiki.sh (optional flag: --with-sidebar)
- [ ] T087 [P] Test sidebar navigation (verify all links work, sidebar appears on all pages)
- [ ] T088 [P] Create GitHub Actions workflow file .github/workflows/wiki-sync.yml
- [ ] T089 [P] Configure workflow to trigger on push to main branch with specs/**/*.md changes
- [ ] T090 [P] Add GitHub token authentication for Wiki push in workflow
- [ ] T091 [P] Test GitHub Actions workflow (push docs change, verify Wiki auto-syncs)
- [ ] T092 [P] Add workflow badge to repository README.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-7)**: All depend on Foundational phase completion
  - User Story 1 (P1): Foundation → Browse Documentation
  - User Story 2 (P1): Foundation → Navigation (can build on US1 or independently)
  - User Story 3 (P2): Foundation → Quickstart Access (enhances US1 homepage)
  - User Story 4 (P2): Foundation → Search (validation only, relies on GitHub's search)
  - User Story 5 (P3): Foundation → Updates Tracking (enhances all pages)
- **Polish (Phase 8)**: Depends on User Stories 1-2 (P1) minimum, ideally all stories
- **Optional (Phase 9)**: Can be done anytime after Polish, completely independent

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories (core MVP)
- **User Story 2 (P1)**: Can start after Foundational - Enhances US1 but can be validated independently
- **User Story 3 (P2)**: Can start after Foundational - Enhances US1 homepage table
- **User Story 4 (P2)**: Can start after Foundational - Validation of GitHub's search feature
- **User Story 5 (P3)**: Can start after Foundational - Adds timestamps to pages (already in US1)

### Within Each User Story

- **US1**: Homepage generation → Feature page generation → Sync orchestration → Testing
- **US2**: Verify navigation structure → Test navigation flow
- **US3**: Quickstart detection → Homepage table enhancement → Testing
- **US4**: Content verification → Search testing
- **US5**: Timestamp implementation (already in US1) → Validation

### Parallel Opportunities

- **Setup (Phase 1)**: T003 and T004 can run in parallel (Wiki check, auth check)
- **Foundational (Phase 2)**: T006 and T007 can run in parallel (transform.sh, validate-markdown.sh)
- **US1**: T010 and T011 can start in parallel (generate-homepage.sh, generate-feature-page.sh script creation)
- **Polish (Phase 8)**: T063, T064, T065, T067, T068, T073, T074, T075, T081 all marked [P] can run in parallel (different files)
- **Optional (Phase 9)**: T084, T085, T088 all marked [P] can run in parallel

---

## Parallel Example: User Story 1 (MVP)

```bash
# Can run in parallel (different files):
Task T010: "Create generate-homepage.sh script"
Task T011: "Create generate-feature-page.sh script"

# Sequential within script development:
Task T012: "Implement homepage header" (after T010)
Task T013: "Implement feature scanning" (after T012)
...

# Can run in parallel during validation:
Task T034: "Test homepage generation"
Task T035: "Test feature page generation"
```

---

## Parallel Example: Polish Phase

```bash
# All these can run in parallel (different concerns):
Task T063: "Implement link transformation"
Task T064: "Implement cross-feature link transformation"
Task T065: "Implement image URL transformation"
Task T073: "Run validation script"
Task T074: "Create scripts/wiki/README.md"
Task T075: "Update repository README.md"
Task T081: "Add security check"
```

---

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only)

1. Complete Phase 1: Setup (4 tasks, ~10 minutes)
2. Complete Phase 2: Foundational (5 tasks, ~30 minutes)
3. Complete Phase 3: User Story 1 (31 tasks, ~180 minutes)
4. Complete Phase 4: User Story 2 (6 tasks, ~30 minutes)
5. **STOP and VALIDATE**: Test Wiki browsing and navigation independently
6. Deploy/demo - **MVP READY** (46 tasks total, ~250 minutes = ~4 hours)

### Incremental Delivery

1. Setup + Foundational → Scripts infrastructure ready (~40 minutes)
2. Add User Story 1 → Test independently → **Deploy/Demo (MVP: browsable Wiki!)** (~4 hours total)
3. Add User Story 2 → Test navigation → **Enhanced navigation** (~4.5 hours total)
4. Add User Story 3 → Test quickstart access → **Quickstart highlighted** (~5 hours total)
5. Add User Story 4 → Test search → **Search validated** (~5.5 hours total)
6. Add User Story 5 → Test timestamps → **Update tracking** (~6 hours total)
7. Add Polish → **Production-ready** (~8 hours total)
8. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (~40 minutes)
2. Once Foundational is done:
   - Developer A: User Story 1 (core sync scripts)
   - Developer B: User Story 3 (quickstart enhancements) - lighter workload
   - Developer C: Polish Phase (transformations, validation) - can start early
3. Reconverge for User Story 2 testing (navigation verification)
4. Stories complete and integrate independently

---

## Task Summary

- **Total Tasks**: 92 tasks
- **Phase 1 (Setup)**: 4 tasks
- **Phase 2 (Foundational)**: 5 tasks
- **Phase 3 (US1 - Browse Documentation - P1 MVP)**: 31 tasks
- **Phase 4 (US2 - Navigation - P1)**: 6 tasks
- **Phase 5 (US3 - Quickstart Access - P2)**: 6 tasks
- **Phase 6 (US4 - Search - P2)**: 5 tasks
- **Phase 7 (US5 - Updates Tracking - P3)**: 5 tasks
- **Phase 8 (Polish & Cross-Cutting)**: 21 tasks
- **Phase 9 (Optional Enhancements - P3)**: 9 tasks

**Parallel Opportunities**: 26 tasks marked [P] for potential parallel execution

**MVP Scope** (US1 + US2): 46 tasks, estimated ~4-5 hours for solo implementation

**Full Feature** (US1-US5 + Polish): 83 tasks, estimated ~8-10 hours for solo implementation

**With Optional Enhancements**: 92 tasks, estimated ~10-12 hours for complete implementation

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label (US1, US2, etc.) maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- Security: Scripts will check for credentials/secrets before pushing to public Wiki
- Testing: Manual verification approach (no automated tests) as per feature spec
