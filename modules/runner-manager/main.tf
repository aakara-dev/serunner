locals {
  # Scale set capacity bounds how many jobs can run at once across both runners.
  concurrent = (var.linux.max_instances * var.linux.capacity_per_instance) + (
    var.windows == null ? 0 : var.windows.max_instances * var.windows.capacity_per_instance
  )

  config_toml = templatefile("${path.module}/templates/config.toml.tpl", {
    concurrent                  = local.concurrent
    name_prefix                 = var.name_prefix
    gitlab_url                  = var.gitlab_url
    fleeting_plugin_version     = var.fleeting_plugin_version
    subscription_id             = var.subscription_id
    workers_resource_group_name = var.workers_resource_group_name
    linux                       = var.linux
    windows                     = var.windows
    runner_token_linux          = var.runner_token_linux
    runner_token_windows        = var.runner_token_windows
    worker_windows_password     = var.worker_windows_password
  })

  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml", {
    config_toml_b64      = base64encode(local.config_toml)
    worker_ssh_key_b64   = base64encode(var.worker_ssh_private_key)
    client_id            = azurerm_user_assigned_identity.this.client_id
    runner_binary_url    = var.runner_binary.url
    runner_binary_sha256 = var.runner_binary.sha256
  })

  # Same roles as the plugin's own test setup, but scoped to each scale set (and the
  # instance NICs beneath it) instead of the whole resource group, so the identity cannot
  # touch the manager VM, its NIC or the NSG that share the resource group.
  scale_set_roles = merge([
    for k, id in var.scale_set_ids : {
      for role in ["Virtual Machine Contributor", "Network Contributor"] :
      "${k}/${role}" => { scope = id, role = role }
    }
  ]...)
}

resource "azurerm_user_assigned_identity" "this" {
  name                = "id-${var.name_prefix}-manager"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "scale_sets" {
  for_each             = local.scale_set_roles
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

# Scaling out places new NICs in the subnet, which needs subnets/join/action on it (ARM
# linked-access check). The subnet lives in the spoke VNet's resource group, outside the
# scale set scope above. Narrower than this needs a custom role.
resource "azurerm_role_assignment" "subnet_join" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_network_interface" "this" {
  name                = "nic-${var.name_prefix}-manager"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip_address
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                  = "vm-${var.name_prefix}-manager"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.this.id]
  tags                  = var.tags

  # Carries config.toml (runner tokens, Windows password) and the worker SSH key. Any
  # runner setting or token change replaces this VM; it keeps no state, but apply while
  # no jobs are running.
  custom_data = base64encode(local.cloud_init)

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_public_key
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  boot_diagnostics {}

  lifecycle {
    ignore_changes = [source_image_reference[0].version]
  }

  # The runner starts at first boot and immediately scales sets; grant rights first.
  depends_on = [azurerm_role_assignment.scale_sets, azurerm_role_assignment.subnet_join]
}
