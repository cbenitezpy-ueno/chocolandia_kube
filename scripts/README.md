# Setup Scripts - ChocolandiaDC K3s Cluster

Utility scripts for cluster setup and configuration.

## setup-ssh-passwordless.sh

Interactive script to configure SSH passwordless authentication for K3s nodes.

### What it does

1. **Generates SSH key pair** (ed25519) at `~/.ssh/id_ed25519_k3s`
2. **Copies public key** to master1 and nodo1 using `ssh-copy-id`
3. **Configures passwordless sudo** on both nodes
4. **Tests connectivity** to ensure SSH and sudo work correctly
5. **Updates SSH config** (optional) with aliases for easy access
6. **Creates terraform.tfvars** with your configuration

### Prerequisites

Before running this script, ensure:

- [ ] Both nodes (master1 and nodo1) are powered on and connected to Eero network
- [ ] You know the IP addresses of both nodes (check Eero app or router admin)
- [ ] You can SSH to both nodes with password (test with `ssh user@ip`)
- [ ] The user account exists on both nodes and can use `sudo`
- [ ] Your local machine can reach the nodes on the network

### Usage

```bash
cd /Users/cbenitez/chocolandia_kube/scripts
./setup-ssh-passwordless.sh
```

Follow the interactive prompts:

1. **SSH Key Generation**: Script will create a new key at `~/.ssh/id_ed25519_k3s`
2. **Enter SSH username**: Your username on the nodes (e.g., `cbenitez`, `ubuntu`)
3. **Enter node IPs**: IP addresses from your Eero network (e.g., `192.168.4.10`)
4. **Enter passwords**: You'll be prompted for SSH password twice (once per node)
5. **Enter sudo password**: Required to configure passwordless sudo (may be same as SSH password)

### Example Run

```
╔═══════════════════════════════════════════════════════════════╗
║  SSH Passwordless Setup for K3s Cluster                      ║
║  ChocolandiaDC MVP                                            ║
╚═══════════════════════════════════════════════════════════════╝

[10:30:15] Step 1: Generate SSH Key
Generating new SSH key at /Users/cbenitez/.ssh/id_ed25519_k3s...
✓ SSH key generated

[10:30:18] Step 2: Node Information
? Enter the username for SSH access (e.g., cbenitez, ubuntu):
cbenitez
? Enter master1 IP address (e.g., 192.168.4.10):
192.168.4.10
? Enter nodo1 IP address (e.g., 192.168.4.11):
192.168.4.11

[10:30:25] Configuration:
  SSH User:   cbenitez
  SSH Key:    /Users/cbenitez/.ssh/id_ed25519_k3s
  Master1 IP: 192.168.4.10
  Nodo1 IP:   192.168.4.11

Is this correct? (y/n): y

[10:30:30] Step 3: Copy SSH Key to Nodes
⚠ You will be prompted for the password for each node

[10:30:32] Copying SSH key to master1 (192.168.4.10)...
cbenitez@192.168.4.10's password: ********
✓ SSH key copied to master1

[10:30:40] Copying SSH key to nodo1 (192.168.4.11)...
cbenitez@192.168.4.11's password: ********
✓ SSH key copied to nodo1

[10:30:48] Step 4: Configure Passwordless Sudo
✓ Passwordless sudo configured on master1
✓ Passwordless sudo configured on nodo1

[10:31:00] Step 5: Test SSH Connectivity
✓ SSH and sudo working on master1
✓ SSH and sudo working on nodo1

[10:31:05] Step 6: SSH Config (Optional)
? Do you want to add SSH aliases to /Users/cbenitez/.ssh/config? (y/n): y
✓ SSH config updated

[10:31:10] Step 7: Create terraform.tfvars
✓ terraform.tfvars created

╔═══════════════════════════════════════════════════════════════╗
║  Setup Complete!                                              ║
╚═══════════════════════════════════════════════════════════════╝

✓ SSH passwordless authentication is configured

Summary:
  ✓ SSH key generated: /Users/cbenitez/.ssh/id_ed25519_k3s
  ✓ Public key copied to master1 and nodo1
  ✓ Passwordless sudo configured on both nodes
  ✓ SSH connectivity tested successfully
  ✓ terraform.tfvars created

Next Steps:

  1. Verify SSH access:
     ssh -i /Users/cbenitez/.ssh/id_ed25519_k3s cbenitez@192.168.4.10
     ssh -i /Users/cbenitez/.ssh/id_ed25519_k3s cbenitez@192.168.4.11

  2. Deploy the K3s cluster:
     cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp
     tofu plan
     tofu apply

  3. Access the cluster:
     export KUBECONFIG=/Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp/kubeconfig
     kubectl get nodes

Happy clustering! 🚀
```

### What Gets Created

1. **SSH Key Pair**:
   - Private: `~/.ssh/id_ed25519_k3s`
   - Public: `~/.ssh/id_ed25519_k3s.pub`

2. **On Each Node** (`/etc/sudoers.d/<username>`):
   ```
   <username> ALL=(ALL) NOPASSWD:ALL
   ```

3. **SSH Config** (optional, `~/.ssh/config`):
   ```
   Host master1
       HostName 192.168.4.10
       User cbenitez
       IdentityFile ~/.ssh/id_ed25519_k3s

   Host nodo1
       HostName 192.168.4.11
       User cbenitez
       IdentityFile ~/.ssh/id_ed25519_k3s
   ```

4. **Terraform Variables** (`terraform/environments/chocolandiadc-mvp/terraform.tfvars`):
   ```hcl
   cluster_name = "chocolandiadc-mvp"
   k3s_version  = "v1.28.3+k3s1"

   master1_ip = "192.168.4.10"
   nodo1_ip   = "192.168.4.11"

   ssh_user             = "cbenitez"
   ssh_private_key_path = "~/.ssh/id_ed25519_k3s"
   ```

### Troubleshooting

#### ssh-copy-id fails

**Error**: `Permission denied (publickey,password)`

**Solution**:
- Verify you can SSH with password: `ssh username@node_ip`
- Check that password authentication is enabled on the node:
  ```bash
  ssh username@node_ip
  cat /etc/ssh/sshd_config | grep PasswordAuthentication
  # Should show: PasswordAuthentication yes
  ```

#### Sudo configuration fails

**Error**: Permission issues when running sudo commands

**Solution**:
- Ensure your user can already use sudo (test: `ssh user@node "sudo whoami"`)
- If sudo requires password, you may need to run with NOPASSWD temporarily

#### SSH key already exists

If you already have `~/.ssh/id_ed25519_k3s`, the script will ask if you want to use it or create a new one at a different path.

### Manual Alternative

If the script doesn't work for your setup, you can configure SSH manually:

```bash
# 1. Generate key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_k3s -N ""

# 2. Copy to master1
ssh-copy-id -i ~/.ssh/id_ed25519_k3s.pub user@192.168.4.10

# 3. Copy to nodo1
ssh-copy-id -i ~/.ssh/id_ed25519_k3s.pub user@192.168.4.11

# 4. Configure passwordless sudo (on each node)
ssh user@192.168.4.10
echo "user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/user
sudo chmod 0440 /etc/sudoers.d/user
exit

# 5. Test
ssh -i ~/.ssh/id_ed25519_k3s user@192.168.4.10 "sudo whoami"
```

### After Setup

Once SSH is configured, you can deploy the cluster:

```bash
cd /Users/cbenitez/chocolandia_kube/terraform/environments/chocolandiadc-mvp
tofu plan    # Review what will be created
tofu apply   # Deploy the cluster
```
