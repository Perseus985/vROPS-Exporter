resource "kubernetes_secret" "approle" {
  for_each = toset(var.approle_namespaces)
  metadata {
    name      = "orca-vault-approle"
    namespace = each.key
  }

  data = {
    role_id   = vault_approle_auth_backend_role.cluster-secret-read.role_id
    secret_id = vault_approle_auth_backend_role_secret_id.id.secret_id
  }

  type = "Opaque"

}

resource "kubernetes_manifest" "clustersecretstore_vault" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "orca-vault-secrets"
    }
    spec = {
      provider = {
        vault = {
          server    = "https://vault.konvoi.svc.intdev.cloud.bwi.intranet-bw.de"
          path      = var.vault_kv_engine_name
          version   = "v2"
          namespace = var.vault_namespace
          caProvider = {
            type      = "Secret"
            namespace = "argocd-integrator"
            name      = "pkibw-ca-certs"
            key       = "root-certs.crt"
          }
          auth = {
            appRole = {
              path = var.vault_backend
              roleRef = {
                name = "orca-vault-approle"
                key  = "role_id"
              }
              secretRef = {
                name = "orca-vault-approle"
                key  = "secret_id"
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_secret.approle
  ]
}

resource "kubernetes_manifest" "externalsecret_psa_gitlab" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "private-repo-gitlab"
      namespace = "cpaas-system"
    }
    spec = {
      data = [{
        remoteRef = {
          key      = "${var.clustername}/global/psa-gitlab-credential"
          property = "username"
        }
        secretKey = "username"
        },
        {
          remoteRef = {
            key      = "${var.clustername}/global/psa-gitlab-credential"
            property = "password"
          }
          secretKey = "password"
      }]
      secretStoreRef = {
        name = "orca-vault-secrets"
        kind = "ClusterSecretStore"
      }
      target = {
        name = "private-repo-gitlab"
        template = {
          metadata = {
            labels = {
              "argocd.argoproj.io/secret-type" = "repository"
            }
          }
          data = {
            type     = "git"
            url      = var.argocd_url
            project  = var.argocd_project
            username = "{{ .username }}"
            password = "{{ .password }}"
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_manifest.clustersecretstore_vault
  ]
}

resource "kubernetes_manifest" "externalsecret_psa_gitlab_repo_creds" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "private-repo-creds-gitlab"
      namespace = "cpaas-system"
    }
    spec = {
      data = [{
        remoteRef = {
          key      = "${var.clustername}/global/psa-gitlab-credential"
          property = "username"
        }
        secretKey = "username"
        },
        {
          remoteRef = {
            key      = "${var.clustername}/global/psa-gitlab-credential"
            property = "password"
          }
          secretKey = "password"
      }]
      secretStoreRef = {
        name = "orca-vault-secrets"
        kind = "ClusterSecretStore"
      }
      target = {
        name = "private-repo-creds-gitlab"
        template = {
          metadata = {
            labels = {
              "argocd.argoproj.io/secret-type" = "repo-creds"
            }
          }
          data = {
            type     = "git"
            url      = var.argocd_url
            username = "{{ .username }}"
            password = "{{ .password }}"
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_manifest.clustersecretstore_vault
  ]
}

resource "kubernetes_manifest" "externalsecret_nexus_charts" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "private-helm-repo"
      namespace = "cpaas-system"
    }
    spec = {
      data = [{
        remoteRef = {
          key      = "orca-secrets/data/global/nexus"
          property = "username"
        }
        secretKey = "username"
        },
        {
          remoteRef = {
            key      = "orca-secrets/data/global/nexus"
            property = "password"
          }
          secretKey = "password"
      }]
      secretStoreRef = {
        name = "orca-vault-secrets"
        kind = "ClusterSecretStore"
      }
      target = {
        name = "private-helm-repo"
        template = {
          metadata = {
            labels = {
              "argocd.argoproj.io/secret-type" = "repository"
            }
          }
          data = {
            type     = "helm"
            url      = var.argocd_helm_url
            name     = var.argocd_helm_name
            username = "{{ .username }}"
            password = "{{ .password }}"
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_manifest.clustersecretstore_vault
  ]
}

resource "kubernetes_manifest" "externalsecret_nexus_charts_repo_creds" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "private-repo-creds-helm"
      namespace = "cpaas-system"
    }
    spec = {
      data = [{
        remoteRef = {
          key      = "orca-secrets/data/global/nexus"
          property = "username"
        }
        secretKey = "username"
        },
        {
          remoteRef = {
            key      = "orca-secrets/data/global/nexus"
            property = "password"
          }
          secretKey = "password"
      }]
      secretStoreRef = {
        name = "orca-vault-secrets"
        kind = "ClusterSecretStore"
      }
      target = {
        name = "private-repo-creds-helm"
        template = {
          metadata = {
            labels = {
              "argocd.argoproj.io/secret-type" = "repo-creds"
            }
          }
          data = {
            type     = "helm"
            url      = var.argocd_helm_url
            name     = var.argocd_helm_name
            username = "{{ .username }}"
            password = "{{ .password }}"
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_manifest.clustersecretstore_vault
  ]
}