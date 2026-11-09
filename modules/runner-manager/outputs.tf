output "vm_id" {
  description = "Manager VM resource ID."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Manager VM name (use with `az vm run-command invoke`)."
  value       = azurerm_linux_virtual_machine.this.name
}

output "identity_principal_id" {
  description = "Principal ID of the manager's user-assigned identity."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "identity_client_id" {
  description = "Client ID of the manager's user-assigned identity."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "config_template" {
  description = "Rendered config.toml with __PLACEHOLDER__ secrets; stored in Key Vault as runner-config-template."
  value       = local.config_template
}

output "concurrent" {
  description = "Computed global `concurrent` value in config.toml."
  value       = local.concurrent
}
