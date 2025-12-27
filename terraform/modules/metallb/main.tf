# ============================================================================
# MetalLB Load Balancer Module
# ============================================================================
# This module deploys MetalLB via Helm chart for bare-metal LoadBalancer
# services in K3s cluster.
# ============================================================================

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# MetalLB Helm Release
resource "helm_release" "metallb" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = true
  wait             = true
  timeout          = 300

  # Disable speaker if using L2 only mode (our case)
  set {
    name  = "speaker.frr.enabled"
    value = "false"
  }
}

# Wait for MetalLB CRDs to be ready
resource "null_resource" "wait_for_crds" {
  depends_on = [helm_release.metallb]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for MetalLB CRDs to be ready..."
      for i in {1..30}; do
        if kubectl get crd ipaddresspools.metallb.io >/dev/null 2>&1; then
          echo "CRDs are ready"
          exit 0
        fi
        echo "Waiting for CRDs... attempt $i/30"
        sleep 2
      done
      echo "Timeout waiting for CRDs"
      exit 1
    EOT
  }
}

# IPAddressPool for LoadBalancer IPs
resource "null_resource" "ip_address_pool" {
  depends_on = [null_resource.wait_for_crds]

  triggers = {
    pool_name = var.pool_name
    ip_range  = var.ip_range
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ${var.pool_name}
  namespace: ${var.namespace}
spec:
  addresses:
    - ${var.ip_range}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: ${var.pool_name}-l2
  namespace: ${var.namespace}
spec:
  ipAddressPools:
    - ${var.pool_name}
EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl delete ipaddresspool ${self.triggers.pool_name} -n metallb-system --ignore-not-found=true
      kubectl delete l2advertisement ${self.triggers.pool_name}-l2 -n metallb-system --ignore-not-found=true
    EOT
  }
}
