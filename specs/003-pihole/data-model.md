# Data Model: Pi-hole DNS Ad Blocker

**Feature**: 003-pihole
**Date**: 2025-11-09
**Status**: Phase 1 - Design

## Overview

This document defines the key entities, their attributes, relationships, validation rules, and state transitions for the Pi-hole DNS ad blocker deployment on K3s.

---

## 1. Core Entities

### 1.1 Pi-hole Instance

**Description**: The containerized Pi-hole application running as a Kubernetes Deployment.

**Attributes**:

| Attribute | Type | Description | Constraints | Source |
|-----------|------|-------------|-------------|--------|
| `name` | String | Deployment name | `pihole` | Kubernetes metadata |
| `namespace` | String | Kubernetes namespace | `default` or `pihole` | Kubernetes metadata |
| `image` | String | Container image reference | `pihole/pihole:2024.07.0` | Deployment spec |
| `admin_password` | Secret | Web UI admin password | Min 8 chars, stored in K8s Secret | Environment variable |
| `timezone` | String | Timezone for logs | IANA format (e.g., `America/New_York`) | Environment variable |
| `upstream_dns` | List[String] | Upstream DNS servers | Valid IP addresses, semicolon-separated | Environment variable |
| `replicas` | Integer | Number of pod replicas | 1 (MVP), 2+ (HA future) | Deployment spec |
| `cpu_request` | String | CPU resource request | `100m` to `500m` | Resource limits |
| `memory_request` | String | Memory resource request | `256Mi` to `512Mi` | Resource limits |
| `state` | Enum | Current operational state | `Pending`, `Running`, `Failed`, `Unknown` | Pod phase |

**Validation Rules**:
- `admin_password` MUST be at least 8 characters
- `upstream_dns` MUST contain at least one valid IP address
- `cpu_request` MUST be ≤ `cpu_limit`
- `memory_request` MUST be ≤ `memory_limit`
- `timezone` MUST be valid IANA timezone string

**State Transitions**:
```
[Initial] → Pending → Running → [Terminal: Failed/Succeeded]
                ↓         ↓
              Failed ←  Running (restart on failure)
```

---

### 1.2 DNS Service

**Description**: Kubernetes Service exposing Pi-hole DNS resolver on port 53 TCP+UDP (NodePort) + MetalLB LoadBalancer for external DNS access.

**Attributes**:

| Attribute | Type | Description | Constraints | Source |
|-----------|------|-------------|-------------|--------|
| `name` | String | Service name | `pihole-dns` | Service metadata |
| `type` | Enum | Service type | `NodePort` | Service spec |
| `cluster_ip` | String | Internal cluster IP | Auto-assigned by K8s | Service status |
| `dns_tcp_port` | Integer | DNS TCP port | 53 | Service port |
| `dns_udp_port` | Integer | DNS UDP port | 53 | Service port |
| `node_port` | Integer | NodePort (exposed) | 30053 | Service spec |
| `selector` | Map[String, String] | Pod selector labels | `app: pihole` | Service spec |

**Validation Rules**:
- `type` MUST be `NodePort`
- `dns_tcp_port` and `dns_udp_port` MUST be 53
- `node_port` MUST be 30053 (custom NodePort for DNS)
- `selector` MUST match Pi-hole Deployment labels

**Relationships**:
- **Targets**: Pi-hole Instance pods (1:N relationship via label selector)
- **Consumed By**: CoreDNS (forwards external queries to Pi-hole ClusterIP)
- **Alternative Access**: Direct access via NodePort 30053 (fallback)

---

### 1.3 Web Admin Service

**Description**: Kubernetes Service exposing Pi-hole web admin interface on port 80 HTTP.

**Attributes**:

| Attribute | Type | Description | Constraints | Source |
|-----------|------|-------------|-------------|--------|
| `name` | String | Service name | `pihole-web` | Service metadata |
| `type` | Enum | Service type | `NodePort` | Service spec |
| `http_port` | Integer | HTTP port (target) | 80 | Service port |
| `node_port` | Integer | NodePort (exposed) | 30001 (custom) | Service spec |
| `external_traffic_policy` | Enum | Traffic policy | `Local`, `Cluster` | Service spec |

