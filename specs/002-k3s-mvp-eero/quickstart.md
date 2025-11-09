# Quickstart Guide: K3s MVP - 2-Node Cluster on Eero Network

**Feature**: 002-k3s-mvp-eero
**Date**: 2025-11-09
**Deployment Method**: OpenTofu (Infrastructure as Code)
**Estimated Time**: ~15 minutes (from prerequisites to working cluster with monitoring)

## Overview

This quickstart guide walks you through deploying a minimal viable K3s cluster with 2 nodes (1 control-plane + 1 worker) on your Eero mesh network using OpenTofu. This is a learning environment designed to unblock Kubernetes experimentation while FortiGate hardware is being repaired.

**What you'll deploy**:
- **master1** (192.168.4.101): K3s control-plane node (single-server mode, SQLite datastore)
- **nodo1** (192.168.4.102): K3s worker node (agent mode)
- **Monitoring Stack**: Prometheus + Grafana with 30 pre-configured dashboards
- **Test workload**: nginx deployment to verify cluster functionality

**What you'll learn**:
- Infrastructure as Code with OpenTofu
- K3s cluster deployment and management
- Kubernetes monitoring with Prometheus and Grafana
- Cluster validation and troubleshooting

---

## Prerequisites

### Hardware
- [ ] 2 mini-PCs (Lenovo or HP ProDesk) available and powered on
- [ ] Both mini-PCs connected to Eero mesh network via **Ethernet** (WiFi not recommended)
- [ ] Ubuntu Server 22.04 LTS installed on both mini-PCs
- [ ] Static DHCP reservations configured in Eero app

**Eero Configuration** (REQUIRED for stable cluster):
1. Open Eero app → Settings → Network Settings → Reservations & Port Forwarding
2. Add static DHCP reservations:
   - `master1` → `192.168.4.101`
   - `nodo1` → `192.168.4.102`

**Why required**: Without static reservations, DHCP IP changes will break cluster connectivity.

### Software on Mini-PCs
- [ ] SSH server running on both nodes (`sudo systemctl status ssh`)
- [ ] Passwordless SSH configured (SSH keys copied to both nodes)
- [ ] Passwordless sudo configured for SSH user
- [ ] Internet connectivity via Eero (test: `ping 8.8.8.8`)

### Software on Operator Laptop
- [ ] OpenTofu >= 1.6.0 installed (`tofu version`)
- [ ] kubectl >= 1.28 installed (`kubectl version --client`)
- [ ] Helm >= 3.12 installed (`helm version`)
- [ ] SSH client available
- [ ] Git configured with access to this repository

**Verify Prerequisites**:
```bash
# Test SSH access to both nodes
ssh chocolim@192.168.4.101 "hostname && whoami"  # Should return: master1, chocolim
ssh chocolim@192.168.4.102 "hostname && whoami"  # Should return: nodo1, chocolim

# Verify OpenTofu and kubectl
tofu version  # Should show: OpenTofu v1.6.x
kubectl version --client  # Should show: Client Version v1.28+
helm version  # Should show: version.BuildInfo{Version:"v3.12+"}
```

---

## Step 1: Configure SSH Access

Set up passwordless SSH authentication to both nodes:

```bash
# Generate SSH key for K3s cluster (if not already exists)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_k3s -N ""

# Copy public key to both nodes
ssh-copy-id -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101
ssh-copy-id -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102

# Test SSH access (should not prompt for password)
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 "hostname"
# Expected output: master1

ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102 "hostname"
# Expected output: nodo1
```

**Configure passwordless sudo on each node**:
```bash
# On master1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101
echo "chocolim ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/chocolim
sudo chmod 0440 /etc/sudoers.d/chocolim
exit

# On nodo1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102
echo "chocolim ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/chocolim
sudo chmod 0440 /etc/sudoers.d/chocolim
exit

# Test sudo access (should not prompt for password)
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 "sudo whoami"
# Expected output: root
```

---

## Step 2: Clone Repository and Configure

```bash
# Clone the repository
git clone https://github.com/cbenitezpy-ueno/chocolandia_kube.git
cd chocolandia_kube

# Switch to feature branch
git checkout 002-k3s-mvp-eero

# Navigate to environment directory
cd terraform/environments/chocolandiadc-mvp
```

