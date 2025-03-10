module "argo_bootstrap" {
  source = "./modules/orca-argocd-bootstrap"

  vault_namespace           = var.vault_namespace
  vault_backend             = var.vault_backend
  vault_kv_engine_name      = var.vault_kv_engine_name
  argocd_url                = var.argocd_url
  argocd_project            = var.argocd_project
  argocd_helm_url           = var.argocd_helm_url
  argocd_helm_name          = var.argocd_helm_name
  argocd_app_of_apps_file   = var.argocd_app_of_apps_file
  gitlab_argocd_project_id  = var.gitlab_argocd_project_id
  gitlab_argocd_project_ref = var.gitlab_argocd_project_ref
  approle_namespaces        = var.approle_namespaces
  clustername               = var.clustername

}