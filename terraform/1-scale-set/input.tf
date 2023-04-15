variable "azdo_pat" {
  type        = string
  description = "The PAT token for Azure DevOps access"
  sensitive   = true
  nullable    = false
}

variable "azdo_url" {
  type        = string
  description = "The URL of Azure DevOps instance"
  sensitive   = true
  nullable    = false
}

variable "azdo_project" {
  type = string
  description = "The project name of the Azure DevOps repo"
  sensitive = true
  nullable = false
}

variable "azdo_agent_pool_name" {
  type        = string
  description = "The name of the agent pool if you want one specified"
  default     = null
}

