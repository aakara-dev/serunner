variable "name_prefix" {
  description = "Short prefix used in resource and runner names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the manager VM and its identity."
  type        = string
}

variable "subnet_id" {
  description = "Runner subnet ID (shared with the workers)."
  type        = string
}

variable "private_ip_address" {
  description = "Static private IP for the manager; the worker NSG allows SSH/WinRM only from it."
  type        = string
}

variable "vm_size" {
  description = "Manager VM size. It only schedules jobs; B1ms (1 vCPU/2 GB) is enough."
  type        = string
  default     = "Standard_B1ms"
}

variable "admin_ssh_public_key" {
  description = "Your OpenSSH public key for break-glass access (no inbound SSH is open; use run-command or serial console)."
  type        = string
}

variable "subscription_id" {
  description = "Subscription that holds the worker scale sets."
  type        = string
}

variable "workers_resource_group_name" {
  description = "Resource group name of the worker scale sets."
  type        = string
}

variable "scale_set_ids" {
  description = "Worker scale set IDs the manager identity may scale, keyed by a static name (linux, windows)."
  type        = map(string)
}

variable "runner_token_linux" {
  description = "glrt- authentication token of the Linux runner."
  type        = string
  sensitive   = true
}

variable "runner_token_windows" {
  description = "glrt- authentication token of the Windows runner; empty when Windows is disabled."
  type        = string
  sensitive   = true
  default     = ""
}

variable "worker_ssh_private_key" {
  description = "OpenSSH private key the connector uses to reach Linux workers."
  type        = string
  sensitive   = true
}

variable "worker_windows_password" {
  description = "Windows worker admin password for the WinRM connector; empty when Windows is disabled."
  type        = string
  sensitive   = true
  default     = ""
}

variable "gitlab_url" {
  description = "GitLab instance URL, e.g. https://gitlab.example.com."
  type        = string
}

variable "runner_binary" {
  description = "Pinned gitlab-runner Linux binary URL and SHA256."
  type = object({
    url    = string
    sha256 = string
  })
}

variable "fleeting_plugin_version" {
  description = "Exact fleeting-plugin-azure version (plugin = \"azure:<version>\")."
  type        = string
}

variable "linux" {
  description = "Linux docker-autoscaler runner settings."
  type = object({
    vmss_name             = string
    admin_username        = string
    default_image         = string
    privileged            = bool
    capacity_per_instance = number
    max_use_count         = number
    max_instances         = number
    idle_time             = string
  })
}

variable "windows" {
  description = "Windows instance-executor runner settings; null disables the Windows runner."
  type = object({
    vmss_name                = string
    admin_username           = string
    capacity_per_instance    = number
    max_use_count            = number
    max_instances            = number
    idle_time                = string
    instance_acquire_timeout = string
  })
  default = null
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
