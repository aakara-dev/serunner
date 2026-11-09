variable "name" {
  description = "Scale set name. Must be dedicated to one [[runners]] entry."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the scale set (the manager identity gets scoped rights here)."
  type        = string
}

variable "subnet_id" {
  description = "Worker subnet ID."
  type        = string
}

variable "vm_size" {
  description = "Worker VM size. D4s_v5 (4 vCPU/16 GB) fits sbt/Spark and Maven builds."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "use_spot" {
  description = "Use Spot priority (~80% cheaper, may be evicted mid-job)."
  type        = bool
  default     = false
}

variable "computer_name_prefix" {
  description = "Hostname prefix for instances."
  type        = string
  default     = "cilnx"
}

variable "admin_username" {
  description = "Admin user the runner connector logs in as."
  type        = string
  default     = "runner"
}

variable "admin_ssh_public_key" {
  description = "OpenSSH public key matching the private key the manager reads from Key Vault."
  type        = string
}

variable "os_disk_size_gb" {
  description = "OS disk size; Docker images for JVM/Spark stacks are large."
  type        = number
  default     = 64
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
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
