resource "vault_policy" "approle_policies" {
  name   = "cluster-${var.clustername}"
  policy = <<EOT
path "orca-secrets/data/global/*" {
  capabilities = [ "read" ]
}

path "orca-secrets/data/${var.clustername}/global/*" {
  capabilities = [ "read" ]
}

path "orca-secrets/data/${var.clustername}/monitoring/*" {
  capabilities = [ "read" ]
}
EOT
}

resource "vault_approle_auth_backend_role" "cluster-secret-read" {
  backend        = var.vault_backend
  role_name      = "cluster-${var.clustername}-secret-read"
  token_policies = ["cluster-${var.clustername}"]
  depends_on = [
    vault_policy.approle_policies
  ]
}

resource "vault_approle_auth_backend_role_secret_id" "id" {
  backend   = var.vault_backend
  role_name = vault_approle_auth_backend_role.cluster-secret-read.role_name
}

resource "vault_kv_secret_v2" "secret" {
  mount = var.vault_kv_engine_name
  name  = "${var.clustername}/global/psa-gitlab-credential"
  data_json = jsonencode(
    {
      username = gitlab_deploy_token.argocd-deploy-token.username,
      password = gitlab_deploy_token.argocd-deploy-token.token
    }
  )
  depends_on = [
    gitlab_deploy_token.argocd-deploy-token
  ]
}