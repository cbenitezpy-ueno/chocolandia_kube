# Research: PostgreSQL Cluster Database Service

**Branch**: `011-postgresql-cluster` | **Date**: 2025-11-14
**Purpose**: Resolve technical unknowns from Technical Context and establish implementation approach

## Overview

This research document resolves the NEEDS CLARIFICATION items identified in the Technical Context:
1. PostgreSQL deployment method (Helm chart vs Kubernetes operator)
2. Internal network access method (NodePort vs LoadBalancer)

Additionally, it documents best practices for PostgreSQL high availability in Kubernetes homelab environments.

---

## Research Topic 1: PostgreSQL Deployment Method

### Question
Should we deploy PostgreSQL using a Helm chart or a Kubernetes operator?

### Options Evaluated

#### Option A: Bitnami PostgreSQL Helm Chart
**Pros**:
- Mature, well-maintained chart with 1M+ downloads
- Built-in HA support via PostgreSQL replication
- Simple configuration via Helm values
- OpenTofu has native Helm provider support
- Includes PostgreSQL Exporter for Prometheus metrics
- Well-documented and widely used in production
- Stateful deployment via StatefulSet
- Automatic PersistentVolumeClaim management
- ArgoCD has native Helm chart support

**Cons**:
- Less sophisticated automated failover (manual promotion may be required)
- Requires external orchestration for complex HA scenarios
- Limited operator-level automation (no auto-healing beyond pod restart)

**Configuration Complexity**: LOW
**Operational Maturity**: HIGH
**Homelab Suitability**: HIGH (simpler for learning, less moving parts)

#### Option B: CloudNativePG Operator
**Pros**:
- Cloud-native PostgreSQL operator built for Kubernetes
- Advanced automated failover and self-healing
- Declarative cluster management via CRDs
- Continuous backup support (Barman)
- Automatic replica promotion on primary failure
- Connection pooling (PgBouncer) built-in
- Advanced monitoring and observability
- Designed for production HA scenarios

**Cons**:
- Additional operational complexity (operator deployment, CRD management)
- Less mature than Bitnami chart (newer project)
- Requires learning operator-specific concepts
- More components to monitor and troubleshoot
- ArgoCD requires CRD installation before cluster deployment

**Configuration Complexity**: MEDIUM-HIGH
**Operational Maturity**: MEDIUM
**Homelab Suitability**: MEDIUM (excellent learning opportunity for operators, but higher complexity)

#### Option C: Zalando Postgres Operator
**Pros**:
- Production-tested at scale (Zalando)
- Advanced automated failover via Patroni
- Connection pooling via PgBouncer
- Continuous backup support
- Team/user management automation
- Well-documented and battle-tested

**Cons**:
- Higher operational complexity
- Larger attack surface (more components)
- May be over-engineered for homelab
- Requires Patroni knowledge
- Complex troubleshooting when issues arise

**Configuration Complexity**: HIGH
**Operational Maturity**: HIGH
**Homelab Suitability**: LOW (production-focused, too complex for homelab learning)

### Decision: Bitnami PostgreSQL Helm Chart

**Rationale**:
1. **Learning value**: Helm charts are fundamental to Kubernetes operations; mastering chart configuration and customization is a valuable skill
2. **Simplicity**: Lower operational overhead means more focus on PostgreSQL internals (replication, backups, queries) rather than operator mechanics
3. **Mature tooling**: Bitnami chart is production-ready, well-documented, and widely used (reduces risk of edge cases)
4. **OpenTofu integration**: Native Helm provider support in OpenTofu simplifies infrastructure as code
5. **ArgoCD compatibility**: ArgoCD has first-class Helm chart support with values override
6. **Monitoring ready**: Built-in PostgreSQL Exporter for Prometheus metrics
7. **Constitution alignment**: Simpler solution for homelab without compromising HA requirements (primary-replica via streaming replication)
8. **Future upgrade path**: If operator features become necessary, migration to CloudNativePG is possible

**Alternatives Considered**:
- CloudNativePG: Excellent for learning operators but adds complexity that doesn't directly serve core learning goals (PostgreSQL HA, replication, backup/restore). Could be future enhancement.
- Zalando Operator: Over-engineered for homelab scale; Patroni adds unnecessary complexity when Kubernetes already provides pod restart/rescheduling.

