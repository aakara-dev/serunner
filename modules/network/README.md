# network

VNet, manager and worker subnets (no default outbound access), and NSGs. Workers accept SSH/WinRM only from the manager subnet.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.12.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 5.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_network_security_group.manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_group.workers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_subnet.manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.workers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_network_security_group_association.workers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | VNet CIDR. | `string` | `"10.60.0.0/16"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for all network resources. | `string` | n/a | yes |
| <a name="input_manager_subnet_prefix"></a> [manager\_subnet\_prefix](#input\_manager\_subnet\_prefix) | CIDR for the runner manager subnet. | `string` | `"10.60.1.0/24"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Short prefix used in resource names, e.g. "glrun". | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Resource group that holds the VNet and NSGs. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |
| <a name="input_workers_subnet_prefix"></a> [workers\_subnet\_prefix](#input\_workers\_subnet\_prefix) | CIDR for the autoscaled worker subnet (Linux and Windows VMSS). | `string` | `"10.60.2.0/23"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_manager_subnet_id"></a> [manager\_subnet\_id](#output\_manager\_subnet\_id) | Subnet ID for the runner manager VM. |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | ID of the runner VNet. |
| <a name="output_workers_subnet_id"></a> [workers\_subnet\_id](#output\_workers\_subnet\_id) | Subnet ID for the worker scale sets. |
<!-- END_TF_DOCS -->
