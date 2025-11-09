# Troubleshooting Runbook: Eero Network Issues

## Overview

This runbook documents common connectivity and network issues specific to the Feature 002 MVP K3s cluster deployed on the Eero mesh network. The Eero network presents unique challenges due to its flat topology, WiFi-based connectivity, and DHCP-managed IP addressing.

**Environment**: chocolandiadc-mvp (Feature 002)
**Network**: Eero mesh (192.168.4.0/24)
**Nodes**: master1 (192.168.4.101), nodo1 (192.168.4.102)

## Common Issues

### Issue 1: Node Cannot Be Reached via SSH

#### Symptoms
```bash
$ ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101
ssh: connect to host 192.168.4.101 port 22: No route to host
# or
ssh: connect to host 192.168.4.101 port 22: Connection refused
# or
ssh: connect to host 192.168.4.101 port 22: Connection timed out
```

#### Possible Causes
1. **Node is powered off or unreachable**
2. **WiFi connectivity issues** (weak signal, interference)
3. **IP address changed** (DHCP lease expired)
4. **Eero router rebooted** (temporary network outage)
5. **SSH service not running** on node

#### Diagnosis

**Step 1: Check node power and physical connectivity**
```bash
# Physically verify node is powered on (check LEDs, monitor if available)
# If using WiFi dongles, verify they're connected
```

**Step 2: Ping the node**
```bash
ping -c 4 192.168.4.101

# If ping fails, node is not reachable on network
# If ping succeeds but SSH fails, SSH service issue
```

**Step 3: Check if IP address changed**
```bash
# Access Eero app on mobile device
# Navigate to: Settings > Network Settings > Devices
# Find node by MAC address or hostname
# Verify current IP address

# Alternative: Scan network for SSH services
nmap -p 22 192.168.4.0/24
```

**Step 4: Check Eero network status**
```bash
# Open Eero app
# Check if any nodes are offline or experiencing issues
# Verify internet connectivity is working
```

#### Resolution

**If IP address changed:**
```bash
# Option A: Update terraform.tfvars with new IP
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp
vim terraform.tfvars
# Update master1_ip or nodo1_ip

# Option B: Configure static DHCP reservation in Eero app
# Settings > Network Settings > Reservations & Port Forwarding
# Reserve 192.168.4.101 for master1
# Reserve 192.168.4.102 for nodo1
```

**If node is unreachable:**
```bash
# Physical access required
# 1. Connect monitor and keyboard to node
# 2. Login locally
# 3. Check network status:
ip addr show
# Verify interface has correct IP

# 4. Check WiFi connection (if using WiFi):
nmcli device status
nmcli connection show

# 5. Restart network service:
sudo systemctl restart NetworkManager
# or
sudo systemctl restart systemd-networkd
```

**If SSH service not running:**
```bash
# Physical access or console required
sudo systemctl status sshd
sudo systemctl start sshd
sudo systemctl enable sshd
```

### Issue 2: Intermittent Node Connectivity

#### Symptoms
- SSH connections drop unexpectedly
- `kubectl` commands time out intermittently
- Nodes appear as `NotReady` periodically
- High latency between nodes

#### Possible Causes
1. **WiFi signal strength issues**
2. **Eero mesh hand-off problems** (node switching between Eero access points)
3. **WiFi interference** (2.4GHz congestion, microwave, etc.)
4. **Eero firmware update** in progress
5. **Network congestion** (other devices saturating bandwidth)

#### Diagnosis

**Step 1: Check node status in cluster**
```bash
export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig

kubectl get nodes -o wide

# Check node conditions
kubectl describe node master1 | grep -A 10 Conditions
kubectl describe node nodo1 | grep -A 10 Conditions

# Look for:
# - Ready=False or Unknown
# - NetworkUnavailable=True
# - MemoryPressure, DiskPressure (unlikely on Eero network)
```

**Step 2: Monitor ping latency and packet loss**
```bash
# Continuous ping from your workstation
ping 192.168.4.101

# Watch for:
# - Latency spikes (>100ms on LAN is bad)
# - Packet loss (any % is concerning)
# - Timeouts (complete connectivity loss)

# Ping between nodes (SSH to master1)
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101
ping -c 100 192.168.4.102

# Check statistics:
# - rtt min/avg/max/mdev
# - Packet loss %
```

**Step 3: Check WiFi signal strength** (if using WiFi)
```bash
# On node (physical or SSH access)
iwconfig wlan0 | grep -i signal
# or
nmcli device wifi list

# Good signal: >-70 dBm
# Marginal: -70 to -80 dBm
# Poor: <-80 dBm
```

**Step 4: Check Eero mesh status**
```bash
# Open Eero app
# Navigate to: Network Health
# Check for:
# - Slow internet speed warnings
# - Offline Eero nodes
# - Firmware update in progress
```

