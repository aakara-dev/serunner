output "key_vault_name" {
  description = "Key Vault to store runner tokens in (runner-token-linux, runner-token-windows)."
  value       = module.keyvault.name
}

output "manager_vm_name" {
  description = "Runner manager VM (for az vm run-command)."
  value       = module.runner_manager.vm_name
}

output "core_resource_group" {
  description = "Resource group with network, Key Vault and manager."
  value       = azurerm_resource_group.core.name
}

output "workers_resource_group" {
  description = "Resource group with the worker scale sets."
  value       = azurerm_resource_group.workers.name
}

output "linux_vmss_name" {
  description = "Linux worker scale set."
  value       = module.worker_linux.name
}

output "windows_vmss_name" {
  description = "Windows worker scale set (null when disabled)."
  value       = var.enable_windows ? module.worker_windows[0].name : null
}

output "runner_concurrent" {
  description = "Global concurrent job limit written to config.toml."
  value       = module.runner_manager.concurrent
}
