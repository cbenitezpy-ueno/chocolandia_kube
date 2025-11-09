# Migration Runbook: Feature 002 (MVP Eero) to Feature 001 (FortiGate HA)

## Overview

This runbook documents the migration path from the temporary Feature 002 MVP deployment (single-server K3s on Eero flat network) to the production Feature 001 deployment (HA K3s cluster with FortiGate firewall and VLAN segmentation).

**Status**: Feature 002 is a temporary solution while FortiGate hardware is being repaired. This migration will be executed once the FortiGate is operational.

## Current State (Feature 002 - MVP)

### Network Architecture
- **Network Type**: Eero mesh (flat network, no VLANs)
- **Subnet**: 192.168.4.0/24
- **Gateway**: Eero router (DHCP managed)
- **Nodes**:
  - `master1`: 192.168.4.101 (K3s server, single-node control plane)
  - `nodo1`: 192.168.4.102 (K3s agent, worker node)

### Cluster Configuration
- **K3s Version**: v1.28.3+k3s1
- **Datastore**: SQLite (embedded, single-server mode)
- **High Availability**: None (single control-plane node)
- **Disabled Components**: Traefik (custom ingress planned)
- **Storage**: Local path provisioner (non-replicated)
- **Monitoring**: Prometheus + Grafana (kube-prometheus-stack)

### Workloads
- **Monitoring Stack** (namespace: `monitoring`):
  - Prometheus (10Gi PVC)
  - Grafana (5Gi PVC, NodePort 30000)
  - Alertmanager
  - Node Exporter (DaemonSet on both nodes)
  - Kube State Metrics

## Target State (Feature 001 - Production)

### Network Architecture
- **Network Type**: FortiGate-managed VLANs
- **VLANs**:
  - VLAN 10 (Management): 10.10.10.0/24 - Proxmox, management interfaces
  - VLAN 20 (Cluster): 10.20.20.0/24 - K3s control plane and data plane
  - VLAN 30 (Storage): 10.30.30.0/24 - Longhorn storage network
  - VLAN 40 (Services): 10.40.40.0/24 - Exposed services (LoadBalancer)
- **Gateway**: FortiGate 60F
- **Nodes** (planned):
  - `k3s-master1`: 10.20.20.11 (Proxmox VM, control plane)
  - `k3s-master2`: 10.20.20.12 (Proxmox VM, control plane)
  - `k3s-master3`: 10.20.20.13 (Proxmox VM, control plane)
  - `k3s-worker1`: 10.20.20.21 (Proxmox VM, worker)
  - `k3s-worker2`: 10.20.20.22 (Proxmox VM, worker)

### Cluster Configuration
- **K3s Version**: v1.28.3+k3s1 (same as MVP)
- **Datastore**: Embedded etcd (HA mode, 3 masters)
- **High Availability**: 3 control-plane nodes with embedded etcd
- **Storage**: Longhorn (replicated block storage on VLAN 30)
- **Load Balancer**: MetalLB (VLAN 40 IP pool)
- **Ingress**: Traefik or nginx-ingress
- **Monitoring**: Prometheus + Grafana (migrated from Feature 002)

## Migration Strategy

### Migration Approach

**Strategy**: Parallel deployment with controlled workload migration

1. Deploy Feature 001 cluster as new infrastructure
2. Backup all data from Feature 002 cluster
3. Migrate workloads one namespace at a time
4. Validate workloads in Feature 001 cluster
5. Decommission Feature 002 cluster

**Rationale**: Parallel deployment minimizes downtime and allows rollback if issues occur.

### Network Transition

#### Option A: Dual-Stack (Recommended)
- Keep Feature 002 operational on Eero network (192.168.4.0/24)
- Deploy Feature 001 on FortiGate VLANs (10.20.20.0/24)
- Configure routing between networks during migration
- Gradually shift traffic to Feature 001
- Decommission Feature 002 when stable

#### Option B: In-Place Conversion (Higher Risk)
- Drain workloads from Feature 002
- Backup all data
- Reconfigure network interfaces on physical nodes
- Redeploy K3s with new IPs and HA configuration
- Restore workloads

**Recommendation**: Use Option A for production-grade migration.

## Pre-Migration Validation

### Checklist: Current Cluster Health

Before starting migration, verify Feature 002 cluster is healthy:

```bash
# Export kubeconfig
export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig

# Check all nodes are Ready
kubectl get nodes -o wide

# Check all system pods are Running
kubectl get pods -A | grep -v Running | grep -v Completed

# Verify monitoring stack
kubectl get pods -n monitoring

# Check PersistentVolumes (Prometheus, Grafana data)
kubectl get pv,pvc -A

# Verify workload endpoints
curl -s http://192.168.4.101:30000/api/health | jq
```

Expected results:
- ✅ All nodes: `Ready`
- ✅ All system pods: `Running`
- ✅ Monitoring pods: 7/7 Running
- ✅ PVCs: Bound (Prometheus 10Gi, Grafana 5Gi)
- ✅ Grafana API: `{"database": "ok"}`