**Create terraform.tfvars configuration**:
```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your actual values
vim terraform.tfvars
```

**terraform.tfvars content** (update with your values):
```hcl
cluster_name = "chocolandiadc-mvp"
k3s_version  = "v1.28.3+k3s1"

# Master node configuration
master1_hostname = "master1"
master1_ip       = "192.168.4.101"

# Worker node configuration
nodo1_hostname   = "nodo1"
nodo1_ip         = "192.168.4.102"

# SSH configuration
ssh_user             = "chocolim"
ssh_private_key_path = "~/.ssh/id_ed25519_k3s"
ssh_port             = 22

# K3s configuration
disable_components = ["traefik"]  # Disable Traefik ingress controller
k3s_additional_flags = []
```

---

## Step 3: Deploy Cluster with OpenTofu

```bash
# Ensure you're in the environment directory
cd terraform/environments/chocolandiadc-mvp

# Initialize OpenTofu (downloads providers)
tofu init

# Expected output:
# OpenTofu has been successfully initialized!
```

**Review deployment plan**:
```bash
tofu plan

# Review the plan output:
# - 2 null_resource for K3s installation (master1, nodo1)
# - 1 helm_release for kube-prometheus-stack
# - Kubeconfig generation
# - Expected: Plan: X to add, 0 to change, 0 to destroy
```

**Deploy the cluster**:
```bash
tofu apply

# Type 'yes' when prompted

# Expected output after ~5 minutes:
# Apply complete! Resources: X added, 0 changed, 0 destroyed.
#
# Outputs:
# cluster_endpoint = "https://192.168.4.101:6443"
# grafana_url = "http://192.168.4.101:30000"
# kubeconfig_path = "./kubeconfig"
# ...
```

**What OpenTofu does**:
1. SSHs to master1 and installs K3s server
2. Retrieves kubeconfig and cluster join token from master1
3. SSHs to nodo1 and installs K3s agent (joins cluster)
4. Deploys Prometheus + Grafana monitoring stack via Helm
5. Saves kubeconfig locally for kubectl access

---

## Step 4: Verify Cluster Deployment

**Export kubeconfig**:
```bash
export KUBECONFIG=$(pwd)/kubeconfig

# Verify environment variable
echo $KUBECONFIG
# Expected: /Users/.../chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig
```

**Check node status**:
```bash
kubectl get nodes -o wide

# Expected output:
# NAME      STATUS   ROLES                  AGE   VERSION        INTERNAL-IP      OS-IMAGE
# master1   Ready    control-plane,master   5m    v1.28.3+k3s1   192.168.4.101    Ubuntu 22.04 LTS
# nodo1     Ready    <none>                 3m    v1.28.3+k3s1   192.168.4.102    Ubuntu 22.04 LTS
```

**Check all pods**:
```bash
kubectl get pods -A

# Expected output: All pods in Running or Completed state
# Key namespaces to verify:
# - kube-system: coredns, metrics-server, local-path-provisioner
# - monitoring: prometheus, grafana, alertmanager, node-exporter
```

**Check monitoring stack**:
```bash
kubectl get pods -n monitoring

# Expected output (7 pods):
# NAME                                                   READY   STATUS
# alertmanager-kube-prometheus-stack-alertmanager-0      2/2     Running
# kube-prometheus-stack-grafana-XXXXX                   3/3     Running
# kube-prometheus-stack-kube-state-metrics-XXXXX        1/1     Running
# kube-prometheus-stack-operator-XXXXX                  1/1     Running
# kube-prometheus-stack-prometheus-node-exporter-XXX    1/1     Running  (on master1)
# kube-prometheus-stack-prometheus-node-exporter-XXX    1/1     Running  (on nodo1)
# prometheus-kube-prometheus-stack-prometheus-0          2/2     Running
```

---

## Step 5: Access Grafana

**Get Grafana admin password**:
```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo

# Copy the password output
```

**Access Grafana UI**:
1. Open browser: http://192.168.4.101:30000
2. Login with credentials:
   - **Username**: `admin`
   - **Password**: (from command above)
3. Navigate to Dashboards → Browse
4. Explore pre-configured dashboards:
   - **K3S cluster monitoring**: Overview of cluster health
   - **Node Exporter Full**: Detailed node metrics (CPU, memory, disk, network)
   - **Kubernetes Cluster Monitoring**: Pod and deployment metrics

