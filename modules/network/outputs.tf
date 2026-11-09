output "subnet_id" {
  description = "Runner subnet ID (manager and worker scale sets)."
  value       = azurerm_subnet.this.id
}

output "manager_private_ip" {
  description = "Static private IP reserved for the runner manager."
  value       = local.manager_private_ip
}
