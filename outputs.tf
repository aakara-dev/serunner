output "resource_group" {
  description = "Resource group with the manager, worker scale sets, identity and NSG."
  value       = azurerm_resource_group.this.name
}

output "subnet_id" {
  description = "Runner subnet created in the spoke VNet."
  value       = module.network.subnet_id
}

output "manager_vm_name" {
  description = "Runner manager VM (for az vm run-command)."
  value       = module.runner_manager.vm_name
}

output "manager_private_ip" {
  description = "Manager's static private IP (source address seen by the hub firewall and GitLab)."
  value       = module.network.manager_private_ip
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