**Expected dashboards** (30 total):
- Kubernetes resource usage (compute, networking, persistent volumes)
- Prometheus and Alertmanager overviews
- Node exporter metrics
- CoreDNS performance

---

## Step 6: Deploy Test Workload

Run the included test script to deploy nginx:

```bash
cd terraform/environments/chocolandiadc-mvp

bash scripts/deploy-test-workload.sh $(pwd)/kubeconfig

# Expected output:
# [TIMESTAMP] Deploying test workload to chocolandiadc-mvp cluster
# [TIMESTAMP] Creating test-workload namespace...
# [TIMESTAMP] SUCCESS: Namespace test-workload created
# [TIMESTAMP] Deploying nginx (2 replicas)...
# [TIMESTAMP] SUCCESS: nginx deployment created
# [TIMESTAMP] Waiting for pods to be Ready (timeout: 120s)...
# [TIMESTAMP] SUCCESS: All nginx pods are Ready (2/2)
# [TIMESTAMP] Creating LoadBalancer service...
# [TIMESTAMP] SUCCESS: Service created
# [TIMESTAMP] Testing service connectivity...
# [TIMESTAMP] SUCCESS: Service is accessible (HTTP 200)
# [TIMESTAMP] =========================================
# [TIMESTAMP] SUCCESS: Test workload deployed
```

**Verify test workload manually**:
```bash
export KUBECONFIG=$(pwd)/kubeconfig

# Check nginx pods
kubectl get pods -n test-workload -o wide

# Expected output:
# NAME                     READY   STATUS    NODE
# nginx-XXXXX              1/1     Running   master1
# nginx-XXXXX              1/1     Running   nodo1

# Check service
kubectl get svc -n test-workload

# Get service ClusterIP and test
SERVICE_IP=$(kubectl get svc -n test-workload nginx-service -o jsonpath='{.spec.clusterIP}')
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s http://$SERVICE_IP

# Expected output: HTML from nginx welcome page
```

---

## Step 7: Run Integration Tests

Run Prometheus and Grafana integration tests:

```bash
cd /Users/cbenitez/chocolandia_kube

# Test Prometheus
bash tests/integration/test-prometheus.sh \
  $(pwd)/terraform/environments/chocolandiadc-mvp/kubeconfig

# Expected output:
# SUCCESS: Prometheus integration test PASSED
# - 19 active scrape targets
# - Both nodes (master1, nodo1) being scraped
# - CPU and memory metrics queries working

# Test Grafana
bash tests/integration/test-grafana.sh \
  $(pwd)/terraform/environments/chocolandiadc-mvp/kubeconfig \
  192.168.4.101

# Expected output:
# SUCCESS: Grafana integration test PASSED
# - Grafana accessible via NodePort 30000 (HTTP 200)
# - API health: database OK
# - 30 dashboards available
```

---

## Step 8: Explore the Cluster

Now that your cluster is running, try these commands:

```bash
export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig

# List all namespaces
kubectl get namespaces

# View cluster info
kubectl cluster-info

# Check resource usage
kubectl top nodes
kubectl top pods -A

# View events (useful for troubleshooting)
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Access Prometheus UI (port-forward)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open browser: http://localhost:9090
# Try query: up{job="kubernetes-nodes"}

# View K3s logs on master1 (via SSH)
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 \
  "sudo journalctl -u k3s -n 50 --no-pager"
```

---

## Troubleshooting

### Issue: Nodes Not Ready

**Check node status**:
```bash
kubectl get nodes
kubectl describe node master1
kubectl describe node nodo1
```

**Check K3s service status**:
```bash
# On master1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 \
  "sudo systemctl status k3s"

# On nodo1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102 \
  "sudo systemctl status k3s-agent"
```

**Restart K3s if needed**:
```bash
# On master1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 \
  "sudo systemctl restart k3s"

# On nodo1
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.102 \
  "sudo systemctl restart k3s-agent"
```

### Issue: Grafana Not Accessible

**Check Grafana pod status**:
```bash
kubectl get pods -n monitoring | grep grafana
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana
```

**Verify service**:
```bash
kubectl get svc -n monitoring kube-prometheus-stack-grafana

# Should show TYPE: NodePort, PORT(S): 80:30000/TCP
```