### Inventory: Workloads to Migrate

Document all workloads currently running on Feature 002:

| Namespace   | Workload Type    | Name                              | Storage | Notes                    |
|-------------|------------------|-----------------------------------|---------|--------------------------|
| monitoring  | StatefulSet      | prometheus                        | 10Gi PVC| Metrics retention 15d    |
| monitoring  | Deployment       | grafana                           | 5Gi PVC | Admin password changed   |
| monitoring  | StatefulSet      | alertmanager                      | -       | Default config           |
| monitoring  | DaemonSet        | node-exporter                     | -       | Runs on all nodes        |
| monitoring  | Deployment       | kube-state-metrics                | -       | -                        |
| kube-system | Deployment       | coredns                           | -       | DNS service              |
| kube-system | Deployment       | local-path-provisioner            | -       | Default storage class    |
| kube-system | Deployment       | metrics-server                    | -       | Resource metrics         |

### IP Address Mapping

Map current IPs to target IPs for DNS/service updates:

| Current (Feature 002)          | Target (Feature 001)          | Purpose               |
|--------------------------------|-------------------------------|-----------------------|
| 192.168.4.101 (master1)        | 10.20.20.11-13 (VIP)          | K3s API Server        |
| 192.168.4.101:30000 (Grafana)  | 10.40.40.50:80 (LoadBalancer) | Grafana Web UI        |
| 192.168.4.101:6443 (API)       | 10.20.20.100:6443 (VIP)       | Kubernetes API        |

## Migration Steps

### Phase 1: Backup Feature 002 Cluster

#### Step 1.1: Backup OpenTofu State

```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Run backup script (see T046)
bash scripts/backup-state.sh

# Expected outputs:
# - backups/terraform-state-YYYYMMDD-HHMMSS.tar.gz
# - backups/cluster-token-YYYYMMDD-HHMMSS.txt
```

#### Step 1.2: Backup Cluster Data

```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Run cluster backup script (see T047)
bash scripts/backup-cluster.sh

# Expected outputs:
# - backups/k3s-state-db-YYYYMMDD-HHMMSS.db (SQLite database)
# - backups/kubeconfig-YYYYMMDD-HHMMSS.yaml
# - backups/manifests-YYYYMMDD-HHMMSS/ (all deployed manifests)
```

#### Step 1.3: Backup Monitoring Data

```bash
# Export Prometheus data (optional, for historical metrics)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
PF_PID=$!

# Create snapshot (requires promtool or remote write)
# For quick migration, rely on Prometheus scraping from scratch in new cluster

# Export Grafana dashboards and datasources
curl -u admin:$GRAFANA_PASSWORD http://192.168.4.101:30000/api/search | \
  jq -r '.[] | .uid' | \
  while read uid; do
    curl -u admin:$GRAFANA_PASSWORD \
      http://192.168.4.101:30000/api/dashboards/uid/$uid > \
      backups/grafana-dashboard-$uid.json
  done

kill $PF_PID
```

#### Step 1.4: Backup PersistentVolume Data

```bash
# Find PV paths on nodes
kubectl get pv -o json | jq -r '.items[] | "\(.metadata.name): \(.spec.local.path)"'

# SSH to master1 and backup PV data
ssh chocolim@192.168.4.101 "sudo tar -czf /tmp/pv-monitoring-prometheus.tar.gz /var/lib/rancher/k3s/storage/pvc-*-prometheus*"
scp chocolim@192.168.4.101:/tmp/pv-monitoring-prometheus.tar.gz backups/

ssh chocolim@192.168.4.101 "sudo tar -czf /tmp/pv-monitoring-grafana.tar.gz /var/lib/rancher/k3s/storage/pvc-*-grafana*"
scp chocolim@192.168.4.101:/tmp/pv-monitoring-grafana.tar.gz backups/
```

### Phase 2: Deploy Feature 001 Cluster

**Pre-requisites**:
- FortiGate 60F configured with VLANs 10, 20, 30, 40
- Proxmox VE operational
- VMs created for K3s nodes (3 masters, 2 workers)
- OpenTofu code for Feature 001 ready

```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/production-ha

# Review terraform.tfvars
cat terraform.tfvars

# Plan deployment
tofu plan

# Deploy HA cluster
tofu apply

# Verify cluster
export KUBECONFIG=./kubeconfig
kubectl get nodes
kubectl get pods -A
```

### Phase 3: Migrate Monitoring Stack

#### Step 3.1: Deploy Monitoring Stack on Feature 001

```bash
# Already included in Feature 001 OpenTofu code (monitoring.tf)
# Verify deployment
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

#### Step 3.2: Restore Grafana Dashboards

```bash
# Import custom dashboards (if any were created)
for dashboard in backups/grafana-dashboard-*.json; do
  curl -X POST \
    -H "Content-Type: application/json" \
    -u admin:$NEW_GRAFANA_PASSWORD \
    -d @$dashboard \
    http://10.40.40.50/api/dashboards/db
