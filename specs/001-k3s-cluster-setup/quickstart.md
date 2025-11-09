# Quick Start Guide: ChocolandiaDC K3s HA Cluster

**Feature**: 001-k3s-cluster-setup
**Date**: 2025-11-08
**Estimated Time**: 30-45 minutes (first-time setup)

## Overview

This guide walks you through deploying a 4-node K3s high-availability cluster named "chocolandiadc" using Terraform. By the end, you'll have:

- ✅ 3 control-plane nodes (master1, master2, master3) with embedded etcd in HA
- ✅ 1 worker node (nodo1) for application workloads
- ✅ Prometheus + Grafana monitoring stack
- ✅ kubectl access to your cluster

**Prerequisites Checklist**:

- [ ] 4 mini-PCs on the same local network
- [ ] Each mini-PC has: minimum 2 CPU cores, 4GB RAM, 20GB disk
- [ ] Linux OS installed on all mini-PCs (Ubuntu 22.04 LTS recommended)
- [ ] Static IP addresses or DHCP reservations configured
- [ ] SSH access enabled on all mini-PCs
- [ ] SSH keys configured for passwordless authentication
- [ ] OpenTofu 1.6+ installed on your control machine
- [ ] kubectl installed on your control machine

## Step 1: Prepare Your Mini-PCs (10 minutes)

### 1.1 Verify Network Connectivity

From your control machine, verify SSH access to all 4 mini-PCs:

```bash
# Test SSH access (replace with your actual IPs and SSH user)
ssh ubuntu@192.168.1.101 hostname  # Should print: master1
ssh ubuntu@192.168.1.102 hostname  # Should print: master2
ssh ubuntu@192.168.1.103 hostname  # Should print: master3
ssh ubuntu@192.168.1.104 hostname  # Should print: nodo1
```

**Troubleshooting**:
- If SSH fails: Verify IPs are correct, mini-PCs are powered on, SSH service is running
- If password required: Set up SSH keys (see "SSH Key Setup" section below)

### 1.2 Set Hostnames on Mini-PCs

```bash
# On each mini-PC, set the hostname
ssh ubuntu@192.168.1.101 sudo hostnamectl set-hostname master1
ssh ubuntu@192.168.1.102 sudo hostnamectl set-hostname master2
ssh ubuntu@192.168.1.103 sudo hostnamectl set-hostname master3
ssh ubuntu@192.168.1.104 sudo hostnamectl set-hostname nodo1
```

### 1.3 Verify System Requirements

```bash
# Run on each mini-PC to verify resources
for ip in 192.168.1.{101..104}; do
  echo "=== Checking $ip ==="
  ssh ubuntu@$ip 'echo "CPU: $(nproc) cores | RAM: $(free -h | grep Mem | awk "{print \$2}") | Disk: $(df -h / | tail -1 | awk "{print \$2}")"'
done
```

**Expected Output**:
```
=== Checking 192.168.1.101 ===
CPU: 4 cores | RAM: 8.0Gi | Disk: 30G
(Similar for other nodes)
```

**Minimum**: 2 CPU cores, 4GB RAM, 20GB disk per node

---

## Step 2: Clone Repository and Configure Terraform (5 minutes)

### 2.1 Navigate to Terraform Directory

```bash
cd chocolandia_kube/terraform/environments/chocolandiadc
```

### 2.2 Copy Example Configuration

```bash
# Copy the example tfvars file
cp terraform.tfvars.example terraform.tfvars
```

### 2.3 Edit Configuration

Open `terraform.tfvars` in your editor and update with your actual values:

