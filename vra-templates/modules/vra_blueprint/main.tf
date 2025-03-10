resource "vra_blueprint" "this" {
  name        = var.name
  description = var.description
  content     = var.content
  project_id  = var.project_id
}

# Additional resources like version management, etc.
resource "vra_blueprint_version" "this" {
  blueprint_id = vra_blueprint.this.id
  change_log   = "Created/updated via OpenTofu"
  description  = "Version created via OpenTofu CI/CD"
  version      = var.version
  release      = var.release

  count = var.manage_version ? 1 : 0
}