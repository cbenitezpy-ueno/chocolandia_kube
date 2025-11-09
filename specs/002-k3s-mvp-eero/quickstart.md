# Quickstart Guide: K3s MVP - 2-Node Cluster on Eero Network

**Feature**: 002-k3s-mvp-eero
**Date**: 2025-11-09
**Estimated Time**: < 10 minutes (cluster bootstrap to workload running)

## Overview

This quickstart guide walks you through deploying a minimal viable K3s cluster with 2 nodes (1 control-plane + 1 worker) connected to your Eero mesh network. This is a learning environment designed to unblock Kubernetes experimentation while FortiGate 100D is being repaired.

**What you'll deploy**:
- **master1**: K3s control-plane node (single-server mode, SQLite datastore)
- **nodo1**: K3s worker node (agent mode)
- Test workload: nginx pod to verify cluster functionality

**What you'll learn**:
- K3s installation and cluster bootstrapping
- Kubectl basics (viewing nodes, deploying pods)
- Troubleshooting cluster connectivity issues

---

## Prerequisites

Before starting, ensure you have:

### Hardware
- [ ] 2 mini-PCs (Lenovo or HP ProDesk) available and powered on
- [ ] Both mini-PCs connected to Eero mesh network via **Ethernet** (strongly recommended) or WiFi
- [ ] Ubuntu Server 22.04 LTS installed on both mini-PCs
- [ ] Static DHCP reservations configured in Eero app (recommended to prevent IP changes)

**Eero Configuration** (recommended):
1. Open Eero app → Settings → Advanced → DHCP & NAT → Reservations
2. Add static reservations:
   - `master1` (MAC: aa:bb:cc:dd:ee:ff) → `192.168.4.10`
   - `nodo1` (MAC: ff:ee:dd:cc:bb:aa) → `192.168.4.11`

### Software on Mini-PCs
- [ ] SSH server running on both nodes (`sudo systemctl status ssh`)
- [ ] Passwordless SSH configured (SSH keys copied to both nodes)
- [ ] Sudo privileges for SSH user (required for K3s installation)
- [ ] Internet connectivity via Eero (test: `ping 8.8.8.8`)

