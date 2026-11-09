locals {
  # First usable address (Azure reserves .0-.3). Static so the NSG can trust exactly one source.
  manager_private_ip = cidrhost(var.subnet_prefix, 4)
}

# One subnet in the existing hub-spoke VNet. No public IPs anywhere (org policy): egress goes
# through the hub firewall via the spoke route table, so default outbound access stays off.
resource "azurerm_subnet" "this" {
  name                            = "snet-${var.name_prefix}"
  resource_group_name             = var.vnet_resource_group_name
  virtual_network_name            = var.vnet_name
  address_prefixes                = [var.subnet_prefix]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet_route_table_association" "this" {
  count          = var.route_table_id == null ? 0 : 1
  subnet_id      = azurerm_subnet.this.id
  route_table_id = var.route_table_id
}

# Manager and workers share the subnet, and NSG rules apply inside a subnet too, so the
# workers' SSH/WinRM ports are open only to the manager's static IP. WinRM uses Basic auth
# over HTTP (what fleeting-plugin-azure expects); it must never be reachable more widely.
resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "allow-manager-ssh-winrm"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "5985"]
    source_address_prefix      = "${local.manager_private_ip}/32"
    destination_address_prefix = var.subnet_prefix
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}
