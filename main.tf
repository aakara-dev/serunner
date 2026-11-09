locals {
  tags = merge({ workload = "gitlab-runners", managed_by = "terraform" }, var.tags)

  runner_base_url = "https://gitlab-runner-downloads.s3.amazonaws.com/v${var.runner_version}/binaries"

  linux_vmss   = "vmss-${var.name_prefix}-linux"
  windows_vmss = "vmss-${var.name_prefix}-win"
}

# Manager, workers, identity and NSG share one resource group. The manager identity's
# rights are scoped to the scale sets themselves (see modules/runner-manager), not the RG.
resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

# Stored in Terraform state and the manager's custom data: keep the state backend private.
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
  source                   = "./modules/network"
  name_prefix              = var.name_prefix
  location                 = var.location
  resource_group_name      = azurerm_resource_group.this.name
  vnet_resource_group_name = var.vnet_resource_group_name
  vnet_name                = var.vnet_name
  subnet_prefix            = var.subnet_prefix
  route_table_id           = var.route_table_id
  tags                     = local.tags
}

module "worker_linux" {
  source               = "./modules/worker-vmss-linux"
  name                 = local.linux_vmss
  location             = var.location
  resource_group_name  = azurerm_resource_group.this.name
  subnet_id            = module.network.subnet_id
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
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.subnet_id
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
  resource_group_name         = azurerm_resource_group.this.name
  subnet_id                   = module.network.subnet_id
  private_ip_address          = module.network.manager_private_ip
  vm_size                     = var.manager_vm_size
  admin_ssh_public_key        = var.manager_admin_ssh_public_key
  subscription_id             = var.subscription_id
  workers_resource_group_name = azurerm_resource_group.this.name
  gitlab_url                  = var.gitlab_url
  fleeting_plugin_version     = var.fleeting_plugin_version
  runner_binary = {
    url    = "${local.runner_base_url}/gitlab-runner-linux-amd64"
    sha256 = var.runner_sha256_linux
  }

  scale_set_ids = merge(
    { linux = module.worker_linux.id },
    var.enable_windows ? { windows = module.worker_windows[0].id } : {},
  )

  runner_token_linux      = var.runner_token_linux
  runner_token_windows    = var.enable_windows ? var.runner_token_windows : ""
  worker_ssh_private_key  = tls_private_key.worker.private_key_openssh
  worker_windows_password = var.enable_windows ? random_password.windows[0].result : ""

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
