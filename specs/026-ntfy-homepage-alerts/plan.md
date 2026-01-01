# Implementation Plan: Fix Ntfy Notifications and Add Alerts to Homepage

**Branch**: `026-ntfy-homepage-alerts` | **Date**: 2025-12-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/026-ntfy-homepage-alerts/spec.md`

## Summary

Fix ntfy notification delivery by adding authentication to Alertmanager webhooks (root cause: ntfy requires auth but Alertmanager sends unauthenticated requests), and add a Prometheus alerts widget to Homepage for at-a-glance cluster health visibility.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6+), YAML (Kubernetes manifests)
**Primary Dependencies**: kube-prometheus-stack Helm chart, ntfy, Homepage
**Storage**: Kubernetes Secrets (ntfy credentials), ConfigMaps (Homepage config)
**Testing**: Manual curl tests, visual verification on Homepage
**Target Platform**: K3s v1.28+ cluster
**Project Type**: Infrastructure configuration
**Performance Goals**: Notifications delivered within 60 seconds of alert firing
**Constraints**: Internal cluster communication only, no external API calls
**Scale/Scope**: Single homelab cluster, ~10 active alert rules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] No new Terraform modules required (modifying existing)
- [x] No new namespaces required
- [x] No external dependencies added
- [x] Uses existing patterns (Helm values, ConfigMaps, Secrets)
- [x] Single purpose feature with clear boundaries

## Project Structure

### Documentation (this feature)

```text
specs/026-ntfy-homepage-alerts/
├── spec.md              # Feature specification
├── research.md          # Root cause analysis and solution options
├── plan.md              # This file - implementation approach
├── data-model.md        # Entity definitions
├── quickstart.md        # Quick implementation guide
├── contracts/           # API contracts
│   ├── alertmanager-ntfy.md    # Webhook auth contract
│   └── homepage-prometheus.md  # PromQL query contract
└── checklists/
    └── requirements.md  # Specification quality checklist
```

### Source Code (repository root)

```text
terraform/
├── environments/chocolandiadc-mvp/
│   └── monitoring.tf          # Alertmanager config with basic auth
└── modules/
    ├── homepage/
    │   └── configs/
    │       └── services.yaml  # Add alerts widget
    └── ntfy/
        └── main.tf            # Reference (no changes needed)
```

**Structure Decision**: Minimal changes - only modifying existing Terraform files. No new modules or major structural changes.

## Implementation Approach

### Phase 1: Fix ntfy Authentication (P1 - Critical)

**Root Cause**: ntfy configured with `auth-default-access: "read-only"` means:
- Anonymous users can only subscribe (read)
- Publishing requires authentication
- Alertmanager sends webhooks WITHOUT auth → 403 Forbidden

**Solution**: Configure Alertmanager webhook with basic auth credentials.

**Changes Required**:

1. **Create ntfy user for Alertmanager**
   - Command: `ntfy user add alertmanager`
   - Grant write permission: `ntfy access alertmanager homelab-alerts write`

2. **Create Kubernetes Secret**
   - Name: `ntfy-alertmanager-password`
   - Namespace: `monitoring`
   - Contents: Generated password

3. **Update Alertmanager configuration** (`monitoring.tf`)
   ```hcl
   receivers = [
     {
       name = "ntfy-homelab"
       webhook_configs = [
         {
           url = "http://ntfy.ntfy.svc.cluster.local/homelab-alerts?template=alertmanager"
           http_config = {
             basic_auth = {
               username      = "alertmanager"
               password_file = "/etc/alertmanager/secrets/ntfy-alertmanager-password/password"
             }
           }
           send_resolved = true
         }
       ]
     }
   ]
   ```

4. **Mount secret in Alertmanager**
   ```hcl
   alertmanagerSpec = {
     secrets = ["ntfy-alertmanager-password"]
   }
   ```

### Phase 2: Add Homepage Alerts Widget (P2 - Enhancement)

**Approach**: Use `prometheusmetric` widget with PromQL queries for alert counts.

**Changes Required**:

1. **Update services.yaml** (terraform/modules/homepage/configs/)
   - Add new "Cluster Alerts" service card in "Cluster Health" section
   - Widget type: `prometheusmetric`
   - Queries:
     - Critical: `count(ALERTS{alertstate="firing", severity="critical"}) or vector(0)`
     - Warning: `count(ALERTS{alertstate="firing", severity="warning"}) or vector(0)`
   - Link to Grafana alerting page

### Phase 3: Validation (P3 - Verification)

1. **Test notification delivery**
   - Create a test PrometheusRule that fires immediately
   - Verify notification appears on ntfy mobile app
   - Verify resolution notification is sent when alert clears

2. **Test Homepage widget**
   - Verify widget displays correct counts
   - Verify auto-refresh works (30 second interval)
   - Verify graceful handling when no alerts

## Complexity Tracking

> No constitution violations. Implementation uses existing patterns.

| Aspect | Complexity | Justification |
|--------|------------|---------------|
| Files changed | 2 | monitoring.tf, services.yaml |
| New resources | 1 | Kubernetes Secret for password |
| New dependencies | 0 | All services already deployed |
| Risk level | Low | Non-breaking changes to existing config |

## Rollback Plan

If notifications break after changes:

1. Remove `http_config.basic_auth` block from Alertmanager config
2. Re-apply Terraform
3. Grant anonymous write to topic (temporary): `ntfy access '*' homelab-alerts write`

If Homepage widget breaks:

1. Remove the "Cluster Alerts" block from services.yaml
2. Re-apply Terraform

## Dependencies

- [x] ntfy already deployed with authentication enabled
- [x] kube-prometheus-stack already deployed with Alertmanager
- [x] Homepage already deployed with Prometheus widget support
- [x] Grafana already accessible for alert dashboard links