#### Resolution

**For WiFi signal issues:**
```bash
# Option A: Move node closer to Eero access point
# Option B: Add another Eero node to improve coverage
# Option C: Use Ethernet instead of WiFi (recommended)

# If WiFi must be used, connect to 5GHz band:
# Eero automatically steers devices, but you can:
# - Disable 2.4GHz on node WiFi adapter
# - Use WiFi analyzer to find least congested channel
```

**For mesh hand-off issues:**
```bash
# Eero automatically manages hand-offs
# Workaround: Force connection to specific Eero node
# (Not officially supported by Eero)

# Better solution: Use Ethernet backhaul for Eero nodes
```

**For network congestion:**
```bash
# Identify bandwidth-heavy devices in Eero app
# Settings > Network Settings > Devices
# Sort by data usage

# Pause high-bandwidth devices during critical operations
```

### Issue 3: DHCP IP Address Changed

#### Symptoms
- `kubectl` commands fail with "unable to connect to server"
- SSH fails with "no route to host"
- Previously working IP addresses no longer respond
- OpenTofu apply fails with connection errors

#### Possible Causes
1. **DHCP lease expired** and node got new IP
2. **Eero router rebooted** and reassigned IPs
3. **New device joined network** and took reserved IP
4. **DHCP reservation not configured** in Eero

#### Diagnosis

**Step 1: Check current IP via Eero app**
```bash
# Open Eero app
# Settings > Network Settings > Devices
# Find node by hostname or MAC address
# Note current IP address
```

**Step 2: Scan network for nodes**
```bash
# Scan for SSH services (port 22)
nmap -p 22 --open 192.168.4.0/24

# Or scan for all devices
nmap -sn 192.168.4.0/24

# Look for known MAC addresses or hostnames
```

**Step 3: Physical access to check IP**
```bash
# Connect monitor/keyboard to node
# Check IP address:
ip addr show
hostname -I
```

#### Resolution

**Configure static DHCP reservations** (REQUIRED for stable cluster)
```bash
# Open Eero app
# Settings > Network Settings > Reservations & Port Forwarding
# Tap "Add a reservation"

# For master1:
# - Select device (by hostname or MAC)
# - Reserved IP: 192.168.4.101
# - Save

# For nodo1:
# - Select device
# - Reserved IP: 192.168.4.102
# - Save

# Reboot nodes to ensure they get reserved IPs
ssh -i ~/.ssh/id_ed25519_k3s chocolim@<current_ip> "sudo reboot"
```

**Update OpenTofu configuration if IP changed**
```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Edit terraform.tfvars
vim terraform.tfvars

# Update IPs:
master1_ip = "192.168.4.NEW_IP"  # Update if changed
nodo1_ip   = "192.168.4.NEW_IP"  # Update if changed

# Re-run OpenTofu (updates may trigger redeployment)
tofu plan
# Review changes carefully
tofu apply
```

**Update kubeconfig with new IP**
```bash
# If master1 IP changed, regenerate kubeconfig
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp

# Fetch new kubeconfig from master1 (use new IP)
ssh -i ~/.ssh/id_ed25519_k3s chocolim@NEW_IP \
  "sudo cat /etc/rancher/k3s/k3s.yaml" | \
  sed "s/127.0.0.1/NEW_IP/g" > kubeconfig

chmod 600 kubeconfig

# Test connectivity
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

### Issue 4: Pods Cannot Communicate (CNI Issues)

#### Symptoms
- Pods stuck in `ContainerCreating` state
- Pods cannot reach other pods or services
- DNS resolution fails within pods
- `kubectl logs` shows network errors

#### Possible Causes
1. **Flannel CNI not initialized** properly
2. **Node networking misconfigured** (wrong subnet)
3. **Eero firewall blocking VXLAN** (unlikely but possible)
4. **Node ran out of IP addresses** in pod CIDR

#### Diagnosis

**Step 1: Check pod status**
```bash
export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig

kubectl get pods -A -o wide

# Look for pods stuck in:
# - ContainerCreating
# - CrashLoopBackOff
# - Error
```

**Step 2: Check Flannel pods**
```bash
kubectl get pods -n kube-system | grep flannel

# Expected: flannel pods Running on each node
# If missing or failing, CNI is broken
```

**Step 3: Check node networking**
```bash
kubectl describe node master1 | grep -i cidr
kubectl describe node nodo1 | grep -i cidr

# Verify each node has unique PodCIDR
# Example:
# master1: 10.42.0.0/24
# nodo1:   10.42.1.0/24
```

**Step 4: Test pod-to-pod connectivity**
```bash
# Deploy test pod
kubectl run test-pod --image=nicolaka/netshoot --rm -it -- /bin/bash

