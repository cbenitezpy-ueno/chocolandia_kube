# Research: Homepage Dashboard Redesign

**Feature**: 025-homepage-redesign
**Date**: 2025-12-28
**Status**: Complete

## Research Questions

### 1. Homepage Widget Compatibility

**Question**: Which native widgets work with our deployed service versions?

**Findings**:

| Service | Widget Type | Compatibility | Configuration Required |
|---------|-------------|---------------|------------------------|
| Pi-hole | `pihole` | Full | API key via `key` parameter |
| ArgoCD | `argocd` | Full | Username/password or token |
| Traefik | `traefik` | Full | Internal URL (http://192.168.4.202:9100) |
| Grafana | `grafana` | Full | Username/password for dashboard count |
| Prometheus | `prometheus` | Limited | Shows targets only, not custom metrics |
| Longhorn | `customapi` | Via Prometheus | Use custom API with Prometheus query |

**Decision**: Use native widgets for Pi-hole, ArgoCD, Traefik. Use `customapi` widget with Prometheus queries for additional metrics.

**Rationale**: Native widgets provide the best user experience with minimal configuration. Prometheus widget is limited but sufficient for basic status.

---

### 2. Color Scheme Selection

**Question**: Which color palette provides the best professional dark theme appearance?

**Findings**:

| Palette | Characteristics | Pros | Cons |
|---------|-----------------|------|------|
| Sky | Blue tones (navy bg, cyan accents) | Professional, excellent contrast, calming | Common choice |
| Slate | Gray tones | Ultra-minimal, neutral | Low visual interest |
| Emerald | Green tones | Unique, calming, nature feel | May clash with status colors |
| Violet | Purple tones | Sophisticated, unique | Harder to read for some |
| Zinc | Pure grayscale | Maximum minimalism | No color personality |

**Decision**: Use `sky` color palette with dark theme.

**Rationale**: Sky provides excellent contrast for status indicators (green/yellow/red), professional appearance suitable for technical dashboards, and good readability. Aligns with Grafana dashboard aesthetic the user referenced.

**Alternatives Considered**:
- Slate was considered but lacks visual interest
- Emerald could conflict with "healthy" status green indicators

---

### 3. Native Widget Credentials

**Question**: What credentials are needed for native widget integrations?

**Findings**:

| Widget | Credential Type | Current Status | Action Required |
|--------|-----------------|----------------|-----------------|
| ArgoCD | API Token | Already configured (`HOMEPAGE_VAR_ARGOCD_TOKEN`) | None |
| Pi-hole | API Key | Not configured | Add variable and secret |
| Grafana | Username/Password | Not configured | Add variables and secret |
| Traefik | None (unauthenticated API) | N/A | None |

**Decision**: Add new secrets for Pi-hole and Grafana widgets.

**Implementation**:
```hcl
# In variables.tf
variable "pihole_api_key" {
  description = "Pi-hole API key for Homepage widget"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_username" {
  description = "Grafana username for Homepage widget"
  type        = string
  default     = "admin"
}

variable "grafana_password" {
  description = "Grafana password for Homepage widget"
  type        = string
  sensitive   = true
  default     = ""
}
```

**How to obtain credentials**:
- **Pi-hole API Key**: Settings → API → Show API Token
- **Grafana Credentials**: Already known (admin/password from monitoring.tf)

---

### 4. Layout Best Practices

**Question**: What column counts and section organization patterns work best?

**Findings**:

Based on UI Engineer agent recommendations and Homepage documentation:

| Section | Recommended Columns | Rationale |
|---------|---------------------|-----------|
| Cluster Health | 4 | Key metrics side-by-side |
| Critical Infrastructure | 4 | Core services need visibility |
| Applications | 3 | Fewer items, larger cards |
| Platform Services | 4 | Multiple tools |
| Storage & Data | 3 | Important but secondary |
| Quick Reference | 2 (column style) | Text-heavy content |

**Decision**: Use row-based layout with 3-4 columns per section, column-style for Quick Reference.

**Rationale**: Row layout with multiple columns maximizes information density while maintaining readability. Quick Reference uses column layout for better text display.

---

### 5. Background Image Strategy

**Question**: Should we use a background image, and if so, how?

**Findings**:

| Option | Pros | Cons |
|--------|------|------|
| No background | Clean, fast loading, no distraction | Plain appearance |
| External URL | Easy to implement, high quality | Depends on external service, CORS issues |
| Self-hosted | Full control, no external dependency | Storage requirement, manual updates |
| Subtle pattern | Professional, minimal distraction | Less visual impact |

**Decision**: No background image for initial release. Add subtle background as optional enhancement.

**Rationale**: Clean design without background is professional and fast. Background can be added later if desired. Frosted glass card effects (`cardBlur: sm`) provide visual interest without background complexity.

---

### 6. Service Organization Strategy

**Question**: How should services be categorized for optimal homelab operations?

**Findings** (from Homelab DevOps Expert agent):

**Recommended Categories**:

1. **Critical Infrastructure** (P1 - most important)
   - Services whose failure breaks other services
   - Traefik, Pi-hole, PostgreSQL, Redis

2. **Platform Services** (P2)
   - Operational/observability tools
   - ArgoCD, Grafana, Headlamp, Longhorn

3. **Applications** (P3)
   - Business/user-facing workloads
   - Beersystem, MinIO

4. **Network & DNS** (informational)
   - Network-related services
   - Pi-hole (duplicate), MetalLB info, Cloudflare

5. **Storage & Data** (informational)
   - Persistence layer
   - Longhorn (duplicate), MinIO (duplicate), PostgreSQL (duplicate), Redis (duplicate)

6. **Cluster Info** (informational)
   - Status and metadata
   - Node status, Certificates, K3s version

**Decision**: Use 6 categories as outlined, with some services appearing in multiple relevant sections.

**Rationale**: Grouping by failure domain helps during incidents ("Is it infrastructure, platform, or app?"). Duplication in informational sections is acceptable for quick reference.

---

### 7. Quick Reference Content

**Question**: What commands and information should be in the Quick Reference section?

**Findings**:

**Essential Commands**:
```bash
# SSH Access
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101

# Port Forwards
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Common Operations
kubectl get pods -A | grep -v Running
kubectl top nodes
kubectl top pods -A
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

**IP Assignments**:
```
192.168.4.200 → Pi-hole DNS
192.168.4.202 → Traefik Ingress
192.168.4.203 → Redis
192.168.4.204 → PostgreSQL
```

**Certificate Info**:
```
Public TLS: Let's Encrypt (*.chocolandiadc.com)
Private TLS: local-ca (*.chocolandiadc.local)
```

**Decision**: Include all above in Quick Reference as bookmarks section.

---

## Summary of Decisions

| Area | Decision | Confidence |
|------|----------|------------|
| Color Scheme | Sky palette, dark theme | High |
| Layout | 6 sections, row-based, 3-4 columns | High |
| Background | No background initially | Medium |
| Native Widgets | Pi-hole, ArgoCD, Traefik, Grafana | High |
| Credentials | Add Pi-hole key, Grafana user/pass | High |
| Service Categories | 6 categories by operational priority | High |
| Quick Reference | Commands, IPs, Certs as bookmarks | High |

## Open Questions

None - all research questions resolved.

## References

- [Homepage Widget Documentation](https://gethomepage.dev/widgets/)
- [Homepage Settings Documentation](https://gethomepage.dev/configs/settings/)
- UI Engineer Agent Recommendations (2025-12-28)
- Homelab DevOps Expert Agent Recommendations (2025-12-28)
