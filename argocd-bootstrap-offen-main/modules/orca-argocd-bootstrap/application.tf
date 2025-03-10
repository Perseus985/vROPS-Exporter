resource "kubernetes_manifest" "application_app_of_apps" {
  manifest = yamldecode(base64decode(data.gitlab_repository_file.app_of_apps.content))
  depends_on = [
    kubernetes_manifest.externalsecret_psa_gitlab,
    kubernetes_manifest.externalsecret_psa_gitlab_repo_creds,
    kubernetes_manifest.externalsecret_nexus_charts,
    kubernetes_manifest.externalsecret_nexus_charts_repo_creds
  ]
}