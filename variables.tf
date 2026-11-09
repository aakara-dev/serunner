# --- Placement -----------------------------------------------------------------

variable "subscription_id" {
  description = "Target subscription ID. Passed explicitly so the active az context cannot redirect a deploy."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "name_prefix" {
  description = "Short lowercase prefix for resource names (max 8 chars keeps the Key Vault name under 24)."
  type        = string
  default     = "glrun"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.name_prefix))
    error_message = "name_prefix must be 2-8 lowercase alphanumerics starting with a letter."
  }
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}

# --- GitLab / runner -------------------------------------------------------------

variable "gitlab_url" {
  description = "Self-managed / Dedicated GitLab URL, e.g. https://gitlab.example.com."
  type        = string

  validation {
    condition     = can(regex("^https://", var.gitlab_url))
    error_message = "gitlab_url must start with https://."
  }
}

variable "runner_version" {
  description = "GitLab Runner version for the manager and Windows workers (keep within the GitLab server's supported range)."
  type        = string
  default     = "19.5.2"
}

variable "runner_sha256_linux" {
  description = "SHA256 of binaries/gitlab-runner-linux-amd64 for runner_version (from release.sha256)."
  type        = string
  default     = "1c1752101f5b0f212615ad2c674d8f3499de96d9377f31aed1e3eecdbd068de1"
}

variable "runner_sha256_windows" {
  description = "SHA256 of binaries/gitlab-runner-windows-amd64.exe for runner_version (from release.sha256)."
  type        = string
  default     = "5885cb5298651080386c91dbcdff38ff5aa9de7bf7cf913eadb2bd6b8387e6c7"
}

variable "fleeting_plugin_version" {
  description = "fleeting-plugin-azure version, pinned exactly."
  type        = string
  default     = "1.2.0"
}

# --- Manager ---------------------------------------------------------------------

variable "manager_vm_size" {
  description = "Runner manager VM size (always on)."
  type        = string
  default     = "Standard_B1ms"
}

variable "manager_admin_ssh_public_key" {
  description = "Your OpenSSH public key for the manager VM (break-glass only; no inbound SSH is opened)."
  type        = string
}

variable "key_vault_allowed_ip_cidrs" {
  description = "Deployer egress CIDRs allowed to the Key Vault data plane. Empty = any network (RBAC still required)."
  type        = list(string)
  default     = []
}

# --- Workers (shared) --------------------------------------------------------------

variable "use_spot" {
  description = "Run worker scale sets on Spot capacity (~80% cheaper; jobs can be evicted)."
  type        = bool
  default     = false
}

# --- Linux workers -----------------------------------------------------------------

variable "linux_vm_size" {
  description = "Linux worker size."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "linux_default_job_image" {
  description = "Image used when a job does not set `image:`."
  type        = string
  default     = "alpine:3.20"
}

variable "linux_privileged" {
  description = "Run job containers privileged (needed for docker:dind / Testcontainers)."
  type        = bool
  default     = false
}

variable "linux_capacity_per_instance" {
  description = "Concurrent jobs per Linux instance."
  type        = number
  default     = 2
}

variable "linux_max_use_count" {
  description = "Jobs an instance may run before it is replaced (0 = unlimited). Reuse within a pipeline avoids a boot per job."
  type        = number
  default     = 10
}

variable "linux_max_instances" {
  description = "Upper bound on Linux instances (cost ceiling)."
  type        = number
  default     = 3
}

variable "linux_idle_time" {
  description = "How long an idle Linux instance survives before deletion."
  type        = string
  default     = "15m"
}

# --- Windows workers ---------------------------------------------------------------

variable "enable_windows" {
  description = "Create the Windows .NET Framework pool and runner."
  type        = bool
  default     = true
}

variable "windows_vm_size" {
  description = "Windows worker size."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "windows_capacity_per_instance" {
  description = "Concurrent jobs per Windows instance (instance executor shares the host)."
  type        = number
  default     = 1
}

variable "windows_max_use_count" {
  description = "Jobs a Windows instance may run before it is replaced."
  type        = number
  default     = 20
}

variable "windows_max_instances" {
  description = "Upper bound on Windows instances."
  type        = number
  default     = 1
}

variable "windows_idle_time" {
  description = "Idle time before a Windows instance is deleted. Longer than Linux because cold start is ~20-30 min."
  type        = string
  default     = "30m"
}

variable "windows_instance_acquire_timeout" {
  description = "How long a Windows job waits for an instance (cold start includes VS Build Tools install)."
  type        = string
  default     = "45m"
}

variable "windows_git_installer" {
  description = "Pinned Git for Windows installer URL and SHA256."
  type = object({
    url    = string
    sha256 = string
  })
  default = {
    url    = "https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/Git-2.56.0.4-64-bit.exe"
    sha256 = "4961a4a8cc778d8b6e00a5819e5fe4d078b754555aff7aedc2d77a5d74c2de80"
  }
}
