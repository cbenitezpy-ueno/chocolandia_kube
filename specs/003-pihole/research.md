# Research: Pi-hole DNS Ad Blocker Deployment

**Feature**: 003-pihole
**Date**: 2025-11-09
**Status**: Complete

## Overview

This document consolidates research findings for deploying Pi-hole as a containerized DNS ad blocker on the existing K3s cluster (Feature 002 MVP). Research covers deployment approaches, configuration requirements, networking considerations, and Prometheus integration.

---

## 1. Deployment Approach

### Decision: Kubernetes Raw Manifests (Managed via OpenTofu)

**Rationale:**
- **Learning value**: Writing raw Kubernetes YAML manifests teaches Kubernetes resource structure, labels, selectors, and dependencies
- **OpenTofu integration**: Manifests deployed via OpenTofu Kubernetes provider (`kubernetes_manifest` resource) maintains Infrastructure as Code principle
- **Simplicity**: Single Pi-hole instance with straightforward configuration doesn't require Helm's complexity
- **Transparency**: Every Kubernetes resource is explicitly defined and version-controlled
- **GitOps alignment**: OpenTofu manages Kubernetes resources declaratively with state tracking

### Alternatives Considered:

#### Helm Chart (MoJo2600/pihole-kubernetes)
- **Pros**: Single command deployment, community support, built-in best practices
- **Cons**: Abstracts Kubernetes details (reduces learning), adds Helm as dependency, harder to customize for specific requirements
- **Why rejected**: Learning environment benefits from explicit manifest creation; Helm better suited for complex multi-component applications or prod environments with frequent upgrades

#### Pure OpenTofu Kubernetes Provider (HCL syntax)
- **Pros**: All configuration in HCL, OpenTofu native
- **Cons**: HCL doesn't natively understand Kubernetes YAML structure, requires manual translation, verbose for complex resources
- **Why rejected**: YAML manifests applied via `kubernetes_manifest` resource provides best balance of readability and IaC management

---

## 2. Pi-hole Docker Image Configuration

### Image: `pihole/pihole:latest`

### Required Environment Variables:

| Variable | Purpose | Example Value | Required |
|----------|---------|---------------|----------|
| `TZ` | Timezone for log timestamps | `America/New_York` | Yes |
| `FTLCONF_webserver_api_password` | Admin password (web UI) | `<secure-password>` | Yes |
| `FTLCONF_dns_upstreams` | Upstream DNS servers | `1.1.1.1;8.8.8.8` | Yes |
| `FTLCONF_dns_listeningMode` | DNS listening mode | `all` | Yes (for Kubernetes) |

### Optional Configuration:

| Variable | Purpose | Default | Notes |
|----------|---------|---------|-------|
| `PIHOLE_UID` | Container user ID | 1000 | Match host UID for volume permissions |
| `PIHOLE_GID` | Container group ID | 1000 | Match host GID for volume permissions |
| `TAIL_FTL_LOG` | Enable FTL logging | 1 | Set to 0 to reduce log noise |
| `WEBPASSWORD_FILE` | Path to password file | — | For Kubernetes Secrets |

**Configuration Pattern:**
- Use `FTLCONF_[section_][setting]` syntax for FTL configuration
- Environment variables become **read-only** (cannot change via web UI)
- Prevents configuration drift and ensures single source of truth (IaC principle)

### Required Volumes:

| Path | Purpose | Size | Required |
|------|---------|------|----------|
| `/etc/pihole` | Configuration, databases, blocklists | 2Gi | Yes |
| `/etc/dnsmasq.d` | Custom DNS configurations | 100Mi | No (requires `FTLCONF_misc_etc_dnsmasq_d: 'true'`) |

**Storage Decision**: Use K3s `local-path-provisioner` (already deployed in Feature 002) with `ReadWriteOnce` access mode. Single pod doesn't require shared storage.

### Required Ports:

| Port | Protocol | Purpose | Exposed |
|------|----------|---------|---------|
| 53 | TCP + UDP | DNS service | Yes (via NodePort) |
| 80 | TCP | Web admin interface | Yes (via NodePort) |

**Why port 53 TCP+UDP**: DNS queries use UDP primarily, but TCP fallback required for large responses (DNSSEC, zone transfers)

### Container Capabilities:

```yaml
securityContext:
  capabilities:
    add:
      - NET_BIND_SERVICE  # Required to bind port 53 (privileged port)
```

---

## 3. Kubernetes Service Configuration

### Decision: NodePort Service (Dual Services for DNS)

**Rationale:**
- **Eero network constraint**: No LoadBalancer controller (MetalLB) available in MVP environment
- **Simplicity**: NodePort works without additional infrastructure
- **Accessibility**: Web interface accessible at `http://<node-ip>:<nodeport>` from Eero network (192.168.4.0/24)
- **DNS service**: Port 53 accessible via `<node-ip>:30053` (or custom NodePort)

### Service Architecture:

