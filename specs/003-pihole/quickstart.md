# Quickstart: Pi-hole DNS Ad Blocker Deployment

**Feature**: 003-pihole
**Target**: K3s cluster on Eero network (Feature 002 MVP)
**Time to Deploy**: ~10 minutes

## Prerequisites

Before deploying Pi-hole, ensure you have:

✅ **K3s cluster operational** (Feature 002 completed)
- 2 nodes: master1 (192.168.4.101), nodo1 (192.168.4.102)
- `kubectl` access configured
- K3s local-path-provisioner available

✅ **OpenTofu installed** (version 1.6+)
- `tofu version` should return 1.6 or higher

✅ **Network access to Eero network** (192.168.4.0/24)
- Laptop connected to Eero WiFi or Ethernet

✅ **Cluster resources available**:
- At least 512Mi free memory on one node
- At least 0.5 CPU cores available
- At least 2Gi storage space

---

## Step 1: Verify Cluster Health

```bash
# Set kubeconfig
export KUBECONFIG=./terraform/environments/chocolandiadc-mvp/kubeconfig

# Verify nodes are Ready
kubectl get nodes

# Expected output:
# NAME      STATUS   ROLES                  AGE   VERSION
# master1   Ready    control-plane,master   Xd    v1.28.3+k3s1
# nodo1     Ready    <none>                 Xd    v1.28.3+k3s1

# Verify local-path-provisioner is running
kubectl get pods -n kube-system | grep local-path

# Expected output:
# local-path-provisioner-xxx   1/1     Running   X   Xd
```

---

## Step 2: Generate Pi-hole Admin Password

```bash
# Generate secure random password
PIHOLE_PASSWORD=$(openssl rand -base64 16)

# Display password (save this!)
echo "Pi-hole Admin Password: $PIHOLE_PASSWORD"

# Alternative: Use custom password
# PIHOLE_PASSWORD="your-secure-password-here"
```

**Important**: Save this password! You'll need it to access the Pi-hole web interface.

---

## Step 3: Deploy Pi-hole via OpenTofu

### Option A: Quick Deploy (Recommended)

```bash
# Navigate to environment directory
cd terraform/environments/chocolandiadc-mvp

# Initialize OpenTofu (if not already done)
tofu init

# Set admin password variable
export TF_VAR_pihole_admin_password="$PIHOLE_PASSWORD"

# Deploy Pi-hole
tofu apply -target=module.pihole

# Review plan and type 'yes' to confirm
```

### Option B: Manual Review Before Apply

```bash
# Preview changes
tofu plan -target=module.pihole

# Review planned resources:
# - kubernetes_namespace.pihole (if using dedicated namespace)
# - kubernetes_secret.pihole_admin_password
# - kubernetes_persistent_volume_claim.pihole_config
# - kubernetes_deployment.pihole
# - kubernetes_service.pihole_dns
# - kubernetes_service.pihole_web

# Apply if plan looks good
tofu apply -target=module.pihole
```

---

## Step 4: Verify Deployment

### Check Pod Status

```bash
# Watch pod creation
kubectl get pods -l app=pihole -w

# Expected final state:
# NAME                      READY   STATUS    RESTARTS   AGE
# pihole-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# Check pod logs
kubectl logs -l app=pihole --tail=50

# Look for successful initialization:
# [✓] FTL started
# [✓] lighttpd started
# [✓] DNS service started
```

### Check Services

```bash
# Verify DNS service
kubectl get svc pihole-dns

# Expected output:
# NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)            AGE
# pihole-dns   ClusterIP   10.43.x.x       <none>        53/TCP,53/UDP      2m

# Verify web admin service
kubectl get svc pihole-web

# Expected output:
# NAME         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
# pihole-web   NodePort   10.43.x.x       <none>        80:30001/TCP    2m
```

### Check PersistentVolumeClaim

```bash
# Verify storage is bound
kubectl get pvc pihole-config

# Expected output:
# NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# pihole-config   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   2Gi        RWO            local-path     2m
```

---

## Step 5: Access Pi-hole Web Interface

### Get Web Interface URL

```bash
# Pi-hole web interface is accessible at:
echo "http://192.168.4.101:30001"
echo "http://192.168.4.102:30001"

# Both URLs should work (NodePort accessible on all nodes)
```

### Login to Pi-hole

