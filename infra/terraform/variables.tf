variable "location" {
  type        = string
  description = "Azure region for the C2C lab resources."
  default     = "eastus"
}

variable "resource_prefix" {
  type        = string
  description = "Short lowercase prefix used for all lab resources."
  default     = "c2cprod"
}

variable "environment" {
  type        = string
  description = "Environment label for resource tags."
  default     = "prod"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository that owns the workflows."
  default     = "CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios"
}

variable "workflow_principal_object_id" {
  type        = string
  description = "Object ID of the service principal used by GitHub Actions OIDC. Leave empty to skip workflow role assignments."
  default     = ""
}

variable "enable_defender_plans" {
  type        = bool
  description = "Enable Defender CSPM and Containers plans when permissions allow it."
  default     = true
}

variable "aks_node_count" {
  type        = number
  description = "AKS node count for the test cluster."
  default     = 1
}

variable "aks_node_size" {
  type        = string
  description = "AKS node VM size."
  default     = "Standard_D2s_v4"
}