**Test from node itself**:
```bash
ssh -i ~/.ssh/id_ed25519_k3s chocolim@192.168.4.101 \
  "curl -s http://localhost:30000/api/health | jq"

# Expected: {"database": "ok"}
```

### Issue: IP Address Changed

If node IPs change (DHCP lease expired):

1. Update Eero DHCP reservations to correct IPs
2. Reboot nodes to get reserved IPs
3. Update terraform.tfvars with new IPs
4. Re-run `tofu apply`

See `docs/runbooks/troubleshooting-eero-network.md` for detailed troubleshooting.

---

## Backup and Recovery

**Create backups before making changes**:

```bash
cd terraform/environments/chocolandiadc-mvp

# Backup OpenTofu state and cluster token
bash scripts/backup-state.sh

# Backup complete cluster (SQLite DB, manifests, PV data)
bash scripts/backup-cluster.sh

# Backups stored in: backups/
# - backups/terraform-state-TIMESTAMP.tar.gz
# - backups/cluster-token-TIMESTAMP.txt
# - backups/kubeconfig-TIMESTAMP.yaml
# - backups/k3s-state-db-TIMESTAMP.db
# - backups/manifests-TIMESTAMP/
# - backups/grafana-TIMESTAMP/
```

---

## Cleanup

To destroy the cluster (when migrating to Feature 001):

```bash
cd terraform/environments/chocolandiadc-mvp

# Create final backup first!
bash scripts/backup-state.sh
bash scripts/backup-cluster.sh

# Destroy all resources
tofu destroy

# Type 'yes' when prompted

# This will:
# - Uninstall K3s from both nodes
# - Remove kubeconfig file
# - Clean up all deployed resources
```

---

## Next Steps

Now that your cluster is running:

1. **Explore Grafana Dashboards**: http://192.168.4.101:30000
   - Review K3s cluster metrics
   - Monitor node resource usage
   - Explore pod and container metrics

2. **Deploy Custom Workloads**:
   ```bash
   kubectl create deployment my-app --image=nginx
   kubectl expose deployment my-app --port=80 --type=ClusterIP
   ```

3. **Learn Kubernetes Basics**:
   - Pods, Deployments, Services
   - ConfigMaps and Secrets
   - PersistentVolumes and PersistentVolumeClaims

4. **Plan Migration to Feature 001**:
   - Read: `docs/runbooks/migration-to-feature-001.md`
   - Understand HA architecture with FortiGate
   - Plan workload migration strategy

5. **Security Best Practices**:
   - Read: `docs/security-checklist.md`
   - Change Grafana admin password (IMPORTANT)
   - Review SSH key permissions
   - Never commit sensitive files to Git

---

## Additional Resources

- **Detailed README**: `/Users/cbenitez/chocolandia_kube/terraform/README.md`
- **Feature Specification**: `specs/002-k3s-mvp-eero/spec.md`
- **Architecture Design**: `specs/002-k3s-mvp-eero/architecture.md`
- **Migration Runbook**: `docs/runbooks/migration-to-feature-001.md`
- **Troubleshooting**: `docs/runbooks/troubleshooting-eero-network.md`
- **Security Checklist**: `docs/security-checklist.md`
- **K3s Documentation**: https://docs.k3s.io
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/

---

## Summary

✅ **What you accomplished**:
- Deployed 2-node K3s cluster using Infrastructure as Code (OpenTofu)
- Installed Prometheus + Grafana monitoring stack
- Verified cluster health with integration tests
- Deployed test workload to validate functionality
- Learned Kubernetes and K3s basics

🎉 **Your cluster is ready for learning and experimentation!**

**Cluster Details**:
- **API Endpoint**: https://192.168.4.101:6443
- **Grafana**: http://192.168.4.101:30000
- **Prometheus**: Port-forward to localhost:9090
- **Kubeconfig**: `terraform/environments/chocolandiadc-mvp/kubeconfig`

**Remember**: This is a **temporary MVP environment**. Migrate to Feature 001 (HA cluster with FortiGate) when hardware is available.

---

**Version**: 2.0 (OpenTofu Deployment)
**Last Updated**: 2025-11-09
**Status**: ✅ Fully Operational
