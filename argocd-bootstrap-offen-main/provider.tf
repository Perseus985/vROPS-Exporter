terraform {
  required_version = ">=1.9.0"
  # using GitLab http backend
  backend "http" {
    # auto-configured by the template
  }
}

provider "kubernetes" {
  config_path    = var.kube_config
  config_context = var.clustername
  insecure       = false
}

provider "gitlab" {
  base_url = var.gitlab_base_url
  token    = var.gitlab_token
  insecure = false
}

provider "vault" {
  address         = var.vault_address
  skip_tls_verify = false
  namespace       = var.vault_namespace
  auth_login {
    path = format("auth/ldap/login/%s", var.vault_username)
    parameters = {
      username = var.vault_username
      password = var.vault_password
    }
  }
}