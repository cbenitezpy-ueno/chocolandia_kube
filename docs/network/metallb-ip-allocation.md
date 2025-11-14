# MetalLB IP Allocation

**Network**: Eero Mesh (192.168.4.0/24)
**Created**: 2025-11-14
**Feature**: 011-postgresql-cluster

## IP Address Allocation

### Cluster Nodes
- `192.168.4.101` - master1 (control-plane)
- `192.168.4.102` - nodo1 (worker)
- `192.168.4.103` - nodo03 (control-plane)
- `192.168.4.104` - nodo04 (worker)

### MetalLB LoadBalancer Pool
- **Pool Name**: `eero-pool`
- **Range**: `192.168.4.200` - `192.168.4.210` (11 IPs)
- **Mode**: Layer 2 (L2Advertisement)
- **Auto-assign**: Enabled

### Reserved for MetalLB LoadBalancer Services
This range is reserved for Kubernetes LoadBalancer services and should NOT be assigned by the Eero router's DHCP server.

### Current Allocations
- **PostgreSQL External Access**: TBD (will be assigned from pool when LoadBalancer service is created)

## Router Configuration Notes

**Action Required**: Ensure Eero router DHCP does not assign IPs in the range `192.168.4.200-210`.

If Eero does not support DHCP exclusion ranges, monitor for IP conflicts and adjust the MetalLB pool range if needed (e.g., move to 192.168.4.220-230).

## Verification

```bash
# Check MetalLB IP pool
kubectl get ipaddresspool -n metallb-system

# Check L2 advertisement
kubectl get l2advertisement -n metallb-system

# List LoadBalancer services and their assigned IPs
kubectl get svc -A | grep LoadBalancer
```

## Troubleshooting

### IP Not Assigned to LoadBalancer Service
1. Check MetalLB controller logs: `kubectl logs -n metallb-system deployment/controller`
2. Check speaker logs: `kubectl logs -n metallb-system daemonset/speaker`
3. Verify IPAddressPool exists: `kubectl get ipaddresspool -n metallb-system`

### IP Conflict with DHCP
1. Check for duplicate IP assignment: `ping 192.168.4.200` (should not respond until LoadBalancer created)
2. Adjust MetalLB pool to different range if needed
3. Update `kubernetes/metallb/ip-pool.yaml` and reapply