**Validation Rules**:
- `type` MUST be `NodePort` for MVP
- `node_port` MUST be in range 30000-32767 (K8s NodePort range)
- `node_port` SHOULD be 30001 (memorable, low port in range)
- `external_traffic_policy` SHOULD be `Local` (preserves client source IPs)

**Relationships**:
- **Targets**: Pi-hole Instance pods (1:N relationship via label selector)
- **Accessed By**: User's notebook on Eero network

**Access Pattern**:
```
User Notebook (192.168.4.x) → http://192.168.4.101:30001/admin → NodePort Service → Pi-hole Pod
                                 or http://192.168.4.102:30001/admin
```

---

### 1.3.1 CoreDNS LoadBalancer Service

**Description**: MetalLB LoadBalancer service exposing CoreDNS externally on standard DNS port 53 for network devices.

**Attributes**:

| Attribute | Type | Description | Constraints | Source |
|-----------|------|-------------|-------------|--------|
| `name` | String | Service name | `coredns-lb` | Service metadata |
| `namespace` | String | Kubernetes namespace | `kube-system` | Service metadata |
| `type` | Enum | Service type | `LoadBalancer` | Service spec |
| `loadbalancer_ip` | String | External IP (MetalLB) | `192.168.4.200` | Service annotation + MetalLB IP pool |
| `dns_tcp_port` | Integer | DNS TCP port | 53 | Service port |
| `dns_udp_port` | Integer | DNS UDP port | 53 | Service port |
| `selector` | Map[String, String] | Pod selector labels | `k8s-app: kube-dns` | Service spec |

**Validation Rules**:
- `type` MUST be `LoadBalancer`
- `loadbalancer_ip` MUST be within MetalLB IP pool range (192.168.4.200-192.168.4.210)
- `dns_tcp_port` and `dns_udp_port` MUST be 53
- `selector` MUST match CoreDNS pods

**Relationships**:
- **Targets**: CoreDNS pods in kube-system namespace
- **Consumed By**: Network devices (192.168.4.0/24) - Eero router, notebooks, phones
- **Forwards To**: Pi-hole ClusterIP (10.43.232.162) for external queries

**Access Pattern**:
```
Device DNS Query (192.168.4.x) → 192.168.4.200:53 (MetalLB LoadBalancer)
                                       ↓
                                  CoreDNS Service
                                       ↓
                            ┌──────────┴───────────┐
                            ↓                      ↓
                   Internal queries         External queries
                   (*.cluster.local)        (google.com, etc.)
                            ↓                      ↓
                    CoreDNS resolves        Forward to Pi-hole
                                            (10.43.232.162:53)
```

---

### 1.4 PersistentVolume & PersistentVolumeClaim

**Description**: Storage for Pi-hole configuration, blocklists, and query database.

**Attributes**:

| Attribute | Type | Description | Constraints | Source |
|-----------|------|-------------|-------------|--------|
| `pvc_name` | String | PVC name | `pihole-config` | PVC metadata |
| `storage_class` | String | Storage provisioner | `local-path` (K3s default) | PVC spec |
| `size` | String | Storage size | `2Gi` | PVC spec |
| `access_mode` | Enum | Access mode | `ReadWriteOnce` | PVC spec |
| `mount_path` | String | Container mount path | `/etc/pihole` | Deployment volume mount |
| `state` | Enum | Binding state | `Pending`, `Bound`, `Lost` | PVC status |

**Validation Rules**:
- `size` MUST be at least 1Gi (blocklists + database + logs)
- `access_mode` MUST be `ReadWriteOnce` (single pod deployment)
- `storage_class` MUST be `local-path` (K3s built-in provisioner)
- `mount_path` MUST be `/etc/pihole` (Pi-hole Docker image requirement)

**State Transitions**:
```
[Initial] → Pending → Bound → [Terminal: Lost (if node fails)]
```

**Relationships**:
- **Provisioned By**: K3s local-path-provisioner
- **Consumed By**: Pi-hole Instance (1:1 relationship)

**Data Stored**:
- `/etc/pihole/gravity.db` - Blocklist database (SQLite)
- `/etc/pihole/pihole-FTL.db` - Query history and statistics (SQLite)
- `/etc/pihole/setupVars.conf` - Configuration settings
- `/etc/pihole/custom.list` - Custom DNS records
- `/etc/pihole/adlists.list` - Blocklist URLs

