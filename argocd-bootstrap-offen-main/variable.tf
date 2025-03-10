# Diese Variablen müssen beim Verwenden dieses Moduls gesetzt werden.
# ---------------------------------------------------------------------------------------------------------------------
variable "clustername" {
  type        = string
  description = "Der Name des Kubernetes Clusters, der für die Identifizierung verwendet wird"
  nullable    = false
}
variable "kube_config" {
  type        = string
  description = "Der Pfad der Konfig Datei für die Authentifizierung bei Kubernetes"
  nullable    = false
}

# ---------------------------------------------------------------------------------------------------------------------
# VAULT CONFIGURATION
# Variablen für die Vault-Integration und Authentifizierung
# ---------------------------------------------------------------------------------------------------------------------
variable "vault_address" {
  type        = string
  description = "Die vollständige URL des Vault-Servers (z.B. https://vault.example.com)"
  nullable    = false
}
variable "vault_namespace" {
  type        = string
  description = "Der Namespace in Vault, in dem die Secrets und Policies verwaltet werden"
  nullable    = false
}
variable "vault_username" {
  type        = string
  description = "Der Benutzername für die LDAP-Authentifizierung bei Vault"
  nullable    = false
}
variable "vault_password" {
  type        = string
  sensitive   = true
  description = "Das Passwort für die LDAP-Authentifizierung bei Vault. Wird verschlüsselt gespeichert"
  nullable    = false
}
variable "vault_kv_engine_name" {
  type        = string
  description = "Der Name der Key-Value Secrets Engine in Vault (z.B. 'kv' oder 'secret')"
  nullable    = false
}
variable "vault_backend" {
  type        = string
  description = "Der zu verwendende Authentication Backend-Typ in Vault (z.B. 'approle')"
  nullable    = false
}
variable "approle_namespaces" {
  type        = list(any)
  description = "Die Liste der Namespace, wo das Approle secret erzeugt wird"
  nullable    = false
}
# ---------------------------------------------------------------------------------------------------------------------
# ARGOCD CONFIGURATION
# Variablen für die ArgoCD-Integration und Helm-Deployment
# ---------------------------------------------------------------------------------------------------------------------
variable "argocd_project" {
  type        = string
  description = "Der Name des ArgoCD Projekts, in dem die Anwendungen verwaltet werden"
  nullable    = false
}
variable "argocd_app_of_apps_file" {
  type        = string
  description = "Der Name mit relativen Pfad der app-of-apps yaml"
  nullable    = false
}
variable "argocd_url" {
  type        = string
  description = "Die URL des Git-Repositories, das die ArgoCD Anwendungskonfigurationen enthält"
  nullable    = false
}
variable "argocd_helm_url" {
  type        = string
  description = "Die URL des Helm-Repository, das das ArgoCD Chart enthält"
  nullable    = false
}
variable "argocd_helm_name" {
  type        = string
  description = "Der Name des Helm-Charts für die ArgoCD-Installation"
  nullable    = false
}
# ---------------------------------------------------------------------------------------------------------------------
# GITLAB CONFIGURATION
# Variablen für die GitLab-Integration und API-Zugriff
# ---------------------------------------------------------------------------------------------------------------------
variable "gitlab_argocd_project_id" {
  type        = string
  description = "Die numerische ID des GitLab-Projekts, das für ArgoCD verwendet wird"
  nullable    = false
}

variable "gitlab_argocd_project_ref" {
  type        = string
  description = "Die Branch des GitLab-Projekts, das für ArgoCD verwendet wird"
  nullable    = false
}

variable "gitlab_token" {
  # REQUIRED PARAMETERS
  type        = string
  sensitive   = true
  description = "Der Personal Access Token für die GitLab API-Authentifizierung. Wird verschlüsselt gespeichert"
  nullable    = false
}
variable "gitlab_base_url" {
  type        = string
  description = "Die Basis-URL der GitLab-Instanz (z.B. https://gitlab.example.com)"
  nullable    = false
}
