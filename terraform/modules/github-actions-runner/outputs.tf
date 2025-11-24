# GitHub Actions Runner Module - Outputs
# Feature 017: GitHub Actions Self-Hosted Runner
# T014: Runner status outputs
# T028: Scaling status outputs

# ==============================================================================
# Namespace Outputs
# ==============================================================================

output "namespace" {
  description = "Kubernetes namespace where runner resources are deployed"
  value       = kubernetes_namespace.github_actions.metadata[0].name
}

# ==============================================================================
# Controller Outputs
# ==============================================================================

output "controller_release_name" {
  description = "Helm release name for ARC controller"
  value       = helm_release.arc_controller.name
}

output "controller_version" {
  description = "ARC controller Helm chart version"
  value       = helm_release.arc_controller.version
}

output "controller_status" {
  description = "ARC controller deployment status"
  value       = helm_release.arc_controller.status
}

# ==============================================================================
# Runner Scale Set Outputs (T014)
# ==============================================================================

output "runner_release_name" {
  description = "Helm release name for runner scale set"
  value       = helm_release.arc_runner_scale_set.name
}

output "runner_version" {
  description = "Runner scale set Helm chart version"
  value       = helm_release.arc_runner_scale_set.version
}

output "runner_status" {
  description = "Runner scale set deployment status"
  value       = helm_release.arc_runner_scale_set.status
}

output "runner_name" {
  description = "Runner scale set name for workflow targeting"
  value       = var.runner_name
}

output "runner_labels" {
  description = "Labels assigned to runners (use in workflow runs-on)"
  value       = var.runner_labels
}

output "github_config_url" {
  description = "GitHub repository/organization URL configured for runners"
  value       = var.github_config_url
}

# ==============================================================================
# Scaling Outputs (T028)
# ==============================================================================

output "min_runners" {
  description = "Minimum number of runners configured"
  value       = var.min_runners
}

output "max_runners" {
  description = "Maximum number of runners configured"
  value       = var.max_runners
}

output "scaling_config" {
  description = "Complete scaling configuration summary"
  value = {
    min_runners    = var.min_runners
    max_runners    = var.max_runners
    cpu_request    = var.cpu_request
    cpu_limit      = var.cpu_limit
    memory_request = var.memory_request
    memory_limit   = var.memory_limit
  }
}

# ==============================================================================
# Monitoring Outputs
# ==============================================================================

output "monitoring_enabled" {
  description = "Whether Prometheus monitoring is enabled"
  value       = var.enable_monitoring
}

# ==============================================================================
# Connection Info
# ==============================================================================

output "workflow_usage" {
  description = "Example workflow configuration to use the runner"
  value       = <<-EOT
    # Use this in your GitHub Actions workflow:
    jobs:
      build:
        runs-on: [self-hosted, linux, x64, homelab]
        # OR use the runner name directly:
        # runs-on: ${var.runner_name}
  EOT
}
