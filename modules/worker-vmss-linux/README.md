# worker-vmss-linux

Uniform Linux VMSS at 0 instances with Docker (cloud-init) for the docker-autoscaler executor. Capacity is owned by GitLab Runner; `instances` is ignored after creation.

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
| [azurerm_linux_virtual_machine_scale_set.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_ssh_public_key"></a> [admin\_ssh\_public\_key](#input\_admin\_ssh\_public\_key) | OpenSSH public key matching the private key the manager reads from Key Vault. | `string` | n/a | yes |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Admin user the runner connector logs in as. | `string` | `"runner"` | no |
| <a name="input_computer_name_prefix"></a> [computer\_name\_prefix](#input\_computer\_name\_prefix) | Hostname prefix for instances. | `string` | `"cilnx"` | no |
| <a name="input_image"></a> [image](#input\_image) | Marketplace image for workers. | <pre>object({<br/>    publisher = string<br/>    offer     = string<br/>    sku       = string<br/>    version   = string<br/>  })</pre> | <pre>{<br/>  "offer": "ubuntu-24_04-lts",<br/>  "publisher": "Canonical",<br/>  "sku": "server",<br/>  "version": "latest"<br/>}</pre> | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Scale set name. Must be dedicated to one [[runners]] entry. | `string` | n/a | yes |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS disk size; Docker images for JVM/Spark stacks are large. | `number` | `64` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Resource group for the scale set (the manager identity gets scoped rights here). | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Worker subnet ID. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |
| <a name="input_use_spot"></a> [use\_spot](#input\_use\_spot) | Use Spot priority (~80% cheaper, may be evicted mid-job). | `bool` | `false` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Worker VM size. D4s\_v5 (4 vCPU/16 GB) fits sbt/Spark and Maven builds. | `string` | `"Standard_D4s_v5"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_admin_username"></a> [admin\_username](#output\_admin\_username) | Username the connector uses. |
| <a name="output_id"></a> [id](#output\_id) | Scale set resource ID. |
| <a name="output_name"></a> [name](#output\_name) | Scale set name (fleeting plugin\_config.name). |
<!-- END_TF_DOCS -->