**Implementation Notes**:
- Use Bitnami PostgreSQL HA chart (not standalone chart)
- Enable streaming replication (primary-replica topology)
- Configure synchronous commit for data consistency
- Use StatefulSet with PersistentVolumeClaims for data persistence
- Deploy PostgreSQL Exporter sidecar for Prometheus scraping
- Configure readiness/liveness probes for automatic pod recovery

---

## Research Topic 2: Internal Network Access Method

### Question
How should internal network clients access the PostgreSQL cluster? NodePort or LoadBalancer service?

### Options Evaluated

#### Option A: NodePort Service
**Description**: Kubernetes allocates a static port (30000-32767) on all cluster nodes. External clients connect to `<node-ip>:<nodeport>`.

**Pros**:
- No additional infrastructure required (works out-of-box in K3s)
- Simple to configure (single Service resource)
- Deterministic port mapping (can document for clients)
- Works with existing FortiGate firewall rules (allow port on cluster VLAN)
- Low resource usage (no extra pods)

**Cons**:
- Clients must know node IPs (manual IP management)
- If node fails, clients must retry with different node IP (unless using all node IPs)
- Non-standard PostgreSQL port (e.g., 31432 instead of 5432)
- Exposes service on all nodes (broader attack surface)
- Not ideal for many clients (each must track node IPs)

**Complexity**: LOW
**HA Suitability**: MEDIUM (requires clients to handle node failures)
**Homelab Suitability**: MEDIUM (works but not elegant)

#### Option B: LoadBalancer Service (MetalLB)
**Description**: MetalLB provides LoadBalancer services in bare-metal/homelab environments. It allocates a virtual IP from a pool and announces it via ARP (Layer 2) or BGP (Layer 3).

**Pros**:
- Single stable IP address for clients (e.g., 192.168.10.100)
- Standard PostgreSQL port (5432)
- Automatic failover if announcing node fails (MetalLB handles IP migration)
- Clean client configuration (no node IP tracking)
- Production-like experience (same as cloud LoadBalancers)
- Aligns with homelab learning goals (MetalLB is industry-standard for bare-metal)

**Cons**:
- Requires MetalLB installation and configuration (additional component)
- Requires IP pool configuration (must coordinate with FortiGate DHCP)
- Layer 2 mode has single-node announcement (potential bottleneck, though not issue for PostgreSQL)
- More moving parts to troubleshoot

**Complexity**: MEDIUM (MetalLB setup required)
**HA Suitability**: HIGH (single stable IP)
**Homelab Suitability**: HIGH (excellent learning opportunity, production-like)

#### Option C: Ingress with TCP Passthrough
**Description**: Use Traefik Ingress with TCP passthrough to route PostgreSQL connections.

**Pros**:
- Reuses existing Traefik infrastructure (already deployed in feature 005)
- Hostname-based routing (e.g., postgres.homelab.local)
- TLS termination possible

**Cons**:
- Ingress is designed for HTTP/HTTPS, not raw TCP (awkward configuration)
- Requires Traefik TCP router (non-standard for Ingress)
- Clients must use hostname (DNS dependency)
- Over-engineered for database access pattern
- Non-standard port handling (Traefik entrypoint configuration required)

**Complexity**: HIGH
**HA Suitability**: MEDIUM
**Homelab Suitability**: LOW (wrong tool for the job)

### Decision: LoadBalancer Service via MetalLB

**Rationale**:
1. **Production-like experience**: LoadBalancer is the standard for exposing TCP services in Kubernetes; learning MetalLB teaches bare-metal best practices
2. **Single stable IP**: Clients configure one IP address, simplifying administration and documentation
3. **Standard port**: Use PostgreSQL default port 5432 (no client confusion)
4. **High availability**: MetalLB handles IP announcement failover automatically if node fails
5. **Constitution alignment (Principle VII: Test-Driven Learning)**: MetalLB setup provides learning opportunity for bare-metal load balancing, ARP/BGP, and IP management
6. **Future-proof**: MetalLB can be reused for other services requiring external access (e.g., future web services, monitoring endpoints)
7. **Separation of concerns**: Network access layer (MetalLB) is separate from application layer (PostgreSQL), following architectural best practices

