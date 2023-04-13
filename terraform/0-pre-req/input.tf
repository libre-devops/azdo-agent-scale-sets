variable "azdo_pat" {
  type        = string
  description = "The PAT token for Azure DevOps access"
  default     = "AzdoPat"
}

variable "azdo_url" {
  type        = string
  description = "The URL of Azure DevOps instance"
  default     = "AzdoUrl"
}
