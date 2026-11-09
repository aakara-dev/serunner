variable "name" {
  description = "Scale set name. Must be dedicated to one [[runners]] entry."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the scale set."
  type        = string
}

variable "subnet_id" {
  description = "Worker subnet ID."
  type        = string
}

variable "vm_size" {
  description = "Worker VM size."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "use_spot" {
  description = "Use Spot priority (cheaper, may be evicted mid-job)."
  type        = bool
  default     = false
}

variable "computer_name_prefix" {
  description = "Hostname prefix (Windows: max 9 chars)."
  type        = string
  default     = "ciwin"

  validation {
    condition     = length(var.computer_name_prefix) <= 9
    error_message = "Windows computer_name_prefix must be 9 characters or fewer."
  }
}

variable "admin_username" {
  description = "Local admin the WinRM connector logs in as."
  type        = string
  default     = "runner"
}

variable "admin_password" {
  description = "Local admin password (generated in the root module, also stored in Key Vault)."
  type        = string
  sensitive   = true
}

variable "os_disk_size_gb" {
  description = "OS disk size (Windows images need at least 127 GB)."
  type        = number
  default     = 128
}

variable "image" {
  description = "Marketplace image for workers."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

variable "git_installer" {
  description = "Pinned Git for Windows installer URL and SHA256."
  type = object({
    url    = string
    sha256 = string
  })
}

variable "runner_binary" {
  description = "Pinned gitlab-runner Windows binary URL and SHA256 (same version as the manager)."
  type = object({
    url    = string
    sha256 = string
  })
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