---

### 1.5 Kubernetes Secret

**Description**: Stores Pi-hole admin password securely.

**Attributes**:

| Attribute | Type | Description | Constraints | Source |
|-----------|------|-------------|-------------|--------|
| `name` | String | Secret name | `pihole-admin-password` | Secret metadata |
| `type` | Enum | Secret type | `Opaque` | Secret spec |
| `password_key` | String | Data key for password | `password` | Secret data |
| `password_value` | String (base64) | Encoded admin password | Base64-encoded | Secret data |

**Validation Rules**:
- `password_value` MUST be base64-encoded
- Decoded password MUST be at least 8 characters
- Secret MUST be created before Deployment (dependency)

**Relationships**:
- **Consumed By**: Pi-hole Instance (via environment variable `valueFrom.secretKeyRef`)

**Access Pattern**:
```
OpenTofu → Create Secret (base64 encoded password)
            ↓
          Deployment references Secret via env var
            ↓
          Container receives decoded password at runtime
```

---

### 1.6 Blocklist

**Description**: List of domains to block (ads, trackers, malware).

**Attributes**:

| Attribute | Type | Description | Constraints | Source |
|-----------|------|-------------|-------------|--------|
| `name` | String | Blocklist name | User-defined or default | Pi-hole adlists.list |
| `url` | String | Blocklist URL | Valid HTTP(S) URL | Pi-hole adlists.list |
| `status` | Enum | Activation status | `Enabled`, `Disabled` | Pi-hole config |
| `domain_count` | Integer | Number of domains | Read-only, updated on gravity update | Pi-hole gravity.db |
| `last_updated` | Timestamp | Last update time | Auto-updated on gravity run | Pi-hole gravity.db |

**Default Blocklists**:
- StevenBlack's Unified Hosts: `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
- Additional lists configured via Pi-hole web UI

**Validation Rules**:
- `url` MUST be accessible from cluster (not behind firewall)
- `domain_count` MUST be > 0 for enabled lists

**State Transitions**:
```
[Initial] → Disabled → Enabled → Updating → Enabled
                          ↓          ↓
                       Disabled ← Failed (if URL unreachable)
```

**Relationships**:
- **Stored In**: PersistentVolume (`/etc/pihole/adlists.list` and `gravity.db`)
- **Managed By**: Pi-hole Instance

---

### 1.7 Whitelist

**Description**: List of domains to never block (user-defined exceptions).

**Attributes**:

| Attribute | Type | Description | Constraints | Source |
|-----------|------|-------------|-------------|--------|
| `domain` | String | Domain name | Valid domain (FQDN or wildcard) | Pi-hole whitelist |
| `type` | Enum | Match type | `Exact`, `Regex`, `Wildcard` | Pi-hole whitelist |
| `comment` | String | Reason for whitelisting | Optional | Pi-hole whitelist |
| `added_date` | Timestamp | When added | Auto-generated | Pi-hole database |

**Validation Rules**:
- `domain` MUST be valid domain format
- `type` determines matching behavior (exact match, regex pattern, or wildcard)

**Relationships**:
- **Stored In**: PersistentVolume (`/etc/pihole/gravity.db` whitelist table)
- **Managed By**: User via Pi-hole web UI or API

---

### 1.8 DNS Query

**Description**: Individual DNS lookup request from a client device.

**Attributes**:

| Attribute | Type | Description | Constraints | Source |
|-----------|------|-------------|-------------|--------|
| `id` | Integer | Query ID | Auto-increment | Pi-hole FTL database |
| `timestamp` | Timestamp | Query time | Unix timestamp | Pi-hole FTL |
| `client_ip` | String | Source client IP | IPv4 or IPv6 | DNS packet source |
| `domain` | String | Requested domain | FQDN | DNS query |
| `query_type` | Enum | DNS record type | `A`, `AAAA`, `PTR`, `CNAME`, etc. | DNS query |
| `status` | Enum | Query result | `Allowed`, `Blocked`, `Cached`, `Forwarded` | Pi-hole FTL |
| `response_time_ms` | Integer | Query latency | Milliseconds | Pi-hole FTL |
| `upstream_server` | String | Forwarded to (if applicable) | IP address | Pi-hole FTL |

