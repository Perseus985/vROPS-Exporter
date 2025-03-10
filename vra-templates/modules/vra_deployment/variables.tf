variable "name" {
  description = "Name of the deployment"
  type        = string
}

variable "description" {
  description = "Description of the deployment"
  type        = string
  default     = ""
}

variable "blueprint_id" {
  description = "ID of the blueprint to deploy"
  type        = string
}

variable "project_id" {
  description = "ID of the project for the deployment"
  type        = string
}

variable "inputs" {
  description = "Input values for the deployment"
  type        = map(string)
  default     = {}
}

variable "monitor_deployment" {
  description = "Whether to monitor the deployment status"
  type        = bool
  default     = false
}

variable "create_timeout" {
  description = "Timeout for creation operations"
  type        = string
  default     = "30m"
}

variable "update_timeout" {
  description = "Timeout for update operations"
  type        = string
  default     = "30m"
}

variable "delete_timeout" {
  description = "Timeout for deletion operations"
  type        = string
  default     = "30m"
}