```hcl
# terraform.tfvars - Update these values!

cluster_name = "chocolandiadc"
k3s_version  = "v1.28.3+k3s1"  # Latest stable K3s version

control_plane_nodes = [
  {
    hostname     = "master1"
    ip_address   = "192.168.1.101"  # ⚠️  REPLACE WITH YOUR ACTUAL IP
    ssh_user     = "ubuntu"          # ⚠️  REPLACE WITH YOUR SSH USER
    ssh_key_path = "~/.ssh/id_rsa"   # ⚠️  REPLACE IF USING DIFFERENT KEY
  },
  {
    hostname     = "master2"
    ip_address   = "192.168.1.102"  # ⚠️  REPLACE WITH YOUR ACTUAL IP
    ssh_user     = "ubuntu"
    ssh_key_path = "~/.ssh/id_rsa"
  },
  {
    hostname     = "master3"
    ip_address   = "192.168.1.103"  # ⚠️  REPLACE WITH YOUR ACTUAL IP
    ssh_user     = "ubuntu"
    ssh_key_path = "~/.ssh/id_rsa"
  }
]

worker_nodes = [
  {
    hostname     = "nodo1"
    ip_address   = "192.168.1.104"  # ⚠️  REPLACE WITH YOUR ACTUAL IP
    ssh_user     = "ubuntu"
    ssh_key_path = "~/.ssh/id_rsa"
  }
]

monitoring_namespace    = "monitoring"
prometheus_retention    = "15d"
prometheus_storage_size = "10Gi"
grafana_admin_user      = "admin"
```

**Save and close the file.**

---

## Step 3: Initialize Terraform (2 minutes)

```bash
# Initialize Terraform (downloads providers)
terraform init
```

**Expected Output**:
```
Initializing the backend...
Initializing provider plugins...
...
Terraform has been successfully initialized!
```

**Troubleshooting**:
- If provider download fails: Check internet connectivity, retry `terraform init`
- If backend errors: Verify you're in the correct directory (`terraform/environments/chocolandiadc`)

---

## Step 4: Validate Configuration (2 minutes)

```bash
# Format Terraform files
terraform fmt

# Validate configuration
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

---

## Step 5: Preview Changes (2 minutes)

```bash
# Generate execution plan
terraform plan -out=tfplan
```

**Expected Output**:
```
Terraform will perform the following actions:
  # null_resource.master1_install will be created
  # null_resource.master2_install will be created
  ...
Plan: 15 to add, 0 to change, 0 to destroy.
```

**Review the plan carefully.** Verify:
- ✅ 3 control-plane nodes (master1-3) will be created
- ✅ 1 worker node (nodo1) will be created
- ✅ Monitoring stack (Prometheus/Grafana) will be deployed
- ✅ No unexpected resources will be modified or destroyed

---

## Step 6: Deploy Cluster (15-20 minutes)

```bash
# Apply the Terraform plan
terraform apply tfplan
```

**What happens during apply**:

1. **Phase 1** (5 min): Master1 bootstrap
   - K3s installed on master1 with `--cluster-init`
   - Cluster token retrieved from master1
   - Kubeconfig retrieved and saved locally

2. **Phase 2** (5 min): Additional control-plane nodes
   - Master2 and master3 join cluster as control-plane nodes
   - Etcd quorum established (3/3 members)

3. **Phase 3** (3 min): Worker node
   - Nodo1 joins cluster as worker node

4. **Phase 4** (5 min): Monitoring stack
   - Prometheus and Grafana deployed via Helm
   - Dashboards configured

**Expected Final Output**:
```
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

api_endpoint = "https://192.168.1.101:6443"
cluster_name = "chocolandiadc"
grafana_admin_password = <sensitive>
grafana_url = "http://10.43.xxx.xxx:80"
kubeconfig_path = "/path/to/kubeconfig"
prometheus_url = "http://10.43.xxx.xxx:9090"
```

**Troubleshooting**:
- If SSH connection fails: Verify IP addresses, SSH keys, and network connectivity
- If K3s installation hangs: SSH into the node manually and check `/var/log/syslog` for errors
- If Helm deployment fails: Check internet connectivity for pulling Docker images

---

## Step 7: Verify Cluster (5 minutes)

### 7.1 Configure kubectl

```bash
# Copy kubeconfig to default location
cp $(terraform output -raw kubeconfig_path) ~/.kube/config