**Two separate Services required** (Kubernetes limitation: can't mix TCP/UDP protocols on same NodePort):

1. **DNS Service (TCP + UDP)**:
   - Type: ClusterIP (for internal K3s DNS resolution if needed)
   - Ports: 53 TCP + 53 UDP
   - Alternative: LoadBalancer (when MetalLB deployed in future)

2. **Web Admin Service**:
   - Type: NodePort
   - Port: 80 HTTP → NodePort 30001 (custom, within range 30000-32767)
   - Accessibility: `http://192.168.4.101:30001` or `http://192.168.4.102:30001`

### DNS Access Pattern:

**For MVP (Eero network)**:
- Devices configured manually to use K3s node IP as DNS server (192.168.4.101 or 192.168.4.102)
- Pi-hole DNS service exposed via ClusterIP + host networking alternative OR NodePort
- **Limitation**: NodePort for DNS requires non-standard port (e.g., 30053 instead of 53)

**Alternative Approach (More Complex)**:
- Run Pi-hole with `hostNetwork: true` to bind directly to node port 53
- **Conflict risk**: K3s CoreDNS already uses port 53 on cluster nodes
- **Not recommended** for learning environment

**Future Enhancement (Feature 001 with FortiGate)**:
- Deploy MetalLB LoadBalancer controller
- Assign dedicated IP to Pi-hole DNS service (e.g., 192.168.4.10)
- Devices use standard port 53 without node IP dependency

### Service Configuration Best Practices:

```yaml
spec:
  type: NodePort
  externalTrafficPolicy: Local  # Preserves client source IPs in Pi-hole logs
  ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: 30001  # Custom, memorable port
```

---

## 4. Health Checks

### Recommended Probe Configuration:

#### Liveness Probe (HTTP):
```yaml
livenessProbe:
  httpGet:
    path: /admin/api.php?info&login
    port: 80
  initialDelaySeconds: 60  # Pi-hole needs time to initialize
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 10     # Avoid premature restarts
```

#### Readiness Probe (HTTP):
```yaml
readinessProbe:
  httpGet:
    path: /admin/api.php?info&login
    port: 80
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3      # Faster traffic removal on failure
```

**Rationale:**
- **HTTP endpoint check**: More reliable than DNS-based check (avoids recursive DNS issues)
- **60s initial delay**: Pi-hole requires ~30-60 seconds to initialize DNS service and FTL database
- **10 failure threshold for liveness**: Prevents pod restart during temporary network glitches or blocklist updates
- **3 failure threshold for readiness**: Quickly removes unhealthy pod from service endpoints

### Alternative DNS-Based Probe (Not Recommended):
```yaml
livenessProbe:
  exec:
    command:
      - dig
      - +short
      - +norecurse
      - "@127.0.0.1"
      - pi.hole
```

**Why not recommended**: Requires `dig` binary in container, adds complexity, can fail during Pi-hole initialization

---

## 5. Prometheus Metrics Integration (P3 Priority)

### Decision: eko/pihole-exporter Sidecar Container

**Rationale:**
- **No native Prometheus support**: Pi-hole doesn't expose `/metrics` endpoint natively
- **Community standard**: `eko/pihole-exporter` is most popular and actively maintained
- **Sidecar pattern**: Deploy exporter as second container in Pi-hole pod, shares localhost network
- **18+ metrics**: Comprehensive coverage of DNS queries, blocking stats, query types, upstream latency

### Exporter Configuration:

**Image**: `ekofr/pihole-exporter:latest`
**Port**: 9617
**Endpoint**: `/metrics`

**Environment Variables**:
```yaml
- name: PIHOLE_HOSTNAME
  value: "127.0.0.1"  # Sidecar shares pod network
- name: PIHOLE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: pihole-admin-password
      key: password
- name: PORT
  value: "9617"
```

### Available Metrics:

| Metric | Description |
|--------|-------------|
| `pihole_domains_being_blocked` | Total blocked domains count |
| `pihole_dns_queries_today` | Daily DNS query volume |
| `pihole_ads_blocked_today` | Daily blocked advertisements |
| `pihole_ads_percentage_today` | Daily blockage percentage |
| `pihole_queries_forwarded` | Forwarded query count |
| `pihole_queries_cached` | Cached query count |
| `pihole_unique_clients` | Active unique clients |
| `pihole_reply` | DNS response type distribution (NODATA, NXDOMAIN, CNAME, IP) |
| `pihole_querytypes` | Query categorization (A, AAAA, PTR, etc.) |
| `pihole_top_queries` | Most frequent domain queries |
| `pihole_forward_destinations_responsetime` | Upstream DNS latency |

### Prometheus Scrape Configuration:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pihole-exporter
  labels:
    app: pihole
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9617"
    prometheus.io/path: "/metrics"
```

### Grafana Dashboard:

**Dashboard ID**: 10176 - "Pi-hole Exporter"
**URL**: https://grafana.com/grafana/dashboards/10176-pi-hole-exporter/
**Features**: 13 key metric visualizations (DNS queries, ad blocking stats, query types, top queries/ads)

**Installation**:
1. Grafana UI → Dashboards → Import
2. Enter dashboard ID: 10176
3. Select Prometheus data source
4. Import

---

## 6. Known Issues and Best Practices

### Critical Gotchas:

#### 1. Persistent Storage Requirement
- **Issue**: Pi-hole requires explicit persistent volumes; settings won't persist without PV/PVC
- **Solution**: Use PersistentVolumeClaim with K3s local-path-provisioner
- **Validation**: After pod restart, verify admin password and blocklists are retained

#### 2. DNS Configuration Loop
- **Issue**: If Pi-hole pod uses itself as DNS, initialization fails
- **Solution**: Configure pod DNS to use reliable upstream (8.8.8.8, 1.1.1.1)
```yaml
spec:
  dnsConfig:
    nameservers:
      - 8.8.8.8
      - 1.1.1.1
```

#### 3. Port 53 Conflicts
- **Issue**: K3s CoreDNS uses port 53 on cluster nodes
- **Solution**: Use ClusterIP service (not hostNetwork mode) or NodePort with non-standard port
- **Alternative**: Deploy MetalLB and assign dedicated IP to Pi-hole

#### 4. Initial Admin Password Retrieval
- **Issue**: If `FTLCONF_webserver_api_password` not set, Pi-hole generates random password logged to console
- **Solution**: Always set password via Kubernetes Secret or environment variable
- **Retrieval**: `kubectl logs <pihole-pod> | grep "password"`

### Production Best Practices:

1. **Security**:
   - Store admin password in Kubernetes Secret (not plaintext environment variable)
   - Set resource limits (memory: 512Mi, CPU: 500m) to prevent resource exhaustion
   - Use strong admin password (16+ characters, random generated)

2. **Backup Strategy**:
   - Regular backups of `/etc/pihole` PersistentVolume
   - Export blocklists and whitelist configurations via Teleporter feature
   - Document custom DNS records and settings

3. **Monitoring**:
   - Deploy Prometheus exporter (P3 priority) to track DNS performance
   - Monitor pod restarts and health check failures
   - Set up alerts for DNS service downtime

4. **Updates**:
   - Manually update Pi-hole Docker image (test in staging first)
   - Avoid automated unattended updates (per Pi-hole documentation)
   - Keep rollback plan ready (previous image version)

---

## 7. Technology Stack Summary

### Core Technologies:
- **Container Runtime**: Docker (via K3s containerd)
- **Orchestration**: Kubernetes 1.28 (K3s distribution)
- **Infrastructure as Code**: OpenTofu 1.6+ with Kubernetes provider
- **Base Image**: pihole/pihole:latest (multi-arch: amd64 + arm64)
- **Storage**: K3s local-path-provisioner (RWO PersistentVolumes)
- **Testing**: Bash integration tests (DNS query validation, web accessibility)

### Optional Technologies (P3):
- **Metrics Exporter**: eko/pihole-exporter
- **Monitoring**: Prometheus (from Feature 002)
- **Visualization**: Grafana Dashboard 10176 (from Feature 002)

### Network Architecture:
- **Target Network**: Eero mesh (192.168.4.0/24)
- **Cluster Nodes**: master1 (192.168.4.101), nodo1 (192.168.4.102)
- **Service Type**: NodePort (web admin on port 30001)
- **DNS Access**: Manual device configuration to use node IP as DNS server
- **Upstream DNS**: Cloudflare (1.1.1.1) + Google (8.8.8.8)

---

## 8. Implementation Recommendations

### MVP Deployment (P1 User Stories):

1. **Create Kubernetes manifests**:
   - Deployment (Pi-hole container with environment variables, volumes, health checks)
   - PersistentVolumeClaim (2Gi for /etc/pihole configuration)
   - Secret (admin password)
   - Service (NodePort for web admin on port 30001)
   - Service (ClusterIP for DNS on port 53 TCP+UDP)

2. **Deploy via OpenTofu**:
   - Use `kubernetes_manifest` resource to apply YAML manifests
   - Store manifests in `terraform/modules/pihole/manifests/`
   - Invoke module from `terraform/environments/chocolandiadc-mvp/pihole.tf`

3. **Testing**:
   - Verify pod reaches Running state
   - Test web admin access at `http://192.168.4.101:30001`
   - Test DNS resolution from laptop: `nslookup google.com <node-ip>`
   - Test ad blocking: Query known ad domain (doubleclick.net) and verify 0.0.0.0 response

4. **Documentation**:
   - Create `docs/pihole-setup.md` with deployment steps
   - Create `docs/device-dns-config.md` with device configuration instructions (macOS, Windows, iOS, Android)
   - Create `docs/pihole-troubleshooting.md` with common issues

### Future Enhancements (P2/P3):

- **P2: Persistence validation**: Add integration test to verify configuration survives pod restart
- **P2: Device auto-config**: Document Eero router DNS configuration (if supported)
- **P3: Prometheus integration**: Deploy exporter sidecar and import Grafana dashboard
- **P3: High availability**: Deploy second Pi-hole replica with pod anti-affinity (requires MetalLB)

---

**Research Complete**: All technical unknowns resolved. Ready for Phase 1 (Design & Contracts).
