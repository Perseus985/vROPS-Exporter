data "gitlab_repository_file" "app_of_apps" {
  project   = var.gitlab_argocd_project_id
  ref       = var.gitlab_argocd_project_ref
  file_path = var.argocd_app_of_apps_file
}

resource "gitlab_deploy_token" "argocd-deploy-token" {
  project  = var.gitlab_argocd_project_id
  name     = "argocd read registry token powered by Tofu"
  username = "argocd-${var.clustername}-user"
  scopes   = ["read_repository"]
}