# Or merge with existing kubeconfig
export KUBECONFIG=~/.kube/config:$(terraform output -raw kubeconfig_path)
kubectl config use-context chocolandiadc
```

### 7.2 Check Nodes

```bash
# Verify all 4 nodes are Ready
kubectl get nodes
```

**Expected Output**:
```
NAME      STATUS   ROLES                  AGE   VERSION
master1   Ready    control-plane,master   15m   v1.28.3+k3s1
master2   Ready    control-plane,master   10m   v1.28.3+k3s1
master3   Ready    control-plane,master   10m   v1.28.3+k3s1
nodo1     Ready    <none>                 5m    v1.28.3+k3s1
```

✅ **All nodes should be "Ready"**

### 7.3 Check System Pods

```bash
# Verify all system pods are Running
kubectl get pods -A
```

**Expected Output**:
```
NAMESPACE     NAME                                        READY   STATUS    RESTARTS   AGE
kube-system   coredns-xxx                                 1/1     Running   0          15m
kube-system   local-path-provisioner-xxx                  1/1     Running   0          15m
kube-system   metrics-server-xxx                          1/1     Running   0          15m
kube-system   svclb-traefik-xxx                           2/2     Running   0          10m
kube-system   traefik-xxx                                 1/1     Running   0          10m
monitoring    prometheus-kube-prometheus-stack-xxx        2/2     Running   0          5m
monitoring    grafana-xxx                                 3/3     Running   0          5m
...
```

✅ **All pods should be "Running"**

### 7.4 Verify Etcd Quorum

```bash
# Check etcd member list (from master1)
ssh ubuntu@192.168.1.101 sudo k3s kubectl get endpoints -n kube-system
```

**Expected**: 3 etcd endpoints (master1, master2, master3)

---

## Step 8: Access Monitoring (5 minutes)

### 8.1 Get Grafana Admin Password

```bash
# Retrieve Grafana password from Terraform output
terraform output -raw grafana_admin_password
```

**Save this password** - you'll need it to log into Grafana.

### 8.2 Access Prometheus

```bash
# Port-forward Prometheus to localhost
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Open browser: http://localhost:9090

**Verify**: Prometheus UI loads, Status → Targets shows all targets "UP"

### 8.3 Access Grafana

```bash
# Port-forward Grafana to localhost
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open browser: http://localhost:3000

**Login**:
- Username: `admin`
- Password: (from Step 8.1)

**Verify**: Dashboards → Browse → Kubernetes cluster overview dashboard shows metrics

---

## Step 9: Test HA Failover (Optional, 5 minutes)

**Warning**: This test simulates node failure. Only proceed if comfortable with testing.

### 9.1 Baseline Check

```bash
# Verify all nodes Ready
kubectl get nodes
```

### 9.2 Simulate master1 Failure

```bash
# Shutdown master1
ssh ubuntu@192.168.1.101 sudo shutdown -h now
```

### 9.3 Verify API Still Accessible

```bash
# Wait 30 seconds, then check nodes
sleep 30
kubectl get nodes
```

**Expected**:
```
NAME      STATUS     ROLES                  AGE   VERSION
master1   NotReady   control-plane,master   20m   v1.28.3+k3s1
master2   Ready      control-plane,master   15m   v1.28.3+k3s1
master3   Ready      control-plane,master   15m   v1.28.3+k3s1
nodo1     Ready      <none>                 10m   v1.28.3+k3s1
```

✅ **kubectl still works** (API served by master2/master3)
✅ **master1 shows NotReady** (expected - node is offline)
✅ **Other nodes remain Ready**

### 9.4 Restore master1

```bash
# Power on master1 (method varies by hardware)
# Wait for boot (~2 minutes)

# Verify master1 rejoins
kubectl get nodes
```

**Expected**: All nodes Ready after master1 boots

✅ **HA verified** - cluster survived single control-plane node failure

---

## Step 10: Deploy Test Workload (2 minutes)

```bash
# Deploy nginx test pod
kubectl run nginx --image=nginx --port=80

# Wait for pod to be Ready
kubectl wait --for=condition=Ready pod/nginx --timeout=60s

