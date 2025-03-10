terraform {
  required_providers {
    vra = {
      source  = "vmware/vra"
      version = "~> 0.6.0"
    }
  }
  
  backend "http" {
    # Backend configuration will be provided via -backend-config flag
  }
}

provider "vra" {
  url           = var.vra_url
  refresh_token = var.vra_refresh_token
  insecure      = var.vra_insecure
}

# Load and process blueprints from the blueprints directory
locals {
  blueprint_files = fileset(path.module, "blueprints/*.yml")
  blueprints = {
    for file in local.blueprint_files :
    basename(file) => {
      content = file("${path.module}/${file}")
      name    = replace(basename(file), ".yml", "")
    }
  }
}

# Create/update vRA blueprints
module "blueprints" {
  source = "./modules/vra-blueprint"

  for_each = local.blueprints

  name        = each.value.name
  description = "Blueprint for ${each.value.name}"
  content     = each.value.content
  project_id  = var.vra_project_id
}

# Deploy blueprints based on environment configuration
module "deployments" {
  source = "./modules/vra-deployment"

  for_each = var.blueprint_deployments

  name         = each.key
  blueprint_id = module.blueprints[each.value.blueprint_name].id
  project_id   = var.vra_project_id
  inputs       = each.value.inputs
  
  depends_on = [module.blueprints]
}