**Alternatives Considered**:
- NodePort: Simpler but requires clients to track node IPs and handle node failures manually. Not production-like, misses learning opportunity.
- Ingress: Wrong abstraction for database access; HTTP-centric, unnecessary complexity for raw TCP connections.

**Implementation Notes**:
- Deploy MetalLB in Layer 2 mode (simpler for homelab, no BGP required)
- Allocate IP pool from cluster VLAN subnet (e.g., 192.168.10.100-192.168.10.110)
- Coordinate with FortiGate DHCP to avoid IP conflicts (exclude MetalLB range from DHCP pool)
- Configure FortiGate firewall rules to allow port 5432 from management VLAN to MetalLB IP
- Document MetalLB IP in quickstart.md for administrators

---

## Research Topic 3: PostgreSQL High Availability Best Practices

### Question
What are the best practices for configuring PostgreSQL replication in Kubernetes homelab?

### Findings

#### Replication Mode: Synchronous vs Asynchronous
**Recommendation**: **Asynchronous replication** for homelab

**Rationale**:
- Synchronous replication requires primary to wait for replica acknowledgment (increased latency)
- Homelab network latency is low enough that async replication lag is negligible (<1 second)
- Async allows primary to continue operating if replica is temporarily unavailable
- Reduces complexity in troubleshooting (no "waiting for replica" issues)
- For learning environment, async is sufficient (not financial transactions requiring strict ACID)

**Trade-off Acknowledged**: Potential data loss of most recent transactions if primary fails before replication. Acceptable for homelab learning.

#### Backup Strategy
**Recommendation**: **Scheduled pg_dump backups** to persistent volume

**Rationale**:
- pg_dump provides logical backups (SQL dump files)
- Easy to restore and portable across PostgreSQL versions
- Can be scheduled via Kubernetes CronJob
- Store backups on persistent volume or export to Raspberry Pi NFS
- Point-in-time recovery (PITR) via WAL archiving is overkill for homelab

**Implementation**:
- Daily pg_dump CronJob
- Retain last 7 days of backups
- Document restore procedure in runbook

#### Connection Pooling
**Recommendation**: **Defer to application-level pooling** initially, add PgBouncer if needed

**Rationale**:
- Most PostgreSQL client libraries (psycopg2, JDBC) include connection pooling
- Adding PgBouncer prematurely increases complexity
- For homelab scale (100 connections target), native PostgreSQL handles it well
- If connection exhaustion occurs, PgBouncer can be added as enhancement

**Future Enhancement**: If connection pooling becomes necessary, deploy PgBouncer as sidecar container in PostgreSQL pods.

#### Resource Allocation
**Recommendation**:
- Primary pod: 2 CPU cores, 4GB RAM
- Replica pod: 2 CPU cores, 4GB RAM
- Persistent volume: 50GB per instance (100GB total)

**Rationale**:
- Conservative allocation for homelab (can adjust based on workload)
- Ensures enough resources for concurrent connections (100+ target)
- Storage sized for moderate application data growth
- Leaves resources for other cluster workloads

#### Health Checks
**Recommendation**:
- **Liveness probe**: `pg_isready` command (checks if PostgreSQL is accepting connections)
- **Readiness probe**: Query to check replication lag (ensures replica is caught up before serving reads)

**Rationale**:
- pg_isready is lightweight and standard for PostgreSQL health
- Replication lag check prevents stale reads from replica
- Kubernetes automatically restarts unhealthy pods (self-healing)

---

## Research Topic 4: ArgoCD Integration Pattern

### Question
How should PostgreSQL cluster integrate with existing ArgoCD workflow?

### Findings

**Recommendation**: **ArgoCD Application with Helm chart source**

**Pattern**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: postgresql-cluster
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: postgresql-ha
    targetRevision: 12.x.x
    helm:
      valuesObject:
        # Custom values from Git
  destination:
    server: https://kubernetes.default.svc
    namespace: postgresql
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Rationale**:
- ArgoCD natively supports Helm charts from remote repositories
- Values customization via Git (stored in `kubernetes/applications/postgresql/values/`)
- Automated sync ensures cluster matches desired state
- Prune and selfHeal enable GitOps reconciliation
- Follows existing pattern from features 006, 007, 008