**Validation Rules**:
- `timestamp` MUST be within reasonable range (not future, not before Pi-hole start)
- `client_ip` MUST be valid IP address
- `response_time_ms` SHOULD be < 1000ms for good performance

**State Transitions**:
```
[Received] → [Blocked] (if domain in blocklist)
          → [Cached] (if domain in cache)
          → [Forwarded] (if domain not cached) → [Allowed]
```

**Relationships**:
- **Source**: Device on Eero network
- **Target**: Pi-hole Instance
- **Stored In**: PersistentVolume (`/etc/pihole/pihole-FTL.db`)

**Retention**:
- Query history retained based on database size limit
- Default: ~100,000 queries or 24 hours (whichever reached first)

---

## 2. Relationships Diagram

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                      Eero Network (192.168.4.0/24)                      │
│                                                                         │
│  ┌──────────────┐           ┌──────────────┐      ┌──────────────┐    │
│  │ User Notebook│           │ Eero Router  │      │ Client Device│    │
│  │ (192.168.4.x)│           │ (192.168.4.1)│      │ (192.168.4.y)│    │
│  └──────┬───────┘           └──────┬───────┘      └──────┬───────┘    │
│         │                          │                     │             │
│         │ HTTP                     │ DNS Query           │ DNS Query   │
│         │ (port 30001)             │ (port 53)           │ (port 53)   │
└─────────┼──────────────────────────┼─────────────────────┼─────────────┘
          │                          │                     │
          │                          └─────────┬───────────┘
          │                                    │
          │                                    ▼
          │                          ┌─────────────────────┐
          │                          │ MetalLB LoadBalancer│
          │                          │ 192.168.4.200:53    │
          │                          └──────────┬──────────┘
          │                                     │
          │                                     ▼
          │                          ┌─────────────────────┐
          │                          │ CoreDNS Service     │
          │                          │ (kube-system)       │
          │                          └──────────┬──────────┘
          │                                     │
          │                          ┌──────────┴─────────┐
          │                          ↓                    ↓
          │                    Internal queries    External queries
          │                    (*.cluster.local)   (google.com, etc.)
          │                          ↓                    ↓
          │                    CoreDNS resolves    Forward to Pi-hole
          │                                        (10.43.232.162:53)
          ▼                                               ▼
  ┌────────────────┐                          ┌────────────────┐
  │ Web Admin      │                          │ DNS Service    │
  │ Service        │                          │ (NodePort)     │
  │ (NodePort)     │                          │ Port 30053     │
  └────────┬───────┘                          └────────┬───────┘
           │                                           │
           └───────────────────┬───────────────────────┘
                               │
                               ▼
                   ┌───────────────────────┐
                   │   Pi-hole Instance    │
                   │   (Deployment/Pod)    │
                   │                       │
                   │  ┌─────────────────┐  │
                   │  │ Pi-hole         │  │
                   │  │ Container       │  │
                   │  │                 │  │
                   │  │ /etc/pihole ────┼──┼───► PersistentVolumeClaim
                   │  └─────────────────┘  │       │
                   │                       │       │
                   │  Environment Vars:    │       ▼
                   │   - Admin Password ───┼───► Kubernetes Secret
                   │   - Upstream DNS      │
                   │   - Timezone          │
                   └───────────────────────┘
                               │
                               │ Upstream DNS
                               ▼
                   ┌───────────────────────┐
                   │ Cloudflare (1.1.1.1)  │
                   │ Google (8.8.8.8)      │
                   └───────────────────────┘
```

---

## 3. State Transitions

### 3.1 Pi-hole Instance Lifecycle

```text
[Not Deployed]
      │
      ▼
[Pending] ──────────────────────────┐
      │                             │
      │ Image pulled                │
      │ Volumes mounted             │
      │ Secrets loaded              │
      │                             │
      ▼                             │ Init failure
[Container Creating]                │ (ImagePullBackOff,
      │                             │  CrashLoopBackOff)
      │ Container started           │
      │ Health checks initializing  │
      │                             │
      ▼                             ▼
