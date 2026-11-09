locals {
  # Scale set capacity bounds how many jobs can run at once across both runners.
  concurrent = (var.linux.max_instances * var.linux.capacity_per_instance) + (
    var.windows == null ? 0 : var.windows.max_instances * var.windows.capacity_per_instance
  )

  required_secrets = concat(
    ["runner-token-linux", "worker-ssh-private-key"],
    var.windows == null ? [] : ["runner-token-windows", "worker-windows-password"],
  )

  config_template = templatefile("${path.module}/templates/config.toml.tpl", {
    concurrent                  = local.concurrent
    name_prefix                 = var.name_prefix
    gitlab_url                  = var.gitlab_url
    fleeting_plugin_version     = var.fleeting_plugin_version
    subscription_id             = var.subscription_id
    workers_resource_group_name = var.workers_resource_group_name
    linux                       = var.linux
    windows                     = var.windows
  })

  render_script = templatefile("${path.module}/templates/render-runner-config.sh", {
    key_vault_name   = var.key_vault_name
    client_id        = azurerm_user_assigned_identity.this.client_id
    required_secrets = join(" ", local.required_secrets)
  })

  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml", {
    render_script        = local.render_script
    client_id            = azurerm_user_assigned_identity.this.client_id
    runner_binary_url    = var.runner_binary.url
    runner_binary_sha256 = var.runner_binary.sha256
  })
}

resource "azurerm_user_assigned_identity" "this" {
  name                = "id-${var.name_prefix}-manager"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Rights the fleeting plugin needs to resize scale sets and read instance NICs/IPs,
# scoped to the workers resource group only (matches the plugin's own test setup).
resource "azurerm_role_assignment" "workers" {
  for_each             = toset(["Virtual Machine Contributor", "Network Contributor"])
  scope                = var.workers_resource_group_id
  role_definition_name = each.key
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name_prefix}-manager"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  name                = "nic-${var.name_prefix}-manager"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                  = "vm-${var.name_prefix}-manager"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.this.id]
  custom_data           = base64encode(local.cloud_init)
  tags                  = var.tags

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

  # custom_data only bootstraps the VM. Runner settings travel through Key Vault
  # (runner-config-template), so changing them never replaces the VM.
  lifecycle {
    ignore_changes = [custom_data, source_image_reference[0].version]
  }
}