1. **Open browser** on your laptop (connected to Eero network)
2. **Navigate** to `http://192.168.4.101:30001`
3. **Click** "Login" in the left sidebar
4. **Enter** admin password (from Step 2)
5. **Verify** you see the Pi-hole dashboard

---

## Step 6: Test DNS Resolution

### Test from Laptop (Manual DNS Configuration)

```bash
# Test DNS query to Pi-hole DNS service
# Note: This requires configuring your laptop to use node IP as DNS

# On macOS/Linux:
nslookup google.com 192.168.4.101

# Expected output:
# Server:    192.168.4.101
# Address:   192.168.4.101#53
#
# Non-authoritative answer:
# Name:   google.com
# Address: 142.250.x.x

# Test ad domain (should be blocked)
nslookup doubleclick.net 192.168.4.101

# Expected output (if blocked):
# Server:    192.168.4.101
# Address:   192.168.4.101#53
#
# Name:   doubleclick.net
# Address: 0.0.0.0
```

### Test from Within Cluster

```bash
# Create test pod
kubectl run -it --rm dns-test --image=nicolaka/netshoot --restart=Never -- /bin/bash

# Inside test pod:
nslookup google.com pihole-dns.default.svc.cluster.local

# Expected: Successful resolution

# Test ad domain
nslookup doubleclick.net pihole-dns.default.svc.cluster.local

# Expected: 0.0.0.0 or NXDOMAIN (blocked)

# Exit test pod
exit
```

---

## Step 7: Configure Your Device to Use Pi-hole

### Option A: macOS

1. **Open System Settings** → **Network**
2. **Select** your WiFi connection (Eero network)
3. **Click** "Details..."
4. **Select** "DNS" tab
5. **Click** "+" and **add**: `192.168.4.101`
6. **Optional**: Add fallback: `192.168.4.102`
7. **Click** "OK" and **Apply**

### Option B: Windows

1. **Open** Control Panel → Network and Sharing Center
2. **Click** on your WiFi connection (Eero network)
3. **Click** "Properties"
4. **Select** "Internet Protocol Version 4 (TCP/IPv4)"
5. **Click** "Properties"
6. **Select** "Use the following DNS server addresses"
7. **Preferred DNS**: `192.168.4.101`
8. **Alternate DNS**: `192.168.4.102` (optional)
9. **Click** "OK"

### Option C: iOS

1. **Open Settings** → **Wi-Fi**
2. **Tap** the "i" icon next to your Eero network
3. **Scroll** to "Configure DNS"
4. **Select** "Manual"
5. **Remove** existing DNS servers
6. **Add** Server: `192.168.4.101`
7. **Tap** "Save"

### Option D: Android

1. **Open Settings** → **Network & Internet** → **Wi-Fi**
2. **Long press** on your Eero network → **Modify network**
3. **Select** "Advanced options"
4. **Change** "IP settings" to "Static"
5. **Set** DNS 1: `192.168.4.101`
6. **Set** DNS 2: `192.168.4.102` (optional)
7. **Save**

---

## Step 8: Verify Ad Blocking

### Quick Test

1. **Configure** your device DNS (Step 7)
2. **Open** Pi-hole web interface (`http://192.168.4.101:30001`)
3. **Navigate** to "Query Log" in left sidebar
4. **Browse** any website with ads (e.g., news sites)
5. **Refresh** Pi-hole Query Log
6. **Verify** you see:
   - Queries from your device IP
   - Some queries marked as "Blocked" (red)
   - Percentage of queries blocked > 0%

### Dashboard Metrics

Check Pi-hole dashboard for:
- **Queries blocked**: Should be > 0 after browsing
- **Percentage blocked**: Typically 10-25% for typical browsing
- **Clients**: Should show your device IP

---

## Step 9: Customize Pi-hole (Optional)

### Add Custom Blocklists

1. **Login** to Pi-hole web interface
2. **Navigate** to "Adlists" (left sidebar)
3. **Paste** blocklist URL (e.g., https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts)
4. **Click** "Add"
5. **Navigate** to "Tools" → "Update Gravity"
6. **Click** "Update" to download and activate new blocklist

### Whitelist a Domain

If a website is broken due to Pi-hole blocking:

1. **Navigate** to "Whitelist" (left sidebar)
2. **Enter** domain name (e.g., `example.com`)
3. **Click** "Add to whitelist"
4. **Test** website again

