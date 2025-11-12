# GitHub Repository Credentials Secret
# Feature 008: GitOps Continuous Deployment with ArgoCD
#
# Creates Kubernetes Secret for authenticating to private chocolandia_kube GitHub repository.
# ArgoCD uses this Secret to clone and fetch repository changes during sync operations.

resource "kubernetes_secret" "github_credentials" {
  metadata {
    name      = "chocolandia-kube-repo"
    namespace = var.argocd_namespace

    labels = {
      # ArgoCD-specific label for repository Secret discovery
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  # Secret data for GitHub authentication
  data = {
    # Repository type (git for standard Git repositories)
    type = "git"

    # GitHub repository URL (must match Application spec.source.repoURL)
    url = var.github_repo_url  # https://github.com/cbenitez/chocolandia_kube

    # GitHub username for authentication
    username = var.github_username  # cbenitez

    # GitHub Personal Access Token (PAT) with 'repo' scope
    # Token retrieved from terraform.tfvars (var.github_token)
    # IMPORTANT: Never commit this token to Git
    password = var.github_token  # Sensitive variable
  }

  # Ensure Secret is created after ArgoCD namespace exists
  depends_on = [
    helm_release.argocd
  ]
}
