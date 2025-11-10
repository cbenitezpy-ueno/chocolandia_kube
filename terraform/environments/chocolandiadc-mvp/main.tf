# ChocolandiaDC MVP - 2-Node K3s Cluster on Eero Network
# Deploys master1 (control-plane) + nodo1 (worker) using k3s-node module

# ============================================================================
# Master Node (Control-Plane) - Server Role
# ============================================================================

module "master1" {
  source = "../../modules/k3s-node"

  # Node identity
  hostname  = var.master1_hostname
  node_ip   = var.master1_ip
  node_role = "server"

  # SSH configuration
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_port             = var.ssh_port

  # K3s configuration
  k3s_version        = var.k3s_version
  disable_components = var.disable_components
  k3s_flags = concat(
    ["--write-kubeconfig-mode=644"],
    var.k3s_additional_flags
  )

  # TLS SAN for API server certificate
  tls_san = [
    var.master1_ip,
    var.master1_hostname,
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster.local"
  ]
}

# ============================================================================
# Worker Node - Agent Role
# ============================================================================

module "nodo1" {
  source = "../../modules/k3s-node"

  # Node identity
  hostname  = var.nodo1_hostname
  node_ip   = var.nodo1_ip
  node_role = "agent"

  # SSH configuration
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_port             = var.ssh_port

  # K3s configuration
  k3s_version = var.k3s_version

  # Cluster join configuration (from master1)
  server_url = module.master1.server_url
  join_token = module.master1.cluster_token

  # Ensure master1 is fully provisioned before starting nodo1
  depends_on = [module.master1]
}

# ============================================================================
# Kubeconfig Management
# ============================================================================

# Save kubeconfig to local file for kubectl access
resource "local_file" "kubeconfig" {
  content         = module.master1.kubeconfig_content
  filename        = "${path.module}/kubeconfig"
  file_permission = "0600"

  depends_on = [module.master1]
}

# ============================================================================
# Post-Deployment Validation
# ============================================================================

# Wait for both nodes to be Ready before completing
resource "null_resource" "wait_for_cluster_ready" {
  depends_on = [
    module.master1,
    module.nodo1,
    local_file.kubeconfig
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for cluster to be fully ready..."
      sleep 10

      export KUBECONFIG=${path.module}/kubeconfig

      # Wait for both nodes to appear
      echo "Checking for 2 nodes..."
      for i in {1..30}; do
        NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
        if [ "$NODE_COUNT" -eq "2" ]; then
          echo "✓ Found 2 nodes"
          break
        fi
        echo "  Waiting for nodes... (found $NODE_COUNT/2, attempt $i/30)"
        sleep 5
      done

      # Wait for nodes to be Ready
      echo "Waiting for nodes to be Ready..."
      kubectl wait --for=condition=Ready nodes --all --timeout=300s || true

      # Display final status
      echo ""
      echo "========================================="
      echo "Cluster Deployment Complete"
      echo "========================================="
      kubectl get nodes -o wide
      echo ""
      echo "To access the cluster, export the kubeconfig:"
      echo "  export KUBECONFIG=${path.module}/kubeconfig"
      echo ""
      echo "Validate cluster:"
      echo "  bash ${path.module}/scripts/validate-cluster.sh"
      echo ""
    EOT
  }
}

# ============================================================================
# Cloudflare Zero Trust Tunnel (Feature 004)
# ============================================================================

module "cloudflare_tunnel" {
  source = "../../modules/cloudflare-tunnel"

  # Cloudflare Configuration
  tunnel_name           = var.tunnel_name
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
  domain_name           = var.domain_name

  # Kubernetes Configuration
  namespace     = var.tunnel_namespace
  replica_count = var.replica_count

  # Ingress Rules
  ingress_rules = var.ingress_rules

  # Access Control
  google_oauth_client_id     = var.google_oauth_client_id
  google_oauth_client_secret = var.google_oauth_client_secret
  authorized_emails          = var.authorized_emails

  # Ensure cluster is ready before deploying tunnel
  depends_on = [
    null_resource.wait_for_cluster_ready
  ]
}
