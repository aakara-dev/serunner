output "id" {
  description = "Key Vault resource ID."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}

output "vault_uri" {
  description = "Key Vault data-plane URI."
  value       = azurerm_key_vault.this.vault_uri
}

output "secrets_ready" {
  description = "Opaque value that becomes known once managed secrets exist; use as a dependency."
  value       = [for s in azurerm_key_vault_secret.managed : s.versionless_id]
}
