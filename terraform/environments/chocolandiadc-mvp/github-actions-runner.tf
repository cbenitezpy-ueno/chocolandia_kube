# GitHub Actions Self-Hosted Runner
# Feature 017: GitHub Actions Self-Hosted Runner
#
# Deploys ARC (Actions Runner Controller) with runner scale set for executing
# GitHub Actions workflows on homelab infrastructure.
#
# Prerequisites:
# 1. Create GitHub App with required permissions (see quickstart.md)
# 2. Set environment variables:
#    - TF_VAR_github_app_id
#    - TF_VAR_github_app_installation_id
#    - TF_VAR_github_app_private_key (PEM format)

module "github_actions_runner" {
  source = "../../modules/github-actions-runner"

  # GitHub Configuration
  github_config_url          = var.github_actions_config_url
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key

  # Runner Configuration
  namespace     = "github-actions"
  runner_name   = "homelab-runner"
  runner_labels = ["self-hosted", "linux", "x64", "homelab"]

  # Scaling Configuration
  min_runners = 1
  max_runners = 4

  # Resource Limits (conservative for homelab)
  cpu_request    = "500m"
  memory_request = "1Gi"
  cpu_limit      = "2"
  memory_limit   = "4Gi"

  # ARC Versions
  arc_controller_version = "0.11.0"  # Upgraded from 0.9.3
  arc_runner_version     = "0.11.0"  # Upgraded from 0.9.3

  # Monitoring
  enable_monitoring = true
}

# ==============================================================================
# Outputs
# ==============================================================================

output "github_runner_namespace" {
  description = "Namespace where GitHub Actions runner is deployed"
  value       = module.github_actions_runner.namespace
}

output "github_runner_name" {
  description = "Runner scale set name for workflow targeting"
  value       = module.github_actions_runner.runner_name
}

output "github_runner_status" {
  description = "Runner scale set deployment status"
  value       = module.github_actions_runner.runner_status
}

output "github_runner_workflow_usage" {
  description = "Example workflow configuration"
  value       = module.github_actions_runner.workflow_usage
}

output "github_runner_scaling" {
  description = "Runner scaling configuration"
  value       = module.github_actions_runner.scaling_config
}
