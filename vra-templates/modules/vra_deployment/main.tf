resource "vra_deployment" "this" {
  name        = var.name
  description = var.description
  blueprint_id = var.blueprint_id
  project_id  = var.project_id
  
  inputs = var.inputs
  
  timeouts {
    create = var.create_timeout
    delete = var.delete_timeout
    update = var.update_timeout
  }
}

# Optionally monitor deployment status
resource "null_resource" "deployment_monitor" {
  count = var.monitor_deployment ? 1 : 0
  
  triggers = {
    deployment_id = vra_deployment.this.id
  }
  
  provisioner "local-exec" {
    command = "echo 'Monitoring deployment ${vra_deployment.this.name} with ID ${vra_deployment.this.id}'"
  }
  
  depends_on = [vra_deployment.this]
}