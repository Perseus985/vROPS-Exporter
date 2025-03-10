output "id" {
  description = "ID of the created blueprint"
  value       = vra_blueprint.this.id
}

output "name" {
  description = "Name of the created blueprint"
  value       = vra_blueprint.this.name
}

output "project_id" {
  description = "Project ID of the created blueprint"
  value       = vra_blueprint.this.project_id
}

output "current_version" {
  description = "Current version of the blueprint"
  value       = var.manage_version ? vra_blueprint_version.this[0].version : null
}