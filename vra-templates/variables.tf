variable "vra_url" {
  description = "The base URL for the vRealize Automation endpoint"
  type        = string
}

variable "vra_refresh_token" {
  description = "The refresh token for the vRealize Automation endpoint"
  type        = string
  sensitive   = true
}

variable "vra_insecure" {
  description = "Allow insecure connections to the vRealize Automation endpoint"
  type        = bool
  default     = false
}

variable "vra_project_id" {
  description = "The ID of the vRealize Automation project"
  type        = string
}

variable "blueprint_deployments" {
  description = "Map of blueprint deployments to create"
  type = map(object({
    blueprint_name = string
    inputs         = map(string)
  }))
  default = {}
}

variable "environment" {
  description = "Current deployment environment"
  type        = string
}