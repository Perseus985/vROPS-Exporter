terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "7.3.1"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "17.8.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "4.6.0"
    }
  }
}