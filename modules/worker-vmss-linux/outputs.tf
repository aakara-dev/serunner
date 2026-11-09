output "id" {
  description = "Scale set resource ID."
  value       = azurerm_linux_virtual_machine_scale_set.this.id
}

output "name" {
  description = "Scale set name (fleeting plugin_config.name)."
  value       = azurerm_linux_virtual_machine_scale_set.this.name
}

output "admin_username" {
  description = "Username the connector uses."
  value       = var.admin_username
}