# Verify pod is Running
kubectl get pods
```

**Expected**:
```
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          30s
```

```bash
# Test connectivity
kubectl exec nginx -- curl -s localhost
```

**Expected**: HTML output from nginx

```bash
# Clean up test pod
kubectl delete pod nginx
```

---

## Success Criteria Checklist

Verify your deployment meets all success criteria:

- [ ] **SC-001**: Cluster bootstrap completed in < 15 minutes ⏱️
- [ ] **SC-002**: All 4 nodes show "Ready" status
- [ ] **SC-003**: kubectl commands respond in < 2 seconds after master1 shutdown (HA test)
- [ ] **SC-004**: Prometheus targets page shows 100% availability
- [ ] **SC-005**: Grafana dashboards load in < 3 seconds
- [ ] **SC-006**: Nginx test pod reached Running state in < 60 seconds
- [ ] **SC-007**: Cluster survived master1 shutdown without service interruption
- [ ] **SC-008**: `terraform plan` shows no drift (no changes needed)
- [ ] **SC-009**: kubectl access works without manual configuration
- [ ] **SC-012**: Monitoring alerts configured (check Prometheus → Alerts)

---

## Next Steps

### Explore Your Cluster

```bash
# View all resources across all namespaces
kubectl get all -A

# Explore Prometheus metrics
# Port-forward and visit http://localhost:9090/graph
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Explore Grafana dashboards
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

### Add Worker Nodes (Optional)

To expand the cluster with nodo2 and nodo3:

1. Edit `terraform.tfvars` and add nodo2, nodo3 to `worker_nodes` list
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to add nodes
4. Verify with `kubectl get nodes`

### Learn More

- **Architecture Decisions**: Read `/docs/adrs/*.md`
- **Operational Runbooks**: See `/docs/runbooks/*.md`
- **Troubleshooting**: Refer to `/docs/runbooks/troubleshooting.md`
- **K3s Documentation**: https://docs.k3s.io/
- **Terraform Docs**: https://developer.hashicorp.com/terraform

---

## Teardown (Cleanup)

**Warning**: This destroys the entire cluster. All data will be lost.

```bash
# Destroy all Terraform-managed resources
cd terraform/environments/chocolandiadc
terraform destroy

# Confirm with 'yes' when prompted
```

**Expected**: All resources deleted, mini-PCs return to pre-cluster state (K3s uninstalled).

To fully clean up mini-PCs:

```bash
# SSH into each node and remove K3s
for ip in 192.168.1.{101..104}; do
  ssh ubuntu@$ip sudo /usr/local/bin/k3s-uninstall.sh || true
  ssh ubuntu@$ip sudo /usr/local/bin/k3s-agent-uninstall.sh || true
done
```

---

## Troubleshooting

### SSH Key Setup (if needed)

```bash
# Generate SSH key pair (if you don't have one)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy public key to all mini-PCs
for ip in 192.168.1.{101..104}; do
  ssh-copy-id ubuntu@$ip
done

# Test passwordless SSH
ssh ubuntu@192.168.1.101 hostname
```

### Common Issues

**Issue**: `terraform apply` fails with "connection timeout"
- **Solution**: Verify IP addresses, check mini-PCs are powered on, verify SSH port 22 is open

**Issue**: Nodes show "NotReady" after installation
- **Solution**: SSH into node, check K3s service status: `sudo systemctl status k3s` (or `k3s-agent`)
- **Logs**: `sudo journalctl -u k3s -f` (or `k3s-agent`)

**Issue**: Prometheus/Grafana pods stuck in "Pending"
- **Solution**: Check disk space on nodes: `df -h`
- **Check events**: `kubectl describe pod <pod-name> -n monitoring`

**Issue**: kubectl connection refused
- **Solution**: Verify kubeconfig path is correct, check master1 API is accessible: `curl -k https://192.168.1.101:6443`

For more troubleshooting, see `/docs/runbooks/troubleshooting.md`

---

## Summary

🎉 **Congratulations!** You've successfully deployed a production-grade K3s HA cluster:

- ✅ 4-node cluster (3 control-plane + 1 worker)
- ✅ High availability (survives single node failure)
- ✅ Prometheus + Grafana monitoring
- ✅ Fully automated via Terraform
- ✅ kubectl access configured

**What you learned**:
- K3s HA architecture with embedded etcd
- Terraform Infrastructure as Code
- Kubernetes cluster management with kubectl
- Cloud-native monitoring with Prometheus/Grafana
- High availability testing and validation

**Next**: Explore runbooks, deploy applications, experiment with cluster operations! 🚀
