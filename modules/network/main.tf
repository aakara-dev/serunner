resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  tags                = var.tags
}

# Default outbound access is disabled explicitly: the manager and every worker get their
# own Standard public IP for egress instead of a NAT gateway (~$33/mo fixed cost).
resource "azurerm_subnet" "manager" {
  name                            = "snet-manager"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [var.manager_subnet_prefix]
  default_outbound_access_enabled = false

  service_endpoint {
    service = "Microsoft.KeyVault"
  }
}

resource "azurerm_subnet" "workers" {
  name                            = "snet-workers"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [var.workers_subnet_prefix]
  default_outbound_access_enabled = false
}

# Manager: no inbound rules at all. Admin access is via `az vm run-command` or serial console.
resource "azurerm_network_security_group" "manager" {
  name                = "nsg-${var.name_prefix}-manager"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

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

# Workers: only the manager may reach SSH (Linux) and WinRM-HTTP (Windows).
# WinRM uses Basic auth over HTTP (what fleeting-plugin-azure expects), so it must
# never be reachable from outside this subnet pair.
resource "azurerm_network_security_group" "workers" {
  name                = "nsg-${var.name_prefix}-workers"
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
    source_address_prefix      = var.manager_subnet_prefix
    destination_address_prefix = var.workers_subnet_prefix
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

resource "azurerm_subnet_network_security_group_association" "manager" {
  subnet_id                 = azurerm_subnet.manager.id
  network_security_group_id = azurerm_network_security_group.manager.id
}

resource "azurerm_subnet_network_security_group_association" "workers" {
  subnet_id                 = azurerm_subnet.workers.id
  network_security_group_id = azurerm_network_security_group.workers.id
}
