output "id" {
  description = "ID of the created deployment"
  value       = vra_deployment.this.id
}

output "name" {
  description = "Name of the created deployment"
  value       = vra_deployment.this.name
}

output "status" {
  description = "Current status of the deployment"
  value       = vra_deployment.this.status
}

output "created_at" {
  description = "Creation timestamp"
  value       = vra_deployment.this.created_at
}

output "last_updated_at" {
  description = "Last update timestamp"
  value       = vra_deployment.this.last_updated_at
}

output "resources" {
  description = "Resources created by this deployment"
  value       = vra_deployment.this.resources
  sensitive   = true
}