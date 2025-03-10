variable "name" {
  description = "Name of the blueprint"
  type        = string
}

variable "description" {
  description = "Description of the blueprint"
  type        = string
  default     = ""
}

variable "content" {
  description = "YAML content of the blueprint"
  type        = string
}

variable "project_id" {
  description = "ID of the project the blueprint belongs to"
  type        = string
}

variable "manage_version" {
  description = "Whether to manage blueprint versions"
  type        = bool
  default     = false
}

variable "version" {
  description = "Version number for the blueprint"
  type        = string
  default     = "1.0.0"
}

variable "release" {
  description = "Whether this version should be released"
  type        = bool
  default     = true
}