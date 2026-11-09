locals {
  is_spot = var.use_spot

  bootstrap = templatefile("${path.module}/templates/bootstrap.ps1", {
    git_installer_url    = var.git_installer.url
    git_installer_sha256 = var.git_installer.sha256
    runner_binary_url    = var.runner_binary.url
    runner_binary_sha256 = var.runner_binary.sha256
  })
}

# Uniform VMSS at 0 instances for .NET Framework builds (instance executor over WinRM).
# Windows custom_data lands in C:\AzureData\CustomData.bin; the CSE renames and runs it,
# which avoids the 8 KB commandToExecute limit.
resource "azurerm_windows_virtual_machine_scale_set" "this" {
  name                 = var.name
  location             = var.location
  resource_group_name  = var.resource_group_name
  sku                  = var.vm_size
  instances            = 0
  computer_name_prefix = var.computer_name_prefix
  admin_username       = var.admin_username
  admin_password       = var.admin_password
  overprovision        = false
  upgrade_mode         = "Manual"
  custom_data          = base64encode(local.bootstrap)
  timezone             = "UTC"
  tags                 = var.tags

  # Instances are short-lived; patching happens by picking up the newest image on scale-out.
  automatic_updates_enabled = false

  priority        = local.is_spot ? "Spot" : "Regular"
  eviction_policy = local.is_spot ? "Delete" : null
  max_bid_price   = local.is_spot ? -1 : null

  source_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name      = "ipcfg"
      primary   = true
      subnet_id = var.subnet_id
    }
  }

  extension {
    name                       = "bootstrap"
    publisher                  = "Microsoft.Compute"
    type                       = "CustomScriptExtension"
    type_handler_version       = "1.10"
    auto_upgrade_minor_version = true

    protected_settings = jsonencode({
      commandToExecute = "powershell -NoProfile -ExecutionPolicy Bypass -Command \"Copy-Item C:\\AzureData\\CustomData.bin C:\\AzureData\\bootstrap.ps1 -Force; & C:\\AzureData\\bootstrap.ps1\""
    })
  }

  boot_diagnostics {}

  lifecycle {
    ignore_changes = [instances]
  }
}