# Inside pod:
ping 8.8.8.8  # Test internet connectivity
nslookup kubernetes.default  # Test DNS
curl http://kube-prometheus-stack-grafana.monitoring  # Test service access
```

#### Resolution

**Restart Flannel pods**
```bash
kubectl delete pods -n kube-system -l app=flannel

# K3s will recreate them automatically
kubectl get pods -n kube-system | grep flannel
```

**Restart K3s on affected nodes**
```bash
# On master1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 \
  "sudo systemctl restart k3s"

# On nodo1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102 \
  "sudo systemctl restart k3s-agent"

# Wait for nodes to be Ready
kubectl get nodes -w
```

**Check K3s logs for errors**
```bash
# On master1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 \
  "sudo journalctl -u k3s -n 100 --no-pager"

# On nodo1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102 \
  "sudo journalctl -u k3s-agent -n 100 --no-pager"

# Look for CNI errors, network errors, VXLAN errors
```

### Issue 5: Grafana Inaccessible on NodePort 30000

#### Symptoms
- `curl http://192.168.4.101:30000` times out or connection refused
- Grafana URL unreachable from browser
- NodePort service exists but not responding

#### Possible Causes
1. **Grafana pod not running**
2. **Service not bound to NodePort**
3. **Firewall on node blocking port 30000** (unlikely on Debian/Ubuntu)
4. **Eero blocking high ports** (very unlikely)

#### Diagnosis

**Step 1: Check Grafana pod status**
```bash
export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig

kubectl get pods -n monitoring | grep grafana

# Expected: grafana pod Running (3/3)
```

**Step 2: Check service configuration**
```bash
kubectl get svc -n monitoring kube-prometheus-stack-grafana

# Verify:
# - TYPE: NodePort
# - PORT(S): 80:30000/TCP

kubectl describe svc -n monitoring kube-prometheus-stack-grafana

# Check Endpoints (should list pod IP:port)
```

**Step 3: Test from node itself**
```bash
# SSH to master1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101

# Curl from localhost
curl -v http://localhost:30000

# Expected: HTTP 200 or 302 redirect
```

**Step 4: Check iptables rules** (NodePort uses iptables)
```bash
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 \
  "sudo iptables -t nat -L KUBE-NODEPORTS -n | grep 30000"

# Should see DNAT rule forwarding 30000 to service
```

#### Resolution

**Restart Grafana pod**
```bash
kubectl rollout restart deployment/kube-prometheus-stack-grafana -n monitoring

kubectl get pods -n monitoring -w  # Watch pod recreate
```

**Verify service is correctly configured**
```bash
# Check service YAML
kubectl get svc -n monitoring kube-prometheus-stack-grafana -o yaml

# Ensure nodePort: 30000 is set
# If not, edit monitoring.tf and re-apply
```

**Test with port-forward as fallback**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Access via http://localhost:3000
```

## Preventative Measures

### Network Stability

1. **Configure DHCP Reservations** (CRITICAL)
   - Reserve 192.168.4.101 for master1
   - Reserve 192.168.4.102 for nodo1
   - Document MAC addresses

2. **Use Ethernet Instead of WiFi**
   - Connect nodes via Ethernet to Eero nodes
   - Avoid WiFi dongles if possible
   - Use Ethernet backhaul for Eero mesh

3. **Monitor Eero Network Health**
   - Check Eero app weekly for issues
   - Enable firmware auto-updates (or monitor manually)
   - Keep Eero nodes powered and connected

### Cluster Stability

1. **Monitor Node Status Daily**
   ```bash
   export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig
   kubectl get nodes
   kubectl get pods -A | grep -v Running | grep -v Completed
   ```

2. **Regular Backups**
   ```bash
   cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp
   bash scripts/backup-state.sh
   bash scripts/backup-cluster.sh
   ```

3. **Document IP Changes**
   - Keep terraform.tfvars up to date
   - Document any IP changes in runbook

## Escalation

If issues persist after trying these troubleshooting steps:

1. **Check K3s GitHub Issues**: https://github.com/k3s-io/k3s/issues
2. **Eero Support**: https://support.eero.com
3. **Consider Migration to Feature 001**: If Eero network is too unstable

## Related Documentation

- **Security Checklist**: `/Users/cbenitez/chocolandia_kube/docs/security-checklist.md`
- **Migration Runbook**: `/Users/cbenitez/chocolandia_kube/docs/runbooks/migration-to-feature-001.md`
- **Quickstart Guide**: `/Users/cbenitez/chocolandia_kube/specs/002-k3s-mvp-eero/quickstart.md`

---

**Last Updated**: 2025-11-09
**Environment**: Feature 002 MVP (chocolandiadc-mvp)
**Network**: Eero mesh (192.168.4.0/24)
