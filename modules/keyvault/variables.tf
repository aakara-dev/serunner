variable "name" {
  description = "Globally unique Key Vault name (3-24 chars, alphanumerics and hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.name))
    error_message = "Key Vault name must be 3-24 chars, start with a letter, alphanumerics/hyphens only."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the vault."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant ID for the vault."
  type        = string
}

variable "purge_protection_enabled" {
  description = "Enable purge protection. Safer, but the vault name is then locked for the retention period after deletion."
  type        = bool
  default     = false
}

variable "allowed_ip_cidrs" {
  description = "Public CIDRs allowed to reach the vault data plane (e.g. the deployer's egress IP). Empty = allow all networks, RBAC only."
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "Subnets (with the Microsoft.KeyVault service endpoint) allowed to reach the vault."
  type        = list(string)
  default     = []
}

variable "secrets_officers" {
  description = "Static key => principal ID granted Key Vault Secrets Officer (read/write). Typically the deployer."
  type        = map(string)
  default     = {}
}

variable "secrets_readers" {
  description = "Static key => principal ID granted Key Vault Secrets User (read). Typically the runner manager identity."
  type        = map(string)
  default     = {}
}

variable "managed_secret_names" {
  description = "Names of secrets Terraform writes. Kept separate from the values so for_each keys are not sensitive."
  type        = list(string)
  default     = []
}

variable "managed_secret_values" {
  description = "Secret name => value for every entry in managed_secret_names."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