### Blacklist a Domain

To manually block a specific domain:

1. **Navigate** to "Blacklist" (left sidebar)
2. **Enter** domain name (e.g., `ads.example.com`)
3. **Click** "Add to blacklist"

---

## Step 10: Monitoring and Logs

### View Real-Time Logs

```bash
# Follow Pi-hole container logs
kubectl logs -f -l app=pihole

# Filter for DNS queries
kubectl logs -l app=pihole | grep "query"

# Filter for blocked queries
kubectl logs -l app=pihole | grep "blocked"
```

### Check Resource Usage

```bash
# Get pod resource usage
kubectl top pod -l app=pihole

# Expected output:
# NAME                      CPU(cores)   MEMORY(bytes)
# pihole-xxxxxxxxxx-xxxxx   50m          250Mi
```

### Query Log via Web Interface

1. **Login** to Pi-hole web interface
2. **Navigate** to "Query Log"
3. **View** real-time DNS queries:
   - Timestamp
   - Client IP
   - Domain queried
   - Status (Allowed/Blocked)
   - Response time

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod -l app=pihole

# Common issues:
# - ImagePullBackOff: Check internet connectivity
# - CrashLoopBackOff: Check logs for error messages
# - Pending: Check if PVC is bound

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep pihole
```

### Web Interface Not Accessible

```bash
# Verify service is running
kubectl get svc pihole-web

# Test from another pod
kubectl run -it --rm curl-test --image=curlimages/curl --restart=Never -- curl -I http://pihole-web:80

# Expected: HTTP/1.1 200 OK or 301 Moved Permanently

# Check NodePort is accessible
curl -I http://192.168.4.101:30001

# If unreachable, check firewall rules or Eero network settings
```

### DNS Not Resolving

```bash
# Check DNS service
kubectl get svc pihole-dns

# Test DNS from within cluster
kubectl run -it --rm dns-test --image=nicolaka/netshoot --restart=Never -- nslookup google.com pihole-dns

# Check Pi-hole logs for DNS errors
kubectl logs -l app=pihole | grep -i error
```

### Configuration Not Persisting

```bash
# Verify PVC is bound
kubectl get pvc pihole-config

# Check PV details
kubectl get pv

# If PVC is lost, data may not persist
# Solution: Ensure local-path-provisioner is running
kubectl get pods -n kube-system | grep local-path
```

---

## Next Steps

### ✅ Phase 1 Complete: MVP Deployment

You now have a functional Pi-hole DNS ad blocker running on your K3s cluster!

### 🚀 Optional Enhancements (P2/P3):

1. **Prometheus Integration** (P3):
   - Deploy `eko/pihole-exporter` sidecar
   - Add Grafana dashboard for Pi-hole metrics
   - Monitor DNS query performance and blocking effectiveness

2. **High Availability** (Future):
   - Deploy second Pi-hole replica
   - Use MetalLB LoadBalancer with dedicated IP
   - Configure devices with both Pi-hole IPs for failover

3. **Automatic Device Configuration**:
   - Configure Eero router to use Pi-hole as primary DNS (if supported)
   - All devices automatically use Pi-hole without manual configuration

---

## Rollback

If you need to remove Pi-hole:

```bash
# Destroy Pi-hole resources
cd terraform/environments/chocolandiadc-mvp
tofu destroy -target=module.pihole

# Confirm with 'yes'

# Verify removal
kubectl get pods -l app=pihole
# Expected: No resources found

# Reconfigure device DNS to Eero defaults (automatic DHCP)
```

---

## Summary

**Deployed Resources**:
- ✅ Pi-hole Deployment (1 pod, 512Mi memory, 500m CPU)
- ✅ DNS Service (ClusterIP on port 53 TCP+UDP)
- ✅ Web Admin Service (NodePort 30001)
- ✅ PersistentVolumeClaim (2Gi for configuration)
- ✅ Kubernetes Secret (admin password)

**Access Points**:
- 🌐 Web UI: `http://192.168.4.101:30001` or `http://192.168.4.102:30001`
- 🔒 Admin Password: (saved from Step 2)
- 📊 Dashboard: Login → Dashboard (query statistics, blocking percentage, top domains)

**Next**: Configure devices to use Pi-hole DNS (Step 7) and enjoy ad-free browsing! 🎉
