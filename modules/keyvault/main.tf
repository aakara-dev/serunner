resource "azurerm_key_vault" "this" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = var.purge_protection_enabled
  tags                       = var.tags

  network_acls {
    bypass = "AzureServices"
    # With no allowed IPs we stay open (RBAC still gates access); add the deployer's
    # egress CIDR to lock data-plane access down to that IP plus the manager subnet.
    default_action             = length(var.allowed_ip_cidrs) > 0 ? "Deny" : "Allow"
    ip_rules                   = var.allowed_ip_cidrs
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }
}

# Static keys so for_each is plannable even when principal IDs are created in the same apply.
resource "azurerm_role_assignment" "officers" {
  for_each             = var.secrets_officers
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "readers" {
  for_each             = var.secrets_readers
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}

# RBAC data-plane grants take a while to propagate; writing secrets immediately 403s.
resource "time_sleep" "rbac_propagation" {
  create_duration = "90s"
  depends_on      = [azurerm_role_assignment.officers]
}

resource "azurerm_key_vault_secret" "managed" {
  for_each     = toset(var.managed_secret_names)
  name         = each.key
  value        = var.managed_secret_values[each.key]
  key_vault_id = azurerm_key_vault.this.id
  content_type = "terraform-managed"

  depends_on = [time_sleep.rbac_propagation]
}