done

# Update Grafana admin password to match Feature 002
kubectl create secret generic -n monitoring grafana-admin-password \
  --from-literal=admin-password=$OLD_GRAFANA_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Step 3.3: Configure Prometheus Remote Write (Optional)

If historical metrics are needed, configure remote write from Feature 002 to Feature 001:

```bash
# Edit Prometheus config in Feature 002
kubectl edit prometheus -n monitoring kube-prometheus-stack-prometheus

# Add remote_write section:
# remoteWrite:
# - url: http://10.20.20.11:9090/api/v1/write
```

### Phase 4: Migrate Additional Workloads

As workloads are deployed on Feature 002, document migration steps here.

Example workflow:
1. Export workload manifests from Feature 002
2. Update IP addresses, storage classes, ingress rules
3. Apply to Feature 001 cluster
4. Verify functionality
5. Update DNS/load balancers
6. Decommission from Feature 002

### Phase 5: Validation & Cutover

#### Validation Checklist

```bash
# Feature 001 cluster health
kubectl get nodes
kubectl get pods -A

# Monitoring stack
curl -s http://10.40.40.50/api/health | jq

# Workload connectivity
# (Add specific tests for each migrated workload)

# Performance baseline
kubectl top nodes
kubectl top pods -A
```

#### Cutover Steps

1. Update external DNS entries to point to Feature 001 IPs
2. Update client kubeconfig files to Feature 001 API endpoint
3. Monitor Feature 001 cluster for 24-48 hours
4. Verify no traffic to Feature 002 cluster
5. Proceed with decommissioning

### Phase 6: Decommission Feature 002

**Only execute after Feature 001 is stable for 7+ days**

```bash
# Drain nodes
kubectl drain master1 --ignore-daemonsets --delete-emptydir-data
kubectl drain nodo1 --ignore-daemonsets --delete-emptydir-data

# Destroy OpenTofu-managed resources
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp
tofu destroy

# Archive configuration
mkdir -p /Users/cbenitez/chocolandia_kube/archive/feature-002
cp -r . /Users/cbenitez/chocolandia_kube/archive/feature-002/
git tag feature-002-decommissioned
git push --tags
```

## Rollback Plan

If issues occur during migration:

### Scenario A: Feature 001 Deployment Failed

1. Do not proceed with workload migration
2. Keep Feature 002 operational
3. Debug Feature 001 issues
4. Retry deployment when resolved

### Scenario B: Workload Migration Issues

1. Stop migration process
2. Revert DNS/load balancer changes
3. Ensure Feature 002 workloads are still operational
4. Investigate issues in Feature 001
5. Plan remediation steps

### Scenario C: Post-Cutover Issues

1. Revert DNS/load balancer changes to Feature 002 IPs
2. Communicate downtime to users
3. Restore Feature 002 cluster from backups if needed:

```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Restore OpenTofu state
tar -xzf backups/terraform-state-YYYYMMDD-HHMMSS.tar.gz

# Restore cluster token
scp backups/cluster-token-YYYYMMDD-HHMMSS.txt chocolim@192.168.4.101:/tmp/node-token
ssh chocolim@192.168.4.101 "sudo mv /tmp/node-token /var/lib/rancher/k3s/server/node-token"

# Restore SQLite database
scp backups/k3s-state-db-YYYYMMDD-HHMMSS.db chocolim@192.168.4.101:/tmp/state.db
ssh chocolim@192.168.4.101 "sudo systemctl stop k3s && sudo mv /tmp/state.db /var/lib/rancher/k3s/server/db/state.db && sudo systemctl start k3s"

# Verify cluster
export KUBECONFIG=backups/kubeconfig-YYYYMMDD-HHMMSS.yaml
kubectl get nodes
```

## Post-Migration Tasks

After successful migration to Feature 001:

- [ ] Update documentation to reference Feature 001 as primary
- [ ] Archive Feature 002 code with git tag
- [ ] Update CLAUDE.md with new network architecture
- [ ] Update monitoring dashboards with new IP ranges
- [ ] Document lessons learned
- [ ] Create Feature 001 runbooks for operations

## References

- **Feature 001 Spec**: `/Users/cbenitez/chocolandia_kube/specs/001-k3s-cluster-setup/`
- **Feature 002 Spec**: `/Users/cbenitez/chocolandia_kube/specs/002-k3s-mvp-eero/`
- **K3s Backup Documentation**: https://docs.k3s.io/backup-restore
- **Prometheus Remote Write**: https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write
- **Grafana Dashboard API**: https://grafana.com/docs/grafana/latest/developers/http_api/dashboard/

## Contact

For questions about this migration:
- **Project Owner**: cbenitez@gmail.com
- **Repository**: https://github.com/cbenitez/chocolandia_kube (if applicable)

---

**Last Updated**: 2025-11-09
**Runbook Version**: 1.0
**Status**: Draft (Feature 001 blocked on FortiGate hardware repair)