[Running] ───────────────────► [Failed]
      │                             │
      │ Liveness probe passing      │ Manual intervention
      │ Readiness probe passing     │ or auto-restart
      │                             │
      ▼                             ▼
[Ready/Serving]              [Restarting] ──► [Pending]
      │
      │ Admin deletes pod
      │ or rolling update
      ▼
[Terminating]
      │
      ▼
[Terminated]
```

### 3.2 DNS Query Processing

```text
Client Device sends DNS query (e.g., "doubleclick.net")
      │
      ▼
[Query Received by Pi-hole]
      │
      ├──► Check Local Cache
      │         │
      │         ├─► [Cache Hit] ──► Return cached result (fast path)
      │         │
      │         └─► [Cache Miss]
      │                 │
      ├──► Check Blocklist
      │         │
      │         ├─► [Domain Blocked] ──► Return 0.0.0.0 or NXDOMAIN
      │         │                         Log as "Blocked"
      │         │
      │         └─► [Domain Allowed]
      │                 │
      └──► Check Whitelist (override blocklist if needed)
                │
                ├─► [Whitelisted] ──► Forward to upstream DNS
                │                     Log as "Allowed (whitelisted)"
                │
                └─► [Forward to Upstream DNS]
                          │
                          ├─► Cloudflare (1.1.1.1)
                          │     or
                          └─► Google (8.8.8.8)
                                │
                                ▼
                          [Upstream Response]
                                │
                                ▼
                          [Cache Response]
                                │
                                ▼
                          [Return to Client]
                                │
                                ▼
                          [Log Query + Response Time]
```

### 3.3 Blocklist Update (Gravity)

```text
[Scheduled Gravity Update] (weekly by default)
      │
      ▼
[Download Blocklists from URLs]
      │
      ├─► URL 1 (StevenBlack's hosts)
      ├─► URL 2 (EasyList)
      └─► URL N (custom lists)
      │
      ▼
[Parse and Deduplicate Domains]
      │
      ▼
[Merge with Existing Gravity DB]
      │
      ▼
[Apply Whitelist Exclusions]
      │
      ▼
[Update gravity.db]
      │
      ▼
[Reload DNS Service (no downtime)]
      │
      ▼
[Log Update Statistics]
      │
      │ Total domains: X
      │ New domains: Y
      │ Removed domains: Z
      ▼
[Gravity Update Complete]
```

---

## 4. Validation Rules Summary

### Infrastructure Validation:
- **Kubernetes Cluster**: Must have at least 512Mi free memory on one node
- **Storage**: Must have K3s local-path-provisioner available
- **Network**: Nodes must be accessible on Eero network (192.168.4.0/24)
- **NodePort Range**: Port 30001 must be available (not used by another service)

### Pi-hole Configuration Validation:
- **Admin Password**: ≥ 8 characters, stored in Kubernetes Secret
- **Upstream DNS**: At least one valid IP address (format: `x.x.x.x`)
- **Timezone**: Valid IANA timezone string (e.g., `America/New_York`, `UTC`)
- **Resource Limits**: Memory ≥ 256Mi, CPU ≥ 100m

### Runtime Validation:
- **Health Checks**: Liveness and readiness probes must pass
- **DNS Resolution**: Test queries must succeed (e.g., `nslookup google.com <pi-hole-ip>`)
- **Web Interface**: Admin UI must be accessible at `http://<node-ip>:30001`
- **Persistence**: Configuration must survive pod restart

---

## 5. Performance Considerations

### Query Performance Targets:
- **Cached queries**: < 10ms response time
- **Uncached queries**: < 100ms response time (95th percentile)
- **Blocked queries**: < 5ms response time (immediate return of 0.0.0.0)

### Database Size Estimates:
- **Blocklist database (gravity.db)**: ~100-500MB (depending on blocklists)
- **Query history (pihole-FTL.db)**: ~10-50MB for 100,000 queries
- **Configuration files**: < 1MB

### Resource Utilization:
- **Idle state**: ~100Mi memory, ~50m CPU
- **Active state** (1000 queries/day): ~256Mi memory, ~200m CPU
- **Gravity update**: Temporary spike to ~512Mi memory, ~500m CPU

---

**Data Model Complete**: All entities, attributes, relationships, and state transitions defined. Ready for quickstart guide creation.