### Software on Operator Laptop
- [ ] OpenTofu 1.6+ installed (`tofu version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] SSH client available
- [ ] Git configured with access to this repository

**Verify Prerequisites**:
```bash
# Test SSH access to both nodes (replace IPs with your actual IPs)
ssh ubuntu@192.168.4.10 "hostname && whoami"  # Should return: master1, ubuntu
ssh ubuntu@192.168.4.11 "hostname && whoami"  # Should return: nodo1, ubuntu

# Verify OpenTofu and kubectl
tofu version  # Should show: OpenTofu v1.6.x
kubectl version --client  # Should show: Client Version v1.28+
```

---

## Step 1: Bootstrap Control-Plane Node (master1)

**Objective**: Install K3s server on master1, verify API server is running, retrieve cluster token for worker join.

### 1.1 SSH to master1

```bash
ssh ubuntu@192.168.4.10
```

### 1.2 Install K3s Server (Single-Server Mode)

Run the K3s installation script with single-server flags:

```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init=false \
  --disable traefik \
  --tls-san 192.168.4.10
```

**Flag explanations**:
- `--cluster-init=false`: Disables HA mode, uses SQLite datastore (not etcd)
- `--disable traefik`: Disables built-in Traefik ingress controller (saves resources)
- `--tls-san 192.168.4.10`: Adds master1 IP to API server TLS certificate (allows external kubectl access)

**Expected output**:
```
[INFO]  Finding release for channel stable
[INFO]  Using v1.28.5+k3s1 as release
[INFO]  Downloading hash https://github.com/k3s-io/k3s/releases/download/v1.28.5+k3s1/sha256sum-amd64.txt
[INFO]  Downloading binary https://github.com/k3s-io/k3s/releases/download/v1.28.5+k3s1/k3s
[INFO]  Verifying binary download
[INFO]  Installing k3s to /usr/local/bin/k3s
[INFO]  Skipping installation of SELinux RPM
[INFO]  Creating /usr/local/bin/kubectl symlink to k3s
[INFO]  Creating /usr/local/bin/crictl symlink to k3s
[INFO]  Creating /usr/local/bin/ctr symlink to k3s
[INFO]  Creating killall script /usr/local/bin/k3s-killall.sh
[INFO]  Creating uninstall script /usr/local/bin/k3s-uninstall.sh
[INFO]  env: Creating environment file /etc/systemd/system/k3s.service.env
[INFO]  systemd: Creating service file /etc/systemd/system/k3s.service
[INFO]  systemd: Enabling k3s unit
Created symlink /etc/systemd/system/multi-user.target.wants/k3s.service → /etc/systemd/system/k3s.service.
[INFO]  systemd: Starting k3s
```

Installation takes **2-3 minutes** (downloading K3s binary + container images).

### 1.3 Verify K3s Server is Running

```bash
# Check K3s service status
sudo systemctl status k3s

# Verify node is Ready (may take 30-60 seconds)
sudo k3s kubectl get nodes
```

**Expected output**:
```
NAME      STATUS   ROLES                  AGE   VERSION
master1   Ready    control-plane,master   45s   v1.28.5+k3s1
```

**Troubleshooting**:
- If service failed to start: `sudo journalctl -u k3s -f`
- If node is NotReady: Wait 60 seconds and retry (CNI initialization delay)
- If connection refused: Check firewall rules (`sudo ufw status`)

### 1.4 Retrieve Cluster Token

The cluster token is needed for worker nodes to join. Retrieve it:

```bash
sudo cat /var/lib/rancher/k3s/server/token
```

**Example token**:
```
K10abc123def456ghi789jkl012mno345pqr678stu901vwx234yza567::server:bcd890efg123hij456klm789nop012qrs
```

**Save this token**—you'll need it in Step 2.

### 1.5 Logout from master1

```bash
exit  # Return to operator laptop
```

---

## Step 2: Join Worker Node (nodo1)

**Objective**: Install K3s agent on nodo1, configure it to join the cluster, verify both nodes appear in `kubectl get nodes`.

### 2.1 SSH to nodo1

```bash
ssh ubuntu@192.168.4.11
```

### 2.2 Install K3s Agent (Join Cluster)

Run the K3s installation script with agent configuration:

```bash
# Replace <TOKEN> with the token from Step 1.4
# Replace 192.168.4.10 with your master1 IP if different

export K3S_URL=https://192.168.4.10:6443
export K3S_TOKEN="K10abc123def456ghi789jkl012mno345pqr678stu901vwx234yza567::server:bcd890efg123hij456klm789nop012qrs"

curl -sfL https://get.k3s.io | sh -s - agent \
  --node-label role=worker
```

**Environment variable explanations**:
- `K3S_URL`: Points to master1 API server (must be accessible from nodo1)
- `K3S_TOKEN`: Cluster join token from master1

**Agent flag explanations**:
- `--node-label role=worker`: Adds custom label to node (helps with pod scheduling)

**Expected output**:
```
[INFO]  Finding release for channel stable
[INFO]  Using v1.28.5+k3s1 as release
[INFO]  Downloading hash https://github.com/k3s-io/k3s/releases/download/v1.28.5+k3s1/sha256sum-amd64.txt
[INFO]  Downloading binary https://github.com/k3s-io/k3s/releases/download/v1.28.5+k3s1/k3s
[INFO]  Verifying binary download
[INFO]  Installing k3s to /usr/local/bin/k3s
[INFO]  Creating /usr/local/bin/kubectl symlink to k3s
[INFO]  Creating /usr/local/bin/crictl symlink to k3s
[INFO]  Creating /usr/local/bin/ctr symlink to k3s
[INFO]  Creating killall script /usr/local/bin/k3s-killall.sh
[INFO]  Creating uninstall script /usr/local/bin/k3s-agent-uninstall.sh
[INFO]  env: Creating environment file /etc/systemd/system/k3s-agent.service.env
[INFO]  systemd: Creating service file /etc/systemd/system/k3s-agent.service
[INFO]  systemd: Enabling k3s-agent unit
Created symlink /etc/systemd/system/multi-user.target.wants/k3s-agent.service → /etc/systemd/system/k3s-agent.service.
[INFO]  systemd: Starting k3s-agent
```

Installation takes **1-2 minutes**.

### 2.3 Verify K3s Agent is Running

```bash
# Check K3s agent service status
sudo systemctl status k3s-agent
```

**Expected output**:
```
● k3s-agent.service - Lightweight Kubernetes
     Loaded: loaded (/etc/systemd/system/k3s-agent.service; enabled; vendor preset: enabled)
     Active: active (running) since ...
```

**Troubleshooting**:
- If connection refused: Verify master1 is accessible (`ping 192.168.4.10`)
- If token invalid: Re-retrieve token from master1 (Step 1.4)
- If certificate errors: Verify `--tls-san` flag was used in Step 1.2

### 2.4 Logout from nodo1

```bash
exit  # Return to operator laptop
```

---

## Step 3: Verify Cluster from Operator Laptop

**Objective**: Configure kubectl on your laptop to access the cluster, verify both nodes are Ready, deploy a test workload.

### 3.1 Copy Kubeconfig from master1

```bash
# Copy kubeconfig from master1 to your laptop
scp ubuntu@192.168.4.10:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Modify kubeconfig to use master1's Eero IP (replace 127.0.0.1 with actual IP)
sed -i.bak 's/127.0.0.1/192.168.4.10/g' ~/.kube/config

# Verify kubeconfig is valid
kubectl config view
```

**Expected output** (truncated):
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1...
    server: https://192.168.4.10:6443  # Should be master1 IP, not 127.0.0.1
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
```

### 3.2 Verify Both Nodes are Ready

```bash
kubectl get nodes -o wide
```

**Expected output**:
```
NAME      STATUS   ROLES                  AGE     VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
master1   Ready    control-plane,master   5m30s   v1.28.5+k3s1   192.168.4.10    <none>        Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.11-k3s2
nodo1     Ready    <none>                 3m15s   v1.28.5+k3s1   192.168.4.11    <none>        Ubuntu 22.04.3 LTS   5.15.0-91-generic   containerd://1.7.11-k3s2
```

**Success criteria**:
- Both nodes show `STATUS: Ready`
- `master1` has role `control-plane,master`
- `nodo1` has role `<none>` (worker node, no special role)
- Both nodes on same K3s version

**Troubleshooting**:
- If nodes NotReady: Check kubelet logs on nodes (`sudo journalctl -u k3s -f` or `sudo journalctl -u k3s-agent -f`)
- If connection refused from laptop: Verify kubeconfig server IP matches master1 Eero IP
- If certificate errors: Re-run Step 1.2 with `--tls-san` flag

### 3.3 Deploy Test Workload (nginx Pod)

Deploy a simple nginx pod to verify cluster functionality:

```bash
# Create nginx deployment
kubectl create deployment nginx --image=nginx:alpine

# Verify pod is Running
kubectl get pods -o wide
```

**Expected output** (after 30-60 seconds):
```
NAME                     READY   STATUS    RESTARTS   AGE   IP          NODE    NOMINATED NODE   READINESS GATES
nginx-7c6d8d8d8d-5x2z9   1/1     Running   0          45s   10.42.1.2   nodo1   <none>           <none>
```

**Success criteria**:
- Pod shows `STATUS: Running`
- Pod scheduled on `nodo1` (worker node)
- Pod has IP from pod CIDR (10.42.x.x)

**Troubleshooting**:
- If pod Pending: Check node resources (`kubectl describe node nodo1`)
- If pod ImagePullBackOff: Check internet connectivity on nodo1 (`ssh ubuntu@192.168.4.11 "ping 8.8.8.8"`)
- If pod CrashLoopBackOff: Check pod logs (`kubectl logs <pod-name>`)

### 3.4 Verify nginx is Accessible

```bash
# Expose nginx via NodePort (accessible from Eero network)
kubectl expose deployment nginx --port=80 --type=NodePort

# Get NodePort assigned
kubectl get svc nginx
```

**Expected output**:
```
NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx   NodePort   10.43.123.45    <none>        80:30123/TCP   10s
```

Note the NodePort (e.g., `30123` in this example).

**Test access from laptop**:
```bash
# Access nginx via nodo1 IP + NodePort
curl http://192.168.4.11:30123

# Expected output: nginx welcome page HTML
```

**Expected output**:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**Cleanup test workload**:
```bash
kubectl delete deployment nginx
kubectl delete svc nginx
```

---

## Expected Timeline

| Step | Duration | Cumulative |
|------|----------|------------|
| Prerequisites verification | 2 min | 2 min |
| Step 1: Bootstrap master1 | 3 min | 5 min |
| Step 2: Join nodo1 | 2 min | 7 min |
| Step 3: Verify cluster + deploy test workload | 3 min | **10 min** |

**Total time to functional cluster with test workload**: < 10 minutes

---

## Troubleshooting Common Issues

### Issue 1: Nodes Show NotReady Status

**Symptoms**:
```
NAME      STATUS     ROLES                  AGE   VERSION
master1   NotReady   control-plane,master   2m    v1.28.5+k3s1
```

**Diagnosis**:
```bash
# Check K3s service logs
ssh ubuntu@192.168.4.10 "sudo journalctl -u k3s -n 50"

# Check kubelet logs
ssh ubuntu@192.168.4.10 "sudo journalctl -u k3s --since '5 minutes ago' | grep -i error"
```

**Common Causes**:
1. **CNI not initialized**: Wait 60 seconds and retry (`kubectl get nodes`)
2. **Firewall blocking traffic**: Disable UFW temporarily (`sudo ufw disable`) or allow ports:
   ```bash
   sudo ufw allow 6443/tcp  # API server
   sudo ufw allow 10250/tcp  # Kubelet
   sudo ufw allow 8472/udp  # Flannel VXLAN
   ```
3. **Eero network connectivity issue**: Verify IP connectivity between nodes (`ping 192.168.4.10` from nodo1)

**Resolution**: Address underlying issue, restart K3s service:
```bash
sudo systemctl restart k3s  # On master1
sudo systemctl restart k3s-agent  # On nodo1
```

---

### Issue 2: kubectl Connection Refused

**Symptoms**:
```
The connection to the server 192.168.4.10:6443 was refused - did you specify the right host or port?
```

**Diagnosis**:
```bash
# Verify kubeconfig server URL
kubectl config view | grep server

# Test API server connectivity
curl -k https://192.168.4.10:6443/version
```

**Common Causes**:
1. **Kubeconfig still has 127.0.0.1**: Re-run `sed -i 's/127.0.0.1/192.168.4.10/g' ~/.kube/config`
2. **Master1 API server not running**: Check `ssh ubuntu@192.168.4.10 "sudo systemctl status k3s"`
3. **Firewall blocking port 6443**: Allow API server port (see Issue 1)
4. **WiFi connectivity issue**: Master1 on WiFi may have intermittent connectivity; switch to Ethernet

**Resolution**: Fix kubeconfig, verify K3s service, check firewall rules.

---

### Issue 3: Worker Node Cannot Join Cluster

**Symptoms**:
```
[ERROR]  Failed to join cluster: Get "https://192.168.4.10:6443/version": dial tcp 192.168.4.10:6443: connect: connection refused
```

**Diagnosis**:
```bash
# From nodo1, test master1 API server connectivity
ssh ubuntu@192.168.4.11 "curl -k https://192.168.4.10:6443/version"
```

**Common Causes**:
1. **Master1 not reachable from nodo1**: Verify network connectivity (`ping 192.168.4.10` from nodo1)
2. **Incorrect K3S_URL**: Verify environment variable has correct IP
3. **Invalid cluster token**: Re-retrieve token from master1 (Step 1.4)
4. **TLS certificate issue**: Verify master1 was started with `--tls-san 192.168.4.10`

**Resolution**: Verify master1 is accessible, re-run agent installation with correct token and URL.

---

### Issue 4: Pods Stuck in Pending State

**Symptoms**:
```
NAME                     READY   STATUS    RESTARTS   AGE
nginx-7c6d8d8d8d-5x2z9   0/1     Pending   0          5m
```

**Diagnosis**:
```bash
# Check why pod is pending
kubectl describe pod <pod-name>

# Check node resources
kubectl describe node nodo1
```

**Common Causes**:
1. **No worker nodes available**: Only master1 present (nodo1 failed to join)
2. **Insufficient resources**: Worker node has insufficient CPU/memory
3. **Node taints**: Master node has NoSchedule taint (expected; workloads should go to nodo1)

**Resolution**:
- If nodo1 missing: Complete Step 2 to join worker node
- If resources exhausted: Check node capacity (`kubectl describe node nodo1`)
- If taints blocking: Workloads should schedule on nodo1 (not master1)

---

### Issue 5: Eero Network Connectivity Issues

**Symptoms**:
- Nodes intermittently NotReady
- Pod network unreachable from operator laptop
- Slow image pulls

**Diagnosis**:
```bash
# Check Eero connectivity from nodes
ssh ubuntu@192.168.4.10 "ping -c 5 8.8.8.8"
ssh ubuntu@192.168.4.11 "ping -c 5 8.8.8.8"

# Check inter-node connectivity
ssh ubuntu@192.168.4.10 "ping -c 5 192.168.4.11"
ssh ubuntu@192.168.4.11 "ping -c 5 192.168.4.10"
```

**Common Causes**:
1. **WiFi connection instability**: Nodes on WiFi experiencing packet loss
2. **Eero mesh handoff**: Node switching between Eero nodes (common with WiFi)
3. **DHCP IP change**: Node IP changed after reboot (no static DHCP reservation)

**Resolution**:
- **Short-term**: Switch nodes to Ethernet for stable connectivity
- **Long-term**: Configure static DHCP reservations in Eero app (see Prerequisites)

---

## Next Steps

Cluster is now operational. What's next:

1. **Explore Kubernetes Basics**:
   ```bash
   kubectl get all --all-namespaces  # View all resources
   kubectl run test --image=busybox --command -- sleep 3600  # Run test pod
   kubectl exec -it test -- sh  # Shell into pod
   ```

2. **Deploy Monitoring Stack** (User Story 2):
   - Install Prometheus + Grafana via Helm
   - Configure scrape targets for cluster nodes
   - Access Grafana dashboards for cluster health

3. **Review Migration Documentation** (User Story 3):
   - Read `docs/runbooks/migration-to-feature-001.md` (when created)
   - Understand steps to migrate to FortiGate VLAN architecture
   - Plan for HA control-plane deployment

4. **Experiment with Workloads**:
   - Deploy stateful applications (PostgreSQL, Redis)
   - Test PersistentVolumes (local-path provisioner)
   - Learn pod networking, services, ingress

---

## Cleanup (Cluster Teardown)

To remove the cluster and start fresh:

### On nodo1 (Worker Node)

```bash
ssh ubuntu@192.168.4.11
sudo /usr/local/bin/k3s-agent-uninstall.sh
exit
```

### On master1 (Control-Plane Node)

```bash
ssh ubuntu@192.168.4.10
sudo /usr/local/bin/k3s-uninstall.sh
exit
```

### On Operator Laptop

```bash
# Remove kubeconfig
rm ~/.kube/config
```

**Cleanup verification**:
```bash
# K3s binary should be removed
ssh ubuntu@192.168.4.10 "which k3s"  # Should return: command not found
ssh ubuntu@192.168.4.11 "which k3s"  # Should return: command not found
```

---

## Summary

You have successfully deployed a 2-node K3s cluster on Eero mesh network:

- **master1** (192.168.4.10): Control-plane node, single-server mode, SQLite datastore
- **nodo1** (192.168.4.11): Worker node for workload execution
- **kubectl access**: Configured from operator laptop
- **Test workload**: nginx pod deployed and verified

**Timeline**: Cluster bootstrap completed in < 10 minutes.

**Learning outcomes**:
- Understand K3s installation process (server vs agent)
- Configure kubectl for remote cluster access
- Deploy and troubleshoot basic Kubernetes workloads
- Diagnose common cluster connectivity issues

**Next steps**: Proceed to User Story 2 (monitoring deployment) or start experimenting with Kubernetes workloads.

For detailed migration planning, see `docs/runbooks/migration-to-feature-001.md` (to be created).