**Alternative Considered**: OpenTofu generates Kubernetes manifests, ArgoCD deploys manifests. **Rejected** because Helm chart approach is simpler and more maintainable (chart updates via targetRevision bump, no OpenTofu apply required for chart upgrades).

---

## Technology Stack Summary

| Component | Technology | Version | Rationale |
|-----------|-----------|---------|-----------|
| PostgreSQL | Official PostgreSQL image | 16.x | Latest stable major version, long-term support |
| Deployment Method | Bitnami PostgreSQL HA Helm Chart | 12.x | Mature, HA-ready, well-documented |
| HA Topology | Primary-Replica Streaming Replication | - | Industry-standard HA for PostgreSQL |
| Replication Mode | Asynchronous | - | Lower latency, acceptable for homelab |
| Internal Network Access | LoadBalancer (MetalLB) | 0.14.x | Production-like, stable IP, standard port |
| Cluster Access | ClusterIP Service | - | Standard Kubernetes service discovery |
| Monitoring | PostgreSQL Exporter | latest | Prometheus metrics integration |
| Backup | pg_dump via CronJob | - | Simple, portable, sufficient for homelab |
| GitOps | ArgoCD Application | - | Existing pattern, automated sync |
| IaC | OpenTofu | 1.6+ | Constitution principle I |

---

## Risks and Mitigations

### Risk 1: MetalLB IP Conflicts with DHCP
**Impact**: HIGH - Service unavailable if IP conflict occurs
**Likelihood**: MEDIUM - Manual DHCP configuration required
**Mitigation**:
- Reserve MetalLB IP range in FortiGate DHCP exclusion list
- Document MetalLB IP pool in network diagram
- Test IP assignment before PostgreSQL deployment

### Risk 2: Replication Lag Causing Stale Reads
**Impact**: MEDIUM - Applications read outdated data from replica
**Likelihood**: LOW - Network latency minimal in homelab
**Mitigation**:
- Monitor replication lag via Prometheus metrics
- Configure readiness probe to check lag threshold
- Document expected lag behavior in troubleshooting guide

### Risk 3: Storage Exhaustion
**Impact**: HIGH - PostgreSQL cannot write data
**Likelihood**: MEDIUM - Depends on application data growth
**Mitigation**:
- Monitor storage usage via Prometheus alerts
- Configure storage size conservatively (50GB per instance)
- Document expansion procedure in runbook
- Backup retention policy (7 days) prevents unbounded growth

### Risk 4: Brain-Split Scenario (Both Instances Think They're Primary)
**Impact**: HIGH - Data corruption possible
**Likelihood**: LOW - Kubernetes ensures single primary via StatefulSet
**Mitigation**:
- StatefulSet guarantees single pod-0 (primary)
- Bitnami chart handles replica promotion logic
- Test failover procedure to verify safe promotion
- Document recovery procedure for split-brain scenario

---

## Open Questions for Implementation Phase

1. **MetalLB IP Pool Range**: Confirm available IP range in cluster VLAN (coordinate with network admin)
2. **Backup Storage Location**: Use local PV or export to Raspberry Pi NFS? (Decision: local PV initially, NFS as enhancement)
3. **PostgreSQL Version**: Use 16.x (latest) or 15.x (more mature)? (Decision: 16.x for learning latest features)
4. **Initial Database Schema**: Should bootstrap include test database, or leave empty for applications? (Decision: empty cluster, applications create databases)

---

## References

- Bitnami PostgreSQL HA Chart: https://github.com/bitnami/charts/tree/main/bitnami/postgresql-ha
- CloudNativePG Documentation: https://cloudnative-pg.io/documentation/current/
- MetalLB Documentation: https://metallb.universe.tf/
- PostgreSQL Streaming Replication: https://www.postgresql.org/docs/current/warm-standby.html
- PostgreSQL Exporter: https://github.com/prometheus-community/postgres_exporter

---

**Research Complete**: 2025-11-14
**Next Phase**: Phase 1 - Design (data-model.md, contracts/, quickstart.md)
