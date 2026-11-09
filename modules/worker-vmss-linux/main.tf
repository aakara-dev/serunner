locals {
  is_spot = var.use_spot
}

# Uniform VMSS that starts at 0 instances. GitLab Runner (fleeting-plugin-azure) owns the
# capacity, so Azure autoscale is not configured and `instances` is ignored after create.
resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                 = var.name
  location             = var.location
  resource_group_name  = var.resource_group_name
  sku                  = var.vm_size
  instances            = 0
  computer_name_prefix = var.computer_name_prefix
  admin_username       = var.admin_username
  overprovision        = false
  upgrade_mode         = "Manual"
  custom_data          = base64encode(templatefile("${path.module}/templates/cloud-init.yaml", { admin_username = var.admin_username }))
  tags                 = var.tags

  priority        = local.is_spot ? "Spot" : "Regular"
  eviction_policy = local.is_spot ? "Delete" : null
  max_bid_price   = local.is_spot ? -1 : null

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

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

      # Per-instance public IP for egress only (NSG blocks inbound). Billed only while
      # the instance exists, unlike a NAT gateway.
      public_ip_address {
        name = "pip"
      }
    }
  }

  boot_diagnostics {}

  lifecycle {
    ignore_changes = [instances]
  }
}
