# keyvault

RBAC-mode Key Vault for runner tokens and worker credentials, with role grants and a propagation wait before Terraform-managed secrets are written.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.12.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.14.2 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 5.12.0 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.14.2 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_secret.managed](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_role_assignment.officers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.readers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [time_sleep.rbac_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_ip_cidrs"></a> [allowed\_ip\_cidrs](#input\_allowed\_ip\_cidrs) | Public CIDRs allowed to reach the vault data plane (e.g. the deployer's egress IP). Empty = allow all networks, RBAC only. | `list(string)` | `[]` | no |
| <a name="input_allowed_subnet_ids"></a> [allowed\_subnet\_ids](#input\_allowed\_subnet\_ids) | Subnets (with the Microsoft.KeyVault service endpoint) allowed to reach the vault. | `list(string)` | `[]` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_managed_secret_names"></a> [managed\_secret\_names](#input\_managed\_secret\_names) | Names of secrets Terraform writes. Kept separate from the values so for\_each keys are not sensitive. | `list(string)` | `[]` | no |
| <a name="input_managed_secret_values"></a> [managed\_secret\_values](#input\_managed\_secret\_values) | Secret name => value for every entry in managed\_secret\_names. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Globally unique Key Vault name (3-24 chars, alphanumerics and hyphens). | `string` | n/a | yes |
| <a name="input_purge_protection_enabled"></a> [purge\_protection\_enabled](#input\_purge\_protection\_enabled) | Enable purge protection. Safer, but the vault name is then locked for the retention period after deletion. | `bool` | `false` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Resource group for the vault. | `string` | n/a | yes |
| <a name="input_secrets_officers"></a> [secrets\_officers](#input\_secrets\_officers) | Static key => principal ID granted Key Vault Secrets Officer (read/write). Typically the deployer. | `map(string)` | `{}` | no |
| <a name="input_secrets_readers"></a> [secrets\_readers](#input\_secrets\_readers) | Static key => principal ID granted Key Vault Secrets User (read). Typically the runner manager identity. | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Entra ID tenant ID for the vault. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | Key Vault resource ID. |
| <a name="output_name"></a> [name](#output\_name) | Key Vault name. |
| <a name="output_secrets_ready"></a> [secrets\_ready](#output\_secrets\_ready) | Opaque value that becomes known once managed secrets exist; use as a dependency. |
| <a name="output_vault_uri"></a> [vault\_uri](#output\_vault\_uri) | Key Vault data-plane URI. |
<!-- END_TF_DOCS -->
