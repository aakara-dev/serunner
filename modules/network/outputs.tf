output "vnet_id" {
  description = "ID of the runner VNet."
  value       = azurerm_virtual_network.this.id
}

output "manager_subnet_id" {
  description = "Subnet ID for the runner manager VM."
  value       = azurerm_subnet.manager.id
}

output "workers_subnet_id" {
  description = "Subnet ID for the worker scale sets."
  value       = azurerm_subnet.workers.id
}
