data "azurerm_client_config" "current" {}

locals {
  tags = merge({ workload = "gitlab-runners", managed_by = "terraform" }, var.tags)

  runner_base_url = "https://gitlab-runner-downloads.s3.amazonaws.com/v${var.runner_version}/binaries"

  key_vault_name = "kv-${var.name_prefix}-${random_string.kv_suffix.result}"
  linux_vmss     = "vmss-${var.name_prefix}-linux"
  windows_vmss   = "vmss-${var.name_prefix}-win"

  # Secrets Terraform owns. Runner tokens (runner-token-*) are set out-of-band; see README.
  # Names are listed separately so for_each keys never inherit sensitivity from values.
  managed_secret_names = concat(
    ["runner-config-template", "worker-ssh-private-key"],
    var.enable_windows ? ["worker-windows-password"] : [],
  )
  managed_secrets = merge(
    {
      "runner-config-template" = module.runner_manager.config_template
      "worker-ssh-private-key" = tls_private_key.worker.private_key_openssh
    },
    var.enable_windows ? { "worker-windows-password" = random_password.windows[0].result } : {},
  )
}

resource "azurerm_resource_group" "core" {
  name     = "rg-${var.name_prefix}-core"
  location = var.location
  tags     = local.tags
}

# Separate RG so the manager identity's VM/Network Contributor rights cover only workers.
resource "azurerm_resource_group" "workers" {
  name     = "rg-${var.name_prefix}-workers"
  location = var.location
  tags     = local.tags
}

resource "random_string" "kv_suffix" {
  length  = 5
  special = false
  upper   = false
}

# Stored in state and Key Vault: keep the state backend private (see backend.tf).
resource "tls_private_key" "worker" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "random_password" "windows" {
  count            = var.enable_windows ? 1 : 0
  length           = 24
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#%*-_=+"
}

module "network" {
  source              = "./modules/network"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = local.tags
}

module "worker_linux" {
  source               = "./modules/worker-vmss-linux"
  name                 = local.linux_vmss
  location             = var.location
  resource_group_name  = azurerm_resource_group.workers.name
  subnet_id            = module.network.workers_subnet_id
  vm_size              = var.linux_vm_size
  use_spot             = var.use_spot
  admin_ssh_public_key = tls_private_key.worker.public_key_openssh
  tags                 = local.tags
}

module "worker_windows" {
  source              = "./modules/worker-vmss-windows"
  count               = var.enable_windows ? 1 : 0
  name                = local.windows_vmss
  location            = var.location
  resource_group_name = azurerm_resource_group.workers.name
  subnet_id           = module.network.workers_subnet_id
  vm_size             = var.windows_vm_size
  use_spot            = var.use_spot
  admin_password      = random_password.windows[0].result
  git_installer       = var.windows_git_installer
  runner_binary = {
    url    = "${local.runner_base_url}/gitlab-runner-windows-amd64.exe"
    sha256 = var.runner_sha256_windows
  }
  tags = local.tags
}

module "runner_manager" {
  source                      = "./modules/runner-manager"
  name_prefix                 = var.name_prefix
  location                    = var.location
  resource_group_name         = azurerm_resource_group.core.name
  subnet_id                   = module.network.manager_subnet_id
  vm_size                     = var.manager_vm_size
  admin_ssh_public_key        = var.manager_admin_ssh_public_key
  subscription_id             = var.subscription_id
  workers_resource_group_id   = azurerm_resource_group.workers.id
  workers_resource_group_name = azurerm_resource_group.workers.name
  key_vault_name              = local.key_vault_name
  gitlab_url                  = var.gitlab_url
  fleeting_plugin_version     = var.fleeting_plugin_version
  runner_binary = {
    url    = "${local.runner_base_url}/gitlab-runner-linux-amd64"
    sha256 = var.runner_sha256_linux
  }

  linux = {
    vmss_name             = module.worker_linux.name
    admin_username        = module.worker_linux.admin_username
    default_image         = var.linux_default_job_image
    privileged            = var.linux_privileged
    capacity_per_instance = var.linux_capacity_per_instance
    max_use_count         = var.linux_max_use_count
    max_instances         = var.linux_max_instances
    idle_time             = var.linux_idle_time
  }

  windows = var.enable_windows ? {
    vmss_name                = module.worker_windows[0].name
    admin_username           = module.worker_windows[0].admin_username
    capacity_per_instance    = var.windows_capacity_per_instance
    max_use_count            = var.windows_max_use_count
    max_instances            = var.windows_max_instances
    idle_time                = var.windows_idle_time
    instance_acquire_timeout = var.windows_instance_acquire_timeout
  } : null

  tags = local.tags
}

module "keyvault" {
  source              = "./modules/keyvault"
  name                = local.key_vault_name
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  allowed_ip_cidrs    = var.key_vault_allowed_ip_cidrs
  allowed_subnet_ids  = [module.network.manager_subnet_id]

  secrets_officers = { deployer = data.azurerm_client_config.current.object_id }
  secrets_readers  = { manager = module.runner_manager.identity_principal_id }

  managed_secret_names  = local.managed_secret_names
  managed_secret_values = local.managed_secrets

  tags = local.tags
}
