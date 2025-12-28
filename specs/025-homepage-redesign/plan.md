# Implementation Plan: Homepage Dashboard Redesign

**Branch**: `025-homepage-redesign` | **Date**: 2025-12-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/025-homepage-redesign/spec.md`

## Summary

Redesign the Homepage dashboard configuration to provide a visually appealing, organized, and useful interface for homelab operators. The implementation involves updating four YAML configuration files (services.yaml, widgets.yaml, settings.yaml, kubernetes.yaml) and potentially adding new secrets for native widget integrations (Pi-hole, Grafana, ArgoCD, Traefik). No changes to the OpenTofu module structure are required; only configuration content updates.

## Technical Context

**Language/Version**: YAML (Homepage configuration format), HCL (OpenTofu 1.6+)
**Primary Dependencies**: Homepage v1.4.6 (ghcr.io/gethomepage/homepage:v1.4.6), Kubernetes provider ~> 2.23
**Storage**: Kubernetes ConfigMaps for configuration persistence
**Testing**: Visual verification, curl/wget health checks, tofu validate/plan
**Target Platform**: K3s cluster (v1.28+), Homepage accessible via https://homepage.chocolandiadc.com
**Project Type**: Infrastructure configuration (YAML files in OpenTofu module)
**Performance Goals**: Page fully interactive within 5 seconds on desktop
**Constraints**: Must maintain existing Homepage infrastructure; no pod restarts for config changes (ConfigMaps auto-reload)
**Scale/Scope**: Single dashboard serving 1-3 concurrent users (homelab scale)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Infrastructure as Code | PASS | All changes via OpenTofu ConfigMaps, no manual kubectl |
| II. GitOps Workflow | PASS | Branch-based development, PR review before merge |
| III. Container-First | PASS | Existing Homepage container unchanged |
| IV. Observability | PASS | Dashboard enhances observability with native widgets |
| V. Security Hardening | PASS | Credentials stored as Kubernetes Secrets, no hardcoding |
| VI. High Availability | N/A | Dashboard is single replica (acceptable for non-critical service) |
| VII. Test-Driven Learning | PASS | Visual verification tests, tofu validate |
| VIII. Documentation-First | PASS | spec.md, plan.md, quickstart.md artifacts |
| IX. Network-First Security | N/A | No network changes required |

**Gate Result**: PASS - All applicable principles satisfied.

## Project Structure

### Documentation (this feature)

```text
specs/025-homepage-redesign/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (YAML structure)
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (Homepage config contracts)
│   ├── services-schema.yaml
│   ├── widgets-schema.yaml
│   └── settings-schema.yaml
├── tasks.md             # Phase 2 output (via /speckit.tasks)
└── checklists/
    └── requirements.md  # Spec quality checklist (complete)
```

### Source Code (repository root)

```text
terraform/modules/homepage/
├── main.tf              # Kubernetes resources (unchanged)
├── variables.tf         # Module variables (may add new secrets)
├── outputs.tf           # Module outputs (unchanged)
├── rbac.tf              # RBAC configuration (unchanged)
└── configs/
    ├── services.yaml    # Service definitions (UPDATED)
    ├── widgets.yaml     # Header widgets (UPDATED)
    ├── settings.yaml    # Theme and layout (UPDATED)
    └── kubernetes.yaml  # K8s integration (minimal changes)
```

**Structure Decision**: Configuration-only update to existing module. No new files outside configs/ directory. Secret additions (if needed) go in variables.tf and main.tf.

## Complexity Tracking

> No violations - feature uses existing infrastructure patterns.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |

## Phase 0: Research Summary

Key research areas to resolve before implementation:

1. **Homepage Widget Compatibility**: Which native widgets work with our service versions?
2. **Color Scheme Selection**: Sky vs. other palettes for professional dark theme
3. **Native Widget Credentials**: What credentials are needed for Pi-hole, Grafana, Traefik widgets?
4. **Layout Best Practices**: Column counts and section organization patterns
5. **Background Image Strategy**: Self-hosted vs. external, blur/opacity settings

See `research.md` for detailed findings.

## Phase 1: Design Summary

Key design decisions:

1. **Service Categories**: 6 sections organized by operational priority
2. **Header Widgets**: resources, kubernetes, search, datetime
3. **Theme**: Dark theme with `sky` color palette
4. **Layout**: Row-based layout with 3-4 columns per section
5. **Native Widgets**: Pi-hole, ArgoCD, Traefik, Grafana (require credentials)
6. **Quick Reference**: Bookmarks section for commands and IPs

See `data-model.md` and `contracts/` for detailed YAML structures.

## Implementation Phases

### Phase A: Core Layout and Theme (P1 Stories)
- Update settings.yaml with new theme and layout
- Reorganize services.yaml with 6 categories
- Update widgets.yaml with header widgets

### Phase B: Native Widget Integration (P3 Stories)
- Add Pi-hole widget with API key
- Add ArgoCD widget (token already configured)
- Add Traefik widget (internal URL)
- Add Grafana widget (credentials needed)

### Phase C: Quick Reference and Polish (P2 Stories)
- Add Quick Reference bookmarks section
- Finalize visual styling and card appearance
- Test mobile responsiveness

### Validation
- Visual verification on desktop and mobile
- Widget data accuracy verification
- Page load time measurement
- Blog article screenshots capture
